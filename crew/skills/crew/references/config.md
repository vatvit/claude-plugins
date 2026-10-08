# crew config

You never need a config file. Each key is resolved separately, in this order:
1. **project**: `.crew.json` at the repo root, a flat JSON object that is committed and shared
   by the crew;
2. **user**: `${CLAUDE_CONFIG_DIR:-~/.claude}/crew.json`, your personal habits across projects. It is per
   Claude account: a second account (`CLAUDE_CONFIG_DIR`) keeps its own;
3. the built-in **default**.

`crew.sh config` prints every effective value and the layer it came from.

| Key | Layers | Default | Meaning |
|-----|--------|---------|---------|
| `crewId` | project | the repo folder name | tags every message and the SessionStart line, so crews on one machine never cross |
| `sharedBranch` | project | the checked-out branch | the one branch the crew works on; switching away is denied |
| `committer` | project, user | `coordinator` | `coordinator`: only the coordinator lands. `each-session`: a session lands its own paths. `human-approved`: `land` prints the command and stops |
| `hookMode` | project, user | `deny` | `deny` blocks a guarded tool call. `warn` lets it through with the reason |
| `hotSpots` | project | none | array of globs: files that need a hold before anyone edits them |
| `landCheck` | project | none | command run on the landed file list before `apply` keeps it (e.g. a formatter check). No double quotes: put a complex command in a script |
| `snapshotKeep` | project, user | `20` | snapshots kept per path |
| `snapshotMaxKB` | project, user | `1024` | larger files are not snapshotted |
| `slotGraceMin` | project, user | `10` | minutes past its estimate before a running slot shows as stale |

Project-only keys (`crewId`, `sharedBranch`, `hotSpots`, `landCheck`) mean nothing across projects. If
they appear in the user file, they are ignored and `config` says so.

```json
{
  "sharedBranch": "develop",
  "hotSpots": ["src/schema.ts", "src/scenes/main.ts"],
  "landCheck": "npx prettier --check",
  "committer": "coordinator"
}
```
