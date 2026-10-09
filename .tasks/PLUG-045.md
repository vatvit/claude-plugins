---
title: crew — silence watchdog: crew watch warns the coordinator
status: completed
type: feature
epic: crew-feedback
priority: high
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | epic PLUG-041; mailbox (PLUG-044) landed first, so the mail check is live |
| 20 | Requirements | done | acceptance criteria below |
| 30 | Assessment | done | stamps fit the PostToolUse hook from PLUG-044; no new hook entry |
| 40 | POC | done | background `watch --wait` wakes an idle session — verified; see references/watch.md |
| 50 | Domain | skipped | no new domain terms |
| 60 | Architecture | done | see Architecture |
| 70 | Tests | done | watch.test.sh, 30 checks, red on HEAD first |
| 80 | Subtasks | skipped | one slice |
| 90 | Implementation | done | applied at 4182186; both targets ALL GREEN |
| 100 | Tech Debt | done | PLUG-044 json_esc dedup folded in; see Tech Debt |
| 110 | Reflection | done | crew/CLAUDE.md design rule; references/watch.md |

## Description

Feedback #2b. Nothing noticed 6.5 h of silence.

- **Activity stamps:** every crew hook touches `<state>/seen/<name>`, using builtins only.
- **`crew watch [--once]`:** one line per finding, built for the Monitor tool, `/loop`, or a
  background run by the coordinator. A finding is any of:
  - a session silent for more than `silenceMin` (default 15) while it holds a hold, has a slot,
    or has dirty paths;
  - mail unread for more than `silenceMin`;
  - a stale slot.
  Each finding names the session and the next step.
- **POC: what wakes an idle coordinator?** Candidates are a Monitor event, an `asyncRewake` hook
  (exit 2, the only documented idle wake) and `/loop`. Record what works and make it the
  documented setup in `references/watch.md`.
- `status` shows each session's last activity.

## Acceptance criteria

- [ ] With a fake clock: a silent session that has a hold appears in `watch --once` after
      `silenceMin`, and not before. An idle session with nothing held does not appear.
- [ ] Unread mail older than `silenceMin` is reported, when the mailbox is installed.
- [ ] POC outcome and the recommended coordinator setup are documented.
- [ ] Hooks stay fork-free on the no-crew path.
- [ ] Suites pass on host + docker.

## Notes

The mail check uses the mailbox slice through `load_area`, so this slice also ships without it.

## Context

- The stall in the first crew night lasted 6.5 h because nothing measured silence. The mailbox (PLUG-044, c099bca) makes lost hand-offs durable. This slice makes a silent crew visible and wakes the coordinator.

## POC: what wakes an idle coordinator (2026-10-09)

- **Docs** (code.claude.com hooks and tools reference):
  - An `asyncRewake` command hook that exits 2 is the one hook documented to wake an idle session, and Claude Code enforces its `timeout`.
  - Monitor events are not documented to start a turn while idle, and a watch ends after 30 min at most.
  - `/loop`, `ScheduleWakeup` and cron fire while idle, but each tick costs a turn.
- **Verified.** A Bash `run_in_background` running `crew watch --wait` on a scratch crew, with `silenceMin` 1 and a silent session holding a file:
  - started at 10:29:47;
  - the session went idle;
  - the watcher exited 2 at 10:30:49 with the finding;
  - the session was re-invoked with the finding's output.
- **The coordinator's documented setup** is in `references/watch.md`: keep `crew watch --wait` running in the background, and restart it after each wake.

## Architecture

- **Stamps.**
  - `fast.sh` gains `crew_fast_sid` (shared with `crew_fast_unread`) and `crew_fast_seen`. `crew_fast_seen` writes `: > <state>/seen/<sid>`, a redirection on a builtin, so no fork. Its mtime is the activity time.
  - `hooks/mail.sh` calls it on PostToolUse and Stop, which fire for every tool. `pre-edit.sh` and `pre-bash.sh` are untouched.
  - `whoami` and SessionStart stamp on the slow path (`watch_stamp`) and create `seen/`.
- **Area `scripts/watch.sh`.**
  - Functions: `last_seen`, `watch_owns`, `watch_findings`, `watch_status`, `watch_stamp`.
  - CLI: `watch [--once | --wait] [--every SEC]`.
  - Each finding is `<key>\t<text>`. The loop remembers a key and repeats it only after `silenceMin`. `--wait` exits 2 at the first finding.
  - The mail check uses `mail_ids`, `mail_field` and `mail_count` only when `declare -F` finds them, so watch degrades without `inbox.sh` (tested).
