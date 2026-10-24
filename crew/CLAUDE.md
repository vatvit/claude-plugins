# CLAUDE.md — crew plugin

Guidance for working on this plugin. The repo-wide rules (shell conventions, plugin
independence, how to change a plugin) live in the repo root `CLAUDE.md` and apply here.

## Layout

```
crew/
├── .claude-plugin/plugin.json
├── bin/crew                `crew` on the Bash tool's PATH (a plugin's bin/ is added while it is enabled)
├── hooks/
│   ├── hooks.json          SessionStart + PreToolUse(Edit|Write|MultiEdit|NotebookEdit) + PreToolUse(Bash) + PostToolUse + Stop
│   ├── fast.sh             builtins-only "is there a crew here?" — sourced first by every hook
│   ├── session-start.sh    ~2 lines of context; silent in a repo without a crew
│   ├── pre-edit.sh         holds guard → snapshot → claim (each from its area script, if present)
│   ├── pre-bash.sh         whoami id pick-up → git guard (land area)
│   └── mail.sh             post | stop: unread-mail notice after a tool call, one held Stop per message
├── skills/crew/
│   ├── SKILL.md            roles + non-negotiables + pointer table (keep it under ~120 lines)
│   └── references/         one file per area, read only when that area is in play
└── scripts/
    ├── crew.sh             the one entry point; `help` is built from each script's `# help:` lines
    ├── lib.sh              the ONE place for project/state, config layers, identity, claims, locks, hook decisions
    ├── whoami.sh config.sh status.sh msg.sh active.sh end.sh
    ├── holds.sh slot.sh copy.sh tree.sh snapshot.sh land.sh inbox.sh watch.sh task.sh one area each: functions when sourced, CLI when executed
    ├── compose-report.awk  copy new's read-only Docker report (compose_report in lib.sh; fixtures in test/compose/)
    ├── status.d/  msg.d/   per-area parts, so adding an area never edits status.sh / msg.sh
    └── test/               helpers.sh, run.sh, <area>.test.sh, Dockerfile (bash:5 + git)
