---
title: crew — a session outside the crew works as usual; membership is opt-in; no dead-end commit guard
status: completed
type: bug
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | another project: the only session was put in its crew as a worker by the session-title auto-join (PLUG-042), and committer=coordinator then denied its commit and push with no coordinator present |
| 20 | Requirements | done | user, 2026-10-14: a crew may exist without every session in it; non-members work as usual |
| 30 | Assessment | done | two causes: auto-join on SessionStart; guards treat an empty NAME as a worker |
| 40 | POC | skipped | the fix is a gate on NAME plus one message |
| 50 | Domain | skipped | no new concept: membership already means sessions/<name> |
| 60 | Architecture | done | gate in the hooks (pre-bash, pre-edit holds); way-out text in land.sh guard_reason; crew CLAUDE.md design rule |
| 70 | Tests | done | names, land, holds suites; red before the fix (holds 2, land 10, names 5) and again under mutation |
| 80 | Subtasks | skipped | one small slice |
| 90 | Implementation | done | crew 1.5.1 -> 1.6.0; 475/475 on host bash 3.2 and on bash:5 |
| 100 | Tech Debt | done | none added |
| 110 | Reflection | done | crew CLAUDE.md, SKILL.md, README, references/land.md updated |

## Description

With `committer=coordinator`, the commit guard denies every `git commit` from a worker and says
"Hand off instead: … msg handoff". It never checks whether a coordinator **exists**. When the crew
has none, the hand-off goes to nobody, and the session cannot commit at all.

**How it happened (2026-10-10, this repo, installed crew 1.0.1; the same code is in 1.5.1):**
- The user ran **one** Claude session in the repo. `session-start.sh` auto-joined it as a
  **worker** (a titled session joins as a worker; the coordinator role is an explicit choice).
- The crew list still held `claude-plugins-kickoff worker`, a session last active on 2026-10-09
  that had ended. Nobody was the coordinator.
- The user asked to commit and push. The guard denied the commit and pointed to a hand-off with no
  recipient. To get past it, the session took the coordinator role
  (`crew whoami <name> coordinator --take`) and committed with `crew land` (4117df7).
- The user: "worker of what? you are the only session". A crew of one silently runs under rules
  meant for several sessions.

**Where:**
- `crew/scripts/land.sh`, around line 48: the `commit` deny, which is also `instead()` for `add`.
- `crew/hooks/session-start.sh`: the join line says the role and `(<c> coordinates)` only when one
  exists. It does not warn when there is none.
- `coordinator()` in `crew/scripts/lib.sh` returns the configured coordinator, even if that
  session is gone.

## Requirements (user, 2026-10-14)

Same incident again on 2026-10-14 in another project: the lone "Feature Adapter" session was auto-joined
as a worker at start, a `old-coordinator` entry from 2026-10-12 was still listed, and the
session could not commit or push. The user: "the Crew plugin can be enabled, but the Crew itself
can be absent — the sessions should work as usual", and "the crew can be created, but not all
sessions on this project can be added to the crew. non-crew should work as usual".

This replaces the earlier proposal (still deny, better message) and its open question.

## Acceptance criteria

- **Membership is opt-in.** SessionStart never joins a session, titled or not; only
  `crew whoami <name>` does. (Reverses the PLUG-042 auto-join.)
- **A non-member works as usual** in a repo that has a crew: no git-guard denial (`add -A`,
  `commit` without a coordinator, `push`, …) and no holds / hot-spot denial on edits. (Reverses
  PLUG-027's "unnamed sessions are denied on held paths and unheld hot spots" and the land guard's
  "unnamed session: treated as a worker".) Snapshots still run, since they are invisible and protect
  members.
- SessionStart tells a non-member, in one line, that the repo has a crew, that its guards do not
  apply to it, and how to join if it is meant to be part of it.
- **Members keep every guard.** When a member worker is denied a commit or push under
  `committer=coordinator` and the crew has no coordinator, the message says so and names the way
  out (`crew whoami <you> coordinator --take`, or ask the user) instead of a hand-off to nobody.
  With a coordinator, the message is unchanged.
- README / SKILL.md / crew CLAUDE.md updated; version bumped and synced to marketplace.json.
- The suite passes on the host and in the container; each new check was seen red.

## Implementation (2026-10-14)

- `hooks/session-start.sh`: no auto-join. A non-member gets one line: the crew exists, its guards do not apply, and `crew whoami` joins it only if the user says so.
- `hooks/pre-bash.sh`: the git guard runs only for a member (`[ -n "$NAME" ] || exit 0`).
- `hooks/pre-edit.sh`: the holds and hot-spot guard run only for a member. Snapshots and claims still run for everyone.
- `scripts/land.sh` `guard_reason`: with no coordinator, commit, push, rebase and similar denials name the way out (`crew whoami <name> coordinator`, or ask the user) instead of `msg handoff`.
- Tests: `names.test.sh` (opt-in membership), `land.test.sh` (non-member allowed; a solo member gets the way out, and taking the role works), `holds.test.sh` (non-member on a held path and on a hot spot).
- Version: crew 1.6.0 (`plugin.json`, `marketplace.json`).

## Current State

Implemented and verified. All 12 suites green (475 checks) on the host and in the crew-test image. Reverting the gates or the way-out text turns exactly the new checks red. Not committed; status is still proposed until the user decides.
