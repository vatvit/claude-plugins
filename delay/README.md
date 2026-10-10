# delay

Delay long-running jobs, such as a slow autotest suite, to **your run window**: a daily time you
choose, e.g. 03:00 for 4 hours. In the window the Mac **wakes from sleep**, runs the queued jobs
**inside each project's own docker container** even with the screen locked, and keeps the
results for whichever Claude session asks next.

Claude can only *queue* jobs. A job is a **`.sh` script** in the project, the **container** it
runs in (compose file + service) and free **params**. You approve the **pair** (container +
script) once with `sudo`; the script and the files that define the container's confinement are
pinned by sha256. Params are never approved: they reach the script as argv words, never through
a shell. Claude chooses no command and no time, and it cannot start the runner: the window is
yours, and **you start the runner** for each night that has work.

**Nothing runs in the background by default.** No daemon is loaded at login. The runner is
loaded when you start it and unloads itself when the work is done.

## How it works

```
Claude session ── delay.sh add scripts/test.sh -- smoke ──▶ ~/.claude/delay/<project>/queue/<id>.job
                                              (compose, service, script, params — no command, no time)
               ◀── "ACTION FOR THE USER: sudo .../start.sh" ── Claude relays it to you

you ── sudo start.sh ──▶ pmset schedule wake <window start + 30 s> claude-delay
                     ──▶ launchctl bootstrap gui/<you> <runner plist>

runner (dispatch.sh, a LaunchAgent ticking every 60 s while loaded)
   in the window:  verify pins ▶ docker compose run --rm -T <service> <approved cmd> <params…>
                   under caffeinate, with a timeout ▶ results/<id>/{meta,log}
   queue empty, or window over ──▶ launchctl bootout itself
```

- **Registry and window:** `/Library/Application Support/claude-delay/{registry,window}`.
  Root-owned, written only by `approve.sh`.
- **What launchd and sudo run:** root-owned **copies** of the scripts, never the plugin
  directory. The runner's plist sits beside them, not in `/Library/LaunchAgents` (which would
  load it at every login).
- **Wakes:** `start.sh` cancels only the wake it scheduled itself. It never runs `cancelall`.

## Setup (once per Mac, by you)

**1. Add the plugin** in Claude Code:

```
/plugin marketplace add vatvit/claude-plugins
/plugin install delay@vatvit-plugins
```

Claude can queue jobs now, but nothing runs until step 2.

**2. Run the install** in a terminal, with `sudo` and the **full path** to the plugin's copy. You
don't have to find that path: ask Claude ("how do I install delay?"), or queue a job, and it shows
the exact line. It comes from `delay.sh status` (`install_cmd=`) or the `ACTION FOR THE USER`
block, and looks like:

```bash
sudo bash "/Users/you/.claude/plugins/cache/vatvit-plugins/delay/2.0.0/scripts/install.sh" \
     [--run-at 03:00] [--hours 4] [--interval 1] [--awake]          # loads nothing
```

The path holds the plugin version, so it changes with each update. Copy it; don't type it. The
install puts root-owned copies in `/Library/Application Support/claude-delay/bin/`, and every
later command runs those: `sudo "/Library/Application Support/claude-delay/bin/approve.sh"` and
`.../bin/start.sh` (`approve_cmd=` and `start_cmd=` in `status`).

**Several Claude accounts** (several `CLAUDE_CONFIG_DIR` folders, e.g. `~/.claude` and
`~/.claude-work`): install once per Mac, from any of them. Each account adds the plugin for
itself (step 1), but they share one queue (`~/.claude/delay`), one set of approvals, one window
and one runner, so a job queued from either runs the same night. **Keep delay at the same version
in every account** until PLUG-054 lands: today an account with a different version reports the
install as outdated, and installing from the older one downgrades it for all.

`--interval MIN` (1–60, default 1) is how often the runner checks the queue while it is loaded.
Re-run the install to change it. The wake is set 30 s *after* the window opens, so the check
that launchd runs on wake is already inside the window.

The window is a daily start time (local time) and a length in hours; the install sets it
(defaults 03:00 for 4h), a re-install keeps it unless `--run-at`/`--hours` is given, and
`approve.sh --window HH:MM HOURS` changes it any time. Jobs **start** only inside it, though a
started job may finish after it.

Re-run the install after a plugin update. `delay.sh status` reports `installed_current=no` when
the installed copies are stale. `--uninstall` unloads the runner, cancels our wake, and removes
the installed scripts and plist. It keeps your approvals, window and results.

## Each night with work (by you)

When Claude queues a job, it passes on a reminder. Run:

```bash
sudo "/Library/Application Support/claude-delay/bin/start.sh" [--awake]
```

`--awake` also keeps the Mac awake from now until the jobs are done: the runner holds
`caffeinate -i -s`, capped at the window end, and releases it when it unloads. Use it when you
don't want to depend on the wake. Closing the lid still sleeps a laptop, so keep it open.
`install.sh --awake` makes it the default for every start (`--no-awake` turns it off), and
`start.sh --no-awake` overrides it for one night.

`start.sh` without sudo also works, but schedules no wake, so the Mac must be awake in the
window. Running it twice is harmless.

## Approve a pair (by you, once per container + script)

