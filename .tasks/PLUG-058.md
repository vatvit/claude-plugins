---
title: "Diagram: task, docs-manager and crew — how they work together and the value each brings (one slide, made with Miro, also in the README)"
status: completed
type: docs
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | see Description |
| 20 | Requirements | done | Decisions (2026-10-16) |
| 30 | Assessment | skipped | docs only |
| 40 | POC | skipped | Miro tried and dropped |
| 50 | Domain | skipped | n/a |
| 60 | Architecture | skipped | n/a |
| 70 | Tests | skipped | docs only; claims reviewed against the plugins four times |
| 80 | Subtasks | skipped | one slide |
| 90 | Implementation | done | SVG + PNG + README, 82e83d9 / b3b43db |
| 100 | Tech Debt | done | PLUG-059 (where decisions live) |
| 110 | Reflection | done | nothing new to record |

## Description

The user, 2026-10-16: a diagram of the most valuable plugins — task, docs-manager, crew — showing
how they collaborate and the value each brings. One slide in the user's presentation, in English,
and the same picture in the root `README.md`.

The user generates it in Miro (the user runs Miro; Claude writes the prompt to copy-paste).

## Steps

1. Agree with the user what the diagram shows and how it looks.
2. Claude writes the Miro prompt; the user creates the diagram and exports it.
3. Claude adds it to the root README.

## Open questions

- What the diagram shows: the three plugins, their links, the value of each, the user's role.
- How it enters the README: an exported image committed to the repo (where, what format), and
  whether a text fallback (a mermaid block) is wanted for viewers without images.

## Decisions (the user's, 2026-10-16)

- Layout: left to right — docs-manager → task → crew → shipped work, with a "lessons" arrow back to docs-manager.
- Only the three plugins on the slide; the README already lists all seven.
- README: a PNG exported from Miro, committed to the repo and linked from the README.
- Focus (2026-10-16, later): the benefits of spec-driven development — the spec comes first and is agreed, every change traces back to it, it stays current, and parallel sessions build from the same spec. Each claim on the slide maps to a real feature: EARS requirements and the step order in the task workflow, acceptance criteria, task ids in commits, suspect diagrams and the reflection step, test-first copies and hand-offs in crew.

## Current State

Miro could not draw it, so the user dropped Miro (2026-10-16). The slide is a hand-written SVG,
`docs/images/spec-driven-development.svg` (16:9, 1600x900); the PNG beside it is rendered from it in
docker (alpine + rsvg-convert) for the presentation. The README embeds the SVG under "How they fit
together". Not committed. Next: the user reviews the slide; commit on their word.

Reviewed against the plugins (2026-10-16): three claims were wrong (docs-manager keeps decisions;
docs-manager decides goals/architecture; task has acceptance criteria) and four overstated. All
reworded with the user's agreement and re-rendered. The decisions conflict is PLUG-059.
Second review: the wording no longer presents conventions as guarantees (subtitle, banner, pill,
docs-manager rule); the crew box now says what crew enforces (guards) instead of the hand-off line.
Third review: the spec is split, system (docs) and change (task requirements), so the step labels are
THE SYSTEM / THE CHANGE; the crew guard claim narrowed to git commands + snapshots; arrow "approved
commits"; banner drops the commit part. README lead-in matches.
Fourth review: append-only starts at implementation, not when work starts; the docs-manager box says
"Rules:" again. Committed and pushed with the user's approval.

Reworded in the plugins' own terms (user, 2026-10-16: "use our terms, but highlight that task == spec"):
docs / task / workflow steps / reflection; the task box is highlighted as "task = spec". The crew line
"each on its own task" states the rule PLUG-060 adds to crew. Not committed.

Checked 2026-10-24: everything above is committed and pushed — SVG and README in 82e83d9, the PNG
(rendered from that SVG, added after it) in b3b43db. The slide's claims still match the plugins
(crew's "each on its own task" shipped with PLUG-060). The workflow table was never filled in; the
work went through the Steps above instead. Left: the user's word to mark this completed.

Completed 2026-10-24 on the user's word.
