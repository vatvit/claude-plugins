#!/usr/bin/env bash
# Durable mailbox: the file copy of every `msg … --send`, so a dropped SendMessage loses nothing.
# $STATE/mail/<name>/new/<id> is unread, …/cur/<id> read; <id> is a zero-padded crew-wide sequence
# ($STATE/mail/seq), so a directory listing is oldest first. A message file is `key=value` lines
# (id from to kind at), a blank line, then the message as printed. …/<name>/held lists the ids a
# Stop has already been held for.
#
# The hooks' fast path cannot map a session id to a name without forking, so sending also leaves a
# marker $STATE/unread/<sid> for each recipient's session. A hook that finds no marker for its
# session exits on builtins alone (fast.sh: crew_fast_unread); the slow path removes a stale one.
#
# Sourced (by msg, status, whoami and the hooks): mail_send, mail_arm, mail_notice, mail_stop, ….
# Executed (via crew.sh): the CLI below.
# help: inbox [--all] — unread crew mail, oldest first, then marked read (--all: read mail too)
# help: inbox --ack <id> — mark one message read without showing it

[ -n "${CREW_LIB_DIR:-}" ] || . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"

mail_box() { echo "$STATE/mail/$1"; }
mail_ids() { # <name> [new|cur] — ids, oldest first (a glob sorts; no fork)
    local f
    for f in "$STATE/mail/$1/${2:-new}"/*; do [ -f "$f" ] && echo "${f##*/}"; done
    return 0
}
mail_count() { # <name> -> unread count, no fork
    local f n=0
    for f in "$STATE/mail/$1/new"/*; do [ -f "$f" ] && n=$((n + 1)); done
    echo "$n"
}
mail_field() { sed -n "s/^$2=//p;/^\$/q" "$1" | head -1; }   # <file> <key> — from the header only

# mail_arm <name> [sid] — leave the fast-path marker for the session behind <name> when it has mail
mail_arm() {
    local sid="${2:-$(sess_get "$1" sid)}"
    [ -n "$sid" ] || return 0
    case "$sid" in */*) return 0 ;; esac
    if [ "$(mail_count "$1")" -gt 0 ]; then mkdir -p "$STATE/unread" && : > "$STATE/unread/$sid"
    else rm -f "$STATE/unread/$sid"; fi
    return 0
}

# --- sending ---------------------------------------------------------------------------------------
_mail_send() { # <from> <to> <kind> <body file>; sets MAIL_TO (who got it)
    local seq=0 id r list
    [ -f "$STATE/mail/seq" ] && seq="$(cat "$STATE/mail/seq")"
    seq=$((seq + 1)); id="$(printf '%06d' "$seq")"
    echo "$seq" | replace_file "$STATE/mail/seq"
    if [ "$2" = all ]; then list="$(sess_names | grep -v -x -- "$1" || true)"; else list="$2"; fi
    MAIL_TO=""
    for r in $list; do
        mkdir -p "$STATE/mail/$r/new" "$STATE/mail/$r/cur"
        { printf 'id=%s\nfrom=%s\nto=%s\nkind=%s\nat=%s\n\n' "$id" "$1" "$2" "$3" "$(now)"; cat "$4"; } \
            | replace_file "$STATE/mail/$r/new/$id"
        mail_arm "$r"
        MAIL_TO="$MAIL_TO${MAIL_TO:+ }$r"
    done
}
# mail_send <from> <to|all> <kind> — the message on stdin goes to <to>'s box (every other session's
# for all). A recipient who has not joined yet finds it when they do (whoami arms the marker).
mail_send() {
    local body="$STATE/mail/body.$$" to
    to="$(name_for "$2")"                       # a display name ("Max Coordinator") → its slug
    valid_name "$to" || die "cannot mail '$2': not a crew name"
    mkdir -p "$STATE/mail"; cat > "$body"
    with_lock mail _mail_send "$1" "$to" "$3" "$body"
    rm -f "$body"
    [ "$to" = all ] || [ -f "$STATE/sessions/$to" ] || note "$2 has not joined: the mail waits for them"
    return 0
}

