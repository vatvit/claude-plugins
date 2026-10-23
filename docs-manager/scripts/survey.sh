#!/usr/bin/env bash
# survey.sh — onboard a legacy project: find the docs it already has, plan, build docs/.
# Sourced by docs.sh, never executed. Relies on lib.sh and external.sh being sourced first.
#
#   docs.sh survey [project]            read-only; prints the plan, one row per source
#   docs.sh onboard <plan> [project]    applies an approved plan (survey output, edited)
#
# A plan row is tab-separated:  action<TAB>kind<TAB>source<TAB>destination<TAB>bytes
#
#   move    source -> destination under docs/ (git mv when tracked); links rewritten both ways
#   link    left in place, listed in docs/_index.md's sources block (README, code-side docs)
#   ignore  left in place, listed in that block under "Not documentation"
#   adopt   already under docs/ but has no frontmatter; onboard adds it
#   write   a doc to write from the code (Claude's job; onboard only reports it)
#   cite    evidence for a `write` row (Makefile, compose, CI); never acted on
#
# Everything is relative to the project, and both commands run inside it. A source is
# handled once it is under docs/ with frontmatter or linked from a doc under docs/ — so the
# sources block is what makes a second survey propose nothing. `write` and `cite` rows are
# proposed only before the first onboard, when docs/_index.md has no sources block yet.

SOURCES_START="<!-- SOURCES:START — written by docs.sh onboard; sources kept in place, linked from here -->"
SOURCES_END="<!-- SOURCES:END -->"
ONBOARD_ACTIONS="move link ignore adopt write cite"

# project_files -> every file of the project in the cwd, project-relative, sorted bytewise
# (LC_ALL=C), so a plan lists in the same order on every machine.
#
# `git ls-files` when the project is a work tree, so .gitignore is respected exactly; `find`
# otherwise. Either way any dot-component is dropped (except CI under .github/workflows/ and
# .gitlab-ci.yml), and so are dependency, build and fixture folders, which hold no docs of the
# project's own.
project_files() {
  {
    if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      git -c core.quotepath=off ls-files --cached --others --exclude-standard
    else
      find . -type f | sed 's|^\./||'
    fi
  } | awk '
    BEGIN { n = split("node_modules vendor bower_components dist build target out coverage __pycache__ venv site-packages fixtures testdata __snapshots__", x, " ")
            for (i = 1; i <= n; i++) skip[x[i]] = 1 }
    $0 == ".gitlab-ci.yml" || index($0, ".github/workflows/") == 1 { print; next }
    {
      c = split($0, p, "/")
      for (i = 1; i <= c; i++) if (substr(p[i], 1, 1) == "." || (i < c && (p[i] in skip))) next
      print
    }' | while IFS= read -r f; do [ -f "$f" ] && printf '%s\n' "$f"; done | LC_ALL=C sort
  return 0
}

# onboarded -> 0 when docs/_index.md carries the sources block, i.e. onboard has run
onboarded() { [ -f docs/_index.md ] && has_marker docs/_index.md "$SOURCES_START"; }

