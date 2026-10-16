# Task worktrees (PLUG-066)

By default the crew works in **one shared tree** on one branch. A project may instead give every
task its own worktree: **one task = branch `task/<ID>` = one worktree = one session**. Which one is
the user's call, made once per project.

## The decision

- `tree` is `shared` or `worktrees`, project layer only (`.crew.json`; `--user` is refused).
- While it is unset, `shared` holds, and `status` and the coordinator's SessionStart line say
  `worktrees: not decided`. The coordinator asks the user once and records only their answer:
  `crew config set tree shared|worktrees`.
- Under `shared`, the user may make an exception for one task. On their word the coordinator runs
  `crew tree allow <ID>`; `status` shows the exception; it ends when the task is merged or with
  `crew tree revoke <ID>`.

## The flow

1. The owner: `crew tree new <ID>` — branch `task/<ID>` from the shared branch, then the worktree
   `.worktrees/<repo>-<ID>` on it. Work, test and commit there; commits on your own branch are yours.
2. Bring in the shared branch: `crew tree sync <ID>` (merge, or rebase with `treeSync=rebase`).
   On a conflict it names the files: resolve them in the worktree, `git add` them, then
   `git commit --no-edit` (rebase: `git rebase --continue`), test, and sync again.
3. Hand off: the branch, its sha, and tests green.
4. The coordinator: `crew tree merge <ID>` — a `--no-ff` merge into the shared branch, then the
   worktree and the branch are removed. Under `committer=human-approved` it prints the merge for
   the user instead, and `crew tree remove <ID>` cleans up after it. A merge that does not go
   cleanly changes nothing: the member syncs first.
5. The coordinator regenerates generated files (indexes, roadmaps) in the main tree and lands them.

`crew tree remove <ID>` is refused while the worktree is dirty or the branch is not merged.

## Guards in a task worktree

The tree and index are the member's own, so `add -A`, `commit`, `reset`, `merge` and `rebase` are
allowed there. Denied, because they reach past the worktree:
- `git stash` (one stack for every worktree), and a raw `git worktree`;
- making, moving or deleting any branch, `checkout`/`switch` to anything but `task/<ID>`,
  `update-ref`, and a `fetch` into a local branch;
- `git push`, unless the user named the member in `taskPush`, and then only `task/<ID>` by name.
  Pushing the shared branch stays under `push`, and only the coordinator does it.

## Local files in a new worktree (PLUG-067)

A worktree starts with tracked files only: no `.env`, no local config, no dependencies, no build
output. Every worktree crew makes (a copy or a task worktree) gets:
- **links** to the paths in `treeLink` (e.g. `.env`, `config/local.yml`), from the main tree. They
  are paths, never commands: relative, with no `..`. An absent one is skipped with a note, a tracked
  one stays the branch's own, and the links never count as work (`status`, `sync`, `remove`, `apply`).
- **the setup step** in `treeSetup` (the project's install, build, migrations, seeds), printed for
  the session to run there. crew never runs it.
