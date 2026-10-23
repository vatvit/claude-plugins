---
title: docs-manager — survey a legacy project's docs and build docs/ from them
status: completed
type: feature
epic: legacy-onboarding
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | below |
| 20 | Requirements | done | the four in the task, settled below (Decisions) |
| 30 | Assessment | done | docs.sh sources one file per concern; lib.sh has the link parser, relpath, block_rewrite to reuse |
| 40 | POC | skipped | no risky unknown: git mv and link rewriting proven directly by tests |
| 50 | Domain | skipped | bash plugin, no domain model |
| 60 | Architecture | done | below (Decisions) |
| 70 | Tests | done | scripts/test/onboard.test.sh, 29 cases |
| 80 | Subtasks | skipped | one plugin, one change |
| 90 | Implementation | done | survey.sh, docs.sh wiring, how-to-onboard.md, SKILL.md, README, manifests; 1.8.1 -> 1.9.0 |
| 100 | Tech Debt | done | PLUG-083 |
| 110 | Reflection | done | plugin CLAUDE.md (survey.sh section, testing), root CLAUDE.md trigger vocabulary |

## Description

On a legacy project, docs-manager finds where documentation lives today, shows it to the user as a plan,
and on approval builds a `docs/` tree that follows its conventions — as if docs-manager had kept the docs
from the start.

## Requirements (negotiable)

1. **Survey (read-only script).** List every doc-like source with its kind and size: `README*`,
   `CHANGELOG`, `CONTRIBUTING`, `doc/`, `docs/`, `documentation/`, `wiki/`, ADR folders, `*.md`/`*.rst`/
   `*.adoc`/`*.txt` outside dependency and build dirs, OpenAPI/AsyncAPI files, `docker-compose*`,
   `Makefile`/CI files (as sources for *how to run/build/test*), existing `CLAUDE.md`/`AGENTS.md`.
   Writes nothing. Respects `.gitignore` and skips `node_modules`, `vendor`, `.git` and the like.
2. **Plan.** For each source, one action: *move into `docs/`*, *link from `docs/` and leave in place*
   (README stays at root), *external reference* (`docs/external`, existing catalogue flow), or *ignore*.
   Plus the docs to **write** from the code where nothing exists: overview, architecture, how to
   run/build/test. The user approves or edits the plan; nothing is touched before that.
3. **Build.** Apply the approved plan: moves via `git mv` when in git (history kept), frontmatter added,
   inbound links rewritten, `_index.md` regenerated, link check clean. Docs written from code say where
   each fact came from and flag what is inferred, never invented.
4. **Idempotent.** A second run on an onboarded project proposes nothing new.

## Acceptance criteria

- A generated fixture legacy project (scattered docs, a `doc/` folder, a README with run instructions,
  one dead link) → survey lists every source; after an approved plan, `docs/` exists, `_index.md` files
  are generated, the link check passes, and moved files keep their git history.
- Without approval, the project tree is byte-identical after the run.
- Second run: no proposed changes.
- Suite green on host and `bash:5`, and from a copy of `docs-manager/` alone.

## Notes

- Invoked as `/docs-manager:docs-manager init`: SKILL.md gains a "Commands" section routing the `init`
  argument to this flow (the skill reads no arguments today). The `description:` triggers get natural
  wording in docs-manager's own words, never bare *init* (built-in `/init`) or *adopt* (crew).
- Reuse the existing external-docs catalogue (`references/how-to-external-docs.md`) for material the
  project does not own, rather than a second mechanism.
- Files: `docs-manager/scripts/` (new survey script, maybe in `docs.sh`), `skills/docs-manager/SKILL.md`
  plus a new `references/how-to-*.md`, `scripts/test/`. Disjoint from PLUG-072.

## Context

- Epic PLUG-070: docs-manager owns `docs/` content and layout; kickoff (PLUG-072) only reads it.
  Invoked as `/docs-manager:docs-manager init`; never a bare *init* trigger (built-in `/init`), never
  *adopt* (crew's word).
- `docs-manager/CLAUDE.md` is the source for what must not regress. Relevant to reuse: `md_link_dests`
  / `doc_links` (the one link parser), `relpath`, `normalize_path`, `md_dest` (every written link),
  `block_rewrite` + markers, `write_if_changed`, `docs_find` (docs tree only, PLUG-079),
  `EXTERNAL_EXTS` and the `docs/external/` drop zone (`how-to-external-docs.md`).
- Container `bash:5` has no git; the host has. The crew plugin's `crew-test` image has bash 5 + git and
  was used once to run the git cases in a container as well.
- SKILL.md frontmatter `version:` had drifted (1.7.1 while the plugin was 1.8.1); set to 1.9.0.

## Decisions

- **Two commands in a new `scripts/survey.sh`**, sourced by `docs.sh`: `survey [project]` (read-only,
  prints the plan) and `onboard <plan> [project]` (applies it). The plan *is* the survey output,
  tab-separated `action kind source destination bytes`, edited by Claude with the user and written to a
  temp file outside the project.
- **Actions:** `move`, `link`, `ignore`, `adopt` (under `docs/`, no frontmatter), `write` (a doc to write
  from the code; reported only), `cite` (build/CI files as evidence; never acted on). "External
  reference" from the requirements is a `move` into `docs/external/`, not a fifth mechanism: the
  existing card flow takes over from there.
- **Handled = under `docs/` with frontmatter, or linked from a doc under `docs/`.** `link` and `ignore`
  rows are written as links into a sources block in `docs/_index.md` (own markers). That is the only
  record, it is guarded by `links`, and it makes the second survey empty. `write`/`cite` rows only
  before the first onboard.
- **Conservative defaults:** a doc folder (`doc/`, `documentation/`, `wiki/`, ADR folders) moves
  wholesale with its images; a root-level doc moves; a doc beside code is linked; an office file
  outside a doc folder is `ignore` (it may be served by the app); `*.txt` only inside doc folders.
- **`onboard` validates the whole plan first**; one bad row, nothing changes. Unknown action = error.
- **A dead link is left as written** in a moved file, so the report names the author's link.

## Tests

`docs-manager/scripts/test/onboard.test.sh` builds a fake legacy project (README with run
instructions, `doc/` with an image, a vendor PDF and a name with spaces and parentheses, a root
`ARCHITECTURE.md`, an ADR folder, module docs, OpenAPI, CI/compose/Makefile, `node_modules`, a
dot-folder, one dead link). Cases: S1–S5 survey (exact plan, writes nothing), P1–P4 plan check,
O1–O12 onboard (moves, links both ways with fragment, frontmatter, indexes, sources block, report),
A1–A3 after onboarding (Claude's follow-up done, `check` clean, second survey empty, second onboard
changes nothing), D1–D2 adopt, G1–G3 git (`.gitignore`, `git mv` keeps history).

Seen red: O2 (emptied folder left after `mv`), O12/A1 (dead link "corrected" to the old place) before
their fixes; A2 with the linked-is-handled rule removed.

## Results

- `onboard.test.sh`: 29/29 host; 26 + 3 skipped (no git) in `bash:5`; 29/29 in `crew-test` (bash 5 +
  git); 29/29 from a copy of `docs-manager/` alone.
- `diagram.test.sh` 100/100 and `external.test.sh` 91/91, host and `bash:5`, and from the copy.
- Read-only `survey` on this repo: 63 rows, sensible defaults, tree unchanged.

## Current State

Implemented 2026-10-23: docs-manager 1.9.0, all steps done; not committed (awaiting the user). Debt: PLUG-083.
