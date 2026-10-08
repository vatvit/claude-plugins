---
title: crew plugin — coordinate parallel Claude sessions on one working tree
status: in-progress
type: epic
epic-name: crew
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

## Goal

A new plugin, **crew**, that lets several Claude Code sessions work on **one working tree, one
branch** of any project without lost edits, broken shared checks or machine-time collisions.
It turns a field-tested playbook (six sessions + an asset pipeline on one repo for a day) into
reusable rules, roles and small runtime-free tools, so the same success reproduces on other
projects and other Claude accounts.

## Why

Sessions talking to each other (SendMessage / ListAgents) is powerful, but the coordination
discipline lives today only in one project's chat history. Every failure it prevents —
a peer's edit overwritten, `git add -A` committing someone else's half-done work, two e2e runs
timing each other out, a failing slice breaking everyone's checks — happened at least once.

## Source material

The user's playbook "Running parallel Claude sessions on one working tree without lost edits"
(pasted 2026-10-08, sections 1–9). Its essence, generalised:

1. **Ground rules** — one tree, one shared branch, no worktrees, no feature branches. The git
   index is shared: no session runs `git add -A/.`, `commit -a`, `stash`, `checkout -- .`,
   `reset --hard`. One committer (default the Coordinator) commits reviewed path lists with
   `git commit -F msg -- <paths>`.
2. **Hot spots** — files almost every feature touches have one holder at a time:
   announce → hold → release with a green commit sha; holds can be chained.
3. **Failing work stays out of the shared tree** — build in a copy based on a named commit,
   red-first tests there, land with a merge-or-refuse apply (take / 3-way merge / refuse),
   rebase the copy before applying; a snapshot before every write makes overwrites recoverable.
4. **Commit at once, one change per commit** — task id in the message; task/docs edits land
   immediately.
5. **One queue for machine time** — the Coordinator owns CPU/browser time; slot classes
   *cpu* (may overlap), *exclusive* (one at a time, e.g. browser e2e; no other runs inside),
   *quiet* (nothing else, for timing); priority = failing-on-shared-branch → user's critical
   asks → shortest first; waiting sessions are told their new time and why; background jobs
   check the queue too.
6. **Verify on push** — re-list `origin/<branch>..HEAD` against what was verified; read the
   output, not the exit status of a pipe; format the final land list after the last edit;
   a failure goes to its owner with the exact error.
7. **Bulk syncs** (assets, generated files) — only between landings, never in an exclusive
   slot, version pins in their own commit.
8. **Messages** — `<from> → <to>: <kind>`; relay the user's words verbatim; record decisions
   as the Coordinator's or the user's; ask for hard stop times; only the Coordinator changes
   task status, and only after push + verification.
9. **Hand-off template** — path list, commit message, the failing-on-HEAD line and the
   deliberate-bug result (test-first made visible).

Project-specific details from the source (`develop`, Blender, prettier, `dev.sh`, selective
asset sync) become per-project config or examples — none is hardcoded.

## Design (agreed 2026-10-08)

- **Name:** `crew`. Vocabulary: *crew, coordinator, worker, hold, hot spot, slot, land,
  snapshot, hand-off*. Never *job* (owned by `delay`) or *task* (owned by `task`).