# --- hooks -----------------------------------------------------------------------------------------
mail_json() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
mail_line() { # <name> <n> — the one-line notice
    echo "crew: $2 unread crew message$([ "$2" -eq 1 ] || echo s) — read before going on: $(prefix_for "$1") inbox"
}
# mail_notice <name> <sid> — PostToolUse: additionalContext while there is unread mail
mail_notice() {
    local n
    [ -n "$1" ] || { rm -f "$STATE/unread/$2"; return 0; }
    n="$(mail_count "$1")"
    [ "$n" -gt 0 ] || { rm -f "$STATE/unread/$2"; return 0; }
    printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$(mail_json "$(mail_line "$1" "$n")")"
}
# mail_start <name> <sid> — SessionStart: the notice line, and the marker for this (maybe new) sid
mail_start() {
    local n
    [ -n "$1" ] || return 0
    mail_arm "$1" "$2"
    n="$(mail_count "$1")"
    [ "$n" -gt 0 ] && mail_line "$1" "$n"
    return 0
}
# mail_stop <name> <sid> — Stop: hold the stop once per unread message (hookMode=warn: only warn)
mail_stop() {
    local held new id r
    [ -n "$1" ] || { rm -f "$STATE/unread/$2"; return 0; }
    held="$STATE/mail/$1/held"; new=""
    for id in $(mail_ids "$1"); do grep -q -x "$id" "$held" 2>/dev/null || new="$new $id"; done
    [ "$(mail_count "$1")" -gt 0 ] || { rm -f "$STATE/unread/$2"; return 0; }
    [ -n "$new" ] || return 0
    printf '%s\n' $new >> "$held"
    r="$(mail_json "$(mail_line "$1" "$(mail_count "$1")") — a hand-off may be waiting on you")"
    if [ "$(cfg hookMode)" = warn ]; then printf '{"systemMessage":"%s"}\n' "$r"
    else printf '{"decision":"block","reason":"%s"}\n' "$r"; fi
}

# mail_status — status part: "mail: s1 2 unread (oldest 14:05) · s3 1 unread (…)"
mail_status() {
    local n c out="" first
    for n in $(sess_names); do
        c="$(mail_count "$n")"; [ "$c" -gt 0 ] || continue
        first="$(mail_ids "$n" | head -1)"
        out="$out${out:+ · }$n $c unread (oldest $(hhmm "$(mail_field "$STATE/mail/$n/new/$first" at)"))"
    done
    [ -z "$out" ] || echo "mail: $out"
}

# --- CLI -------------------------------------------------------------------------------------------
mail_show() { # <file> — a header line, then the message
    printf -- '── #%s · %s · from %s\n' "$((10#$(mail_field "$1" id)))" "$(hhmm "$(mail_field "$1" at)")" "$(mail_field "$1" from)"
    sed '1,/^$/d' "$1"
}
_mail_read() { # <name> <id...> — new → cur
    local n="$1" id; shift
    for id in "$@"; do [ -f "$STATE/mail/$n/new/$id" ] && mv "$STATE/mail/$n/new/$id" "$STATE/mail/$n/cur/$id"; done
    mail_arm "$n"
}
inbox_main() {
    crew_init; need_active
    local me id ids all=0
    me="$(me)"
    case "${1:-}" in
        --ack)
            case "${2:-}" in ''|*[!0-9]*) die "inbox --ack <id> (the number after #)" ;; esac
            id="$(printf '%06d' "$((10#$2))")"
            [ -f "$STATE/mail/$me/new/$id" ] || die "no unread message #$2 for $me"
            with_lock mail _mail_read "$me" "$id"
            echo "inbox: #$((10#$id)) marked read"; return 0 ;;
        --all) all=1 ;;
        '') ;;
        *) die "unknown argument: $1 — inbox [--all] | inbox --ack <id>" ;;
    esac
    if [ "$all" -eq 1 ]; then
        for id in $(mail_ids "$me" cur); do mail_show "$STATE/mail/$me/cur/$id"; echo; done
    fi
    ids="$(mail_ids "$me")"
    if [ -z "$ids" ]; then echo "inbox: no unread mail for $me"; return 0; fi
    echo "inbox: $(echo "$ids" | grep -c .) unread for $me, oldest first"
    for id in $ids; do mail_show "$STATE/mail/$me/new/$id"; echo; done
    # shellcheck disable=SC2086
    with_lock mail _mail_read "$me" $ids
}

if is_main; then set -euo pipefail; inbox_main "$@"; fi