Approval is per **pair**, not per run and not per params. Once `scripts/test.sh` is approved
with the project's `app` service, Claude can queue it every night, with any params, without
asking you again. When Claude queues a pair that isn't approved yet, it is queued anyway, and the
note it passes you is one short command:

```bash
sudo "/Library/Application Support/claude-delay/bin/approve.sh"          # every project: jobs + IDs
sudo "/Library/Application Support/claude-delay/bin/approve.sh" b62c9f   # review that job, answer y
sudo "/Library/Application Support/claude-delay/bin/approve.sh" --revoke b62c9f
```

```
/Users/you/projects/foo
  b62c9f  scripts/smoke.sh     WAITING for approval   compose.yml / smoke
  4e1d0a  scripts/test-all.sh  approved               docker-compose.yml / app / scripts/test-all.sh
  77a9c2  scripts/test-e2e.sh  CHANGED, re-approve    docker-compose.yml / e2e / scripts/test-e2e.sh
```

An ID stands for a project + pair, so it stays the same across runs. Use the same ID to
re-approve after a pinned file changed. Before Claude queued anything, use the full form:
`approve.sh <project-dir> <script.sh> --compose FILE --service NAME [--command "CMD"] [--timeout S] [--pin FILE]`.
`--command` is how the container calls the script (default: the script path); params are
appended to it.

- **What gets pinned:** the compose file, the script, a `Dockerfile` next to the compose file,
  and any `--pin` files. If any of these changes, the job is refused as `needs-reapproval`
  until you approve it again. Test and app code is deliberately **not** pinned, because running
  the latest code is the point.
- **Red flags:** approve renders `docker compose config`, reads the script, and refuses on these
  unless you pass `--accept-risks`:
  - `privileged`
  - `cap_add`
  - a docker socket mount
  - `host` network, pid or ipc namespace
  - a bind mount outside the project
  - **a script that runs a param as a command**, naming the line: `eval`, `sh -c "$1"` (any
    shell), `npm run "$1"`/`make $1`-style build targets, `"$@"` or `$1` in command position,
    `. "$1"`. This is a safety net, not a proof: it reads only that script's non-comment lines,
    follows no other file, and misses a param copied into a variable that is run later. A
    script meant to run unattended takes a param only to pick from a fixed set (`case`) or as a
    quoted value.
- **Other commands:** `--window` shows the window; `--window HH:MM HOURS` changes it.

Recommended compose settings for a delayed test service:
- Mount `.git` and `.claude` **read-only**, so a run cannot plant hooks you later execute.
- Use an `internal: true` network if the tests need no internet.
- Run as your uid.

**Example:** `delay/examples/smoke/` is a harmless job to try the full flow. It uses the `bash:5`
image, mounts its own directory read-only, has no network, prints the time and exits:

```bash
sudo "/Library/Application Support/claude-delay/bin/approve.sh" <your claude-plugins checkout> \
     delay/examples/smoke/smoke.sh --compose delay/examples/smoke/compose.yml --service smoke \
     --command "bash /work/smoke.sh" --timeout 600
```

## Use (by Claude, or you)

```bash
delay.sh jobs                                  # approved pairs for this project
delay.sh add scripts/test.sh -- smoke          # queue for the next window
delay.sh add scripts/test.sh --compose docker-compose.yml --service app -- full
                                               # name the container: first time, or several approved
delay.sh list                      # the window, queued jobs, latest results, reminder if not started
delay.sh show <id>                 # meta + log path
delay.sh rm <id>
delay.sh status                    # installed? window? runner started? + the install, approve, start commands
```

**Duplicates:** the same pair with the same params, in any order, is queued once; a second `add`
says `already queued <id>` and exits 0. Each param is compared as an exact string, so `-- a b` =
`-- b a`, but `filter=p1,p2` ≠ `filter=p2,p1`, and `-- full` and `-- smoke` are two jobs. Params
must be non-empty and one line, at most 64 and 4096 bytes in total.

**Upgrading from 1.x:** delay 1.x approved job *names*. The install moves each approval to its
pair (same compose, service, command and pins, so no re-approval); two names for the same pair
keep the first. A job queued by 1.x is not run: it ends `invalid` and must be queued again.

## Limits

- **Sleep, not shutdown.** After a reboot nothing runs until you log in and start the runner.
- **Lid closed on battery:** most MacBooks will not wake. Lid open, or on AC power, works.
- **You must be logged in** (screen locked is fine), because docker (OrbStack/Docker Desktop) is
  a per-user app and the runner lives in your login session.
- **A missed window means starting again.** If the Mac couldn't wake, the runner unloads when the
  window ends, the jobs stay queued, and the next `add`/`list` reminds you. Nothing starts when
  you open the lid at 10:00.
- **The guarantee is narrower than a sandbox.** Through this plugin, nothing runs unattended
  without your sudo approval, and the container bounds what an approved script can reach — with
  any params. A Claude session still has your user shell, though, and Claude
  Code's permission settings are what limit that.
- macOS only.

## Testing

```bash
bash delay/scripts/test/delay.test.sh
docker run --rm -v "$PWD":/w -w /w bash:5 bash delay/scripts/test/delay.test.sh
```
