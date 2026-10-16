---
title: crew — one working tree or worktrees is the user's call per project, asked once; the user can tell the coordinator to make an exception
status: approved
type: epic
epic-name: crew-worktrees
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

The user, 2026-10-16: "i would like to ask user once per project to decide to work in one
worktree or not. User should be able to tell Coordinator when make the exception of this rule".

Today "one tree, one branch" is a hard rule with no way out:
- SKILL.md non-negotiable 1 and playbook §1: "no worktrees, no feature branches";
- the pre-bash guard denies `git worktree` for every member (`crew/hooks/pre-bash.sh:13`, the
  denial text in `crew/scripts/land.sh:85`, listed in `references/land.md`);
- `copy new` is the isolation crew offers instead: a separate clone, no worktree, no branch.

PLUG-057 already set the pattern for "the user's call, per project, asked once": a config key,
`git_policy_note` (lib.sh) as the one test for "not decided", printed by `status` and the
coordinator's SessionStart line, and the skill making the coordinator ask and record only the
user's answer.

## Goal

A project can choose worktrees instead of one shared tree, asked once. The user can make an
exception for one task. crew's copy uses git's built-in worktree. Neither choice breaks task
ids, Docker stacks or the main tree's `git status`.

## Scope

The decisions recorded below, delivered as the sub-tasks listed under Sub-tasks.

## Out of Scope

- Writing, wrapping or rewriting a project's Docker setup (rejected: not crew's responsibility).
- Worktrees outside the project root.
- Running a project's install step on crew's own (crew prints it).

## Success Criteria

- In a fixture repo, a task worktree goes through branch, worktree, commit, conflict, merge and
  cleanup, with task ids allocated from one sequence across trees.
- `copy new` is a detached worktree, and every existing copy test passes against it.
- `crew status` lists the worktrees.
- crew is bumped once (2.0.1 → 2.1.0) when the epic closes. Sub-tasks do not bump crew; the task
  and task-roadmap sub-tasks bump their own plugins.

## Sub-tasks

Wave 1 runs in parallel (disjoint files); wave 2 needs PLUG-065.

| ID | Sub-task | Needs |
|----|----------|-------|
| PLUG-063 | task: the resolver finds the main tree from a worktree | — |
| PLUG-064 | task-roadmap: the same rule in its own copy | — |
| PLUG-065 | crew: `copy new` becomes a detached worktree in `.worktrees/`; `.gitignore` line; guard | — |
| PLUG-066 | crew: worktree mode (`tree` key, per-task exception, `task/<ID>`, merge) | PLUG-065 |
| PLUG-067 | crew: gitignored files (link list, printed regenerate step) | PLUG-065 |
| PLUG-068 | crew: Docker compose report (D) and the slot rule (C) | — |
| PLUG-069 | crew: `status` lists the worktrees | — |

Tests create real worktrees only in temporary fixture repos (allowed by the user, 2026-10-16).

## Agreed with the user (2026-10-16)

- **Why:** the user's own projects stay on one tree (their rule), but another developer may
  prefer worktrees. crew offers both, carefully.
- **Each session sees only its own changes.** That is the point of a worktree, and it is expected.
- **One task, one branch, one worktree, one session.** This follows PLUG-060's "one task, one
  session". The member **creates the task's branch first**, then the worktree on it (git allows a
  branch in only one worktree at a time anyway).
- **Why never more than one branch per task:** a task that needs more is split into sub-tasks,
  and each sub-task is a task with its own branch. A hand-over moves the task, with its branch and
  worktree, to the new owner, so it never needs a second branch. Fixing a task after its merge is
  either a new task or the same branch name made again from `main`. So there is one branch per
  task at any time, and naming it after the task (e.g. `task/PLUG-062`) keeps the link visible.
- **Merging is local; only the coordinator pushes.** A member merges its branch into the
  coordinator's branch without touching the remote. Pushing the whole job is the coordinator's
  call, within PLUG-057's `push` setting.
- **Conflicts are normal in parallel work.** Before the merge, the member brings in the latest
  state of the destination branch and resolves the conflicts in its own worktree, then tests there.
  The destination is the coordinator's local branch, so this needs no remote.
- **Merge or rebase is configurable; merge by default.** It applies both to bringing the
  destination into the task branch and to landing the task branch on the destination.
