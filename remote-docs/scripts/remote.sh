#!/usr/bin/env bash
# remote.sh — remote documents: cards for files that stay with a provider (Google Drive, Claude
# Artifacts) and are never copied into the repo as bytes. Only Claude talks to a provider, through
# its MCP or tool; no command here makes a network call.
#
#   status [root]               one record per remote card or local copy: state, place, file, card
#   check  [root]               every problem `status` finds; non-zero exit on any
#   list   [root]               every remote card, git-ignored ones too, with its publish and copy
#   stamp <card> <time>         record the provider's modified time the card was written from
#   gone <card>                 mark a card whose file left the provider (never deletes)
#   copy-stamp <card> <time>    record the provider version a local copy was written from
#   diff <dir> <listing.tsv>    a provider listing vs the attachment's cards: new / changed / gone
#   purpose <path> [root]       what a folder is for: purpose, writes, truth, scope, cards (PLUG-145)
#   purposes [root]             the same for every folder holding a `.source.md`
#   questions <dir> [root]      what is still to be asked once for an attachment folder (PLUG-146)
#   guard <card> <time>         before a write: READ-ONLY / STALE / PROPOSE / OK (PLUG-147)
#   repoint <card> <id> <url> <type> <time>   the card follows a converted file (PLUG-147)
#   pack <dir>                  an attachment's .source.md files and cards as one text, for Drive (PLUG-148)
#   unpack <text> <dir>         that text back into files, in an empty folder
#
# A remote card is `<name>.<provider>.md` (PLUG-112): Google Drive (`gdrive`) or a Claude Artifact
# (`artifact`, PLUG-141). The name alone classifies it. Default root is "docs". Moved out of
# docs-manager unchanged (PLUG-144); docs-manager still lists these cards with ☁ by their names.
set -euo pipefail

ROOT_DEFAULT="docs"
EXTERNAL_DIR="external"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

REMOTE_PROVIDERS="gdrive artifact"

# provider_data <provider> <field> — what differs between providers, and the only place it does
# (PLUG-141). Every other line of the remote-card code is the same for all of them.
#   container  the listing type of a container row (a Drive folder), which `diff` skips
#   keys       URL query parameters that are access secrets, never committed (an artifact's `sk=`)
# Prints nothing for a field a provider does not have.
provider_data() {
  case "$1:$2" in
    gdrive:container) echo application/vnd.google-apps.folder ;;
    artifact:keys)    echo sk ;;
  esac
  return 0
}

# remote_provider <path> -> the provider a remote card's name says, nothing for any other file
remote_provider() {
  local p
  for p in $REMOTE_PROVIDERS; do
    case "$1" in ?*."$p".md) echo "$p"; return 0 ;; esac
  done
  return 0
}

# is_remote_card <path> -> 0 if <path> is `<name>.<provider>.md` for a known provider
is_remote_card() {
  case "$1" in *.md) ;; *) return 1 ;; esac
  [ -n "$(remote_provider "$1")" ]
}

# has_access_key <card> -> 0 if the card holds a URL with one of its provider's key parameters,
# anywhere: the frontmatter or a link in the body
has_access_key() {
  local k
  for k in $(provider_data "$(remote_provider "$1")" keys); do
    grep -qE "[?&]$k=" "$1" && return 0
  done
  return 1
}

# is_remote_copy <path> -> 0 if <path> is `<name>.<provider>.local.md`: the local text copy of the
# remote card `<name>.<provider>.md` beside it (PLUG-115). Never a card, never a document.
is_remote_copy() {
  local p
  for p in $REMOTE_PROVIDERS; do
    case "$1" in ?*."$p".local.md) return 0 ;; esac
  done
  return 1
}

# list_remote_copies <dir> -> local copies under <dir>, git-ignored ones included (a copy the
# user keeps local-only must still be checked), sorted, one per line
list_remote_copies() {
  local f
  while IFS= read -r f; do
    [ -n "$f" ] && is_remote_copy "$f" && printf '%s\n' "$f"
  done <<EOF
$(RD_KEEP_IGNORED=1 docs_find "$1" "" -type f -name '*.local.md' | sort)
EOF
  return 0
}

# valid_rfc3339 <time> -> 0 if <time> is an RFC 3339 time: UTC (`Z`, as Drive reports it) or with
# an offset (`+01:00`). Only the shape is checked; times are compared as strings, never ordered.
valid_rfc3339() {
  printf '%s\n' "$1" | awk '!/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9](\.[0-9]+)?(Z|[+-][0-9][0-9]:[0-9][0-9])$/ { bad = 1 } END { exit bad }'
}

# list_remote_cards <dir> [maxdepth] -> remote cards under <dir>, sorted, one per line
list_remote_cards() {
  local f
  while IFS= read -r f; do
    [ -n "$f" ] && is_remote_card "$f" && printf '%s\n' "$f"
  done <<EOF
$(docs_find "$1" "${2:-}" -type f -name '*.md' | sort)
EOF
  return 0
}

