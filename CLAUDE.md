# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

## What This Is

A multi-plugin collection for Claude Code. Each plugin lives in its own sub-directory with its own CLAUDE.md, hooks, scripts, and skills.

## Repository Structure

```
claude-plugins/
├── .claude-plugin/
│   └── marketplace.json      ← marketplace registry (name: vatvit-plugins)
├── task/                    ← plugin: markdown task management (/task)
├── session-storage/           ← plugin: session-scoped key-value storage
│   ├── .claude-plugin/
│   │   └── plugin.json
│   ├── hooks/
│   ├── scripts/
│   ├── skills/
│   ├── CLAUDE.md              ← plugin-specific guidance
│   └── README.md              ← plugin-specific docs
├── docs-manager/              ← plugin
├── task-roadmap/              ← plugin
├── delay/                     ← plugin
├── crew/                      ← plugin
├── kickoff/                   ← plugin
├── .tasks/                    ← this repo's own task files (NOT a plugin)
├── .task-config.json          ← task skill config (tasksDir, prefix)
├── CLAUDE.md                  ← this file (repo-level)
├── README.md                  ← repo-level overview
└── LICENSE
```

**A top-level directory is not automatically a plugin.** Plugins are exactly the
entries listed in `.claude-plugin/marketplace.json`; anything else at root is ignored
by the plugin system. `.tasks/` is this repo's task storage — never add it to the
marketplace, and treat `tasks` / `.tasks` as reserved directory names.

## Plugins

| Plugin | Directory | Description |
|--------|-----------|-------------|
| task | `task/` | Markdown task files with an embedded workflow table, epics, and parallel-safe ID allocation |
| session-storage | `session-storage/` | Session-scoped key-value storage with auto-cleanup |
| docs-manager | `docs-manager/` | Docs-as-product: auto `_index.md` navigation, link checks, conventions |
| task-roadmap | `task-roadmap/` | Abstract-Gantt roadmap from a markdown task set, auto-regenerated on task changes |
| delay | `delay/` | Queue approved per-project jobs (autotests) for the user's run window; user-started runner wakes the Mac, runs them in docker, unloads itself |
| crew | `crew/` | Several Claude sessions on one working tree and branch: coordinator/worker playbook, identity, status by owner, hand-offs, guard hooks |
| kickoff | `kickoff/` | New-project questionnaire: branching questions with options and defaults, answers recorded in the project, charter generated from them |

## Shell Conventions

Every plugin here is pure bash + awk with no language runtime. These are hard
constraints, not preferences — a plugin that breaks them breaks on someone's machine.

- **Target bash 3.2.** That is the system bash on macOS, and `#!/usr/bin/env bash`
  does *not* avoid it — it resolves to 3.2 there too. So **no associative arrays
  (`declare -A`)**, no `globstar`, no `${var^^}`. Indexed arrays (`declare -a`) are fine.
- **Both BSD and GNU userland.** No GNU-only flags in shipped code.
- **Never `sed -i` in shipped code** — `-i ''` is BSD-only, bare `-i` is GNU-only.
  Write via temp file and `mv`, which is also what makes writes atomic.
- **Diff-guard every write.** Compare before `mv` so an unchanged file is never
  touched; this is what makes the generators idempotent.
- **Shebang is `#!/usr/bin/env bash`, never `#!/bin/bash`.** On Alpine — the usual
  container target — bash is at `/usr/local/bin/bash` and `/bin/bash` does not exist, so a
  hardcoded shebang fails with `bad interpreter`. It bites only when one script *execs*
  another directly rather than being run as `bash script.sh`, which is why it can sit
  unnoticed for a long time: found in the task plugin the first time its suite ran in the
  container, where `allocate-id.sh` execs `resolve-config.sh`.
- **Passing multi-line text to awk:** use a temp file read with `getline`, never
  `awk -v` (which cannot carry newlines).
- **awk portability traps** (found in kickoff 0.1.0, each by only one of the two test targets):
  `a[++n] = "x" n` evaluates the two sides in different orders on BSD awk and busybox, so increment
  in its own statement. And a non-ASCII character (`★ ≠ · §`) is one char in gawk but several bytes
  in busybox/mawk, so strip it with a pattern, never a `substr` offset. And a backslash in a `gsub`
  *replacement* is read differently by busybox than by gawk and BSD awk, so escape with a character loop.
  And macOS awk cuts `substr` by bytes while its `tolower` rejects broken UTF-8: `tolower(substr(s, 1, n))`
  aborts when the cut lands inside a multibyte character. Lowercase whole strings and compare with `index`.
- **Hooks always `exit 0`** and never block the tool call that triggered them, with one deliberate
  exception: crew's guard hooks deny (a JSON `permissionDecision`, still exit 0), because a warning
  arrives after `git add -A` has already staged a peer's files; `hookMode=warn` turns them off. A hook that reports
  something writes to stderr — so never wrap a hook body in `2>/dev/null`, which silences the one
  thing it exists for.
- **Never assert on `diff` output shape in tests.** busybox `diff` (Alpine, the usual container
  target) defaults to *unified* format while BSD and GNU default to *normal* format, so a test
  grepping `^>` or `^+` passes on one target and fails on the other. Use `diff -q` for exit status,
  or compare content directly.
- **Never `cmd | grep -q` under `pipefail` in tests.** `grep -q` exits on the first match, the
  writer gets SIGPIPE, and `pipefail` turns the match into a failure, but only when the output is
  big enough. Capture first (`out="$(cmd)"; echo "$out" | grep -q …`). Found in delay 1.0.0, where
  two `list` checks failed on the host for exactly this reason.
