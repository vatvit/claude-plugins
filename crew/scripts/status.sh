#!/usr/bin/env bash
# One screen of crew state: who is in, the branch, and every dirty path by owner. Each area adds
# its own part in status.d/ (holds, slots, ...), so this file never changes when an area is added.
# help: status [--all] — the crew, the branch, dirty paths by owner (an untracked directory is one line; --all lists every file), holds, slots, crew's worktrees
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
ALL=0
case "${1:-}" in --all) ALL=1 ;; '') ;; *) die "status [--all]" ;; esac
crew_init; need_active
ME="$(caller_name)"
[ -n "$ME" ] && [ ! -f "$STATE/sessions/$ME" ] && ME=""

br="$(shared_branch)"
head="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo none)"
ab=""
if git -C "$ROOT" rev-parse -q --verify "origin/$br" >/dev/null 2>&1; then
    ab=" · vs origin/$br: +$(git -C "$ROOT" rev-list --count "origin/$br..HEAD") -$(git -C "$ROOT" rev-list --count "HEAD..origin/$br")"
fi
echo "crew $(crew_id)${ME:+ · you: $ME ($(sess_get "$ME" role))} · $br @ $head$ab · committer: $(cfg committer) · push: $(cfg push)"
note="$(git_policy_note)"; [ -z "$note" ] || echo "commits and pushes: $note"
note="$(tree_policy_note)"; [ -z "$note" ] || echo "worktrees: $note"
echo "sessions: $(crew_line)"

# collapse_untracked_dirs — dirty_owned lines on stdin, out with every untracked directory (as git
# status shows it, one entry) folded into one "<dir>/ (N files)" line owned by the claimants of its
# files (a directory with one file lists that file). A path a member holds stays a line of its own. Third field: how many dirty paths the line stands for.
collapse_untracked_dirs() {
    local dirs="$STATE/untracked-dirs.$$" holds="$STATE/holds"
    [ -f "$holds" ] || holds=/dev/null
    git -C "$ROOT" status --porcelain -z -unormal | tr '\0' '\n' | awk '/^\?\? .*\/$/ { print substr($0, 4) }' > "$dirs"
    awk -F'\t' -v dirs="$dirs" -v holds="$holds" '
        BEGIN { while ((getline l < dirs) > 0) d[++nd] = l
                while ((getline l < holds) > 0) { split(l, h, "\t"); held[h[1] ""] = 1 } }
        { hit = 0
          if (!(($1 "") in held)) for (i = 1; i <= nd; i++) if (index($1, d[i]) == 1) { hit = i; break }
          if (!hit) { print $0 "\t1"; next }
          cnt[hit]++; if (cnt[hit] == 1) first[hit] = $1
          m = split($2, own, ",")
          for (j = 1; j <= m; j++) if (own[j] != "" && !((hit SUBSEP own[j]) in seen)) {
              seen[hit, own[j]] = 1; owners[hit] = owners[hit] (owners[hit] == "" ? "" : ",") own[j] } }
        END { for (i = 1; i <= nd; i++) if (cnt[i] == 1) printf "%s\t%s\t1\n", first[i], owners[i]    # one file: its own path says more
              else if (cnt[i])
                printf "%s (%d file%s)\t%s\t%d\n", d[i], cnt[i], (cnt[i] == 1 ? "" : "s"), owners[i], cnt[i] }'
    rm -f "$dirs"
}
if [ "$ALL" -eq 1 ]; then dirty_owned | awk -F'\t' '{ print $0 "\t1" }'; else dirty_owned | collapse_untracked_dirs; fi | awk -F'\t' -v me="$ME" '
    { n += $3; o = $2
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
