---
title: crew — the pre-bash hook parks a session id for a whoami that is not a join
status: completed
type: bug
priority: low
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | found in PLUG-040; hooks/pre-bash.sh whoami parse |
| 20 | Requirements | skipped | ACs in the task |
| 30 | Assessment | done | one awk line |
| 40 | POC | skipped | n/a |
| 50 | Domain | skipped | n/a |
| 60 | Architecture | skipped | n/a |
| 70 | Tests | done | core.test.sh +2, red first (parked 2, dev-null, leave) |
| 80 | Subtasks | skipped | n/a |
| 90 | Implementation | done | crew 2.3.0 -> 2.3.1 |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | nothing new for CLAUDE.md |

## Description

Found during the PLUG-040 live check (crew 2.2.0). `hooks/pre-bash.sh` parks the session id under
the word after `whoami ` for any command line containing `crew.sh … whoami`. A bare `whoami 2>&1`
parked it as `crew-pending/2`, and `whoami --leave <name>` as `crew-pending/leave`. Neither is a
join. The files stay, so a later `whoami 2` / `whoami leave` without `--sid` would bind to the wrong
session id.

## Acceptance criteria

1. Only a join parks an id: `whoami <name> …`. Not a bare `whoami`, not `whoami --leave`/any
   option, not a redirection or operator (`2>&1`, `;`, `|`) taken as the name.
2. Regression cases in the hook tests, red before the fix; host + `crew-test`.


## Results

- The hook's whoami parse now drops an unquoted token that starts with `-` or contains `<`/`>`, so a bare
  `whoami 2>&1`, `whoami >/dev/null`, `whoami --leave <name>` park nothing; a quoted display name
  followed by a redirection still parks under its slug.
- `core.test.sh` +2 checks: red before (parked `2 dev-null leave`), green after.

## Current State (2026-10-24)

Implemented and verified: every crew suite green on the host and in `crew-test`. Committed and pushed; completed on the user's word.