# remote_place <root> <file> -> filed | unfiled | outside, the same placement docs-manager reports
# for a local external file
#   filed    under <root>/external/<topic>/
#   unfiled  at the top level of <root>/external/ — the drop zone
#   outside  anywhere else under <root>
remote_place() {
  local rel="${2#"$1"/}"
  case "$rel" in
    "$EXTERNAL_DIR"/*/*) echo filed ;;
    "$EXTERNAL_DIR"/*)   echo unfiled ;;
    *)                   echo outside ;;
  esac
}

# remote_status <root>
#
# One tab-separated record per remote card or local copy, for the skill and for `check`:
#
#   state<TAB>place<TAB>file<TAB>card
#
# state: remote (complete card; `file` is "-") | incomplete (no remote-id or remote-modified)
#        | gone (marked `remote-gone: yes`: its file left the provider; PLUG-113)
#        | keyed (an access key in a card outside a publish: local folder; PLUG-141)
#        | copy | copy-stale | copy-unstamped | copy-unasked | copy-orphan (a card's local text
#          copy, `file` is the copy: in step with the card, behind it, never stamped, not agreed
#          in `.source.md`, without a card; PLUG-115).
# An empty field is "-": tab is whitespace to `read`, so a truly empty field would collapse
# and shift the ones after it.
remote_status() {
  local root="$1" card
  while IFS= read -r card; do
    [ -n "$card" ] || continue
    if has_access_key "$card"; then
      if [ "$(src_val "$card" publish "$root")" != local ]; then
        printf 'keyed\t%s\t-\t%s\n' "$(remote_place "$root" "$card")" "$card"; continue
      fi
    fi
    if [ "$(fm_field "$card" remote-gone)" = yes ]; then
      printf 'gone\t%s\t-\t%s\n' "$(remote_place "$root" "$card")" "$card"
    elif [ -n "$(fm_field "$card" remote-id)" ] && [ -n "$(fm_field "$card" remote-modified)" ]; then
      printf 'remote\t%s\t-\t%s\n' "$(remote_place "$root" "$card")" "$card"
    else
      printf 'incomplete\t%s\t-\t%s\n' "$(remote_place "$root" "$card")" "$card"
    fi
  done <<EOF
$(list_remote_cards "$root")
EOF
  # Local copies (PLUG-115): compared with their card, never with Drive (scripts stay offline).
  local copy cm place state
  while IFS= read -r copy; do
    [ -n "$copy" ] || continue
    card="${copy%.local.md}.md"; place="$(remote_place "$root" "$copy")"
    if [ ! -f "$card" ]; then
      printf 'copy-orphan\t%s\t%s\t-\n' "$place" "$copy"; continue
    fi
    if [ "$(src_val "$card" processed "$root")" != local ]; then
      printf 'copy-unasked\t%s\t%s\t%s\n' "$place" "$copy" "$card"; continue
    fi
    cm="$(fm_field "$card" copy-modified)"
    if [ -z "$cm" ]; then state=copy-unstamped
    elif [ "$cm" != "$(fm_field "$card" remote-modified)" ]; then state=copy-stale
    else state=copy; fi
    printf '%s\t%s\t%s\t%s\n' "$state" "$place" "$copy" "$card"
  done <<EOF
$(list_remote_copies "$root")
EOF
  return 0
}

cmd_status() {
  local root="${1:-$ROOT_DEFAULT}"
  [ -d "$root" ] || { echo "No such root: $root" >&2; return 1; }
  remote_status "$root"
}

cmd_check() {
  local root="${1:-$ROOT_DEFAULT}" rc=0 state place f card
  [ -d "$root" ] || { echo "No such root: $root" >&2; return 1; }
  while IFS=$'\t' read -r state place f card; do
    case "$state" in
      incomplete) echo "REMOTE INCOMPLETE: $card (needs remote-id and remote-modified)"; rc=1 ;;
      gone)      echo "REMOTE GONE: $card (removed from its provider: delete the card, or restore the file)"; rc=1 ;;
      keyed)     echo "REMOTE KEY: $card (an access key in a committed card: strip it from every URL; only a publish: local folder may keep a keyed link, as remote-key-url)"; rc=1 ;;
      copy-stale)     echo "LOCAL COPY STALE: $f (the card is newer: rewrite it from the provider, then: remote.sh copy-stamp $card <time>)"; rc=1 ;;
      copy-unstamped) echo "LOCAL COPY UNSTAMPED: $f (run: remote.sh copy-stamp $card <time>)"; rc=1 ;;
      copy-unasked)   echo "LOCAL COPY NOT AGREED: $f (its .source.md does not say processed: local: ask the user, or delete it)"; rc=1 ;;
      copy-orphan)    echo "LOCAL COPY ORPHAN: $f (no card beside it)"; rc=1 ;;
    esac
  done <<EOF
$(remote_status "$root")
EOF
  source_check "$root" || rc=1
  [ "$rc" -eq 0 ] && echo "remote check: OK"
  return $rc
}

# stamp <card> <time> — record the provider's modifiedTime the card was written from.
# The only writer of `remote-modified:`, as docs-manager's `external stamp` is of `digest:`. The time comes from the
# provider through Claude (no command here makes a network call), so its shape is checked:
# RFC 3339 UTC, `YYYY-MM-DDTHH:MM:SS[.fff]Z`.
cmd_stamp() {
  local card="${1:-}" t="${2:-}"
  [ -n "$card" ] && [ -n "$t" ] || { echo "Usage: remote.sh stamp <remote-card> <rfc3339-time>" >&2; return 2; }
  is_remote_card "$card" || { echo "Not a remote card: $card" >&2; return 1; }
  [ -f "$card" ] || { echo "No such card: $card" >&2; return 1; }
  valid_rfc3339 "$t" || { echo "Not an RFC 3339 UTC time: $t" >&2; return 1; }
  # A card stamped again describes a file that is back on Drive: clear the gone mark
  # (only when set, so a card never marked gets no `remote-gone` key at all).
  if [ "$(fm_field "$card" remote-gone)" = yes ]; then
    fm_set "$card" remote-gone no
  elif [ "$(fm_field "$card" remote-modified)" = "$t" ]; then
    echo "UNCHANGED: $card"; return 0
  fi
  fm_set "$card" remote-modified "$t"
  echo "STAMPED: $card"
}

# copy-stamp <card> <time> — record that the card's local copy (`<name>.<provider>.local.md`) was
# written from the Drive version of <time> (PLUG-115). The only writer of `copy-modified:`. Refuses
# when the copy is missing or the card's `.source.md` does not say `processed: local`: a local copy
# goes against the plugin's default, so it exists only when the user agreed to it.
cmd_copy_stamp() {
  local card="${1:-}" t="${2:-}" copy
  [ -n "$card" ] && [ -n "$t" ] || { echo "Usage: remote.sh copy-stamp <remote-card> <rfc3339-time>" >&2; return 2; }
  is_remote_card "$card" || { echo "Not a remote card: $card" >&2; return 1; }
  [ -f "$card" ] || { echo "No such card: $card" >&2; return 1; }
  valid_rfc3339 "$t" || { echo "Not an RFC 3339 UTC time: $t" >&2; return 1; }
  copy="${card%.md}.local.md"
  [ -f "$copy" ] || { echo "No local copy: $copy" >&2; return 1; }
  [ "$(src_val "$card" processed /)" = local ] \
    || { echo "Not agreed: no .source.md above $card says processed: local" >&2; return 1; }
  if [ "$(fm_field "$card" copy-modified)" = "$t" ]; then echo "UNCHANGED: $card"; return 0; fi
  fm_set "$card" copy-modified "$t"
  echo "STAMPED: $card"
}

# gone <card> — mark a remote card whose file is no longer on Drive (or no longer in
# its attachment's scope). Never deletes: whether the card goes is the user's call, and
# `check` reports it until then.
cmd_gone() {
  local card="${1:-}"
  [ -n "$card" ] || { echo "Usage: remote.sh gone <remote-card>" >&2; return 2; }
  is_remote_card "$card" || { echo "Not a remote card: $card" >&2; return 1; }
  [ -f "$card" ] || { echo "No such card: $card" >&2; return 1; }
  if [ "$(fm_field "$card" remote-gone)" = yes ]; then
    echo "UNCHANGED: $card"; return 0
  fi
  fm_set "$card" remote-gone yes
  echo "MARKED GONE: $card"
}

# remote_in_scope <path> <recursive> <includes> <excludes> — 0 if a Drive listing path is in an
# attachment's scope. <includes>/<excludes> are newline-separated shell globs (`case` patterns,
# so `*` also matches `/`). No includes means everything; an exclude always wins.
remote_in_scope() {
  local p="$1" pat hit=no
  case "$2" in false|no) case "$p" in */*) return 1 ;; esac ;; esac
  [ -n "$3" ] || hit=yes
  while IFS= read -r pat; do
    [ -n "$pat" ] || continue
    case "$p" in $pat) hit=yes; break ;; esac
  done <<EOF
