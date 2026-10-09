#!/usr/bin/env bash
# Work in a copy, land with a merge-or-refuse apply. Unfinished or failing work never sits in the
# shared tree, where it would fail every other session's checks.
#
# A copy is a `git clone --shared` of the shared repo at a named commit (no worktree, no branch):
# it sees every new commit through git's alternates, has its own private index, and records its
# base in <copy>/.git/crew-copy. Every file decision goes through ONE function, resolve3, used by
# both `apply` (copy → tree) and `rebase` (tree's new HEAD → copy).
# help: copy new <dir> [--at COMMIT] — make a copy at a named commit (default HEAD)
# help: copy status <dir> — files the copy changed against its base
# help: copy rebase <dir> [--ours <path...>] — move the copy onto the commit the tree is on now (merge or refuse); --ours: conflicts you resolved in the copy
# help: apply <dir> [path...] — land the copy into the shared tree: take, 3-way merge, or refuse all

[ -n "${CREW_LIB_DIR:-}" ] || . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"

copy_meta() { sed -n "s/^$2=//p" "$1/.git/crew-copy" 2>/dev/null | head -1; }
copy_check() { # <dir> — dies unless it is a copy of THIS repo
    [ -f "$1/.git/crew-copy" ] || die "$1 is not a crew copy (make one: copy new $1)"
    [ "$(copy_meta "$1" root)" = "$ROOT" ] || die "$1 is a copy of $(copy_meta "$1" root), not of $ROOT"
}

# copy_changes <dir> — every path the copy changed against its base, NUL-free, one per line
copy_changes() {
    local base; base="$(copy_meta "$1" base)"
    { git -C "$1" diff -z --name-only --no-renames "$base" --; git -C "$1" ls-files -z --others --exclude-standard; } \
        | tr '\0' '\n' | awk 'NF && !seen[$0]++'
}

# blob_at <commit> <path> <out> — the path's content at commit into out; returns 1 when absent
blob_at() { git -C "$ROOT" cat-file -e "$1:$2" 2>/dev/null || return 1; git -C "$ROOT" cat-file blob "$1:$2" > "$3"; }

same_file() { # <a|""> <b|""> — "" means absent
    [ -z "$1" ] && [ -z "$2" ] && return 0
    [ -n "$1" ] && [ -n "$2" ] && cmp -s "$1" "$2"
}
has_nul() { [ "$(tr -d '\000' < "$1" | wc -c)" -ne "$(wc -c < "$1")" ]; }

# resolve3 <target> <base> <incoming> <out> — each a file or "" (absent). Prints one decision:
#   same      target already equals incoming: nothing to do
#   take      target is still the base: incoming wins (out holds it, or the decision is "delete")
#   delete    as take, but incoming deleted the file
#   keep      incoming did not change it: target stays
#   merged    both changed it, a clean 3-way merge is in out
#   conflict  both changed it and they clash (or one side deleted, or binary)
resolve3() {
    local t="$1" b="$2" c="$3" out="$4"
    if same_file "$c" "$t"; then echo same; return; fi
    if same_file "$t" "$b"; then
        if [ -z "$c" ]; then echo delete; else cp "$c" "$out"; echo take; fi; return
    fi
    if same_file "$c" "$b"; then echo keep; return; fi
    if [ -z "$t" ] || [ -z "$b" ] || [ -z "$c" ] || has_nul "$t" || has_nul "$b" || has_nul "$c"; then echo conflict; return; fi
    if git merge-file -p -q "$t" "$b" "$c" > "$out" 2>/dev/null; then echo merged; else echo conflict; fi
}

copy_new() { # <dir> [--at commit]
    local dir="$1" at=HEAD sha; shift
    [ "${1:-}" = --at ] && at="${2:?--at COMMIT}"
    sha="$(git -C "$ROOT" rev-parse -q --verify "$at^{commit}")" || die "no such commit: $at"
    [ ! -e "$dir" ] || [ -z "$(ls -A "$dir" 2>/dev/null)" ] || die "$dir exists and is not empty"
    git clone -q --shared --no-checkout "$ROOT" "$dir" || die "clone into $dir failed"
    git -C "$dir" checkout -q --detach "$sha"
    printf 'base=%s\nroot=%s\nmade=%s\n' "$sha" "$ROOT" "$(now)" > "$dir/.git/crew-copy"
    echo "copy: $dir at $(git -C "$ROOT" rev-parse --short "$sha") — work and test there; land with: apply $dir"
}

copy_status() {
    local base n; base="$(copy_meta "$1" base)"; n="$(copy_changes "$1" | grep -c . || true)"
    echo "copy: $1 based on $(git -C "$ROOT" rev-parse --short "$base") (tree is at $(git -C "$ROOT" rev-parse --short HEAD)) · $n changed"
    copy_changes "$1" | sed 's/^/  /'
    [ "$base" = "$(git -C "$ROOT" rev-parse HEAD)" ] || echo "  (stale: rebase before applying — copy rebase $1)"
    return 0
}

