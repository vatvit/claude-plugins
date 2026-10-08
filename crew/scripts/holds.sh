#!/usr/bin/env bash
# Hot-spot holds: one holder per file at a time, kept in a registry rather than in messages someone
# might miss. $STATE/holds is TSV: path, holder, since (epoch), task, chain (comma-separated names
# waiting, in order). $STATE/holds.log records each release: epoch, path, from, to, sha.
#
# Sourced (by the pre-edit hook, status, msg): defines holder_of, hot_spot, holds_guard.
# Executed (via crew.sh): the CLI below.
# help: hold <path...> [--task ID] — take a hold before editing a hot spot
# help: release <path...> --sha SHA | --unchanged — release after the green commit that landed it
# help: chain <path> [name...] — queue for a held path (default: yourself); passed on at release
# help: who [path] — list holds
# help: drop <path...> — coordinator: remove a hold whose holder is gone

[ -n "${CREW_LIB_DIR:-}" ] || . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"

holds_file() { echo "$STATE/holds"; }
hold_field() { # <path> <n> — field n of the hold on path (2 holder, 3 since, 4 task, 5 chain)
    [ -f "$STATE/holds" ] || return 0
    awk -F'\t' -v p="$1" -v n="$2" '$1 == p { print $n; exit }' "$STATE/holds"
}
holder_of() { hold_field "$1" 2; }

hot_spot() { # <rel path> — true when it matches a hotSpots glob
    local g
    while IFS= read -r g; do
        [ -n "$g" ] || continue
        # shellcheck disable=SC2254
        case "$1" in $g) return 0 ;; esac
    done <<EOF
$(cfg hotSpots)
EOF
    return 1
}

hold_desc() { # <path> — "s1 since 14:05 (PLUG-1), next: s2,s3"
    local h t c
    h="$(holder_of "$1")"; t="$(hold_field "$1" 4)"; c="$(hold_field "$1" 5)"
    printf '%s since %s%s%s\n' "$h" "$(hhmm "$(hold_field "$1" 3)")" "${t:+ ($t)}" "${c:+, next: $c}"
}

# holds_guard <name> <rel> — called by the pre-edit hook; denies via hook_block (which exits)
holds_guard() {
    local n="$1" p="$2" h pre
    h="$(holder_of "$p")"
    pre="$(prefix_for "${n:-<name>}")"
    if [ -n "$h" ] && [ "$h" != "$n" ]; then
        hook_block "$p is held by $(hold_desc "$p"). Don't edit it until it is released. Queue for it: $pre chain $p"
    fi
    if [ -z "$h" ] && hot_spot "$p"; then
        if [ -z "$n" ]; then hook_block "$p is a hot spot and this session has not joined the crew: bash $CREW_BIN whoami <name>, then hold it"; fi
        hook_block "$p is a hot spot: take the hold first, then edit: $pre hold $p"
    fi
    return 0
}

# --- mutations (all under the holds lock) --------------------------------------------------------
_set_hold() { # <path> <holder> <since> <task> <chain> — replace or add; empty holder removes
    local f="$STATE/holds"; [ -f "$f" ] || : > "$f"
    { awk -F'\t' -v p="$1" '$1 != p' "$f"; [ -n "$2" ] && printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; } \
        | replace_file "$f"
}

_hold() { # <me> <task> <path...>
    local me="$1" task="$2" p h rc=0; shift 2
    for p in "$@"; do
        h="$(holder_of "$p")"
        if [ -z "$h" ]; then _set_hold "$p" "$me" "$(now)" "$task" ""; echo "hold: $p — yours"
        elif [ "$h" = "$me" ]; then echo "hold: $p — already yours"
        else echo "hold: $p — REFUSED, held by $(hold_desc "$p"). Queue: $(prefix_for "$me") chain $p" >&2; rc=1
        fi
    done
    return $rc
}

