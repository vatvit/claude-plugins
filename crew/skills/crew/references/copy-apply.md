# Copy, rebase, apply

A failing test in the shared tree fails every other session's checks. So build each change in a
**copy**: write the test, watch it go red, make it green there, and only then land it.

```
copy new <name> [--at COMMIT]     # a detached git worktree at .worktrees/<repo>-<name>
  … edit and test inside that folder (run the tests in a slot) …
copy status <name>                # what the copy changed; flags a stale copy
copy rebase <name>                # move onto the tree's current HEAD (merge or refuse)
copy rebase <name> --ours <path...> # …keeping the copy's version of conflicts you resolved there
apply <name> [path...]            # land into the shared tree
msg handoff                       # then hand off the landed paths
copy remove <name>                # drop the copy; refused while it holds work the tree lacks
```

A new copy holds tracked files only. The project's local files in `treeLink` are linked in, and
its `treeSetup` step is printed for you to run there ([trees.md](trees.md)); the links never land.

**apply** decides each changed file separately and lands nothing unless every file is clean:
- **taken**: the tree still matches the copy's base, so the copy's version goes in. This
  includes adds and deletes.
- **merged**: a peer changed the file too, in different lines, so a clean three-way merge
  (`git merge-file`) goes in.
- **already there**: the tree already has exactly that content.
- **refused**: both sides changed the same lines, or one side deleted the file while the other
  changed it, or the file is binary, or it is held by another session, or it is an unheld hot
  spot. Nothing lands and the tree is left byte-identical.

The summary line reads `apply: N taken, M merged, K already there`.

- **Rebase before applying.** A copy goes stale every time anyone lands. Apply still merges peer
  changes, but your tests never ran against them. `rebase` uses the same rules in reverse and
  refuses on a conflict and leaves the copy unchanged. To resolve one:
  1. edit the file in the copy so it holds both changes. The refusal shows how to see the
     tree's version: `git -C <dir> show <sha>:<path>`;
  2. run `copy rebase <name> --ours <path...>`, which the refusal prints with the conflicting paths.

  A plain rebase would only refuse again, because it still compares the old base, the new base
  and the copy. `--ours` keeps the copy's version only for the paths it names, and only
  where they conflict: any other conflict still refuses, and the other files rebase as usual.
- **`landCheck`** (project config, e.g. a formatter check) runs on the landed file list after the
  writes. If it fails, every write is undone. Run the formatter in the copy first, so that the
  check passes.
- Each file apply overwrites is snapshotted first (when snapshots are installed), and the landed
  paths are claimed for you in `status`.
- A copy is a detached git worktree in `.worktrees/` at the repo root: no branch, its own private
  index, the repo's objects shared. The first copy adds `/.worktrees/` to `.gitignore` unless
  something already ignores it; that change is left uncommitted for you to commit or keep. Edits
  inside a copy are private: no hold, snapshot or claim. crew runs `git worktree` for you, and a
  raw `git worktree` from a member is denied. `copy remove <name>` drops a copy once everything in
  it is in the tree; a copy made before 2.1 is a clone, whose folder you delete yourself.
- Never `cp` from the copy into the tree. `cp` cannot see a peer's change and silently erases
  it.
