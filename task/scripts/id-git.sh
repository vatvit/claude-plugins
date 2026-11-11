#!/usr/bin/env bash
# The git id source (idSource: git). Source it, don't execute it.
#
# The counter lives on a dedicated branch of the remote (default `task-ids` on
# `origin`), one file per prefix: <PREFIX>.next-id, holding the next free number.
# A reservation is a commit built with plumbing (a temporary index, commit-tree)
# and pushed as <sha>:refs/heads/<branch>. The push is the compare-and-swap: when
# another clone moved the branch first it is rejected, and we fetch and retry.
# Nothing here touches the user's index, working tree, HEAD or local branches,
# and nothing is ever force-pushed.
#
# Remote, branch and prefix come from config: they are validated and used only as
# quoted values, never executed.

IDGIT_DEFAULT_REMOTE=origin
IDGIT_DEFAULT_BRANCH=task-ids

# idgit_git <repo> <git args...> — git in <repo>, never prompting for credentials.
idgit_git() {
    local repo="$1"; shift
    GIT_TERMINAL_PROMPT=0 git -C "$repo" "$@"
}

# idgit_net <repo> <git args...> — a git call that talks to the remote, within a
# deadline: TASK_ID_NET_TIMEOUT seconds (default 20, at most 100, anything else is
# ignored). On expiry git is killed and the status is 124. Its output goes through
# temp files, not pipes: a helper git started (ssh) may outlive the kill, and
# holding a pipe it would block the caller's $( ) until it exits. Before the call,
# the id lock (IDGIT_LOCK, set by allocate-id.sh) is touched, so a holder busy with
# the network never looks stale to a waiting session.
idgit_net() {
    local repo="$1" t="${TASK_ID_NET_TIMEOUT:-20}" out err pid ticks=0 rc
    shift
    case "$t" in ''|*[!0-9]*) t=20 ;; esac
    { [ "$t" -ge 1 ] && [ "$t" -le 100 ]; } || t=20
    [ -n "${IDGIT_LOCK:-}" ] && [ -d "$IDGIT_LOCK" ] && touch "$IDGIT_LOCK" 2>/dev/null
    out=$(mktemp) || return 1; err=$(mktemp) || { rm -f "$out"; return 1; }
    idgit_git "$repo" "$@" > "$out" 2> "$err" < /dev/null &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        if [ "$ticks" -ge $((t * 10)) ]; then
            kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
            echo "git $1: no answer from the remote within ${t}s" >> "$err"
            cat "$out"; cat "$err" >&2; rm -f "$out" "$err"
            return 124
        fi
        sleep 0.1; ticks=$((ticks + 1))
    done
    wait "$pid"; rc=$?
    cat "$out"; cat "$err" >&2; rm -f "$out" "$err"
    return "$rc"
}

# idgit_validate <remote> <branch> <prefix> -> 0, or a message on stderr and 1.
idgit_validate() {
    case "$1" in ''|-*|*[!A-Za-z0-9._-]*)
        echo "ERROR: invalid idRemote: '$1'" >&2; return 1 ;; esac
    case "$2" in -*) echo "ERROR: invalid idBranch: '$2'" >&2; return 1 ;; esac
    git check-ref-format "refs/heads/$2" 2>/dev/null || { echo "ERROR: invalid idBranch: '$2'" >&2; return 1; }
    case "$3" in ''|*[!A-Za-z0-9_-]*)
        echo "ERROR: invalid prefix for a counter file: '$3'" >&2; return 1 ;; esac
    return 0
}

# idgit_repo <tasksDir> -> the top level of the git repo holding it; 1 if none.
idgit_repo() {
    git -C "$1" rev-parse --show-toplevel 2>/dev/null
}

# idgit_cache_file <tasksDir> <prefix> -> the clone's cache file. It lives in the
# git *common* dir, so the main tree and every linked worktree share one cache.
idgit_cache_file() {
    local cd
    cd=$(git -C "$1" rev-parse --git-common-dir 2>/dev/null) || return 1
    cd=$(cd "$1" && cd "$cd" && pwd -P) || return 1
    printf '%s/task-ids/%s.cache\n' "$cd" "$2"
}

# idgit_cache_get <tasksDir> <prefix> -> the cached next id, or nothing.
idgit_cache_get() {
    local f
    f=$(idgit_cache_file "$1" "$2") || return 0
    [ -f "$f" ] || return 0
    sed -n 's/^nextId=\([0-9][0-9]*\)$/\1/p' "$f" | head -n 1
    return 0
}