# --- rebase: the tree's new HEAD into the copy ------------------------------------------------------
copy_rebase() { # <dir> [path...] — the paths are --ours: conflicts already resolved in the copy, kept as they are
    local dir="$1" old new f w d r t b c p n=0 bad=0 clash="" kept=""
    shift
    old="$(copy_meta "$dir" base)"; new="$(git -C "$ROOT" rev-parse HEAD)"
    [ "$old" != "$new" ] || { echo "copy: already on $(git -C "$ROOT" rev-parse --short "$new")"; return 0; }
    w="$(mktemp -d)"; CREW_ON_EXIT="rm -rf '$w'"
    while IFS= read -r f; do
        [ -n "$f" ] || continue                                 # an unchanged copy: one blank line
        n=$((n + 1)); d="$w/$n"; mkdir -p "$d"
        printf '%s\n' "$f" > "$d/path"
        [ -e "$dir/$f" ] && cp "$dir/$f" "$d/c" && c="$d/c" || c=""
        blob_at "$old" "$f" "$d/b" && b="$d/b" || b=""
        blob_at "$new" "$f" "$d/t" && t="$d/t" || t=""
        r="$(resolve3 "$t" "$b" "$c" "$d/out")"; echo "$r" > "$d/r"
        if [ "$r" = conflict ]; then
            for p in "$@"; do [ "$p" = "$f" ] && r=ours; done
            if [ "$r" = ours ]; then echo ours > "$d/r"; kept="$kept|$f|"; else echo "copy: rebase conflict in $f" >&2; bad=1; clash="$clash $(printf %q "$f")"; fi
        fi
    done <<EOF
$(copy_changes "$dir")
EOF
    [ "$bad" -eq 0 ] || {
        echo "copy: rebase refused — nothing changed. Resolve each conflict in the copy against $(git -C "$ROOT" rev-parse --short "$new") (its version: git -C $(printf %q "$dir") show $(git -C "$ROOT" rev-parse --short "$new"):<path>), then keep yours with: copy rebase $(printf %q "$dir") --ours$clash" >&2
        return 1; }
    git -C "$dir" checkout -q -f --detach "$new" || die "checkout of $new in $dir failed"
    for d in "$w"/*; do
        [ -f "$d/path" ] || continue
        f="$(cat "$d/path")"
        case "$(cat "$d/r")" in
            take|same) [ -f "$d/c" ] && { mkdir -p "$(dirname "$dir/$f")"; cp "$d/c" "$dir/$f"; } ;;
            merged)    mkdir -p "$(dirname "$dir/$f")"; cp "$d/out" "$dir/$f" ;;
            delete)    rm -f "$dir/$f" ;;
            ours)      if [ -f "$d/c" ]; then mkdir -p "$(dirname "$dir/$f")"; cp "$d/c" "$dir/$f"; else rm -f "$dir/$f"; fi
                       echo "copy: --ours: $f — the copy's version kept" ;;
            keep)      : ;;
        esac
    done
    for p in "$@"; do case "$kept" in *"|$p|"*) ;; *) echo "copy: --ours: $p — no conflict there, rebased as usual" ;; esac; done
    printf 'base=%s\nroot=%s\nmade=%s\n' "$new" "$ROOT" "$(copy_meta "$dir" made)" > "$dir/.git/crew-copy"
    echo "copy: rebased $dir onto $(git -C "$ROOT" rev-parse --short "$new") ($n changed files carried over)"
}

# --- apply: the copy into the shared tree --------------------------------------------------------
copy_apply() { # <me> <dir> [path...]
    local me="$1" dir="$2" base f w d r t c b n=0 bad=0 taken=0 merged=0 same=0 h chk
    shift 2
    base="$(copy_meta "$dir" base)"
    [ "$base" = "$(git -C "$ROOT" rev-parse HEAD)" ] || note "the copy is based on $(git -C "$ROOT" rev-parse --short "$base"), the tree is at $(git -C "$ROOT" rev-parse --short HEAD) — files peers changed are 3-way merged; rebase first to test against them"
    load_area holds
    w="$(mktemp -d)"; CREW_ON_EXIT="rm -rf '$w'"
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        if [ $# -gt 0 ]; then local want=0 p; for p in "$@"; do [ "$(rel_path "$p")" = "$f" ] && want=1; done; [ "$want" -eq 1 ] || continue; fi
        n=$((n + 1)); d="$w/$n"; mkdir -p "$d"; printf '%s\n' "$f" > "$d/path"
        if declare -F holder_of >/dev/null; then
            h="$(holder_of "$f")"
            if [ -n "$h" ] && [ "$h" != "$me" ]; then echo "  refused  $f — held by $h"; bad=1; continue; fi
            if [ -z "$h" ] && hot_spot "$f"; then echo "  refused  $f — hot spot, not held: hold $f"; bad=1; continue; fi
        fi
        [ -e "$dir/$f" ] && c="$dir/$f" || c=""
        blob_at "$base" "$f" "$d/b" && b="$d/b" || b=""
        [ -e "$ROOT/$f" ] && { cp "$ROOT/$f" "$d/t"; t="$d/t"; } || t=""
        r="$(resolve3 "$t" "$b" "$c" "$d/out")"; echo "$r" > "$d/r"
        case "$r" in
            conflict) echo "  refused  $f — changed in the tree and in the copy, and they clash"; bad=1 ;;
            same|keep) same=$((same + 1)) ;;
        esac
    done <<EOF
$(copy_changes "$dir")
EOF
    [ "$n" -gt 0 ] || { echo "apply: nothing to land"; return 0; }
    [ "$bad" -eq 0 ] || { echo "apply: REFUSED — nothing landed. Rebase the copy (copy rebase $dir), resolve there, apply again."; return 1; }

    # write: re-check each target is still what we merged against, keep the originals for undo
    local -a landed=()
    for d in "$w"/*; do
        [ -f "$d/path" ] || continue
        f="$(cat "$d/path")"; r="$(cat "$d/r")"
        case "$r" in same|keep) continue ;; esac
        if ! same_file "$( [ -f "$d/t" ] && echo "$d/t")" "$( [ -e "$ROOT/$f" ] && echo "$ROOT/$f")"; then
            echo "  refused  $f — changed in the tree while applying"; bad=1; break
        fi
        declare -F snapshot_save >/dev/null && snapshot_save "$me" "$f"
        mkdir -p "$(dirname "$ROOT/$f")"
        case "$r" in
            take)   cp "$d/out" "$ROOT/$f"; taken=$((taken + 1)) ;;
            merged) cp "$d/out" "$ROOT/$f"; merged=$((merged + 1)) ;;
            delete) rm -f "$ROOT/$f"; taken=$((taken + 1)) ;;
        esac
        echo "$f" >> "$w/written"; [ "$r" = delete ] || landed+=("$f")
    done
    chk="$(cfg landCheck)"
    if [ "$bad" -eq 0 ] && [ -n "$chk" ] && [ ${#landed[@]} -gt 0 ]; then
        echo "apply: landCheck: $chk …"
        (cd "$ROOT" && sh -c "$chk \"\$@\"" crew-landcheck "${landed[@]}") || { echo "  refused  — landCheck failed"; bad=1; }
    fi
    if [ "$bad" -ne 0 ]; then
        undo_writes "$w"
        echo "apply: REFUSED — the tree is back as it was."; return 1
    fi
    if [ -f "$w/written" ]; then
        local -a done_paths=(); while IFS= read -r f; do done_paths+=("$f"); done < "$w/written"
        claim_add "$me" "${done_paths[@]}"
    fi
    echo "apply: $taken taken, $merged merged, $same already there — landed in the shared tree; hand off: msg handoff"
}
undo_writes() { # <workdir> — put back every file written so far
    local d f
    [ -f "$1/written" ] || return 0
    for d in "$1"/*; do
        [ -f "$d/path" ] || continue; f="$(cat "$d/path")"
        grep -qxF -- "$f" "$1/written" || continue
        if [ -f "$d/t" ]; then cp "$d/t" "$ROOT/$f"; else rm -f "$ROOT/$f"; fi
    done
}

copy_main() {
    local sub="${1:-}" dir p; [ $# -gt 0 ] && shift
    crew_init
    case "$sub" in
        new)    [ -n "${1:-}" ] || die "copy new <dir> [--at COMMIT]"; copy_new "$@" ;;
        status) copy_check "${1:?copy status <dir>}"; copy_status "$1" ;;
        rebase) dir="${1:?copy rebase <dir> [--ours <path...>]}"; shift; copy_check "$dir"
                case "${1:-}" in --ours) shift; [ $# -gt 0 ] || die "--ours needs the paths you resolved" ;; "") ;; *) die "copy rebase <dir> [--ours <path...>]" ;; esac
                local -a ours=(); for p in "$@"; do ours+=("$(rel_path "$p")"); done
                copy_rebase "$dir" ${ours[@]+"${ours[@]}"} ;;
        apply)  need_active; dir="${1:?apply <dir> [path...]}"; shift; copy_check "$dir"
                with_lock apply copy_apply "$(me)" "$dir" "$@" ;;
        *) die "copy new|status|rebase <dir>, or apply <dir>" ;;
    esac
}

if is_main; then set -euo pipefail; copy_main "$@"; fi
