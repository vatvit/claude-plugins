---
name: crew
description: Use when several Claude Code sessions work on one working tree and one branch at the same time and must not lose each other's edits — running a crew of parallel sessions, acting as the coordinator or a worker, handing off a finished slice, landing path lists, holding a hot-spot file, asking for a slot (cpu / exclusive / quiet) before heavy runs, working in a copy and applying it back, recovering an overwritten edit from a snapshot. Activate on "parallel sessions", "run a crew", "join the crew", "you are the coordinator", "you are a worker", "crew status", "hand off", "handoff", "land these paths", "hold this file", "release the hold", "hot spot", "ask for a slot", "slot queue", "work in a copy", "apply the copy", "rebase the copy", "restore from snapshot", "who holds", "inbox", "mailbox", "unread crew mail", "adopt crew mid-project", "import the holds", "set the hot spots", "crew watch", "watchdog", "silent session", or /crew. Also activate when a crew SessionStart line ("crew: you are …") is in context and the session is about to edit, commit, push or start a long run.
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
crew, the branch, every dirty path by owner, the holds and the slots.

To join, run `crew whoami "<name>" [worker|coordinator]` through the Bash tool. A hook passes
it your session id. Use the name your peers address you by in SendMessage. Spaces are fine
(`"Max Coordinator"`): crew keeps that as your display name and derives a short crew name
(`max-coordinator`) for `CREW_AS`. Membership is opt-in: only `whoami` joins, and only when the
user puts this session in the crew. A session outside the crew works as usual, and no guard applies
to it. Names must be unique on the machine, because another repo may run its own crew. `whoami` refuses a name that is taken and suggests `<crew>-<name>`.

## Roles

**Coordinator.** There is one per crew. It:
- relays the user's words to the crew verbatim, and relays every hold and release;
- owns machine time (the slot queue) and tells waiting sessions their new times and why;
- keeps `watch --wait` running in the background, so a silent crew wakes it (`references/watch.md`);
- lands hand-offs (`land`), pushes, and checks the push;
- is the only one who changes task status, and only after the work is pushed and verified;
- records decisions in the task file as "the coordinator's" or "the user's".

**Worker.** It:
- builds its slice in a copy, test-first, and lands it with `apply`;
- holds a hot spot before editing it;
- asks for a slot before any heavy run;
- finishes each slice with a hand-off (`msg handoff`), never with its own commit, unless
  `committer` says otherwise.

## Non-negotiables

1. **One tree, one branch.** No worktrees, no feature branches, no `git switch` away from the
   shared branch.
2. **Never touch the whole index or tree.** No `git add -A` / `.` / `-u`, `commit -a`, `stash`,
   `checkout -- .`, `restore .`, `reset --hard`, `clean`. Use exact paths only. The guard hook
   denies these and tells you the alternative.
3. **One committer.** By default that is the coordinator, and it commits a reviewed path list
   with `land`. `config` shows the mode (`coordinator` / `each-session` / `human-approved`).
4. **Failing work stays out of the shared tree.** Make it red, then green, in a copy. Land it
   with `apply`, which merges or refuses. Never `cp` over the tree, and never write a whole file
   you have not just read.
5. **Hot spots have one holder at a time.** `hold` before editing; release with the sha of the
   green commit that landed it.
6. **Machine time is queued.** Run nothing heavy without a slot. Use `slot run <class> <min> --
   <cmd>` to request, wait, run and release in one go.
7. **Commit at once.** Hand off each green slice the moment it is verified. One commit holds one
   task and one slice, with the task id in the message.
8. **Messages start with `[<crew>] <from> → <to>: <KIND>`.** `msg <kind>` prints them pre-filled.
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
| Snapshots: recover an overwritten edit | `references/snapshots.md` |
| Land, the git guard, pushing | `references/land.md` |
| Mailbox: `msg --send`, `inbox`, the unread notice | `references/inbox.md` |
| Adopting crew in a running project: hot spots, holds import, what to cut from CLAUDE.md | `references/adopt.md` |
| Watchdog: silent sessions, unread mail, stale slots; what wakes an idle coordinator | `references/watch.md` |

## When a hook says no

A denial names the holder, the slot or the rule, plus the command to run instead. Do that.
Never work around a guard with a different spelling of the same command. If the guard is
wrong, tell the coordinator, who can change `hookMode`.