# idgit_cache_list <tasksDir> <prefix> <pending|clash> -> the numbers under that
# key, space-separated. pending: allocated while the remote could not be used, not
# yet claimed on it. clash: pending ids the remote counter had already passed when
# they were synced, so another clone may hold them; kept until renumber.sh moves them.
idgit_cache_list() {
    local f
    f=$(idgit_cache_file "$1" "$2") || return 0
    [ -f "$f" ] || return 0
    sed -n "s/^$3=\\([0-9][0-9]*\\)\$/\\1/p" "$f" | tr '\n' ' ' | sed 's/ $//'
    return 0
}

# idgit_cache_save <tasksDir> <prefix> <nextId> <pending...> <clash...> — the whole
# cache, lists space-separated (each sorted and de-duplicated). Diff-guarded, tmp + mv.
idgit_cache_save() {
    local f tmp n
    f=$(idgit_cache_file "$1" "$2") || return 1
    mkdir -p "${f%/*}" || return 1
    tmp="$f.tmp.$$"
    {
        printf 'nextId=%s\n' "$3"
        for n in $(printf '%s\n' $4 | sort -n -u); do printf 'pending=%s\n' "$n"; done
        for n in $(printf '%s\n' $5 | sort -n -u); do printf 'clash=%s\n' "$n"; done
    } > "$tmp" || return 1
    if cmp -s "$tmp" "$f"; then rm -f "$tmp"; else mv "$tmp" "$f"; fi
}

# idgit_cache_set <tasksDir> <prefix> <n> — nextId only, the lists kept.
idgit_cache_set() {
    idgit_cache_save "$1" "$2" "$3" "$(idgit_cache_list "$1" "$2" pending)" "$(idgit_cache_list "$1" "$2" clash)"
}

# idgit_cache_forget <tasksDir> <prefix> <n> — drop <n> from pending and clash
# (renumber.sh moved that task away).
idgit_cache_forget() {
    local next p c x keep_p="" keep_c=""
    next=$(idgit_cache_get "$1" "$2"); [ -n "$next" ] || return 0
    p=$(idgit_cache_list "$1" "$2" pending); c=$(idgit_cache_list "$1" "$2" clash)
    for x in $p; do [ "$x" = "$3" ] || keep_p="$keep_p $x"; done
    for x in $c; do [ "$x" = "$3" ] || keep_c="$keep_c $x"; done
    idgit_cache_save "$1" "$2" "$next" "$keep_p" "$keep_c"
}

# idgit_probe <repo> <remote> <branch> -> ok | nobranch | noremote | unreachable
idgit_probe() {
    local rc
    idgit_git "$1" config --get "remote.$2.url" >/dev/null 2>&1 || { echo noremote; return 0; }
    idgit_net "$1" ls-remote --exit-code "$2" "refs/heads/$3" >/dev/null 2>&1; rc=$?
    case "$rc" in
        0) echo ok ;;
        2) echo nobranch ;;
        *) echo unreachable ;;
    esac
}

# idgit_fetch <repo> <remote> <branch> -> the remote branch's sha, or nothing when
# the remote has no such branch. Updates only refs/remotes/<remote>/<branch>.
idgit_fetch() {
    local tracking="refs/remotes/$2/$3"
    if idgit_net "$1" ls-remote --exit-code "$2" "refs/heads/$3" >/dev/null 2>&1; then
        idgit_net "$1" fetch -q "$2" "+refs/heads/$3:$tracking" >/dev/null 2>&1 || return 1
        idgit_git "$1" rev-parse -q --verify "$tracking^{commit}"
    else
        [ $? -eq 2 ] || return 1
        return 0
    fi
}

# idgit_read <repo> <sha> <prefix> -> the counter at <sha>, 0 when it has none.
idgit_read() {
    local v
    v=$(idgit_git "$1" show "$2:$3.next-id" 2>/dev/null | tr -d ' \r\n')
    case "$v" in ''|*[!0-9]*) echo 0 ;; *) echo "$((10#$v))" ;; esac
}

