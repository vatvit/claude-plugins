---
title: "kickoff — ends with questions about what to do next; never creates tasks the user did not pick"
status: completed
type: feature
priority: high
related: [PLUG-036, PLUG-087]
tags: ["kickoff-plugin"]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | A0 already says new vs existing; plan.sh --next would ask N before the docs — needs a gate |
| 20 | Requirements | done | gaps absorbed into N; tasks listed and confirmed before creation (the user) |
| 30 | Assessment | done | A0 decides N1/N2; no per-option conditions → two rows; a fact atom needed |
| 40 | POC | skipped | nothing uncertain: the grammar already has a fact atom (`<plugin> installed`) to copy |
| 50 | Domain | done | What next, §N, `charter written`, before-docs |
| 60 | Architecture | done | `charter written` fact atom; `plan.sh --before-docs` for scaffold; `charter_file` helper |
| 70 | Tests | done | scaffold 2n, 10a–10e; kickoff 1a; existing 4a fixture; all seen red, 3 plants red |
| 80 | Subtasks | skipped | one change set, one session |
| 90 | Implementation | done | 302 tests green on host, bash:5 and a standalone copy |
| 100 | Tech Debt | done | none filed; one edge case handled in prose (see Implementation) |
| 110 | Reflection | done | kickoff CLAUDE.md: §N waits for the docs; root CLAUDE.md trigger vocabulary |

## Description

The user noticed (2026-10-27) that after the questionnaire Claude **creates tasks to implement the whole
project**. The user expects instead: Claude documents everything collected, then **asks** which tasks to
create, asking about **tooling and infra** separately from **features and logic**. The user's ruling
(2026-10-27): *"let's the kickoff questionnaire finish with the list of questions of what to do next."*

### Why it happens today (review of kickoff 0.9.0)

- SKILL step 6 says *"create the first tasks that the output names with `/task create`"*. Nothing asks the user first.
- The list is named in two places, `scripts/scaffold.sh` (its `next:` line) and questionnaire §What the answers
  produce (*first tasks* row): agree the charter · architecture overview · dev harness **with the first vertical
  slice** and its checks · the E2E viewer. "Dev harness with the first vertical slice" mixes tooling with a
  feature, and "first vertical slice" with no stop rule invites Claude to break every milestone (B) into tasks.
- Step 7 (close the gaps) already asks per gap (do it now / make it a task / leave it), but creates its tasks on
  its own, separate from step 6. Two places create tasks.
- Context the user gives in chat that fits no question ID reaches no file; only answers and `.why` do.

### The agreed shape (the user, 2026-10-27)

**The questionnaire's goal is to collect information.** When it ends, Claude **writes the docs and fills them
from the answers without asking**: the charter, the quality doc, CLAUDE.md, and the rest of `docs/` through
docs-manager. Asking "write the docs?" makes no sense. What was said in chat that fits no question goes into the
docs too, so nothing lives only in chat. The *agree the charter* task is dropped (the review screen is the
agreement), and the architecture overview is a doc Claude writes in this step, not a task.

**Then one question: "What to do next?" (pick any).** Its options depend on the project:

| Option | New project | Existing (legacy) project |
|--------|:-----------:|:-------------------------:|
| **Infra/tooling tasks** — new: prepare the foundation for the future project (dev harness, containers, test runner and the F12 checks, CI, E2E viewer); legacy: close the gaps the answers expose (`gaps.sh` and the judged gaps of step 7) | yes | yes |
| **Features & business-logic tasks** — the app foundation and the start of its logic, from the goal, milestones and scope | yes | no |
| **Review the legacy code** — read the code against the answers and prepare tasks to adjust it where it contradicts them | no | yes |

Features and legacy review are opposites: one is never offered where the other is. Picking nothing creates no
tasks. **Kickoff never creates a task the user did not pick here.**

Dry run shown to the user and approved as the right questions (2026-10-27):
- New: *Infra/tooling tasks* · *Features & logic tasks*
- Legacy: *Infra/tooling gap tasks* · *Review the legacy code*

