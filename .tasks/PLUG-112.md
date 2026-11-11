---
title: "docs-manager — attach one Google Drive doc remote-only: .source.md, card, ☁ in _index, public-repo ask"
status: completed
type: feature
priority: low
epic: docs-gdrive
created: 2026-11-11 18:02
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | 4 conflicts with existing docs-manager invariants found, see Context |
| 20 | Requirements | done | EARS R1–R14; names/formats proposed, fixed at Architecture |
| 30 | Assessment | done | ready; 6 touchpoints, 2 requirements free; baseline green host + bash:5 |
| 60 | Architecture | done | A1–A7; R9 narrowed (detail in `external remote`, not `status`) |
| 70 | Tests | done | RC1–RC8 in external.test.sh, RC9 in docs.test.sh; 18 red first; 9 mutants all caught |
| 90 | Implementation | done | external.sh, docs.sh, lib.sh; how-to, SKILL.md, CLAUDE.md, READMEs; 1.12.0 |
| 100 | Tech Debt | done | none taken |
| 110 | Reflection | done | docs-manager/CLAUDE.md § Remote cards; how-to § Remote documents; create→modifiedTime lesson in epic POC findings |

## Description

The smallest useful slice of the epic. The user says "attach this Drive doc <link> to the docs"
(or similar). With a Drive MCP connected, Claude reads the doc, creates an attachment folder with
`.source.md` (`provider: gdrive`, id/URL, `content: remote`, `processed: none`) and a card, and
`index` lists the card marked as remote.

Before writing a card or URL into a repo whose git remote is public, the plugin asks and records
the answer in `.source.md` (epic design, option 2), offering to gitignore the attachment's cards.

## Context

**Epic:** PLUG-110 `docs-gdrive`, design agreed 2026-11-11. Its POC (step 40) has **not** run;
the Drive MCP in the sessions so far is connected but not signed in. This task's Architecture
step needs the POC's answers (file id, modifiedTime, mimeType, export formats).

**Prior work to build on:** epic `external-docs` (PLUG-016, all sub-tasks completed): card format,
index integration, staleness (new / changed / orphaned), ingest flow, docx/xlsx extraction.
PLUG-016 put "any network fetch" out of scope; this epic keeps that for **scripts**, since only
Claude calls the MCP.

**Docs:** `docs-manager/CLAUDE.md` (invariants, read first), `skills/docs-manager/references/how-to-external-docs.md`
(card format, layout, procedure). Both accurate today; both need a remote section at Reflection.

**Code to touch:**
- `scripts/external.sh`: `is_card`, `list_cards`, `external_status`, `cmd_external_check`
  (index section `### External documents` is built from these).