# idgit_push <repo> <remote> <branch> <base-sha|""> <prefix> <value> <message>
# Builds a commit equal to <base> with <PREFIX>.next-id set to <value> and pushes
# it. Every other file on the branch (other prefixes' counters) is kept.
idgit_push() {
    local repo="$1" remote="$2" branch="$3" base="$4" prefix="$5" value="$6" msg="$7"
    local idx blob tree commit rc
    # A nonce makes every reservation a different commit. Without it two clones
    # reserving the same number in the same second build byte-identical commits
    # (same tree, parent, message, author, time), and the second push is a no-op
    # "success": both get the id (git-source.test.sh, concurrent clones).
    msg="$msg

Reservation: $$.$RANDOM$RANDOM$RANDOM.$(date +%s)"
    idx=$(mktemp) || return 1
    rm -f "$idx"
    (
        export GIT_INDEX_FILE="$idx"
        if [ -n "$base" ]; then idgit_git "$repo" read-tree "$base" || exit 1
        else idgit_git "$repo" read-tree --empty || exit 1; fi
        blob=$(printf '%s\n' "$value" | idgit_git "$repo" hash-object -w --stdin) || exit 1
        idgit_git "$repo" update-index --add --cacheinfo "100644,$blob,$prefix.next-id" || exit 1
        idgit_git "$repo" write-tree
    ) > "$idx.tree"; rc=$?
    tree=$(cat "$idx.tree" 2>/dev/null); rm -f "$idx" "$idx.tree"
    [ "$rc" -eq 0 ] && [ -n "$tree" ] || return 1
    # A repo without an identity still allocates: a neutral author, for this commit only.
    if [ -z "$(idgit_git "$repo" config user.email 2>/dev/null)" ]; then
        export GIT_AUTHOR_NAME="task plugin" GIT_AUTHOR_EMAIL="task-plugin@localhost"
        export GIT_COMMITTER_NAME="task plugin" GIT_COMMITTER_EMAIL="task-plugin@localhost"
    fi
    if [ -n "$base" ]; then
        commit=$(printf '%s\n' "$msg" | idgit_git "$repo" commit-tree "$tree" -p "$base") || return 1
    else
        commit=$(printf '%s\n' "$msg" | idgit_git "$repo" commit-tree "$tree") || return 1
    fi
    IDGIT_PUSH_ERR=$(idgit_net "$repo" push -q "$remote" "$commit:refs/heads/$branch" 2>&1 >/dev/null) && return 0
    return $?
}

# idgit_reserve <repo> <remote> <branch> <prefix> <tasksDir> <floor> <count> <create-ok> [<pending>]
# Reserves <count> ids (0 = only make sure the counter is at least <floor>).
# <pending> (space-separated numbers allocated offline) are claimed in the same
# push: those at or above the remote counter raise it past them; those below it
# were passed by another clone and are printed as `clash=<n>`.
# Prints the reserved numbers, one per line, the clash= lines, then `next=<counter after>`.
# Ids start at max(remote counter, floor) and skip numbers whose task file exists.
# Returns 3 when the remote has no counter branch and <create-ok> is not 1;
# 1 on any other failure, with the reason on stderr.
idgit_reserve() {
    local repo="$1" remote="$2" branch="$3" prefix="$4" tdir="$5" floor="$6" count="$7" create="$8"
    local pending="${9:-}" tries="${TASK_ID_RETRIES:-5}" attempt=0 base cur cand picked last n next msg p clashes pmax rc
    case "$tries" in ''|*[!0-9]*) tries=5 ;; esac
    [ "$tries" -ge 1 ] || tries=1
    while [ "$attempt" -lt "$tries" ]; do
        attempt=$((attempt + 1))
        base=$(idgit_fetch "$repo" "$remote" "$branch") || { echo "ERROR: cannot fetch $remote/$branch" >&2; return 1; }
        if [ -z "$base" ] && [ "$create" != 1 ]; then return 3; fi
        cur=0; [ -n "$base" ] && cur=$(idgit_read "$repo" "$base" "$prefix")
        cand=$cur; [ "$floor" -gt "$cand" ] && cand=$floor
        clashes=""; pmax=0
        for p in $pending; do
            if [ "$p" -lt "$cur" ]; then clashes="${clashes}clash=$p
"; elif [ "$p" -gt "$pmax" ]; then pmax=$p; fi
        done
        [ "$pmax" -gt 0 ] && [ $((pmax + 1)) -gt "$cand" ] && cand=$((pmax + 1))
        picked=""; n=0; last=$((cand - 1))
        while [ "$n" -lt "$count" ]; do
            if [ ! -e "$tdir/$(printf '%s-%03d' "$prefix" "$cand").md" ]; then
                picked="$picked$cand
