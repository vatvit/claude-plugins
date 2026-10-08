---
title: crew — land path lists with one committer + git-index guard hook
status: proposed
type: feature
epic: crew
priority: high
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | — | |
| 20 | Requirements | — | |
| 30 | Assessment | — | |
| 40 | POC | — | |
| 50 | Domain | — | |
| 60 | Architecture | — | |
| 70 | Tests | — | |
| 80 | Subtasks | — | |
| 90 | Implementation | — | |
| 100 | Tech Debt | — | |
| 110 | Reflection | — | |

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