$3
EOF
  [ "$hit" = yes ] || return 1
  while IFS= read -r pat; do
    [ -n "$pat" ] || continue
    case "$p" in $pat) return 1 ;; esac
  done <<EOF
$4
EOF
  return 0
}

# diff_pointer <folder-id> <container-type> <rows> <cards> — `diff` for a `cards: pointer` attachment
# (PLUG-145): one card describes the whole folder, so files are never new or gone. The folder counts as
# changed when the newest in-scope time differs from the pointer card's `remote-modified`. "Newest" is
# the greatest time as a string, which only has to be the same on every run: it is compared for
# equality, never used to order two cards.
diff_pointer() {
  local latest pc pm pg
  latest="$(cut -f4 "$3" | LC_ALL=C sort | tail -n 1)"
  IFS=$'\t' read -r pc pm pg <<EOF
$(awk -F'\t' -v id="$1" '($1 "") == id { print $2 "\t" $3 "\t" $4; exit }' "$4")
EOF
  [ -n "$latest" ] || return 0
  if [ -z "$pc" ]; then
    printf 'new\t%s\t.\t%s\t%s\n' "$1" "${2:-folder}" "$latest"
  elif [ "$latest" != "$pm" ] || [ "$pg" = yes ]; then
    printf 'changed\t%s\t%s\t%s\n' "$1" "$pc" "$latest"
  fi
  return 0
}

