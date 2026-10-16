#!/usr/bin/env bash
# One committer and a safe shared index.
#
# land: commit exactly a reviewed path list, after checking it against what is dirty.
# git_guard (sourced by the pre-bash hook): deny git commands that act on the whole index or tree,
# move the branch under everyone, or commit / push against the committer and push modes.
# help: land --msg-file F [--] <path...> — commit exactly these paths (checks them against git status)
# help: land prepush — what a push would publish, and whether a quiet slot holds pushes

[ -n "${CREW_LIB_DIR:-}" ] || . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"

# crew_pushes — the crew pushes only when the user said so (push=committer) and someone in it commits.
# By default (push=human) every push is the user's (PLUG-057).
crew_pushes() { [ "$(cfg push)" = committer ] && [ "$(cfg committer)" != human-approved ]; }

# --- git guard -----------------------------------------------------------------------------------
# guard_reason <name> <role> <git args...> — prints why the command is refused, nothing when allowed
guard_reason() {
    local n="$1" role="$2" sub a has_dd=0 i=0 committer br pre q
    shift 2
    while [ $# -gt 0 ]; do                      # git's own options before the subcommand
        case "$1" in
            -C|-c|--git-dir|--work-tree|--namespace) shift 2 ;;
            -*) shift ;;
            *) break ;;
        esac
    done
    sub="${1:-}"; [ $# -gt 0 ] && shift
    local -a args=(); for a in "$@"; do [ "$a" = -- ] && has_dd=1; args+=("$a"); done
    committer="$(cfg committer)"; br="$(shared_branch)"
    # with no coordinator, a hand-off goes to nobody: name the way out instead of a dead end
    local coord; coord="$(coordinator)"
    way_out() { echo "this crew has no coordinator: take the role (crew whoami ${n:-<name>} coordinator), or ask the user"; }
    pre="$(prefix_for "${n:-<name>}")"
    any() { local x p; for x in ${args[@]+"${args[@]}"}; do for p in "$@"; do
        # shellcheck disable=SC2254
        case "$x" in $p) return 0 ;; esac; done; done; return 1; }
    flag() { any "-[$1]*" "-[!-]*[$1]*"; }      # flag <letters> — one of them in a short-option cluster (-Av, -fdn)
    nonopt() { local x; for x in ${args[@]+"${args[@]}"}; do case "$x" in -*) ;; *) printf '%s\n' "$x" ;; esac; done; }
    instead() {                                 # what this caller does instead of staging or committing everything
        if [ "$committer" = each-session ]; then echo "land your own paths: $pre land --msg-file F -- <your paths>"
        elif [ "$role" = coordinator ]; then echo "land the exact paths: $pre land --msg-file F -- <paths>"
        elif [ -z "$coord" ]; then way_out
        else echo "hand off your paths ($pre msg handoff); the coordinator lands them"; fi
    }
    is_commit() { git -C "$ROOT" rev-parse -q --verify "$1^{commit}" >/dev/null 2>&1; }
    is_path() { [ -e "$ROOT/$1" ] || git -C "$ROOT" ls-files --error-unmatch -- "$1" >/dev/null 2>&1; }

    case "$sub" in
        add)
            any --dry-run || flag n && return 0                 # git add -n stages nothing
            any --all . ./ :/ ':/\*' '\*' --update --no-ignore-removal || flag Au && {
                echo "git add of everything stages other sessions' work too (the index is shared). Stage nothing yourself: $(instead)"; return; } ;;
        commit)
            any --all || flag a && { echo "git commit -a takes every session's changes. $(instead)"; return; }
            if [ "$committer" = coordinator ] && [ "$role" != coordinator ]; then
                if [ -z "$coord" ]; then echo "only the coordinator commits in this crew (committer=coordinator), and $(way_out)"; return; fi
                echo "only the coordinator commits in this crew (committer=coordinator). Hand off instead: $pre msg handoff"; return
            fi
            any --amend && [ "$role" != coordinator ] && { echo "--amend rewrites a commit the crew shares — ask the coordinator"; return; }
            [ "$has_dd" -eq 1 ] || { echo "commit an exact path list, checked against what is dirty: $pre land --msg-file F -- <paths> (or git commit -F F -- <paths>)"; return; } ;;
        stash)
            case "${args[0]:-}" in list|show) ;; *) echo "git stash takes every session's uncommitted work off the shared tree. Work in a copy instead ($pre copy new <dir>)"; return ;; esac ;;
        checkout)
            any . ./ :/ '\*' --force --orphan --detach --patch || flag fbBp && { echo "this checkout overwrites or moves the shared tree for every session. Undo your own file with: $pre snapshot restore <id> (snapshot log <path>), or git checkout -- <exact path>"; return; }
            if [ "$has_dd" -eq 0 ]; then
                a="$(nonopt | head -1)"
                if [ -n "$a" ] && [ "$a" != "$br" ] && is_commit "$a" && ! is_path "$a"; then
                    echo "switching to '$a' moves every session's tree off $br. One tree, one branch: stay on $br"; return
                fi
            fi ;;
        switch)
            a="$(nonopt | head -1)"
            [ "$a" = "$br" ] && ! { any --create --force-create --detach --orphan || flag cC; } || { echo "one tree, one branch: every session stays on $br (no switching, no feature branches)"; return; } ;;
        restore)
            any . ./ :/ '\*' && { echo "git restore of everything discards every session's changes. Restore your own path: git restore -- <exact path>, or $pre snapshot restore <id>"; return; } ;;
        reset)
            any --hard --keep --merge --soft && { echo "this reset moves the branch or wipes the tree for every session — ask the coordinator"; return; }
            a="$(nonopt | head -1)"
            [ -n "$a" ] || { echo "a bare git reset unstages the whole shared index. Name the path: git reset -- <exact path>"; return; }
            [ "$has_dd" -eq 0 ] && [ "$(nonopt | wc -l | tr -d ' ')" -eq 1 ] && is_commit "$a" && ! is_path "$a" && {
                echo "git reset $a moves the branch for every session — ask the coordinator"; return; } ;;
        clean)
            any --dry-run || flag n || { echo "git clean deletes other sessions' new files. Remove your own file by its exact path"; return; } ;;
        worktree)
            echo "no worktrees: crew sessions share one working tree on purpose, so collisions surface instead of hiding. Need isolation? $pre copy new <dir>"; return ;;
        branch)
            [ -z "$(nonopt)" ] && ! { any --delete --move --copy || flag dDmMcC; } || { echo "no feature branches: the crew works on $br only"; return; } ;;
        rebase|pull|merge|cherry-pick|revert|am)
            [ "$role" = coordinator ] || { echo "git $sub moves the shared branch and tree — the coordinator does that$([ -n "$coord" ] || echo ", and $(way_out)")"; return; } ;;
        push)
            crew_pushes || { echo "pushes are the user's in this project (push=$(cfg push), committer=$committer): show them what would go ($pre land prepush) and let them push. Only on the user's word: $pre config set push committer"; return; }
            if [ "$committer" = coordinator ] && [ "$role" != coordinator ]; then echo "the coordinator pushes in this crew$([ -n "$coord" ] || echo ", and $(way_out)")"; return; fi
            load_area slot
            q="$(declare -F slot_quiet_holder >/dev/null && slot_quiet_holder)"
            [ -z "$q" ] || [ "$q" = "$n" ] || { echo "$q is running a quiet slot (timing) — pushes wait: $pre slot clear && git push"; return; } ;;
    esac
    return 0
}