# survey_rows -> plan rows without the bytes column. Runs in the project.
survey_rows() {
  local files linked nofm ob=0 f
  files="$(mktemp)"; linked="$(mktemp)"; nofm="$(mktemp)"
  project_files > "$files"
  if [ -d docs ]; then
    doc_links docs | cut -f3 > "$linked"
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      [ "$(head -n 1 "$f")" = "---" ] || normalize_path "$f" >> "$nofm"
    done <<EOF
$(docs_find docs "" -type f -name '*.md' | sort)
EOF
  fi
  onboarded && ob=1
  awk -v linkedf="$linked" -v nofmf="$nofm" -v ob="$ob" -v exts="$EXTERNAL_EXTS" '
    function base(p,   i) { i = split(p, a, "/"); return a[i] }
    function ext(p,   b, i) { b = tolower(base(p)); i = split(b, a, "."); return i > 1 ? a[i] : "" }
    # a destination nothing else claims: on a clash, the parent folder name goes in front
    function claim(d, src,   b, dir, i, n) {
      if (!(d in taken)) { taken[d] = 1; return d }
      n = split(src, s, "/"); b = base(d); dir = substr(d, 1, length(d) - length(b))
      d = dir (n > 1 ? s[n - 1] : "root") "-" b
      for (i = 2; d in taken; i++) d = dir i "-" b
      taken[d] = 1; return d
    }
    function row(a, k, s, d) { printf "%s\t%s\t%s\t%s\n", a, k, s, d }
    BEGIN {
      while ((getline l < linkedf) > 0) linked[l] = 1
      while ((getline l < nofmf) > 0) nofm[l] = 1
      n = split(exts, x, " "); for (i = 1; i <= n; i++) isext[x[i]] = 1
      n = split("doc documentation wiki", x, " "); for (i = 1; i <= n; i++) docdir[x[i]] = 1
      n = split("adr adrs decisions", x, " "); for (i = 1; i <= n; i++) adrdir[x[i]] = 1
      n = split("md markdown rst adoc txt", x, " "); for (i = 1; i <= n; i++) prose[x[i]] = 1
    }
    { f[++nf] = $0; taken[$0] = 1 }
    END {
      for (j = 1; j <= nf; j++) {
        p = f[j]; lp = tolower(p); b = tolower(base(p)); e = ext(p)
        c = split(p, part, "/"); split(lp, lpart, "/")
        if (index(p, "docs/") == 1) {
          if (p in nofm) row("adopt", "docs", p, p)
          continue
        }
        if (p in linked) continue
        # evidence for how to run, build and test
        if (b == "makefile" || b == "gnumakefile" || b == "justfile" || b == "taskfile.yml" || b == "jenkinsfile" \
            || b ~ /^dockerfile/ || b ~ /^(docker-)?compose[^\/]*\.ya?ml$/ || p == ".gitlab-ci.yml" \
            || index(p, ".github/workflows/") == 1 || b == "azure-pipelines.yml" || b == "bitbucket-pipelines.yml") {
          if (!ob) row("cite", "build", p, "-")
          continue
        }
        if (b == "claude.md" || b == "agents.md") { row("link", "agent", p, "-"); continue }
        if (b ~ /^(readme|changelog|contributing|code_of_conduct|security|history)(\.(md|markdown|rst|adoc|txt))?$/) {
          row("link", "meta", p, "-"); continue
        }
        if (b ~ /^(openapi|swagger|asyncapi)/ && (e == "yaml" || e == "yml" || e == "json")) {
          row("link", "api", p, "-"); continue
        }
        # a documentation folder moves wholesale, images and all, so its links keep working
        for (i = 1; i < c; i++) if ((lpart[i] in docdir) || (lpart[i] in adrdir)) break
        if (i < c) {
          rest = ""; for (k = i + 1; k <= c; k++) rest = rest (rest == "" ? "" : "/") part[k]
          if (lpart[i] in adrdir) { kind = "adr"; d = "docs/decisions/" rest }
          else if (e in isext) { kind = "external"; d = "docs/external/" rest }
          else { kind = (e in prose) ? "doc" : "asset"; d = "docs/" rest }
          if (e == "markdown") d = substr(d, 1, length(d) - 8) "md"
          row("move", kind, p, claim(d, p)); continue
        }
        if (e in isext) { row("ignore", "external", p, "-"); continue }
        if (e == "md" || e == "markdown" || e == "rst" || e == "adoc") {
          if (c == 1) {
            d = "docs/" tolower(p); if (e == "markdown") d = substr(d, 1, length(d) - 8) "md"
            row("move", "doc", p, claim(d, p))
          } else row("link", "doc", p, "-")
        }
      }
      if (!ob) {
        n = split("overview.md architecture.md how-to-run.md", w, " ")
        for (i = 1; i <= n; i++) {
          for (j = 1; j <= nf; j++) if (tolower(base(f[j])) == w[i] && index(f[j], "docs/") == 1) break
          if (j > nf && !(("docs/" w[i]) in taken)) row("write", "from-code", "-", "docs/" w[i])
        }
      }
    }' "$files"
  rm -f "$files" "$linked" "$nofm"
  return 0
}

cmd_survey() {
  local project="${1:-.}"
  [ -d "$project" ] || { echo "No such project: $project" >&2; return 1; }
  (
    cd "$project" || exit 1
    printf '# action\tkind\tsource\tdestination\tbytes\n'
    while IFS=$'\t' read -r a k s d; do
      [ -n "$a" ] || continue
      if [ "$s" = "-" ]; then n="-"; else n="$(wc -c < "$s" | tr -d ' ')"; fi
      printf '%s\t%s\t%s\t%s\t%s\n' "$a" "$k" "$s" "$d" "$n"
    done <<EOF
$(survey_rows)
EOF
  )
}

