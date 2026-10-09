---
title: crew — durable mailbox: msg --send, inbox, unread notice, Stop check
status: proposed
type: feature
epic: crew-feedback
priority: high
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | — | |
| 20 | Requirements | — | |
| 30 | Assessment | — | |
| 40 | POC | — | |
| 50 | Domain | — | |
| 60 | Architecture | — | |
| 70 | Tests | — | |
| 80 | Subtasks | — | |
| 90 | Implementation | — | |
| 100 | Tech Debt | — | |
| 110 | Reflection | — | |

## Description

Feedback #2a. A dropped SendMessage lost the final hand-offs, and nothing held a copy.

- **`crew msg <kind> … --send`** writes the message to `<state>/mail/<to>/<id>` (plus `all`)
  and prints it for SendMessage as before. Both channels, so the file copy is the one that
  survives.
- **`crew inbox [--all]`** shows unread messages oldest first and marks them read;
  `crew inbox --ack <id>` acknowledges one.
- **Unread notice:** a PostToolUse hook adds `additionalContext` "crew: N unread — crew inbox"
  when the session has unread mail, behind a fork-free check of the mail directory. SessionStart
  says the same.
- **Stop hook:** a session about to go idle with unread crew mail is told to read it first,
  once per message. This catches the "coordinator went idle with a hand-off waiting" case.
- `status` shows unread counts per session.

## Acceptance criteria

- [ ] `msg handoff --send` with no SendMessage at all: the coordinator's next tool call
      surfaces the unread notice, and `inbox` shows the full hand-off.
- [ ] A Stop with unread mail is held once with the reason; the second Stop passes.
- [ ] Mail is per crew (state dir) and per recipient; `all` reaches everyone.
- [ ] A session with no mail pays no fork (fast path).
- [ ] Suites pass on host + docker.
