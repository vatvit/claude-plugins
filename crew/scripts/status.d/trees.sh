# status part: crew's worktrees (PLUG-069). Sourced by status.sh (lib loaded, ROOT/STATE/ME set).
# One line each: folder · task or copy · branch · owner · commits not on the shared branch · how far
# behind it · uncommitted files. crew's own are the folders .worktrees/<repo>-* on a task/<ID> branch,
# or detached with a crew-copy record; any other worktree is counted, never listed as crew's.
# A part must end true: status.sh sources it at the end of an && list under set -e.
load_area tree
trees_status() {
    local br pre wt head b rel kind by lines="" mine=0 foreign=0 un be dirty
    br="$(shared_branch)"; pre="$CREW_WT/${ROOT##*/}-"
    while IFS=$'\t' read -r wt head b; do
        [ -n "$wt" ] || continue
        rel="${wt#"$ROOT"/}"; kind=""; by=""
        case "$rel" in
            "$pre"*)
                case "$b" in
                    task/*) kind="task ${b#task/}"; by="$(crew_wt_meta "$wt" by)" ;;
                    -) [ -f "$(crew_wt_metafile "$wt")" ] && { kind="copy ${rel#"$pre"}"; by="$(crew_wt_meta "$wt" by)"; } ;;
                esac ;;
        esac
        [ -n "$kind" ] || { foreign=$((foreign + 1)); continue; }
        mine=$((mine + 1))
        un="$(git -C "$ROOT" rev-list --count "$br..$head" 2>/dev/null || echo '?')"
        be="$(git -C "$ROOT" rev-list --count "$head..$br" 2>/dev/null || echo '?')"
        dirty="$(crew_wt_dirty "$wt" | wc -l | tr -d ' ')"
        [ "$b" = - ] && b=detached
        lines="$lines  $rel · $kind · $b · by ${by:-?} · $un unmerged · $be behind · $dirty uncommitted
"
    done <<EOF
$(git -C "$ROOT" worktree list --porcelain 2>/dev/null | awk '
    /^worktree / { if (k++ >= 2) print p "\t" h "\t" b; p = substr($0, 10); h = ""; b = "-" }   # the first is the main tree
    /^HEAD /     { h = substr($0, 6) }
    /^branch /   { b = substr($0, 8); sub(/^refs\/heads\//, "", b) }
    END          { if (k > 1) print p "\t" h "\t" b }')
EOF
    [ $((mine + foreign)) -gt 0 ] || return 0
    if [ "$mine" -gt 0 ]; then
        printf 'trees: %s crew worktree%s%s\n' "$mine" "$([ "$mine" -eq 1 ] || echo s)" "$([ "$foreign" -eq 0 ] || echo " · $foreign not crew's (left alone)")"
        printf '%s' "$lines"
    else
        echo "trees: none of crew's · $foreign not crew's (left alone)"
    fi
}
ex="$(declare -F tree_exceptions >/dev/null && tree_exceptions || true)"
[ -z "$ex" ] || echo "worktrees: tree=$(cfg tree) · the user's exceptions: $ex"
trees_status
true
