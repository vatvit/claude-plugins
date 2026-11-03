---
title: "crew: the coordinator reviews where the crew's time goes, from time to time, and acts on it"
status: completed
type: feature
priority: medium
deps: [PLUG-097]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 5 | Research | done | the one-off's notes in this task; watch.sh's finding pattern |
| 10 | Requirements | done | as Acceptance; the reminder rule lives in time.sh, watch only reports it |
| 70 | Tests | done | time.test.sh reminder block (6), red first; mutants |
| 90 | Implementation | done | time_review_due, watch finding, 2 config keys, SKILL.md duty, references/time.md |
| 110 | Reflection | done | watch.md, config.md, crew CLAUDE.md |

## Problem

A user running a crew (a coordinator and three workers, several days) asked the coordinator how long each session
works and how long it waits for results, apart from waiting for the user. The answer was very useful to them: it
showed where the crew loses time and led straight to changes in how the crew works. They want this to be a standing
duty of the coordinator, done from time to time, not a one-off answer.

Depends on PLUG-097 (`crew time`, the measurement and the slot history it needs). This task is the coordinator's
side: when to run it, how to read it, what to do with it, and how to report it.

## What the one-off did (reference for PLUG-097 and this task)

**Source.** Each crew member's Claude Code transcript (`<config dir>/projects/<project key>/<session id>.jsonl`).
Only entries of type user/assistant, with a timestamp, not sidechains (subagents), sorted by time.

**Rule.** Every gap between two consecutive entries is charged to what ended it:
- an assistant entry: Claude working (an upper bound: it includes the model's own latency);
- a tool result: waiting for that tool. A Bash `slot run` mixes the slot queue and the run itself in one call;
  other Bash (docker, test runs, benches) is "a process running";
- a background job's task notification: map its task id back to the Bash call that started it (the call's result
  says "with ID: <id>"); a background slot run is split like a foreground one;
- a cross-session message: classify by the KIND in its header `[<crew>] <from> → <to>: <KIND>`:
  - the shared tree: GATE, QUEUE, HOLD, HOT, RELEASE, RELEASED, COLLISION, LANDED, HEAD, SEAM;
  - a decision: DECISION, AGREED, GO, OK, YES, ANSWER, ACK, ASSIGN, USER, and task-id kinds;
  - otherwise a peer's work: HANDOFF, STATUS, QUESTION, RESULT, DONE, DESIGN, REQUEST, INFO, FYI;
- a summary continuation: compaction;
- anything else from the user role: waiting for the user.

**Pitfalls the one-off hit:**
- The slot queue and the run cannot be split afterwards: `slot run` prints no times, and the slots file keeps only
  live slots. Recovered only partly, from `RUNNING since HH:MM` lines that happened to be printed, and from test
  output durations. A third of the workers' wait stayed "queue or run, unknown". PLUG-097 adds a slot log.
- Overnight idle lands in "waiting for a peer" or "waiting for the user", and swamps multi-day totals. Report a
  window (today, since HH:MM), or cut gaps above a threshold.
- The local timezone offset was passed by hand and once set wrong: the window began an hour early. Take it from
  the system.
- Docker keeps no container events here to cross-check run times.
- The member's name was found by grepping its `whoami` call. Use crew's own session record instead (PLUG-097).
- Print categories and tool names only, never transcript content (it holds the project's data).

## Findings worth knowing (one crew, one day, generic)

- Workers: Claude working 16–20 % of the time; a process running and the slot queue together 40–70 %; waiting for
  a peer's work or a decision most of the rest. Coordinator: about 6 % working, most of its time idle until a
  worker reports (holds nothing up).
- Holds and landings cost almost nothing (about 0.2 h a day for the whole crew).
- The machine is the bottleneck: the slot queue is shared with other crews on the machine, and their exclusive
  slots held ours back for over an hour.
- Waiting does not spend tokens. The cost is per wake-up: each wake re-reads the conversation (cheap within the
  prompt-cache lifetime, full price after it expires). Many short polls cost more than one wait-until.

## Levers the analysis led to (for the coordinator's playbook)

- Workers run only the checks their change touches in their copies (unit checks, the E2E files they touched); the
  coordinator's one full gate on the shared tree checks everything, on a batch of landings. Trade-off: a failure is
  found later, in the coordinator's gate, and must be traced to the hand-off that caused it.
- Group hand-offs so they land and gate together.
- Run the slow E2E only when a change touches what it covers.
- Prefer waits that end on an event over polling.
- When another crew's slots dominate the queue, say so to the user with the ETA.

## Acceptance

- The crew skill's coordinator role lists the duty: review the crew's time with `crew time` from time to time —
  at least once a working day and after a long stretch of queue waits — and act on it.
- A reference (e.g. `references/time.md`) holds how to read the categories, the pitfalls above, and the levers,
  so the coordinator does not re-derive them.
- The report to the user is short: one table per member (working, a process running, the slot queue, the shared
  tree, a decision, a peer's work, the user), the window it covers, what is uncertain, the bottleneck, and the
  levers proposed. A lever that changes how the crew works is proposed to the user first.
- `crew watch` (or the coordinator's routine) reminds the coordinator when the review is due.
- Nothing in the report or the reminder prints transcript content.

## Implementation (2026-11-03)

- **The duty.** SKILL.md's coordinator role: review where the crew's time goes with `crew time` at least once a working
  day and after a long stretch of queue waits, report to the user, propose levers, never apply one that changes how the
  crew works without the user's word. Trigger phrases: "crew time", "where does the crew's time go", "how long do the
  sessions wait", "time review".
- **`references/time.md`.** The command, the categories and what each means, what is uncertain, the one-off's pitfalls,
  the levers (as a "the table shows → lever" table), the report's shape, the config keys.
- **The reminder.** `time_review_due` (time.sh, the one place the rule lives) → `watch`'s finding `review:time`, so
  `watch --wait` wakes the coordinator: no `crew time` for `timeReviewHours` (24; counted from the crew's first join when
  there was none), or this crew's slots waited `timeReviewQueueMin` (60) in the queue since the last review (slot log,
  start - requested, own crew only). `0` turns a rule off. Every `crew time` run stamps `$STATE/time-reviewed`.
- Nothing in the reminder or the report prints transcript text (`crew time` prints numbers only; PLUG-097).

**Tests.** time.test.sh "the coordinator's review reminder": a young crew is not reminded; after 25 h it is; running
`crew time` clears it; 65 min of this crew's queue waits remind early; another crew's waits do not; `timeReviewHours 0`
turns it off. Red first (2 fails before the code). Mutants: no stamp → 3 red; other crews counted → 2; hours 0 not off → 1.
watch.test.sh unchanged and green.

