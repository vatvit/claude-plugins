#!/usr/bin/env bash
#
# task-roadmap/scripts/generate.sh — render the abstract-Gantt roadmap from a
# markdown task set (tasks/*.md frontmatter, as produced by the /task skill).
#
# Pure bash + awk, no language runtime. Parses each task's YAML frontmatter
# (title, status, type, priority, epic, estimate, deps), builds a JSON object
# {tasks, epics}, and splices it (plus the project title) into the plugin's
# template.html to produce a self-contained HTML page (open via file://).
# All scheduling / critical-path / drawing logic lives in the template's JS.
#
# Usage:
#   generate.sh [PROJECT_ROOT]
#     PROJECT_ROOT defaults to $CLAUDE_PROJECT_DIR, else the current directory.
#
# Configuration (all optional):
#   <root>/.task-config.json   -> tasksDir            (shared with the /task skill)
#   <root>/.task-roadmap.json  -> { title, tasksDir, outputs:[ "path", ... ] }
# Defaults: title "Task Roadmap", tasksDir "tasks", output "<tasksDir>/roadmap.html".
#
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ROOT="${1:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"
TEMPLATE="$PLUGIN_ROOT/assets/template.html"
[ -f "$TEMPLATE" ] || { echo "error: template not found: $TEMPLATE" >&2; exit 1; }

json_str () { grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$2" 2>/dev/null | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//'; }

# --- resolve config ----------------------------------------------------------
TITLE="Task Roadmap"
TASKS_DIR="tasks"
[ -f "$ROOT/.task-config.json" ]  && { v="$(json_str tasksDir "$ROOT/.task-config.json")";  [ -n "$v" ] && TASKS_DIR="$v"; }
CFG="$ROOT/.task-roadmap.json"
declare -a OUTPUTS=()
if [ -f "$CFG" ]; then
  v="$(json_str title "$CFG")";    [ -n "$v" ] && TITLE="$v"
  v="$(json_str tasksDir "$CFG")"; [ -n "$v" ] && TASKS_DIR="$v"
  # outputs: array of strings on a single line
  while IFS= read -r o; do OUTPUTS+=("$o"); done < <(
    grep -o '"outputs"[[:space:]]*:[[:space:]]*\[[^]]*\]' "$CFG" | grep -o '"[^"]*"' | sed '1d; s/^"//; s/"$//')
fi

case "$TASKS_DIR" in /*) : ;; *) TASKS_DIR="$ROOT/$TASKS_DIR" ;; esac
[ -d "$TASKS_DIR" ] || { echo "error: tasks dir not found: $TASKS_DIR" >&2; exit 1; }
[ ${#OUTPUTS[@]} -gt 0 ] || OUTPUTS=("$TASKS_DIR/roadmap.html")
declare -a OUTS=()
for o in "${OUTPUTS[@]}"; do case "$o" in /*) OUTS+=("$o") ;; *) OUTS+=("$ROOT/$o") ;; esac; done

# --- 1. frontmatter -> JSON {tasks:[...], epics:{name:title}} (sorted by ID) ---
# `type: epic` tasks are NOT charted (containers) — they only supply group labels.
JSON="$(awk '
  function jesc(s){ gsub(/\\/,"\\\\",s); gsub(/"/,"\\\"",s); return s }
  FNR==1 { infm=0 }
  {
    if ($0 ~ /^---[ \t]*$/) {
      if (infm==0 && FNR<=2) {
        infm=1
        id=FILENAME; sub(/.*\//,"",id); sub(/\.md$/,"",id)
        title=""; status=""; type=""; priority=""; epic=""; epicname=""; estimate=""; deps=""
        next
      } else if (infm==1) {
        infm=0
        if (type=="epic") { if (epicname!="") epics[epicname]=title; next }
        if (estimate=="") estimate="1"
        d=deps; sub(/^[ \t]*\[/,"",d); sub(/\][ \t]*$/,"",d)
        depjson=""; first=1
        n=split(d, arr, ",")
        for (i=1;i<=n;i++){ g=arr[i]; gsub(/^[ \t]+/,"",g); gsub(/[ \t]+$/,"",g);
          if(g=="") continue; depjson=depjson (first?"":",") "\"" jesc(g) "\""; first=0 }
        objs[++cnt]="{\"id\":\"" jesc(id) "\",\"title\":\"" jesc(title) \
          "\",\"status\":\"" jesc(status) "\",\"type\":\"" jesc(type) \
          "\",\"priority\":\"" jesc(priority) "\",\"epic\":\"" jesc(epic) \
          "\",\"estimate\":" (estimate+0) ",\"deps\":[" depjson "]}"
        next
      }
    }
    if (infm==1 && match($0, /^[A-Za-z_-]+:/)) {
      key=substr($0,1,RLENGTH-1); val=substr($0,RLENGTH+1)
      gsub(/^[ \t]+/,"",val); gsub(/[ \t]+$/,"",val)
      sub(/^"/,"",val); sub(/"$/,"",val); sub(/^'\''/,"",val); sub(/'\''$/,"",val)
      if(key=="title") title=val
      else if(key=="status") status=val
      else if(key=="type") type=val
      else if(key=="priority") priority=val
      else if(key=="epic") epic=val
      else if(key=="epic-name") epicname=val
      else if(key=="estimate") estimate=val
      else if(key=="deps") deps=val
    }
  }
  END{
    printf "{\"tasks\":["
    for(i=1;i<=cnt;i++) printf "%s%s",(i>1?",":""),objs[i]
    printf "],\"epics\":{"
    ei=0; for(k in epics) printf "%s\"%s\":\"%s\"",(ei++?",":""),jesc(k),jesc(epics[k])
    printf "}}"
  }
' "$TASKS_DIR"/*.md)"

# --- 2. splice title + data into template (index/substr => no regex hazards) --
tmp="$(mktemp)"; printf '%s' "$JSON" > "$tmp"
count="$(printf '%s' "$JSON" | grep -o '"id":' | wc -l | tr -d ' ')"
for OUT in "${OUTS[@]}"; do
  mkdir -p "$(dirname "$OUT")"
  awk -v datafile="$tmp" -v title="$TITLE" '
    BEGIN{ data=""; while((getline l < datafile) > 0) data=data l }
    {
      line=$0
      p=index(line,"__TITLE__"); if(p>0) line=substr(line,1,p-1) title substr(line,p+9)
      p=index(line,"__DATA__");  if(p>0) line=substr(line,1,p-1) data  substr(line,p+8)
      print line
    }
  ' "$TEMPLATE" > "$OUT"
  echo "wrote $OUT ($count tasks)"
done
rm -f "$tmp"
