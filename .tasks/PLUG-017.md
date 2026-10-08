---
title: docs-manager external docs — card format + index integration
status: completed
type: feature
priority: medium
epic: external-docs
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | docs-manager CLAUDE.md forbids a config file — see Context |
| 20 | Requirements | skipped | ACs in the task are specific enough; no EARS needed |
| 30 | Assessment | done | `list_docs`/`build_block` are the only index touch points |
| 40 | POC | skipped | no risky unknown — find + awk, same shape as diagram.sh |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | new `scripts/external.sh`, sourced like diagram.sh |
| 70 | Tests | done | `scripts/test/external.test.sh` E1–E4 |
| 80 | Subtasks | skipped | small enough |
| 90 | Implementation | done | 39/39 + diagram 100/100, host + bash:5 standalone |
| 100 | Tech Debt | done | none filed — see Implementation |
| 110 | Reflection | done | plugin CLAUDE.md, README, SKILL.md, reference |

## Description

Define the card that sits beside an external file and make it show up in `_index.md`.
Format per the epic's Design section. Base for every other sub-task.

## Acceptance criteria

1. Card format documented in the skill (one home — a reference file or SKILL.md section).
2. A hand-written card for a sample pdf appears in the folder's `_index.md` with its
   `description`; the binary itself is not listed separately.
3. `docs.sh links` resolves a link from a project doc to a card and to the binary.
4. Layout per the epic: externals under `docs/external/<topic>/`; the root is a single
   optional `.docs-manager.json` key with default `docs/external`. `docs/external/_index.md`
   lists topic folders like any other docs folder.
5. Test in `scripts/test/` covers 2–4; passes on host bash 3.2 and bash:5 container.

## Context

**Epic:** PLUG-016 (`external-docs`); this task is the base the siblings build on.

**Prior decision overridden (do not re-litigate):** `docs-manager/CLAUDE.md` states that
`DOCS_MANAGER_ROOT` is the plugin's *only* setting — "Do not grow it into a config file", and the
render port was already de-specced from a config key for the same reason. The epic's
`.docs-manager.json` / `externalDir` key (AC 4) contradicts that, and was agreed without knowing the
rule. Resolved by following the plugin rule: `<root>/external/` is a **fixed convention**, and the
extension list is built in. Root stays overridable exactly as today (the `[root]` argument).

**Code touched:**
- `docs.sh` — `list_docs` (excludes cards), `build_block` (new section), `cmd_check`, dispatcher.
- New `scripts/external.sh`, sourced like `diagram.sh`, uses `lib.sh` (`fm_field`, `fm_set`).
- Existing suite `scripts/test/diagram.test.sh` (100 cases) guards index/links — must stay green.

**Parallel-session collisions:** none — no other task in progress.

## Architecture

- **Card = `<file>.md` beside the file.** The name is the pairing; the epic's `source:` key was
  dropped as a second record of the same fact.
- **Index:** cards leave `### Documents` and appear under `### External documents` as
  ``[`spec.pdf`](spec.pdf.md) — <card description>``; an uncarded file is listed linking to
  itself with `_(no card yet)_`. The section is emitted only when a folder has externals, so
  existing `_index.md` files regenerate byte-identical (no DRIFT on upgrade).
- A `.pdf` (etc.) beside a same-named `*.diagram.md` is a render artifact, not external.
- One home for the card format: `skills/docs-manager/references/how-to-external-docs.md`;
  SKILL.md points at it and states no rules, matching the other references.

## Implementation

- `scripts/external.sh` — `EXTERNAL_EXTS`, `is_external_name`, `is_card`, `list_externals`,
  `list_cards`. The same file also holds the status/stamp/move code of PLUG-018/019, written in
  one pass because they share these helpers; each is verified and closed under its own task.
- `docs.sh` — sources it; index section; `check` now includes `external check`.
- Tests E1–E4 in `scripts/test/external.test.sh` (AC 2, 3, 4 + artifact exclusion + idempotence).
- Results: `external.test.sh` 39/39 and `diagram.test.sh` 100/100, on host bash 3.2 and on
  `bash:5` from a standalone copy of the plugin directory.
- AC 4 met by convention instead of a config key (see Context).
- Version 1.5.0 → 1.6.0 in `plugin.json`, `marketplace.json`, `SKILL.md`; description and
  keywords synced. One bump covers the whole epic slice (017–019) — nothing ships in between.

## Reflection

**Plugin CLAUDE.md:** layout, a `scripts/external.sh` section with its don't-regress list (incl.
why there is no config key), the reference row, test commands.
**Docs:** README "External docs" section + usage lines; SKILL.md pointer section;
`references/how-to-external-docs.md` (card format, layout, commands).
**Lesson:** read a plugin's own CLAUDE.md before agreeing a design for it — the config key was
agreed at epic level and contradicted a recorded rule.

## Current State

Done; all ACs met (AC 4 by convention). Nothing committed yet.
