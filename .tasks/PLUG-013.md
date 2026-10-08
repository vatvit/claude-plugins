---
title: delay plugin — wake the laptop and run approved per-project jobs in docker
status: completed
type: feature
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | Conventions, platform facts (pmset owner tag, date portability), no collisions — see ## Context |
| 20 | Requirements | done | R1–R16 EARS — see ## Requirements |
| 30 | Assessment | done | Greenfield delay/; shared files: marketplace.json, repo CLAUDE.md |
| 40 | POC | skipped | Only unknown is hardware wake, which needs a sudo install — left to the user (AC3) |
| 50 | Domain | done | job / queue entry / registry / pin / result — see ## Domain |
| 60 | Architecture | done | Dispatcher = LaunchAgent; daemons run root-owned copies; installed.conf blocks env override |
| 70 | Tests | done | delay.test.sh: 105 checks, green on host + bash:5 + standalone copy |
| 80 | Subtasks | skipped | Done in one session; the A–D split was not needed |
| 90 | Implementation | done | delay/ 1.0.0 + marketplace + repo CLAUDE.md — see ## Implementation |
| 100 | Tech Debt | done | Listed in ## Tech Debt; no tickets raised yet |
| 110 | Reflection | done | 2 shell conventions → repo CLAUDE.md — see ## Reflection |

## Description

A new, fully independent plugin: any Claude session can schedule a **named, pre-approved job**
(typically a long autotest run) for its project at a given time. The Mac wakes from sleep at that
time, runs the job inside the project's own docker container without anyone logged in at the
screen, and stores the result where any later session can read it.

Main use case: delay time-consuming test suites to the night.

## Why

