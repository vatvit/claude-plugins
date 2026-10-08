# Snapshots: recover an overwritten edit

Before every Edit / Write / MultiEdit / NotebookEdit, the pre-edit hook saves the file's current
content. `apply` and `snapshot restore` save it too. So when a peer writes a whole file over
your edit, your version still exists.

| Command | Use |
|---------|-----|
| `snapshot log <path>` | the path's snapshots, newest first: id, time, who was about to write |
| `snapshot show <id>` | the content |
| `snapshot diff <id>` | that snapshot against the file now |
| `snapshot restore <id>` | put it back. The current content is snapshotted first, so a restore can itself be undone. Refused while another session holds the file |
| `snapshot prune` | keep only the newest `snapshotKeep` per path, and delete content nothing refers to |

- **What a snapshot holds:** the content *before* the write that the listed session was about
  to make. To get back the text you wrote, find the snapshot taken just before the peer's
  overwrite.
- **What is skipped:** binary files and files over `snapshotMaxKB` are skipped, each with a
  note. A file that has not changed since its last snapshot is not saved again. A new file has
  nothing to save.
- **Not covered:** writes made outside the edit tools, such as shell redirection, `sed`, `cp`
  or generators. Use `apply` instead of `cp`, and commit early: a commit is the real backup.
- Content is stored once per distinct version under `<git-common-dir>/crew/snapshots/`. It is
  never committed, and each path keeps its newest `snapshotKeep` entries automatically.
