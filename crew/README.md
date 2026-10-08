# crew

Run several Claude Code sessions on **one working tree, one branch** without losing each
other's edits.

Sessions can talk to each other (SendMessage / ListAgents). crew adds the discipline that makes
that safe:
- roles: one coordinator, the rest workers;
- one committer;
- one screen showing who changed what;
- pre-filled hand-off messages;
- guard hooks that stop the git commands which wreck a shared index.

It is runtime-free: bash, awk and git.

## Start a crew

In each session, give it the name its peers use for it:

```
bash <plugin>/scripts/crew.sh whoami s1 coordinator     # the first session
bash <plugin>/scripts/crew.sh whoami s2                 # each worker
```

From then on, SessionStart tells each session who it is and gives it the prefix for every
command:

```
crew: you are s2 (worker) · committer: coordinator (s1 coordinates) · guards: deny · crew: s1 coordinator · s2 worker
crew: run crew commands as: CREW_AS=s2 bash …/crew.sh <command> — start with 'status'; 'help' lists commands.
```

In a repo without a crew, the plugin is silent and adds no tokens.

## Commands

| Command | What it does |
|---------|--------------|
| `whoami <name> [worker\|coordinator] [--take]` | join the crew; `whoami` alone lists it |
| `status` | the crew, the branch vs origin, every dirty path by owner (yours, a peer's, SHARED, unclaimed) |
| `msg <kind>` | a ready-to-send message: `handoff` (paths + commit message + test-first proof), `decision`, `stop` |
| `config` | effective settings, each with the layer it came from |
| `hold <path...>` / `release <path...> --sha SHA` / `chain <path>` / `who` / `drop` | hot-spot holds; the pre-edit hook denies edits to a file another session holds |
| `help` | every command |

## Config

Optional. Each key is resolved separately: the project's `.crew.json`, then your
`~/.claude/crew.json`, then a default. See
[skills/crew/references/config.md](skills/crew/references/config.md).

## The rules

The skill carries the full playbook: one tree, one branch, one committer, hot spots,
failing work kept out of the tree, commit at once, queued machine time, push checks and
message habits. See [skills/crew/references/playbook.md](skills/crew/references/playbook.md).

## Testing

See [CLAUDE.md](CLAUDE.md#testing).
