# crew config

You never need a config file. Each key is resolved separately, in this order:
1. **project**: `.crew.json` at the repo root, a flat JSON object that is committed and shared
   by the crew;
2. **user**: `${CLAUDE_CONFIG_DIR:-~/.claude}/crew.json`, your personal habits across projects. It is per
   Claude account: a second account (`CLAUDE_CONFIG_DIR`) keeps its own;
3. the built-in **default**.

`crew.sh config` prints every effective value and the layer it came from.

To change a key, don't edit the JSON by hand:
- `config set <key> <value…>` writes it to `.crew.json` and keeps the other keys. `hotSpots`, `taskPush` and `treeLink`
  take several values.
- `config set --user <key> <value>` writes it to your user file instead. A project-only key is
  refused there.
- `config unset [--user] <key>` removes it.

`committer` and `push` are the user's decision, never the crew's (PLUG-057). While neither layer
sets them, `status` and the coordinator's SessionStart line say so, and the coordinator asks the
user once and records the answer. A value in the user file counts as decided for every project.

`set` checks the value: the committer, push, tree and hook modes, whole numbers, and no `"` or `\`. It does
not start a crew. Adopting crew in a running project: [adopt.md](adopt.md).

| Key | Layers | Default | Meaning |
|-----|--------|---------|---------|
| `crewId` | project | the repo folder name | tags every message and the SessionStart line, so crews on one machine never cross |
| `sharedBranch` | project | the checked-out branch | the one branch the crew works on; switching away is denied |
| `committer` | project, user | `human-approved` | `human-approved`: `land` runs its checks, prints the commit for the user and stops. `coordinator`: only the coordinator lands. `each-session`: a session lands its own paths |
| `push` | project, user | `human` | `human`: the guard denies every member's `git push`, and the user pushes. `committer`: whoever may commit may push (nobody, under `human-approved`) |
| `tree` | project | `shared` | the user's decision (PLUG-066): `shared` is one tree for everyone; `worktrees` gives each task its own worktree on `task/<ID>`. Unset, `status` says it is not decided ([trees.md](trees.md)) |
| `treeSync` | project | `merge` | how `tree sync` brings the shared branch into a task worktree: `merge` or `rebase` |
| `taskPush` | project | none | array of crew names the user lets push their own `task/<ID>` branch, and only that |
| `treeLink` | project | none | array of paths (relative, no `..`) linked from the main tree into every new worktree: local settings and secrets ([trees.md](trees.md)) |
| `treeSetup` | project | none | the project's setup step for a new worktree (install, build, seed), printed for the session to run; crew never runs it |
| `hookMode` | project, user | `deny` | `deny` blocks a guarded tool call. `warn` lets it through with the reason |
| `hotSpots` | project | none | array of globs: files that need a hold before anyone edits them |
| `landCheck` | project | none | command run on the landed file list before `apply` keeps it (e.g. a formatter check). No double quotes: put a complex command in a script |
| `snapshotKeep` | project, user | `20` | snapshots kept per path |
| `snapshotMaxKB` | project, user | `1024` | larger files are not snapshotted |
| `slotGraceMin` | project, user | `10` | minutes past its estimate before a running slot shows as stale |
| `silenceMin` | project, user | `15` | minutes of no tool calls before `watch` reports a session that owns a hold, slot or dirty paths; also the age at which unread mail is reported ([watch.md](watch.md)) |

Project-only keys (`crewId`, `sharedBranch`, `hotSpots`, `landCheck`, `tree`, `treeSync`, `taskPush`, `treeLink`, `treeSetup`) mean nothing across projects. If
they appear in the user file, they are ignored and `config` says so.

```json
{
  "sharedBranch": "develop",
  "hotSpots": ["src/schema.ts", "src/scenes/main.ts"],
  "landCheck": "npx prettier --check",
  "committer": "coordinator",
  "push": "committer"
}
```
