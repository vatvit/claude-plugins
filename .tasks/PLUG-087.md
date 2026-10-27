---
title: "kickoff — asks whether a project wants an E2E test viewer, and a gap rule that finds one wanted but missing"
status: approved
type: feature
priority: medium
related: [PLUG-088]
tags: ["kickoff", "quality", "e2e"]
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

A PoC in another project proved an **E2E test viewer** worth having (the user, 2026-10-27: *"PoC works good"*). The
user's need, verbatim (2026-10-25):

> i want to see the list of test cases and their run results (at least last)
> i want to be able to play any of them in my browser and see the result
> not "i am repeat the steps, but the programm repeat, and i an observer"
> i should be able to see details. maybe pause OR at least do not close after finish.

The user ruled that it goes into **kickoff**, not a new plugin, and that it covers both of kickoff's paths: a **new
project** gets it from its answers, and an **existing project** gets it when its gaps are closed after the survey.

**Optional, never imposed** (the user, 2026-10-27): *"each project MAY have. the Plugin can ask and provide instructions
how to reach that."* kickoff **asks** whether the project wants the viewer and, if yes, **gives the instructions** to
build it; no level makes it mandatory.

This task is the **question and gap half**: kickoff asks, records the answer, and `gaps.sh` reports a project that said
yes but has no viewer. The instructions themselves are [PLUG-088](PLUG-088.md); the two touch different files and can
run in parallel.

## Proposed shape (negotiable at Requirements)

- **A question, not a fixed check:** "Do you want an E2E viewer — every E2E test's last result in the browser, a
  step-by-step replay of a kept trace, and run-and-watch for any one test, local only?" Options yes / no / later. Where it
  sits is a Requirements question: a follow-up question after the quality level, or an optional (dropped by default) row
  in §Generic checks by aspect, aspect *Tests* — mind the catalogue's rule that no aspect has more than 4 non-fixed checks.
- **Asked only when E2E runs in a browser**; the questionnaire already branches on earlier answers.
- **A yes points at the instructions** (PLUG-088): in the charter, and as the "do it now / make it a task" content when
  the gap is closed.
- **A gap rule** in `scripts/gaps.sh`, `F2:"E2E viewer"*` (or wherever the check's answer lands), looking for evidence
  of a viewer. What counts as evidence is a Requirements question: a dev command (`dev.sh e2e:view`), a per-test result
  store, a reporter file. It must not match a plain Playwright HTML report, which is not the viewer.
- **Ports from kickoff's port registry** (`scripts/ports.sh`): the viewer and run-and-watch need two local ports. The PoC
  derived them from the app's port (app × 10 + 1, + 2); decide whether kickoff registers them as named ports or keeps
  the derivation.
- **Trigger phrases:** "test viewer", "e2e viewer", "replay a test", "watch a test run" — checked against the other
  plugins' vocabularies (root CLAUDE.md). delay owns "run the tests later"; this is about *seeing* runs, not timing them.

## Acceptance criteria (draft)

1. A project kicked off with browser E2E is asked the question; a yes lands in its charter with a pointer to the
   instructions, a no leaves no trace of the viewer; one without browser E2E is not asked.
2. `gaps.sh` on a project that answered yes and has no viewer prints one gap row with its evidence paths; once a viewer
   exists, or the answer is no, it prints nothing (seen red first, as every gap rule).
3. The two ports are allocated through the port registry, never hard-coded, and never collide with another project's.
4. Skill description, plugin.json, marketplace.json and the root README in sync (root CLAUDE.md §Changing an Existing
   Plugin); version bumped.
5. Tests pass on the host and in the Alpine container.

## Context

(collected at step 10)

- `kickoff/skills/kickoff/references/questionnaire.md` — levels, §Generic checks by aspect, F1/F2.
- `kickoff/scripts/gaps.sh` — the `F2:"E2E success path"*` rule is the nearest neighbour.
- `kickoff/scripts/ports.sh` — the port registry.
- The PoC's generic findings are listed in [PLUG-088](PLUG-088.md) §What the PoC settled.

## Current State

Proposed, 2026-10-27. Not started.
