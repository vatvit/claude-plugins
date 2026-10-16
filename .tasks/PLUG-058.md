---
title: "Diagram: task, docs-manager and crew — how they work together and the value each brings (one slide, made with Miro, also in the README)"
status: proposed
type: docs
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