_release() { # <me> <sha|-> <path...>
    local me="$1" sha="$2" p h c next rest coord at rc=0; shift 2
    coord="$(coordinator)"
    for p in "$@"; do
        h="$(holder_of "$p")"
        if [ -z "$h" ]; then echo "release: $p — not held" >&2; rc=1; continue; fi
        if [ "$h" != "$me" ] && [ "$me" != "$coord" ]; then echo "release: $p — REFUSED, held by $h, not you" >&2; rc=1; continue; fi
        if [ "$sha" = - ]; then
            if [ -n "$(git -C "$ROOT" status --porcelain -- "$p")" ]; then
                echo "release: $p — REFUSED, it has uncommitted changes; land them, then release with --sha" >&2; rc=1; continue
            fi
        elif [ -z "$(git -C "$ROOT" diff-tree --no-commit-id --name-only -r --root "$sha" -- "$p")" ]; then
            echo "release: $p — REFUSED, $sha did not touch it" >&2; rc=1; continue
        fi
        at="at $sha"; [ "$sha" = - ] && at="unchanged"
        c="$(hold_field "$p" 5)"; next="${c%%,*}"; rest=""; case "$c" in *,*) rest="${c#*,}" ;; esac
        if [ -n "$next" ]; then
            _set_hold "$p" "$next" "$(now)" "" "$rest"; echo "release: $p $at → now held by $next${rest:+ (then $rest)}"
        else
            _set_hold "$p" "" "" "" ""; echo "release: $p $at → free"
        fi
        printf '%s\t%s\t%s\t%s\t%s\n' "$(now)" "$p" "$h" "${next:--}" "$sha" >> "$STATE/holds.log"
    done
    return $rc
}

_chain() { # <path> <name...>
    local p="$1" h c n; shift
    h="$(holder_of "$p")"
    [ -n "$h" ] || { echo "chain: $p is not held — take it: hold $p" >&2; return 1; }
    c="$(hold_field "$p" 5)"
    for n in "$@"; do
        [ -f "$STATE/sessions/$n" ] || { echo "chain: '$n' is not in the crew" >&2; return 1; }
        [ "$n" = "$h" ] && continue
        case ",$c," in *",$n,"*) continue ;; esac
        c="$c${c:+,}$n"
    done
    _set_hold "$p" "$h" "$(hold_field "$p" 3)" "$(hold_field "$p" 4)" "$c"
    echo "chain: $p — $(hold_desc "$p")"
}

_drop() { local p; for p in "$@"; do _set_hold "$p" "" "" "" ""; echo "drop: $p — free"; done; }

holds_list() { # [path]
    [ -s "$STATE/holds" ] || { echo "holds: none"; return 0; }
    local p
    while IFS=$'\t' read -r p _; do
        [ -z "${1:-}" ] || [ "$1" = "$p" ] || continue
        echo "  $p — $(hold_desc "$p")"
    done < "$STATE/holds"
}

holds_main() {
    local cmd="$1" me task="" sha="" unchanged=0 a; shift
    crew_init; need_active
    local -a paths=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --task) task="${2:-}"; shift 2 ;;
            --sha) sha="${2:-}"; shift 2 ;;
            --unchanged) unchanged=1; shift ;;
            *) paths+=("$(rel_path "$1")"); shift ;;
        esac
    done
    case "$cmd" in
        who) holds_list "${paths[0]:-}"; return 0 ;;
    esac
    me="$(me)"
    case "$cmd" in
        hold)
            [ ${#paths[@]} -gt 0 ] || die "hold <path...>"
            with_lock holds _hold "$me" "$task" "${paths[@]}" ;;
        release)
            [ ${#paths[@]} -gt 0 ] || die "release <path...> --sha SHA | --unchanged"
            if [ "$unchanged" -eq 1 ]; then sha=-
            else
                [ -n "$sha" ] || die "release needs the sha of the green commit that landed it (--sha), or --unchanged"
                a="$(git -C "$ROOT" rev-parse -q --verify "$sha^{commit}")" || die "no such commit: $sha"
                git -C "$ROOT" merge-base --is-ancestor "$a" HEAD || die "$sha is not on the current branch"
                sha="$(git -C "$ROOT" rev-parse --short "$a")"
            fi
            with_lock holds _release "$me" "$sha" "${paths[@]}" ;;
        chain)
            [ ${#paths[@]} -gt 0 ] || die "chain <path> [name...]"
            local p="${paths[0]}"; local -a names=("${paths[@]:1}")
            [ ${#names[@]} -gt 0 ] || names=("$me")
            with_lock holds _chain "$p" "${names[@]}" ;;
        drop)
            [ "$me" = "$(coordinator)" ] || die "only the coordinator drops a hold (holder gone); the holder releases it"
            with_lock holds _drop "${paths[@]}" ;;
        *) die "unknown holds command: $cmd" ;;
    esac
}

if is_main; then set -euo pipefail; holds_main "$@"; fi