- **A member commits on its own task branch.** That is acceptable in worktree mode, whatever
  `committer` says; `committer` governs the merge into the coordinator's branch. The user may let a
  specific member push its own task branch (a per-member grant). Pushing the coordinator's branch
  stays under `push`.
- **Worktrees live in one place crew chooses.** It was first `.crew/trees/<task-id>`; it is now
  `.worktrees/` (see below). git lets anyone create a worktree at any path, and other tools do. So
  crew must recognise its own worktrees by their task branch, never assume every worktree is its
  own, and leave the others alone.
- **Generated files are regenerated by the coordinator after the merge.** A member may regenerate
  and resolve them in some cases, but the coordinator doing it once after the merge is the rule.

## Agreed with the user (2026-10-16, later): one mechanism — git worktrees

- **`copy new` becomes `git worktree add --detach`.** crew's own clone (`git clone --shared`,
  `crew/scripts/copy.sh:61`) is replaced by git's built-in feature. A detached worktree is a
  private checkout at a commit, with no branch: what a copy is today. Under `tree=shared`,
  `copy rebase` and `apply` keep landing file by file (merge or refuse, no commits, no branch),
  so "one tree, one branch" still holds for the shared tree.
- **Where branches are allowed** (`tree=worktrees`, or the user's per-task exception), the
  worktree is made on the task's branch (`task/<ID>`) and lands by a git merge, as agreed above.
- **Every other decision applies to both kinds**, detached or on a branch:
  - task files resolve to the main tree (one lock, one id sequence);
  - Docker is B + C + D;
  - gitignored files are linked or regenerated;
  - the guards deny `stash` and branches other than the task's own;
  - crew recognises its own worktrees and leaves others alone;
  - `status` lists them.
- **Worktrees live in `.worktrees/<repo>-<id>` (the user: "it looks commonly and generic").**
  This replaces `.crew/trees/`. The folder name is also the Docker project name (B), and `<id>`
  is the task id, or a copy's name for a detached one. The name is generic, so other tools may
  use `.worktrees/` too: crew recognises its own by name and branch, and leaves the rest alone.
  Accepted trade-off: tools that scan the project (test runners, linters, `tsc`, search, the
  Docker build context) also see `.worktrees/` unless the project excludes it.
- **The user's global rule is reworded (2026-10-16):** raw `git worktree` stays forbidden, and the
  exception is a worktree made through crew's own commands when it is necessary.
- **`.worktrees/` goes into `.gitignore` (the user, 2026-10-16: "gitignore").** Otherwise the main
  tree's `git status` shows `?? .worktrees/`, and `git add -A` from anyone (not only members)
  stages it as an embedded repo. A folder inside the repo is commonly ignored this way.
  `info/exclude` (local, never committed) was weighed and set aside in favour of the normal,
  visible way.
  - When crew creates the first worktree, it appends `/.worktrees/` to the main tree's `.gitignore`.
    It does so only when `git check-ignore -q .worktrees/` says the folder is not already ignored
    (so an existing rule, global or local, is respected). The write is diff-guarded, and the file
    is created if absent.
  - crew leaves the change uncommitted in the main tree. Committing it follows the project's
    `committer` setting like any other change. crew never removes the line.
  - This is the one project file crew writes in this task, by the user's explicit decision.
- **A worktree shares git state.** It shares the stash, refs, hooks and config with the main tree,
  where a clone shares none. Creating one runs the project's `post-checkout` hook. crew's
  pre-bash guard (`pre-bash.sh:13`) must allow crew's own commands and keep denying a raw
  `git worktree` from a member.

## Proposal (to agree before coding)

1. **A project decision, asked once.** A new key, e.g. `tree`: `shared` (one working tree, today's
   rule) | `worktrees` (one worktree per task). While undecided, `shared` holds and the
   coordinator asks the user. Extend `git_policy_note` for the "not decided" line rather than
   adding a second helper.
2. **An exception on the user's word.** Under `shared`, the user can tell the coordinator to let
   one task use a worktree. The coordinator records it as the user's decision, `status` lists it,
   and it ends when that task is merged (or the coordinator revokes it).
3. **The flow for one task:** create branch `task/<ID>` from the coordinator's branch → worktree
   in a fixed place → work and commit on the branch → bring in the destination and resolve
   conflicts → test → hand off "branch, sha, tests green" → the coordinator merges → worktree
   removed (refused while it has uncommitted work), branch deleted.
4. **Guards in a worktree.** Whole-index commands are safe in a member's own worktree (its own
   index). Still denied: `stash` (one stash for all worktrees), moving the coordinator's branch,
   and creating any branch other than the task's own.
