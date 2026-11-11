---
title: "task: core git ID allocation — pull and push the latest ID on the task-ids branch, plus the switch command"
status: completed
type: feature
priority: medium
epic: task-id-sync
created: 2026-11-11 18:14
tags: ["task-plugin", "git-sync-feature"]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | see Context |
| 20 | Requirements | done | R1–R11 (EARS) |
| 30 | Assessment | done | ready; own test Dockerfile (bash:5 + git) |
| 40 | POC | skipped | standard plumbing; fixture tests exercise it first |
| 60 | Architecture | done | see Architecture |
| 70 | Tests | done | git-source.test.sh (46), lock.test.sh (3); red first |
| 90 | Implementation | done | task 1.6.0; all suites green host + container + standalone |
| 100 | Tech Debt | done | PLUG-133 (network timeout, lock wait) |
| 110 | Reflection | done | plugin CLAUDE.md, id-sources.md, root CLAUDE.md |

## Description

The core slice of epic `task-id-sync` (PLUG-126). The epic holds the agreed decisions, so they are not repeated here. When `idSource: git` is set, `allocate-id.sh` allocates through a new script that **pulls the latest ID from the remote `task-ids` branch and pushes the increment**, without touching the user's index, working tree, checked-out branch or unpushed commits.

Mechanism (Git plumbing):

1. `git fetch <remote> task-ids`, then read the counter with `git show <remote>/task-ids:<file>`, never from a working-tree file.
2. Build the new tree with a temporary `GIT_INDEX_FILE` (`read-tree`, `hash-object -w`, `update-index --cacheinfo`, `write-tree`).
3. `git commit-tree <tree> -p <remote-sha>`, then `git push <remote> <sha>:refs/heads/task-ids`. Never `--force`.
4. A rejected push (non-fast-forward) means someone else allocated first: re-fetch, re-read, retry, up to a bounded number of attempts.

The push is the compare-and-swap, so two clones can never get the same ID.

In scope:

- The `idSource` selection point (`local` default, `git`), built so another source is one more branch.
- The `.git/` cache (last synced value), and `resolve-config.sh` reporting `nextId` from it in `git` mode.
- `--count N`: one push that advances the counter by N.
- **Setup command (`local` → `git`).** It creates `task-ids` from max(`nextId`, highest existing task ID + 1), seeds the cache, sets `idSource: git`, and removes `nextId` from the committed config. It never commits. Re-running it adopts an existing `task-ids` and never resets it.
- With no git repo or no remote in `git` mode: allocate locally and say so. The pending-sync behaviour belongs to PLUG-128.

Out of this slice: offline pending sync (PLUG-128), migration safety (PLUG-129), the renumbering guide (PLUG-127), the way back (PLUG-130).

## Conflict instructions (this slice's part)

User-facing docs (task plugin README/CLAUDE.md, and a pointer in SKILL.md):

- A rejected push: automatic retry, and what to do when retries run out.
- Someone edited or force-pushed `task-ids` by hand: how to restore it (the counter must be at least the highest existing task ID + 1).
- Repository rules that protect every branch and reject the push to `task-ids`: what to allow, or stay on `local`.
- Hooks do not run for allocation commits (`commit-tree`).

## Acceptance criteria (draft)

- With `idSource: git`, two clones allocating concurrently against one bare remote get distinct IDs (test with a fixture bare repo).
- The user's index, working tree, HEAD and unpushed commits are byte-identical before and after allocation (test: staged change + unpushed commit + a non-default branch checked out).
- A push rejection triggers a re-fetch and retry. Exhausting the retries fails with a clear message and creates no task file.
- `--count N` in `git` mode makes one push.
- Setup on a fixture repo creates `task-ids` from `nextId`, and a second clone running setup adopts it without resetting it.
- `idSource: local` (the default), and a tasks dir with no git at all, behave exactly as today, and the existing suite passes.
- No `--force` anywhere.
- Standard shell conventions apply: bash 3.2, BSD+GNU, no `sed -i`, and tests in Docker with fixture repos only.

## Context

**Epic:** `task-id-sync` (PLUG-126) holds the decisions, so do not re-litigate them here. Siblings: PLUG-127 (renumbering guide) can run in parallel. PLUG-128/129/130 build on this task's cache and push.

