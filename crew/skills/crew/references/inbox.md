# Mailbox: messages a dropped SendMessage cannot lose

SendMessage is fire-and-forget. If a delivery is dropped, the hand-off is gone and both sides
wait. In the first real crew night, the final hand-offs were lost at 02:56 and nobody noticed
for 6.5 hours. The mailbox keeps a file copy of every message, and hooks keep telling the
recipient about it until it is read.

## Send

```
msg <kind> [--to NAME] … --send
```

`--send` prints the same text as before, and you still send it with SendMessage. It also files
the message in the recipient's mailbox. With `--to all`, it files it for every session except you.
Use `--send` for anything someone else must act on: hand-offs, decisions, stop times. A message
that arrives through both channels is a cheap duplicate. A message lost on both channels costs
hours.

You can mail a name that has not joined yet. The message waits, and `whoami` reports it when
that name joins.

## Read

| Command | Use |
|---------|-----|
| `inbox` | unread mail, oldest first, in full; marks it read |
| `inbox --all` | read mail too (history) |
| `inbox --ack <id>` | mark one message read without showing it, e.g. when SendMessage already delivered it |

## How you are told

- **After every tool call** (PostToolUse): `crew: N unread crew messages — read before going on: … inbox`.
  This repeats until you read the messages.
- **At session start, and after `/compact` or a re-join**, you get the same line.
- **Before going idle** (Stop): the stop is held once for each unread message, with the same line,
  so a coordinator cannot go quiet while a hand-off waits. The next stop goes through. With
  `hookMode=warn`, you get a warning instead of a hold.
- **`status`** shows `mail: <name> N unread (oldest HH:MM)` for every session with unread mail.

When there is no mail, these hooks cost nothing. Sending leaves a marker for the recipient's
session id in `<state>/unread/`, and a hook that finds no marker exits on shell builtins alone.

## Layout

`<git-common-dir>/crew/mail/<name>/new/<id>` is unread, and `…/cur/<id>` is read. The id is a
sequence shared by the whole crew, so a directory listing is in sending order. Each message file
has `id= from= to= kind= at=` header lines, a blank line, and then the message as printed. Mail
belongs to its crew's state directory. Another crew on the same machine never sees it.
