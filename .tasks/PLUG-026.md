---
title: crew — plugin skeleton, playbook skill, session identity, status/msg, layered config
status: completed
type: feature
epic: crew
priority: high
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | repo conventions + delay/docs-manager/session-storage patterns; see Context |
| 20 | Requirements | skipped | ACs in the task are specific enough |
| 30 | Assessment | done | new plugin, no existing code touched beyond repo docs/marketplace |
| 40 | POC | skipped | hook contracts are documented; payload parsing proven in tests |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | see Architecture — shared by all crew slices |
| 70 | Tests | done | `crew/scripts/test/core.test.sh` (48 checks) |
| 80 | Subtasks | skipped | epic already sliced |
| 90 | Implementation | done | 48/48 host (bash 3.2/BSD) + crew-test docker (bash 5/busybox), standalone copy |
| 100 | Tech Debt | done | none filed |
| 110 | Reflection | done | plugin CLAUDE.md, README, repo CLAUDE.md (hook exception, user config layer, vocabulary) |

## Description

The base every other crew slice builds on, and valuable on its own: with only this
installed, sessions can already follow the playbook by hand.

- Plugin skeleton: `crew/.claude-plugin/plugin.json`, `CLAUDE.md`, `README.md`,
  `scripts/lib.sh` (json_str, `.git/crew/` state dir, session identity), marketplace entry,
  a row in the repo CLAUDE.md Plugins table, and an entry for the agreed hook exception.
- **Playbook skill** `skills/crew/SKILL.md`: short. It holds the roles (Coordinator / Worker),
  the non-negotiables (one tree and one branch; no whole-index git commands; who commits;
  failing work stays out of the tree; commit at once; machine time goes through the
  Coordinator) and a pointer table to `references/<area>.md`. The playbook text from the epic,
  generalised, goes to `references/playbook.md` (ground rules, push checks, bulk syncs,
  messaging, what to record where).
- **Session identity:** `whoami.sh <name> [coordinator|worker]` maps the Claude session id
  (from hook stdin / SessionStart context) to a crew name and role under `.git/crew/sessions/`.
- **SessionStart hook:** injects the session's crew name, role, committer mode and the
  `status` hint in about 5 lines. If the session has no name yet, it says how to set one.
- **`status.sh`:** shows this session's dirty paths, dirty paths nobody claims, and the
  current HEAD versus the shared branch. It runs every `scripts/status.d/*.sh` part, which the
  later slices add.
- **`msg.sh`** for the generic messages `handoff` (path list + commit message + test-first
  lines), `decision` and `stop-time`, in the format `<from> → <to>: <kind>`. Later slices
  add their own kinds through `scripts/msg.d/`.
- **`hooks/hooks.json`:** every hook entry is registered here once, each pointing at a stub
  script that exits 0. Later slices fill in their own stubs and never edit `hooks.json`,
  which keeps parallel slices on disjoint files.
- **Layered config** in `lib.sh`, resolved per key: project `.crew.json`, then user
  `~/.claude/crew.json`, then the default. Project-only keys are ignored in the user file,
  with a note. `config.sh` prints every effective value with its source layer
  (`committer=human-approved (user)`).

## Acceptance criteria

- [ ] `whoami.sh s1 coordinator`, then a new SessionStart run in that session, injects
      "crew: s1 (coordinator)…". A session with no name gets the setup hint.
- [ ] In a scratch repo with two named sessions, `status.sh` lists each one's dirty paths and
      flags an unclaimed dirty path.
- [ ] `msg.sh handoff` prints a complete, well-formatted message with the session's own
      paths filled in.
- [ ] The plugin works without `.crew.json`, and with a `.crew.json` that is missing any key.
- [ ] The suite passes in docker (alpine bash) and from a standalone copy of `crew/`.
- [ ] Config layering: a key set at user level applies; the same key at project level
      overrides it; a project-only key in the user file is ignored with a note; `config.sh`
      names each value's source layer.
- [ ] `SKILL.md` stays under ~120 lines; each area's detail lives in its own reference file.

## Notes

This is the one genuine shared dependency in the epic. Every other slice starts once it lands.

## Context

- **Patterns followed:** `delay/` for layout (`scripts/lib.sh` as the ONE helper file, `scripts/test/`,
  plugin `CLAUDE.md` with "don't regress" rules); `session-storage` for SessionStart context
  injection; `docs-manager` for PreToolUse payload parsing without jq; `task/allocate-id.sh` for the
  mkdir lock with stale-break.
- **Hook contracts relied on:** PreToolUse payload carries `session_id`, `cwd`, `tool_input`; a
  deny is `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny",…}}`
  on stdout with exit 0; SessionStart stdout is added to context (and re-runs after /compact).
- **Hard to find:** the stock `bash:5` test image has no git; crew needs it → `crew/scripts/test/Dockerfile`
  (bash:5 + `apk add git`), built as `crew-test`. User approved the network fetch for that build (2026-10-08).
- **Collisions:** none — no other in-progress task touches `crew/`.

## Architecture

Recorded in `crew/CLAUDE.md` "Design rules" (the doc of record). Summary of the decisions every
sibling slice builds on:
- State in `<git-common-dir>/crew/`; crew is *active* in a repo only when that directory exists
  (first `whoami` creates it) — otherwise every hook is silent: zero tokens where unused.
- Identity = crew name. Scripts get it from the `CREW_AS=<name>` prefix that SessionStart teaches;
  hooks map `session_id → name`. The pre-bash hook captures the session id of a
  `crew.sh whoami <name>` call into `pending/<name>`, so no one types an id.
- One entry point `crew.sh <command>`; `help` built from `# help:` lines. Areas are dual-use scripts
  (functions when sourced, CLI when executed); hooks `load_area` them and degrade if absent.
- Extension points so slices never share a file: `status.d/`, `msg.d/`, and `msg_handoff_extra_*`.
- Claims (`claims`: path, name, time) recorded by the pre-edit hook; `status` groups dirty paths as
  yours / a peer's / SHARED / unclaimed.
- Config: per key, project `.crew.json` > user `~/.claude/crew.json` > default; project-only keys
  (`sharedBranch`, `hotSpots`, `landCheck`) ignored in the user file with a note.

## Implementation

Shipped `crew` 0.1.0: `crew.sh`, `lib.sh`, `whoami.sh`, `config.sh`, `status.sh`, `msg.sh` +
`msg.d/core.sh` (handoff, decision, stop), hooks (`session-start`, `pre-edit`, `pre-bash`), skill
(`SKILL.md` 70 lines, `references/playbook.md`, `references/config.md`), README, CLAUDE.md,
marketplace entry. Tests: `core.test.sh` 48/48 on host and in `crew-test`, also from a standalone copy.

## Reflection

- **Repo CLAUDE.md:** crew row + tree entry; the hook rule now names crew's deliberate deny exception
  and why; config convention allows a per-key user layer; crew's trigger vocabulary added to the
  disjoint-vocabulary list.
- **Plugin docs:** `crew/CLAUDE.md` holds the design rules and the test commands (both targets).
- **Lesson:** awk `NR == FNR` breaks when the first file is empty (it then matches the second file) —
  use `FILENAME == <var>`; done in `dirty_owned`/`_claim_drop`.

## Current State

Completed. Build green (host + docker + standalone). Next: PLUG-027…031.