# git_guard <name> <command line> — called by the pre-bash hook; denies via hook_block (which exits)
git_guard() {
    local n="$1" seg role r w
    case "$2" in *git*) ;; *) return 0 ;; esac
    role="$(sess_get "$n" role)"; [ -n "$role" ] || role=worker
    # one segment per simple command; quotes dropped (good enough to see the flags)
    while IFS= read -r seg; do
        set -f; set -- $seg; set +f
        while [ $# -gt 0 ]; do
            case "$1" in *=*|sudo|command|env|time|nohup|exec|'('|'{') shift ;; *) break ;; esac
        done
        case "${1:-}" in git|*/git) shift ;; *) continue ;; esac
        r="$(guard_reason "$n" "$role" "$@")"
        [ -n "$r" ] && hook_block "$r"
    done <<EOF
$(printf '%s\n' "$2" | tr -d "\"'" | awk '{ gsub(/&&|\|\||[;|&()]/, "\n") } 1')
EOF
    return 0
}

# --- land ------------------------------------------------------------------------------------------
land_main() {
    local me mf="" mode coord p st h c sha bad=0
    local -a paths=() untracked=()
    crew_init; need_active
    if [ "${1:-}" = prepush ]; then
        local br; br="$(shared_branch)"
        echo "land: would push to origin/$br:"
        git -C "$ROOT" log --oneline "origin/$br..HEAD" 2>/dev/null | sed 's/^/  /' || echo "  (no origin/$br to compare with)"
        echo "land: match each commit above against what was verified; read the push output, not the pipe's exit status."
        crew_pushes || echo "land: pushes are the user's here (push=$(cfg push), committer=$(cfg committer)) — give them this list and let them push"
        load_area slot
        if declare -F slot_quiet_holder >/dev/null && [ -n "$(slot_quiet_holder)" ]; then echo "land: HOLD — $(slot_quiet_holder) runs a quiet slot"; return 1; fi
        return 0
    fi
    me="$(me)"; mode="$(cfg committer)"; coord="$(coordinator)"
    while [ $# -gt 0 ]; do
        case "$1" in
            --msg-file) mf="${2:-}"; shift 2 ;;
            --) shift; while [ $# -gt 0 ]; do paths+=("$(rel_path "$1")"); shift; done ;;
            -*) die "unknown option: $1" ;;
            *) paths+=("$(rel_path "$1")"); shift ;;
        esac
    done
    [ ${#paths[@]} -gt 0 ] || die "land --msg-file F -- <path...>"
    [ -n "$mf" ] && [ -s "$mf" ] || die "land needs a non-empty commit message file (--msg-file); one task, one slice, task id in it"
    [ "$mode" != coordinator ] || [ "$me" = "$coord" ] || die "only the coordinator ($coord) lands in this crew — hand off instead: msg handoff"

    load_area holds
    for p in "${paths[@]}"; do
        st="$(git -C "$ROOT" status --porcelain -- "$p")"
        if [ -z "$st" ]; then echo "  refused  $p — not dirty (already landed, or a wrong path?)"; bad=1; continue; fi
        case "$st" in '??'*) untracked+=("$p") ;; esac
        if declare -F holder_of >/dev/null; then
            h="$(holder_of "$p")"
            # the coordinator lands a holder's hand-off; anyone else must not land a peer's held file
            [ -z "$h" ] || [ "$h" = "$me" ] || [ "$me" = "$coord" ] || { echo "  refused  $p — held by $h"; bad=1; continue; }
        fi
        if [ "$mode" = each-session ]; then
            c="$(claimants "$p")"
            case ",$c," in ",,"|*",$me,"*) ;; *) echo "  refused  $p — touched by $c, not you (committer=each-session)"; bad=1 ;; esac
        fi
    done
    [ "$bad" -eq 0 ] || { echo "land: REFUSED — nothing committed"; return 1; }

    # everything dirty that this commit leaves behind, by owner — the coordinator reviews it
    dirty_owned | awk -F'\t' 'NR == FNR { want[$0] = 1; next } !($1 in want) { o = ($2 == "" ? "unclaimed" : $2); printf "  not landed: %s (%s)\n", $1, o }' \
        <(printf '%s\n' "${paths[@]}") - || true
    local staged; staged="$(git -C "$ROOT" diff --cached --name-only | awk 'NR == FNR { want[$0] = 1; next } !($0 in want)' <(printf '%s\n' "${paths[@]}") -)"
    [ -z "$staged" ] || printf '  staged by someone, not in this commit: %s\n' $staged

    if [ "$mode" = human-approved ]; then
        echo "land: checks passed. committer=human-approved — the user runs (or approves) exactly:"
        [ ${#untracked[@]} -eq 0 ] || echo "  git add -- $(printf '%q ' "${untracked[@]}")"
        echo "  git commit -F $(printf '%q' "$mf") -- $(printf '%q ' "${paths[@]}")"
        return 0
    fi
    [ ${#untracked[@]} -eq 0 ] || git -C "$ROOT" add -- "${untracked[@]}"
    git -C "$ROOT" commit -q -F "$mf" -- "${paths[@]}" || die "git commit failed — nothing landed"
    sha="$(git -C "$ROOT" rev-parse --short HEAD)"
    claim_drop "${paths[@]}"
    echo "land: $sha $(git -C "$ROOT" log -1 --format=%s) — ${#paths[@]} path(s)"
    if declare -F holder_of >/dev/null; then
        for p in "${paths[@]}"; do
            h="$(holder_of "$p")"
            [ -n "$h" ] && echo "  $h releases $p: $(prefix_for "$h") release $p --sha $sha"
        done
    fi
    if crew_pushes; then echo "land: post the sha to the crew; push after: land prepush"
    else echo "land: post the sha to the crew; the user pushes (push=$(cfg push)): land prepush shows them what would go"; fi
}

if is_main; then set -euo pipefail; land_main "$@"; fi
