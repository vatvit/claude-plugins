# Time: where the crew's time goes, and what to do about it

The coordinator reviews where the crew's time goes **at least once a working day, and after a long
stretch of slot-queue waits**, and acts on it. `watch` reminds you when either is due (`review:time`).
One crew's first review showed a worker working 16–20 % of its day and waiting on the machine for
40–70 %, and led straight to changes in how the crew works.

## The command

```
crew time [--since HH:MM | YYYY-MM-DD | "YYYY-MM-DD HH:MM"] [--idle MIN]
```

One table: a row per category, a column per member and the crew, as `h:mm` and the share of that
member's counted time. The default window is today from midnight (local). Running it counts as the
review and resets the reminder.

It reads each member's Claude Code transcript, found by every session id crew recorded for that
name (a `/clear` or restart is merged), and the slot history. It prints categories and tool names
only, never transcript text, which holds the project's data. Keep your report to the user the same.

## Reading the categories

Every gap between two transcript entries is charged to what ended it.

| Row | Means | Notes |
|-----|-------|-------|
| Claude working | the model produced the next step | an upper bound: it includes the model's own latency |
| a tool (not Bash) | Read, Edit, SendMessage … | usually seconds |
| a process running | a Bash command, a background job, a subagent, the run part of a slot | the machine doing real work |
| the slot queue | a `slot run` waiting for its turn | split from the run by the slot history |
| slot: queue or run, unknown | a `slot run` with no history | slots run before the history existed |
| the shared tree | `land`, `hold`, `apply`, `release`; messages GATE, QUEUE, HOLD, HOT, RELEASE(D), COLLISION, LANDED, HEAD, SEAM | |
| a decision from a peer | messages DECISION, AGREED, GO, OK, YES, ANSWER, ACK, ASSIGN, USER, or a task id | |
| a peer's work | any other crew message (HANDOFF, STATUS, RESULT, DONE …) or a subagent's report | |
| the user | the user's next message | |
| compaction | the context was summarised | |
| idle, not counted | a gap longer than `--idle` (30 min) | overnight and breaks; raise `--idle` to count them |

**What is uncertain.** A Bash command is classified by its text, so a script that runs crew
indirectly counts as a process. A member that joined before session ids were recorded has only its
current session. Say what is uncertain in the report instead of rounding it away.

## Pitfalls the first one-off analysis hit (now handled, keep in mind)

- Multi-day totals drown in overnight idle. Report a window (today, `--since 09:00`), and keep the
  idle cut.
- Queue and run of one `slot run` are one tool call. Only the slot history splits them, so time
  before the history shows as "unknown".
- Timezones: `--since` is local time, taken from the system. Never pass an offset by hand.
- Waiting spends no tokens. The cost is per wake-up: each one re-reads the conversation, cheap within
  the prompt-cache lifetime and full price after it. Many short polls cost more than one wait that
  ends on an event.

## Levers: what the numbers usually point to

| The table shows | Lever |
|-----------------|-------|
| workers mostly in "a process running" and "the slot queue" | workers run only the checks their change touches in their copies (unit checks, the E2E files they touched); the coordinator's one full gate on the shared tree checks everything, on a batch of landings. Trade-off: a failure is found later and must be traced to its hand-off |
| many short landings, each with its own gate | group hand-offs, so they land and gate together |
| slow E2E runs on every change | run the slow E2E only when a change touches what it covers |
| another crew's slots dominate the queue | tell the user, with the ETA; `slot list` tags them `[crew]` |
| memory-heavy runs made `exclusive` while cores idle | `--mem` and `--group` instead ([slots.md](slots.md)) |
| "a decision from a peer" large for workers | decide sooner, or decide in batches; the coordinator is the usual bottleneck |
| many short gaps of polling | waits that end on an event (`slot run` in the background, `watch --wait`) |

Holds and landings cost almost nothing in practice (about 0.2 h a day for a whole crew). Do not
optimise them first.

## The report to the user

Short:

1. The window it covers, and the table (`crew time` output as is).
2. What is uncertain.
3. The bottleneck, in one sentence.
4. The levers you propose. **A lever that changes how the crew works is proposed to the user first**,
   never applied on your own.

## Config

| Key | Default | Meaning |
|-----|---------|---------|
| `timeReviewHours` | `24` | `watch` reminds the coordinator after this many hours without `crew time`. `0` turns it off |
| `timeReviewQueueMin` | `60` | …or once this crew's slots waited this many minutes in the queue since the last review. `0` turns it off |
