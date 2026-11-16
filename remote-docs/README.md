# remote-docs

Remote documents in your project's docs: Google Drive files and folders, and Claude Artifacts, kept as
**remote cards** that say what each file holds, when to read it and where inside it to look. The file
stays with its provider; Claude reads it through the session's tool only when a card says the answer is
there.

Split out of docs-manager. It works alone, or together with docs-manager, which then lists the cards in
its `_index.md` navigation and checks their links.

## What it does

With a Google Drive MCP connected (`/mcp`), Claude can attach a Drive doc as reference material without
copying it: it writes a **remote card**, `pricing-model.gdrive.md`, with a summary, a *where to look*
table, and the Drive file id, URL and the `modifiedTime` it was written from. Claude opens Drive only when
the card says the answer is there, and tells you when Drive has a newer version than the card.

- **Scripts never touch Drive.** Only Claude does, through the MCP; `remote.sh stamp` is the one
  writer of the recorded Drive version.
- **Private material stays private on request.** Before the first card in a repo with a public remote,
  Claude asks whether to commit the cards or keep the folder local-only (git-ignored). A local-only folder
  is never named in a committed `_index.md`; `remote.sh list` still lists it for Claude.
- **Claude Artifacts too.** A `claude.ai/…/artifact/…` page given as a link gets a card,
  `dashboard.artifact.md`, the same way. Its refresh reports only the artifacts already carded, and an
  `sk=` access key never reaches a committed card (`check` fails with `REMOTE KEY`).
- **Each folder says what it is for.** `.source.md` gives a purpose (`reference`, `agreements`,
  `collaboration`, `output`, or your own words), whether Claude may write there (`never`, `propose`,
  `free`), whether decisions live there, and whose material it is (`user`, `project`, `team`, `company`,
  or a scope of your own). A sub-folder inherits from its parent; nothing declared means read-only.
  A collaboration folder gets one card for the whole folder instead of one per file.
- **Writes only where the folder allows, never over a teammate's change.** Before every write Claude
  re-reads the file and runs `remote.sh guard`: read-only folders refuse, a file changed since Claude read
  it is reported, `propose` folders (and team or company ones) wait for your approval. Google Docs writes
  are rejected by Google itself when someone wrote in between; Sheets have no such guard, so Claude appends
  where it can. An Office file is converted to Google format first, on your say-so, and the card follows
  the new file (`remote.sh repoint`).
- **Cards shared with the team, on request.** An attachment's cards can live on Drive in one Google Doc,
  so every teammate's Claude reads the same map (and a project without git can keep its docs there).
  Claude pulls it into a temp folder (`remote.sh unpack`), works there, and writes it back (`remote.sh
  pack`) guarded by Google's revision check, so two sessions never overwrite each other silently.
- The procedure and the card format: [`how-to-remote-docs.md`](skills/remote-docs/references/how-to-remote-docs.md).

## Commands

```bash
bash scripts/remote.sh check docs                 # incomplete, gone, keyed cards; stale or orphan local copies
bash scripts/remote.sh list docs                  # every card, local-only ones too
bash scripts/remote.sh status docs                # one record per card or copy
bash scripts/remote.sh stamp docs/external/vendor/pricing-model.gdrive.md 2026-11-10T13:37:23Z
bash scripts/remote.sh gone docs/external/vendor/old.gdrive.md
bash scripts/remote.sh copy-stamp docs/external/vendor/pricing-model.gdrive.md 2026-11-10T13:37:23Z
bash scripts/remote.sh diff docs/external/vendor /tmp/listing.tsv
bash scripts/remote.sh purposes docs                                 # what each attached folder is for
bash scripts/remote.sh purpose docs/external/team/drafts             # one folder, inheritance resolved
bash scripts/remote.sh guard docs/external/team/plan.gdrive.md 2026-11-12T08:00:00.000Z   # before a write
```

Pure bash and awk, bash 3.2 and BSD or GNU userland, no network calls. Tests: see [`CLAUDE.md`](CLAUDE.md#testing).

## License

MIT
