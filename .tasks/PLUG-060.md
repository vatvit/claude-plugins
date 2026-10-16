---
title: crew — one task, one session; parallel work means separate tasks (wording in skill, references, scripts, slide)
status: completed
type: improvement
priority: high
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | "slice" is undefined and appears only in crew (skill, 4 references, land.sh die text); crew knows a task id only as a label on holds and hand-offs; the split tool already exists in the task plugin (subtasks step and epics) |
| 20 | Requirements | done | the user, 2026-10-16: "finish if no question" accepted the proposed wording (drop slice; the rule stated once; explicit hand-over) and the crew status view as a follow-up (PLUG-061) |
| 30 | Assessment | done | wording only: skill, 4 references, one die message, one comment; no test asserts on any of it |
| 40 | POC | skipped | wording |
| 50 | Domain | skipped | no new concept: the split tool is the task plugin's sub-tasks |
| 60 | Architecture | skipped | no code structure changes |
| 70 | Tests | done | new wording.test.sh (5 checks): red before the change (5 of 5), and red again when "slice" is put back in land.sh |
| 80 | Subtasks | skipped | the crew status view went to PLUG-061 instead |
| 90 | Implementation | done | crew 2.0.0 -> 2.0.1; 497/497 on host bash 3.2 and on bash:5 |
| 100 | Tech Debt | done | none added; PLUG-061 is a follow-up feature, not debt |
| 110 | Reflection | done | crew CLAUDE.md design rule; crew README and root README crew bullets; plugin.json and marketplace.json descriptions and version; SKILL.md triggers |

## Description

The user, 2026-10-16: "parallel sessions on the same task makes no sense and will work wrongly"
and "wording is very important".

Several sessions on one task cannot know which part of its scope is built. Nothing records it:
- the task file's workflow table tracks *steps* (requirements → … → implementation), which run in
  order for one task — it says nothing about which parts of the scope are done;
- crew tracks *files* (holds, claims, snapshots); a task id on a hold, hand-off or commit message
  does not say "part A done, part B not";
- a split the coordinator makes ("you do the parser, you do the CLI") lives only in chat messages
  and is lost on `/compact` or a restart;
- both sessions would write the same task file (workflow table, Current State), unguarded.

The task plugin already has the right tool: the `subtasks` step and epics with sub-tasks. Each
part becomes its own task, with its own scope, table and Current State; "what is done" is each
sub-task's status.

crew's wording points the other way. **"slice" is never defined**, and every use of it reads as
"a piece of a task, shared out between sessions":
- `crew/skills/crew/SKILL.md` — description ("handing off a finished slice"), lines 46, 49, 71–72
  ("One commit holds one task and one slice")
- `crew/skills/crew/references/playbook.md` — 18, 39, 53, 56
- `crew/skills/crew/references/land.md` — 6, 30
- `crew/skills/crew/references/copy-apply.md` — 3
- `crew/skills/crew/references/holds.md` — 25
- `crew/scripts/land.sh:146` (a user-visible die message), `crew/scripts/msg.d/holds.sh:22`
- the slide `docs/images/spec-driven-development.svg` — crew box "build slices of one spec",
  arrow "slices to sessions", pill "Parallel work, one spec" (the user does not like this pill;
  "one spec" is also false: each task is its own change spec)

## Proposal (to agree before coding)