# diff <attachment-dir> <listing.tsv> — compare a provider's listing, written by Claude
# through the provider's tool, with the attachment's remote cards (PLUG-113, PLUG-141). The listing
# is `id<TAB>path<TAB>type<TAB>modified` per item; container rows (Drive folders) are skipped. The
# attachment's `.source.md` says the provider (`provider:`, default gdrive) and, with `remote-id:`,
# the container it mirrors. Prints one record per difference, sorted; nothing means in sync:
#
#   new<TAB>id<TAB>path<TAB>type<TAB>modified    in scope in the container, no card
#   changed<TAB>id<TAB>card<TAB>modified         the provider's time differs from the card's
#   gone<TAB>id<TAB>card                         card whose file is gone or out of scope
#
# Without a container the cards were attached one by one (every artifact, a single Drive file):
# the listing may hold far more than the project uses, so only carded ids count and nothing is
# `new`. Only cards of the attachment's provider are compared.
#
# Files match cards by Drive id, so a rename or a move is not gone + new. Ids and times are
# compared as strings: an id can look like a number to awk, and `…11Z` / `…11.986Z` do not
# sort, so a time is only ever equal or not. A card already marked gone is not reported again,
# and is `changed` once its file is back, so stamping it clears the mark.
cmd_diff() {
  local dir="${1:-}" listing="${2:-}" src rec inc exc rows cards card id path mime mod prov box skip pointer
  [ -n "$dir" ] && [ -n "$listing" ] || { echo "Usage: remote.sh diff <attachment-dir> <listing.tsv>" >&2; return 2; }
  dir="${dir%/}"; src="$dir/.source.md"
  [ -f "$src" ] || { echo "No .source.md in $dir: not a remote attachment" >&2; return 1; }
  prov="$(fm_field "$src" provider)"; prov="${prov:-gdrive}"
  case " $REMOTE_PROVIDERS " in *" $prov "*) ;; *) echo "Unknown provider in $src: $prov" >&2; return 1 ;; esac
  box="$(fm_field "$src" remote-id)"; skip="$(provider_data "$prov" container)"
  [ -f "$listing" ] || { echo "No such listing: $listing" >&2; return 1; }
  awk -F'\t' 'NF == 0 { next }
    NF != 4 || $1 == "" { printf "Bad listing, line %d: want id<TAB>path<TAB>mimeType<TAB>modifiedTime\n", NR; bad = 1 }
    END { exit bad }' "$listing" >&2 || return 1
  rec="$(fm_field "$src" recursive)"; inc="$(fm_list "$src" include)"; exc="$(fm_list "$src" exclude)"
  pointer=no; [ "$(src_val "$dir" cards /)" = pointer ] && pointer=yes
  if [ "$pointer" = yes ] && [ -z "$box" ]; then
    echo "cards: pointer needs remote-id in $src: the folder its one card describes" >&2; return 1
  fi
  rows="$(mktemp)"; cards="$(mktemp)"
  while IFS=$'\t' read -r id path mime mod; do
    [ -n "$id" ] || continue
    [ -n "$skip" ] && [ "$mime" = "$skip" ] && continue
    [ -z "$box" ] || remote_in_scope "$path" "$rec" "$inc" "$exc" || continue
    printf '%s\t%s\t%s\t%s\n' "$id" "$path" "$mime" "$mod"
  done < "$listing" > "$rows"
  while IFS= read -r card; do
    [ -n "$card" ] || continue
    [ "$(remote_provider "$card")" = "$prov" ] || continue
    id="$(fm_field "$card" remote-id)"
    [ -n "$id" ] || continue          # incomplete: `check` reports it
    printf '%s\t%s\t%s\t%s\n' "$id" "$card" "$(fm_field "$card" remote-modified)" "$(fm_field "$card" remote-gone)"
  done > "$cards" <<EOF
$(RD_KEEP_IGNORED=1 list_remote_cards "$dir")
EOF
  if [ "$pointer" = yes ]; then
    diff_pointer "$box" "$skip" "$rows" "$cards"; rm -f "$rows" "$cards"; return 0
  fi
  # FILENAME, not FNR==NR: either input may be empty.
  awk -F'\t' -v OFS='\t' -v C="$cards" -v carded="$([ -n "$box" ] || echo 1)" '
    FILENAME == C { k = $1 ""; card[k] = $2; mod[k] = $3 ""; gone[k] = $4 ""; next }
    { k = $1 ""; seen[k] = 1
      if (!(k in card)) { if (!carded) print "new", k, $2, $3, $4 }
      else if (($4 "") != mod[k] || gone[k] == "yes") print "changed", k, card[k], $4 }
    END { for (k in card) if (!(k in seen) && gone[k] != "yes") print "gone", k, card[k] }
  ' "$cards" "$rows" | LC_ALL=C sort
  rm -f "$rows" "$cards"
  return 0
}

# --- .source.md: per-folder settings, resolved per key (PLUG-145) ---------------------------------
#
# A `.source.md` holds the answers for its folder and every folder below it. Each key is resolved on
# its own: the nearest `.source.md` from the folder up to <root> that sets it wins, so a sub-folder's
# file may set only `purpose:` and still take `publish:` or `provider:` from its parent (RF12, PP1e).
# A suggested purpose also sets the keys it implies (`purpose_default`), at its own level.

