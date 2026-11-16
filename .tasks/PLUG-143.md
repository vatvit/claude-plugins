---
title: "EPIC: remote-docs — a plugin that manages remote documents (Drive, artifacts) inside docs/, by folder purpose"
status: in-progress
type: epic
epic-name: remote-docs
priority: medium
tags: ["remote-docs-plugin", "docs-manager-plugin"]
created: 2026-11-16 14:55
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | ## Context |
| 20 | Requirements | done | the epic's Decisions are the requirements; per-slice ones in each sub-task |
| 60 | Architecture | done | ## Architecture: the seam between the two plugins (A1–A7) |
| 80 | Subtasks | done | PLUG-144 … PLUG-149 |
| 90 | Implementation | — | |
| 110 | Reflection | — | |

## Goal

Make Google Drive (and Claude Artifacts, later other providers) a comfortable space for a team to
collaborate through Claude: Claude knows what each remote folder is for, reads it, writes to it where
its purpose allows, and keeps decisions in one place.

## Why

docs-manager attaches Drive material read-only, as reference cards (epic `docs-gdrive`). Real use is
wider: a team or company folder of agreements and templates, a project folder that is read and written
both ways, intermediate collaboration files, outputs. Nothing tells Claude what a remote folder is for,
whether it may write there, or where a decision made in a working file must end up. A project may have
no git at all, with Drive as its only docs store.

## Decisions (user, 2026-11-16)

- **Split.** A new plugin `remote-docs` owns every remote provider (Drive, artifacts); docs-manager keeps
  the project's own docs (index, links, check, diagrams, local external files, CLAUDE.md, onboarding).
  The plugins are independent (root CLAUDE.md, *Plugin Independence*): they share the card format, which
  is data, never code. docs-manager keeps listing `*.<provider>.md` cards with ☁ by their name; the
  remote-docs plugin validates them with its own `check`.
- **Everything local lives under `docs/`.** Cards, pointers, `.source.md`, local copies. Documents only:
  no code or other files are attached, and nothing is stored outside the docs root.
- **Folder purpose, declared by a file in the folder, inherited from the parent when absent.** Described
  for the main folder and a few at the first level, not for every folder.
  - A suggested list plus **other** (custom, in the user's words). Suggestions: *reference* (read-only),
    *agreements and context* (mostly read; where decisions live), *collaboration* (read-write, temporary,
    changes often), *output* (mostly write, also read, lasting).
  - The free-text purpose is for Claude; two settings are for scripts: `writes: never | propose | free`
    and `truth: yes | no` (is this where decisions live). A suggestion fills both; a custom purpose is
    asked both once.
  - **Fallback** when nothing up the chain declares a purpose: `writes: never`, `truth: no`, and Claude
    asks once to declare it.
- **Scope:** ordered `user > project > team > company`; the user may add a custom scope by placing it in
  that order. The narrower scope wins a conflict; the wider the scope, the more careful a write, and a
  wider scope never receives project-specific content.
- **An artifact is never where a decision lives** (PLUG-141). The same holds for any `truth: no` folder:
  a decision made there is extracted into the doc it belongs to.
- **Collaboration folders get one pointer** in `docs/` (purpose + link), not per-file cards; per-file
  cards there are opt-in. Per-file cards are the default for lasting material.
- **Where cards live is the user's choice per attachment:** local (default; with git, the commit-or-not
  question as today; without git, that question is skipped) or on Drive, shared with the team.
- **Editing a non-Google file:** Claude asks to convert it to Google format first; that is the default in
  folders whose purpose allows writes.
- **Stale-write guard:** Claude re-reads a file before updating it; when it changed since Claude last
  read it, warn. The card stores the update time (Drive gives no content hash).
- The plugin description changes from "not for creating or editing Google files" to read and write per
  folder purpose; some projects attach read-only folders only.

## Connector facts (tested 2026-11-16 against the claude.ai connectors)

- **Drive:** creates files (empty Google types or uploads), searches, reads as text, downloads, copies,
  renames, moves, locks, shares, trashes. `update_file` changes **metadata only**, never content. It can
  trash but **not restore**, and the Docs/Sheets connectors cannot open a trashed file.
- **Docs:** `read_doc` returns structure and a `revisionId`; `update_doc` (batchUpdate) edits in place,
  same file and link. `writeControl.requiredRevisionId` rejects a write when the doc changed since the
  read: the real guard. `replaceAllText` matches text, not positions. A reply's new revision id is not
  reused; read again before the next guarded write.
- **Sheets:** `get_values`, `update_values`, `append_values` edit in place. **No revision guard:** same
  cell, last write wins silently; prefer `append_values` on shared sheets.
- **Slides:** read and edit decks; **not tested.**
- **Office files in Drive** (.docx, .xlsx): readable as text (Docs `read_doc` even reads a .docx), never
  editable in place by any connector. Converting = upload again with conversion on: a **new file and a
  new link**; the original is kept or trashed (trash cannot be undone through the connector). Complex
  formatting, macros and tracked changes may not survive; exporting back to Office is untested.
- A connector that refuses every call ("requires additional permissions") needs reconnecting with full
  access before concluding it cannot do something.
- Load the `google-workspace` skill before the first call that creates or changes a Google file: it owns
  the *how* (positions, value parsing, helper scripts). remote-docs decides *what* and *where*.

## Context

