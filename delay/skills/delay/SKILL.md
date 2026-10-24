---
name: delay
description: Use to delay a long-running job, typically a slow autotest suite, to the user's run window on this Mac (e.g. overnight). Claude queues a .sh script with params to run in the project's docker container; the user approves the container + script once and decides when queued jobs run. In the window the Mac wakes from sleep and runs the job inside that container, even with the screen locked, and the result waits for any later session. Queuing the same script with the same params twice is a no-op. Activate on "delay the tests", "run the tests tonight", "run this later", "run at night", "delay a job", "delay this script", "run the smoke tests tonight with these params", "wake the laptop and run", "what delayed jobs are queued", "when do delayed jobs run", "did last night's run pass", "delayed job results", "install delay", "set up delay", "how do I install delay", "delay on another Mac", or /delay.
version: 2.0.1
---

# delay

Queue a **job** for the current project: a **`.sh` script** in the project, the **container**
it runs in (a compose file + service), and free **params**. The user approves the **pair**
(container + script) once, in a root-owned registry. Params are never approved: they reach the
script as argv words. **When** queued jobs run is the user's **run window**, a daily start time
and length that applies to all jobs. You never pass a raw command (`docker …`, `npm …`) and
never a time.

Nothing runs in the background by default. The **runner** is loaded only when the user starts it
with `sudo start.sh`. That schedules the wake for the window and loads the runner, which unloads
itself once the queue is done or the window ends. So queuing a job is only half of it: **the user
must start the runner**, and the script tells you when.

Everything goes through one script. `<PLUGIN_ROOT>` is this plugin's directory, resolved
relative to this skill file:

```
bash <PLUGIN_ROOT>/scripts/delay.sh jobs                              # approved pairs here
bash <PLUGIN_ROOT>/scripts/delay.sh add <script.sh> [-- param...]     # queue for the next window
bash <PLUGIN_ROOT>/scripts/delay.sh list          # the window, queued jobs, latest results
bash <PLUGIN_ROOT>/scripts/delay.sh show <id>     # one job: status, exit, outcome, log path
bash <PLUGIN_ROOT>/scripts/delay.sh rm <id>       # cancel a queued job
bash <PLUGIN_ROOT>/scripts/delay.sh status        # install state, run window, runner started?
```

The project is the git top-level of the working directory. `--project DIR` (before the command)
picks another project. Paths are relative to the project root.

- **The container** may be left out when the script is approved with exactly one. Otherwise name
  it: `add <script.sh> --compose <file> --service <name>`. The first time a script is queued it
  is not approved yet, so name the container then. A pair that is **not approved yet is still
  queued**, and the user approves it by a short ID.
- **Params** go after `--`, each one argv word: `add scripts/test.sh -- smoke filter=a,b`. Each
  must be non-empty and one line; at most 64, 4096 bytes in total.
- **Duplicates:** the same pair with the same params, in any order, is already queued. `add` then
  says `already queued <id>` and exits 0, so that is not an error. `-- full` and `-- smoke` are
  two jobs, and so are `filter=a,b` and `filter=b,a`.
- Optional, for an unapproved pair: `--timeout <seconds>` and `--command "<how the container
  calls the script>"` (default: the script path) are a proposal the user reviews.

## Writing the script

The script runs **inside** the container, so it holds no `docker` command. Pick the project's
existing test service; don't invent new infrastructure just to queue something.

**Treat params as data, never as commands.** The user approves the script once; params are
chosen later. Use a param only to choose from a fixed set (`case "$1" in full) … ;; smoke) … ;;
*) echo "unknown: $1" >&2; exit 2 ;; esac`) or as a quoted value (`pytest -k "$2"`). Never
`eval` it, never `sh -c "$1"`, never `npm run "$1"`/`make "$1"`, never put `"$@"` in command
position. `approve.sh` refuses a script that does (it names the line), unless the user overrides.

