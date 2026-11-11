---
title: "task: remote-atomic ID allocation through git (idSource: git)"
status: completed
type: epic
epic-name: task-id-sync
priority: medium
created: 2026-11-11 18:41
tags: ["task-plugin", "git-sync-feature"]
---

## Goal

Several clones of one project (other machines, other people) can create tasks at the same time without ever getting the same `PREFIX-NNN`. Today this is guaranteed only on one machine. Projects without git, and local-only work, keep working exactly as today.

## Why

`allocate-id.sh` reserves IDs under a local lock and advances `nextId` in `.task-config.json`. Two clones can each allocate the same ID, and the clash only shows up at merge time, when the two task files collide or, worse, merge as two different tasks with one ID.

## Decisions (user, 2026-11-11)

- **ID sources: local is the base, git is one optional source.** `idSource` selects the source. The default is `local`: today's behaviour, `nextId` in `.task-config.json`, no VCS needed. It is the mode for local-only work and for projects with no git or another VCS. `git` is opt-in, because pushing is outward-facing. Other VCSs or backends may come later as further `idSource` values with their own commands. They are out of scope, but the selection point must make adding one a new branch, not a rewrite.
- **Mechanism: Git plumbing, a push as compare-and-swap.** Fetch, read the counter from the remote, build the commit with a temporary `GIT_INDEX_FILE` and `commit-tree`, and push `<sha>:refs/heads/<branch>`. A rejection means someone allocated first: re-fetch and retry. Never `--force`. The user's index, working tree, HEAD, branch and unpushed commits are never touched.
- **Counter home: a dedicated branch, `task-ids`** (name configurable). It holds only the counter, is never checked out or merged, and only the allocator writes it. So there are no conflicts with feature branches, no allocation commits on `main`, and `main`'s branch protection does not apply.
- **Local mirror.** In `git` mode the committed `.task-config.json` has no `nextId`. Each clone keeps a cache inside `.git/` (never committed, never a diff): the last value synced and the IDs pending sync. `resolve-config.sh` reports `nextId` from it. The remote branch is the only source of truth.
- **Degrade, never block.** `git` mode falls back to local allocation when the tasks dir is not in a git repo, has no remote, or the remote is unreachable. IDs allocated that way are normal `PREFIX-NNN`, marked *pending sync*, and pushed later.
- **Nothing is automatic on plugin update.** `local` stays the default. Switching is a deliberate setup command per project. After that, each clone catches up by itself on its first allocation. The one manual rule is that every machine runs the new plugin version before the switch.
- **Conflict instructions are spread across the slices.** Each slice documents its own failure cases. The renumbering guide is the one shared reference they link to.

## Scope

Sub-tasks carry `epic: task-id-sync`.

- Core `git` allocation and the switch command. Everything else builds on it.
- Offline fallback: pending sync, push later, report clashes.
- Migration safety: a first-run check per clone, a duplicate scan at setup, and a warning when `task-ids` is missing.
- Renumbering guide (+ optional script). Independent: it can start now.
- The way back, from `git` to `local`.

Order: core → offline → migration is a chain. Renumbering runs alongside the core. The way back runs alongside offline/migration once the core is done.

## Out of Scope

- Other VCSs or backends (Mercurial, SVN, a server). The selection point only leaves room for them.
- Committing on the user's behalf. Setup edits the config. The user commits it.
- Enforcing plugin versions across machines.

## Success Criteria

- Two clones allocating concurrently against one remote never get the same ID.
- Offline allocation works, and a later clash is reported, never silent.
- An existing project with several active clones can switch without duplicate IDs.
- A `local` project, and a project with no git, behave exactly as before. The existing suite passes.

## Closing (2026-11-11)

Success criteria checked against passing suites (host, task-test container, standalone copy):
- Concurrent clones never share an id: `git-source.test.sh` (concurrent clones; fails without the nonce).
- Offline works and a clash is reported, never silent: `offline.test.sh`, `net-timeout.test.sh`.
- A project with several active clones switches without duplicates: `migration.test.sh`, and back with `switch-back.test.sh`.
- `local` and no-git projects behave as before: every earlier suite is unchanged and green.

Release deferred (user, 2026-11-11): no version bump. The task plugin stays at 1.5.0 in `plugin.json`, `SKILL.md` and `marketplace.json`. The sub-tasks' mentions of "1.6.0" are history; the bump comes with a later release.

## Current State

Completed 2026-11-11. Not committed; the commit needs hunk selection, because other sessions have uncommitted edits in shared files (`resolve-config.sh`, `config.test.sh`, `marketplace.json`, root `README.md` and `CLAUDE.md`). The version is not bumped.
