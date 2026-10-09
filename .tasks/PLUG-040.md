---
title: crew — live smoke test of the hook contracts in Claude Code
status: blocked
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
| 90 | Implementation | —  | bugfix done (1.0.2); live hook check still pending a fresh session |
| 100 | Tech Debt | — |  |
| 110 | Reflection | — |  |

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
