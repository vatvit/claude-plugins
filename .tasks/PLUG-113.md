---
title: "docs-manager — attach a Google Drive folder and refresh it: new / changed / orphaned cards"
status: completed
type: feature
priority: low
epic: docs-gdrive
deps: [PLUG-112]
created: 2026-11-11 18:02
tags: ["docs-manager-plugin"]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | builds on PLUG-112 (same session); see Context |
| 20 | Requirements | done | F1–F12 |
| 30 | Assessment | done | ready; all additive in external.sh |
| 60 | Architecture | done | B1–B7; listing TSV id/path/mime/modified, match by id |
| 70 | Tests | done | RF1–RF12 in external.test.sh, seen red first; 7 mutants caught; see Tests |
| 90 | Implementation | done | remote-diff, remote-gone, gone state, source_of; e2e on the real connector; see Implementation |
| 100 | Tech Debt | done | none added; see Tech Debt |
| 110 | Reflection | done | how-to, SKILL.md triggers, plugin + root CLAUDE.md; see Verification |

## Description

A `.source.md` can point at a Drive **folder** with a scope (recursive, include / exclude). On
"refresh the Drive docs", Claude lists the folder through the MCP into a temp file; a script compares
that listing with the attachment's cards (file id + modifiedTime) and reports new, changed and gone.
Claude writes cards for new files and updates changed ones. A card whose file is gone is marked
orphaned, never deleted.

The comparison must reuse the existing external-docs staleness logic where it fits (DRY within the plugin).

## Context

Same session as PLUG-112, which built the base: remote cards `<name>.gdrive.md` (fields `remote-id`,
`remote-url`, `remote-type`, `remote-modified`), `.source.md` per folder (`publish:`), commands
`external remote` / `external remote-stamp`, how-to § *Remote documents (Google Drive)*. Read
PLUG-112 § Architecture (A1–A7) and the epic's POC findings, which say: a folder is listed with
`search_files` `parentId = '<id>'`, paginated, sub-folders come back as items, so recursion is one call
per folder; `modifiedTime` is the only change stamp.

**Reuse, not clone:** the local staleness check (`external_status`: new / changed / orphan by digest)
compares files on disk; this compares a Drive listing with cards. The inputs differ, so the code is
new, but the vocabulary and the `check` reporting style are the same (`NO CARD` ≈ `new`, `CHANGED`,
`ORPHAN CARD` ≈ gone).

**Code to touch:** `scripts/external.sh` (new commands, status/check states), `scripts/lib.sh`
(`fm_field`, `fm_list`, `fm_set`, `docs_find`), how-to § Remote documents, tests in
`external.test.sh`. **Collisions:** none; PLUG-114/115 untouched and proposed.

**awk trap (repo CLAUDE.md):** Drive ids can look numeric to awk; compare ids as `($1 "") == id`.
`modifiedTime` strings are compared for **inequality only**: `…11Z` and `…11.986Z` do not sort
lexically, and Drive always reports milliseconds.

## Requirements

- **F1** When the user attaches a Drive **folder**, Claude shall record it in the local folder's
  `.source.md` (`remote-id`, `remote-url` of the Drive folder, `recursive`, optional `include` /
  `exclude`), asking the publish question as in PLUG-112 (R11).
- **F2** On "refresh the Drive docs" (or when an attached folder is used and has not been refreshed
  this session), Claude shall list the Drive folder through the MCP (recursively when `recursive: true`,
  all pages) into a temp TSV file, never into the repo.
- **F3** `docs.sh external remote-diff <attachment-dir> <listing.tsv>` shall compare the listing with the
  remote cards under the attachment and print one record per difference: `new`, `changed`, `gone`.
- **F4** Files match cards **by Drive id**, never by name: a renamed or moved Drive file is `ok`
  (or `changed`, if its `modifiedTime` moved), not gone + new.
- **F5** `changed` = the listing's `modifiedTime` differs from the card's `remote-modified`.
- **F6** Folder rows (mimeType `application/vnd.google-apps.folder`) are never files to card.
- **F7** With `recursive: false`, rows in sub-folders are out of scope. `include` / `exclude` are glob
  patterns on the listing path; a row is in scope when it matches some `include` (or there is none)
  and no `exclude`. Out-of-scope rows are never `new`; a card whose file left the scope is `gone`.
- **F8** A `gone` card is never deleted by a script. `external remote-gone <card>` marks it
  (`remote-gone: yes`); `check` then reports `REMOTE GONE: <card>` and fails, like `ORPHAN CARD`,
  until the user deletes the card or the file comes back. `remote-stamp` clears the mark
  (`remote-gone: no`) when the file is back.
- **F9** Before writing cards for more than 20 new files in one refresh, Claude shall ask; above a few,
  it delegates reading to sub-agents (as for large local files).
- **F10** Sub-folders on Drive become sub-folders of the attachment (names in kebab-case), so the
  topic structure and `index` work unchanged.
- **F11** `remote-diff` shall reject a malformed listing (wrong field count, empty id) with an error
  naming the line, and write nothing.
- **F12** All of it offline-testable from fixture listings; existing output unchanged (RC/E2 hold).

## Assessment

Ready, all additive. `external_status` gains a `gone` state (from `remote-gone: yes`) beside
`remote` / `incomplete`; `cmd_external_check` reports it. `remote-diff` and `remote-gone` are new
commands in `external.sh`'s dispatch. Glob matching: shell `case` patterns, no awk regex needed.
`fm_list` already reads `include: [a, b]`. No index change: cards in sub-folders are indexed as today.

