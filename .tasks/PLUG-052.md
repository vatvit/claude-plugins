---
title: kickoff — docs skeleton carries the SOLID/DRY docs conventions
status: completed
type: feature
epic: kickoff-next
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done |  |
| 20 | Requirements | done | SOLID reading adopted as proposed |
| 30 | Assessment | done | descriptions already one-purpose, no TODO |
| 40 | POC | skipped | no unknowns |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | convention in docs-manager SKILL.md |
| 70 | Tests | done | scaffold.test.sh 2r, seen red by mutation |
| 80 | Subtasks | skipped | small |
| 90 | Implementation | done |  |
| 100 | Tech Debt | done | K1-skip noted on PLUG-072 |
| 110 | Reflection | done | docs-manager README |
## Description

SOLID and DRY matter for how the documentation is organised, too, not only for code. docs-manager
already enforces DRY ("define once, link everywhere", single source of truth). Nothing enforces the
SOLID side, and the docs skeleton kickoff seeds (K1) gives each folder only a title.

Proposed reading of SOLID for docs, to agree at Requirements:
- **S** — one doc, one purpose and one audience. Each folder's `_index.md` states its purpose.
- **O** — grow the set by adding docs and links, not by rewriting a settled doc.
- **L** — docs of one kind (decision, how-to, architecture) follow one shape, so any of them reads the same way.
- **I** — readers get entry points that fit them, not one mega-doc everyone must read.
- **D** — docs depend on the canonical source: link to the decision, never restate it.

## Open question (settle at Architecture)

**Where does the convention live?** It applies to every docs set, not only kicked-off ones, so its
natural home is **docs-manager's conventions**, and kickoff's part is only the seeding: every
`_index.md` gets a one-line purpose, so S holds from day one. If it goes to docs-manager, split this
task, or move that part to a docs-manager task. Plugin independence: kickoff must keep working without
docs-manager.

## Acceptance criteria (draft)

- A fresh scaffold writes an `_index.md` per folder whose `description` states that folder's single
  purpose (no `TODO` for the standard folders).
- The SOLID/DRY docs conventions are written down **once** (in docs-manager or kickoff, not both) and
  linked from where they are needed.
- Seeded files that already exist stay untouched.

## Notes

- Files: `kickoff/scripts/scaffold.sh` (`index_md` calls), `scripts/test/scaffold.test.sh`. This is
  disjoint from PLUG-050, but shares `scaffold.test.sh` with PLUG-051, so coordinate if both run at
  once. The docs-manager part would touch only docs-manager.

## Outcome (2026-10-17, docs-manager 1.8.0 + kickoff 0.6.0)

- **Decision (the open question):** the convention lives in docs-manager's SKILL.md §Conventions,
  as "SOLID for docs" (S, O, L, I); the existing DRY bullet carries *D* ("link to the decision,
  never restate it"). Written once; kickoff does not restate or link it, so it works without
  docs-manager. The SOLID reading was adopted as proposed in this task.
- kickoff's seeded `_index.md` files already had one-purpose descriptions and no TODO; test 2r now
  pins it (described, distinct, no TODO; seen red with a TODO description). Existing seeded files stay
  untouched (3c).
- Not done here: skipping K1 when `docs/` predates kickoff (PLUG-070's decision). charter.sh creates
  `docs/project/` before scaffold runs, so it needs a "docs predate kickoff" rule — noted on PLUG-072.
- docs-manager 1.7.1 → 1.8.0 (plugin.json, marketplace.json, README, trigger "how should the docs be organised").

## Current State

Completed 2026-10-17. Host, `bash:5` container and a sibling-free copy: ALL GREEN.
