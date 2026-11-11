# Id sources

Where `allocate-id.sh` gets its numbers. The config key `idSource` picks one.

| `idSource` | Numbers come from | Safe across |
|---|---|---|
| `local` (default, also when absent) | `nextId` in the config + the highest task file, under a local lock | parallel sessions on one machine and one checkout |
| `git` | a counter on a dedicated branch of the remote, reserved by a push | every clone of the repo: other machines, other people |

`local` needs nothing: no git, no remote. It is right for local-only work and for projects
in another VCS. `git` is opt-in, because allocating then pushes to the remote.

## The git source

The counter lives on its own branch, `task-ids` on `origin` by default, in one file per
prefix: `<PREFIX>.next-id` holds the next free number. The branch is never checked out
or merged, and only the allocator writes it, so it never conflicts with feature branches
and adds no commits to `main`.

To allocate, the script fetches the branch, picks the next free ids, and pushes a commit
that raises the counter (plumbing: a temporary index and `commit-tree`). The push is the
compare-and-swap. If another clone pushed first, ours is rejected; we fetch and retry, and
the task file is written only after a push succeeds. The user's index, working tree, HEAD,
checked-out branch and unpushed commits are never touched, and nothing is force-pushed.
Allocation commits skip git hooks, because `commit-tree` runs none.

Config keys, all optional:

| Key | Default | Meaning |
|---|---|---|
| `idSource` | `local` | `local` or `git` |
| `idRemote` | `origin` | the remote holding the counter branch |
| `idBranch` | `task-ids` | the counter branch |

In `git` mode the shared `.task-config.json` holds no `nextId`. Each clone keeps its own
cache in `<git common dir>/task-ids/<PREFIX>.cache`. That location is never committed and
is shared by the clone's worktrees. `resolve-config.sh` reports `nextId` from the cache.
The remote branch is the only source of truth. Env `TASK_ID_RETRIES` (default 5) bounds
the retries.

Every call that talks to the remote has a deadline: env `TASK_ID_NET_TIMEOUT` seconds
(default 20, at most 100; any other value is ignored). A remote that does not answer the
first check counts as unreachable, so allocation goes local with a pending id. A push that
does not finish in time fails the allocation and creates no file; that push may still land
later, so its number is spent: a gap, never a duplicate. A session waiting for the id lock
while another one is on the network waits until the lock would be stale (about two
minutes), not 10 s. The holder refreshes the lock before every network call. A killed
git can leave its ssh running until ssh's own timeout; it holds nothing of ours.

## Switching a project to git

1. Update the task plugin on every machine that works on the project first. An older
   version ignores `idSource`, so it cannot see the remote counter and can hand out an
   id that is already taken.
2. Run `<PLUGIN_ROOT>/scripts/id-source.sh <project-dir> git`. It creates the counter
   branch at max(`nextId`, highest task file + 1), seeds this clone's cache, sets
   `idSource: git` and removes `nextId` from `.task-config.json`. If another clone already
   switched, it adopts that branch instead, raising the counter if this clone has
   higher task files and never lowering it.
3. Commit and push the config change. The command never commits on its own.

The other clones need no step of their own. The first time a clone uses git ids (its first
allocation, or running setup there), its own task files that no branch of the remote has
(tasks made there and never pushed) are handed in like offline ids (*Offline: pending ids*
below). Each one is claimed if the counter has not passed it, or reported as a possible
clash if it has. Setup also warns about one number under two file names (`X-05.md` and
`X-005.md`) and about task files that still hold merge-conflict markers.

`id-source.sh <project-dir> status` shows the source, the remote's counter and this clone's
cache: `nextId`, `pending` and `clash`. Only a project-local `.task-config.json` can switch;
a global registry cannot.

## Switching back to local

