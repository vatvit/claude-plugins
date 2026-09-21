# CLAUDE.md — task plugin

Guidance for working on this plugin. Repo-wide rules (shell conventions, plugin
independence, how to change a plugin) live in the repo root `CLAUDE.md` and apply here.

## Layout

```
task/
├── .claude-plugin/plugin.json
├── skills/task/
│   ├── SKILL.md          ← the whole command surface
│   ├── references/       ← workflow-guide.md
│   └── examples/         ← example task file
└── scripts/              ← pure bash + awk, each standalone
    ├── resolve-config.sh     project → tasksDir / prefix
    ├── allocate-id.sh        the ONLY sanctioned way to get an id
    ├── resolve-task.sh       id → metadata + current workflow step
    ├── read-tasks.sh         all frontmatter → compact JSON (used by /task list)
    ├── resolve-epic.sh       epic-name or id → epic metadata
    ├── update-epic-index.sh  rebuilds _epic-index.json
    ├── epic-dashboard.sh     epic + sub-task statuses + recommendation
    └── test/epic-dashboard.test.sh
```

Scripts are referenced from `SKILL.md` as `<PLUGIN_ROOT>/scripts/…`, and would be
`${CLAUDE_PLUGIN_ROOT}` in a hook. **Never write an absolute path into this plugin.**

## Don't regress

- **ID allocation.** `allocate-id.sh` is the only path to an id. Its four guarantees —
  no stale counter, self-healing `max(nextId, highest+1)`, `noclobber`, `mkdir` mutex —
  exist because parallel Claude sessions genuinely raced and destroyed each other's task
  files. Never compute an id from `nextId`, never write to a constructed path.
- **The workflow table is the state.** Nothing else records which step a task reached.
- **Status is never changed without the user asking.** This is a guardrail in prose
  precisely because it is a judgement call, not something a script can enforce.
- **Epic membership is list items and table rows only.** Prose inside `## Sub-tasks` is
  commentary — a sentence naming a task id must not make it a member. Regression-tested.
- **session-storage is optional and detected, never required.** The skill finds it by a
  context string and skips silently when absent. Every command must work with it missing;
  that is the path most installs are in.
- **`.task-config.json` is a shared data contract.** `task-roadmap` reads `tasksDir` from
  it. Moving or renaming it breaks that plugin — the file stays where it is.

## Testing

```
bash scripts/test/epic-dashboard.test.sh   # 11 cases — epic membership parsing
bash scripts/test/port.test.sh             # 17 cases — packaging + standalone copy
```

Dual-target (host + `bash:5` container) per the repo convention, and the suite must pass
from a copy of `task/` outside this repo with no siblings present.

## Known shape

`SKILL.md` is large (~1000 lines) because it inlines procedures that are really programs —
the `/task list` rendering above all. Two follow-up tasks address that: extracting the data
work into scripts, then splitting `SKILL.md` into a router plus on-demand command files.
Until those land, edits to the list/status sections are prose edits; afterwards they are
script edits. Check the repo's `.tasks/` for the current state before restructuring.
