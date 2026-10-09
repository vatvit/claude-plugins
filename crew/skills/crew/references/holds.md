# Holds: one holder per hot spot

A commit takes a whole file. If two sessions change one file, their changes can't be split
into two commits, so a file that many features touch gets one holder at a time.

- **Hot spots** are the globs in `.crew.json` `hotSpots`, for example the schema, shared type
  tables or the main scene file. The pre-edit hook denies an edit to an unheld hot spot and
  tells you to hold it first. A `*` in a glob also matches `/`.
- **Any file can be held,** hot spot or not. Hold an ordinary file when you know a peer is
  about to touch it.
- The pre-edit hook **denies an edit to a file another session holds,** naming the holder, the
  time it took the hold and the task.

| Command | Use |
|---------|-----|
| `hold <path...> [--task ID]` | take the hold before editing; refused if someone else holds it |
| `chain <path> [name...]` | queue for a held path (default: yourself); release passes the hold to the next in the chain |
| `release <path...> --sha SHA` | after the green commit that landed your change; refused unless that commit touched the path and is on the branch |
| `release <path...> --unchanged` | you held it but changed nothing; refused while the path is dirty |
| `who [path]` | the registry |
| `drop <path...>` | coordinator only: free a hold whose holder is gone |
| `hold import <file> [--dry-run]` | coordinator only: one hold per bullet `- <path> — <holder> (…)` of a hand-kept list; unknown holders and conflicts are listed, not held. See [adopt.md](adopt.md) |
| `msg hold <path...>` / `msg release <path>` | the announcement, pre-filled; the coordinator relays it to everyone |

`msg handoff` lists the holds you will release once your slice lands. The coordinator posts
the landed sha, and you release with it.

The registry is a file, so a missed message never loses a hold. The coordinator still relays
every hold and release, so nobody is surprised by a denial.