Run `id-source.sh <project-dir> local`, then commit and push the config change. It writes
`nextId` back into `.task-config.json` and removes `idSource`. `nextId` is the remote counter,
never lower than the highest task file + 1 or this clone's cache. When the remote can be
reached, the pending ids are claimed first, so no clone that is still on git ids is handed
them later. A clash found then is named, as it is in *Offline: pending ids* below. Offline,
it uses the counter as this clone last fetched it, and names the ids it could not sync.
After that the clone's cache is deleted.

The `task-ids` branch is left as it was. A clone that has not pulled the config change
yet still allocates from it, so delete it by hand only once no clone uses it. Running
`local` on a project that is already local changes nothing.

Switch while online, and pull the config change into every clone soon. Until a clone
pulls it, that clone still reserves on `task-ids`, and the committed `nextId` does not
see those reservations. The local source heals from task files (`max(nextId, highest
file + 1)`), so the gap closes as soon as those tasks are merged.

## Offline: pending ids

When the remote cannot be reached, allocation does not wait. It takes the next id locally
and records it as **pending** in the clone's cache. The next allocation that reaches the
remote claims the pending ids in the same push as its own reservation.
`id-source.sh <project-dir> sync` claims them without creating a task. It fails while the
remote is still unreachable, and the ids stay pending.

A pending id is usually still free, and claiming it simply raises the counter past it.
If another clone took that number in the meantime, the remote counter is already beyond
it. The id is then reported once as a possible **clash** (a `WARNING` naming it) and kept
in the cache's `clash` list until `renumber.sh` moves that task (`renumber.md`). A clash
is only *possible*: the other clone may have spent the number on a task that never
reached the remote. Check the remote's tasks before renumbering.

With no git repo at all there is no cache, so nothing is recorded as pending. The warning
says `not synced`, and checking for a clash is up to you.

## When something goes wrong

| What you see | What it means | What to do |
|---|---|---|
| `WARNING: idSource is git, but … not synced with the remote yet. It is recorded as pending` | No such remote, or the remote is unreachable. The id was allocated locally. | Nothing. The next allocation, or `id-source.sh … sync`, claims it. |
| `WARNING: … not synced with the remote` (without *pending*) | The tasks dir is not in a git repo, so nothing could be recorded. | Check by hand that the id is not taken elsewhere. |
| `WARNING: <ID> was allocated while the remote could not be used, and another clone has since passed that number` | A possible clash, kept in `status` as `clash=`. | Compare with the remote's tasks. If two tasks share the id, move this one (`renumber.md`); that also clears the clash. |
| `ERROR: … has no branch 'task-ids'` | The config says `git`, but this remote was never set up. | Run `id-source.sh <project-dir> git`. |
| `ERROR: the push … was refused and the branch did not move` | The remote rejects the push: branch protection or rules that cover every branch, or no write access. | Allow pushes to `task-ids` for the people who create tasks, or switch the project back to `local`. |
| `ERROR: the push … did not finish within Ns` | The remote stopped answering mid-push (slow VPN, stalled ssh, a slow server hook). | Run again. Raise `TASK_ID_NET_TIMEOUT` for a slow but working remote. |
| `ERROR: … lost the race N times` | Many clones allocated at once. | Run again. Raise `TASK_ID_RETRIES` if it keeps happening. |
| `ERROR: <ID>.md appeared while its id was being reserved` | A file with that id was created by hand during the reservation. | Run again. The reserved number stays unused, so nothing is duplicated. |
| The counter on `task-ids` is lower than an existing task id (edited or force-pushed by hand) | The next allocations could reuse ids. | Run `id-source.sh <project-dir> git` in a clone that has every task file. It raises the counter to the highest file + 1. Never lower the counter by hand. |
| Two task files with one id (from before the switch, or a local allocation) | A real clash. | Renumber one of them: `renumber.md`. |
| `WARNING: one number, several files: …` (setup) | Two file names in this clone for one number. | Keep one; move the others with `renumber.sh`. |
| `WARNING: merge-conflict markers in: …` (setup) | A merge joined two versions into one task file, maybe two different tasks. | Resolve the file; if it was two tasks, follow *during a merge* in `renumber.md`. |
