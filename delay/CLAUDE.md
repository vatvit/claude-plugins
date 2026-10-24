# CLAUDE.md — delay plugin

Guidance for working on this plugin. Repo-wide rules (shell conventions, plugin independence,
how to change a plugin) live in the repo root `CLAUDE.md` and apply here.

## Layout

```
delay/
├── .claude-plugin/plugin.json
├── skills/delay/SKILL.md
└── scripts/
    ├── lib.sh              shared helpers; the ONE place paths and dates are resolved
    ├── delay.sh            client (Claude): add / list / show / rm / jobs / status
    ├── dispatch.sh         the runner: LaunchAgent loaded on demand, runs jobs, unloads itself
    ├── start.sh            human, sudo: schedules the wake + loads the runner for the window
    ├── approve.sh          human, sudo: writes the registry (the whitelist) and the run window
    ├── install.sh          human, sudo: installs root-owned copies + the runner plist; loads nothing
    └── test/delay.test.sh
```

## Trust boundaries (don't regress these)

- **The queue is user-writable, so it is never trusted.** It names a pair (compose, service,
  script) and carries params: no command and no time. The dispatcher hashes the pair, looks it up
  in the registry and runs the **registry's** compose, service and command, and `start.sh` (root)
  only asks "how many queued pairs are approved?". A `command=` in the queue is ignored.
- **Params are Claude's, unapproved — so they are data.** They are appended as argv words after
  `SERVICE` (`set -- "$@" "$arg"`), where docker parses no more options: no shell, no glob, no
  eval. The container bounds what an approved script can reach with any params. The one way a
  script turns params into arbitrary code is running them; `approve.sh` scans for that
  (`scan_params`) and refuses without `--accept-risks`. The scan is a safety net — the rule itself
  lives in the user's global CLAUDE.md. Before 2.0, Claude chose only *which* approved job ran.
- **When is the human's, never Claude's.** The root-owned `window` file (`approve.sh --window`)
  is the only time source: `start.sh` wakes for its start, and the dispatcher starts jobs
  only inside it, re-checking before each job. A missed window waits for the next one; there is
  no catch-up run outside it, so a forged `created=` buys nothing.
- **launchd and sudo run installed copies.** When an `installed.conf` sits next to `lib.sh`, it pins the
  paths and every `DELAY_*` override is ignored. Without this, `launchctl setenv DELAY_REGISTRY=…`
  would bypass the whitelist. The overrides exist only as test seams in the source tree.
- **One installed copy, several plugin copies (PLUG-054).** Each Claude account holds its own plugin
  copy and version. The install writes `bin/version`; `install_state` (lib.sh) compares versions
  (bytes only when they are equal or the install predates the file), so an older account never
  reads as "install needed", and `install.sh` refuses a downgrade without `--downgrade`.
- **No always-on daemon.** Nothing is loaded until the human runs `start.sh`; the runner unloads
  itself (`launchctl bootout` as the last act of a tick) when the queue is empty or the armed
  window has ended. Its plist lives under `$DELAY_SYSTEM`, **never** in `/Library/LaunchAgents`,
  which launchd loads at every login. `start.sh` is the per-night human approval: it is what
  `delay.sh` reminds Claude to relay (`ACTION FOR THE USER`). There is no root daemon at all —
  the only root step is `start.sh`'s one `pmset schedule wake`.
- **The runner is a LaunchAgent (gui domain), not a LaunchDaemon with `UserName`.** Docker
  (OrbStack) is a per-user app, so there is nothing to run without a login session anyway, and
  the agent gets the user's docker context. launchd also fires an overdue tick on wake, which a
  plain `sleep` loop would not do reliably (its timer does not advance during system sleep).
- **Never `pmset schedule cancelall`.** It wipes Apple's own wakes. Cancel only the exact strings
  recorded in `state/wakes`, and record a wake only after pmset accepted it.
- **`~/.claude/delay` is never part of the docker invocation**, so test code cannot write its own
  result.
- Under sudo, `approve.sh` runs git and docker **as `SUDO_USER`**. Root's git refuses a
  user-owned repo, and root has no OrbStack docker context.

## Portability traps already hit

The general rules (BSD `date -j -f`, `pipefail` + `grep -q` in tests) are in the repo
`CLAUDE.md` *Shell Conventions*. Here they mean:
- Window math (`in_window`, `next_window`) is in `lib.sh`, built on `fmt_epoch` / `parse_local`,
  the only date conversions. A window may cross midnight, so `in_window` checks yesterday's start too.
- `sha256sum` vs `shasum -a 256`: `sha256_file` picks one. Alpine has only the first.
- `head -n -N` is GNU-only. Retention uses awk.

## Testing

```bash
bash delay/scripts/test/delay.test.sh
docker run --rm -v "$PWD":/w -w /w bash:5 bash delay/scripts/test/delay.test.sh
```

**Run both.** docker, pmset, launchctl and caffeinate are PATH shims. The suite never schedules
a real wake or loads a launchd job.

What the suite **cannot** prove needs a real install and a real sleep:
- `launchctl bootstrap gui/<uid>` accepting a plist outside `~/Library/LaunchAgents` (root-owned,
  under `$DELAY_SYSTEM`).
- A pmset dark wake surviving until the runner's next tick, with `caffeinate -i -w` then holding it.

Verify with `pmset -g log | grep -i wake` against a result's `started=`.
