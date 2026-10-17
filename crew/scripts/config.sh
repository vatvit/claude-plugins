#!/usr/bin/env bash
# Effective config, one key per line with the layer it came from; set / unset one key in a layer.
# help: config — effective settings and where each comes from (project > user > default)
# help: config set [--user] <key> <value...> — write a key to .crew.json (or the user file); hotSpots, taskPush and treeLink take several
# help: config unset [--user] <key> — remove a key from .crew.json (or the user file)
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
crew_init

config_show() {
    local k v src
    for k in $CREW_KEYS; do
        v="$(cfg "$k" | paste -sd, -)"; src="$(cfg_src "$k")"
        [ "$k" = sharedBranch ] && [ "$src" = default ] && v="$(shared_branch)" && src="default: the checked-out branch"
        printf '%s=%s (%s)\n' "$k" "$v" "$src"
        if cfg_project_only "$k" && [ -n "$(cfg_layer user "$k")" ]; then
            echo "  note: $k in $CREW_USER_CONFIG is ignored — it only makes sense per project (.crew.json)"
        fi
    done
}

# key_type <key> — how a key is written: a (array of strings), n (number), s (string)
key_type() {
    case "$1" in
        hotSpots|taskPush|treeLink) echo a ;; snapshotKeep|snapshotMaxKB|slotGraceMin) echo n ;; *) echo s ;;
    esac
}

# check_value <key> <value...> — dies unless the values suit the key
check_value() {
    local k="$1" v; shift
    [ $# -gt 0 ] || die "config set $k needs a value (to remove it: config unset $k)"
    [ "$(key_type "$k")" = a ] || [ $# -eq 1 ] || die "$k takes one value; only hotSpots, taskPush and treeLink take several"
    for v in "$@"; do
        case "$v" in '') die "empty value for $k (to remove it: config unset $k)" ;;
                     *[\"\\]*) die "$k: a value cannot contain \" or \\ (put such a command in a script)" ;; esac
    done
    case "$k" in
        committer) case "$1" in coordinator|each-session|human-approved) ;; *) die "committer is coordinator, each-session or human-approved" ;; esac ;;
        push) case "$1" in committer|human) ;; *) die "push is committer or human" ;; esac ;;
        hookMode) case "$1" in deny|warn) ;; *) die "hookMode is deny or warn" ;; esac ;;
        tree) case "$1" in shared|worktrees) ;; *) die "tree is shared or worktrees" ;; esac ;;
        treeSync) case "$1" in merge|rebase) ;; *) die "treeSync is merge or rebase" ;; esac ;;
        treeLink|crewRules) for v in "$@"; do crew_link_ok "$v" || die "$k takes paths inside the main tree (relative, no ..): $v"; done ;;
        taskPush) for v in "$@"; do valid_name "$v" || die "taskPush takes crew names: $v is not one"; done ;;
    esac
    if [ "$(key_type "$k")" = n ]; then case "$1" in *[!0-9]*) die "$k is a whole number" ;; esac; fi
    return 0
}

# write_layer <file> <layer> <key> [value...] — the layer with <key> replaced (no value: removed).
# Re-emits every key of that layer as typed JSON; a key crew does not know keeps a string, number
# or array shape (true/false/null stay bare).
write_layer() {
    local f="$1" layer="$2" key="$3" l k v t hit=0
    shift 3
    cfg_load                                    # re-read under the lock: a concurrent set is not lost
    emit() { # <key> <type> <values joined by \037>
        local out=""
        case "$2" in
            a) out="[$(printf '%s' "$3" | awk 'BEGIN { RS = "\037" } { printf "%s\"%s\"", (NR > 1 ? ", " : ""), $0 }')]" ;;
            n) out="$3" ;;
            *) out="\"$3\"" ;;
        esac
        printf '  "%s": %s' "$1" "$out"
    }
    {
        echo "{"
        local sep="" joined
        while IFS=$'\t' read -r l k v; do
            [ "$l" = "$layer" ] || continue
            if [ "$k" = "$key" ]; then
                hit=1; [ $# -gt 0 ] || continue
                joined="$(printf '%s\037' "$@")"; v="${joined%$'\037'}"; t="$(key_type "$k")"
            else
                t="$(key_type "$k")"
                case " $CREW_KEYS " in *" $k "*) ;; *)
                    case "$v" in *$'\037'*) t=a ;; true|false|null) t=n ;; *[!0-9.-]*|'') t=s ;; *) t=n ;; esac ;;
                esac
            fi
            printf '%s' "$sep"; emit "$k" "$t" "$v"; sep=$',\n'
        done <<EOF_CFG
${CREW_CFG:-}
EOF_CFG
        if [ "$hit" -eq 0 ] && [ $# -gt 0 ]; then
            joined="$(printf '%s\037' "$@")"
            printf '%s' "$sep"; emit "$key" "$(key_type "$key")" "${joined%$'\037'}"; sep=$',\n'
        fi
        [ -z "$sep" ] || echo
        echo "}"
    } | replace_file "$f"
}

# locked <cmd...> — under the config lock when a crew exists; never creates crew/ (that would switch crew on)
locked() { if crew_active; then with_lock config "$@"; else "$@"; fi; }

config_write() { # set|unset [--user] <key> [value...]
    local op="$1" layer=project f; shift
    [ "${1:-}" = --user ] && { layer=user; shift; }
    local key="${1:-}"; [ $# -gt 0 ] && shift
    [ -n "$key" ] || die "config $op [--user] <key> [value...]"
    case " $CREW_KEYS " in *" $key "*) ;; *) die "unknown key: $key (keys: $CREW_KEYS)" ;; esac
    if [ "$layer" = user ] && cfg_project_only "$key"; then
        die "$key is project-only: it means nothing across projects, so it goes in .crew.json (drop --user)"
    fi
    [ "$op" = unset ] || check_value "$key" "$@"
    if [ "$layer" = user ]; then f="$CREW_USER_CONFIG"; mkdir -p "$(dirname "$f")"; else f="$ROOT/.crew.json"; fi
    if [ "$op" = unset ]; then
        [ -n "$(cfg_layer "$layer" "$key")" ] || { echo "config: $key is not set in $f"; return 0; }
        locked write_layer "$f" "$layer" "$key"
    else
        locked write_layer "$f" "$layer" "$key" "$@"
    fi
    cfg_load
    echo "config: $(config_show | grep "^$key=")  — $f"
}

case "${1:-}" in
    '') config_show ;;
    set|unset) config_write "$@" ;;
    *) die "config [set|unset [--user] <key> [value...]]" ;;
esac
