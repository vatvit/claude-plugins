---
title: crew — bare `crew` command on PATH, no CREW_AS prefix
status: proposed
type: feature
epic: crew-feedback
priority: medium
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
