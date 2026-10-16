# The crew playbook

How several Claude sessions work on one working tree without losing edits. Each rule names the
failure it prevents; every one of those failures happened at least once in practice.

## 1. Ground rules

- **One working tree, one shared branch, no worktrees, no feature branches.** Every session edits
  the same clone on the same branch. Worktrees and branches hide collisions instead of surfacing
  them, and sessions switching branches under each other is worse than any merge.
- **The git index is shared too.** No session runs anything that touches the whole index or tree
  (`git add -A`, `commit -a`, `stash`, `checkout -- .`, `reset --hard`, `clean`). Each one touches
  only its own paths. The `pre-bash` guard enforces this.
- **The user decides who commits and who pushes.** By default nobody in the crew does: `land`
  checks the paths and prints the commit for the user, and the user pushes. The coordinator asks
  the user once per project and records the answer (`committer`, `push`).
- **One committer.** Sessions do not commit for themselves. A worker that has finished
  a slice sends the coordinator a hand-off with the exact path list and the commit message. The
  coordinator then:
  - checks the list against `git status`, and looks for anything else that is dirty;
  - commits exactly those paths (`git commit -F msg -- <paths>`).

  That is what `land` does. With one committer, the index never has two writers and every commit
  is a reviewed path list.

## 2. Hot-spot files: one holder at a time

Some files are touched by almost every feature: the schema, shared type tables, the main
scene or router file, and similar. List them in `hotSpots`.

- Hold a hot spot before you edit it. The first session to hold it has it. Nobody else edits it
  until the holder releases it with the sha of a green commit.
- Holds can be chained in advance: "s2 takes it next, then s4".
- The reason: a commit takes a whole file. Two sessions' changes in one file can't be split into
  two commits afterwards.

## 3. Unfinished or failing work stays out of the shared tree

- Build a slice in a **copy** based on a named commit, and run its red-first tests there. A
  failing test that sits in the shared tree fails every other session's checks.
- Land the copy with **apply**, which merges or refuses:
  - it takes the copy's version where the tree still matches the copy's base;
  - it does a three-way merge where a peer changed the file;
  - it refuses, naming the file, on a conflict, and then lands nothing.

  Never use `cp`, and never write a whole file you have not just read.
- **Rebase the copy** onto the commit the tree is on now before applying. A copy goes stale
  every time anyone lands.
- A **snapshot** is taken before every edit, so an overwritten edit can always be recovered.

## 4. Commit at once, one change per commit

- Hand off each green slice the moment it is verified. A pile of uncommitted work is what ties
  sessions together, and it is the only kind of work a peer can destroy for you.
- Task-file and docs-only edits land straight away. They need no test run.
- One commit holds one task and one slice, with the task id in the message.

## 5. One queue for machine time

- The coordinator owns all CPU and browser time. Sessions ask for a slot and give an estimate.
  They start nothing heavy without one.
- Order: anything failing on the shared branch first, then the user's critical asks, then the
  shortest first.
- Slot classes:
  - `cpu`: untimed work (unit runs, bakes, renders). It may run alongside other `cpu` slots.
  - `exclusive`: one at a time, with nothing else running inside it, for example a browser e2e
    run. Extra load makes e2e tests time out, and then you can't tell a real failure from load.
  - `quiet`: timing measurements. Nothing else runs, and pushes and background jobs wait too,
    including your own.
- Background and automatic jobs (push retries, watchers) check the queue first. An automatic
  retry that fires during a quiet measurement ruins it.
- Whenever the queue moves, tell every waiting session its new time and why. Sessions that wait
  without being told assume they have been forgotten.

## 6. The tests run when you push

- Before every push, list `origin/<branch>..HEAD` and match it against what was verified.
- A piped command's exit status is not its verdict. Read the output. Once, every test passed
  but the push still failed, and a retry went through.
- Run the formatter on the final land list, after the last edit, not before.
- When a push check fails on someone's commit, hand the failure to its owner with the exact
  error. Don't fix their files yourself.

## 7. Bulk syncs (delivered assets, generated files)

- A sync that mirrors a whole folder cannot hold one file back. Sync only between landings, and
  queue the matching code change right behind it (for example, a resized footprint after new
  art).
- Never sync during an exclusive or quiet slot.
- Record asset versions (pins) in a commit of their own after every sync.
- A selective sync that takes a path list is the project's own tool. crew does not ship one.

## 8. Communication habits

- Every message starts with `<from> → <to>: <KIND>` and says what it is. `msg` prints the common
  kinds pre-filled.
- Relay the user's words verbatim. Record decisions in the task file as "the coordinator's" or
  "the user's".
- Ask each session for a hard stop time ("finish by 22:59, or stop between runs").
- A task closes only after it is landed and verified, and only the coordinator changes a task's
  status.

## 9. Hand-off template: test-first made visible

Every hand-off carries:
- the path list;
- the commit message;
- the line showing the new test failing on HEAD before the fix;
- the result of a deliberately planted bug that the test caught;
- the verifying run's result line.

`msg handoff` prints it with your paths filled in.