```

## Design rules (don't regress these)

- **No crew, no cost.** Every hook exits early unless `<git-common-dir>/crew/` exists. In a repo
  without a crew the plugin prints nothing and adds no tokens. A crew starts with the first
  `whoami` and ends with `crew end` (PLUG-075), which removes that state again; `crew active` is the
  same test for scripts (`crew_active`). `end` refuses while a crew worktree holds work (`crew_trees`
  in tree.sh, also what `status` lists) or mail is unread, and never deletes a worktree; `--force`
  is the user's word.
- **State lives in `<git-common-dir>/crew/`**, except what guards the machine (below). Every
  session on the tree shares it, it is never committed, and it needs no `.gitignore` entry. Every
  mutation goes through `with_lock` (`with_lock_at` for a lock in another dir) and `replace_file`
  (temp + `mv`).
- **Crew-only project rules are crew's to show (PLUG-076).** `crewRules` names a file in the tree;
  `crew_rules_print` shows it to a member on join and at SessionStart, never to a non-member, so a
  project's rules for crew mode cost a solo session nothing.
- **`ROOT` is the main tree, even from a linked worktree (PLUG-065).** `crew_try_init` reads
  `--show-toplevel --git-common-dir --git-dir` in its one `rev-parse`: `CREW_TREE` is the tree the
  session stands in, and `ROOT` is the main tree whenever the common dir is a `<main>/.git`. So a
  command run inside a copy acts on the shared tree and its crew, as from the root.
- **A copy is a detached worktree in `.worktrees/<repo>-<name>` (`CREW_WT`, `crew_wt_dir`).** Its
  meta is `crew-copy` in the copy's own git dir, so a pre-2.1 clone copy still works by path. The
  first copy runs `crew_wt_ignore`: `/.worktrees/` is appended to `.gitignore` only when
  `git check-ignore` says nothing ignores it yet, and left uncommitted. The pre-edit hook skips
  `.worktrees/*` (a copy is private), and `copy remove` refuses while the copy holds anything the
  tree does not. Tests make worktrees only in their `mktemp -d` fixtures.
- **Task worktrees are the user's choice (PLUG-066).** `tree` (project layer only) is `shared` until
  the user says `worktrees`; `tree_policy_note` reports it undecided, beside `git_policy_note`.
  Under `shared`, `$STATE/tree-allow` holds the user's per-task exceptions. `crew_wt_add` is the
  ONE way crew makes a worktree (copy and tree), and the record `crew-copy` carries `task=<ID>` for a
  task worktree. The git guard finds that record with `crew_wt_task` on the session's tree (or
  `git -C`) and then applies the worktree rules instead of the shared-tree ones.
- **A new worktree is made ready in one place (PLUG-067).** `crew_wt_ready` runs after every
  `crew_wt_add`: it links the `treeLink` paths from the main tree (data: `crew_link_ok` refuses
  absolute paths and `..`, at `config set` and again at runtime; a tracked path is never replaced),
  prints `treeSetup` without running it, then runs `compose_report`. `crew_link_filter` keeps those
  links out of "dirty" (`crew_wt_dirty`) and out of a copy's changes, so they never block a
  `sync`, `remove` or `apply`.
- **crew never writes to a project's Docker setup (PLUG-068).** The folder name makes each copy its
  own compose project; `compose_report` only reads `docker compose config --no-interpolate` and
  names what defeats that. It is silent without a compose file or docker, so the suites never call
  a real docker: `docker.test.sh` puts a stub on `PATH`.
- **Name vs display name.** Peers address a session by its SendMessage name, which may contain
  spaces. crew keeps that as `display=` and keys everything by `name_for` (the name itself when it
  is valid, else a lowercase slug), so `PLUG-W1` stays `PLUG-W1` and `Max Coordinator` becomes
  `max-coordinator`. Messages show display names, and `CREW_AS` accepts either form.
- **Membership is opt-in; a non-member works as usual (PLUG-055).** Only `whoami` joins. SessionStart
  never auto-joins (that was PLUG-042, reversed), because not every session on a repo belongs to its
  crew. The guards key on `NAME`: a session with none gets no git guard and no holds or hot-spot
  denial, only snapshots and claims. A member of a crew with no coordinator is told how to take the
  role, never sent to hand off to nobody.
- **Commits and pushes are the user's call, per project (PLUG-057).** The defaults commit and push
  nothing: `committer=human-approved` and `push=human`, the guard denying every member's push.
  `git_policy_note` (lib.sh) is the one test for "not decided yet" (neither layer sets the key);
  `status` and the coordinator's SessionStart line print it, and the skill makes the coordinator
  ask the user. A crew installed from the marketplace must never commit or push on its own.
- **One task, one session (PLUG-060).** Two sessions on one task cannot know which part of it is
  built, so a task in progress has one owner, and parallel work means separate tasks (the task
  plugin's sub-tasks). The words follow: crew speaks of tasks and changes, never of "slices", which
  read as pieces of one task shared out. `wording.test.sh` keeps the word out and the rule stated.
  The owner is `task=` in `sessions/<name>` (PLUG-061), set by `task.sh` only (`task_assign`, under the
  sessions lock; `tree new` calls it too) and kept across a re-join; `task_owner` finds it and
  `crew_line` shows it, so status, SessionStart and whoami agree. A task another session owns is
  refused, never shared; `--take` moves it and mails the old owner. Silence is not leaving: a silent
  owner keeps its task until it leaves or the coordinator hands the task over.
- **A crew name is the identity.** Holds, slots and claims are all keyed by name. The Claude
  session id only maps a hook payload to a name (`sessions/<name>`: `sid= role= since= display=`, and `task=` when set).
  Scripts learn the caller via `caller_name`, which takes `CREW_AS` (a name or a display name) when it
  is set, and otherwise `CREW_SID`. SessionStart exports `CREW_SID` through `CLAUDE_ENV_FILE`, the
  preamble Claude Code runs before every Bash command. It is documented for SessionStart hooks, not
  explicitly for plugin hooks; it works for crew's (checked live, PLUG-040). When the file is absent
  SessionStart teaches the `CREW_AS=<name> crew` form instead. `bin/crew` puts the command on PATH.
- **Per account vs per machine** (the repo rule in the root `CLAUDE.md` Config convention):
  - The user config `crew.json` is per account. It follows `${CLAUDE_CONFIG_DIR:-~/.claude}`.
  - `CREW_HOME` (`~/.claude/crew`) is per machine and deliberately ignores `CLAUDE_CONFIG_DIR`. It
    holds the name registry (SendMessage spans accounts), the slot queue (PLUG-074: CPU and Docker
    are the machine's, so every crew on it queues together) and the `ended` log.
  - `core.test.sh` asserts both; `crosscrew.test.sh` the shared queue.
- **Slots are machine-wide, decisions stay per crew.** One file, `$CREW_HOME/slots`, under its own
  lock; the row carries the owner's crew id for display. `slots_plan` adds `ours` (field 15), the one
  place that says whether a slot is this crew's: `release`, `slot clear` / the push hold and `watch`
  act only on this crew's. A slot whose owner is no longer `reg_live` is reaped under the lock by the
  next request, start or listing, so a vanished crew never holds the machine.
- **Names are unique on the machine, not just in the crew.** SendMessage addresses sessions
  machine-wide, and several crews (one per repo) can run at once. `whoami` checks
  `~/.claude/crew/names/<name>` (`CREW_HOME`) and refuses a name a live session of another crew
  holds. An entry is live while that crew's `sessions/<name>` still has the same sid (`reg_live`, the
  one liveness rule, also for slots); a stale one is taken over silently. Every message and the SessionStart line carry `[<crewId>]`.
- **Nobody types a session id.** The pre-bash hook sees the session id of the
  `crew.sh whoami <name>` call and leaves it in `<git-common-dir>/crew-pending/<name>` for `whoami.sh` to bind. It is outside `crew/` on purpose:
  a join that never completes must not switch crew on for the repo and put peer sessions under the guard.
  `--sid` is the fallback for when the hooks are not installed.
- **Area scripts are dual-use.** `holds.sh`, `slot.sh` and the rest define functions when
  sourced (by hooks and other scripts) and run their CLI when executed (`is_main`). Hooks load
  them with `load_area`, so a missing area degrades instead of failing.
- **Guard hooks deny**: the repo's one exception to "hooks never block", with its why, is in the
  root `CLAUDE.md` (Shell Conventions). Here: the denial is `hook_block` (lib.sh), and nothing else
  emits a `permissionDecision`.
- **Hooks pay nothing where there is nothing to do.** They run on every Bash call and every edit,
  in every repo. `hooks/fast.sh` reads the payload with `read` and walks up to `.git` with pure bash.
  With no `crew/` there, the hook exits without a single fork. pre-bash also exits early unless the
  payload names a guarded git subcommand or `whoami`. Measured: 47 → 3 ms per Bash call. Keep any new
  hook logic behind these checks.
- **Config is parsed once per process.** `crew_try_init` runs one `git rev-parse` (it needs git
  2.31 or later for `--path-format=absolute`) and one awk pass over both config files into `CREW_CFG`.
  After that, `cfg` forks nothing. The pre-edit hook reads config several times per edit, and this
  took it from ~95 ms to ~50 ms. Never read a config file directly anywhere else.
- **lib.sh owns the one EXIT trap.** It drops a lock left by a dying process and then runs
  `CREW_ON_EXIT` (for example, `slot run` releasing its slot). A script that sets its own `trap … EXIT`
  silently disables both, so it sets `CREW_ON_EXIT` instead. That includes tests that source `lib.sh`.
- **Silence is measured, not guessed.** Every tool call bumps `<state>/seen/<sid>` (fast.sh: `crew_fast_seen`,
  a redirection on a builtin, so no fork), and `watch.sh` reads its mtime. A session counts as silent only
  while it owns something (hold, slot, claimed dirty path). An idle session that owns nothing is just idle.
  The stale-slot rule lives once, in `slots_plan` (field 14); `slot list` and `watch` both read it.
- **Mail is a file before it is a message.** `msg --send` files a copy under `<state>/mail/<name>/`,
  and the mail hooks repeat the notice until it is read. They find "no mail for me" without a fork:
  sending leaves `<state>/unread/<sid>` for the recipient (fast.sh: `crew_fast_unread`), and the slow
  path removes a stale marker. `whoami` and SessionStart re-arm it for a session's new id.
- **Claims are advisory.** The pre-edit hook records which session touched which path. A path
  written another way (Bash, a generator) shows as *unclaimed* in `status`, which is the point:
  `status` surfaces it instead of guessing.
- **Scripts do the mechanics, the skill does judgement.** Before adding prose to the skill,
  check whether a script could print the answer instead. That is how `status`, `msg` and the
  denial texts came about.

## Testing

```bash
bash crew/scripts/test/run.sh                                   # host: bash 3.2 + BSD userland
docker build -t crew-test crew/scripts/test                     # once: bash:5 (Alpine/busybox) + git
docker run --rm -v "$PWD":/w -w /w crew-test bash crew/scripts/test/run.sh
```

**Run both.** The plain `bash:5` image has no git, and every crew script needs it, hence the
Dockerfile. Hooks are tested by piping a JSON payload into them (`helpers.sh: payload, hook`).
`join` goes through the real path, so the hook leaves the id and `whoami` binds it. The suites
never read the real `~/.claude/crew.json` (`CREW_USER_CONFIG` points into the fixture).

What the suites cannot prove: that Claude Code honours the `permissionDecision: deny` JSON, injects
SessionStart stdout and PostToolUse `additionalContext`, and runs the `CLAUDE_ENV_FILE` preamble for a
plugin hook. Check them by hand once per Claude Code upgrade, in a session started *after* crew was
installed (a plugin installed mid-session has no hooks in that session), in the repo the session runs
in (the Bash tool returns to it after every call, so a scratch repo cannot host the check):
`crew whoami <name>` binds without `--sid`; `git add -A -- <no such path>` is denied with crew's reason
(`--dry-run` is let through on purpose, and a no-match pathspec stages nothing if the guard fails);
a Write to a path another member holds is denied naming the holder; a `msg --send` to yourself shows
the unread notice after the next tool call, and ending the turn with it unread is held by Stop; `crew active` names you with no `CREW_AS`. Then
`whoami --leave <name>`.

Last checked: Claude Code 2.1.307, crew 2.2.0 (2026-10-24, PLUG-040) — all of the above, plus the
SessionStart line after `/compact` and the Stop hold with unread mail.
