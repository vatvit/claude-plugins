---
title: crew — machine-wide slots: a heavy run in one repo queues against another repo's
status: completed
type: feature
epic: crew-solo
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done |  |
| 20 | Requirements | done | below |
| 30 | Assessment | done | slot.sh, watch.sh, msg.d, status.d read the file |
| 40 | POC | skipped | no unknowns |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | CREW_HOME/slots; ours = field 15 |
| 70 | Tests | done | crosscrew.test.sh, seen red |
| 80 | Subtasks | skipped | small |
| 90 | Implementation | done |  |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | crew/CLAUDE.md, root CLAUDE.md |

## Description

Slots live in `<git-common-dir>/crew`, so they only order runs inside one repo. The CPU, memory and Docker
they protect belong to the machine. Two crews in two repos on one Mac each grant a `cpu` slot at once and
slow each other down. Session names are already machine-wide (`~/.claude/crew/`), so slot state of the
machine kind fits the repo's "Per account or per machine" rule: it guards a machine resource, so it lives
in `~/.claude/crew/` and ignores `CLAUDE_CONFIG_DIR`.

## Requirements (negotiable)

- Machine-scoped queue for the classes that contend for the machine (`cpu`, `exclusive`; decide `quiet`
  at Architecture), or a separate cross-repo class. Settle which at Architecture.
- `slot` and `status` show a waiting request's blocker by session name **and repo**, with an ETA.
- Stale entries from a repo whose crew is gone are reaped, as per-repo slots are today.
- Open: does a **solo** session (repo with no crew) take part? Today "no crew, no cost" means its hooks do
  nothing. Probably an explicit `crew slot` call from a solo session still queues, with no hooks added.

## Acceptance criteria

- Two fixture repos, each with a crew: a `cpu` slot held in A makes a `cpu` request in B wait, and B's
  output names A's holder and an ETA. Releasing in A grants B.
- A repo-local class (if any remain) still does not block across repos.
- Machine-wide state lives under `~/.claude/crew/` (tests override HOME), never in a committed path.
- Suite green on host and `bash:5`, and from a copy of `crew/` alone.

## Notes

- Files: `crew/scripts/slot.sh`, `lib.sh`, `status.d/`, `scripts/test/`, skill reference on slots.

## Outcome (2026-10-17, crew 2.2.0)

- The queue is `$CREW_HOME/slots` (+ `.seq`, lock via the new `with_lock_at`): per machine, like the
  name registry. Rows carry the owner's crew id (field 10); `slots_plan` adds `ours` (field 15).
- **Decision (the coordinator's, differs from the request):** class rules are unchanged, now across
  repos. `exclusive` and `quiet` block every run on the machine; `cpu` still overlaps `cpu`, since that
  is what the class means. The field case (heavy runs) is `exclusive`. The test is "an exclusive slot in
  A makes a cpu request in B wait, with an ETA".
- Per-crew decisions stay per crew: `release` only this crew's slots (another crew's is refused, naming
  it); `slot clear` and the push hold only see this crew's quiet slot; `watch` reports only this crew's
  stale slots. Another crew's row shows as `name [crew]`.
- Reaping: `reg_live` (factored out of `reg_other`, the one liveness rule) — a slot whose owner left,
  was replaced or whose crew vanished is dropped under the lock on request, start and list.
- **Decision (open question settled):** a session in a repo without a crew does not queue; it joins a
  crew of one (`whoami … coordinator`), keeping "no crew, no cost". Documented in slots.md and solo.md.
- An old per-repo `.git/crew/slots` is ignored (slots last minutes; no migration).
- Tests: `slots.test.sh` reads the machine file; `crosscrew.test.sh` gains 11 checks. Seen red with the
  file moved back per repo (9 failing) and with reaping disabled.

## Current State

Completed. Host, `bash:5` container and a sibling-free copy of `crew/`: ALL GREEN.
