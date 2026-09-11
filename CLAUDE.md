# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

## What This Is

A multi-plugin collection for Claude Code. Each plugin lives in its own sub-directory with its own CLAUDE.md, hooks, scripts, and skills.

## Repository Structure

```
claude-plugins/
├── .claude-plugin/
│   └── marketplace.json      ← marketplace registry (name: vatvit-plugins)
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
| session-storage | `session-storage/` | Session-scoped key-value storage with auto-cleanup |
| docs-manager | `docs-manager/` | Docs-as-product: auto `_index.md` navigation, link checks, conventions |
| task-roadmap | `task-roadmap/` | Abstract-Gantt roadmap from a markdown task set, auto-regenerated on task changes |

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
- **Passing multi-line text to awk:** use a temp file read with `getline`, never
  `awk -v` (which cannot carry newlines).
- **Hooks always `exit 0`** and never block the tool call that triggered them. A hook that reports
  something writes to stderr — so never wrap a hook body in `2>/dev/null`, which silences the one
  thing it exists for.
- **Never assert on `diff` output shape in tests.** busybox `diff` (Alpine, the usual container
  target) defaults to *unified* format while BSD and GNU default to *normal* format, so a test
  grepping `^>` or `^+` passes on one target and fails on the other. Use `diff -q` for exit status,
  or compare content directly.
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

## Tasks

Task files live in `.tasks/` (`PLUG-NNN.md`), configured by `.task-config.json`.
The project workflow is `.tasks/_workflow/WORKFLOW.md` — it deliberately omits the
`bdd` step, since this repo has no Cucumber/Gherkin infrastructure; behavioural
coverage lives in each task's acceptance criteria and is implemented at the `tests`
step as plain bash test scripts.

## Working on a Specific Plugin

Refer to the plugin's own `CLAUDE.md` for architecture, conventions, and testing instructions.