5. **Skill and playbook wording:** non-negotiable 1 becomes "one tree, unless the user decided
   otherwise for the project or for one task"; the coordinator asks once and records only the
   user's answer.

## Open questions

- **Task files in worktrees — settled (the user, 2026-10-16):** the resolver handles a worktree
  and returns the main project root. `resolve-config.sh:18` takes `PROJECT_DIR` from `pwd`. It
  becomes the main tree: the parent of `git rev-parse --path-format=absolute --git-common-dir`,
  when that is a non-bare repo. Otherwise `pwd`, as today, which also covers no git and bare
  repos. Every script resolves through it, so there is one lock, one id sequence and one set of
  task files. task-roadmap gets the same rule in its own copy (plugin independence). The smaller
  points below follow from it and are part of the implementation:
  - The stale tracked copy of `.tasks/` in the worktree stays untouched. Every task path the skill
    uses comes from the scripts' output (absolute, in the main tree). That extends the existing
    "only the path `allocate-id.sh` printed" guardrail to every command. In a crew worktree, crew's
    pre-edit hook may also deny an edit under the worktree's own `tasksDir`, naming the main-tree
    path (crew's own folder, crew's own guard).
  - Task-file changes land as uncommitted changes in the main tree, not on the task branch. That
    is intended: the coordinator owns task status (playbook §8), and the merge carries no task-file
    conflict while the worktree copy is never edited.
  Kept below as history:
  With `.tasks/` in the repo, each worktree has its own
  copy of the task files and of `.task-config.json`. The id lock lives in that folder
  (`task/scripts/allocate-id.sh:55`), so two worktrees can create the same id. Status and Current
  State changes also stay hidden on the branch until it is merged. Options: task files are always
  edited in the coordinator's tree, or `tasksDir` lives outside the repo. The fix must hold
  without crew installed (plugin independence).
  **Direction (the user, 2026-10-16):** the task scripts resolve the project from the working
  directory; make them recognise a worktree and resolve to the main tree, so there is one lock,
  one id sequence and one copy of every task file. It belongs to the task plugin, and is useful
  without crew (any worktree, including ones that Claude Code or an IDE create, has the same id
  collision today). Points to settle there: the worktree still holds a stale tracked copy of
  `.tasks/` that an edit by relative path would change; task-file edits land as uncommitted
  changes in the main tree, not on the task branch; task-roadmap resolves tasks the same way and
  needs its own fix; the fallback when not in a git repo or in a bare repo.
  **Scope (the user, 2026-10-16): no separate task.** The task and task-roadmap fixes are part of
  this task. It fixes task files only; gitignored files are the next point.
- **Gitignored files (the user, 2026-10-16): link and regenerate.** Local settings and secrets
  (`.env`, local config) are linked from the main tree, from a list in config that crew treats as
  data. What is built from the branch's code (dependencies, build output, caches) is regenerated
  in the worktree by the project's own install step.
- **Docker (the user, 2026-10-16):** tests run inside the Docker network, with no host ports.
  Host ports are published only from the main tree. Heavy runs still wait for a slot. Migrations
  and seed data for a worktree's empty database are part of "regenerate".
