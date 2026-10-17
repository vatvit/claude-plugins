# Working solo, ending a crew, rules per mode

A project does not run a crew all the time. Sessions come and go; at some point one session works
alone again. crew is built for that: with no crew in the repo it prints nothing and guards nothing.

## Is a crew running here?

`crew active` answers it for scripts and hooks: exit 0 and one line (`crew <id>: <members>`, plus
`you: <name> (<role>)` when the caller is in it), or exit 1 and no output, outside git too.

```
if crew active >/dev/null; then crew slot run exclusive 15 -- ./e2e.sh; else ./e2e.sh; fi
```

A session that is not in the crew works as usual even while one runs (SessionStart says so).

## Ending a crew

`crew end` (the coordinator) closes it: holds and slots are released, the names are freed on the
machine, and the repo's crew state is removed, so every hook is silent again. It prints the message
for the other members; send it with SendMessage, since their mailboxes go with the state.

It refuses while something would be lost, and names it:
- a copy holding work the tree does not (`apply` it, or `copy remove` after dropping it);
- a task worktree with uncommitted or unmerged work (`tree merge`);
- unread crew mail (`inbox`).

`crew end --force` ends it anyway, from any session, also when nobody is left in the crew. Use it only
on the user's word. crew never deletes a worktree: `end` names the ones left in place. A one-line record
of each end stays in `~/.claude/crew/ended`.

One session leaving is `whoami --leave <name>`; the crew goes on without it.

## Project rules per mode

A project's `CLAUDE.md` is read by every session, crew or not. Split its session rules by when they
apply:

1. **Rules crew enforces**: cut them. The guard and the config already carry them
   ([adopt.md](adopt.md), step 5).
2. **Rules for every session**: build and test, conventions, the domain. They stay in `CLAUDE.md`.
3. **Rules that apply only while a crew runs**, which no guard can enforce: "build red work in a copy",
   "check the commit list before pushing", "ask the coordinator before touching the schema". Move them
   to their own file in the repo and point crew at it:

   ```
   crew config set crewRules CLAUDE.crew.md
   ```

   Members are shown the file when they join and at every session start. A solo session or a
   non-member never sees it, so it costs them nothing. `CLAUDE.md` keeps one line about it:

   ```markdown
   While a crew runs here, its members also follow CLAUDE.crew.md (crew shows it to them).
   ```

## Machine time when one repo has no crew

Slots are one queue for the whole machine: an `exclusive` run in one repo makes a run in another repo
wait ([slots.md](slots.md)). Only crew members queue. A session working alone in a repo that should
queue against another repo's crew joins a crew of one: `crew whoami "<name>" coordinator`, then
`slot run …`. `crew end` gives the repo back when it is done.
