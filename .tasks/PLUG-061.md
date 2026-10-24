---
title: crew status shows which task each session works on; a second session on the same task gets a note
status: completed
type: improvement
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | see Context |
| 20 | Requirements | done | the user's decisions below |
| 30 | Assessment | done | see Context |
| 40 | POC | skipped | no unknowns |
| 50 | Domain | skipped | n/a |
| 60 | Architecture | done | see Design |
| 70 | Tests | done | task.test.sh, red before the code |
| 80 | Subtasks | skipped | one change |
| 90 | Implementation | done | crew 2.2.0 -> 2.3.0 |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | crew/CLAUDE.md rule, SKILL, playbook, READMEs, root trigger vocabulary |

## Description

Follow-up to PLUG-060, which made "one task, one session" a stated crew rule (wording only).
Nothing in crew links a session to its task yet: a task id is only a label on a hold
(`hold --task`) and a hand-off (`msg handoff --task`). This task makes the rule visible:

- `crew status` shows each session's task;
- a session that takes up a task another live session already owns gets a note naming the owner.

This needs new state (session → task), how it is set and cleared, and tests. That is why it was
split out of PLUG-060.

## Open questions

- How a session declares its task: `whoami --task`, a new `crew task <ID>`, or inferred from
  `hold --task` / `msg handoff --task`.
- A note or a denial when a second session takes the same task (crew denies only for git and holds today).

## Current State

See the end of the file.

## Context (2026-10-24)

- Rule wording (PLUG-060): `skills/crew/SKILL.md` non-negotiable 2, `references/playbook.md` §1,
  `README.md`. The coordinator assigns tasks; ownership moves by explicit hand-over.
- Session state: `<git-common-dir>/crew/sessions/<name>`, `key=value` lines (`sid role since display`),
  written by `whoami.sh` only, read with `sess_get`. Removed on `whoami --leave` and `crew end`.
- `crew_line` (lib.sh) renders "name role · …" for `status`, SessionStart and `whoami`: one place to
  show a task in all three.
- Task ids today: a label on a hold (`hold --task`) and a hand-off (`msg handoff --task`); `tree new <ID>`
  names a task worktree. No session -> task link.
- Precedents for "someone else has it": `hold` refuses (exit 1, names the holder, offers `chain`),
  `whoami --take` takes a role/name over explicitly.
- crew cannot read the task plugin (plugin independence): the session must say which task it is on.

## Decisions (the user's, 2026-10-24)

- A session declares its task with a new `crew task <ID>`; the coordinator assigns with `--for <name>`;
  `crew task --clear`; `tree new <ID>` sets it too.
- A second session taking an owned task is **refused** (like `hold`), naming the owner; `--take` moves
  it explicitly and mails the old owner.
- Claude's refinement, reported to the user: a *silent* owner is not taken over automatically. In a
  crew, "gone" means left (`whoami --leave`, `crew end`); silence is not leaving (this repo's crew had
  been silent 13 days and was still the crew). `--take` is always the explicit way.

## Design

- State: `task=` in `sessions/<name>`, written by `sess_set` (lib.sh, new: replace/add/remove one key),
  found by `task_owner` (lib.sh). `whoami` keeps it across a re-join; `--leave`/`end` remove it with the file.
- `scripts/task.sh` (dual-use): `task_assign <me> <target> <id> [take]` under the sessions lock; the CLI
  shows / sets / clears; `--for` is the coordinator's; ids pass `valid_name`; unknown options rejected.
- `crew_line` shows "<name> <role> on <ID>", so status, SessionStart, whoami and `crew active` agree.
- `tree new <ID>`: after the worktree is ready, `task_assign` for the caller; a refusal is printed,
  the worktree is still made.

## Results

- `crew task` shipped as designed; `crew status` reads "s2 worker on PLUG-7".
- `task.test.sh` 31 cases: red before the code (20 of 27 first, then the 2 `tree new` cases), green
  after; the re-join rule seen red by mutation. All crew suites green: host (723), `crew-test`
  container, standalone copy.
- Docs: crew/CLAUDE.md (one-task rule + state keys + layout), SKILL.md (worker line, non-negotiable 2,
  triggers "crew task", "which session works on which task"), playbook §1, crew/README.md, root
  README crew section, root CLAUDE.md crew vocabulary (+ crew task); plugin.json + marketplace 2.3.0.

## Current State (2026-10-24)

Implemented and verified; not committed.
