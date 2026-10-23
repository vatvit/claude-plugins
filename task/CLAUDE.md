# CLAUDE.md — task plugin

Guidance for working on this plugin. Repo-wide rules (shell conventions, plugin
independence, how to change a plugin) live in the repo root `CLAUDE.md` and apply here.

## Layout

```
task/
├── .claude-plugin/plugin.json
├── skills/task/
│   ├── SKILL.md          ← router only: guardrails, config step, where to read next
│   ├── commands/         ← one file per command, read on demand
│   ├── references/       ← looked up, not followed: formats, config, scripts
│   └── examples/         ← example task file
└── scripts/              ← pure bash + awk, each standalone
    ├── resolve-config.sh     project → tasksDir / prefix
    ├── allocate-id.sh        the ONLY sanctioned way to get an id
    ├── resolve-task.sh       id (or epic-name) → metadata + current workflow step
    ├── read-tasks.sh         the one frontmatter parser: JSON or TSV records (+ body excerpt)
    ├── list-tasks.sh         the finished /task list output
    ├── list-render.awk       its renderer — grouping, sorting, collapsing, columns
    ├── set-status.sh         status write + epic cascade + active-tasks
    ├── tags.sh               tags in use; add / remove a task's tags; review candidates
    ├── session-active.sh     the session's active-tasks list
    ├── resolve-epic.sh       epic-name or id → epic metadata
    ├── update-epic-index.sh  rebuilds _epic-index.json
    ├── epic-dashboard.sh     epic + sub-tasks in work order + queue + recommendation
    ├── lib.sh                global roots, worktree → main tree, task_fm_set (the one frontmatter writer)
    └── test/*.test.sh        each sources test/lib.sh: TMP, counters, check/contains/lacks, report
```

Scripts are referenced from the skill as `<PLUGIN_ROOT>/scripts/…`, and would be
`${CLAUDE_PLUGIN_ROOT}` in a hook. **Never write an absolute path into this plugin.**

**One parser.** Frontmatter is read in exactly one place — `read-tasks.sh`, JSON for
consumers and `--records` TSV for scripts. `resolve-task.sh` adds id resolution and the
workflow table on top of it, and everything else goes through one of those two. Five copies
of that awk block is what this replaced; do not start a sixth.

**Prose is for judgement, scripts are for work.** If a rule can be executed the same way
every time — filtering, sorting, collapsing, a frontmatter write — it belongs in a script
with a test. What stays in the skill is what needs the user: whether a status should change
at all, whether to skip a step, append-or-switch when two tasks compete for a session.


## Don't regress

- **ID allocation.** `allocate-id.sh` is the only path to an id. Its four guarantees —
  no stale counter, self-healing `max(nextId, highest+1)`, `noclobber`, `mkdir` mutex —
  exist because parallel Claude sessions genuinely raced and destroyed each other's task
  files. Never compute an id from `nextId`, never write to a constructed path.
- **A linked git worktree is the main tree.** `task_project_dir` in `lib.sh` maps it, and
  every script that takes a project dir goes through it. Resolve from the worktree's own
  copy and each worktree gets its own lock and its own sequence — the race above, again.
- **The workflow table is the state.** Nothing else records which step a task reached.
- **Status is never changed without the user asking.** This is a guardrail in prose
  precisely because it is a judgement call, not something a script can enforce.
- **Epic membership is the `epic:` field alone.** The epic never lists its sub-tasks; an
  older epic's `## Sub-tasks` section is prose, and an id listed there without the field is not
  a member. A second source of membership is what PLUG-077 removed. Regression-tested.
- **session-storage is optional and detected, never required.** The skill finds it by a
  context string and skips silently when absent. Every command must work with it missing;
  that is the path most installs are in.
- **Claude never invents a tag.** `tags.sh add` refuses a tag no task uses yet unless given
  `--new`, which stands for the user's OK; reusing a tag in use needs no asking
  (`references/tags.md`). `tags` is decoded in `read-tasks.sh` only, into `["a", "b"]`.
- **`.task-config.json` is a shared data contract.** `task-roadmap` reads `tasksDir` from
  it. Moving or renaming it breaks that plugin — the file stays where it is.

## Testing

```
bash scripts/test/epic-dashboard.test.sh   # 21 cases — membership, work order, epic-name resolution
bash scripts/test/list-tasks.test.sh       # 41 cases — every documented list shape
bash scripts/test/status-session.test.sh   # 26 cases — status writes, cascade, active-tasks
bash scripts/test/tags.test.sh             # 48 cases — tags decoding, filter, group=tags, tags.sh
bash scripts/test/review.test.sh           # 33 cases — digest excerpts and filters, candidates, epic hints
bash scripts/test/port.test.sh             # 19 cases — packaging + standalone copy
bash scripts/test/config.test.sh           # 13 cases — global registry + step lookup, CLAUDE_CONFIG_DIR
bash scripts/test/worktree.test.sh         # 14 cases — a linked git worktree resolves to the main tree
```

A new suite sources `scripts/test/lib.sh` and ends with `report <suite>`; it never defines
its own assertions (PLUG-081 removed seven copies).

Dual-target (host + `bash:5` container) per the repo convention, and the suite must pass
from a copy of `task/` outside this repo with no siblings present. The container run is
not optional: it is busybox awk, and `list-render.awk` is the largest awk program here.

## Known shape

`SKILL.md` is a router (~110 lines). A command costs it plus one file from `commands/`;
reference material is read only when a command file names it. Adding a rule means
choosing its one home — a rule in two files is the failure mode this layout exists to
prevent, and the older, larger `SKILL.md` had several.
