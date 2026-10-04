# delay

Delay long-running jobs, such as a slow autotest suite, to **your run window**: a daily time you
choose, e.g. 03:00 for 4 hours. In the window the Mac **wakes from sleep**, runs the queued jobs
**inside each project's own docker container** even with the screen locked, and keeps the
results for whichever Claude session asks next.

Claude can only *queue* jobs, by name. It chooses neither what runs nor when, and it cannot start
the runner. Each job is a name **you** approve with `sudo`; the files that define the container's
confinement are pinned by sha256; the window is yours; and **you start the runner** for each
night that has work.

**Nothing runs in the background by default.** No daemon is loaded at login. The runner is
loaded when you start it and unloads itself when the work is done.

## How it works

```
Claude session ── delay.sh add tests-full ──▶ ~/.claude/delay/<project>/queue/<id>.job
                                              (a job name, nothing else)
               ◀── "ACTION FOR THE USER: sudo .../start.sh" ── Claude relays it to you

you ── sudo start.sh ──▶ pmset schedule wake <window start + 30 s> claude-delay
                     ──▶ launchctl bootstrap gui/<you> <runner plist>

runner (dispatch.sh, a LaunchAgent ticking every 60 s while loaded)
   in the window:  verify pins ▶ docker compose run --rm -T <service> <cmd>
                   under caffeinate, with a timeout ▶ results/<id>/{meta,log}
   queue empty, or window over ──▶ launchctl bootout itself
```

- **Registry and window:** `/Library/Application Support/claude-delay/{registry,window}`.
  Root-owned, written only by `approve.sh`.
- **What launchd and sudo run:** root-owned **copies** of the scripts, never the plugin
  directory. The runner's plist sits beside them, not in `/Library/LaunchAgents` (which would
  load it at every login).
- **Wakes:** `start.sh` cancels only the wake it scheduled itself. It never runs `cancelall`.

## Setup (once, by you)

```bash
sudo bash <plugin>/scripts/install.sh [--run-at 03:00] [--hours 4] [--interval 1] [--awake]   # loads nothing
```

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

## Approve a job (by you, once per job)

Approval is per **job definition**, not per run. Once `smoke` is approved for a project, Claude
can queue it every night without asking you again. When Claude queues a job that isn't approved
yet, it proposes the definition (compose file, service, wrapper script), and the note it passes
you is one short command:

```bash
sudo "/Library/Application Support/claude-delay/bin/approve.sh"          # every project: jobs + IDs
sudo "/Library/Application Support/claude-delay/bin/approve.sh" b62c9f   # review that job, answer y
sudo "/Library/Application Support/claude-delay/bin/approve.sh" --revoke b62c9f
```

```
/Users/you/projects/foo
  b62c9f  smoke            WAITING for approval   delay/examples/smoke/compose.yml / smoke / bash /work/smoke.sh
  4e1d0a  tests-full       approved               docker-compose.yml / app / scripts/test-all.sh
  77a9c2  tests-e2e        CHANGED, re-approve    docker-compose.yml / e2e / scripts/test-e2e.sh
```

An ID stands for a project + job name, so it stays the same across runs. Use the same ID to
re-approve after a pinned file changed. Without a proposal, use the full form:
`approve.sh <project-dir> <job> --compose FILE --service NAME --wrapper SCRIPT [--command "CMD"] [--timeout S] [--pin FILE]`.

- **What gets pinned:** the compose file, the wrapper, a `Dockerfile` next to the compose file,
  and any `--pin` files. If any of these changes, the job is refused as `needs-reapproval`
  until you approve it again. Test and app code is deliberately **not** pinned, because running
  the latest code is the point.
- **Red flags:** approve renders `docker compose config` and refuses on these unless you pass
  `--accept-risks`:
  - `privileged`
  - `cap_add`
  - a docker socket mount
  - `host` network, pid or ipc namespace
  - a bind mount outside the project
- **Other commands:** `--window` shows the window; `--window HH:MM HOURS` changes it.

Recommended compose settings for a delayed test service:
- Mount `.git` and `.claude` **read-only**, so a run cannot plant hooks you later execute.
- Use an `internal: true` network if the tests need no internet.
- Run as your uid.

**Example:** `delay/examples/smoke/` is a harmless job to try the full flow. It uses the `bash:5`
image, mounts its own directory read-only, has no network, prints the time and exits:

```bash
sudo "/Library/Application Support/claude-delay/bin/approve.sh" <your claude-plugins checkout> smoke \
     --compose delay/examples/smoke/compose.yml --service smoke \
     --wrapper delay/examples/smoke/smoke.sh --command "bash /work/smoke.sh" --timeout 600
```

## Use (by Claude, or you)

```bash
delay.sh jobs                      # approved names for this project
delay.sh add tests-full            # queue for the next window (already queued = no-op)
delay.sh list                      # the window, queued jobs, latest results, reminder if not started
delay.sh show <id>                 # meta + log path
delay.sh rm <id>
delay.sh status                    # installed? window? runner started?
```

## Limits

- **Sleep, not shutdown.** After a reboot nothing runs until you log in and start the runner.
- **Lid closed on battery:** most MacBooks will not wake. Lid open, or on AC power, works.
- **You must be logged in** (screen locked is fine), because docker (OrbStack/Docker Desktop) is
  a per-user app and the runner lives in your login session.
- **A missed window means starting again.** If the Mac couldn't wake, the runner unloads when the
  window ends, the jobs stay queued, and the next `add`/`list` reminds you. Nothing starts when
  you open the lid at 10:00.
- **The guarantee is narrower than a sandbox.** Through this plugin, nothing runs unattended
  without your sudo approval. A Claude session still has your user shell, though, and Claude
  Code's permission settings are what limit that.
- macOS only.

## Testing

```bash
bash delay/scripts/test/delay.test.sh
docker run --rm -v "$PWD":/w -w /w bash:5 bash delay/scripts/test/delay.test.sh
```
