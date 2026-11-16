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
  *) echo "Usage: remote.sh {status|check|list|purposes} [root] | stamp <card> <time> | gone <card> | copy-stamp <card> <time> | diff <dir> <listing.tsv> | purpose <path> [root] | questions <dir> [root]" >&2; exit 2 ;;
esac
