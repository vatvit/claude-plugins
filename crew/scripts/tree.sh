#!/usr/bin/env bash
# Worktree mode (PLUG-066): one task = branch task/<ID> = one worktree = one session. Whether a
# project works this way is the user's call (`tree`: shared | worktrees, asked once per project);
# under `shared` the user may still make an exception for one task, which the coordinator records.
# The member commits on its own branch and brings in the shared branch (`treeSync`: merge |
# rebase); the coordinator merges the task branch into the shared branch, and only it pushes that.
# help: tree new <task-id> — branch task/<ID> from the shared branch and its worktree in .worktrees/<repo>-<ID>
# help: tree sync <task-id> — bring the shared branch into the task worktree (merge or rebase: treeSync)
# help: tree merge <task-id> — coordinator: merge task/<ID> into the shared branch, then drop worktree and branch
# help: tree remove <task-id> — drop a task worktree and its branch; refused while dirty or not merged
# help: tree allow|revoke <task-id> — coordinator: the user's exception for one task under tree=shared

[ -n "${CREW_LIB_DIR:-}" ] || . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"

tree_allowed() { [ "$(cfg tree)" = worktrees ] || grep -qxF -- "$1" "$STATE/tree-allow" 2>/dev/null; }
tree_exceptions() { [ -f "$STATE/tree-allow" ] && paste -sd' ' - < "$STATE/tree-allow"; return 0; }
_tree_set() { # <id> <add|drop>
    local f="$STATE/tree-allow"
    { [ -f "$f" ] && grep -vxF -- "$1" "$f"; [ "$2" = drop ] || printf '%s\n' "$1"; } | replace_file "$f"
    [ -s "$f" ] || rm -f "$f"
}
tree_coordinator() { [ "$(me)" = "$(coordinator)" ] || die "only the coordinator runs tree $1 (the user's decision, relayed)"; }
# tree_dir <id> — the task worktree's folder; dies unless it is one of crew's
tree_dir() {
    local d; valid_name "$1" || die "a task id: letters, digits, . _ -"
    d="$(crew_wt_dir "$1")"
    [ -d "$d" ] && [ "$(crew_wt_meta "$d" task)" = "$1" ] || die "no task worktree for $1 (make it: crew tree new $1)"
    printf '%s\n' "$d"
}
tree_clean() { # <dir> <id> <what is refused>
    [ -z "$(crew_wt_dirty "$1")" ] || die "$1 has uncommitted work — commit it on task/$2 first ($3 is refused)"
    [ ! -e "$(git -C "$1" rev-parse --path-format=absolute --git-path MERGE_HEAD)" ] && [ ! -d "$(git -C "$1" rev-parse --path-format=absolute --git-path rebase-merge)" ] \
        || die "$1 is mid-merge or mid-rebase — finish it first ($3 is refused)"
}
tree_merged() { git -C "$ROOT" merge-base --is-ancestor "task/$1" "$(shared_branch)" 2>/dev/null; }

