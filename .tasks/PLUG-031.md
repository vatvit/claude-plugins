---
title: crew — land path lists with one committer + git-index guard hook
status: completed
type: feature
epic: crew
priority: high
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | same session; pre-bash hook already calls `git_guard` via load_area; slots expose `slot_quiet_holder` |
| 20 | Requirements | skipped | ACs specific enough |
| 30 | Assessment | done | measured pre-bash at 47 ms per Bash call in repos WITHOUT a crew → fast path needed |
| 40 | POC | skipped | no unknowns |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | see Architecture |
| 70 | Tests | done | `crew/scripts/test/land.test.sh` (79 checks) |
| 80 | Subtasks | skipped | small enough |
| 90 | Implementation | done | 257/257 host + docker + standalone copy |
| 100 | Tech Debt | done | none filed |
| 110 | Reflection | done | references/land.md, SKILL/README rows, crew CLAUDE.md fast-path rule + layout; 1.0.0 |

## Description

One committer and a safe shared index (playbook §1, §4, §6).

- `land.sh --msg-file F -- <paths…>`:
  - checks that every listed path is dirty;
  - reports dirty paths that are not in the list (another session's work);
  - refuses paths that are already staged by someone else;
  - then runs `git commit -F F -- <paths>`.

  It respects `committer` mode: `coordinator` (only the coordinator session lands),
  `each-session` (lands its own paths only), `human-approved` (prints the exact command and
  stops). It prints the new sha and a `msg.sh release`-ready line.
- `land.sh prepush` lists `origin/<sharedBranch>..HEAD` so it can be matched against what
  was verified.
- A PreToolUse hook on Bash **denies** the commands that touch the whole index or tree:
  `git add -A|.|-u`, `commit -a`, `stash`, `checkout -- .`, `restore .`, `reset --hard`,
  `clean`, `worktree`, branch switches away from `sharedBranch`, and `git commit` from a
  session that is not the committer. Each denial names the safe alternative. `hookMode=warn`
  turns them into warnings.
- `references/land.md`, covering push verification: read the output, not the exit status of
  a pipe; format the final land list after the last edit; send a failure to its owner.

## Acceptance criteria

- [ ] `land` with a path that is not dirty is refused. It reports an unlisted dirty path
      without committing it.
- [ ] In `coordinator` mode a worker's `land` / `git commit` is denied with the reason. In
      `human-approved` mode nothing is committed.
- [ ] Each guarded git form is denied, and harmless forms (`git add path`, `git status`,
      `git log`) pass. Quoting and chained commands (`a && git add -A`) are covered.
- [ ] `hookMode=warn` lets the commands through with the reason printed.
- [ ] The suite passes in docker and from a standalone copy.

## Architecture

- `crew/scripts/land.sh`, dual-use. Sourced: `guard_reason` / `git_guard`; executed: `land`, `land prepush`.
- `land` validates the whole list before committing anything: each path must be dirty, not held
  by someone else (the coordinator may land a holder's hand-off), and under `each-session`
  touched by the caller. It then reports every dirty path it leaves behind with its owner and
  any paths staged outside the list. It stages only the listed untracked files and runs
  `git commit -F msg -- <paths>`. `human-approved` stops after the checks and prints the exact
  commands.
- `git_guard` splits the command line into simple commands (`&& || ; | & ( )`), drops quotes,
  skips env assignments and wrappers, and parses git's global options. `guard_reason` applies
  one rule per subcommand (see `references/land.md`). Exact-path forms always pass. The commit
  rule needs `-- <paths>` and the right role for the committer mode. A push is held during
  another session's quiet slot.
- **Hook fast path (`hooks/fast.sh`), applies to all hooks:** read the payload with `read`, and
  walk up to `.git` in pure bash. With no `crew/` there, exit without a fork. pre-bash also
  exits early unless the payload names a guarded git subcommand or `whoami`. Pre-bash went from
  47 to 3 ms in a repo without a crew, and to 3 ms for `ls` / `git status` in a crew repo. The
  guarded path costs ~60–120 ms, depending on machine load.

## Implementation

`land.sh`, `hooks/fast.sh`, the three hooks (fast path), `lib.sh` (`hook_init` reuses PAYLOAD);
`land.test.sh` 79/79 (30 deny + 17 allow cases, modes, quiet push, land/prepush); full run 257/257 on
host and in `crew-test`, also from a standalone copy. Plugin 1.0.0.

## Reflection

- `references/land.md`; SKILL pointer row; README row; crew `CLAUDE.md` "Hooks pay nothing where there is
  nothing to do" + layout (fast.sh, area scripts). plugin.json keywords refreshed.
- Lesson: in `case`, a pattern held in a variable is a glob, so `'*'` matches every word. To
  match a literal star, use `'\*'`. This made the guard deny every `git add` until it was
  fixed before the first run.
- Coordination: a peer session (kickoff plugin) shares `marketplace.json`, the repo
  `CLAUDE.md` and `PLUG-025.md`. marketplace.json was claimed by message before this commit.

## Current State

Completed. Build green.
