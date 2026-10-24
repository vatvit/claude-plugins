---
title: crew — live smoke test of the hook contracts in Claude Code
status: completed
type: chore
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | user installed crew 1.0.1 (2026-10-09); see Findings |
| 20 | Requirements | skipped | ACs specific enough |
| 30 | Assessment | done | hooks of a plugin installed mid-session do not run in that session |
| 40 | POC | done | the live attempt itself — see Findings |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | skipped | no design change beyond the bugfix |
| 70 | Tests | done | core.test.sh +3 regression checks (red on 1.0.1, green on fix) |
| 80 | Subtasks | skipped | — |
| 90 | Implementation | done | bugfix 1.0.2; live check 2026-10-24 on Claude Code 2.1.307, crew 2.2.0 |
| 100 | Tech Debt | done | PLUG-084 (pre-bash parks ids for non-join whoami) |
| 110 | Reflection | done | crew/CLAUDE.md: CREW_SID rule, § Testing procedure + last checked |

## Description

The crew suites prove everything except the two contracts with Claude Code itself:
- a PreToolUse hook's JSON `permissionDecision: "deny"` really blocks the tool call, and Claude
  reads the reason;
- SessionStart stdout really lands in context, including again after `/compact`.

Both are documented hook contracts, but nothing in the repo exercises them. They were not run
during the epic, because that needs the plugin installed in a live session, and installing
needs the user's go-ahead.

## Acceptance criteria

- [ ] With crew installed from the marketplace, two sessions in a scratch repo:
  - `whoami` binds without `--sid`;
  - SessionStart shows the crew lines after a restart and after `/compact`.
- [ ] `git add -A` is denied in the live session, with crew's reason shown to Claude.
- [ ] An Edit to a file the other session holds is denied, naming the holder.
- [ ] Record the Claude Code version checked in `crew/CLAUDE.md` § Testing.

## Findings (2026-10-09, live attempt in the session that built crew)

- **The plugin's hooks did not run in this session.** It was already running when the user
  installed crew 1.0.1. Piping a realistic payload into the installed `pre-bash.sh` by hand
  works (it parked the id), but the real Bash call left nothing, so Claude Code never invoked
  the hook. A session started after install, or restarted, is needed. `whoami`'s error now
  says so.
- **Venue:** the Bash tool resets the shell to the project root after every call, and the hooks
  key off the session's cwd. So a scratch repo cannot host the check: it has to be the repo
  the session runs in. Running it here touches the parallel kickoff session too. It was
  coordinated as a 3-minute quiet window by message, and the state was removed afterwards.
- **Bug found and fixed (1.0.2):** a *failed* `whoami` created `.git/crew/sessions` and
  `pending`, and so did the pre-bash hook parking an id. Either one switches crew on for the
  whole repo, putting every other session under the guard as an unnamed worker. Fix: ids are
  parked in `<git-common-dir>/crew-pending/` (outside `crew/`), and `whoami` creates `crew/`
  only once it has an id to bind. Three regression checks in `core.test.sh` fail on 1.0.1 and
  pass now. Full run: 264/264 on the host and in `crew-test`.

## Added checks (2026-10-09, crew-feedback epic)

For the same fresh session, also check live:
- the PostToolUse `additionalContext` unread notice, and the Stop hold with unread mail (PLUG-044);
- that a plugin SessionStart hook gets `CLAUDE_ENV_FILE`: after start, `crew status` works with no
  CREW_AS prefix (PLUG-043);
- auto-join of a titled session started with `--name` (PLUG-042).

## Current State

Blocked on a fresh session. The bugfix (1.0.2) is uncommitted, waiting for the user's approval
to commit and push. Next action, in a session started AFTER crew 1.0.2 is installed, in a repo
with no other session at work:
1. `crew.sh whoami <name> coordinator` without `--sid` → binds;
2. `git add -A --dry-run` → denied, with crew's reason;
3. a second session holds a probe file → Write to it is denied, naming the holder;
4. `/compact` → the crew lines reappear;
5. record the Claude Code version in `crew/CLAUDE.md` § Testing.

## Live check (2026-10-24, Claude Code 2.1.307, crew 2.2.0)

This session was started with crew installed, in this repo, whose crew (delay coordinator, kickoff
worker) had been silent for 13+ days, so nobody was disturbed. Joined as `claude-plugins-smoke`.

- [x] `crew whoami claude-plugins-smoke worker` with no `--sid` → bound.
- [x] SessionStart stdout lands in context after `/compact`: the "crew: this repo runs crew …" line
      arrived as `SessionStart:compact hook success` when this session's context was compacted.
- [x] `git add -A -- crew-smoke-no-such-path` → denied; Claude saw "crew: git add of everything stages
      other sessions' work too …". (`git add -A --dry-run` is let through on purpose, `land.sh:94`;
      the no-match pathspec makes the probe harmless if the guard fails.)
- [x] Write to `crew-smoke-probe.txt` held by `claude-plugins-kickoff` → denied: "… is held by
      claude-plugins-kickoff since 10:48 (PLUG-040). Don't edit it until it is released."
- [x] `msg decision --to claude-plugins-smoke --send` → the next tool call carried PostToolUse
      `additionalContext`: "crew: 1 unread crew message — read before going on …".
- [x] `CLAUDE_ENV_FILE` works for a plugin SessionStart hook: `CREW_SID` set in the Bash env, and
      `crew active` / `crew inbox` name this session with no `CREW_AS`.
- [x] Stop hold: a message left unread at the end of a turn → "Stop hook feedback: crew: 1 unread
      crew message — read before going on …"; the turn went on, `inbox` read it.
- Left the crew afterwards (`whoami --leave`); no holds or probe file remain.
- [x] ~~Auto-join of a session started with `--name` (PLUG-042)~~: obsolete — PLUG-055 reversed it;
      SessionStart never auto-joins, membership is `whoami` only.
- Recorded in `crew/CLAUDE.md` (the `CREW_SID` rule and § Testing: procedure + last checked version).
- Minor: `whoami` still says "Prefix every crew call with CREW_AS=…" when `CREW_SID` already
  identifies the session. Correct (the prefix always works), only more than needed; left as is.
- Found: the pre-bash hook parked this session's id as `crew-pending/2` (from `whoami 2>&1`) and
  `crew-pending/leave` (from `whoami --leave`). Removed by hand; fix is PLUG-084.

## Current State (2026-10-24)

All acceptance criteria checked live. Committed and pushed (2026-10-24); completed on the user's word.
