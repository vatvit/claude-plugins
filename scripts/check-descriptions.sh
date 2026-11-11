#!/usr/bin/env bash
# Check every plugin's marketplace metadata before a release (PLUG-137):
#   - its description is at most MAX characters: a pitch, not a changelog;
#   - <plugin>/.claude-plugin/plugin.json and .claude-plugin/marketplace.json carry the
#     identical description and version.
# Repo tooling, not a plugin: no plugin sources it.
#   bash scripts/check-descriptions.sh [repo-root]     exit 0 = all good, 1 = findings
set -uo pipefail

MAX=250
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd -P)}"
MARKET="$ROOT/.claude-plugin/marketplace.json"
[ -f "$MARKET" ] || { echo "check-descriptions: no $MARKET" >&2; exit 2; }

# One JSON string field's raw value from one line ("key": "value"), escapes kept as written.
field_awk='
function val(line, key,   re, s) {
  re = "\"" key "\"[ \t]*:[ \t]*\""
  if (!match(line, re)) return ""
  s = substr(line, RSTART + RLENGTH)
  if (!match(s, /^([^"\\]|\\.)*/)) return ""
  return substr(s, 1, RLENGTH)
}'

# marketplace.json → name<TAB>source<TAB>version<TAB>description, one plugin per line.
# Expects one field per line, as the file is written; a field missing reads as empty.
market_rows() {
  awk "$field_awk"'
    /"plugins"[ \t]*:/ { inp = 1; next }
    !inp { next }
    /"name"[ \t]*:/        { n = val($0, "name") }
    /"source"[ \t]*:/      { s = val($0, "source") }
    /"version"[ \t]*:/     { v = val($0, "version") }
    /"description"[ \t]*:/ { d = val($0, "description") }
    /^[ \t]*}/ { if (n != "") printf "%s\t%s\t%s\t%s\n", n, s, v, d; n = s = v = d = "" }
  ' "$MARKET"
}

# Top-level field of a plugin.json (first match; the nested author block has no such keys).
pj_field() { awk "$field_awk"' /"'"$2"'"[ \t]*:/ { print val($0, "'"$2"'"); exit }' "$1"; }

# Characters, not bytes: drop UTF-8 continuation bytes, so an em dash counts once on every target.
chars() { printf '%s' "$1" | LC_ALL=C tr -d '\200-\277' | wc -c | tr -d ' '; }

rc=0; n=0
fail() { echo "FAIL $1: $2"; rc=1; }
rows="$(market_rows)"
while IFS=$'\t' read -r name src ver desc; do
  [ -n "$name" ] || continue
  n=$((n + 1))
  pj="$ROOT/${src#./}/.claude-plugin/plugin.json"
  len="$(chars "$desc")"
  [ "$len" -le "$MAX" ] || fail "$name" "marketplace description is $len characters (max $MAX)"
  if [ ! -f "$pj" ]; then fail "$name" "no ${src#./}/.claude-plugin/plugin.json"; continue; fi
  pdesc="$(pj_field "$pj" description)"; pver="$(pj_field "$pj" version)"
  [ "$pdesc" = "$desc" ] || fail "$name" "plugin.json description differs from marketplace.json"
  [ "$pver" = "$ver" ] || fail "$name" "version: plugin.json $pver, marketplace.json $ver"
done <<EOF
$rows
EOF

[ "$n" -gt 0 ] || { echo "check-descriptions: no plugins read from $MARKET" >&2; exit 2; }
[ "$rc" -eq 0 ] && echo "descriptions ok: $n plugins, each at most $MAX characters and in sync"
exit "$rc"
