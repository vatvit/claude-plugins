# Slots: one queue for machine time

The coordinator owns CPU and browser time. Sessions ask for a slot with an estimate and start
nothing heavy without one. Extra load makes e2e tests time out, and then nobody can tell a real
failure from load.

| Class | Runs with | Use for |
|-------|-----------|---------|
| `cpu` | other `cpu` slots | unit runs, builds, bakes, renders: untimed work |
| `exclusive` | nothing | a browser/e2e run, anything load-sensitive |
| `quiet` | nothing, and pushes and background jobs wait | timing measurements |

**One queue for the machine.** CPU, memory and Docker belong to the Mac, not to a repo, so every
crew on it shares the queue (`~/.claude/crew/slots`). An `exclusive` run in one repo makes a run in
another repo wait. `slot list` and `status` show every slot, another crew's tagged `[crew]`. Each crew
still decides only over its own: `release` takes only this crew's slots, and a `quiet` slot holds only
this crew's pushes. A slot whose owner is gone (left, ended, replaced) is dropped by the next slot
command. Only crew members queue; working alone, see [solo.md](solo.md).

**Order:** first anything failing on the shared branch (`--prio failing`), then the user's
critical asks (`--prio critical`), then the shortest first, then first come. A `cpu` slot never
jumps ahead of a waiting `exclusive` or `quiet` slot.

| Command | Use |
|---------|-----|
| `slot run <class> <min> [--prio P] [--why T] -- <cmd…>` | **the default.** It requests, waits, runs, and releases even on failure. It returns the command's exit code |
| `slot request <class> <min> …` then `slot start` / `slot done` | when the run is not one command |
| `slot list` | the queue with each slot's ETA. A slot running longer than its estimate plus `slotGraceMin` shows as **STALE** |
| `slot cancel [id]` | leave the queue |
| `slot clear` | exits 0 when no quiet slot is running. Put it in front of pushes, retries and watchers: `slot clear && git push` |
| `slot release <id>` | coordinator only: remove a stale slot of this crew |
| `msg queue-moved "<why>"` | the coordinator tells every waiting session its new time and why |

- `slot run` blocks until the slot opens. If the wait may be long, start it with the Bash tool's
  `run_in_background`, so the session is not stuck inside a tool call.
- `done` / `release` print who can start now. Then send `msg queue-moved`, because sessions
  that wait without being told assume they have been forgotten.
- Wrap the project's heavy commands once, for example `slot run exclusive 15 -- ./e2e.sh`, so
  nobody has to remember to.

## Docker in a copy (PLUG-068)

A copy is its own folder, so compose names it its own project (`<repo>-<name>`): its containers,
networks and volumes do not meet the main tree's. What still collides is what the project fixes by
hand, and `copy new` prints it once, read-only, from `docker compose config`: a `name:`,
`container_name`, a fixed tag on a built image, host ports, mounts outside the project, external
volumes. crew never changes the compose files; if the report lists anything, run Docker from the
main tree only, or make those values differ per copy yourself.

- A compose run in a copy with **no host ports** takes a `cpu` slot; one that **publishes host
  ports** takes `exclusive`, since a second copy cannot bind the same port.
- A one-off unnamed container is isolated already and needs no compose: `docker run --rm -v
  "$PWD":/w -w /w <image> <cmd>`, with no `--name` and no `-p`. Its traps: the mount (mount the
  copy, not the main tree), a fixed image tag you build to, and a named volume (`-v name:/path`),
  which every copy shares. It still takes a `cpu` slot like any heavy run.
