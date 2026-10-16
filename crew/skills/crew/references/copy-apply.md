# Copy, rebase, apply

A failing test in the shared tree fails every other session's checks. So build each change in a
**copy**: write the test, watch it go red, make it green there, and only then land it.

```
copy new <dir> [--at COMMIT]      # e.g. your scratchpad; a `git clone --shared` at that commit
  … edit and test inside <dir> (run the tests in a slot) …
copy status <dir>                 # what the copy changed; flags a stale copy
copy rebase <dir>                 # move onto the tree's current HEAD (merge or refuse)
copy rebase <dir> --ours <path...> # …keeping the copy's version of conflicts you resolved there
apply <dir> [path...]             # land into the shared tree
msg handoff                       # then hand off the landed paths
```

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
  2. run `copy rebase <dir> --ours <path...>`, which the refusal prints with the conflicting paths.

  A plain rebase would only refuse again, because it still compares the old base, the new base
  and the copy. `--ours` keeps the copy's version only for the paths it names, and only
  where they conflict: any other conflict still refuses, and the other files rebase as usual.
- **`landCheck`** (project config, e.g. a formatter check) runs on the landed file list after the
  writes. If it fails, every write is undone. Run the formatter in the copy first, so that the
  check passes.
- Each file apply overwrites is snapshotted first (when snapshots are installed), and the landed
  paths are claimed for you in `status`.
- A copy is a separate clone: no worktree and no branch. It sees every new commit in the shared
  repo through git's alternates, and its index is private. Delete the directory when you are
  done.
- Never `cp` from the copy into the tree. `cp` cannot see a peer's change and silently erases
  it.