- **Remote code in docs-manager 1.13.0** (uncommitted, PLUG-140/141): `scripts/external.sh` holds it
  interleaved with local externals: `REMOTE_PROVIDERS="gdrive artifact"`, `provider_data`, `remote_provider`,
  `is_remote_card`, `has_access_key`, `is_remote_copy`, `list_remote_copies`, `valid_rfc3339`,
  `list_remote_cards`, the remote and copy states inside `external_status` / `cmd_external_check`,
  `cmd_external_remote_stamp|copy_stamp|remote_gone|remote_diff|remote`, `remote_in_scope`, `source_of`.
  It uses `fm_field`, `fm_list`, `fm_set`, `docs_find` (with `DM_KEEP_IGNORED`) from `lib.sh`.
- **docs-manager outside external.sh:** `docs.sh` index lists remote cards with ☁ (`list_remote_cards`)
  and `list_docs` skips cards and copies; `links` checks remote cards' `relates-to:` (BROKEN REF).
- **Tests:** `external.test.sh` (773 lines) mixes local (E*, S*) and remote cases (RC*, RF*, LC*, AR*);
  docs/diagram/onboard suites have no remote cases.
- **Docs:** how-to-external-docs.md § *Remote documents*; plugin CLAUDE.md § *Remote cards*; SKILL.md
  trigger phrases for Drive and artifacts; root CLAUDE.md vocabulary list (docs-manager owns *remote card*,
  *Drive folder*, …).
- **Prior epic:** `docs-gdrive` (PLUG-110, completed); its decisions stand (no bytes through an MCP,
  scripts offline, one writer per stamp, never delete a gone card, ids and times compared as strings).

## Architecture

- **A1 Layout.** `remote-docs/` with `.claude-plugin/plugin.json`, `scripts/lib.sh`, `scripts/remote.sh`
  (CLI), `scripts/test/`, `skills/remote-docs/SKILL.md` + `references/how-to-remote-docs.md` (the moved
  *Remote documents* section), `CLAUDE.md`, `README.md`. No hooks. The CLI keeps the subcommands, renamed
  out of the `external` namespace: `remote.sh status|check|stamp|gone|copy-stamp|diff|list [root]`.
- **A2 What docs-manager keeps.** The name classifier only: its own `REMOTE_PROVIDERS`, `is_remote_card`,
  `is_remote_copy`, so `index` still lists cards with ☁, `list_docs` still skips cards and copies, and a
  card is never an orphan. `links` still checks a card's `relates-to:` (a link check, not a card check).
  Everything else remote leaves. `check` adds one non-failing line when remote cards exist:
  `REMOTE CARDS: N (validated by the remote-docs plugin)`.
- **A3 The contract is data.** File names `<name>.<provider>.md`, `<name>.<provider>.local.md`,
  `.source.md`; card fields `title`, `description`, `read-when`, `relates-to`. Each plugin carries the
  provider list and a contract test pinning the names and fields it reads. A new provider changes both
  lists; that is rare and accepted, and the alternative (classifying by frontmatter) breaks the
  "the name is the classifier" rule.
- **A4 Copied helpers.** remote-docs' `lib.sh` takes only what its code calls: the `fm_parse` family with
  `AWK_FM_COMMENT`, `fm_set`, `docs_find` + `drop_git_ignored` (keep-ignored is its default for cards),
  `normalize_path`, `write_if_changed`. Copies, not shared code (root CLAUDE.md, *Plugin Independence*).
- **A5 Root.** Default `docs`, overridable by the CLI argument, as docs.sh does. No new setting.
- **A6 Versions.** docs-manager 2.0.0 (commands removed: breaking); its README says where they went.
  remote-docs 1.0.0. Marketplace, root README, root CLAUDE.md plugin table and trigger vocabulary move the
  remote words (*remote card*, *Drive folder*, *refresh the Drive docs*, *local copy of a Drive doc*,
  *Claude artifact*) from docs-manager to remote-docs.
- **A7 Order.** PLUG-144 is a pure move and lands before any new behaviour, so its tests prove nothing
  changed. Purpose storage, writes and extraction are decided in their own sub-tasks.

## Scope

- New plugin `remote-docs`: the remote code, how-to and tests moved out of docs-manager.
- Folder purpose and scope; attachment questions extended (purpose, card location, no-git).
- Writing to Drive per purpose: stale-write guard, convert-on-edit.
- Cards on Drive, shared with the team.
- Extracting decisions from `truth: no` folders into `truth: yes` docs.
- Artifacts are already a provider: PLUG-141 shipped them in docs-manager 1.13.0 (`REMOTE_PROVIDERS="gdrive artifact"`,
  R9 extraction rule in the how-to); they move with the rest in PLUG-144.

## Out of Scope

- Attaching code or non-document files; anything outside the docs root.
- Exporting converted files back to Office formats.
- Splitting docs-manager further (diagrams, onboarding): the skill-size question is PLUG-139.

## Success Criteria

- docs-manager and remote-docs each pass their suites alone and together; a project with only one
  installed works.
- A teammate's Claude, in a fresh session, can tell from the docs what each attached folder is for and
  whether it may write there, without reading the folder's files.
- No write overwrites a teammate's change silently: a Doc write is guarded, a Sheet write is warned.
- A decision made in a collaboration file or artifact ends up in a `truth: yes` doc, and `check` says
  when a working file changed since the last extraction.

## Current State

Planning rows done (Context, Requirements, Architecture A1–A7, Subtasks). docs-manager PLUG-140/141 committed
as fd367c5, version left at 1.12.1 (user). **PLUG-144 (the split) completed**, pushed as
e4f7c7b. **PLUG-145 (purpose and scope), PLUG-146 (attachment questions), PLUG-147 (writing) and PLUG-148 (cards on Drive) completed.** Running the rest one by one (user, 2026-11-16: commit and
push each, no version bumps): PLUG-146, PLUG-147, PLUG-148, PLUG-149. Design for all of them: the approved
plan, recorded in each task's Requirements/Architecture as it starts.
