# Slots: one queue for machine time

The coordinator owns CPU and browser time. Sessions ask for a slot with an estimate and start
nothing heavy without one. Extra load makes e2e tests time out, and then nobody can tell a real
failure from load.

| Class | Runs with | Use for |
|-------|-----------|---------|
| `cpu` | other `cpu` slots | unit runs, builds, bakes, renders: untimed work |
| `exclusive` | nothing | a browser/e2e run, anything load-sensitive |
| `quiet` | nothing, and pushes and background jobs wait | timing measurements |

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
| `slot release <id>` | coordinator only: remove a stale slot |
| `msg queue-moved "<why>"` | the coordinator tells every waiting session its new time and why |

- `slot run` blocks until the slot opens. If the wait may be long, start it with the Bash tool's
  `run_in_background`, so the session is not stuck inside a tool call.
- `done` / `release` print who can start now. Then send `msg queue-moved`, because sessions
  that wait without being told assume they have been forgotten.
- Wrap the project's heavy commands once, for example `slot run exclusive 15 -- ./e2e.sh`, so
  nobody has to remember to.