Decided: the question is **questionnaire rows** (parsed by lib.awk), so `plan.sh` lists it and an interrupted
kickoff resumes there.

### Open points (for Requirements/Assessment)

- **How the row knows new vs existing.** Today that is "the directory already has files" / `init` (step 0), not an
  answer. Likely two rows with conditions, or one row whose options carry conditions; it may need a recorded answer.
- **Step 7 (close the gaps)** today offers *do it now / make it a task / leave it* per gap. Does the infra/tooling
  option replace it, or does step 7 stay and feed the option?
- **Confirm the task list before creating?** Each picked option yields several tasks; Claude probably shows them
  and creates on the user's OK.
- **The 4-option limit** is not hit (2 options per project kind).

## Context

**Prior decisions (do not re-litigate):**
- PLUG-036 (deviation): kickoff never writes tasks itself; ids are the task plugin's. The scaffold *names* the first
  tasks and the skill creates them with `/task create`. This task keeps "the skill creates", but only what the user picks.
- PLUG-087: the E2E viewer (F13 = Yes) is "a first task" with its two ports (`ports.sh viewer`). It becomes a candidate
  of the infra/tooling option instead.

**New vs existing is already an answer: A0** (*Starting point?* ★ New, empty repo · Existing code, no setup · Existing,
partly set up, `always`). So open point 1 resolves without a new question: the What-next options follow `A0 = New`
vs `A0 ≠ New`. The grammar has no per-option condition, so that means **two rows** (one per A0 kind), each with
2 options; both multi-select.

**Timing is the real design problem.** `plan.awk --next` returns the first section that still has ask/judge rows, and
SKILL step 1 says "empty output → review screen (step 4)". A section N placed last would be asked *before* the review
and before any doc is written. The user wants it *after* the docs. Candidates for Architecture:
- a fact atom in the condition grammar, like `<plugin> installed` (lib.awk `atom()`, line 63): e.g. `charter written`,
  passed from lib.sh as `-v` the way `plugins` is (lib.sh `kickoff_awk`, line 76–80);
- or `plan.sh --next` skips a marked "after the docs" section until a flag (`--after`) asks for it.

**Where tasks are named today (all change, DRY):**
- `kickoff/skills/kickoff/SKILL.md:112–115` step 6 "create the first tasks that the output names"; step 7 (`:116–136`)
  close the gaps, with its own *make it a task* → `/task create` (`:131`). Two creators.
- `kickoff/skills/kickoff/references/questionnaire.md:347` (§What the answers produce, *first tasks* row) and `:289`
  (F13: "A Yes becomes a first task").
- `kickoff/scripts/scaffold.sh:94–95` prints `next: create the first tasks — agree the charter · architecture overview ·
  dev harness …` (+ the viewer).
- Tests pinning that line: `scripts/test/scaffold.test.sh:40` (2n, "agree the charter") and `:122` (7a, viewer named).

**Docs-writing step today** (SKILL 4–6): review screen → `charter.sh` → `scaffold.sh` (quality doc, CLAUDE.md, task
config/workflow) → docs-manager for the rest of `docs/`. There is no step that writes chat context with no question
ID, and none that writes an architecture overview; both are new.

**Tests:** `bash kickoff/scripts/test/all.sh` on host and `docker run --rm -v "$PWD":/w -w /w bash:5 bash
kickoff/scripts/test/all.sh`. Kickoff's CLAUDE.md: never copy question text into tests; assert through the real
questionnaire. `kickoff.test.sh` replays a client PoC kickoff and will see any new section.

**Parallel-session collisions:** crew lists a `claude-plugins-kickoff` worker, silent for ~18 days, no holds; no other
task in progress touches `kickoff/`.

## Acceptance criteria

- [ ] When the questionnaire ends, the docs are written and filled from the answers without a question; chat
      context that fits no question is in the docs.
- [ ] The *agree the charter* task is gone; the architecture overview is written as a doc, not made a task.
- [ ] Then exactly one multi-select "What to do next?" question: new project offers infra/tooling and
      features & logic; an existing project offers infra/tooling (gaps) and legacy-code review.
