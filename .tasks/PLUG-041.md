---
title: crew — field feedback from the first real night
status: in-progress
type: epic
epic-name: crew-feedback
priority: high
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

## Goal

Fix what the first real night of crew use showed (user feedback, 2026-10-09). Above all, a
dropped SendMessage must never again stall a crew for hours. The night had 6.5 h of silence
after the final hand-offs were lost at 02:56. Also make crew easy to adopt mid-project.

## Feedback → slice

| # | Feedback | Slice |
|---|----------|-------|
| 1 | Crew names can't contain spaces, but the skill says "use the name peers address you by" (e.g. "Max Coordinator") | display names + auto-join |
| 2a | Hand-offs lost with a dropped SendMessage | durable mailbox |
| 2b | Nothing noticed the stall | silence watchdog |
| 3 | The guard told the coordinator to "hand off your paths" | role-aware guard advice |
| 4 | No import path mid-project: hot spots in CLAUDE.md, holds in `_holds.md`, every worker has to run whoami | adoption: config set, holds import, adoption guide |
| 5 | `CREW_AS=… bash <long path>` on every call | `crew` on PATH, no CREW_AS |
| 6 | The guard blocks `git add --dry-run` (safe) | with #3 |

## Facts checked (Claude Code docs, 2026-10-09)

- A plugin's `bin/` is on the Bash tool's PATH while the plugin is enabled, after the user's
  own entries (claude.ai/Cowork do not install plugins with a top-level `bin/`).
- SessionStart input carries `session_title` when one is set (`--name`, `/rename`).
- `CLAUDE_ENV_FILE` is documented for SessionStart and turns the hook's `export` lines into a
  preamble for later Bash commands, but it is **not documented for plugin hooks**. A POC is
  needed.
- `additionalContext` is accepted by PreToolUse, PostToolUse and Stop, among others. The one
  documented way to wake an idle session is an `asyncRewake` hook that exits 2. Monitor waking
  an idle session is **not documented**. A POC is needed.

## Decisions (2026-10-09)

- The user's holds file is a **bullet list**, so the importer targets
  `- <path> — <holder> (…)`, tolerant of separators.
- The watchdog's default `silenceMin` is **15**, configurable.
- The mailbox **complements** SendMessage rather than replacing it. A message goes to both, the
  file copy is the durable one, and duplicates are cheap.

## Out of scope

- Converting the user's other project now. The user's own advice: don't switch the crew over
  while its last mile is finishing.

## Success criteria

- A hand-off whose SendMessage is dropped is still delivered: it waits in the mailbox, and the
  coordinator is told within `silenceMin`.
- A session titled "Max Coordinator" joins with no manual step and is addressed by that title
  in messages.
- Every crew call is `crew <command>`, with no CREW_AS prefix, wherever the env-file mechanism
  works.

## Sub-tasks
- PLUG-042: display names (spaces) + auto-join from the session title — #1, #4
- PLUG-043: bare `crew` command on PATH, no CREW_AS prefix — #5
- PLUG-044: durable mailbox — msg --send, inbox, unread notice, Stop check — #2a
- PLUG-045: silence watchdog — crew watch warns the coordinator — #2b
- PLUG-046: role-aware guard advice; allow git add --dry-run — #3, #6
- PLUG-047: adopt mid-project — config set, hold import, adoption guide — #4

Order and parallelism:
- **Independent, can start at once:** PLUG-044 (mailbox), PLUG-046 (guard) and PLUG-047
  (adoption). Their files don't overlap.
- **PLUG-042 and PLUG-043** both touch `session-start.sh` and `lib.sh` identity (`me`). Run them
  one after the other, PLUG-042 first, because the PATH slice resolves names that 042 defines.
- **PLUG-045** uses the mailbox for its "unread too long" check through `load_area`, so it can
  ship before or after PLUG-044.
- **Most urgent:** PLUG-044 + PLUG-045. They prevent a repeat of the 6.5 h stall.
