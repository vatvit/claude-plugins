# Watch: notice a crew that has gone quiet

A crew stalls without anyone noticing when the one message that would have moved it is lost.
In the first real crew night, nobody noticed 6.5 hours of silence. The watchdog reports silence
while work is waiting, and it can wake an idle coordinator to deal with it.

## What counts as a finding

`silenceMin` (default 15, set in `config`) is the limit for each of these:

| Finding | Reported when |
|---------|---------------|
| `<name> silent Nm while owning: hold … · slot #… · dirty …` | the session has made no tool call for longer than `silenceMin`, **and** it holds a hold, has a slot, or has claimed dirty paths. An idle session that owns nothing is fine, and is not reported |
| `<name> has N unread for Nm` | its oldest unread mail is older than `silenceMin`. This check needs the mailbox area (`inbox.sh`) |
| `slot #N of <name> … is stale` | a slot has run past its estimate + `slotGraceMin`. `slot list` uses the same rule |

Every line ends with `next:`, the step to take.

Activity is the time of the session's last tool call. Every tool call stamps it, at no cost to
the hook. A session that has made no tool call since it joined counts from its join. `status`
shows `activity: <name> Nm ago` for every session.

## Commands

| Command | Use |
|---------|-----|
| `watch --once` | one pass: the findings, or `watch: quiet` |
| `watch --wait [--every SEC]` | stays silent until the first finding, prints it and **exits 2**. **Run this in the background as the coordinator** (below) |
| `watch [--every SEC]` | runs forever, one line per finding. Each finding is reported again only after it has lasted another `silenceMin`. Built for Monitor-style line streams |

## Coordinator setup: what wakes an idle session

Tested on 2026-10-09 (PLUG-045 POC) against the Claude Code docs:

| Mechanism | Wakes an idle session? |
|-----------|------------------------|
| **Bash `run_in_background` + `watch --wait`** | **Yes, verified.** The command exits at the first finding, and the session is re-invoked with its output. The test used a 1-minute limit: the session went idle at 10:29:55 and was woken at 10:30:49 |
| `asyncRewake` command hook that exits 2 | Documented as the one hook that wakes an idle session. Claude Code enforces its `timeout`. Not needed, given the row above |
| Monitor tool events | Not documented to start a turn while idle. A watch also ends after 30 minutes at most |
| `/loop`, `ScheduleWakeup`, cron | Documented to fire while idle, but each tick costs a full turn, even when nothing is wrong |

**So the coordinator does this:** once the crew is running, start

```
crew watch --wait          # with the Bash tool's run_in_background
```

When it wakes you, act on the `next:` step and then start it again. Restart it after every wake.
Without the restart, nothing watches anymore. The watcher only reads state, so it costs nothing
while the crew is busy. It reports a finding at most once per `silenceMin`.
