# Claude Plugins

Plugins for [Claude Code](https://claude.ai/code), Anthropic's coding agent, that add
project discipline: tasks kept as files, docs treated as a product, a visual roadmap, a
questionnaire to start each project, several sessions sharing one working tree, and slow test
suites run overnight.

They grew out of one developer's daily work with Claude Code and are published as a
[plugin marketplace](https://docs.claude.com/en/docs/claude-code/plugins), so you can install
any of them with two commands.

## What they have in common

- **Your state lives in plain files.** Tasks, docs, the roadmap and kickoff answers are markdown
  or HTML in your repo, so you can grep them, diff them, review them in a PR, and read them
  without the plugin installed.
- **No runtime, no dependencies.** Every plugin is pure `bash` + `awk` (plus `git` where it
  needs one). There's no Node, no Python, nothing to install, and no network calls. Each one runs
  on macOS's bash 3.2 and BSD tools as well as Linux and Alpine/busybox, and its test suite runs
  on both.
- **Nothing runs where it isn't used.** Hooks exit straight away in a project that doesn't use
  their plugin, and nothing runs in the background. The one plugin that runs jobs (`delay`) is
  started by you, and it unloads itself when it's done.
- **Each plugin works on its own.** Install one, several or all. None needs another, though some
  pair well (see [How they fit together](#how-they-fit-together)).
- **Config is optional.** Every setting has a working default. Where a plugin reads config, it's
  one flat JSON file at the project root, named after the plugin.

## Plugins

| Plugin | In one line |
|--------|-------------|
| [task](task/) | Markdown task files with a built-in workflow, epics and parallel-safe IDs |
| [task-roadmap](task-roadmap/) | An abstract Gantt chart of your task set, regenerated when tasks change |
| [docs-manager](docs-manager/) | Docs as a product: index pages, link checks, diagrams, catalogued reference files |
| [kickoff](kickoff/) | One questionnaire to start every project, turned into a charter and a scaffold |
| [crew](crew/) | Several Claude sessions on one working tree and branch without lost edits |
| [delay](delay/) | Queue slow test suites to run overnight in docker while the Mac sleeps |
| [session-storage](session-storage/) | Key-value storage scoped to one Claude session, cleaned up automatically |

### task

**For:** keeping a project's work as tasks Claude can create, pick up and finish, with no tracker
outside the repo.

Each task is a `PREFIX-NNN.md` file with YAML frontmatter and a **workflow table**: the steps a
task goes through (context, requirements, tests, implementation, reflection, …) and where it
stands. The table *is* the state. `/task do` reads it and continues from the current step.
Epics group sub-tasks. ID allocation is atomic and lock-guarded, so parallel sessions never
take the same number. Listing is scripted, with filters, grouping, sorting and epic views that
collapse closed work.

```
/task create <title>   /task list [filters]   /task show <id>
/task do <id>          /task finish [id]      /task status <id> [status]   /task workflow
```

Tasks can live in the repo or anywhere you point `.task-config.json` at. [More →](task/README.md)

### task-roadmap

**For:** seeing a task set as a plan: what blocks what, and which chain decides when it's done.

Reads the same task files as `task` (`deps`, `estimate`, `epic` in frontmatter) and renders one
self-contained `roadmap.html`. It schedules tasks by the critical-path method in relative units
(no calendar dates), groups them by epic, outlines the critical path and colours tasks by status.
A hook regenerates it whenever a task file changes. [More →](task-roadmap/README.md)

### docs-manager

**For:** a `docs/` folder that stays navigable, consistent and current as it grows.

- **Navigation:** an auto-generated `_index.md` in every folder, listing its docs with
  descriptions taken from their frontmatter.
- **Link checks:** finds broken relative links between docs.
- **Diagrams as text:** a diagram lives in a `*.diagram.md` source and is copied into every doc
  that uses it. It can link to the code and docs it depicts, and it flags itself as *suspect*
  when they change.
- **How-tos** that Claude reads before drawing an ERD, or before trimming `CLAUDE.md` /
  `AGENTS.md` by moving project knowledge into the docs.
- **External reference files:** a PDF, Word or Excel file dropped into `docs/external/` gets a
  **card** saying what it holds and where inside it to look, and `check` reports files with no
  card or a stale one.

Nothing is rendered by default, because GitHub, IDEs and Obsidian already draw fenced diagrams.
[More →](docs-manager/README.md)

### kickoff

**For:** starting every project from the same questions, so nothing important is left unasked.

Ask Claude to *kick off this project*. It walks a branching questionnaire one section at a time.
Every question has pre-defined options and a default, so a whole section can be accepted at once,
and later questions depend on earlier answers. The answers are saved in `.kickoff-answers`. From
them kickoff generates `docs/project/charter.md` (overview, goal, scope, non-goals, numbered
decisions with their reasons, open questions) and can scaffold the project: a `docs/` skeleton, a
small instructions-only `CLAUDE.md` and the task config. It also works on an existing project,
proposing answers from what it finds there, and keeps a machine-wide registry of dev ports.
[More →](kickoff/README.md)

### crew

**For:** running several Claude Code sessions at once on **one clone and one branch**, without
one session's `git add -A` or `git stash` wiping out another's work.

Sessions opt in with `crew whoami "<name>" [worker|coordinator]`. crew then adds:
- roles: one coordinator, the rest workers;
- **no commit or push without you**: by default `land` prints the commit for you and you push;
  the coordinator asks you once per project whether the crew may do either;
- `crew status`: one screen showing every dirty path and who owns it;
- hand-off messages with a durable mailbox;
- **holds** on hot-spot files, and a **slot** queue for heavy runs;
- a snapshot before every edit, so an overwritten edit can be recovered;
- guard hooks that deny whole-index git commands (`add -A`, `stash`, `reset --hard`, …).

A session that hasn't joined works as usual, and in a repo with no crew the plugin does nothing.
Requires git 2.31 or later. [More →](crew/README.md)

### delay

**For:** a test suite too slow to run while you work. Claude queues it, and it runs at night.

Claude can only *queue* a job: a `.sh` script in the project, the docker container it runs in,
and params. **You** approve each (container, script) pair once with `sudo`. The approval pins
the script and the container definition by sha256, and checks them for red flags. **You** set a
daily run window and start the runner on nights with work. Then the Mac wakes from sleep, runs
the jobs inside the project's container (even with the screen locked), keeps the results for the
next Claude session and unloads itself. Params reach the script as plain arguments, never through
a shell. Requires macOS and Docker (OrbStack or Docker Desktop). [More →](delay/README.md)

### session-storage

**For:** remembering small values (the task you're on, a mode, a path) for the length of one
Claude session, even across `/compact`.

A SessionStart hook tells Claude its session id and the storage command. Values are kept per
session and removed when the session ends; anything older than 24 hours is purged. `task` uses it,
when present, to remember which tasks the session is working on. [More →](session-storage/README.md)

## How they fit together

```
kickoff ──scaffolds──▶ docs/ (docs-manager)  +  task config (task)
task ──task files──▶ task-roadmap (the chart)
task ──optional──▶ session-storage (this session's active tasks)
crew + delay: parallel sessions share one tree; slow suites go to the night
```

Every link above is optional. A plugin reads another's config only when it's there and falls back
to defaults when it isn't.

## Install

From within Claude Code:

```shell
# 1. Add the marketplace (once)
/plugin marketplace add vatvit/claude-plugins

# 2. Install the plugins you want
/plugin install task@vatvit-plugins
/plugin install task-roadmap@vatvit-plugins
/plugin install docs-manager@vatvit-plugins
/plugin install kickoff@vatvit-plugins
/plugin install crew@vatvit-plugins
/plugin install delay@vatvit-plugins          # then follow delay/README.md: a one-time sudo setup
/plugin install session-storage@vatvit-plugins
```

Choose **User scope** to enable a plugin for all your projects, or **Project scope** to share it
with collaborators. Restart open sessions (or run `/reload-plugins`) to load it.

**Update:** `/plugin marketplace update vatvit-plugins`, then update the plugins from the `/plugin`
menu. Removing and re-adding the marketplace isn't needed, and it uninstalls its plugins.

## Development

Each plugin has its own `README.md` (usage), `CLAUDE.md` (design rules and conventions) and a
bash test suite under `<plugin>/scripts/test/`. The suites run on the host and in a `bash:5`
(Alpine/busybox) container, so both BSD and GNU userlands stay covered. The repo-wide shell rules
are in [CLAUDE.md](CLAUDE.md).

## License

[MIT](LICENSE)