PURPOSES="reference agreements collaboration output"
SCOPES_DEFAULT="user project team company"

# purpose_default <purpose> <key> — what a suggested purpose implies; nothing for a custom one
purpose_default() {
  case "$1:$2" in
    reference:writes) echo never ;;       reference:truth) echo no ;;      reference:cards) echo files ;;
    agreements:writes) echo propose ;;    agreements:truth) echo yes ;;    agreements:cards) echo files ;;
    collaboration:writes) echo free ;;    collaboration:truth) echo no ;;  collaboration:cards) echo pointer ;;
    output:writes) echo free ;;           output:truth) echo no ;;         output:cards) echo files ;;
  esac
  return 0
}

is_suggested() { case " $PURPOSES " in *" $1 "*) return 0 ;; esac; return 1; }

# allowed <key> <value> -> 0 if <value> is valid for <key>; any value for a key not listed here
allowed() {
  case "$1" in
    writes) case "$2" in never|propose|free) return 0 ;; esac; return 1 ;;
    truth)  case "$2" in yes|no) return 0 ;; esac; return 1 ;;
    cards)  case "$2" in files|pointer) return 0 ;; esac; return 1 ;;
    cards-at) case "$2" in local|drive) return 0 ;; esac; return 1 ;;
  esac
  return 0
}

# src_key <path> <key> <root> -> value<TAB>file: the nearest `.source.md` from <path> (a folder, or a
# file whose folder is used) up to <root> that sets <key>, directly or through its suggested purpose.
# Prints nothing when none does.
src_key() {
  local d root="${3%/}" v f
  if [ -d "$1" ]; then d="${1%/}"; else d="$(dirname "$1")"; fi
  while :; do
    f="$d/.source.md"
    if [ -f "$f" ]; then
      v="$(fm_field "$f" "$2")"
      if [ -z "$v" ]; then
        case "$2" in writes|truth|cards) v="$(purpose_default "$(fm_field "$f" purpose)" "$2")" ;; esac
      fi
      if [ -n "$v" ]; then printf '%s\t%s\n' "$v" "$f"; return 0; fi
    fi
    [ "$d" = "$root" ] || [ "$d" = . ] || [ "$d" = / ] && return 0
    d="$(dirname "$d")"
  done
}

# src_val <path> <key> <root> -> the value alone
src_val() { src_key "$@" | cut -f1; }

# src_scopes <path> <root> -> the scope order in force, narrowest first, one per line
src_scopes() {
  local d root="${2%/}" l
  if [ -d "$1" ]; then d="${1%/}"; else d="$(dirname "$1")"; fi
  while :; do
    if [ -f "$d/.source.md" ]; then
      l="$(fm_list "$d/.source.md" scopes)"
      if [ -n "$l" ]; then printf '%s\n' "$l"; return 0; fi
    fi
    if [ "$d" = "$root" ] || [ "$d" = . ] || [ "$d" = / ]; then break; fi
    d="$(dirname "$d")"
  done
  printf '%s\n' $SCOPES_DEFAULT
}

# purpose_record <path> <root> -> purpose<TAB>writes<TAB>truth<TAB>scope<TAB>cards<TAB>declared-in
# With nothing declared: `-`, never, no, project, files, `-` (the fallback: read-only, not where
# decisions live, until the user says otherwise).
purpose_record() {
  local p decl w t sc c
  IFS=$'\t' read -r p decl <<EOF
$(src_key "$1" purpose "$2")
EOF
  w="$(src_val "$1" writes "$2")"; t="$(src_val "$1" truth "$2")"
  sc="$(src_val "$1" scope "$2")"; c="$(src_val "$1" cards "$2")"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "${p:--}" "${w:-never}" "${t:-no}" "${sc:-project}" "${c:-files}" "${decl:--}"
}

# source_dirs <root> -> every folder under <root> (itself included) holding a `.source.md`, git-ignored
# ones too, sorted. `.source.md` is a dot-file, which `docs_find` prunes, so folders are walked instead.
source_dirs() {
  local d
  { printf '%s\n' "${1%/}"; RD_KEEP_IGNORED=1 docs_find "$1" "" -type d; } | LC_ALL=C sort | while IFS= read -r d; do
    if [ -n "$d" ] && [ -f "$d/.source.md" ]; then printf '%s\n' "$d"; fi
  done
  return 0
}

# is_attachment <.source.md> -> 0 if it describes an attachment (not only defaults for folders below)
is_attachment() {
  [ -n "$(fm_field "$1" provider)$(fm_field "$1" remote-id)$(fm_field "$1" publish)" ]
}