- **Dates: BSD `date -j -f FMT` fills every field missing from FMT with the *current* value**,
  seconds included, so `-f "%Y-%m-%d %H:%M"` returns a different epoch each second. Always parse
  with explicit seconds. Try BSD (`date -j -f`, `date -r <epoch>`) first, then fall back to
  GNU/busybox (`date -d`, `date -d @<epoch>`), and keep both in one helper.
- **Never bake an absolute path into a value that gets committed.** A digest, cache key or stamp
  containing a checkout path computes differently on every machine, so it always mismatches and the
  check it guards becomes noise people learn to ignore.

When a map is needed, don't hold it in bash: have awk emit tab-separated typed
records and read them with `while IFS=$'\t' read -r`.

## Adding a New Plugin

1. Create a new directory at root level (e.g., `my-plugin/`)
2. Add `.claude-plugin/plugin.json` inside it
3. Add entry to `.claude-plugin/marketplace.json` plugins array with `"source": "my-plugin"`
4. Add hooks, scripts, skills, CLAUDE.md, README.md as needed
5. Add a row to the Plugins table above

Hooks are auto-discovered at `<plugin>/hooks/hooks.json` — `plugin.json` does not
declare them.

## Plugin Independence

**Every plugin must work standalone and in any combination with the others.** A plugin
ships as its own directory and cannot assume a sibling is installed.

- **Never source another plugin's file**, and never add a `lib/` at repo root. Each
  plugin keeps its own `scripts/lib.sh` for what more than one of *its* scripts needs.
- **DRY applies within a plugin, not across plugins.** Two plugins each carrying a small
  JSON-reading helper is the correct outcome, not debt. The duplication to eliminate is
  the second copy *inside* one plugin.
- **Shared config data is fine; shared code is not.** A plugin may read a key out of a
  file another tool owns — `task-roadmap` reads `tasksDir` from `.task-config.json` —
  provided it has a working default when that file is absent. It degrades, never fails.
- **Prove it**: copy the plugin directory somewhere with no siblings and no repo root,
  and run its test suite there.

### Config convention

No plugin requires a config file. Where one is supported it is a flat JSON object at the
project root named for the plugin (`.task-roadmap.json`), read with the plugin's own
`json_str`, and every key is optional with a working default. A plugin may add a **user layer**
(`${CLAUDE_CONFIG_DIR:-~/.claude}/<plugin>.json`) resolved per key, project first: crew does, and keeps the keys that
only make sense per project (branch names, paths) out of it.

**Per account or per machine — decide which, per file.** The user runs several Claude accounts on one
machine; Claude Code sets `CLAUDE_CONFIG_DIR` for a non-default one.
- **Per-account** data (the user's preferences, the user layer above) lives in
  `${CLAUDE_CONFIG_DIR:-~/.claude}`, so each account keeps its own. `task` resolves it this way.
- **Machine-wide** state (anything that guards a resource of the machine — ports, Docker, the
  session-name registry, the run window) lives in `~/.claude/<plugin>/` and deliberately ignores
  `CLAUDE_CONFIG_DIR`, because two accounts sharing one Docker must see each other. crew's name
  registry and delay's home are this kind.

**Beware `set -euo pipefail` when reading config.** `grep` exits non-zero when it matches
nothing, and with `pipefail` that status propagates out of `v="$(json_str …)"` and kills
the script. An absent key is normal. This shipped as a live bug in task-roadmap 1.0.1:
any `.task-roadmap.json` missing *any* key aborted generation, and it went unnoticed
because the one read that worked happened to sit inside an `&&` list where `set -e` is
suppressed. Helpers whose empty result is normal must end in `|| true` or `return 0`.

## Changing an Existing Plugin

When a plugin gains or loses a user-visible capability, three things drift apart unless
updated together. The marketplace entry is what people read before installing, and the
skill description is what decides whether the plugin ever activates — both are easy to
forget because neither is exercised by any test.

1. `<plugin>/.claude-plugin/plugin.json` — bump `version`, refresh `description` and `keywords`
2. `.claude-plugin/marketplace.json` — sync that plugin's `description` and `version`
3. `<plugin>/skills/<name>/SKILL.md` — add trigger phrases to `description:`, or the new
   capability is unreachable no matter how good it is

**Check trigger phrases against the other plugins' skill descriptions.** Two plugins
competing for the same words is a coin flip at activation time. Today the vocabularies are
disjoint: docs-manager owns *docs / index / links / diagram / picture / CLAUDE.md / AGENTS.md /
external docs / catalogue / ingest / reference material*, task-roadmap owns *roadmap / gantt /
timeline*, session-storage owns *storage / session data*, delay owns *delay / run later / run
tonight / run at night / wake* and says *job*, never *task*, crew owns *crew / coordinator / worker /
hand off / hold / hot spot / slot / land / copy / snapshot / inbox / mailbox* and says *slot*, never *job* or *queue* alone,
kickoff owns *kickoff / kick off / new project / start a project / bootstrap / questionnaire / charter*
and never says *init*, which is the built-in `/init`.
Bare *pdf / word / excel / docx /
xlsx* belong to Claude's built-in document skills — no plugin here claims them.

## Tasks

Task files live in `.tasks/` (`PLUG-NNN.md`), configured by `.task-config.json`.
The project workflow is `.tasks/_workflow/WORKFLOW.md` — it deliberately omits the
`bdd` step, since this repo has no Cucumber/Gherkin infrastructure; behavioural
coverage lives in each task's acceptance criteria and is implemented at the `tests`
step as plain bash test scripts.

## Working on a Specific Plugin

Refer to the plugin's own `CLAUDE.md` for architecture, conventions, and testing instructions.