## Architecture

- **B1 Listing TSV** (Claude writes it, one row per Drive item):
  `id<TAB>path<TAB>mimeType<TAB>modifiedTime`, `path` = Drive titles from the attached folder down,
  joined by `/` (a `/` inside a title becomes `-`). Folder rows may be present; they are skipped.
- **B2 Attachment = the folder holding a `.source.md` with `remote-id`**; its cards are the remote
  cards under it, sub-folders included. Attachments do not nest (documented, not detected).
- **B3 `remote-diff` output**, one record per difference, sorted, tab-separated:
  `new<TAB>id<TAB>path<TAB>mimeType<TAB>modifiedTime`,
  `changed<TAB>id<TAB>card<TAB>modifiedTime` (Drive's, to pass to `remote-stamp`),
  `gone<TAB>id<TAB>card`. Nothing printed = in sync. rc 0 in every case except a bad listing (rc 1).
- **B4 One awk pass** reads two inputs: cards as `id<TAB>card<TAB>modified` records (built in the shell
  with `fm_field`), then the in-scope listing rows; ids compared as strings.
- **B5 Scope filter in the shell** (`case "$path" in $pattern)`) before awk, reading `recursive`,
  `include`, `exclude` from `.source.md` with `fm_field` / `fm_list`.
- **B6 `remote-gone <card>`**: remote card only, sets `remote-gone: yes` via `fm_set`, diff-guarded.
  `remote-stamp` sets `remote-gone: no` only when the key exists with `yes`.
- **B7 `external_status`**: a remote card with `remote-gone: yes` → `gone` row (before the complete /
  incomplete test); `check` → `REMOTE GONE: <card> (removed from Drive: delete the card, or restore the file)`.

## Acceptance criteria

- Refresh reports exactly the new / changed / gone files for fixture listings.
- Orphaned cards are marked and reported by `check`, not deleted.
- Include / exclude and recursive scope are honoured.
- Tests need no network and no MCP.

## Tests

`docs-manager/scripts/test/external.test.sh`, section `== remote folders (PLUG-113) ==`, offline on fixture
listings (helpers `attach`, `listing`, `diff_of`; `rcard` gained id / modified overrides):

- RF1 in sync · RF2 new · RF3 changed by id, a rename is no record · RF4 gone · RF5 folder rows never new
- RF6 `recursive: false`, `include`, `exclude` (an exclude wins; out of scope → gone)
- RF7 numeric-looking ids stay distinct (`010`/`10`, `75e763`/`7e1794`)
- RF8 malformed listing → rc 1, line named, empty stdout · RF11 no `.source.md` / no `remote-id`
- RF9 `remote-gone` marks, UNCHANGED on repeat, refuses a non-remote card
- RF10 `gone` status row, `REMOTE GONE` fails `check`, `remote-stamp` clears, an unmarked card gets no key
- RF12 (found by the e2e run) a card in a sub-folder of an attachment takes `publish` from the nearest
  `.source.md` above it, not only beside it

Each case was seen red first (RF12 against the old lookup). Mutation run in a temp copy, one mutant
each: match by path instead of id, no folder skip, no `recursive` check, no exclude, numeric ids, no
gone state, no gone clear — all seven caught.

## Implementation

`docs-manager/scripts/external.sh`:
- `remote-diff <dir> <listing>` — validates the attachment and the listing, filters by scope in
  `remote_in_scope` (`case` globs), card records from `DM_KEEP_IGNORED=1 list_remote_cards`, one awk pass
  keyed by id as a string; `FILENAME == C` because either input may be empty. Sorted output.
- `remote-gone <card>` sets `remote-gone: yes`, diff-guarded; `remote-stamp` sets it back to `no`.
- `external_status` emits `gone`; `check` prints `REMOTE GONE`.
- `source_of <card> <root>` — nearest `.source.md` upward; `external remote` reads `publish` through it.

Docs: `how-to-external-docs.md` (commands, `gone` state, *Attaching a Drive folder*, *Refreshing a Drive
folder*: listing format, record handling, ask above 20 new files), SKILL.md triggers ("attach a Drive
folder", "refresh the Drive docs", …), `docs-manager/CLAUDE.md` § Remote cards, root CLAUDE.md vocabulary.
No version bump: release at the end of epic `docs-gdrive`.

## Tech Debt

None added. The single-file attach procedure (PLUG-112) and the folder one share `.source.md` and the
card format; the how-to keeps one copy of each and the folder section points back.

## Verification

- Suites: external 158/158, docs 38, diagram 100, onboard 34 — host, `bash:5`, `bash:5` without HOME;
  docs.test.sh also in `bash:5` with git; all suites green from a standalone copy of the plugin.
- E2E on the real connector, inside the Drive test folder only: created a sub-folder with one doc, listed
  the folder (2 pages) and the sub-folder through the MCP into a temp TSV, attached with
  `include: [dm-e2e-*]` in a temp git repo. `remote-diff` → exactly 2 `new` (the folder row and every
  out-of-scope file skipped); cards written and stamped → in sync, `check` OK; the glossary dropped from
  the listing → `gone`, marked, `check` fails, not reported twice; restored → `changed`, stamped → clean.
  Confirmed again: a created doc's `modifiedTime` moves after creation (21.834Z → 24.269Z); the listing
  is the value to stamp. The two test items stay in the test folder.

## Current State

Completed. Uncommitted. Next in the
epic: PLUG-114 (sync), PLUG-115 (processed: local), then PLUG-116.