# source_check <root> — the settings problems, one line each; returns 1 on any failure.
# PURPOSE? is a note, never a failure: an attachment made before purposes existed must not fail.
source_check() {
  local root="$1" d f k v p sc rc=0
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    f="$d/.source.md"
    for k in writes truth cards cards-at; do
      v="$(fm_field "$f" "$k")"
      if [ -n "$v" ] && ! allowed "$k" "$v"; then echo "BAD SETTING: $f $k=$v"; rc=1; fi
    done
    p="$(fm_field "$f" purpose)"
    if [ -n "$p" ] && ! is_suggested "$p" && { [ -z "$(fm_field "$f" writes)" ] || [ -z "$(fm_field "$f" truth)" ]; }; then
      echo "PURPOSE INCOMPLETE: $d (a custom purpose needs writes: and truth: — ask the user once)"; rc=1
    fi
    sc="$(fm_field "$f" scope)"
    if [ -n "$sc" ] && ! src_scopes "$d" "$root" | grep -qxF -- "$sc"; then
      echo "SCOPE UNKNOWN: $f $sc (place it in a scopes: list, narrowest first)"; rc=1
    fi
    if is_attachment "$f" && [ -z "$(src_val "$d" purpose "$root")" ]; then
      echo "PURPOSE?: $d (undeclared: writes never, truth no until the user says)"
    fi
  done <<EOF
$(source_dirs "$root")
EOF
  return $rc
}

# in_git <path> -> 0 if <path> (or its nearest existing folder) is inside a git work tree. No git
# installed counts as no repo: then nothing is published, so there is nothing to ask about it.
in_git() {
  local d="$1"
  while [ ! -d "$d" ]; do d="$(dirname "$d")"; done
  command -v git >/dev/null 2>&1 || return 1
  [ "$(git -C "$d" rev-parse --is-inside-work-tree 2>/dev/null)" = true ]
}

# questions <dir> [root] — what is still unanswered for an attachment folder, one word per line, in
# the order to ask (PLUG-146). An answer counts once any `.source.md` from <dir> up to <root> records
# it, so nothing is asked twice; the folder need not exist yet.
#   purpose               none resolved
#   writes, truth         the purpose is the user's own words and its file lacks the key
#   cards-at              where the cards live: local (the default answer) or drive
#   publish, copy-publish only in a git work tree; copy-publish only with processed: local
cmd_questions() {
  local dir="${1:-}" root="${2:-$ROOT_DEFAULT}" p f k
  [ -n "$dir" ] || { echo "Usage: remote.sh questions <dir> [root]" >&2; return 2; }
  dir="${dir%/}"
  IFS=$'\t' read -r p f <<EOF
$(src_key "$dir" purpose "$root")
EOF
  if [ -z "$p" ]; then echo purpose
  elif ! is_suggested "$p"; then
    for k in writes truth; do [ -n "$(fm_field "$f" "$k")" ] || echo "$k"; done
  fi
  [ -n "$(src_val "$dir" cards-at "$root")" ] || echo cards-at
  if in_git "$dir"; then
    [ -n "$(src_val "$dir" publish "$root")" ] || echo publish
    if [ "$(src_val "$dir" processed "$root")" = local ] && [ -z "$(src_val "$dir" copy-publish "$root")" ]; then
      echo copy-publish
    fi
  fi
  return 0
}

# wider_than_project <path> -> 0 if the scope in force at <path> comes after `project` in the scope
# order: a team's or a company's material, written to with more care
wider_than_project() {
  local sc
  sc="$(src_val "$1" scope /)"; sc="${sc:-project}"
  src_scopes "$1" / | awk -v s="$sc" '$0 == "project" { p = NR } ($0 "") == s { i = NR } END { exit !(p && i > p) }'
}

# guard <card> <provider-time> — run right before writing to the file a card describes (PLUG-147).
# <provider-time> is the file's modified time as the provider reports it now. In this order:
#   exit 3  READ-ONLY  the folder's `writes:` is never (the fallback): no write at all
#   exit 1  STALE      the file changed since the card was stamped: re-read it, re-plan, tell the user
#   exit 0  PROPOSE    writes: propose, or free in a scope wider than project: show the change, apply
#                      it only when the user approves
#   exit 0  OK         writes: free
# After the write, `stamp` records the file's new time.
cmd_guard() {
  local card="${1:-}" t="${2:-}" w have
  [ -n "$card" ] && [ -n "$t" ] || { echo "Usage: remote.sh guard <remote-card> <rfc3339-time>" >&2; return 2; }
  is_remote_card "$card" || { echo "Not a remote card: $card" >&2; return 1; }
  [ -f "$card" ] || { echo "No such card: $card" >&2; return 1; }
  valid_rfc3339 "$t" || { echo "Not an RFC 3339 time: $t" >&2; return 1; }
  w="$(src_val "$card" writes /)"; w="${w:-never}"
  if [ "$w" = never ]; then
    echo "READ-ONLY: $card (its folder says writes: never; ask the user to change the folder's purpose first)"; return 3
  fi
  have="$(fm_field "$card" remote-modified)"
  if [ "$have" != "$t" ]; then
    echo "STALE: $card card ${have:--}, provider $t (changed since it was read: re-read it, re-plan, tell the user)"; return 1
  fi
  if [ "$w" = propose ]; then echo "PROPOSE: show the change; apply it only when the user approves"
  elif wider_than_project "$card"; then
    echo "PROPOSE (scope $(src_val "$card" scope /): wider than the project): show the change; apply it only when the user approves"
  else echo OK; fi
  return 0
}

