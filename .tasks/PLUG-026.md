---
title: crew — plugin skeleton, playbook skill, session identity, status/msg, layered config
status: proposed
type: feature
epic: crew
priority: high
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