- **Docker — crew never touches what is not its own (the user, 2026-10-16).** A project's Docker
  setup belongs to the project. crew writes no compose file, sets no `COMPOSE_*` variable, and
  neither wraps nor rewrites `docker compose`. It may use only what it owns: the worktree folder,
  its slots, and a read-only look at the config. Rejected for that reason: a generated
  `docker-compose.override.yml` in the worktree; the same file kept in crew's state and applied
  through `COMPOSE_FILE` (exported for the session, or written into `.env`); a `crew compose`
  wrapper with or without a guard; a hook that rewrites the command.
  **Options within that limit** (combinable; to choose):
  - A. **Nothing.** Docker in a worktree is the project's and the user's concern; crew stays silent.
  - B. **Folder name.** compose names a stack after its folder by default, so the worktree folder
    `<repo>-<task>` (optionally with a short path hash, against two clones with the same name)
    gives it its own stack, network and volumes. It works only while the compose file sets no
    top-level `name:`.
  - C. **Slot.** In a worktree, a Docker run happens only inside a slot, so one stack per crew runs
    at a time and host ports never clash. Slots are per crew: two repos clashing on a port is
    today's problem, not a new one.
  - D. **Report.** On creating a worktree, crew reads `docker compose config` and names, once,
    whatever defeats B and C: a top-level `name:`, a `container_name`, a fixed tag on a built
    image, or a mount outside the project (shared by every worktree). The fix stays the project's.
  - E. **Docker only from the main tree.** A worktree never runs Docker; its tests run in the main
    tree after the merge. It is the safest option, but a task is tested only after it lands.
  - F. **`copy new` for Docker-heavy tasks.** A separate clone in its own folder: the same effect
    as B, with no worktree at all.
  **Chosen (the user, 2026-10-16): B + C + D.** A and E are alternatives to them. F stays
  available per task. E is what D advises for a project that cannot run two copies.
  - C, refined: a worktree's Docker run that publishes no host ports (dependencies included:
    `docker compose run` publishes the ports of the services it starts) takes an ordinary `cpu`
    slot. It runs alongside other members and waits only behind `exclusive` or `quiet` runs. A run
    that publishes host ports takes `exclusive`. "No slot at all" stays out, because an
    unannounced run can still spoil someone's measurement. C is a skill rule; nothing enforces it.
  - B + C + D is for starting the project's infrastructure (a compose stack). A one-off unnamed
    container (`docker run --rm -v <worktree>:/w …`, no `--name`, no `-p`) already runs isolated
    and needs none of it, only today's `cpu` slot. Its traps: mount the worktree, not the main
    tree. Never tag an image built from a worktree with a fixed name, because the main tree's
    image of that name gets replaced. And a named volume (a dependency cache, say) is shared by
    every tree that names it.
  **Evidence behind B and D** (a throwaway fixture, then the user's projects read-only; Docker
  29.4.0, Compose v5.1.2):
  - Without isolation, a worktree's `up` reported the main tree's containers (`shop-api Running`)
    as its own, with no error. The fixture set a top-level `name:`, which is the case where B
    alone fails.
  - In the real projects (config only, nothing written or started), none sets a top-level `name:`,
    a `container_name` or a fixed tag on a built image. So B holds for them, and their remaining
    trap is host ports, which C covers. Mounts outside the project exist (the Docker socket,
    other projects' folders); they stay shared, so D names them. One project keeps a gitignored
    local override with machine-specific mounts. That is one more reason never to write a compose
    file into a worktree.
  - Other tools already create worktrees (Claude Code's own under `.claude/worktrees/`). Their
    folder names differ, so B keeps them apart too.
- **Per-worktree setup.** Untracked files (`.env`, dependencies, build output) are absent in a new
  worktree, and two worktrees running the same docker setup can collide on host ports. The slot
  queue still applies.
- **crew's own view — `status` updated (the user, 2026-10-16: "update crew status").** A new part,
  `status.d/trees.sh`, so `status.sh` itself is not edited. It prints one line per crew worktree:
  the folder, the task id (or copy name), the branch or `detached`, the owner session, commits not
  yet merged, how far behind the destination it is, and its count of uncommitted files. Worktrees
  crew did not make are counted in one line and never listed as crew's. This covers PLUG-061's
  "which task is each session on" for sessions that work in a worktree. Claims and snapshots must know which tree a path is in. Hooks work from a worktree, where
  `.git` is a file, but take the slower path.
- **User layer — settled (the user, 2026-10-16): "separately for each project".** `tree` is a
  project-only key, like the branch names: the user layer never sets it, so every project is
  asked once, unlike `committer` / `push`.
- Is a worktree still worth it next to `copy new`? It is visible in the IDE, has history and a
  normal git flow; a copy has none of that.

## Current State

Approved epic. Nothing changed in code. Every open question is settled (recorded above). Split
into PLUG-063 – PLUG-069 (2026-10-16). Next: approve the sub-tasks and start wave 1 (PLUG-063,
064, 065, 068, 069), which can run in parallel sessions.