# office_ext <name> -> the Office extension kept in a card's name (`plan.docx.gdrive.md` -> docx), if any
office_ext() {
  local e base="${1%.*.md}"
  e="${base##*.}"; [ "$e" != "$base" ] || return 0
  case "$e" in doc|docx|xls|xlsx|ppt|pptx|odt|ods|odp|rtf) echo "$e" ;; esac
  return 0
}

# repoint <card> <new-id> <new-url> <new-type> <time> — an Office file was converted to a Google file,
# which is a new file with a new link (PLUG-147). The card follows it: new remote-id, remote-url,
# remote-type and remote-modified, `converted-from:` the old id, and the Office extension dropped from
# its name when the new type is a Google one (`plan.docx.gdrive.md` -> `plan.gdrive.md`). Its local copy
# is renamed with it. Refuses when the new name is taken. Never touches the provider: whether the
# original is kept or trashed is the user's call.
cmd_repoint() {
  local card="${1:-}" id="${2:-}" url="${3:-}" type="${4:-}" t="${5:-}" old new prov ext
  [ -n "$card" ] && [ -n "$id" ] && [ -n "$url" ] && [ -n "$type" ] && [ -n "$t" ] \
    || { echo "Usage: remote.sh repoint <remote-card> <new-id> <new-url> <new-type> <rfc3339-time>" >&2; return 2; }
  is_remote_card "$card" || { echo "Not a remote card: $card" >&2; return 1; }
  [ -f "$card" ] || { echo "No such card: $card" >&2; return 1; }
  valid_rfc3339 "$t" || { echo "Not an RFC 3339 time: $t" >&2; return 1; }
  prov="$(remote_provider "$card")"; ext="$(office_ext "$card")"; new="$card"
  case "$type" in
    application/vnd.google-apps.*) [ -z "$ext" ] || new="${card%."$ext.$prov".md}.$prov.md" ;;
  esac
  if [ "$new" != "$card" ]; then
    [ ! -e "$new" ] || { echo "Taken: $new (rename or remove it first)" >&2; return 1; }
    [ ! -e "${new%.md}.local.md" ] || { echo "Taken: ${new%.md}.local.md" >&2; return 1; }
  fi
  old="$(fm_field "$card" remote-id)"
  [ -z "$old" ] || [ "$old" = "$id" ] || fm_set "$card" converted-from "$old"
  fm_set "$card" remote-id "$id"; fm_set "$card" remote-url "$url"; fm_set "$card" remote-type "$type"
  fm_set "$card" remote-modified "$t"
  if [ "$new" != "$card" ]; then
    mv "$card" "$new"
    [ ! -f "${card%.md}.local.md" ] || mv "${card%.md}.local.md" "${new%.md}.local.md"
    echo "REPOINTED: $new (was $card)"
  else
    echo "REPOINTED: $card"
  fi
}

# --- cards kept on Drive (PLUG-148) ------------------------------------------------------------
#
# With `cards-at: drive` an attachment's card set lives on Drive as one document, so every teammate's
# Claude reads the same cards. Scripts stay offline: Claude reads the document into a temp file,
# `unpack`s it into a temp folder, runs check / diff / stamp there, `pack`s it and writes it back with
# the Docs revision guard. Each file is opened by a marker line holding its path relative to the
# attachment; anything before the first marker (a title) is ignored.

MARK_OPEN='<!-- remote-docs: '
MARK_CLOSE=' -->'

# pack_files <dir> -> the files a card set holds, relative to <dir>: every `.source.md` (the folder's
# settings travel with its cards), then every card; each list in byte order, so the text is the same on
# every machine. Local copies never: they are one user's offline text, not the team's map.
pack_files() {
  local d c
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    if [ "$d" = "$1" ]; then echo .source.md; else echo "${d#"$1"/}/.source.md"; fi
  done <<EOF
$(source_dirs "$1")
EOF
  while IFS= read -r c; do
    [ -n "$c" ] && echo "${c#"$1"/}"
  done <<EOF
$(RD_KEEP_IGNORED=1 list_remote_cards "$1" | LC_ALL=C sort)
EOF
  return 0
}

# pack <dir> — print <dir>'s card set as one text. Refuses (printing nothing) when a file holds a
# marker line, which would split it on the way back.
cmd_pack() {
  local dir="${1:-}" f bad=0
  [ -n "$dir" ] || { echo "Usage: remote.sh pack <attachment-dir>" >&2; return 2; }
  dir="${dir%/}"; [ -d "$dir" ] || { echo "No such folder: $dir" >&2; return 1; }
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if grep -q "^$MARK_OPEN" "$dir/$f"; then echo "Holds a marker line: $dir/$f" >&2; bad=1; fi
  done <<EOF
$(pack_files "$dir")
EOF
  [ "$bad" -eq 0 ] || return 1
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    printf '%s%s%s\n' "$MARK_OPEN" "$f" "$MARK_CLOSE"
    cat "$dir/$f"
    [ -z "$(tail -c 1 "$dir/$f")" ] || echo
  done <<EOF
$(pack_files "$dir")
EOF
  return 0
}

