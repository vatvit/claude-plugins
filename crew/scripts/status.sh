#!/usr/bin/env bash
# One screen of crew state: who is in, the branch, and every dirty path by owner. Each area adds
# its own part in status.d/ (holds, slots, ...), so this file never changes when an area is added.
# help: status — the crew, the branch, dirty paths by owner, holds, slots
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
crew_init; need_active
ME="${CREW_AS:-}"
[ -n "$ME" ] && [ ! -f "$STATE/sessions/$ME" ] && ME=""

br="$(shared_branch)"
head="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo none)"
ab=""
if git -C "$ROOT" rev-parse -q --verify "origin/$br" >/dev/null 2>&1; then
    ab=" · vs origin/$br: +$(git -C "$ROOT" rev-list --count "origin/$br..HEAD") -$(git -C "$ROOT" rev-list --count "HEAD..origin/$br")"
fi
echo "crew $(crew_id)${ME:+ · you: $ME ($(sess_get "$ME" role))} · $br @ $head$ab · committer: $(cfg committer)"
echo "sessions: $(crew_line)"

dirty_owned | awk -F'\t' -v me="$ME" '
    { n++; o = $2
      if (o == "") k = "unclaimed"
      else if (index(o, ",")) k = "SHARED " o
      else k = o (o == me ? " (you)" : "")
      if (!(k in g)) ord[++m] = k
      g[k] = g[k] (g[k] == "" ? "" : ", ") $1 }
    END {
      if (!n) { print "dirty: none"; exit }
      print "dirty (" n "):"
      for (i = 1; i <= m; i++) {
        k = ord[i]; hint = ""
        if (k ~ /^SHARED/) hint = "   ← edited by several sessions: one commit takes the whole file"
        if (k == "unclaimed") hint = "   ← no crew edit touched it: generated, or written outside Edit/Write"
        print "  " k ": " g[k] hint
      } }'

for part in "$CREW_LIB_DIR"/status.d/*.sh; do
    [ -f "$part" ] && . "$part"
done
exit 0