1. **The rule, stated once** (SKILL.md non-negotiables + playbook §1): *one task, one session.
   A task in flight has one owner session at a time. To work on a task in parallel, split it into
   sub-tasks first (the task workflow's `subtasks` step); each session owns one.* The coordinator
   assigns tasks, not parts of tasks.
2. **Define or replace "slice".** Either define it once — *a slice is one verified, committable
   increment of the task the session owns; one commit holds one slice* — or drop the word for
   "increment" / "change". Wording to agree with the user before any edit.
3. **Hand-off of ownership** (a task moving from one session to another, e.g. a session stops) is
   explicit: the old owner updates Current State and says so; never two owners at once.
4. **Optional, mechanical:** `crew status` shows which task each session works on (holds already
   carry `--task`); a second session taking a hold with the same task id gets a note. Decide
   whether this is in scope or a follow-up.
5. **Slide**: crew box and arrow say tasks, not slices ("tasks to sessions"); the pill is
   replaced — candidates: "Parallel sessions, one tree", "Many tasks, many sessions".
6. Sync: plugin.json version + description, marketplace.json, SKILL.md trigger phrases, crew
   README, root README if the crew section mentions slices.

## Context

**Prior decisions (do not re-litigate):**
- PLUG-055: membership is opt-in; a non-member works as usual.
- PLUG-057: by default nobody in the crew commits (`committer=human-approved`) or pushes
  (`push=human`). The coordinator assigns work and lands it, but closes a task only after landing.
- The task plugin already covers splitting work: the `subtasks` step ("Break into sub-tickets")
  and epics with sub-tasks (`task/skills/task/references/epics.md`). crew must point at it, not
  invent a second way of splitting.

**Where "slice" appears.** It is not defined anywhere, and every use is in crew (none in `docs/`,
the READMEs, the task plugin or crew's tests):
- `crew/skills/crew/SKILL.md`: the description ("handing off a finished slice"), and lines 46, 49, 71–72
- `crew/skills/crew/references/playbook.md`: 18, 39, 53, 56
- `crew/skills/crew/references/land.md`: 6, 30
- `crew/skills/crew/references/copy-apply.md`: 3
- `crew/skills/crew/references/holds.md`: 25
- `crew/scripts/land.sh:146`: a die message ("one task, one slice, task id in it"). No test asserts on it.
- `crew/scripts/msg.d/holds.sh:22`: a comment only.

**What crew already knows about tasks.** It knows only a task id, and only as a label:
- `hold --task ID` stores the id (holds.sh field 4), and `holds_list` shows it through `hold_desc`;
- `msg handoff --task ID` puts it in the hand-off;
- `land` requires a commit message but never checks it for a task id;
- `status` has no per-session task line (its parts are holds, inbox, slots, watch).

Nothing links a session to "its" task. So point 4 of the Proposal would be new state, not a new
view of existing state.

**Docs:**
- The slide `docs/images/spec-driven-development.svg` and the root README already say "each on its
  own task" (uncommitted, PLUG-058's rewording). That wording runs ahead of crew until this task lands.
- The playbook rule (§8) that only the coordinator changes task status fits "one owner session per
  task". The coordinator owns the status and the worker owns the work.

**Tests:** run `bash crew/scripts/test/run.sh` on the host, and in docker with `crew-test` (see
`crew/CLAUDE.md`, Testing). A wording-only change touches no assertion.

**Parallel-session collisions:** none. The other in-progress task (PLUG-034, the kickoff epic) and
the proposed PLUG-049–052 and PLUG-059 touch no crew files. This repo's crew (a delay coordinator
and a kickoff worker) has not claimed crew paths. Re-check `git status` before editing.

## Open questions

- Keep "slice" with a definition, or replace it? Which word?
- Is a crew-side check (point 4) part of this task or a follow-up?
- The slide pill: which wording?

## Answers (2026-10-16)

- "slice" is dropped, not defined. Each use now says what it meant: "change", "each change in a
  copy", and "one commit holds work for one task only" (a task may take several commits).
- The `crew status` view of each session's task (Proposal point 4) is a follow-up: PLUG-061.
- The slide pill is "Parallel sessions, one tree", settled during PLUG-058's rewording.

## What changed

- SKILL.md: new non-negotiable 2 (one task, one session), renumbered 3–9. The coordinator assigns
  each task to one session, and the worker works only on its assigned task. Description and
  trigger phrases added ("assign tasks to sessions", "two sessions on one task", "split work between sessions").
- playbook.md §1: the rule and why it holds, plus the explicit hand-over (a task never has two
  owners at once).
- "slice" replaced in playbook.md, land.md, copy-apply.md, holds.md, `land.sh` (die message) and
  `msg.d/holds.sh` (comment).
- New `crew/scripts/test/wording.test.sh`.
- crew 2.0.1: plugin.json and marketplace.json; crew README; the root README crew bullet; a
  crew CLAUDE.md design rule.

## Current State

Implemented and verified: 497/497 on host bash 3.2 and on bash:5. Not committed. It goes with the
uncommitted PLUG-058 rewording (slide and README), whose crew line "each on its own task" is now
backed by crew. Next: the user approves the commit.
