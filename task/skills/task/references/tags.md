# Tags

A task may carry `tags`: labels that cut across epics and types (`performance`, `tech debt`,
`asset-generation`). Optional; a task without them behaves exactly as one never tagged.

## A tag is not an epic

| | Epic | Tag |
|---|---|---|
| Says | which **batch of work** a task belongs to | what a task **is about** — its kind or topic |
| Scope | finite: a goal, a scope, success criteria | open: no scope of its own |
| Lifetime | is worked systematically and **completed** | never finishes; new tasks keep getting it |
| Per task | at most one (`epic:`) | any number (`tags:`) |

Pick by asking *does this grouping have an end?* "Ship the auth rewrite" has one: an epic, and
so is a milestone ("milestone 2"), which is reached and closed.
"Everything about performance" has none: a tag. When the user asks for one and the other fits,
say so before creating it — a tag used as a batch never gets closed, and an epic used as a topic
never can be. A batch held in a tag splits its membership in two: a task tagged `milestone 2`
but outside the epic is one nobody counts when asking whether the milestone is done. Both on one task is normal: an epic `render-v2` whose sub-tasks are tagged
`performance`.

## The field

```yaml
tags: ["performance", "tech debt", "three of several words, and with comma"]
```

A flow array of double-quoted strings, lowercase. The quotes are what let a tag hold spaces
and commas; a tag cannot hold `"` or `\`. `read-tasks.sh` also reads the loose `[a, b]` and any
case, so a hand edit still counts, but write the quoted lowercase form — `tags.sh` does.

## Writing tags — what Claude may do on its own

The tags already in use come first: `tags.sh <tasksDir> <prefix> list` prints each with its count.

- **Reuse without asking.** When a task you create or shape clearly fits a tag in use, add it.
  The user should not have to name the same tag on every task.
- **Never invent a tag.** A tag no task has yet is added only when the user asked for it or
  agreed to it. `tags.sh add` refuses one unless given `--new`, and `--new` is that OK — never
  pass it on your own judgement.
- **Ask when unsure** whether a tag fits, and when a wanted tag looks like one in use
  (`perf` / `performance`, `tech-debt` / `tech debt`): name the existing tag and ask which.

Add and remove through the script, on a new task or one in flight alike — tags are labels, not
history, so the append-only rule does not cover them:

```
<PLUGIN_ROOT>/scripts/tags.sh <tasksDir> <prefix> add <id> [--new] <tag>...
<PLUGIN_ROOT>/scripts/tags.sh <tasksDir> <prefix> remove <id> <tag>...
```

## Filtering

| `/task list …` | lists |
|----------------|-------|
| `tags=performance` | tasks with that tag (case ignored) |
| `tags=performance,ui` | tasks with either |
| `tags=performance 'tags="tech debt"'` | tasks with both — a repeated `tags=` is AND |
| `'tags="three of several words, and with comma"'` | a tag with spaces or commas, quoted |
| `tags~debt` | tasks with a tag containing `debt` |
| `tags=_` | tasks with no tags |
| `group=tags` | one group per tag; a task with two tags is in both |

Pass a quoted value to `list-tasks.sh` with its double quotes intact (single-quote the argument).

## Reviewing the backlog for a tag

When the user asks for a tag to be applied across the backlog, or a part of it ("tag the
rendering work `performance`", "review the proposed tasks for `tech debt`"). Asking for a new
tag this way is the user's OK for it: the first `add` takes `--new`, the rest need none.

Reading every task file is what makes this expensive — never open them all. In order:

1. **Shortlist.** `tags.sh <tasksDir> <prefix> candidates <tag> --match "<stems>"`: the keywords
   are matched as substrings anywhere in a file, case ignored, so pick stems and synonyms
   (`perf,latency,slow,cache`) and expect some noise (`perf` also hits *perfectly*). Each line is
   `tagged`, `match` with the line it hit, or `via epic`. Add `--all` to include closed tasks.
2. **Digest.** `list-tasks.sh <tasksDir> <prefix> digest` with the user's filters (`status=`,
   `epic=`, `all`, …) — one block per task with the start of its summary, about 1/20 of the
   files. It covers the tasks the keywords missed; judge most tasks from it alone.
3. **Open a file only when the digest is not enough** to decide. For a large backlog where many
   are unclear, split them across subagents that read the files and return only proposals.
4. **Propose, then write.** Show one table — *tag*, *unsure*, *skip* — with a one-line reason
   each, and write nothing before the user's OK. Then `tags.sh add` per task, and confirm with
   `/task list tags=<tag>`.