Researched 2026-10-03 (see ## Research). Nothing existing combines all three of: wake on time,
run without an interactive login, and restrict to approved per-project commands.

- Claude Desktop scheduled tasks: skipped while asleep, one catch-up run on wake.
- `/loop`, CronCreate: die with the session.
- `/schedule` (cloud routines): run in Anthropic's cloud, cannot touch the laptop.
- Third-party launchd/cron schedulers (intertwine scheduler, jshchnz/claude-code-scheduler,
  Oz scheduler, claudecron, AgentCron, runCLAUDErun): catch-up after wake at best, no wake,
  no command whitelist.

## Design (agreed in discussion — negotiable until Architecture)

**Jobs are names, not commands.** Claude never passes command text. It can only say
"run `tests-full` in this project at 03:00"; the command comes from a registry Claude cannot edit.

### Storage

```
~/.claude/delay/<encoded-project>/          user-writable, Claude writes here
  project.path                                  real absolute path (source of truth)
  queue/<id>.job                                job name + run_at only
  results/<id>/{log,exit,meta}                  written by the dispatcher only

/Library/Application Support/claude-delay/<encoded-project>/registry   root-owned
  job name -> compose file, service, command + sha256 pins
```

- **Not** `~/.claude/jobs/` — that name is already owned by Claude Code (`state.json`,
  `timeline.jsonl` per entry). **Not** `~/.claude/projects/` (Claude Code cleans it up) and
  **not** `~/.claude/project-tasks/` (the task plugin's namespace).
- Encoding is Claude Code's style (`/` -> `-`), which is lossy (`/a/b-c` vs `/a-b/c`), so
  `project.path` is authoritative; a mismatch refuses, never guesses.
- Project = `git rev-parse --show-toplevel`, falling back to `pwd`.

### Components

| Piece | Runs as | Does |
|---|---|---|
| `delay.sh add/list/rm/show` (the skill's client) | user (Claude) | writes/reads the queue and results of the current project; rejects unknown job names |
| dispatcher (LaunchDaemon with `UserName`, `StartInterval 60`) | user | runs due jobs: verify pins -> `docker compose run` -> capture stdout + exit code on the host |
| wake scheduler (LaunchDaemon) | root | only parses timestamps strictly and syncs `pmset schedule wake` for the next pending jobs |
| `approve` | root, via `sudo` by the user | shows command + `docker compose config` red flags, records sha256 of compose file, Dockerfile, wrapper script |
| `install-daemon.sh` | the user runs it once with sudo | installs the two plists. **Claude never runs it.** |

### Security guarantees

- Claude can only trigger approved job names in approved projects (root-owned registry).
- Confinement cannot change without `sudo approve`: the compose file, Dockerfile and wrapper
  script are pinned by hash; any change -> `needs re-approval`, nothing runs.
- Test/app code is deliberately **not** pinned — running Claude's latest changes is the point;
  the container bounds it.
- `~/.claude/delay` is never mounted into the container, so test code cannot fake its own
  result.
- `approve` flags: `privileged`, `cap_add`, docker socket mounts, host mounts outside the
  project, `network_mode: host`. Recommended in the compose: `.git` and `.claude` read-only,
  `internal: true` network when tests need no internet, run as the user's uid.
- Remaining accepted gap: the job may change project files you later run on the host —
  mitigated by read-only `.git`/`.claude` and a `git status`/`git diff --stat` in the result.

### Operational limits (document them, don't fight them)

- Lid closed on battery: most MacBooks do not wake. Lid open or on AC: fine.
- Sleep works; shutdown / FileVault reboot does not (no docker, disk locked).
- Docker is OrbStack (user app, VM): dispatcher retries `docker info` ~30-60 s after wake.
- Wrap runs in `caffeinate -i` or the dark wake sleeps again; enforce a hard timeout.
- Keep the last N results per job (retention).

## Naming — decided 2026-10-03

Plugin `delay`, command `/delay`, client `delay.sh`, storage `~/.claude/delay/`, root registry
`/Library/Application Support/claude-delay/`. (`/schedule` is taken by cloud routines; `/job` was
the other candidate.) "Delay" fits the one-shot scope — recurring stays out of scope. The unit of
work is still called a *job*.
Trigger vocabulary must be **disjoint from the task plugin**: own *delay / delay a job / run later
/ run tonight / run at / wake*, never the word *task* ("delay task PLUG-13's tests" must not be a
coin flip).

## Independence

Fully independent, per repo CLAUDE.md: no sourcing of other plugins, no shared storage, no
`task=` link to the task plugin (dropped). Own `scripts/lib.sh`, bash 3.2, BSD+GNU userland,
no `sed -i`, diff-guarded writes, hooks exit 0.

## Out of scope

- Arbitrary commands, `claude -p` / AI jobs (would need `claude setup-token`; later, maybe).
- Linux/systemd and Windows.
- Recurring schedules (one-shot first; keep the format open for it).
- Any link to the task plugin.

## Acceptance criteria

1. From a Claude session, `/delay add tests-full 03:00` in an approved project creates a queue
   entry; an unapproved name or project is rejected with a clear message.
2. `/delay list` shows the current project's queued jobs and recent results (pass / fail /
   `needs re-approval` / `project missing`); `/delay rm <id>` removes a queued job.
3. With the Mac asleep, screen locked, on AC, the job runs at the scheduled time
   (verified by `pmset -g log` wake reason + the result's timestamps).
4. Editing the compose file, Dockerfile or wrapper after approval -> the job is refused with
   `needs re-approval`; editing test code -> the job runs.
5. The result log and exit code come from the host-side capture; the container has no mount of
   `~/.claude/delay`.
6. The plugin's test suite passes when the plugin dir is copied somewhere with no siblings.
7. Plugin registered: `plugin.json`, `marketplace.json`, Plugins table in repo CLAUDE.md,
   README with the install (sudo) step and the operational limits.

## Candidate split (decide at Subtasks)

Meet only at the `.job` file format and the registry format — agree those first, then these
can run in parallel sessions on disjoint files:

- A. queue + `delay.sh` client + skill (read and write side together)
- B. dispatcher: pin verification + docker run + result capture + retention
- C. wake scheduler + `install-daemon.sh` (pmset, plists)
- D. `approve` + `docker compose config` red-flag checks

## Research

- Claude Code docs, Desktop scheduled tasks: https://code.claude.com/docs/en/desktop-scheduled-tasks
- Amit Kothari, Claude Code scheduled jobs: https://amitkoth.com/claude-code-scheduled-jobs
- intertwine scheduler plugin: https://claudepluginhub.com/plugins/intertwine-scheduler
- jshchnz/claude-code-scheduler: https://cdn.jsdelivr.net/gh/jshchnz/claude-code-scheduler@main/README.md
- claudecron: https://github.com/phildougherty/claudecron
- `wakeScheduler` flag issue (Anthropic may be adding wake to Desktop, unconfirmed):
  https://claudeissues.com/issue/44129-scheduled-tasks-never-execute-automatically-wakescheduler-feature-flag-unavailab

## Context

**Epic:** none. **Related tasks:** PLUG-001..012, all completed. No sibling covers scheduling.
No rejected task touches this ground (only PLUG-001 mentions "rejected", unrelated).

**Prior decisions that bind this plugin (do not re-litigate):**
- PLUG-006 → repo CLAUDE.md *Plugin Independence* + *Config convention*: own `scripts/lib.sh`,
  never source a sibling, cross-plugin duplication of a small helper is correct. Any config file
  is a flat JSON named for the plugin (`.delay.json`), every key optional. Helpers whose empty
  result is normal end in `|| true` (the `set -e` + `grep` bug shipped once in task-roadmap 1.0.1).
- PLUG-008 / PLUG-011 → `#!/usr/bin/env bash` only. The bug shows only when one script *execs*
  another, and only on Alpine.
- PLUG-008 reflection → a test that greps for forbidden patterns matches itself; exclude the test
  file by path, once.

**Patterns to match (from `task-roadmap/`, the cleanest template):**
- Layout: `.claude-plugin/plugin.json`, `scripts/lib.sh`, `scripts/test/<name>.test.sh`,
  `skills/delay/SKILL.md`, `CLAUDE.md`, `README.md`; hooks only if needed (`hooks/hooks.json`,
  auto-discovered).
- Test harness: no framework. `check <name> <expected> <actual>`, fixtures under `mktemp -d`,
  never touches the real repo. **Dual target, run both:**
  `bash delay/scripts/test/delay.test.sh` and
  `docker run --rm -v "$PWD":/w -w /w bash:5 bash delay/scripts/test/delay.test.sh`.
- `plugin.json`: `name`, `description`, `version`, `author {name: Vat, url}`, `license: MIT`,
  `keywords`. The marketplace entry uses `"source": "./delay"`.
- Plugin skills are namespaced, so the user types `/delay:delay` (the task skill is `/task:task`).

**Platform facts (checked on this Mac 2026-10-03, hard to find, keep):**
- `pmset schedule [cancel] wake "MM/dd/yy HH:mm:ss" [owner]`. The **owner** argument lets us tag
  our wakes (`claude-delay`) and cancel only ours. **Never `cancelall`**: it wipes other apps'
  wakes, and `pmset -g sched` shows system ones such as `com.apple.alarm...calaccessd`. Events are
  stored in `/Library/Preferences/SystemConfiguration/com.apple.AutoWake.plist`. Needs root.
- `pmset -g sched` lists events as `wake at MM/DD/YYYY HH:MM:SS by '<owner>'`, which is parseable
  to sync state.
- Host tools: `docker` = OrbStack at `/usr/local/bin/docker`, Docker Compose v5.1.2; `shasum` and
  `sha256sum` both exist on macOS; Alpine/bash:5 has only `sha256sum` → a helper must pick.
  `plutil` is available to validate plists.
- **Portability traps to design around:** date parsing/formatting differs (BSD `date -j -f` /
  `date -r <epoch>` vs GNU `date -d` / `date -d @<epoch>`) → store `run_at` as **epoch seconds**
  and keep the only date conversions in one `lib.sh` helper with both branches. Use
  `cd … && pwd -P` rather than `realpath` for path resolution.
- **Test seams:** `pmset`, `launchctl`, `docker`, `caffeinate` don't exist in bash:5 and must
  never really run in tests → PATH shims in the suite; scripts call them by bare name.

**Name clashes checked:** `~/.claude/jobs/` is Claude Code's own (per-entry `state.json`,
`timeline.jsonl`) → avoided. `~/.claude/delay/` doesn't exist. Trigger words owned by others:
task (*task*), task-roadmap (*roadmap / gantt / timeline*), docs-manager (*docs / index / links /
diagram*), session-storage (*storage / session data*) → *delay / run later / run at / wake* is free.

**Parallel-session collisions:** none. No other task is in progress, and the work goes into a new
`delay/` directory. The shared files touched at the end are `.claude-plugin/marketplace.json` and
the Plugins table in the repo `CLAUDE.md`. `.task-config.json` shows modified only because
`allocate-id.sh` advanced `nextId`.

## Requirements

EARS. "Client" is `delay.sh`, which Claude runs. "Dispatcher" runs as the user via launchd.
"Wake sync" runs as root via launchd. "Approve" and "install" are run by the human with sudo.

- R1 (ubiquitous) The client shall accept only a job **name** and a time. It never takes command
  text.
- R2 (event) When `add` names a project or job absent from the registry, the client shall refuse
  with exit 1 and a message naming the approve command.
- R3 (event) When `add` is given `HH:MM`, `YYYY-MM-DD HH:MM` or `+N[mhd]`, the client shall store
  `run_at` as epoch seconds. A past `HH:MM` means tomorrow. A past absolute time is refused.
- R4 (ubiquitous) `list` shall show the current project's queued jobs and its latest results.
  `show <id>` shall show a result's meta and log path. `rm <id>` shall remove a queued job only.
- R5 (event) When a queued job is due, the dispatcher shall claim it atomically and run
  `docker compose -f <compose> run --rm -T <service> <command>` in the project root, under
  `caffeinate -i`.
- R6 (unwanted) If any pinned file's sha256 differs from the registry, then the dispatcher shall
  not call docker and shall record `needs-reapproval`.
- R7 (unwanted) If the project dir is missing, `project.path` mismatches, the job is no longer
  approved, or the job file is malformed, then the dispatcher shall record `project-missing` /
  `not-approved` / `invalid` without running anything.
- R8 (unwanted) If docker is not answering within `DELAY_DOCKER_WAIT` (default 60 s), the
  dispatcher shall record `docker-unavailable`.
- R9 (unwanted) If a run exceeds its timeout (default 3 h, set per job at approve time), the
  dispatcher shall kill it and record `timeout`.
- R10 (ubiquitous) The result (exit code, status, timings, lateness, `git status --short` of the
  project) shall be captured on the host. `~/.claude/delay` is never part of the docker invocation.
- R11 (ubiquitous) Only one dispatcher run at a time (a lock with stale-PID recovery). Keep the
  last 20 results per project.
- R12 (event) On every tick, wake sync shall make the set of `pmset` wakes owned by `claude-delay`
  equal the next ≤3 future, approved queue times minus 30 s. Only diffs touch pmset. Never
  `cancelall`.
- R13 (unwanted) If a queue entry's `run_at` is not all digits or its job name is not
  `[A-Za-z0-9._-]`, wake sync (root) shall ignore it.
- R14 (event) When approve runs, it shall pin the compose file, the wrapper and any `--pin` files
  (plus a `Dockerfile` next to the compose file, if one exists). It shall show `docker compose
  config` red flags and refuse on red flags unless `--accept-risks`. Wrapper and pins must
  resolve inside the project.
- R15 (ubiquitous) The daemons shall run root-owned *installed copies* of the scripts. An
  installed copy shall ignore environment overrides of its paths.
- R16 (ubiquitous) Install and approve are never run by Claude. The skill tells the user the
  exact command.

## Assessment

Greenfield `delay/` directory, so there's nothing to break. Ready.
- Shared files touched: `.claude-plugin/marketplace.json`, the repo `CLAUDE.md` Plugins table and
  trigger-vocabulary line.
- No collisions (see ## Context).

## Domain

- **job**: an approved, named command for one project (`tests-full`). It lives in the registry.
- **queue entry**: a request to run a job at `run_at`, written by the client.
- **registry**: root-owned; per project, `project.path` plus `jobs/<name>` (compose, service,
  command, timeout, pins).
- **pin**: `<relative path> <sha256>`. Confinement-defining files only, never test code.
- **result**: `results/<id>/{job,meta,log}`, written by the dispatcher.
- Use "job", never "task", in all user-facing text: the task plugin owns that word.

## Architecture

**Honest threat model.** A Claude session already has a user-level shell, so it could install its
own LaunchAgent. No plugin can stop a hostile agent with a user shell; that boundary is Claude
Code's permission system. This plugin guarantees something narrower but real:
- *Through this plugin*, nothing runs unattended unless a human approved it with sudo.
- Approved confinement cannot drift without re-approval.
- Accidental edits to the scheduling machinery are impossible, because the daemons run root-owned
  copies.

**Key decision: the dispatcher is a LaunchAgent, not a LaunchDaemon with `UserName`.** Docker is
OrbStack, a per-user app, so docker exists only while the user is logged in. "Without login"
therefore means *screen locked*, which a LaunchAgent (gui domain) covers. It also gets a proper
user environment. The plist goes in `/Library/LaunchAgents`, which is root-owned, so it can't be
edited.

```
/Library/Application Support/claude-delay/       root:wheel 755
  bin/{lib.sh,dispatch.sh,wake-sync.sh,approve.sh,installed.conf}   installed copies
  registry/<enc>/{project.path,jobs/<name>}
  state/wakes                                    exact pmset strings we scheduled
/Library/LaunchDaemons/com.claude-delay.wake.plist      root, StartInterval 60
/Library/LaunchAgents/com.claude-delay.dispatch.plist   user, StartInterval 60
~/.claude/delay/<enc>/{project.path,queue/,results/,.lock}
```

- **Wake timing:** wake at `run_at − 30 s`. launchd fires an overdue StartInterval job on wake,
  and the dispatcher then holds `caffeinate -i -w <pid>` for the run. *Unverified on hardware:*
  whether a dark wake survives until the first tick. That is the manual AC3 check.
- **Cancel only what we scheduled.** `state/wakes` stores the exact strings we passed to pmset, so
  we cancel those and never parse `pmset -g sched` back.
- **Formats** are `key=value` lines (job, meta, registry job). Pins are repeated
  `pin=<relpath> <sha256>` lines.
- **`installed.conf`** sits next to the installed scripts. When it is present, `lib.sh` takes its
  paths from it and ignores `DELAY_*` env. This closes `launchctl setenv DELAY_REGISTRY=…`.
- **Test seams:** `DELAY_HOME`, `DELAY_REGISTRY`, `DELAY_STATE`, `DELAY_NOW`,
  `DELAY_DOCKER_WAIT`, `DELAY_INSTALL_PREFIX`, plus PATH shims for docker, pmset, launchctl and
  caffeinate. These are honoured only without `installed.conf`.
- **Encoding:** `tr -c 'A-Za-z0-9\n' '-'`. `project.path` is authoritative, and a collision
  refuses.
- **Dates:** BSD `date -j -f … +%s` first, falling back to GNU `date -d`. Seconds are always given
  explicitly, because BSD fills omitted fields from *now*.
- A late run (Mac asleep or off at `run_at`) still runs, and `late=` records by how much.

## Tests

`delay/scripts/test/delay.test.sh` has 105 checks and no framework. docker, pmset, launchctl and
caffeinate are PATH shims, and all `DELAY_*` paths point into `mktemp -d`. It covers:
- dates (including the BSD seconds trap)
- identity and traversal guards
- approve: pins, auto-pinned Dockerfile, red flags, `--accept-risks`, revoke, list, idempotent
  re-approve
- client add/list/show/rm/jobs and its refusals
- dispatcher: passed, failed, test-code change still runs, pin change refuses without calling
  docker, not-approved / invalid / project-missing / docker-unavailable, timeout plus container
  removal, live and stale lock, retention
- wake sync: owner tag, 30 s lead, cap of 3, idempotent, cancel-on-remove, failed pmset retried
- install: copies, plists (`plutil -lint` on the host), installed copy ignores env, refusal paths,
  uninstall
- conventions scan

Results on 2026-10-03: **105/105 on the host (bash 3.2, BSD)**, **105/105 in bash:5 (busybox)**,
and 105/105 on both from a standalone copy of `delay/` with no siblings.

## Implementation

New `delay/` plugin, version 1.0.0:
- `scripts/{lib,delay,dispatch,wake-sync,approve,install-daemon}.sh`
- the test suite
- `skills/delay/SKILL.md`, `plugin.json`, `README.md`, `CLAUDE.md`

Registered in `.claude-plugin/marketplace.json` and in the repo `CLAUDE.md` (structure tree,
Plugins table, trigger vocabulary).

Changes made during implementation, beyond the Architecture:
- The run container is named `claude-delay-<id>` and is `docker rm -f`'d on timeout. Killing the
  CLI alone can leave the container running.
- docker's stdin is `/dev/null`. Otherwise `docker compose run` can swallow the rest of the
  dispatcher's queue list, which arrives through a `while read` pipe.
- `delay.sh status` reports `installed_current=no` when the root-owned copies differ from the
  plugin. A plugin update does not reach the daemons until the install is re-run.
- A smoke test against the real paths (`status`, `jobs`, and `add` refused) found the client's
  approve hint showing the wrong syntax. It is fixed and wrote nothing to `~/.claude/delay`.

**Not run, by rule:** `install-daemon.sh` and `approve.sh` for real (sudo, installs on the host).

## Tech Debt

No tickets raised. Candidates, in order of value:
1. **AC3 (hardware wake) is unverified.** Does a pmset dark wake survive until the LaunchAgent's
   next tick? If not, the fix is to have wake-sync kick the agent itself
   (`launchctl kickstart gui/<uid>/com.claude-delay.dispatch`) right after a wake.
2. **No lateness cap.** A 03:00 job runs at 10:00 when you open the lid, which may be unwanted.
   Candidate: a `max_late` setting per job at approve time.
3. **DST:** a past `HH:MM` adds 86400 s, so it is an hour off on a DST-change day.
4. Results are user-writable, so a session could edit them. This is accepted and documented.

## Reflection

- **Repo `CLAUDE.md` *Shell Conventions*** gained two rules that apply to every plugin:
  - `pipefail` + `| grep -q` in tests (SIGPIPE turns a match into a failure)
  - BSD `date -j -f` filling missing fields from *now*

  The delay `CLAUDE.md` points to them instead of repeating them.
- **Repo `CLAUDE.md`:** delay added to the structure tree, the Plugins table and the trigger
  vocabulary (*delay / run later / run tonight / run at / wake*; says *job*, never *task*).
- **Lessons:**
  - Writing the threat model down changed the design. Once it was written that Claude already has
    a user shell, two choices became obvious: running the daemons from root-owned *copies* (not
    the plugin dir), and `installed.conf` ignoring env. Both close real gaps (`launchctl setenv`)
    that a "whitelist" alone leaves open.
  - Docker being a per-user app (OrbStack) settled LaunchAgent vs LaunchDaemon. There is no
    docker without a login session, so a daemon would add privilege without adding capability.

## Design change — 2026-10-03: the user owns the time

**Vat:** "claude should not set a time. the user setup the time for all delayed jobs".
This supersedes R3, the `/delay add <job> 03:00` form in the acceptance criteria and in the
Naming section, `run_at`, the cap of 3 wakes, and "a late run still runs" (Tech Debt #2 is now
moot).

- **One daily run window for all jobs.** `sudo approve.sh --window HH:MM HOURS` writes the
  root-owned `/Library/Application Support/claude-delay/window` (`start=`, `hours=`, 1–24h, local
  time; it may cross midnight). With no window set, nothing runs, and `status`/`list` say so with
  the exact command.
- **`delay.sh add <job>` takes no time.** A time argument is refused, and the message points at the
  user's window. A job already queued for the project is not queued twice. The queue entry holds
  `id, project, job, created`, with no `run_at`.
- **The dispatcher starts jobs only inside the window.** It re-checks before each job, so a long
  run that overlaps the window's end stops further starts. A missed window waits for the next one,
  with no catch-up run outside it. So a forged `created=` buys nothing, and there is no
  "03:00 job runs at 10:00 when the lid opens".
- **Wake sync keeps exactly one wake**, at the next window start − 30 s, and only while an approved
  job is queued. Moving the window re-schedules; an empty queue cancels.
- AC1 now reads: `/delay add tests-full` in an approved project queues it for the user's window.
  AC3 now reads: with the Mac asleep and a job queued, it runs at the window start.

Verified: suite rewritten for the window model (dates, window math including midnight crossing,
refusal of a time, dedupe, nothing starts with no window or outside it, the single wake moves
and cancels). Results: **120/120 on the host, 120/120 in bash:5, and 120/120 from a standalone
copy on both.** Real-path smoke: `status` shows `window: NOT SET` plus the command;
`add tests-full 03:00` is refused; nothing was written to `~/.claude/delay`.

Docs synced: SKILL.md (new rule: "Never pick a time"; triggers *run at night*, *when do delayed
jobs run*), README, plugin CLAUDE.md (new trust boundary "When is the human's"), plugin.json +
marketplace description, repo CLAUDE.md table and vocabulary.

## Design change 2 — 2026-10-03: no always-on daemon; the user starts the runner

**Vat:** "when Claude delays some job, it receives a reminder to run the daemon. The Claude will
pass it to User. i want to avoid the always running daemon. it should run if needed and shutdown
after jobs processing."

This supersedes the two always-loaded launchd jobs (the root `wake-sync.sh` LaunchDaemon and the
`/Library/LaunchAgents` dispatcher), R12, and Tech Debt #1, whose kickstart idea depended on
wake-sync.

- **`install.sh`** (was `install-daemon.sh`) only copies root-owned scripts and the runner plist
  to `/Library/Application Support/claude-delay/`. It loads nothing. The plist is deliberately
  **not** in `/Library/LaunchAgents`, because launchd loads that directory at every login.
- **`start.sh`** (new; the human runs it with sudo) refuses when not installed or no window is
  set, and does nothing when no approved job is queued. Otherwise it schedules **one**
  `pmset schedule wake` for window start − 30 s (owner tag; cancels only its own previous wake),
  writes `~/.claude/delay/armed` (`start=`, `end=`), and runs
  `launchctl bootstrap gui/<uid> <plist>`. It is idempotent. Without sudo it loads the runner but
  schedules no wake, and says the Mac must be awake.
- **The runner** (`dispatch.sh`) runs jobs only in the window, as before. At the end of each tick
  it **unloads itself** (`launchctl bootout`, the last thing it does) when the queue is empty or
  the armed window has ended. Leftover jobs stay queued.
- **The reminder:** `delay.sh add` / `list` print an `ACTION FOR THE USER` block with the exact
  commands (install / window / start, whichever are missing) while approved jobs are queued and
  the runner is not armed and loaded for that window. The skill tells Claude to relay it verbatim.
- **Removed:** `wake-sync.sh`, and with it any root process that runs periodically. The only root
  actions left are install, approve and start.
- The shared helpers `approved_queued`, `window_target`, `runner_*`, `is_root`, `sudo_user` and
  `user_home` are in `lib.sh` (one copy). `in_window` is now built on `window_target`.

Verified: 139/139 on the host, 139/139 in bash:5, and 139/139 from a standalone copy on both. New
sections in the suite:
- **install:** loads nothing; nothing in LaunchAgents or LaunchDaemons.
- **start:** refusals; owner-tagged wake; gui-domain bootstrap; armed window; idempotent; moving
  the window cancels the old wake; no wake without sudo; pmset refusal; window already open.
- **reminder:** asks when not started, and again when armed but not loaded.
- **self-unload:** stays loaded before the window; unloads after the queue drains; unloads when
  the window ends with jobs left, which stay queued and trigger the reminder again.
- **uninstall.**

Real-path smoke: `status` shows `runner=not-started`; `start.sh` refuses with "not installed";
nothing was loaded and nothing was written.

**New unverified hardware point** (added to AC3): does `launchctl bootstrap gui/<uid>` accept a
root-owned plist outside `~/Library/LaunchAgents`? If not, the fallback is to copy the plist to
`~/Library/LaunchAgents` at start and remove it on unload. That would still never be loaded at
login, because it is gone by then.

## Change 3 — 2026-10-03: check interval as a setup step; wake after the window opens

**Vat:** "set check each X mins as setup step".

- `install.sh --interval MIN` (1–60, default 1) sets the runner plist's `StartInterval`.
  `delay.sh status` reports `interval_min=`.
- **Bug found and fixed while doing it.** The wake was at window start **−** 30 s. launchd runs
  the overdue tick right at wake, so that tick found the window still shut and did nothing, and
  the next tick (now possibly 5+ minutes later) could fall after the dark wake had ended. The
  wake is now at window start **+** 30 s (`WAKE_AFTER` in `start.sh`). This supersedes "−30 s" in
  Design change 2.
- New `delay/examples/smoke/`: `bash:5` image (already local, so no pull at night), its own
  directory mounted read-only, `network_mode: none`; it prints the time, sleeps 20 s and exits.

Verified:
- Suite at 143/143 on the host, in bash:5, and from a standalone copy on both.
- The smoke compose runs in real docker (21 s, exit 0).
- **Rehearsal with real docker, scratch registry and store** (no sudo, `/Library` untouched):
  `approve.sh` pinned the compose file and wrapper with no red flags; `--window <now> 1`;
  `delay.sh add smoke` printed the ACTION block; `dispatch.sh` ran it → `passed`, exit 0, log with
  output and git status.
- What is left for the real test is launchd, pmset and an actual sleep.

## Real test — night of 2026-10-03 → 04 (together with Vat)

Plan: Vat installs with `--interval 5`, sets the window, approves `smoke`, Claude queues it, Vat
runs `start.sh` and puts the Mac to sleep on AC power. **On 2026-10-04 Claude checks:**
1. `bash delay/scripts/delay.sh list` → smoke `passed`, with `started=` inside the window.
2. `launchctl print gui/$(id -u)/com.claude-delay.dispatch` → not loaded (self-unload worked).
3. `pmset -g log | grep -iE "wake.*claude-delay|Wake from"` around the window → our wake fired.
4. `cat /tmp/claude-delay-runner.$USER.err` → empty, or the reason it failed.
5. The result log's first line (docker started inside the container) vs `started=`.
Then complete PLUG-013, or file what failed.

## Change 4 — 2026-10-03: install takes the run time; a failed add still queues

**Vat:** "install should accept the time when to run. defaults: interval = 1 min. runAt = 03:00",
and "is unsuccess call add the job? it should".

- `install.sh [--run-at HH:MM] [--hours N] [--interval MIN]`, defaults 03:00 / 4h / 1 min. The
  4h default length is Claude's choice; Vat did not specify it. A first install sets the window.
  A re-install keeps it unless `--run-at` or `--hours` is given, so an upgrade never resets the
  time. `set_window` in lib.sh is the only writer (used by install and `approve --window`).
- `delay.sh add` **queues an unapproved job too** and marks it `(not approved yet)`. Approval is
  still enforced at run time, so this loosens nothing. The ACTION block now lists only what is
  missing: install (once); the window line (only once installed, since install sets it); one
  approve command per unapproved queued job (with FILE/NAME/SCRIPT placeholders); start.
- Before install, the `window:` line says "not set yet — the install sets it" instead of pointing
  at an approve.sh that does not exist yet.
- Suite at 151/151 on the host, in bash:5, and from a standalone copy on both.
- **Known flake:** 1 failure out of 11 container runs of the repo copy, not reproduced in 8
  reruns, so the check is unidentified. Suspects: the timing-based cases (9f timeout, 10a lock
  holder). Tech debt: make them deterministic.

Night test, step 1 done at 19:04: real `delay.sh add smoke` with nothing installed →
`queued 20261003-190435-24750: smoke (not approved yet)`, rc=0, ACTION block shown. The job is in
`~/.claude/delay/` now.

## Change 5 — 2026-10-03: approval by ID, one list of all projects

**Vat:** "what is approve.sh? should i run it on each delayed job? i don't want", then "make the
approval process clear and simple. let the user approve by ID or similar. let the user see the
all projects list".

Approval stays per **job definition** (once per project + job, not per run), with option A kept.
The friction was the UX, so the UX changed:
- **Claude proposes** the definition when queuing an unapproved job:
  `delay.sh add <job> --compose F --service S --wrapper W [--command C] [--timeout N]`. The
  proposal is stored in the queue entry as `proposed_*`. The client validates it early (inside
  the project, complete, valid names). Re-adding with a proposal updates the queued entry.
- **IDs:** `job_id` = first 6 hex digits of sha256("project\njob"). An ID stays the same across
  runs and covers both the approved and the waiting state.
- **`sudo approve.sh`** with no arguments shows every project: approved jobs (or `CHANGED,
  re-approve` when pins mismatch, or `project missing`), and waiting jobs with their proposal or
  "no definition", each with its ID. `all_jobs` in lib.sh is the one enumerator.
- **`sudo approve.sh <ID>`** reviews and approves a waiting job from its proposal, or re-approves
  an approved one from its registry entry. Same validation, red-flag check and y/N prompt as the
  full form. `--revoke <ID>` revokes. The full form still works.
- The registry job file now records `wrapper=` (needed to re-approve by ID).
- The ACTION note gives `approve.sh <ID>` (or the full form when nothing was proposed) plus the
  pointer to the full list. Shared helpers: `sha256`, `job_id`, `user_store` (start.sh uses it
  too), `all_jobs`.

Verified: 175/175 on the host, in bash:5, and from a standalone copy on both; new section
"approval by ID" (18a–18x). Real: `smoke` was re-queued with its proposal → the note says
`sudo ".../approve.sh" b62c9f`, and the list shows the project with `b62c9f smoke WAITING for
approval …`. The installed copies predate this change (`installed_current=no`), so Vat re-runs
install, which keeps the window.

## Change 6 — 2026-10-03: install shows the job list

**Vat:** "the install initial script should show the already added list of jobs".
`list_all` moved from approve.sh to lib.sh as `print_jobs` (one copy). `approve.sh` with no
arguments and the end of `install.sh` both call it, so install ends with every project, its
waiting and approved jobs, and their IDs. Suite at 176/176 on all four targets (new 13a9).
A preview against the real queue, with a scratch prefix, shows `b62c9f smoke WAITING for approval`.

## Change 7 — 2026-10-03: start.sh --awake

**Vat:** "will start.sh block my laptop from sleeping?" — no. Then "can you make it? prevent sleeping".
- `start.sh --awake` writes `awake=1` to `armed`. On every tick the runner keeps one
  `caffeinate -i -s -t <seconds to window end>` alive. It is user-owned and its pid is in
  `~/.claude/delay/awake.pid`. It is killed on unload, or when re-armed without `--awake`.
- Before killing anything, `awake_alive` checks that the pid's command line contains
  `caffeinate`, because pids get reused.
- The runner plist gets `AbandonProcessGroup`, so the hold survives the tick's exit. Without it,
  launchd kills the tick's process group.
- The `-t` cap means the hold can never outlive the window, even if unloading fails. The lid
  still sleeps a laptop. The pmset wake stays scheduled as a backup.
- `is_digits` moved to the top of dispatch.sh, because unload (and so `stop_awake`) can run
  before the old definition point.
- Suite at 185/185 on all four targets (new section 19a–19i). Real `caffeinate -i -s -t 2`
  returns 0 on this Mac.
- Needs a re-install (plist and copies changed).

## Change 8 — 2026-10-03: --awake as an install default

**Vat:** "add --awake as possible option to install, then it will be default for all start".
- `install.sh --awake` / `--no-awake` writes `awake=1|0` to the root-owned
  `$DELAY_SYSTEM/settings`. `setting` and `set_setting` in lib.sh are generic key=value helpers.
  A re-install without either flag keeps the existing choice.
- `start.sh` takes its default from that setting; `--awake` / `--no-awake` override it for one
  start. `status` shows `awake_default=`. Install prints which behaviour `start.sh` will have.
- Suite at 191/191 on all four targets (19j–19o).

**Verified on the real machine at 21:20** (first real start, before this change):
`launchctl bootstrap gui/<uid>` **accepts the root-owned plist** outside `~/Library/LaunchAgents`
(`state = active`, `run interval = 60 seconds`, last exit 0). That resolves the first unverified
point of Design change 2. `pmset -g sched` shows `wake at 10/04/2026 03:00:30 by 'claude-delay'`.
The awake hold was not on (`armed` had no `awake=1`), most likely because start ran before the
re-install. Seen at the same time: two unrelated `caffeinate`s from other Claude sessions
(`-i -t 7200` from 20:24, and one tied to a `project-c` e2e docker run).

## Real test result — night of 2026-10-03 → 04 (checked 2026-10-04 11:38)

| Check | Result |
|---|---|
| Job | `smoke` **passed**, exit 0. `started=03:00:19`, `finished=03:00:41` (window opened 03:00:00) |
| Container | log shows `delay smoke job: started 2026-10-04 01:00:20 UTC`, which is 03:00:20 local |
| Runner self-unload | ✅ `launchctl print` → service not found; `armed` and `awake.pid` removed |
| Awake hold | ✅ caffeinate pid 84852 held from 21:32:10 to **03:00:41**, released the same second the job finished (5h28m), so it was not kept until the 07:00 cap |
| pmset wake | fired at 03:00:30 (`powerd … com.apple.powermanagement.wakeschedule`). The Mac was already awake, so it did nothing |
| Runner errors | `/tmp/claude-delay-runner.vatvit.err` is empty |
| Mac sleep | **no Sleep or Wake events overnight.** `--awake` kept it up, as intended |

**Proven on hardware:**
- launchd loads the root-owned plist on demand.
- The 60 s tick starts jobs only inside the window; the first tick was 19 s in.
- The real docker run, host-side result capture, self-unload, and hold release on unload all
  work.
- The full approve-by-ID → start → run path works.

**Not proven:** waking from **actual sleep** (dark wake → launchd's overdue tick → run), because
`--awake` meant the Mac never slept. That needs one night with `start.sh --no-awake` (or
`install --no-awake`).

**Cosmetic:** `pmset -g sched` still lists the past 03:00:30 entry. macOS keeps past entries
(Apple's own from 09/29 appeared the same way). Our `state/wakes` still records it, and the next
`start.sh` cancels it, so it is harmless.

## Real test 2 result — night of 2026-10-04 → 05 (checked 2026-10-05 07:18): did not test the wake

Armed at 12:43 with `start.sh --no-awake` (verified: runner active, no awake flag, wake
10/05 03:00:30). **The job did not run**; `smoke` is still queued. Two independent causes:
1. **The Mac rebooted at 2026-10-04 19:08** (`kern.boottime`; powerd "Start" 19:08:38; the
   shutdown cause was not logged). On-demand launchd jobs don't survive a reboot, so the runner
   was gone. The pmset wake did survive and fired at 03:00:30 (`powerd … wakeschedule`), with
   nothing loaded to act on it.
2. **The Mac never slept**: no Sleep/Wake events 19:08 → 07:00. Other Claude sessions' `caffeinate
   -i` holds ran all night, and the lid stayed open. So the dark-wake path is **still unproven**.

What worked: after the reboot the client still reports the truth. `runner_armed` checks
`launchctl print` and not just the stale `armed` file, so `list` shows `smoke` queued plus
`ACTION: start.sh` again. Nothing ran outside the window and nothing failed silently.

**Design gap found:** a reboot between `start.sh` and the window silently cancels the night.
Proposed fix: `start.sh` also copies the runner plist into `~/Library/LaunchAgents`, so launchd
reloads it at the next login, and the runner deletes that copy when it unloads. It exists only
while armed, so there is still no always-on job. This is the fallback idea noted in Design
change 2.

## Real test 3 result — night of 2026-10-05 → 06 (checked 2026-10-06 09:56)

`smoke` **passed**: started 03:00:12, finished 03:00:38, exit 0. No reboot (boot time is still
2026-10-04 19:08); the runner unloaded itself; the error log is empty. It started 18 s
**before** our 03:00:30 wake, because **the Mac never slept**. No Sleep/Wake events overnight;
`pmset -g` reports `sleep prevented by caffeinate ×6, sharingd, powerd`. On this setup there are
three independent reasons:
- `displaysleep 0`
- an external 1080p display on the USB-C AV adapter (lid close → clamshell)
- Claude sessions' `caffeinate` holds

Side note: the `bash:5` image had been removed and was re-pulled at 03:00, which worked only
because the network was up.

## Closing — 2026-10-08

Vat: "let's assume it works. somewhen later will check". Three nights proved:
- install, approve by ID, the run window
- the on-demand runner and its self-unload
- the `--awake` hold and its release
- the real docker run and results
- reboot detection (the reminder comes back)

Two follow-ups were split out:
- **PLUG-014:** verify wake from real sleep (a 15-minute daytime recipe is in the task).
- **PLUG-015:** make the timing-based test cases deterministic (the unidentified flake).

The reboot-survival idea (a temporary plist in `~/Library/LaunchAgents` while armed) was not
taken up: Vat's reboot was a one-off "dead screen".

## Current State

2026-10-08: **completed.** Shipped as delay 1.0.0 (commit 41121ca). Follow-ups: PLUG-014 (wake from real
sleep), PLUG-015 (test flake). Nothing open here.


2026-10-05: night 2 did not exercise the wake (reboot at 19:08 + the Mac never slept); see ## Real
test 2 result. Open: the reboot-survival fix (pending Vat), then a night with the lid closed.


2026-10-04: **night test passed** (see ## Real test result). Remaining before completed: optionally one
`--no-awake` night to prove wake-from-sleep, the known test flake, and a commit (Vat decides).

Earlier:

**Armed for the night, verified 21:32 on 2026-10-03:** installed copies current; `awake_default=yes`;
runner `state = active`; `armed` has start=03:00 end=07:00 awake=1; hold `caffeinate -i -s -t 34070`
(pid 84852, ends exactly at 07:00); `wake at 10/04/2026 03:00:30 by 'claude-delay'`; `smoke` approved and queued.

2026-10-03 evening: built and rehearsed. **Waiting on the real night test** (see ## Real test); the next
session checks the result on 2026-10-04 using the five checks listed there. Nothing is committed.

Earlier state, kept for history:

2026-10-03. Implementation is complete, including both design changes (the user's run window,
and the on-demand runner the user starts). It is verified by the test suite: 139/139 on the host,
in bash:5, and from a standalone copy. **Nothing is committed.**

The status stays **in-progress**. AC3, the real hardware path, can only be checked after the user
installs with sudo, which Claude must not do. Steps:
1. `sudo bash delay/scripts/install.sh`
2. `sudo ".../bin/approve.sh" <project> <job> --compose … --service … --wrapper …`
3. `sudo ".../bin/approve.sh" --window HH:MM 1`, with a start a few minutes ahead.
4. `delay.sh add <job>`. It prints the reminder.
5. `sudo ".../bin/start.sh"`. Check it says "wake scheduled" and that
   `launchctl print gui/$(id -u)/com.claude-delay.dispatch` shows it loaded.
6. Sleep the Mac on AC power before the window opens.
7. Afterwards: `delay.sh list` shows the job passed or failed, the runner is no longer loaded, and
   `pmset -g log | grep -i wake` shows the wake.

If step 5 fails to load, use the `~/Library/LaunchAgents` fallback in Design change 2. If the
job ran only when you woke the Mac, the dark wake is too short for launchd's tick: investigate
a `caffeinate` hold started by start.sh at wake time.