- [ ] No `/task create` happens for anything the user did not pick; picking nothing creates nothing.
- [ ] The question is questionnaire rows; `plan.sh --next` lists it after the docs step, and resuming works.
- [ ] The task candidates are named in one place (DRY): SKILL step 6, questionnaire §What the answers produce
      and `scaffold.sh`'s `next:` line no longer each list tasks.
- [ ] `scaffold.test.sh` 2n (pins "agree the charter") changes with it; suite green on host and `bash:5`.
- [ ] Version bump, marketplace entry, SKILL description and root README synced.

## Requirements

Agreed with the user (2026-10-27), on top of the shape above:
- **Step 7 (close the gaps) is absorbed into What next.** Its file-visible gaps (`gaps.sh`) are the existing project's
  infra/tooling option; its judged gaps (code contradicting an answer, a check nothing runs) are the legacy review.
  *Do it now* and *leave it* are gone; a gap the user does not want as a task is recorded with `<ID>.why`.
- **Claude lists the tasks of each ticked option and creates them only on the user's OK.**

## Architecture

- **Section N** in the questionnaire, after K: **N1** (`A0 = New and charter written`) and **N2** (`A0 ≠ New and
  charter written`), both `(pick any)` with **CREATE —** / **REVIEW —** labels, Goes to *the tasks Claude creates*
  (no generator routes it). Nothing ticked is `None`. The grammar has no per-option condition, hence two rows.
- **`charter written`**, a new fact atom in `lib.awk` `atom()`, beside `<plugin> installed`. `lib.sh kickoff_awk`
  passes `-v written=1|0` from the new `charter_file <root>` helper, which `charter.sh` now uses too (it spelled the
  path three times).
- **`plan.sh --before-docs`** passes `-v written=0` after kickoff_awk's own, so it wins. `scaffold.sh` checks open
  questions with it: the docs must be writable while N is open.
- `scaffold.sh` no longer names tasks; its `next:` line says to write the rest of the docs and then ask what next.

## Implementation

- `kickoff/scripts/lib.awk`, `lib.sh`, `plan.sh`, `charter.sh`, `scaffold.sh` as above.
- `questionnaire.md`: §N; the CREATE/REVIEW labels; `charter written` in §Reading the tables; F13's Yes is a candidate
  of N's tooling option; §What the answers produce: *tasks — only those the user picks in §N*.
- `SKILL.md`: step 6 writes the docs without asking, including `docs/project/architecture.md` and
  `docs/project/notes.md` (chat context no answer holds); step 7 is What next and the only place tasks are created;
  the old step 7 is gone. Version 0.10.0, trigger phrases added.
- **Bug found by the tests:** with N1 open, `scaffold.sh` refused to run ("questions are still open"), so the docs
  could never be finished. Fixed with `--before-docs`; pinned by scaffold 10a2.
- **Test that proved nothing:** the first 10a (empty `--next` before the charter) stayed green with the gate removed,
  because `autofill` answers N1 `n/a` when offered. It now reads N1's state (`skip`).
- **Plants, each red:** `scaffold.sh` without `--before-docs` (10a2); N rows without `charter written` (10a, 10b,
  10e); N1 routed to the charter (10c).
- existing 4a's fixture now answers N1: a finished kickoff includes What next. Consequence, stated in the README: a
  project kicked off before 0.10 is asked *what to do next* once on its next kickoff run.
- **Edge case, handled in prose:** when a charter exists from an earlier run, an N row can appear in step 1 before
  the review; SKILL step 1 says to go to the review then. No script change.
- Synced: `plugin.json` and marketplace (0.10.0, description), kickoff README, root README, kickoff CLAUDE.md, root
  CLAUDE.md (trigger vocabulary). Not committed.

## Current State

Implementation complete: 302 tests green on host, `bash:5` and a standalone copy. Not committed, not pushed (waiting
for the user). Next: commit on the user's word.
