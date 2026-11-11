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
    ├── id-source.sh          switch a project to the git id source and back / sync pending ids / show it
    ├── id-git.sh             sourced: the git id source (probe, fetch, reserve by push, clone cache)
    ├── renumber.sh           move a task to a fresh id; rewrites only the tasks named, reports the rest
    ├── lib.sh                global roots, worktree → main tree, task_canonical_id (number → PREFIX-NNN), task_fm_set (the one frontmatter writer), task_highest_id, _TASK_JSON_AWK (the one JSON reader, as awk functions), task_config_read, task_config_set_num (nextId in place), task_config_edit (keys set/removed), task_id_replace / task_id_lines (the one id matcher, boundary-aware)
    └── test/*.test.sh        each sources test/lib.sh: TMP, counters, check/contains/lacks, report;
                              run.sh runs all; Dockerfile = bash:5 + git, the container target
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
- **The git id source reserves before it writes, and never touches the user's git state.** The
  task file is created only after the counter push lands. Plumbing only: a temporary index,
  `commit-tree`, `push <sha>:refs/heads/<branch>`. No checkout, no index, no local branch, never
  `--force`. Every reservation commit carries a nonce: without it two clones reserving one number
  in the same second build *identical* commits, and the second push is a no-op "success" that
  hands both the id. `git-source.test.sh` goes red without it.
  Every git call that reaches the remote goes through `idgit_net` (a deadline, output via temp
  files so a surviving ssh cannot block a `$( )`, a lock heartbeat); never call the network
  through `idgit_git` directly (`net-timeout.test.sh`). In `git` mode `nextId` lives in the
  clone's cache under the git common dir, never in the shared config (`references/id-sources.md`).
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
- **A new tag is deliberate, never quiet.** `tags.sh add` refuses a tag no task uses yet unless
  given `--new`. Claude passes it when a tag is logically needed: on its own for a member of a
  family already in use (a per-plugin tag for a new plugin), named in the reply; after asking for a
  new kind of grouping; never for a near-duplicate of a tag in use. Reusing a tag in use needs no
  asking (`references/tags.md`). `tags` is decoded in `read-tasks.sh` only, into `["a", "b"]`.
- **`.task-config.json` is a shared data contract.** `task-roadmap` reads `tasksDir` from
  it. Moving or renaming it breaks that plugin — the file stays where it is.
- **Works without HOME.** With HOME unset, missing or read-only, a project's own `.task-config.json`
  and `_workflow/` are enough. `task_global_roots` skips the `~/.claude` root when HOME is empty, and
  the "no config" error offers a global registry only where one could be created (root `CLAUDE.md`,
  *Without HOME*; PLUG-118). Regression-tested in `config.test.sh`.

## Testing

```
bash scripts/test/epic-dashboard.test.sh   # 21 cases — membership, work order, epic-name resolution
bash scripts/test/list-tasks.test.sh       # 41 cases — every documented list shape
bash scripts/test/status-session.test.sh   # 35 cases — status writes, cascade, active-tasks, canonical ids
bash scripts/test/tags.test.sh             # 48 cases — tags decoding, filter, group=tags, tags.sh
bash scripts/test/review.test.sh           # 33 cases — digest excerpts and filters, candidates, epic hints
bash scripts/test/port.test.sh             # 19 cases — packaging + standalone copy
bash scripts/test/config.test.sh           # 42 cases — global registry + step lookup, CLAUDE_CONFIG_DIR, no HOME
bash scripts/test/config-layout.test.sh    # 18 cases — any JSON layout: one-line project config and registry, odd whitespace, escapes, nextId written in place
bash scripts/test/worktree.test.sh         # 14 cases — a linked git worktree resolves to the main tree
bash scripts/test/created.test.sh          # 22 cases — created: stamp, Created column, sort=created, digest
bash scripts/test/git-source.test.sh       # 46 cases — idSource git: setup/adopt, push reservation, --count, user state untouched, concurrent clones, refusals, fallbacks
bash scripts/test/migration.test.sh        # 16 cases — switching with several clones: a clone's own unpushed tasks claimed or reported on first use, setup warnings
bash scripts/test/offline.test.sh          # 24 cases — idSource git offline: pending, claimed in one push, clash reported and kept, sync, renumber clears
bash scripts/test/switch-back.test.sh      # 18 cases — back from git to local: pending claimed, clash named, nextId from the counter (last fetched offline), cache gone, branch kept, idempotent
bash scripts/test/renumber.test.sh         # 22 cases — renumber.sh: move, created kept, artifacts, --update only, refs, id boundaries, epic index
bash scripts/test/net-timeout.test.sh      # 11 cases — git calls within TASK_ID_NET_TIMEOUT: hung remote falls back, hung push fails clean, long lock wait, lock heartbeat
bash scripts/test/lock.test.sh             #  3 cases — a stale id lock is broken (busybox stat)
bash scripts/test/run.sh                   # every suite
```

A new suite sources `scripts/test/lib.sh` and ends with `report <suite>`; it never defines
its own assertions (PLUG-081 removed seven copies).

Dual-target (host + the `task-test` image: `bash:5` + git, `scripts/test/Dockerfile`) per the repo convention, and the suite must pass
from a copy of `task/` outside this repo with no siblings present. The container run is
not optional: it is busybox awk, and `list-render.awk` is the largest awk program here.

## Known shape

`SKILL.md` is a router (~110 lines). A command costs it plus one file from `commands/`;
reference material is read only when a command file names it. Adding a rule means
choosing its one home — a rule in two files is the failure mode this layout exists to
prevent, and the older, larger `SKILL.md` had several.