# crew_trees — every worktree of the repo except the main tree, one TSV line each:
#   dir  rel  kind  branch  by  unmerged  behind  uncommitted
# kind: "task <ID>" or "copy <name>" for crew's own (.worktrees/<repo>-* on task/<ID>, or detached with
# a crew-copy record), "-" for any other (counted by status, judged by nobody). status lists them;
# end refuses while one of crew's holds work.
crew_trees() {
    local br pre wt head b rel kind by
    br="$(shared_branch)"; pre="$CREW_WT/${ROOT##*/}-"
    while IFS=$'\t' read -r wt head b; do
        [ -n "$wt" ] || continue
        rel="${wt#"$ROOT"/}"; kind=-; by=""
        case "$rel" in
            "$pre"*)
                case "$b" in
                    task/*) kind="task ${b#task/}"; by="$(crew_wt_meta "$wt" by)" ;;
                    -) [ -f "$(crew_wt_metafile "$wt")" ] && { kind="copy ${rel#"$pre"}"; by="$(crew_wt_meta "$wt" by)"; } ;;
                esac ;;
        esac
        [ "$kind" != - ] || { printf '%s\t%s\t-\t%s\t-\t0\t0\t0\n' "$wt" "$rel" "$b"; continue; }
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$wt" "$rel" "$kind" "$b" "${by:-?}" \
            "$(git -C "$ROOT" rev-list --count "$br..$head" 2>/dev/null || echo '?')" \
            "$(git -C "$ROOT" rev-list --count "$head..$br" 2>/dev/null || echo '?')" \
            "$(crew_wt_dirty "$wt" | wc -l | tr -d ' ')"
    done <<EOF
$(git -C "$ROOT" worktree list --porcelain 2>/dev/null | awk '
    /^worktree / { if (k++ >= 2) print p "\t" h "\t" b; p = substr($0, 10); h = ""; b = "-" }   # the first is the main tree
    /^HEAD /     { h = substr($0, 6) }
    /^branch /   { b = substr($0, 8); sub(/^refs\/heads\//, "", b) }
    END          { if (k > 1) print p "\t" h "\t" b }')
EOF
}

tree_new() { # <id>
    local id="$1" br dir me
    valid_name "$id" || die "tree new <task-id>: letters, digits, . _ -"
    tree_allowed "$id" || die "this project works in one shared tree (tree=$(cfg tree)). A worktree for $id is the user's exception: ask them; on their word the coordinator runs crew tree allow $id"
    br="$(shared_branch)"; [ -n "$br" ] || die "no shared branch (detached HEAD?): set sharedBranch"
    ! git -C "$ROOT" rev-parse -q --verify "refs/heads/task/$id" >/dev/null || die "branch task/$id exists already (crew status lists crew's worktrees)"
    [ ! -e "$(crew_wt_dir "$id")" ] || die "$(crew_wt_dir "$id") is in use (crew status lists crew's worktrees)"
    git -C "$ROOT" branch -q "task/$id" "$br" || die "git branch task/$id failed"
    dir="$(crew_wt_add "$id" "task/$id")" || { git -C "$ROOT" branch -q -D "task/$id"; exit 1; }
    crew_wt_write_meta "$dir" "$(git -C "$ROOT" rev-parse "$br")" "$(now)" "$(caller_name)" "$id"
    echo "tree: $dir on task/$id (from $br) — work, test and commit there; bring in $br with: crew tree sync $id; hand off branch, sha and green tests"
    crew_wt_ready "$dir"
    # one task = one worktree = one session: the session that makes it owns the task (PLUG-061)
    me="$(caller_name)"
    if [ -n "$me" ] && [ -f "$STATE/sessions/$me" ]; then load_area task; declare -F task_assign >/dev/null && { task_assign "$me" "$me" "$id" || true; }; fi
    return 0
}

tree_sync() { # <id>
    local id="$1" dir br how
    dir="$(tree_dir "$id")"; tree_clean "$dir" "$id" sync; br="$(shared_branch)"; how="$(cfg treeSync)"
    if [ "$how" = rebase ]; then git -C "$dir" rebase -q "$br" >/dev/null 2>&1
    else git -C "$dir" merge -q --no-edit "$br" >/dev/null 2>&1; fi && {
        echo "tree: $br brought into task/$id ($how) — test there, then hand off"; return 0; }
    echo "tree: conflicts bringing $br into task/$id ($how), in:"
    git -C "$dir" diff --name-only --diff-filter=U | sed 's/^/  /'
    if [ "$how" = rebase ]; then echo "resolve them in $dir, git add <paths>, git rebase --continue; test; then sync again"
    else echo "resolve them in $dir, git add <paths>, git commit --no-edit; test; then sync again"; fi
    return 1
}

tree_remove() { # <id>
    local id="$1" dir
    dir="$(tree_dir "$id")"; tree_clean "$dir" "$id" remove
    tree_merged "$id" || die "task/$id is not merged into $(shared_branch) — the coordinator merges it first (crew tree merge $id)"
    git -C "$ROOT" worktree remove --force "$dir" || die "git worktree remove $dir failed"
    git -C "$ROOT" branch -q -d "task/$id" || die "git branch -d task/$id failed"
    with_lock tree _tree_set "$id" drop
    echo "tree: removed $dir and task/$id"
}

tree_merge() { # <id>
    local id="$1" dir br
    tree_coordinator merge; dir="$(tree_dir "$id")"; tree_clean "$dir" "$id" merge; br="$(shared_branch)"
    [ "$(git -C "$ROOT" symbolic-ref --short -q HEAD)" = "$br" ] || die "the main tree is not on $br"
    if [ "$(cfg committer)" = human-approved ]; then
        echo "tree: committer=human-approved — the user runs (or approves) exactly:"
        echo "  git -C $(printf %q "$ROOT") merge --no-ff --no-edit task/$id"
        echo "then: crew tree remove $id, and regenerate generated files (indexes, roadmaps) in the main tree"
        return 0
    fi
    git -C "$ROOT" merge -q --no-ff --no-edit "task/$id" >/dev/null 2>&1 || {
        git -C "$ROOT" merge --abort >/dev/null 2>&1
        die "task/$id does not merge cleanly into $br — nothing changed. The member brings $br in first: crew tree sync $id"; }
    echo "tree: merged task/$id into $br at $(git -C "$ROOT" rev-parse --short HEAD)"
    tree_remove "$id"
    echo "tree: now regenerate generated files (indexes, roadmaps) in the main tree, and land them"
}

tree_main() {
    local sub="${1:-}" id="${2:-}" ex
    crew_init; need_active
    [ -n "$id" ] || die "tree new|sync|merge|remove|allow|revoke <task-id>"
    case "$sub" in
        new)    tree_new "$id" ;;
        sync)   tree_sync "$id" ;;
        merge)  with_lock apply tree_merge "$id" ;;
        remove) tree_remove "$id" ;;
        allow|revoke)
                tree_coordinator "$sub"; valid_name "$id" || die "a task id: letters, digits, . _ -"
                if [ "$sub" = allow ]; then with_lock tree _tree_set "$id" add; else with_lock tree _tree_set "$id" drop; fi
                ex="$(tree_exceptions)"
                echo "tree: exceptions under tree=$(cfg tree): ${ex:-none}" ;;
        *) die "tree new|sync|merge|remove|allow|revoke <task-id>" ;;
    esac
}

if is_main; then set -euo pipefail; tree_main "$@"; fi
