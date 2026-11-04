# Watch: notice a crew that has gone quiet

A crew stalls without anyone noticing when the one message that would have moved it is lost.
In the first real crew night, nobody noticed 6.5 hours of silence. The watchdog reports silence
while work is waiting, and it can wake an idle coordinator to deal with it.

## What counts as a finding

`silenceMin` (default 15, set in `config`) is the limit for each of these:

| Finding | Reported when |
|---------|---------------|
| `<name> silent Nm while owning: hold … · slot #… · dirty …` | the session has made no tool call for longer than `silenceMin`, **and** it holds a hold, has a slot, or has claimed dirty paths. An idle session that owns nothing is fine, and is not reported. Neither is one that waits in the slot queue or runs its own slot within the estimate: that is waiting, and `status` shows it (`s2 4m ago (slot #7 waiting 17m, ETA 12:10)`) |
| `slot #N of <name> has waited Nm in the queue (ETA …) behind #…` | a slot of this crew has waited longer than `slotWaitMin` (20). Tell the user how long and why |
| `slot #N of <name> [crew] can start but has not (…)` | a slot of any crew is STUCK: the queue passes it ([slots.md](slots.md)). Tell its owner, or its crew's coordinator |
| `<name> has N unread for Nm` | its oldest unread mail is older than `silenceMin`. This check needs the mailbox area (`inbox.sh`) |
| `slot #N of <name> … is stale` | a slot has run past its estimate + `slotGraceMin`. `slot list` uses the same rule |
| `crew time not reviewed for Nh` / `this crew waited Nm in the slot queue since the last review` | the coordinator's time review is due: `timeReviewHours` (24) without `crew time`, or `timeReviewQueueMin` (60) of this crew's queue waits since the last one ([time.md](time.md)) |

Every line ends with `next:`, the step to take.

Activity is the time of the session's last tool call. Every tool call stamps it, at no cost to
the hook. A session that has made no tool call since it joined counts from its join. `status`
shows `activity: <name> Nm ago` for every session.

## Commands

| Command | Use |
|---------|-----|
| `watch --once` | one pass: the findings, or `watch: quiet` |
| `watch --wait [--max MIN] [--every SEC]` | stays silent until a **new** finding, prints it and **exits 2**. With `--max`, it exits 0 after MIN minutes with no new finding, printing `watch: no new finding for MINm; open: N`, a heartbeat. **Run this in the background as the coordinator** (below) |
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
crew watch --wait --max 20          # with the Bash tool's run_in_background
```

When it wakes you, act on the `next:` step, tell the user what changed, and start it again. Restart it
after every wake. Without the restart, nothing watches anymore. The watcher only reads state, so it costs
nothing while the crew is busy.

**A finding wakes you once (PLUG-103).** `--wait` remembers what it reported in `watch.reported`, so the
next `--wait` does not exit on the same finding again. Before this, a coordinator restarted it and was
woken at once on the same line, and stopped running it. A finding that clears and comes back wakes you
again. `--max 20` still wakes you every 20 quiet minutes, so a crew stalled on something that is no finding
is noticed too. Use `watch --once` to list what is still open.

**Nothing watching is reported (PLUG-105).** A running watch leaves `watch.pid`. When none runs, the
coordinator's SessionStart line (at start, resume and after `/compact`) and `status` say
`watch is not running`, with the command. One crew stalled overnight because its watch was not restarted
after a compaction.
