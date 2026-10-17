# status part: crew's worktrees (PLUG-069). Sourced by status.sh (lib loaded, ROOT/STATE/ME set).
# One line each: folder · task or copy · branch · owner · commits not on the shared branch · how far
# behind it · uncommitted files. Which worktrees are crew's is crew_trees' call (tree.sh); any other
# is counted, never listed as crew's.
# A part must end true: status.sh sources it at the end of an && list under set -e.
load_area tree
trees_status() {
    local dir rel kind b by un be dirty lines="" mine=0 foreign=0
    while IFS=$'\t' read -r dir rel kind b by un be dirty; do
        [ -n "$dir" ] || continue
        [ "$kind" != - ] || { foreign=$((foreign + 1)); continue; }
        mine=$((mine + 1))
        [ "$b" = - ] && b=detached
        lines="$lines  $rel · $kind · $b · by $by · $un unmerged · $be behind · $dirty uncommitted
"
    done <<EOF
$(crew_trees)
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