# pack_path_ok <relative-path> -> 0 if a marker names a file a card set may hold: relative, no `..`,
# and a `.source.md` or a remote card (never a local copy, never anything else)
pack_path_ok() {
  case "$1" in ""|/*|..|../*|*/..|*/../*) return 1 ;; esac
  case "$1" in .source.md|*/.source.md) return 0 ;; esac
  is_remote_card "$1" && ! is_remote_copy "$1"
}

# unpack <text> <dir> — write a packed card set into <dir>, which must be empty or absent. Every path
# is checked before anything is written: one bad marker and nothing is.
cmd_unpack() {
  local doc="${1:-}" dir="${2:-}" work n p bad=0
  [ -n "$doc" ] && [ -n "$dir" ] || { echo "Usage: remote.sh unpack <packed.md> <empty-dir>" >&2; return 2; }
  [ -f "$doc" ] || { echo "No such file: $doc" >&2; return 1; }
  dir="${dir%/}"
  if [ -e "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then echo "Not empty: $dir" >&2; return 1; fi
  work="$(mktemp -d)"
  awk -v W="$work" -v O="$MARK_OPEN" -v C="$MARK_CLOSE" '
    index($0, O) == 1 && substr($0, length($0) - length(C) + 1) == C {
      if (f != "") close(f)
      n++; f = W "/" n
      printf "%d\t%s\n", n, substr($0, length(O) + 1, length($0) - length(O) - length(C)) > (W "/index")
      printf "" > f; next }
    n { print > f }
  ' "$doc"
  if [ ! -s "$work/index" ]; then echo "No card set in $doc (no marker line)" >&2; rm -rf "$work"; return 1; fi
  while IFS=$'\t' read -r n p; do
    pack_path_ok "$p" || { echo "Refused: $p (not a .source.md or a remote card under the attachment)" >&2; bad=1; }
  done < "$work/index"
  if [ "$bad" -ne 0 ]; then rm -rf "$work"; return 1; fi
  while IFS=$'\t' read -r n p; do
    mkdir -p "$(dirname "$dir/$p")"; mv "$work/$n" "$dir/$p"
  done < "$work/index"
  rm -rf "$work"
  echo "UNPACKED: $dir"
}

cmd_purpose() {
  local path="${1:-}" root="${2:-$ROOT_DEFAULT}"
  [ -n "$path" ] || { echo "Usage: remote.sh purpose <dir|file> [root]" >&2; return 2; }
  purpose_record "$path" "$root"
}

cmd_purposes() {
  local root="${1:-$ROOT_DEFAULT}" d
  [ -d "$root" ] || { echo "No such root: $root" >&2; return 1; }
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    printf '%s\t%s\n' "$d" "$(purpose_record "$d" "$root")"
  done <<EOF
$(source_dirs "$root")
EOF
  return 0
}

# list [root] — every remote card, git-ignored ones included, one record each:
#
#   card<TAB>publish<TAB>remote-modified<TAB>description<TAB>read-when<TAB>local-copy
#
# `publish` comes from the nearest `.source.md` above the card that sets it (`src_val`): commit | local,
# "-" when none does.
# A local-only attachment is git-ignored, so `index` never lists it and no committed file
# names it; this listing is how Claude still finds it (PLUG-112, R12).
cmd_list() {
  local root="${1:-$ROOT_DEFAULT}" card pub mod desc when copy
  [ -d "$root" ] || { echo "No such root: $root" >&2; return 1; }
  while IFS= read -r card; do
    [ -n "$card" ] || continue
    pub="$(src_val "$card" publish "$root")"
    mod="$(fm_field "$card" remote-modified)"; desc="$(fm_field "$card" description)"
    when="$(fm_field "$card" read-when)"
    copy="${card%.md}.local.md"; [ -f "$copy" ] || copy=-
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$card" "${pub:--}" "${mod:--}" "${desc:--}" "${when:--}" "$copy"
  done <<EOF
$(RD_KEEP_IGNORED=1 list_remote_cards "$root")
EOF
  return 0
}

sub="${1:-check}"; shift || true
case "$sub" in
  status)     cmd_status "$@" ;;
  check)      cmd_check "$@" ;;
  list)       cmd_list "$@" ;;
  stamp)      cmd_stamp "$@" ;;
  gone)       cmd_gone "$@" ;;
  copy-stamp) cmd_copy_stamp "$@" ;;
  diff)       cmd_diff "$@" ;;
  purpose)    cmd_purpose "$@" ;;
  purposes)   cmd_purposes "$@" ;;
  questions)  cmd_questions "$@" ;;
  guard)      cmd_guard "$@" ;;
  repoint)    cmd_repoint "$@" ;;
  pack)       cmd_pack "$@" ;;
  unpack)     cmd_unpack "$@" ;;
  *) echo "Usage: remote.sh {status|check|list|purposes} [root] | stamp <card> <time> | gone <card> | copy-stamp <card> <time> | diff <dir> <listing.tsv> | purpose <path> [root] | questions <dir> [root] | guard <card> <time> | repoint <card> <id> <url> <type> <time> | pack <dir> | unpack <packed.md> <dir>" >&2; exit 2 ;;
esac
