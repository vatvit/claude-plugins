---
title: "crew time: where each crew session's wall time went (working, waiting for tools, the machine, the crew, the user)"
status: completed
type: feature
priority: medium
deps: [PLUG-090]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 5 | Research | done | transcript shape read (keys and counts only, no content): wake-ups are user entries with origin.kind human / peer / task-notification; queued_command attachments arrive mid-turn and are ignored |
| 10 | Requirements | done | as Acceptance; sid history added (a /clear changes the id) |
| 70 | Tests | done | time.test.sh (23), red first; mutants |
| 90 | Implementation | done | time.sh, time.awk, slot log, whoami sid history |
| 110 | Reflection | done | crew CLAUDE.md layout + rule; reading guide is PLUG-098's references/time.md |

## Problem

A user running a crew asked how long each session (the coordinator and every worker) spends with Claude working and
how long it waits for results (tools, test runs, the slot queue, background jobs, other sessions), apart from waiting
for the user. Today that needs an ad-hoc script over the session transcripts.

How a one-off version measured it, its pitfalls and what it found: PLUG-098, *What the one-off did*. PLUG-098 is
the coordinator's duty that uses this command.

## Acceptance

- `crew time [--since HH:MM|DATE]` prints one table per crew session (by crew name), and a crew total: Claude working,
  waiting for tools / the machine (slot queue, runs, background jobs), waiting for the crew, waiting for the user,
  compaction.
- It finds each member's transcript by the session id crew already records; a session not in the crew is not read.
- Long idle gaps (overnight) can be cut off by a threshold, so they are not counted as waiting.
- Waiting is split by what the session waited for: a process running, the slot queue, the shared tree (a hold, a
  gate, a land), a decision from a peer, a peer's work, the user. A `slot run` mixes queue and run time in one tool
  call, and crew keeps no slot history, so the split cannot be recovered afterwards. So slots get a history: every
  request, start and finish is appended with its time to a slot log, and `crew time` reads it.
- Prints no transcript content; tests on a generated transcript.

## Implementation (2026-11-03)

- **`crew time [--since HH:MM|YYYY-MM-DD|"YYYY-MM-DD HH:MM"] [--idle MIN]`** (`time.sh`; parsing and arithmetic in
  `time.awk`, two stages: events → sort → report). Default window: today from 00:00 local; gaps over 30 min are
  shown as "idle, not counted". One table: a row per category, a column per member and the crew, `h:mm` and %.
- **Transcripts.** Found by session id under `$CLAUDE_CONFIG_DIR`, `~/.claude` and every `~/.claude*/` (`projects/*/<sid>.jsonl`),
  so a crew spread over accounts is read. `CREW_TRANSCRIPTS` replaces the search (tests).
- **Session ids.** `whoami` now appends `name sid since` to `$STATE/sids` when the id is new for the name; `crew time`
  reads that history plus each current `sessions/<name>` sid, so a member's /clear or restart is merged.
- **Slot history.** `slot.sh` appends `time event <row>` to `$CREW_HOME/slots.log` for request, start, done, cancelled,
  released, reaped (dropped); trimmed to `CREW_SLOT_LOG_KEEP` (10000) once past twice that. A `slot run` gap (foreground,
  or a background one via its task id) splits at the slot's start into the slot queue and a process running; no start found
  → "slot: queue or run, unknown".
- **JSON without a parser.** Escapes dropped first (`\\`, then `\"`), split on quotes, odd parts are structure: braces there give
  depth; top-level keys at depth 1 (`type`, `timestamp`, `isSidechain`, `isMeta`, `isCompactSummary`), `origin.kind`, and
  in `message` the tool ids, names, Bash command and `tool_use_id`. Timestamps converted in awk (days-from-civil), no date calls.
- **Categories.** assistant → Claude working; tool_result → by its tool (Bash: `slot run` → queue/run, `crew land|hold|apply|release`
  → the shared tree, else a process; Agent/Task → a process; others → a tool); task-notification → the category of the call that
  started it; peer → by the KIND of the crew header (tree / decision / a peer's work, PLUG-098's lists); compaction; human → the
  user. Sidechain and other meta entries are skipped. Only categories and numbers are printed.

**Tests.** `time.test.sh` (23): a generated transcript per member with a known timeline (foreground run, `slot run` split by
the slot log, background slot run via its task id, a tool, a land, a peer DECISION and HANDOFF, an idle hour, a compaction, a
sidechain entry, an attachment, a string with unbalanced braces after an escaped quote, a secret that must not print), `--since`,
`--idle`, a second session id, a bad `--since`, an empty window, a member without a transcript, the slot log and its trim.
Red first. Mutants each go red: no slot split (2), sidechain counted (3), no idle cut (12), no escape handling (3), no
background mapping (2), no decision kind (2), no empty-window line (1). Host and container green.

**Found by the smoke run on this repo's crew** (aggregates only): a member with no transcript ended `time_files` with status 1
and `set -e` killed the command silently (the root CLAUDE.md pitfall). Reproduced in the test (a member w2 with no transcript),
fixed with `return 0`. After it, the real run read 1153 entries in ~0.15 s.

**Limits.** "Claude working" includes the model's latency (an upper bound). A Bash command is classified by its text, so a
script that calls crew indirectly counts as a process. Sessions joined before this version have only their current id.

