# CLAUDE.md — task-roadmap plugin

Guidance for working on this plugin.

## What it is

An abstract-Gantt roadmap generated from a markdown task set: a runtime-free shell tool
(`scripts/generate.sh`) plus a hook that keeps the output in sync, rendering a
self-contained HTML page from `assets/template.html`.

## Layout

```
task-roadmap/
├── .claude-plugin/plugin.json
├── scripts/
│   ├── lib.sh                   ← shared helpers, sourced by the others
│   ├── generate.sh              ← the generator
│   ├── regenerate-hook.sh       ← PostToolUse hook
│   └── test/roadmap.test.sh     ← the suite (no framework, no dependencies)
├── assets/template.html
├── hooks/hooks.json
├── skills/task-roadmap/SKILL.md
└── README.md
```

**`lib.sh` is this plugin's, not the repo's.** Plugins must work standalone and in any
combination, so nothing here may source another plugin's file. See the repo CLAUDE.md
section *Plugin Independence*.

## scripts/lib.sh

- `json_str <key> <file>` / `json_str_array <key> <file>` — flat JSON reads.
- `resolve_tasks_dir <root>` — **the single implementation** of the precedence rule
  `.task-roadmap.json` > `.task-config.json` > `tasks`. It used to exist twice, once
  here and once inline in the hook; they agreed only by coincidence and nothing would
  have caught them drifting.
- `project_root <dir>` — a linked git worktree stands for the same place in the main
  tree; anything else is returned unchanged. Both `generate.sh` and the hook resolve
  their root through it, because a worktree's tasks are a stale checked-out copy. The
  task plugin has the same rule in its own `lib.sh`; that copy is correct, not debt.

Reading `tasksDir` from `.task-config.json` — a file the task skill owns — is
deliberate. It is shared *data*, not shared code, and it degrades to the default when
absent, so this plugin never requires the task tooling to be installed.

## The `set -e` trap (don't regress this)

`generate.sh` runs under `set -euo pipefail`. **`grep` exits non-zero when it matches
nothing**, and with `pipefail` that status propagates out of `v="$(json_str …)"` and
kills the script.

This shipped as a live bug in 1.0.1: any `.task-roadmap.json` that did not contain
*every* key aborted generation. It went unnoticed for two reasons — the plugin had no
tests, and the one config read that worked happened to sit inside an `&&` list, where
`set -e` is suppressed. `json_str` now ends in `|| true`; keep it that way.

## Key behaviours (don't regress these)

- **The hook always exits 0** and never blocks the tool call that triggered it.
- The hook ignores `_workflow/` paths — those are workflow definitions, not tasks.
- `outputs` in `.task-roadmap.json` replaces the default `<tasksDir>/roadmap.html`
  entirely; multiple outputs are all written.
- No GNU-only flags, no `sed -i`, bash 3.2 compatible — see repo CLAUDE.md.

## Testing

```bash
bash scripts/test/roadmap.test.sh                                            # host
docker run --rm -v "$PWD":/w -w /w bash:5 bash scripts/test/roadmap.test.sh  # container
```

**Run both.** The host target (macOS bash 3.2 + BSD userland) and the container target
(bash 5 + GNU coreutils) catch different portability bugs.

The suite builds throwaway fixtures under `mktemp -d` and never touches the real repo.
It was written *before* `lib.sh` was extracted, specifically to pin behaviour that had
no coverage — and it immediately found the `set -e` bug above. Keep the config-precedence
cases: they are what make it safe to have one implementation instead of two.