- **Stale slots.** The rule now lives once, as field 13 of `slots_plan`. `slot_line` and `watch` both read it; before this, `slot_line` computed it inline.
- **`silenceMin`.** Config key, default 15, in `CREW_KEYS`/`cfg_default` in lib.sh. A non-numeric value falls back to `cfg_default`.
- **lib.sh gains two helpers.**
  - `file_mtime`: GNU/busybox form first, because busybox `stat -f` prints filesystem info to stdout even while failing. That was a latent bug in `with_lock`'s stale-lock age, and `with_lock` now uses the helper.
  - `json_esc`: one escaper for `hook_block` and the mail hooks. This is the PLUG-044 tech debt.
- **`status`** gets the part `status.d/watch.sh`: `activity: <name> Nm ago … (silent after Nm)`.

## Tests

`crew/scripts/test/watch.test.sh` has 30 checks on a fake clock (`CREW_NOW` = the stamp time + N minutes):
- stamps on join, on a tool call (fork-free, under `PATH=""`) and on SessionStart;
- silence with a hold is reported after `silenceMin` and not before;
- an idle session that owns nothing is never reported;
- `silenceMin` is configurable and is a config key with default 15;
- a slot and claimed dirty paths count as owning work;
- unread mail older than `silenceMin` is reported;
- a stale slot is reported with its release command;
- status shows activity and exits 0;
- the loop prints one line over three rounds;
- watch runs without `inbox.sh`.

`mailhook` moved from `inbox.test.sh` into `helpers.sh`, since both suites use it.

- **Red on HEAD (c099bca):** 6 passed, 24 failed, starting with `FAIL joining stamps the session`.
- **Deliberate bugs caught:**
  - The "owns something" filter removed: FAIL "an idle session with nothing held is not reported".
  - The loop's dedup removed: FAIL "three rounds, one line".
  - `crew_fast_seen` made a no-op: FAIL "a tool call stamps the session". That check first passed vacuously, because whoami had already stamped; the test now removes the stamp first.
- **Bugs found on the way, each red first:**
  - `status` exited 1 in any crew with no slots. `status.d/slots.sh` ended in `[ -s slots ] && …`, and status.sh sources parts at the end of an `&&` list under `set -e`, so every later part was skipped. The parts now end in `if …; fi`.
  - Docker: every watch check failed until `file_mtime` tried the GNU form first.
- **Suites:** host ALL GREEN, docker ALL GREEN (watch 30, inbox 47, land 102, …).

## Implementation

Files:
- new: `crew/scripts/watch.sh`, `crew/scripts/status.d/watch.sh`, `crew/scripts/test/watch.test.sh`, `crew/skills/crew/references/watch.md`;
- changed: `crew/hooks/fast.sh`, `crew/hooks/mail.sh`, `crew/hooks/session-start.sh`, `crew/scripts/lib.sh`, `crew/scripts/inbox.sh`, `crew/scripts/slot.sh`, `crew/scripts/whoami.sh`, `crew/scripts/status.d/{slots,inbox}.sh`, `crew/scripts/test/{helpers,inbox.test}.sh`, `crew/skills/crew/references/config.md`, `crew/skills/crew/SKILL.md`, `crew/README.md`, `crew/CLAUDE.md`, and root `CLAUDE.md` (vocabulary: *watchdog*).

## Tech Debt

- Done: one `json_esc` in lib.sh, used by `hook_block` and `inbox.sh` (from PLUG-044), and one `file_mtime`, used by `with_lock` and `watch.sh`.
- Open: `test/helpers.sh` keeps its own `json_esc` for building payloads. Tests deliberately do not source lib.sh, so this is left as is.

## Reflection

- The design rule ("silence is measured, not guessed"; the stale rule lives once) is in `crew/CLAUDE.md`, and the coordinator setup is in `references/watch.md`.
- **Lessons:**
  - A sourced status part must end true.
  - On busybox, `stat -f` succeeds on stdout while failing, so try `stat -c` first.
  - A test that passes because an earlier step already did the work proves nothing. Clear the state the check is about.

## Current State

- Applied to the tree at 4182186 (copy rebased onto 1897d3e / PLUG-043). Host and docker ALL GREEN in the copy (13 suites), host ALL GREEN on the tree. Handed off to the coordinator for landing as crew 1.5.0.
- The live checks for the Stop/PostToolUse contracts are in PLUG-040's list (the coordinator).
