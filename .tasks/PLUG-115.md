---
title: "docs-manager — processed: local for a Drive attachment: a stamped <doc>.md text copy, asked once"
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
| 10 | Context | done | read_file_content gives Drive's text rendering as a plain string (probe); see Context |
| 20 | Requirements | done | L1–L9 |
| 30 | Assessment | done | ready; additive in external.sh, one line in docs.sh |
| 60 | Architecture | done | plan approved 2026-11-11; see Architecture |
| 70 | Tests | done | LC1–LC11, seen red first; 5 mutants caught; see Tests |
| 90 | Implementation | done | copy-stamp, copy states, is_remote_copy; e2e on the real connector |
| 100 | Tech Debt | done | one time-shape helper now (valid_rfc3339); none added |
| 110 | Reflection | done | how-to § Keeping a local copy, SKILL.md, plugin + root CLAUDE.md |

## Description

With `processed: local`, Claude keeps a readable `<doc>.md` text version of a complex file next to its
card, so the user can work offline, at their own risk. It goes against docs-manager's default "only the
card goes into the repo", so the plugin asks once per attachment and records the answer in `.source.md`.
Whether the copy is committed or gitignored is part of the same question.

The copy is stamped with the source's modifiedTime; `check` / refresh report it as stale when the source
is newer. When Claude answers from it, it says the answer comes from a local copy of a given date.

## Acceptance criteria

- No `.md` copy is written before the user agreed; the answer is recorded and not asked again.
- A stale copy is reported by `check`.
- For a synced local file, text comes from extract.sh (no second extractor).

## Scope added from PLUG-114 (2026-11-11)

PLUG-114 (`content: sync`) was rejected: through the connector a binary can only be copied by retyping
base64, with no checksum (PLUG-114, Context). This task takes over what was worth keeping:
- The local copy of a **native Doc / Sheet** is its text export (`text/markdown` / `text/csv`); there is
  no separate sync. A native Slides deck: its text rendering.
- **Binaries stay remote.** The how-to tells the user to download one into `docs/external/` by hand when
  they want it locally; it then follows the existing external-file flow.

## Context

- PLUG-114 rejected: `download_file_content` is base64-only, even for a markdown export. Probe
  (2026-11-11, test folder): `read_file_content` returns Drive's text rendering (markdown-like, e.g.
  `1\\. Authentication`) as a plain JSON string, for Docs, Sheets, Slides, pdf, docx and more. That is the
  copy's source; no extractor is needed, so `extract.sh` is not involved (the old AC about it was about
  synced local files, which no longer exist).
- The copy is text Claude writes; scripts cannot verify its fidelity, only that it is agreed and current.

## Requirements

- **L1** Claude writes a copy only when the card's `.source.md` says `processed: local`; the user is asked
  once per folder (offline use at their own risk; commit or git-ignore the copies: `copy-publish`).
- **L2** The copy is `<name>.gdrive.local.md` beside the card: Drive's text rendering verbatim.
- **L3** `external copy-stamp <card> <time>` is the only writer of the card's `copy-modified`; it refuses
  when `processed: local` is absent or the copy is missing.
- **L4** `check` fails on a copy that is stale (`copy-modified` ≠ `remote-modified`), unstamped, not
  agreed, or without a card.
- **L5** A git-ignored copy is still checked; a copy is never indexed as a document.
- **L6** `external remote` names each card's copy (6th field).
- **L7** Refresh rewrites the copy on `changed`; answers from it say they come from a local copy of a date.
- **L8** Above ~200 KB of text, ask before writing a copy.
- **L9** Binaries are never copied through the connector; the how-to says to download one by hand.

## Architecture

As in the approved plan: name classifier (`is_remote_copy`, `list_remote_copies`), stamp in the card,
`copy-stamp` guarded by `source_of`, five status states (`copy`, `copy-stale`, `copy-unstamped`,
`copy-unasked`, `copy-orphan`), one time-shape helper shared with `remote-stamp`.

## Tests

`external.test.sh` § `== local copies (PLUG-115) ==`: LC1 never indexed, card still ☁ · LC2 `copy-stamp`
refuses without `processed: local` or `.source.md`, card untouched · LC3 refuses with no copy · LC4 stamps,
UNCHANGED, bad time, not a card · LC5 `copy` + clean check · LC6 card restamped → `LOCAL COPY STALE`, then
clean after copy-stamp · LC7 unstamped · LC8 not agreed · LC9 orphan, not mistaken for a card · LC11
`external remote` 6th field. `docs.test.sh` LC10: a git-ignored copy is still reported (git case).
Red first; mutants in a temp copy (classifier, agreement guard, stale compare, ignored listing, unasked
state): all five caught.

## Implementation

`external.sh`: `is_remote_copy`, `list_remote_copies` (`DM_KEEP_IGNORED=1`), `valid_rfc3339` (now shared
with `remote-stamp`, one regex), five copy states in `external_status`, `LOCAL COPY …` messages in
`check`, `cmd_external_copy_stamp` guarded by `source_of`, 6th field `local-copy` in `external remote`.
`docs.sh`: `list_docs` skips copies. Docs: how-to § *Keeping a local copy* (ask once, `copy-publish`,
verbatim text rendering, ask above ~200 KB, binaries by hand), refresh and answering rules, commands and
states; SKILL.md triggers; plugin CLAUDE.md notes; root CLAUDE.md vocabulary. No version bump.

## Verification

- All suites green on the host, `bash:5` with git, `bash:5` without HOME, and from a standalone copy:
  external 181, docs 39, diagram 100, onboard 34.
- E2E with the real connector's text rendering of the test doc (read-only): copy written verbatim in a
  temp repo with `processed: local`, `copy-publish: local`; before stamps `check` named UNSTAMPED; after
  `remote-stamp` + `copy-stamp`, `check` OK, git ignored the copy, `_index.md` did not list it, `external
  remote` named it; card restamped → `LOCAL COPY STALE`.
- Found by the e2e: a card linking a git-ignored copy would be a broken link in every other clone. The
  how-to now links the copy only with `copy-publish: commit`.

## Current State

Completed.