"; n=$((n + 1)); last=$cand
            fi
            cand=$((cand + 1))
        done
        if [ "$count" -eq 0 ]; then next=$cand; else next=$((last + 1)); fi
        # Already high enough, nothing to reserve: no push.
        if [ "$count" -eq 0 ] && [ -n "$base" ] && [ "$next" -le "$cur" ]; then
            printf '%s' "$clashes"; printf 'next=%s\n' "$cur"; return 0
        fi
        if [ "$count" -eq 0 ]; then msg="task-ids: $prefix counter at $next"
        elif [ "$count" -eq 1 ]; then msg="task-ids: allocate $(printf '%s-%03d' "$prefix" "$last")"
        else msg="task-ids: allocate $count ids up to $(printf '%s-%03d' "$prefix" "$last")"; fi
        IDGIT_PUSH_ERR=""
        idgit_push "$repo" "$remote" "$branch" "$base" "$prefix" "$next" "$msg"; rc=$?
        if [ "$rc" -eq 0 ]; then
            printf '%s' "$picked"; printf '%s' "$clashes"; printf 'next=%s\n' "$next"
            return 0
        fi
        # No answer in time: the push may still land later, so its numbers are spent.
        if [ "$rc" -eq 124 ]; then
            echo "ERROR: the push to $remote/$branch did not finish within ${TASK_ID_NET_TIMEOUT:-20}s; its numbers may be spent (a gap, never a duplicate). Try again." >&2
            return 1
        fi
        # Rejected. If the remote moved, someone allocated first: try again.
        # If it did not, the remote refuses us (rules, permissions): stop.
        if [ "$(idgit_fetch "$repo" "$remote" "$branch" 2>/dev/null)" = "$base" ]; then
            echo "ERROR: the push to $remote/$branch was refused and the branch did not move:" >&2
            [ -n "$IDGIT_PUSH_ERR" ] && printf '%s\n' "$IDGIT_PUSH_ERR" | sed 's/^/  /' >&2
            return 1
        fi
    done
    echo "ERROR: the push to $remote/$branch lost the race $tries times; try again" >&2
    return 1
}

# idgit_settle <tasksDir> <prefix> <reserve-output> — after a successful
# idgit_reserve that was handed the pending list: nothing is pending any more,
# clashes join the clash list (each one warned about on stderr), nextId follows
# the remote counter.
idgit_settle() {
    local next new c old_c
    next=$(printf '%s\n' "$3" | sed -n 's/^next=//p')
    new=$(printf '%s\n' "$3" | sed -n 's/^clash=//p' | tr '\n' ' ')
    old_c=$(idgit_cache_list "$1" "$2" clash)
    for c in $new; do
        echo "WARNING: $(printf '%s-%03d' "$2" "$c") was allocated while the remote could not be used, and another clone has since passed that number: two tasks may share it. Check the remote's tasks; if they clash, move this one with renumber.sh (references/renumber.md)." >&2
    done
    idgit_cache_save "$1" "$2" "$next" "" "$old_c $new"
}

# idgit_add_pending <tasksDir> <prefix> <nextId> <numbers...> — record ids
# allocated locally while idSource is git, to be claimed by the next push.
idgit_add_pending() {
    local td="$1" px="$2" next="$3"; shift 3
    idgit_cache_save "$td" "$px" "$next" "$(idgit_cache_list "$td" "$px" pending) $*" "$(idgit_cache_list "$td" "$px" clash)"
}

# idgit_local_only <repo> <remote> <tasksDir> <prefix> -> the numbers of this
# clone's task files that no branch of the remote has: tasks made here and never
# pushed. Run on a clone's first use of git ids (no cache yet) and by setup, so a
# clone switching over hands them to idgit_reserve as pending: claimed when the
# counter has not passed them, reported as a possible clash when it has. Fetches
# the remote first, so its branches are current; offline, the last fetch is used.
idgit_local_only() {
    local repo="$1" remote="$2" td="$3" px="$4" rel known ref f
    rel=$(git -C "$td" rev-parse --show-prefix 2>/dev/null) || return 0
    idgit_net "$repo" fetch -q "$remote" >/dev/null 2>&1 || true
    known=$(mktemp) || return 0
    for ref in $(idgit_git "$repo" for-each-ref --format='%(refname)' "refs/remotes/$remote/"); do
        idgit_git "$repo" ls-tree -r --name-only "$ref" -- "$rel" 2>/dev/null
    done | sort -u > "$known"
    for f in "$td/$px-"*.md; do
        [ -f "$f" ] || continue
        n=$(basename "$f" .md); n="${n#"$px"-}"
        case "$n" in ''|*[!0-9]*) continue ;; esac
        grep -qxF "$rel$(basename "$f")" "$known" || printf '%s\n' "$((10#$n))"
    done
    rm -f "$known"
    return 0
}
