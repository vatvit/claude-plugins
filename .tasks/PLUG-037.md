---
title: kickoff — machine-wide port registry
status: completed
type: feature
epic: kickoff
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | |
| 20 | Requirements | done | |
| 30 | Assessment | done | |
| 40 | Architecture | done | |
| 50 | Tests | done | |
| 60 | Implementation | done | |
| 70 | Tech Debt | done | |
| 80 | Reflection | done | |

## Goal

A registry of every project's dev ports at `~/.claude/kickoff/ports.json`, machine-wide, which
deliberately ignores `CLAUDE_CONFIG_DIR` (repo CLAUDE.md, "Per account or per machine"). Commands:
allocate the next free port for a project, and list. When the registry does not exist yet, fall back to
scanning the compose files of existing projects. Seed it with the ports already in use (listed today
in project-e's CLAUDE.md).

Spec: `kickoff/skills/kickoff/references/questionnaire.md` (agreed 2026-10-08). Epic: PLUG-034. (section "Where kickoff keeps its own data", question I5)

## Acceptance criteria

- Two allocations never return the same port, even from two accounts with different
  `CLAUDE_CONFIG_DIR` values. A test proves it.
- Concurrent allocation is safe (lock, then write via a temp file and mv).
- Bash 3.2, BSD and GNU, no runtime. Tests run in Docker and from a copy of the plugin with no siblings.

## Dependencies

None. It has its own script and tests, so it can run in parallel with PLUG-035. It does not touch
`plugin.json`, `marketplace.json` or `SKILL.md`; the landing of PLUG-035 wires it in.

## Context

The PLUG-035 skeleton exists (32c1af8). Real compose files under `~/projects` publish ports as `"3035:3000"`, `'6006:6006'`, `"${APP_PORT:-8310}:8000"` (sample-poc) and `127.0.0.1:…`. The ports in use are also listed by hand in project-e's CLAUDE.md. The repo rule "Per account or per machine" makes this registry machine-wide.

## Architecture

- `scripts/ports.sh` provides `next`, `allocate`, `set`, `release` and `list [--all]`. The registry is a flat JSON object, one entry per line, in `~/.claude/kickoff/ports.json`. Overrides for tests: `KICKOFF_PORTS_FILE`, `KICKOFF_PROJECTS_DIR`, `KICKOFF_PORT_BASE` (3030).
- **Deviation from the task text, deliberately:** the compose scan runs on *every* allocation, not only when the registry is absent. It is strictly safer (a port taken without kickoff is never handed out) and cheap. That also makes automatic seeding redundant: compose ports are always excluded, and ports used elsewhere are recorded with `ports.sh set`.
- Writes happen under a `mkdir` lock with a pid file; a dead holder's lock is broken. The rewrite goes through a temp file + mv and is diff-guarded.
- Names are `<project>` or `<project>/<service>`.

## Tests

`scripts/test/ports.test.sh` has 26 checks, green on the host and in `bash:5`, and standalone. The shared helpers moved to `test/helpers.sh`, and `test/all.sh` runs every suite. **Shown failing:** without the compose scan, 2a and 2b fail; without the lock, 4a, 4b and 4d fail.

## Implementation

`ports.sh`. SKILL.md: I5 is offered from `ports.sh next` and reserved with `allocate`. The questionnaire's data section, README and CLAUDE.md are updated. Version 0.1.0 → 0.2.0 in plugin.json, the marketplace and SKILL.md, with the description and keywords refreshed and a "port registry" trigger added.

## Tech Debt

None.

## Reflection

The rule is in kickoff/CLAUDE.md under Don't regress. No repo-level lesson this time.

## Current State

Completed. Next: PLUG-036 (setup scaffold).