# plan_check <plan> -> reports every problem; non-zero if any. Runs in the project.
plan_check() {
  local rc=0 a k s d seen known
  seen="$(mktemp)"
  while IFS=$'\t' read -r a k s d _; do
    case "$a" in ''|'#'*) continue ;; esac
    known=0; for k in $ONBOARD_ACTIONS; do [ "$k" = "$a" ] && known=1; done
    [ "$known" = 1 ] || { echo "PLAN: unknown action '$a' for $s" >&2; rc=1; continue; }
    case "$a" in write|cite) continue ;; esac
    case "/$s/" in */../*|//*) echo "PLAN: source must be inside the project: $s" >&2; rc=1; continue ;; esac
    [ -f "$s" ] || { echo "PLAN: no such file: $s" >&2; rc=1; continue; }
    case "$a" in
      move)
        case "/$d/" in /docs/*/) ;; *) echo "PLAN: destination must be under docs/: $s -> $d" >&2; rc=1; continue ;; esac
        case "/$d/" in */../*) echo "PLAN: destination must be inside docs/: $d" >&2; rc=1; continue ;; esac
        [ -e "$d" ] && { echo "PLAN: refusing to overwrite: $d" >&2; rc=1; continue; }
        grep -qxF -- "$d" "$seen" && { echo "PLAN: two sources move to $d" >&2; rc=1; continue; }
        printf '%s\n' "$d" >> "$seen" ;;
      adopt)
        case "$s" in docs/*.md) ;; *) echo "PLAN: adopt is for a doc under docs/: $s" >&2; rc=1 ;; esac ;;
    esac
  done < "$1"
  rm -f "$seen"
  return $rc
}

# move_file <old> <new> — git mv when the file is tracked, so its history follows it
move_file() {
  mkdir -p "$(dirname "$2")"
  if command -v git >/dev/null 2>&1 && git ls-files --error-unmatch -- "$1" >/dev/null 2>&1; then
    git mv -- "$1" "$2" >/dev/null || return 1
  else
    mv "$1" "$2" || return 1
  fi
  echo "MOVED: $1 -> $2"
  # a folder the move emptied goes too, as it does under git mv
  local d; d="$(dirname "$1")"
  while [ "$d" != "." ] && rmdir "$d" 2>/dev/null; do d="$(dirname "$d")"; done
  return 0
}

# moved_to <movesfile> <path> -> where <path> is now (itself when it did not move)
moved_to() {
  awk -F'\t' -v p="$2" '$1 == p { n = $2 } END { print (n == "" ? p : n) }' "$1"
}
moved_from() {
  awk -F'\t' -v p="$2" '$2 == p { n = $1 } END { print (n == "" ? p : n) }' "$1"
}

# rewrite_links <file> <old-path-of-file> <movesfile>
#
# Every relative link in <file> whose target moved, or that sits in a file that moved, is
# re-pointed at where the target is now. The destinations come from md_link_dests, the one
# link parser; only the destinations it returns are replaced, and only inside `](…)`.
rewrite_links() {
  local file="$1" old="$2" moves="$3" raw path suffix dec target now new map tmp
  map="$(mktemp)"
  while IFS= read -r raw; do
    case "$raw" in http://*|https://*|mailto:*|\#*|/*|"") continue ;; esac
    path="${raw%%[#?]*}"; suffix="${raw#"$path"}"
    [ -n "$path" ] || continue
    dec="$path"; case "$dec" in *%*) dec="$(url_decode "$dec")" ;; esac
    target="$(normalize_path "$(dirname "$old")/$dec")"
    now="$(moved_to "$moves" "$target")"
    [ "$now" != "$target" ] || [ "$file" != "$old" ] || continue
    # a dead link stays as written, so the report names what the author wrote
    [ "$now" != "$target" ] || [ -e "$target" ] || continue
    new="$(relpath "$(dirname "$file")" "$now")"
    [ "$new" = "$dec" ] && continue
    printf '%s\t%s\n' "$raw" "$(md_dest "$new$suffix")" >> "$map"
  done <<EOF
$(md_link_dests "$file" | sort -u)
EOF
  if [ -s "$map" ]; then
    tmp="$(mktemp)"
    awk -v mapf="$map" '
      BEGIN { while ((getline l < mapf) > 0) { t = index(l, "\t"); from[++n] = substr(l, 1, t - 1); to[n] = substr(l, t + 1) } }
      # replace `](raw` (bare, ending at ")" or blank) and `](<raw>`, scanning left to right
      {
        s = $0; out = ""
        while ((i = index(s, "](")) > 0) {
          out = out substr(s, 1, i + 1); s = substr(s, i + 2)
          ws = s; sub(/[^ \t].*$/, "", ws); out = out ws; s = substr(s, length(ws) + 1)
          for (k = 1; k <= n; k++) {
            if (substr(s, 1, length(from[k]) + 2) == "<" from[k] ">") { out = out to[k]; s = substr(s, length(from[k]) + 3); break }
            nx = substr(s, length(from[k]) + 1, 1)
            if (substr(s, 1, length(from[k])) == from[k] && (nx == ")" || nx == " " || nx == "\t")) {
              out = out to[k]; s = substr(s, length(from[k]) + 1); break
            }
          }
        }
        print out s
      }' "$file" > "$tmp"
    write_if_changed "$tmp" "$file" "RELINKED" || true
  fi
  rm -f "$map"
}

# add_frontmatter <file> — title from the first `# ` heading (else the file name), and the
# description left as TODO, the same placeholder `index` gives a new _index.md
add_frontmatter() {
  local f="$1" title tmp
  [ "$(head -n 1 "$f")" = "---" ] && return 0
  title="$(awk '/^# / { sub(/^# +/, ""); print; exit }' "$f")"
  [ -n "$title" ] || { title="$(basename "$f")"; title="${title%.*}"; }
  tmp="$(mktemp)"
  { printf -- '---\ntitle: %s\ndescription: TODO\n---\n\n' "$title"; cat "$f"; } > "$tmp"
  mv "$tmp" "$f"
  echo "FRONTMATTER: $f"
}

# write_sources <rowsfile> — merge `link`/`ignore` rows into docs/_index.md's sources block.
# Rows already in the block are kept, so the block only grows; a stale row is a broken link
# that `links` reports.
write_sources() {
  local rows="$1" all block tmp sec path kind
  all="$(mktemp)"; block="$(mktemp)"
  if onboarded; then   # rows already there, read back from the block's own lines
    awk -v s="$SOURCES_START" -v e="$SOURCES_END" '
      $0 == s { on = 1; sec = "link"; next } $0 == e { on = 0 }
      on && /^### Not documentation/ { sec = "ignore" }
      on && /^- \[`/ { p = $0; sub(/^- \[`/, "", p); k = p; sub(/`.*$/, "", p)
                       sub(/^.* — /, "", k); if (k == $0) k = "-"; printf "%s\t%s\t%s\n", sec, p, k }' docs/_index.md > "$all"
  fi
  cat "$rows" >> "$all"
  {
    printf '%s\n## Elsewhere in this repository\n\n' "$SOURCES_START"
    printf 'Documentation kept beside the code it describes, linked rather than moved.\n\n'
    sort -u "$all" | awk -F'\t' '$1 == "link"' | while IFS=$'\t' read -r sec path kind; do
      printf -- '- [`%s`](%s) — %s\n' "$path" "$(md_dest "$(relpath docs "$path")")" "$kind"
    done
    if awk -F'\t' '$1 == "ignore" { f = 1 } END { exit !f }' "$all"; then
      printf '\n### Not documentation\n\n'
      sort -u "$all" | awk -F'\t' '$1 == "ignore"' | while IFS=$'\t' read -r sec path kind; do
        printf -- '- [`%s`](%s) — %s\n' "$path" "$(md_dest "$(relpath docs "$path")")" "$kind"
      done
    fi
    printf '%s\n' "$SOURCES_END"
  } > "$block"
  tmp="$(mktemp)"
  if onboarded; then
    block_rewrite docs/_index.md "$SOURCES_START" "$SOURCES_END" "$block" > "$tmp"
  else
    { cat docs/_index.md; printf '\n'; cat "$block"; } > "$tmp"
  fi
  write_if_changed "$tmp" docs/_index.md "SOURCES" || true
  rm -f "$all" "$block"
}

cmd_onboard() {
  local plan="${1:-}" project="${2:-.}"
  [ -n "$plan" ] || { echo "Usage: docs.sh onboard <plan-file> [project]" >&2; return 2; }
  [ -f "$plan" ] || { echo "No such plan: $plan" >&2; return 1; }
  [ -d "$project" ] || { echo "No such project: $project" >&2; return 1; }
  plan="$(cd "$(dirname "$plan")" && pwd)/$(basename "$plan")"
  (
    cd "$project" || exit 1
    plan_check "$plan" || { echo "Plan rejected; nothing was changed." >&2; exit 1; }
    moves="$(mktemp)"; rows="$(mktemp)"
    while IFS=$'\t' read -r a k s d _; do
      case "$a" in
        move) printf '%s\t%s\n' "$s" "$d" >> "$moves" ;;
        link|ignore) printf '%s\t%s\t%s\n' "$a" "$s" "$k" >> "$rows" ;;
      esac
    done < "$plan"

    while IFS=$'\t' read -r s d; do
      [ -n "$s" ] && { move_file "$s" "$d" || exit 1; }
    done < "$moves"

    if [ -s "$moves" ]; then
      while IFS= read -r f; do
        case "$f" in *.md) rewrite_links "$f" "$(moved_from "$moves" "$f")" "$moves" ;; esac
      done <<EOF
$(project_files)
EOF
    fi

    while IFS=$'\t' read -r a k s d _; do
      case "$a" in
        move) case "$d" in *.md) add_frontmatter "$d" ;; esac ;;
        adopt) add_frontmatter "$s" ;;
        write) echo "TO WRITE: $d" ;;
      esac
    done < "$plan"

    mkdir -p docs
    cmd_index --write docs
    write_sources "$rows"
    rm -f "$moves" "$rows"
    out="$(cmd_links docs || true)"
    [ -z "$out" ] || printf '%s\n' "$out"
    exit 0
  )
}
