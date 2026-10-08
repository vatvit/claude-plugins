# Land, the git guard, pushing

## Land: commit exactly a reviewed path list

```
land --msg-file F -- <path...>      # one task, one slice, task id in the message
```

`land` refuses, and commits nothing, if any listed path:
- is not dirty;
- is held by another session (the coordinator may land a holder's hand-off);
- or, under `each-session`, was touched only by another session.

It then:
- prints every dirty path it leaves behind, with its owner, for the coordinator to check;
- reports paths someone staged that are not in the list;
- stages only the new files in the list and runs `git commit -F F -- <paths>`;
- drops the claims on what it landed;
- prints who releases which hold, with the exact command and the new sha.

| `committer` | Who may land |
|-------------|--------------|
| `coordinator` (default) | only the coordinator; workers hand off (`msg handoff`) |
| `each-session` | anyone, but only paths that they touched |
| `human-approved` | nobody: `land` runs every check, then prints the exact `git add` / `git commit` for the user to run or approve |

Land at once. A green slice that sits uncommitted ties sessions together, and it is the only
kind of work a peer can destroy for you. Task-file and docs-only edits land immediately.

## The git guard

The pre-bash hook denies, with the reason and the alternative:
- anything that stages, stashes, restores, resets or cleans the **whole** index or tree
  (`add -A/./-u`, `commit -a`, `stash`, `checkout -- .`, `restore .`, a bare `reset`,
  `reset --hard`, `clean`);
- anything that moves the shared branch for everyone (`checkout`/`switch` to another branch or
  commit, `reset <commit>`; and for workers, `rebase`, `pull`, `merge`, `cherry-pick`, `revert`,
  `am`);
- `worktree`, and creating or deleting branches;
- `git commit` by a non-committer, or without a `-- <paths>` list;
- `git push` by a worker (when the committer is the coordinator), and anyone's push while
  another session runs a quiet slot.

Exact-path forms always pass: `git add <path>`, `git checkout -- <path>`,
`git restore -- <path>`, `git reset -- <path>`.

`hookMode=warn` turns every denial into a warning. Don't re-spell a denied command to get
past the guard. If the guard is wrong, raise it with the coordinator.

## Push

1. `land prepush` lists `origin/<branch>..HEAD`. Match each commit against what was verified.
   It refuses while a quiet slot runs.
2. Run the formatter on the final land list, after the last edit, not before.
3. A piped command's exit status is not its verdict. Read the output: tests can all pass while
   the push still fails, and a retry can then succeed.
4. Automatic retries and background pushes check `slot clear` first.
5. When a push check fails on someone's commit, hand the failure to its owner with the exact
   error. Don't fix their files yourself.