**Prior decisions that bind this task:**
- `allocate-id.sh` is the only path to an id. It has four guarantees (lock, self-heal `max(nextId, highest+1)`, `noclobber`, persisted `nextId`). They came from real races between parallel sessions (task/CLAUDE.md, *Don't regress*). `git` mode must keep all four and add the remote compare-and-swap on top. The local lock still serialises sessions on one machine before the push.
- A linked worktree resolves to the main tree (PLUG-063, `task_project_dir` in `lib.sh`). The `.git/` cache must use the **common** git dir (`git rev-parse --git-common-dir`), or each worktree gets its own cache.
- `.task-config.json` is a shared data contract (task-roadmap reads `tasksDir`). Adding `idSource` and other keys is fine. Moving or renaming the file is not.
- Works without HOME (PLUG-118). The git path must not need `~/.claude`.

**Code to touch:**
- `task/scripts/allocate-id.sh`: the selection point goes after the self-heal candidate and before the file reservation. In `git` mode the candidate becomes max(remote counter, local self-heal), and the file is written only after a successful push.
- `task/scripts/resolve-config.sh`: report `nextId` from the `.git/` cache in `git` mode. Its parser is a line-based awk; **PLUG-131** (proposed, another session) fixes one-line JSON in that same parser, so this is a file collision, so coordinate or land it first.
- New script(s) for the git source and the setup command. The likely home of shared bits is `lib.sh`, keeping the DRY-within-a-plugin rule.
- Docs: `task/README.md` (config section l.57–62, the id paragraph l.47), `skills/task/references/configuration.md` (l.29–53), `references/scripts.md` (l.11–38), `SKILL.md` l.40–61 (the `nextId` guardrail stays true).

**Tests:** `task/scripts/test/*.test.sh` source `test/lib.sh` and end with `report`. `worktree.test.sh` is the pattern for git fixtures: the `g()` wrapper with an inline identity, `init.defaultBranch=main`, everything under `$TMP`, and `SKIP` when git is missing. **Gap:** the documented container target `bash:5` has no git, so every git test silently SKIPs there. This task needs a container with git (e.g. `bash:5` + `apk add git` inside the container), decided at Tests.

**Found in passing:** the stale-lock check in `allocate-id.sh` runs `stat -f %m` before `stat -c %Y`. That is the order the repo CLAUDE.md forbids (busybox `stat -f` prints filesystem status to stdout and fails, so junk lands in the age arithmetic). It is latent in the container. Fix it test-first here, since this task edits the same block.

**Parallel-session collisions:** in progress elsewhere: PLUG-110/113/123 (docs-manager) and PLUG-117 (cowork epic). None touches `task/`. PLUG-131 (proposed) touches `resolve-config.sh`.

## Requirements (EARS)

- R1 (ubiquitous): The id source shall be chosen by the config key `idSource`, whose values are `local` (default, used when absent) and `git`. Any other value shall be rejected with an error naming the allowed values.
- R2 (state, `local`): While `idSource` is `local`, allocation shall behave exactly as before this task.
- R3 (event): When `allocate-id.sh` runs with `idSource: git` and the remote branch is reachable, the system shall read the counter from the remote branch, choose ids ≥ max(remote counter, highest existing task file + 1, local cache), push the advanced counter, and only then create the task files.
- R4 (unwanted): If the push is rejected because the remote branch moved, then the system shall re-fetch and retry, up to `TASK_ID_RETRIES` attempts (default 5). If the remote did not move (rules, permissions), it shall stop at once. Either failure shall create no task file and exit non-zero with a message.
- R5 (ubiquitous): Allocation and setup shall never change the user's index, working tree, HEAD, checked-out branch or local branches, and shall never use `--force`.
- R6 (event): When `--count N` is given in `git` mode, the system shall advance the counter by N in one push.
- R7 (state): While `idSource` is `git` and the tasks dir is not in a git repo, has no such remote, or the remote is unreachable, the system shall allocate locally and print a warning that the ids are not synced. (Pending sync: PLUG-128.)
- R8 (unwanted): If the remote is reachable but has no counter branch, then allocation shall fail with a message naming the setup command.
- R9 (event): When the user runs the setup command (`id-source.sh <project-dir> git`), the system shall create the counter branch with max(`nextId`, highest task file + 1), or adopt an existing one, raising it to that value if it is lower and never lowering it. It shall then write the cache, set `idSource: git` and remove `nextId` from the project's `.task-config.json`, without committing.
- R10 (state): While `idSource` is `git`, `resolve-config.sh` shall report `nextId` from the clone's cache, and allocation shall not write `nextId` to the config.
- R11 (ubiquitous): Remote, branch and prefix values from config shall be validated and used only as quoted data, never executed.

## Assessment

Ready. The change is local to `task/scripts/` plus docs. `allocate-id.sh` has one clean seam (after the self-heal candidate, before reservation). `resolve-config.sh` passes config keys through generically, so `idSource` needs no parser change, and only `nextId` must be added from the cache. Setup is project-scope only: a global registry (`configScope=global`) is nested JSON, and `git` mode is refused there with a message. Risk: the test container `bash:5` has no git (see Context). The plugin gets its own `scripts/test/Dockerfile` (`bash:5` + git), the same two lines crew carries. That is allowed duplication across plugins, by the repo's independence rule.

## Architecture

- **Counter on the remote:** branch `task-ids` (config `idBranch`), remote `origin` (config `idRemote`). One file per prefix, `<PREFIX>.next-id`, holding the next free number. Several task sets in one repo can then share the branch.
- **Plumbing:** `ls-remote --exit-code` tells *unreachable* (fallback) apart from *no branch* (exit 2 → R8). `fetch` into `refs/remotes/<remote>/<branch>`. Temporary `GIT_INDEX_FILE` → `read-tree <remote sha>` (keeps other prefixes' files) → `hash-object -w` → `update-index --cacheinfo` → `write-tree` → `commit-tree -p <remote sha>` → `push <sha>:refs/heads/<branch>`. When the repo has no `user.email`, a neutral author `task plugin <task-plugin@localhost>` is used for the commit only. `GIT_TERMINAL_PROMPT=0`, so it never blocks on a password prompt.
- **Retry rule:** after a failed push, fetch again. If the remote sha changed, retry with the new counter. If not, stop (R4).
- **Order inside the existing local lock:** pick N free ids from the candidate (skipping existing files), push counter = last + 1, then create the files with `noclobber`. If a file appears in between, fail loudly: the ids are burnt, never duplicated.
- **Cache:** `<git common dir>/task-ids/<PREFIX>.cache`, one line `nextId=N`. The common dir means one cache per repo, shared by worktrees (PLUG-063).
- **Code layout:** `scripts/id-git.sh` is a sourced library of the git functions, used by `allocate-id.sh`, `resolve-config.sh` and the new `scripts/id-source.sh`. `id-source.sh` has subcommands from a fixed set: `git` (setup) and `status`. PLUG-130 adds `local`. Flat-config read/write helpers go in `lib.sh`: a `match()` loop over `"key": value` pairs, so a one-line config also works (cf. PLUG-131), rewritten with tmp + `mv` and diff-guarded.
- **POC:** skipped as a separate step. The plumbing sequence is standard and was shown in the discussion. The fixture tests below exercise it end to end first.

## Tests

- `task/scripts/test/git-source.test.sh` (46 checks) uses fixture bare remote + clones under `$TMP`, with HOME and the system git config isolated. It covers: unknown `idSource`; setup (counter from max(nextId, highest + 1); config edited, not committed); `resolve-config` in git mode; allocation; adopting from a second clone (raises the counter, never lowers it); `--count` as one push; the user's index, tree, HEAD and branches byte-identical; 2 clones × 5 concurrent allocations with no duplicates; a remote that refuses the push; no counter branch; an unreachable remote and no repo (local, with a warning); refusals in setup; `task_config_edit`; `status`; no forced push.
- `task/scripts/test/lock.test.sh` (3 checks): the stale-lock bug from Context. It was red in the busybox container before the fix.
- Red first: the suite failed 32 of 45 checks before any implementation.
- Proven to fail: with the nonce removed (in a scratch copy), "no id twice" fails 3 runs out of 3.
- `scripts/test/run.sh` and `scripts/test/Dockerfile` (`task-test` = `bash:5` + git) are new. In the container, `worktree.test.sh` now runs instead of skipping.

## Implementation

- `scripts/id-git.sh` (new, sourced): validate, probe (`ls-remote --exit-code`: ok / nobranch / noremote / unreachable), fetch into `refs/remotes/<remote>/<branch>`, read `<PREFIX>.next-id`, push (temporary index → `commit-tree` → `push <sha>:refs/heads/<branch>`), reserve (the retry loop: it retries only when the remote moved), and the clone cache in the git common dir.
- `scripts/id-source.sh` (new): `git` (setup or adopt) and `status`.
- `scripts/allocate-id.sh`: an `idSource` check; modes local / git / gitlocal; the reservation happens before the files are written; `nextId` goes to the cache in git modes; the self-heal uses `task_highest_id`; the stale-lock `stat` order is fixed.
- `scripts/resolve-config.sh`: in git mode, `nextId` comes from the cache. The value loop moved into a function (bash 3.2 cannot parse `case` inside `$( )`).
- `scripts/lib.sh`: `task_highest_id` and `task_config_edit` (a flat JSON writer that also reads one-line files).
- Bug found by the concurrency test: identical commits from two clones made the second push a no-op success, so both got the id. Fixed with a nonce line `Reservation:` in every reservation commit.
- Docs: `skills/task/references/id-sources.md` (new; the one home for how it works, switching, and troubleshooting), `configuration.md`, `scripts.md`, `commands/create.md` (what to do on a warning or error), `SKILL.md` (triggers, references row), plugin `README.md`, plugin `CLAUDE.md`, root `README.md`. Version 1.5.0 → 1.6.0 in `plugin.json`, `SKILL.md` and `marketplace.json`.
- Not done here, by design: pending sync (PLUG-128), the first-run check and duplicate scan (PLUG-129), renumbering (PLUG-127), the way back (PLUG-130). This repo itself stays on `idSource: local`; switching it is the user's call.

## Reflection

- The repo `CLAUDE.md` Shell Conventions gained two lessons: no `case` inside `$( )` under bash 3.2, and the nonce needed for plumbing commits used as a compare-and-swap.
- Plugin `CLAUDE.md` *Don't regress*: the git source reserves before it writes, never touches the user's git state, and must keep the nonce.

## Current State

Completed 2026-11-11. task 1.6.0: all 11 suites green on the host (bash 3.2), in the `task-test` container (busybox + git) and from a standalone copy. Nothing committed. Follow-ups in the epic: PLUG-127 (can start now), PLUG-128 → PLUG-129, PLUG-130, PLUG-133 (tech debt).