## Rules

- **Relay `ACTION FOR THE USER` verbatim.** When `add` or `list` prints a block starting with
  `ACTION FOR THE USER`, the runner is not started for the window, a pair waits for approval, or
  the install is outdated. Put that block, commands included, in your reply to the user, plainly
  and near the end so it isn't missed. Don't paraphrase the commands. When it prints
  `runner: started`, there is nothing to ask.
- **Never pick a time.** If the user says "run it at 3am", queue it and tell them when their
  window opens (`list` prints it). If the window doesn't suit, *they* change it with
  `sudo approve.sh --window HH:MM HOURS`.
- **Give install, approve and start commands as full paths, never `<PLUGIN_ROOT>`.** When the
  user asks how to install or set up delay (a new Mac, another account), run `delay.sh status`
  and give the `install_cmd=` line exactly; it is the full, quoted path to this plugin copy, which
  holds the version, so it changes with each update. Before it, they add the plugin
  (`/plugin marketplace add vatvit/claude-plugins`, `/plugin install delay@vatvit-plugins`).
  After the install, `approve_cmd=` and `start_cmd=` are the commands for the installed copies.
  The install is once per Mac: several Claude accounts on one Mac share one queue, approvals,
  window and runner, so it doesn't matter which account installs.
- **Never run `install.sh`, `approve.sh` or `start.sh`, and never use `sudo`.** They are the
  user's approval steps. When a pair is not approved, no window is set, or the runner is not
  installed or started, show the user the exact command the script printed and stop.
- **Never write into `~/.claude/delay/` or the registry directly.** Only `delay.sh` writes the
  queue, and only the dispatcher writes results.
- **Never edit the pinned files to get a job to run.** Pinned files are the compose file, its
  Dockerfile and the script. A result of `needs-reapproval` means the user re-approves with
  `sudo approve.sh` and the same ID (the list marks it `CHANGED`). Say which file changed (the log
  names it). Editing the script is fine when the user asked for it; say it needs re-approval.
- Say **job**, never "task", in what you tell the user. "Task" belongs to the task plugin.

## Result statuses

| status | meaning |
|---|---|
| `passed` / `failed` | ran; `exit=` holds the code; the log ends with `git status --short` |
| `timeout` | killed after the pair's approved timeout |
| `needs-reapproval` | a pinned file changed since approval; nothing ran |
| `not-approved` | the pair was never approved, or was revoked after it was queued |
| `docker-unavailable` | docker did not answer within 60 s |
| `project-missing` / `invalid` | project moved, a malformed queue entry, or one queued by delay 1.x (re-queue it) |

`list` and `show` (`outcome=`) put this in words: **ran** — the exit code is the script's own
verdict — or **not run**, which is the only kind delay caused. Report `failed` as "the job ran;
the tests failed (exit N)", never as "the job failed": the user reads that as a delay fault.

A job still **queued** after its window means either the runner was not started, or the Mac
didn't wake in time (lid closed on battery, shut down, or the user logged out). The runner has
unloaded itself, and `list` will ask the user to start it again. A job never starts outside a
window.

## Telling the user about limits

When asked whether something will run, mention what applies:
- The Mac must be **asleep, not shut down**, and on AC power if the lid is closed.
- If the user doesn't trust the wake, `start.sh --awake` keeps the Mac awake until the jobs are
  done (lid open).
- The user must be **logged in** (the screen may be locked), because docker is a per-user app.
- After a plugin update, `status` shows `installed_current=no` and the ACTION block asks for the
  install again. With several Claude accounts, an account whose plugin is older than the
  installed copy gets a `note:` line (and `plugin_update=` in `status`) instead: pass on that the
  user should update the plugin in that account, never the install, which would downgrade it for
  every account (`install.sh` refuses unless `--downgrade`). It updates the root-owned copies that launchd and sudo run, and moves approvals
  from delay 1.x job names to pairs.
