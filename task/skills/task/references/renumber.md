# Renumbering a task

Two different tasks can end up with one id. Sessions on one machine cannot cause this,
because `allocate-id.sh` prevents it. It happens when clones allocate apart from each
other: `idSource: local` on two machines, or a `git` allocation that fell back to local
while offline (`id-sources.md`). The fix is always the same: keep one task on the id
and move the other one to a fresh id.

```
<PLUGIN_ROOT>/scripts/renumber.sh <project-dir> <OLD-ID> [--update <ID>...]
```

- The new id comes from `allocate-id.sh`, so it follows the project's `idSource`.
- The moved task keeps its content and `created:`. Its own mentions of the old id follow
  it, and it gains `renumbered-from: <OLD-ID>`. Its artifacts folder moves with it, and
  an epic's index is rebuilt.
- Other tasks change **only when named in `--update`**. After a clash, a mention of the
  old id elsewhere may mean either task. Every other mention is printed as
  `ref=<ID>:<line>`. Read each one and decide which task it means, then pass those tasks
  in `--update` on the same call. Afterwards, fix any leftover by hand.
- Ids are matched at id boundaries: `X-100` never matches inside `X-1000`.

## Which one moves

The task that has been shared longest keeps the id, because other people, commits and
branches may already refer to it. Move the newer or still-local one. Ask the user when
it is not clear.

## Case 1: before the merge, the clash is in your clone only

A `git pull` reports that an untracked `PREFIX-050.md` would be overwritten, or you can
see that the remote also has a different `PREFIX-050.md`.

1. Before pulling, run `renumber.sh <project-dir> PREFIX-050 --update <your tasks that mean it>`.
2. Commit the result, then pull. There is no conflict left.

## Case 2: during a merge (git reports add/add on the task file)

Both versions are inside the conflict. Get them out, then move yours:

1. Save your version: `git show :2:<tasksDir>/PREFIX-050.md > /tmp/mine.md`.
   (`:2:` is ours, `:3:` is theirs. During a rebase the two are swapped.)
2. Keep theirs at the path: `git checkout --theirs -- <tasksDir>/PREFIX-050.md`, then `git add` it.
3. Put yours back as a new task: `printf '%s' "$(cat /tmp/mine.md)" | <PLUGIN_ROOT>/scripts/allocate-id.sh <project-dir> --stdin`.
   Note the printed id. In the new file, replace the old id with the new one where it
   refers to itself, and add `renumbered-from: PREFIX-050`.
4. Fix the references as in the rule above. `renumber.sh` cannot help in the middle of a
   merge, because the old path now holds their task.
5. Finish the merge.

If both sides have an artifacts folder under the same name, its files conflict
one by one. Keep theirs in place and move yours into the new task's folder.