- `scripts/lib.sh`: `fm_field` / `fm_parse` (the one frontmatter reader; reuse, don't add one),
  `docs_find` (the one tree walk), `md_dest` (every written link).
- `skills/docs-manager/SKILL.md` + a reference for the Drive procedure (or a section of how-to-external-docs.md).
- Tests: `scripts/test/external.test.sh`, host **and** `bash:5` container (commands in docs-manager/CLAUDE.md).

**Conflicts with existing invariants (must be resolved at Requirements / Architecture):**
1. **A remote card is read as an orphan today.** `is_card` = `<name>.<external-ext>.md`, and
   `external_status` reports any card without its file beside it as `orphan`, which fails `check`.
   A remote card needs its own recognisable form (a distinct name, or recognised via the
   attachment's `.source.md`), so it is never confused with a card whose file was deleted.
2. **Native Google files have no extension** (Doc / Sheet / Slides), and `EXTERNAL_EXTS` is a fixed
   list. The card name for them has to be decided (e.g. by the export type, or a gdrive-specific suffix).
3. **"The file name is the link; a card has no `source:` key."** A remote card has no local file,
   so the Drive id/URL must live somewhere: in the card, or only in `.source.md`. Either is a
   deliberate, documented exception to this rule.
4. **"Convention, not config" / no `.docs-manager.json`** (dropped in PLUG-016). `.source.md` must
   be per-attachment data (like a card), not a config file in disguise. Note: `docs_find` prunes
   dot-entries, so `.source.md` is invisible to `index` (good: not listed as a doc) and scripts must
   read it directly, by path.

**Invariants to keep (from docs-manager/CLAUDE.md):** no command makes a network call; `stamp` is
the only writer of `digest:` (a remote stamp needs the same single-writer rule); the
`### External documents` section appears only when a folder has externals, so existing
`_index.md` files regenerate byte-identical (case E2); `check` never fails on placement.

**Parallel-session collisions:** none. In progress elsewhere: Cowork epic PLUG-117 / research PLUG-111;
it lists docs-manager only as "none found" (PLUG-123), no file overlap now.

## Requirements

Inputs: epic PLUG-110 (agreed design, POC findings). Names below (`.source.md`, `*.gdrive.md`, field
names) are proposals; Architecture fixes them. EARS: **When / While / If … the plugin shall …**

**Attaching (skill, Claude side)**
- **R1** When the user asks to attach a Drive doc (a URL or id), and a Drive MCP is connected and
  signed in, Claude shall read its metadata and content through the MCP and write: the attachment's
  `.source.md` (if absent) and one **remote card** for the doc.
- **R2** If no Drive MCP is connected, or it is not signed in, Claude shall say so and how to fix it
  (`/mcp`), and write nothing.
- **R3** Claude shall recognise a Drive MCP by what its tools do (search / read / metadata of Drive
  files), never by one fixed tool name (POC: names are the claude.ai connector's).
- **R4** The remote card shall hold the standard card sections (title, description, `read-when`,
  Summary, Where to look, Key terms) plus the remote fields: provider, file id, mimeType, view URL,
  and the `modifiedTime` it was written from. Its body shall say the file lives on Drive and is
  reachable only with access to it.

**Recognising a remote card (scripts, offline)**
- **R5** A remote card shall be recognisable by its **name** (proposal: `<slug>.gdrive.md`), so no
  script needs to read frontmatter to classify a file, matching how `is_card` works today.
- **R6** A remote card shall never be reported as `orphan`, and its absence of a local file shall
  never fail `check`.
- **R7** `index` shall list remote cards in the folder's `### External documents` section, each marked
  remote (proposal: `☁`), with the card's `description`. A folder with no externals and no remote cards
  shall regenerate byte-identical to today (E2 holds).
- **R8** `links` and `check` shall accept a remote card's view URL without fetching it (no command
  makes a network call). `check` shall fail on a remote card missing its file id or `modifiedTime`.
- **R9** `external status` shall report each remote card as `remote` with its recorded
  `modifiedTime`, so the skill can compare it with Drive's.

**Freshness (skill)**
- **R10** When Claude opens a remote file for an answer and Drive's `modifiedTime` is newer than the
  card's, Claude shall say the card is out of date and offer to refresh it. Only the refresh writes
  `modifiedTime` (single writer, like `stamp` for `digest:`).

**Public repo (skill + scripts)**
- **R11** Before writing the first card or `.source.md` of an attachment into a repo whose git
  remote is public (or unknown), Claude shall ask: commit it, or keep the attachment local-only.
  The answer is recorded in `.source.md` and not asked again for that attachment.
- **R12** While an attachment is local-only (git-ignored), it shall stay discoverable to Claude
  without anything about it entering a committed file. Today `docs_find` drops git-ignored files, so
  `index` would hide it completely. Proposal: a script listing (`docs.sh external remote`) that walks
  attachments *including* git-ignored ones and prints title, description and `read-when`, which the
  skill tells Claude to run; committed `_index.md` files never mention a local-only attachment.

**Unchanged behaviour**
- **R13** With no `.source.md` and no remote card in the tree, every command's output shall be
  byte-identical to the current release (all existing suites pass unchanged).
- **R14** No test shall need network, an MCP or Drive; all run on host (bash 3.2, BSD) and in `bash:5`.

**Open for Architecture:** card name for an uploaded file vs. a native one (`x.pdf.gdrive.md`?);
where `.source.md` lives for a single-doc attachment (the folder holding the card?); whether
`.source.md`, a dot-file, is a doc at all (it is not indexed, by `docs_find`'s dot-entry pruning).

## Assessment

Baseline 2026-11-11, all green: host diagram 100, external 100, onboard 34, docs 35; `bash:5`
diagram 100, external 100, onboard 31 + 1 skipped, docs 25 + 4 skipped (git cases, expected).

Readiness per requirement (files in `docs-manager/scripts/`):
- **R5/R6 free by naming.** `is_card` is `<name>.<external-ext>.md`; `x.gdrive.md` and `x.pdf.gdrive.md`
  are not cards, so the orphan loop (`external_status`, via `list_cards`) never sees them.
- **R8 URL part free.** `doc_link_records` already skips `http(s)://` (`lib.sh` ~267).
- **R7 needs** `list_docs` (`docs.sh` ~44) to exclude remote cards (today one would be listed under
  `### Documents`), and `build_block`'s gate (`docs.sh` ~80) to open the section for remote cards too.
- **R8 field check and `relates-to`:** `cmd_check`'s third pass (`docs.sh` ~170) iterates `list_cards`
  only; remote cards must join it.
- **R12 needs a walk that keeps git-ignored files.** `docs_find` always pipes through
  `drop_git_ignored` (PLUG-093) and prunes dot-entries. Add an opt-out to the one walk rather than a
  second walk (DRY: "do not add a bare find over the docs tree").
- **R10 single writer:** `fm_set` (`lib.sh`) is the existing safe writer; `cmd_external_stamp` is the
  pattern to copy the shape of (diff-guarded).
- Tests go in `external.test.sh` (cards, index, check) and `docs.test.sh` (git-ignore case, host only
  as today).

## Architecture

- **A1 Card name:** `<name>.gdrive.md`, `<name>` chosen by Claude from the Drive title (kebab-case),
  keeping an uploaded file's extension (`spec-v3.pdf.gdrive.md`); a native file has none
  (`pricing-model.gdrive.md`). The provider is the suffix, so another provider is `.<provider>.md`;
  today `REMOTE_PROVIDERS="gdrive"`, one list beside `EXTERNAL_EXTS`. Same title twice in a folder:
  Claude appends `-2`. Predicate `is_remote_card`, lister `list_remote_cards`, beside `is_card`/`list_cards`.
- **A2 Card fields:** the standard card frontmatter plus `remote-id:`, `remote-url:` (view URL),
  `remote-type:` (mimeType), `remote-modified:` (RFC 3339 from Drive). The id lives in the card, a
  **documented exception** to "a card has no `source:` key": there is no local file name to be the link.
- **A3 Single writer of `remote-modified:`:** `docs.sh external remote-stamp <card> <rfc3339>`.
  It validates the time's shape, writes with `fm_set`, diff-guarded. Claude passes the value it got from
  Drive; nothing else writes the field (mirrors `stamp` → `digest:`).
- **A4 `.source.md` = settings of one attachment folder**, not a config file: per-folder data, like a
  card. Frontmatter: `provider: gdrive`, `content: remote`, `processed: none`, `publish: commit|local`
  (the R11 answer), and for a folder attachment (PLUG-113) `remote-id:` / `remote-url:` of the Drive folder.
  A single-doc attachment's id is in its card, so several single docs can share one folder. Being a dot-file,
  `docs_find` never lists it as a doc; scripts read it by path (`<card dir>/.source.md`).
- **A5 Index line:** in `### External documents`, after the local externals, sorted:
  `- ☁ [`<name>`](<name>.gdrive.md) — <description>`. The section opens when a folder has externals
  **or** remote cards; otherwise output is byte-identical (E2, R13).
- **A6 `check`:** a remote card without `remote-id:` or `remote-modified:` →
  `REMOTE INCOMPLETE: <card>` (fails). Remote cards join the `relates-to` pass. No remote card is ever an orphan.
- **A7 Local-only (R11/R12):** `publish: local` → Claude adds the attachment folder to `.gitignore` as part
  of the answer the user gave. `docs_find` gets an opt-out of the ignore filter (env
  `DM_KEEP_IGNORED=1`), used only by `docs.sh external remote [root]`, which prints one record per
  remote card, ignored ones included: `card<TAB>publish<TAB>remote-modified<TAB>description<TAB>read-when`.
  SKILL.md tells Claude to run it when looking for reference material. **R9 narrowed:** `external status`
  gets a plain `remote` state row (`remote<TAB>place<TAB>-<TAB>card`); the detail lives in `external remote`.

## Tests

`docs-manager/scripts/test/external.test.sh` § *remote cards (PLUG-112)*: RC1 index line `☁`, not a
document, idempotent; RC2 section opens for remote cards alone, native file has no extension; RC4
`remote` status row, never orphan; RC5 `REMOTE INCOMPLETE` without id / modified, complete card clean,
URL not link-checked; RC6 `relates-to` of a remote card checked; RC7 `remote-stamp` writes, UNCHANGED
on repeat, rejects bad time / non-remote card; RC8 `external remote` records with `publish`, `.source.md`
not indexed. `docs.test.sh` RC9 (git, host + `bash:5`+git): a git-ignored attachment is absent from every
`_index.md` and present in `external remote`.

Red first: 18 failing before implementation. Mutation check (temp copy of the plugin, never the shared
tree), each reverted piece turned its case red: list_docs exclusion → RC1b, section gate → RC2a,
incomplete state → RC5a–c, time shape → RC7e, remote-card guard → RC7f, relates-to pass → RC6,
`DM_KEEP_IGNORED` → RC9b, diff guard → RC7c, provider list → RC1–RC8.

## Implementation

- `scripts/external.sh`: `REMOTE_PROVIDERS`, `is_remote_card`, `list_remote_cards`; `external_status`
  emits `remote` / `incomplete`; `external check` reports `REMOTE INCOMPLETE`; new `external remote-stamp`
  (only writer of `remote-modified:`) and `external remote` (ignored files included).
- `scripts/docs.sh`: `list_docs` skips remote cards; `build_block` lists them as `☁` after local
  externals, section opens for either; `check`'s relates-to pass covers them.
- `scripts/lib.sh`: `docs_find` honours `DM_KEEP_IGNORED=1` (one walk, filter switched).
- Skill: `how-to-external-docs.md` § *Remote documents (Google Drive)* (format, `.source.md`, attach
  procedure, publish question, finding/reading, freshness); `SKILL.md` triggers + pointer.
- `docs-manager/CLAUDE.md` § *Remote cards*; plugin and root README; root CLAUDE.md vocabulary;
  version 1.12.0 in plugin.json + marketplace.json.

## Verification

- Suites green: host diagram 100, external 127, onboard 34, docs 38; `bash:5` diagram 100,
  external 127, onboard 31+1 skipped, docs 25+5 skipped; `bash:5`+git docs 38 (RC9 included).
- Standalone copy of `docs-manager/` alone: external 127, docs 38, green.
- **E2E with the real claude.ai Drive connector:** a throwaway Google Doc created in the user's test
  folder, attached by following the new how-to into a temp git repo: `check` reported `REMOTE INCOMPLETE`
  before `remote-stamp`, then `index --write` listed it as `☁`, `check` clean, `external remote` printed
  the record. Temp tree removed; the Drive test doc is kept for PLUG-113 unless the user wants it trashed.
- Not testable by script (Claude behaviour, written in the how-to): MCP detection by capability, the
  publish question, the freshness comparison (R2, R3, R10, R11).

## Release note (2026-11-11)

The 1.12.0 bump named under Implementation was **withdrawn** before commit: the user releases only when
the whole epic is finished. plugin.json, marketplace.json and the root README stay at 1.11.0 until the
epic's Reflection; the code, skill and plugin README ship in the commit unversioned.

## Acceptance criteria

- With no Drive MCP: no behaviour change; existing tests pass.
- Attaching one doc yields `.source.md` + card; `index` lists it with the remote marker; `links` and `check` pass.
- Public remote: asked once, the answer recorded; not asked again on the next attach to that folder.
- No MCP connected or not signed in when a remote card is needed: Claude says so, does not answer from the card as if it read the file.
- Skill trigger phrases added and checked against the other plugins and the built-in google-workspace skill.

## Current State

All workflow steps done; tests green on host and bash:5; e2e verified on the real connector. Nothing committed (user commits). Status left in-progress until the user confirms completion. Next in the epic: PLUG-113, PLUG-114, PLUG-115 can run in parallel sessions.
