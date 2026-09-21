---
title: docs-manager scripts use a hardcoded #!/bin/bash shebang
status: proposed
type: bugfix
priority: low
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

`docs-manager/scripts/{diagram.sh,docs.sh,lib.sh}` start with `#!/bin/bash`. On Alpine — the
`bash:5` image this repo's dual-target convention uses — bash lives at `/usr/local/bin/bash`
and `/bin/bash` does not exist, so anything that *execs* those scripts directly dies with
`bad interpreter: No such file or directory`.

Raised by PLUG-008, where exactly this broke the task plugin in the container: `allocate-id.sh`
execs `resolve-config.sh` rather than running `bash resolve-config.sh`, so the shebang fired.
Eight test cases failed on Alpine while all passed on macOS.

## Why it is latent rather than broken

docs-manager's own suite invokes its scripts as `bash scripts/docs.sh …`, which ignores the
shebang entirely — so the bug is invisible today. It becomes real the moment any script,
hook or user runs one of them as an executable. `task-roadmap` already uses the `env` form;
docs-manager is the only plugin left on the hardcoded path.

## Scope

- Change the three shebangs to `#!/usr/bin/env bash`.
- Add a case to docs-manager's suite asserting no `#!/bin/bash` remains, matching the one
  added to `task/scripts/test/port.test.sh`.
- Verify on both targets.

## Acceptance criteria

- No `#!/bin/bash` anywhere in `docs-manager/`.
- docs-manager's suite passes on the host and in `bash:5`.
- A test fails if the hardcoded form is reintroduced.

## Notes

The repo `CLAUDE.md` Shell Conventions section already gained the rule during PLUG-008 —
this task is the remaining cleanup, not the decision.
