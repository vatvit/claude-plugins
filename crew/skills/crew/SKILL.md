---
name: crew
description: Use when several Claude Code sessions work on one working tree and one branch at the same time and must not lose each other's edits — running a crew of parallel sessions, acting as the coordinator or a worker, assigning tasks to sessions (one task, one session), handing off a finished change, landing path lists, holding a hot-spot file, asking for a slot (cpu / exclusive / quiet) before heavy runs, working in a copy and applying it back, recovering an overwritten edit from a snapshot. Activate on "parallel sessions", "run a crew", "join the crew", "you are the coordinator", "you are a worker", "assign tasks to sessions", "two sessions on one task", "split work between sessions", "crew status", "hand off", "handoff", "land these paths", "hold this file", "release the hold", "hot spot", "ask for a slot", "slot queue", "work in a copy", "apply the copy", "rebase the copy", "remove the copy", "task worktree", "worktree per task", "tree new", "tree sync", "tree merge", "restore from snapshot", "who holds", "inbox", "mailbox", "unread crew mail", "adopt crew mid-project", "import the holds", "set the hot spots", "crew watch", "watchdog", "silent session", "who commits", "who pushes", or /crew. Also activate when a crew SessionStart line ("crew: you are …") is in context and the session is about to edit, commit, push or start a long run.
---

# crew — parallel Claude sessions on one working tree

Several sessions share **one clone, one branch, one git index**. Nothing isolates them, so
the crew rules below are what stop lost edits. Most rules are enforced by scripts and hooks;
this file covers the judgement calls.

## Commands

Every command is `crew <command> [args]`: the plugin puts `crew` on the Bash tool's PATH. SessionStart
tells you whether the session already knows who you are. If it does not, prefix the command with
`CREW_AS=<your name>`:

```
crew <command> [args]            # or: CREW_AS=<your name> crew <command> [args]
```

`help` lists the commands. Start every piece of work with `status`: one screen showing the
crew, the branch, every dirty path by owner, the holds, the slots and crew's worktrees.

To join, run `crew whoami "<name>" [worker|coordinator]` through the Bash tool. A hook passes
it your session id. Use the name your peers address you by in SendMessage. Spaces are fine
(`"Max Coordinator"`): crew keeps that as your display name and derives a short crew name
(`max-coordinator`) for `CREW_AS`. Membership is opt-in: only `whoami` joins, and only when the
user puts this session in the crew. A session outside the crew works as usual, and no guard applies
to it. Names must be unique on the machine, because another repo may run its own crew. `whoami` refuses a name that is taken and suggests `<crew>-<name>`.

## Roles

**Coordinator.** There is one per crew. It:
- relays the user's words to the crew verbatim, and relays every hold and release;
- assigns each task to one session; a task too big for one is split into sub-tasks first;
- owns machine time (the slot queue) and tells waiting sessions their new times and why;
- keeps `watch --wait` running in the background, so a silent crew wakes it (`references/watch.md`);
- asks the user once how this project commits and pushes, when `status` says it is not decided,
  and records only the user's answer (`config set committer …`, `config set push …`). Until then
  nobody commits or pushes: `land` prints the commit for the user, and pushes are the user's;
- asks the user once, the same way, whether the project works in one shared tree or a worktree
  per task (`config set tree …`), and records a per-task exception only on their word (`tree allow`);
- lands hand-offs (`land`), and pushes and checks the push only when `push` lets the crew push;
- is the only one who changes task status, and only after the work is landed and verified;
- records decisions in the task file as "the coordinator's" or "the user's".

**Worker.** It:
- works on the one task assigned to it, and only that task;
- builds each change in a copy, test-first, and lands it with `apply`;
- holds a hot spot before editing it;
- asks for a slot before any heavy run;
- finishes each change with a hand-off (`msg handoff`), never with its own commit, unless
  `committer` says otherwise.

## Non-negotiables

1. **One tree, one branch, unless the user chose worktrees.** No worktrees but crew's own, no
   feature branches, no `git switch` away from the shared branch. Under `tree=worktrees`, or the
   user's exception for one task, that task works in its own worktree on `task/<ID>`
   (`crew tree new <ID>`) and the coordinator merges it (`references/trees.md`).
2. **One task, one session.** A task in progress has one owner session. To work on a task in
   parallel, split it into sub-tasks first (the task workflow's `subtasks` step); each session
   owns one. Ownership moves only by an explicit hand-over (`references/playbook.md` §1).
3. **Never touch the whole index or tree.** No `git add -A` / `.` / `-u`, `commit -a`, `stash`,
   `checkout -- .`, `restore .`, `reset --hard`, `clean`. Use exact paths only. The guard hook
   denies these and tells you the alternative.
4. **Commits and pushes are the user's call.** By default nobody in the crew commits
   (`committer=human-approved`: `land` checks the paths and prints the commit for the user) or
   pushes (`push=human`). Only the user's word changes that, never your own judgement:
   `committer=coordinator` lets the coordinator commit a reviewed path list with `land`, and
   `push=committer` lets whoever commits push.
5. **Failing work stays out of the shared tree.** Make it red, then green, in a copy. Land it
   with `apply`, which merges or refuses. Never `cp` over the tree, and never write a whole file
   you have not just read.
6. **Hot spots have one holder at a time.** `hold` before editing; release with the sha of the
   green commit that landed it.
7. **Machine time is queued.** Run nothing heavy without a slot. Use `slot run <class> <min> --
   <cmd>` to request, wait, run and release in one go. Docker in a copy: `cpu` without host
   ports, `exclusive` with them (`references/slots.md`).
8. **Commit at once.** Hand off each green change the moment it is verified. One commit holds
   work for one task only, with the task id in the message.
9. **Messages start with `[<crew>] <from> → <to>: <KIND>`.** `msg <kind>` prints them pre-filled.
   Add the judgement lines. Send anything a peer must act on with `--send` as well as SendMessage:
   it files a copy in their mailbox, which a dropped SendMessage cannot lose. Read yours with
   `inbox` as soon as a hook says you have unread mail. Several crews can run on one
   machine, so never act on a message tagged with another crew: tell the sender it reached the
   wrong crew.

## Where the detail is

Read only the reference for the area you are working in:

| Area | Read |
|------|------|
| Full playbook: the why behind each rule, push checks, bulk syncs, messages, hard stops | `references/playbook.md` |
| Config keys and layers; `config set` / `unset` | `references/config.md` |
| Hot spots and holds | `references/holds.md` |
| Slots: machine time | `references/slots.md` |
| Copy, rebase, apply | `references/copy-apply.md` |
| Task worktrees: the `tree` decision, `tree new` / `sync` / `merge`, their guards, local files in a new worktree | `references/trees.md` |
| Snapshots: recover an overwritten edit | `references/snapshots.md` |
| Land, the git guard, pushing | `references/land.md` |
| Mailbox: `msg --send`, `inbox`, the unread notice | `references/inbox.md` |
| Adopting crew in a running project: hot spots, holds import, what to cut from CLAUDE.md | `references/adopt.md` |
| Watchdog: silent sessions, unread mail, stale slots; what wakes an idle coordinator | `references/watch.md` |

## When a hook says no

A denial names the holder, the slot or the rule, plus the command to run instead. Do that.
Never work around a guard with a different spelling of the same command. If the guard is
wrong, tell the coordinator, who can change `hookMode`.
