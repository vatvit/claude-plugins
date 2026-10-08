---
title: crew — cross-crew isolation: crew id in messages, machine-wide unique names
status: completed
type: feature
epic: crew
priority: high
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | raised by the user mid-epic; identity lives in lib.sh/whoami.sh (PLUG-026) |
| 20 | Requirements | skipped | ACs specific enough |
| 30 | Assessment | done | state already per repo; only names + message tags cross crews |
| 40 | POC | skipped | no unknowns |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | see Architecture |
| 70 | Tests | done | `crew/scripts/test/crosscrew.test.sh` (15 checks) |
| 80 | Subtasks | skipped | small |
| 90 | Implementation | done | 97/97 host + docker |
| 100 | Tech Debt | done | none filed |
| 110 | Reflection | done | crew CLAUDE.md design rule, SKILL rule 8, config.md, README; 0.3.0 |

## Description

Raised by the user on 2026-10-08: someone can run several crews, for example one coordinator per
repo. Each crew's state is already per repo (`<git-common-dir>/crew/`), but **names are not
scoped.** Two crews can each have an `s1` or a `coord`, and SendMessage / ListAgents address
sessions across the whole machine. So a hand-off meant for one crew's coordinator can reach the
other crew's coordinator, which may act on it.

- **Crew id:** the project key `crewId`, defaulting to the repo folder name. It appears in the
  SessionStart line and in every `msg` header (`[<id>] s2 → s1: HANDOFF`).
- **Machine-wide name registry** `~/.claude/crew/names/<name>` (root, crew id, sid). `whoami`
  refuses a name that a live session in another crew holds, and suggests `<crewId>-<name>`.
  A stale entry (the other crew's session is gone or rebound) is taken over silently. `--leave`
  removes the entry.
- **Skill rule:** a crew message whose `[id]` is not your crew is not acted on; tell the sender
  it reached the wrong crew.

## Acceptance criteria

- [ ] Two repos: `s1` joins crew A. Then `s1` joining crew B is refused, naming crew A and
      suggesting `B-s1`. `--take` overrides.
- [ ] After A's `s1` leaves, or its binding is gone, B can take `s1` with no flag.
- [ ] Every `msg` header carries `[<crewId>]`; the SessionStart line names the crew.
- [ ] `crewId` from `.crew.json` overrides the folder name; a `crewId` in the user file is ignored
      (it is project-only).
- [ ] The suite passes on the host and in docker.

## Architecture

- `crew_id` (lib): project key `crewId` (project-only), else the repo folder name, sanitised to
  name characters. Used by `msg_head` (`[<id>] from → to`), the SessionStart lines, the status header.
- Machine registry `$CREW_HOME/names/<name>` (default `~/.claude/crew`): `state= crew= sid=`.
  `reg_other` reports a **live** owner in another crew: its `sessions/<name>` still has that sid.
  A stale entry (session file gone, or rebound to another sid without a registry update) is
  taken over silently. `whoami` writes it on bind, `--leave` and renames drop it.
- Decision (the coordinator's, i.e. this session's, under the user's ask): refuse + suggest
  `<crewId>-<name>` rather than auto-prefixing names — the crew name must equal the SendMessage
  name, which the user picks, so the plugin cannot rename sessions.

## Implementation

`lib.sh` (crew_id, reg_*), `whoami.sh`, `msg.sh`, `status.sh`, `session-start.sh`;
`crosscrew.test.sh` 15/15; full run 97/97 on host and in `crew-test`.

## Reflection

Design rule added to `crew/CLAUDE.md`; SKILL rule 8 (never act on another crew's message);
`config.md` `crewId` row; README naming advice. Plugin 0.3.0.

## Current State

Completed. Build green.
