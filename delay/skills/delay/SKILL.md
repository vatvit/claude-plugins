---
name: delay
description: Use to delay a long-running job, typically a slow autotest suite, to the user's run window on this Mac (e.g. overnight). Claude only queues an approved job by name; the user decides when the queued jobs run. In the window the Mac wakes from sleep and runs the job inside the project's own docker container, even with the screen locked, and the result waits for any later session. Activate on "delay the tests", "run the tests tonight", "run this later", "run at night", "delay a job", "wake the laptop and run", "what delayed jobs are queued", "when do delayed jobs run", "did last night's run pass", "delayed job results", or /delay.
version: 1.0.0
---

# delay

Queue an **approved job** for the current project. The command behind a job name lives in a
root-owned registry. **When** queued jobs run is the user's **run window**, a daily start time
and length that applies to all jobs. The user sets both with `sudo approve.sh`. You pass a
**job name only**: never a command, and never a time.

Nothing runs in the background by default. The **runner** is loaded only when the user starts it
with `sudo start.sh`. That schedules the wake for the window and loads the runner, which unloads
itself once the queue is done or the window ends. So queuing a job is only half of it: **the user
must start the runner**, and the script tells you when.

Everything goes through one script. `<PLUGIN_ROOT>` is this plugin's directory, resolved
relative to this skill file:

```
bash <PLUGIN_ROOT>/scripts/delay.sh jobs          # what can be delayed here
bash <PLUGIN_ROOT>/scripts/delay.sh add <job>     # queue it for the next run window
bash <PLUGIN_ROOT>/scripts/delay.sh list          # the window, queued jobs, latest results
bash <PLUGIN_ROOT>/scripts/delay.sh show <id>     # one job: status, exit, log path
bash <PLUGIN_ROOT>/scripts/delay.sh rm <id>       # cancel a queued job
bash <PLUGIN_ROOT>/scripts/delay.sh status        # install state, run window, runner started?
```

The project is the git top-level of the working directory. `--project DIR` (before the command)
picks another project. Adding a job that is already queued does nothing and names the existing
id. A job that is **not approved yet is still queued**, and the user approves it by a short ID.

**When a job is not approved yet, propose its definition** so the user gets a one-line approve
command instead of placeholders:

```
bash <PLUGIN_ROOT>/scripts/delay.sh add <job> --compose <compose file> --service <service> \
     --wrapper <script> [--command "<cmd inside the container>"] [--timeout <seconds>]
```

Paths are relative to the project root. The wrapper is the script that runs the job (it gets
pinned); `--command` is how the container calls it, and defaults to the wrapper path. Pick the
project's existing test service and script; don't invent new infrastructure just to queue
something. The proposal is only shown to the user, who reviews it with `sudo approve.sh <ID>`;
it never runs unreviewed. Adding the same job again with a proposal updates it.

## Rules

- **Relay `ACTION FOR THE USER` verbatim.** When `add` or `list` prints a block starting with
  `ACTION FOR THE USER`, the runner is not started for the window. Put that block, commands
  included, in your reply to the user, plainly and near the end so it isn't missed. Don't
  paraphrase the commands. When it prints `runner: started`, there is nothing to ask.
- **Never pick a time.** If the user says "run it at 3am", queue it and tell them when their
  window opens (`list` prints it). If the window doesn't suit, *they* change it with
  `sudo approve.sh --window HH:MM HOURS`.
- **Never run `install.sh`, `approve.sh` or `start.sh`, and never use `sudo`.** They are the
  user's approval steps. When a job is not approved, no window is set, or the runner is not
  installed or started, show the user the exact command the script printed and stop.
- **Never write into `~/.claude/delay/` or the registry directly.** Only `delay.sh` writes the
  queue, and only the dispatcher writes results.
- **Never edit the pinned files to get a job to run.** Pinned files are the compose file, its
  Dockerfile and the wrapper script. A result of `needs-reapproval` means the user re-approves
  with `sudo approve.sh` and the same ID (the list marks it `CHANGED`). Say which file changed (the log names it).
- Say **job**, never "task", in what you tell the user. "Task" belongs to the task plugin.

## Result statuses

| status | meaning |
|---|---|
| `passed` / `failed` | ran; `exit=` holds the code; the log ends with `git status --short` |
| `timeout` | killed after the job's approved timeout |
| `needs-reapproval` | a pinned file changed since approval; nothing ran |
| `not-approved` | the job was revoked after it was queued |
| `docker-unavailable` | docker did not answer within 60 s |
| `project-missing` / `invalid` | project moved, or a malformed queue entry |

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
- After a plugin update, `status` may show `installed_current=no`. The user then re-runs the
  install to update the root-owned copies that launchd and sudo run.
