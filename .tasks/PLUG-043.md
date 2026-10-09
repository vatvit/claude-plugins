---
title: crew — bare `crew` command on PATH, no CREW_AS prefix
status: completed
type: feature
epic: crew-feedback
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | feedback #5; facts: plugin bin/ on PATH (documented), CLAUDE_ENV_FILE for SessionStart (plugin hooks undocumented) |
| 20 | Requirements | skipped | ACs specific enough |
| 30 | Assessment | done | identity in lib.sh me()/prefix_for, status.sh ME, session-start run line, crew.sh usage |
| 40 | POC | done | code works both ways; the live plugin-hook check is folded into PLUG-040 (needs a fresh session) |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | see Architecture |
| 70 | Tests | done | `path.test.sh` (13) — red first: 13/13 failed on HEAD |
| 80 | Subtasks | skipped | small |
| 90 | Implementation | done | full run ALL GREEN host + docker (via slots) |
| 100 | Tech Debt | done | copy-rebase gaps filed as PLUG-048 |
| 110 | Reflection | done | SKILL Commands, README start, crew CLAUDE.md identity rule + layout |

## Description

Feedback #5. The prefix `CREW_AS=<name> bash <long plugin path>` is noise on every call.

- **`crew/bin/crew`** (executable). The plugin's `bin/` is on the Bash tool's PATH, so every call
  becomes `crew status`.
- **No CREW_AS.** A SessionStart hook writes `export CREW_SID=<session id>` to
  `$CLAUDE_ENV_FILE`. Scripts resolve the caller as sid → name, and CREW_AS stays as an
  override and a fallback.
- **POC first:** does a *plugin* SessionStart hook get `CLAUDE_ENV_FILE`, and does the variable
  survive `/compact` and resume? It is not documented. If it fails, keep `CREW_AS=<name> crew …`,
  which is still far shorter.
- SessionStart and the skill teach the short form; the denial texts use it.

## Acceptance criteria

- [ ] `crew help` works as a bare command in a session with the plugin enabled.
- [ ] With the env file working: `crew status` knows the caller with no prefix. Without it: the
      fallback works, and the SessionStart line shows the right form.
- [ ] POC result recorded (plugin hooks + CLAUDE_ENV_FILE; compact/resume) in `crew/CLAUDE.md`.
- [ ] Suites pass on host + docker.

## Architecture

- `crew/bin/crew` execs `scripts/crew.sh`. A plugin's `bin/` is on the Bash tool's PATH while the
  plugin is enabled.
- `caller_name` (lib) uses `CREW_AS` (name or display) when it is set, else `CREW_SID` mapped through
  `name_of_sid`. `me()` and `status` both use it. `prefix_for` is now the short `CREW_AS=<name> crew`, so
  every denial and release hint is short.
- SessionStart: when `CLAUDE_ENV_FILE` is set it appends `export CREW_SID=<sid>` once, which is
  idempotent across resume and compact. The run line then says `crew <command>`; otherwise it says
  `CREW_AS=<name> crew <command>`. The join hint says `crew whoami`.
- The live question, whether a *plugin* SessionStart hook gets `CLAUDE_ENV_FILE`, is folded into
  PLUG-040's live check. The code is correct either way.

## Implementation

`bin/crew`, `lib.sh`, `status.sh`, `crew.sh` (usage), `hooks/session-start.sh`; `path.test.sh` 13/13.
Prefix expectations updated in core/holds/land/names/inbox tests. Full run ALL GREEN on host and in
`crew-test`, via `slot run`.

**Process note (dogfood):** the first copy could not be rebased past W1's PLUG-044, which changed
the same lines of `session-start.sh`. `copy rebase` then has no way to accept an already-resolved
copy file, so the slice moved to a fresh copy at the new base. That is filed in PLUG-048
(`copy rebase --ours <path>`).

## Current State

Completed when landed.
