---
title: "kickoff — instructions for reaching an E2E test viewer: the per-test result store, the trace whitelist, the viewer page and run-and-watch"
status: proposed
type: feature
priority: medium
related: [PLUG-087]
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

The **instructions half** of the E2E test viewer in kickoff; the question and gap half is [PLUG-087](PLUG-087.md) (the
user's need and rulings are quoted there). The viewer is optional (the user, 2026-10-27: *"each project MAY have. the
Plugin can ask and provide instructions how to reach that."*). When a project says yes, or closes that gap, kickoff
**gives it the instructions**: what to build, in what order, and the pitfalls the PoC already hit, so the project does
not rediscover them. Whether kickoff also ships ready-made files is a Requirements question, not the default.

**Start after the PoC's hardening pass.** The PoC is getting a structured bug hunt in its own project, which ends with a
"safe to generalise" verdict per generic part. Writing the instructions before it would pass its bugs on to every
project. Context and Requirements can start now; Implementation waits for the verdicts.

## What the PoC settled (generic — any Playwright project in Docker)

The user's rulings that shaped it:
- **Watching a new run is the main view.** A replay is a trace stepped at the user's pace, with nothing re-run. **No video.**
- **One stored result per test, overwritten by its next run** (passed / failed / flaky / skipped + when). No history.
- **A trace is kept only for a failed or flaky test, or a test on the whitelist**, toggled in the viewer, local to the
  machine, never committed. A test that passes and is not whitelisted loses its trace. Flaky counts as failed.
- **Local only:** every port published on `127.0.0.1`, because a trace holds the app's pictures and the viewer writes.

What it took:
- **A reporter writing one file per test on the final attempt, atomically**, so a run killed half-way still leaves every
  finished test's result. A trace is hard-linked into the store, not copied.
- **The whitelist read by the config at run start**, turned into a second project with `grep` / `grepInvert` and
  `trace: 'on'`; with an empty list the config is exactly the gate's. Tracing every test and deleting the passes was
  rejected: a trace measured ~45 MB median.
- **Playwright's trace viewer served from `playwright-core/lib/vite/traceViewer/`** on the same origin as the traces.
- **UI mode in a container:** `--ui-host 0.0.0.0 --ui-port <p>`, published on `127.0.0.1` only. UI mode runs **every**
  reporter of the config, so the report paths must be movable (an env var), or it overwrites the gate's reports.
- **Long-lived containers** by `docker compose run -d --rm --name … --publish 127.0.0.1:<p>:<p>`, no compose edit.
- **A canvas app** (WebGL) shows in a step's pane only with "Display canvas content" on (Playwright 1.50+, off by
  default); with it off, only in the screencast thumbnails. Below 1.50, black.
- **A CLI `--reporter=…` replaces the config's reporters**, so such a run feeds no store unless the store reporter is
  named too.
- **Named steps:** without `test.step()` a trace is a flat list of low-level calls; worth recommending in the template.
- **Pin the image and the package together.**
- **Pausing a live run** needs a headed browser with the Inspector on a virtual display (noVNC); the PoC left it as a
  follow-up.

Project-specific in the PoC, **not** to template: its dev lock, its night-gate folder layout, its script dispatcher, its
port numbers, its Playwright upgrade.

## Proposed shape (negotiable at Requirements)

- **A reference in kickoff** (e.g. `skills/kickoff/references/e2e-viewer.md`): the goal in the user's words, the
  pieces (result store reporter, whitelist as a second project, served trace viewer, UI mode in a container,
  `127.0.0.1` ports), the order to build them in, acceptance scenarios a project can turn into its tests, and the
  pitfalls above. Claude follows it in the project; kickoff points at it from the charter and the gap row.
- **Language-neutral where it can be:** the pieces are Playwright concepts; the PoC's code is TypeScript. Decide at
  Requirements how a non-Node E2E stack (Playwright for Python / .NET / Java) is served: the same instructions with
  that runner's equivalents, or "not covered".
- **Ready-made files only if Requirements asks for them** (`kickoff/templates/e2e-viewer/`, copied by `scaffold.sh`,
  never run by kickoff, which stays bash + awk). Instructions first; files are a later step if projects keep rebuilding
  the same code.

## Acceptance criteria (draft)

1. Following the instructions in a fresh fixture project with Playwright E2E in Docker gives a working viewer and
   run-and-watch on `127.0.0.1` ports from the registry, with its own tests passing in Docker — proved once, by a
   Claude session that had only the instructions.
2. The instructions' scenarios cover: a run killed half-way leaves every finished test's result; a passing
   non-whitelisted test keeps no trace; a whitelisted one does.
3. The charter (PLUG-087's yes) and the gap row point at the instructions; a project that said no gets nothing.
4. kickoff's suite passes on the host and in the Alpine container; docs and versions synced.

## Context

(collected at step 10)

- `kickoff/scripts/scaffold.sh`, `kickoff/templates/` — how kickoff writes files today.
- `kickoff/scripts/ports.sh` — the port registry.
- [PLUG-087](PLUG-087.md) — the check and the gap rule this scaffold closes.

## Current State

Proposed, 2026-10-27. Context and Requirements may start; Implementation waits for the PoC's hardening verdicts.
