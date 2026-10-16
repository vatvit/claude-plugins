---
title: kickoff — docs skeleton carries the SOLID/DRY docs conventions
status: proposed
type: feature
epic: kickoff-next
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

## Current State

Proposed, backlog for the next kickoff release (epic PLUG-049). Not started.
