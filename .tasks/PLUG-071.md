---
title: docs-manager — survey a legacy project's docs and build docs/ from them
status: proposed
type: feature
epic: legacy-onboarding
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | — | |
| 20 | Requirements | — | |
| 30 | Assessment | — | |
| 40 | POC | — | |
| 50 | Domain | — | |
| 60 | Architecture | — | |
| 70 | Tests | — | |
| 80 | Subtasks | — | |
| 90 | Implementation | — | |
| 100 | Tech Debt | — | |
| 110 | Reflection | — | |

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

## Current State

Proposed 2026-10-17 (epic PLUG-070). Not started.
