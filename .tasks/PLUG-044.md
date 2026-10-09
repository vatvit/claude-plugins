---
title: crew — durable mailbox: msg --send, inbox, unread notice, Stop check
status: completed
type: feature
epic: crew-feedback
priority: high
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | epic PLUG-041 facts; first-night stall: 6.5 h after dropped hand-offs |
| 20 | Requirements | done | acceptance criteria below |
| 30 | Assessment | done | fits the area-script pattern; no lib.sh change needed |
| 40 | POC | skipped | Stop `decision: block` and PostToolUse `additionalContext` are documented hook contracts |
| 50 | Domain | skipped | no new domain terms beyond mailbox / unread |
| 60 | Architecture | done | see Architecture |
| 70 | Tests | done | inbox.test.sh, 47 checks, red on HEAD first |
| 80 | Subtasks | skipped | one slice |
| 90 | Implementation | done | applied to the tree on 5f5e951; host + docker ALL GREEN |
| 100 | Tech Debt | done | one item, see Tech Debt |
| 110 | Reflection | done | crew/CLAUDE.md design rule; references/inbox.md |

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

## Context

- The epic (PLUG-041) decided that the mailbox **complements** SendMessage. A message goes out on both channels, and the file copy is the durable one.
- The goal is a hand-off that survives a dropped SendMessage. The recipient must keep being told about it, even after going idle.

## Architecture

- **Area script `crew/scripts/inbox.sh`.** It defines functions when sourced (`mail_send`, `mail_arm`, `mail_notice`, `mail_start`, `mail_stop`, `mail_status`, `mail_count`, `mail_ids`). When executed it is the `inbox` CLI. `crew.sh` reaches it with no change, because unknown commands resolve to `<cmd>.sh`.
- **Layout.**
  - Mail lives in `<state>/mail/<name>/new/<id>` (unread) and `…/cur/<id>` (read).
  - `<id>` is a zero-padded sequence shared by the whole crew (`mail/seq`, under the `mail` lock), so a listing is oldest first.
  - Each file has `id= from= to= kind= at=` header lines, a blank line, then the message as printed.
  - `--to all` files one copy for every session except the sender.
  - `<state>/mail/<name>/held` lists the ids a Stop was already held for.
- **Fork-free fast path.**
  - A hook cannot map a session id to a name without forking (`name_of_sid` greps). Sending therefore leaves the marker `<state>/unread/<recipient sid>`.
  - `fast.sh` now exports `CREW_FAST_STATE`, the state dir that `crew_fast_skip` found. `crew_fast_unread` checks the marker with builtins.
  - The slow path drops a stale marker.
  - `whoami` and SessionStart re-arm the marker for a session's new id, which covers re-joins and mail sent before the recipient joined.
- **Hooks.**
  - There is one hook script, `hooks/mail.sh post|stop`, rather than two near-identical ones.
  - PostToolUse (matcher "") adds `additionalContext` while mail is unread.
  - Stop returns `{"decision":"block"}` once for each new unread id. With `hookMode=warn` it returns a `systemMessage` instead.
- **`msg … --send`.**
  - It prints the same text, then calls `mail_send` through a here-string, not a pipe, so `MAIL_TO` survives.
  - It notes the recipients on stderr, so stdout stays the text to paste into SendMessage.
  - A display name passed to `--to` is mapped through `name_for` (PLUG-042).
- **`status`** gets the part `status.d/inbox.sh`: `mail: <name> N unread (oldest HH:MM)`.
- **For PLUG-045:**
  - `mail_ids <name>` and `mail_field <file> at` give the age of the oldest unread message.
  - Load them with `load_area inbox`.

## Tests

`crew/scripts/test/inbox.test.sh` has 47 checks:
- `--send` delivery;
- the PostToolUse and SessionStart notices;
- Stop held once, then passes, and is held again for new mail;
- inbox order, `--all` and `--ack`;
- `--to all` excludes the sender;
- status;
- a rejoin re-arms the notice;
- a stale marker heals;
- warn mode;
- display-name recipients;
- mail is per crew;
- fork-free fast path.

The fast-path checks run the hook with `PATH=""`, so any fork shows up on stderr. A control check proves that the probe does see the slow path's forks.

- **Red on HEAD (ab586ba):**
  - `crew: handoff: unknown argument --send`
  - `crew: unknown command 'inbox'`
  - 0 of the mail checks passed.
- **Deliberate bugs caught:**
  - `crew_fast_unread` made to always take the slow path: 2 FAILs ("no fork").
  - The Stop dedup removed: "the second Stop for the same mail passes" FAILs.
  - The display-name case went red before `name_for` was added to `mail_send`.
- **Suites, run on 5f5e951:** host ALL GREEN and docker (crew-test) ALL GREEN; inbox 47, land 102, core 55.

## Implementation

Files:
- new: `crew/scripts/inbox.sh`, `crew/scripts/status.d/inbox.sh`, `crew/hooks/mail.sh`, `crew/scripts/test/inbox.test.sh`, `crew/skills/crew/references/inbox.md`;
- changed: `crew/hooks/fast.sh`, `crew/hooks/hooks.json`, `crew/hooks/session-start.sh`, `crew/scripts/msg.sh`, `crew/scripts/whoami.sh`, `crew/skills/crew/SKILL.md`, `crew/README.md`, `crew/CLAUDE.md`, and root `CLAUDE.md` (the crew vocabulary gains *inbox / mailbox*).

The versions in plugin.json and marketplace.json are left for the coordinator.

## Tech Debt

- The JSON string escaping is now in two places: `hook_block` in lib.sh does it inline, and `mail_json` in inbox.sh. lib.sh should expose one `json_esc` for both. It was not done here because lib.sh was held for PLUG-042. Fold it in when lib.sh is next touched.

## Reflection

- The mailbox design rule ("mail is a file before it is a message"; the marker fast path) is in `crew/CLAUDE.md`. User-facing behaviour is in `references/inbox.md`.
- A lesson: a function whose side effects must reach the caller cannot sit at the end of a pipe (`printf | mail_send`), because it runs in a subshell. Use a here-string.
