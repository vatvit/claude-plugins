#!/usr/bin/env bash
# Snapshots: the content of a file just before each edit, so an overwritten edit can always be
# recovered. The pre-edit hook (and apply) call snapshot_save; nothing here ever blocks an edit.
#
# $STATE/snapshots/blobs/<git blob hash>  content, stored once however many times it recurs
# $STATE/snapshots/log                    TSV: id, epoch, session, path, hash, bytes
# Each path keeps its newest snapshotKeep entries; `prune` also deletes blobs nothing refers to.
# help: snapshot log <path> — the path's snapshots, newest first
# help: snapshot show <id> | diff <id> — a snapshot's content / its diff against the file now
# help: snapshot restore <id> — put a snapshot back (the current content is snapshotted first)
# help: snapshot prune — apply snapshotKeep and drop unreferenced blobs

[ -n "${CREW_LIB_DIR:-}" ] || . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"

SNAP=""   # set from STATE by snapshot_save / snapshot_main (STATE is unknown when sourced)

_snap_add() { # <name> <rel> <hash> <bytes> — append unless the path's newest entry has that hash
    local log="$SNAP/log" last id keep
    [ -f "$log" ] || : > "$log"
    last="$(awk -F'\t' -v p="$2" '($4 "") == p { h = $5 } END { print h }' "$log")"
    [ "$last" = "$3" ] && return 0
    id=$(( $(cat "$SNAP/seq" 2>/dev/null || echo 0) + 1 )); echo "$id" > "$SNAP/seq"
    keep="$(cfg snapshotKeep)"
    { cat "$log"; printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$(now)" "$1" "$2" "$3" "$4"; } \
        | awk -F'\t' -v p="$2" -v k="$keep" '{ l[NR] = $0; if (($4 "") == p) n++ ; pp[NR] = $4 }
            END { for (i = 1; i <= NR; i++) { if (pp[i] == p && n > k) { n--; continue } print l[i] } }' \
        | replace_file "$log"
}

# snapshot_save <name> <rel> — called before a write; silent unless it skips something
snapshot_save() {
    local f="$ROOT/$2" bytes h
    SNAP="$STATE/snapshots"
    [ -f "$f" ] || return 0
    bytes="$(wc -c < "$f" | tr -d ' ')"
    if [ "$bytes" -gt $(( $(cfg snapshotMaxKB) * 1024 )) ]; then note "not snapshotted (over snapshotMaxKB): $2"; return 0; fi
    if [ "$(tr -d '\000' < "$f" | wc -c | tr -d ' ')" -ne "$bytes" ]; then note "not snapshotted (binary): $2"; return 0; fi
    h="$(git hash-object "$f")" || return 0
    mkdir -p "$SNAP/blobs"
    [ -f "$SNAP/blobs/$h" ] || cp "$f" "$SNAP/blobs/$h"
    with_lock snapshots _snap_add "$1" "$2" "$h" "$bytes"
}

snap_row() { [ -f "$SNAP/log" ] && awk -F'\t' -v id="$1" '$1 == id' "$SNAP/log"; return 0; }
snap_field() { snap_row "$1" | cut -f"$2"; }

snapshot_log() {
    local p; p="$(rel_path "$1")"
    [ -f "$SNAP/log" ] && awk -F'\t' -v p="$p" '($4 "") == p' "$SNAP/log" | sort -t "$(printf '\t')" -k1,1nr \
        | while IFS=$'\t' read -r id t n _ h b; do printf '  #%s  %s  by %s  %s bytes\n' "$id" "$(fmt_epoch "$t" '%m-%d %H:%M:%S')" "$n" "$b"; done
    return 0
}

_snap_prune() {
    local keep log="$SNAP/log" h
    [ -f "$log" ] || return 0
    keep="$(cfg snapshotKeep)"
    sort -t "$(printf '\t')" -k1,1nr "$log" | awk -F'\t' -v k="$keep" '++n[$4] <= k' | sort -t "$(printf '\t')" -k1,1n | replace_file "$log"
    for h in "$SNAP"/blobs/*; do
        [ -f "$h" ] || continue
        awk -F'\t' -v h="$(basename "$h")" '($5 "") == h { f = 1; exit } END { exit !f }' "$log" || rm -f "$h"
    done
    echo "snapshot: kept the newest $keep per path; $(wc -l < "$log" | tr -d ' ') snapshots, $(ls "$SNAP/blobs" | wc -l | tr -d ' ') blobs"
}

snapshot_main() {
    local sub="${1:-}" id p h me; [ $# -gt 0 ] && shift
    crew_init; need_active
    SNAP="$STATE/snapshots"
    case "$sub" in
        log)  [ -n "${1:-}" ] || die "snapshot log <path>"; snapshot_log "$1" ;;
        show|diff|restore)
            id="${1:?snapshot $sub <id>}"; id="${id#\#}"
            p="$(snap_field "$id" 4)"; h="$(snap_field "$id" 5)"
            [ -n "$p" ] && [ -f "$SNAP/blobs/$h" ] || die "no snapshot #$id (snapshot log <path> lists them)"
            case "$sub" in
                show) cat "$SNAP/blobs/$h" ;;
                diff) diff -u "$SNAP/blobs/$h" "$ROOT/$p" || true ;;
                restore)
                    me="$(me)"
                    load_area holds
                    if declare -F holder_of >/dev/null; then
                        local hh; hh="$(holder_of "$p")"
                        [ -z "$hh" ] || [ "$hh" = "$me" ] || die "$p is held by $hh — ask them, or chain for it"
                    fi
                    snapshot_save "$me" "$p"
                    mkdir -p "$(dirname "$ROOT/$p")"; cp "$SNAP/blobs/$h" "$ROOT/$p"
                    claim_add "$me" "$p"
                    echo "snapshot: restored $p from #$id ($(fmt_epoch "$(snap_field "$id" 2)" '%H:%M:%S') by $(snap_field "$id" 3)); what it replaced is the newest snapshot now" ;;
            esac ;;
        prune) with_lock snapshots _snap_prune ;;
        *) die "snapshot log|show|diff|restore|prune" ;;
    esac
}

if is_main; then set -euo pipefail; snapshot_main "$@"; fi