- **Roles:** Coordinator and Worker, each with its own rules in the skill.
- **Guard hooks deny, configurable.** PreToolUse hooks for git-index safety and held files
  return a *deny* decision with the reason (exit 0, never crash); a config key drops them to
  warn-only. This is a deliberate exception to the repo rule "hooks never block" — record it
  in the repo CLAUDE.md with the reason (a warning arrives after `git add -A` has already
  staged a peer's files).
- **Committer is configurable, default Coordinator:** `coordinator | each-session |
  human-approved`. `land` always runs the path-list check whatever the mode.
- **State lives in `.git/crew/`** (holds, slot queue, session names, snapshots): shared by
  every session on the tree, never committed, needs no `.gitignore` edit. Confirm at the
  skeleton slice's architecture step.
- **Token economy — scripts do the mechanics, the skill does judgement** (user's ask,
  2026-10-08). Anything Claude would otherwise reason out or type every time becomes a script
  with one-line output:
  - `SKILL.md` stays short (roles + the non-negotiables); every area has its own
    `references/<area>.md`, read only when that area is in play.
  - A **SessionStart hook** injects ~5 lines: this session's crew name and role, the
    committer mode and "run `status` before acting". Most turns never need to load the skill.
  - **`status`**: one screen with holds, the slot queue, this session's dirty paths and
    dirty paths nobody has claimed. It replaces asking around and reading `git status`.
    Each area adds its own part under `scripts/status.d/` so slices never edit one file.
  - **`msg`** prints protocol messages (`handoff`, `hold`, `release`, `slot`, `queue-moved`),
    already formatted and filled from state: the path list from the session's changes, the
    sha, the queue position. Claude adds the judgement lines and sends the result.
  - Hook denials name the next step ("held by s2 since 14:05 — `holds.sh chain …`"), so a
    denial needs no skill lookup.
  - Each slice's Reflection step asks: what did Claude still do by hand that a script
    could do?
- **Config is layered, project wins** (user's ask, 2026-10-08). Every key is optional.
  A key is resolved per key: project `.crew.json` (flat JSON at the project root), then the
  user's `~/.claude/crew.json`, then a built-in default.
  - User level, for personal habits: `committer`, `hookMode`, snapshot retention, slot
    grace period.
  - Project level only, meaningless across projects: `sharedBranch`, hot-spot globs,
    `landCheck`. These are ignored, with a note, if they appear in the user file.

  A `config.sh` prints each effective value and which layer it came from. This extends the
  repo's config convention (project root only), so record it in the repo CLAUDE.md
  "Config convention" section.
- **Messaging is Claude Code's** (SendMessage / ListAgents). The plugin adds conventions and
  file registries, so a missed message never loses a hold or a slot.
- **Repo constraints apply:** bash 3.2 + awk, BSD and GNU, standalone (no sibling plugin),
  tests run in docker (alpine bash) and from a standalone copy.

## Scope

Plugin skeleton + playbook skill; hot-spot holds; slot queue; copy/apply merge-or-refuse;
write snapshots; land + git-index guard.

## Out of scope

- A messaging transport of its own (relies on Claude Code's SendMessage).
- Selective asset sync and other project-specific tooling (documented as an extension point).
- CI integration; pushing (stays a human-approved / Coordinator action outside the plugin).
- Worktree or branch-based isolation — explicitly rejected.

## Success criteria

On a scratch repo with three simulated sessions: a session cannot stage the whole index or
edit a file another session holds (denied with the holder's name); two *exclusive* slots
never overlap and a *quiet* slot waits for every other; a stale copy applies as
taken/merged/refused and a conflict lands nothing; an overwritten edit is restored from a
snapshot; `land` refuses a path list that does not match `git status`. Every suite passes in
docker and from a standalone copy of `crew/`.

## Sub-tasks

- PLUG-026: plugin skeleton, playbook skill, session identity, `status` / `msg`, layered config
- PLUG-027: hot-spot holds registry + held-file edit guard
- PLUG-028: slot queue for machine time
- PLUG-029: work in a copy, land with merge-or-refuse apply
- PLUG-030: snapshot before every write
- PLUG-031: `land` path lists + git-index guard hook

Order: PLUG-026 first (the one shared dependency: lib, identity, config, hook stubs,
`status.d` / `msg.d` extension points). Then PLUG-027 ‖ PLUG-028 ‖ PLUG-029 ‖ PLUG-030 ‖
PLUG-031, all in parallel. Each owns its own scripts, its hook stub, its `status.d` / `msg.d`
parts and its reference file, so they touch disjoint files. The shared hot spots are
`plugin.json`, `marketplace.json` and the `SKILL.md` pointer table. Bump the version and edit
the pointer table one landing at a time.
