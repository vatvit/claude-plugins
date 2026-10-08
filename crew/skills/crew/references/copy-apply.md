# Copy, rebase, apply

A failing test in the shared tree fails every other session's checks. So build a slice in a
**copy**: write the test, watch it go red, make it green there, and only then land it.

```
copy new <dir> [--at COMMIT]      # e.g. your scratchpad; a `git clone --shared` at that commit
  … edit and test inside <dir> (run the tests in a slot) …
copy status <dir>                 # what the copy changed; flags a stale copy
copy rebase <dir>                 # move onto the tree's current HEAD (merge or refuse)
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
  refuses, leaving the copy unchanged, on a conflict. Resolve the conflict in the copy.
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
