---
name: remote-docs
description: Use when documents that stay with a provider — Google Drive files and folders, Claude Artifacts — are kept as reference in the project's docs as remote cards, read through the session's tool for that provider and never copied in as bytes. Activate for Google Drive material kept as reference — "attach this Google Drive doc to the docs", "add a Drive doc as reference", "catalogue a Drive file", "remote card", "is the Drive doc card current", "keep the Drive cards local-only", "attach a Drive folder", "refresh the Drive docs", "sync the Drive folder cards", "a Drive file was deleted", "keep a local copy of the Drive doc", "work offline with the Drive docs", "list the remote cards", "remote.sh". Also activate before changing a file in an attached Drive folder — "write to the Drive doc", "update the shared sheet", "edit the doc in the team folder", "convert the docx to Google Docs", "STALE", "READ-ONLY" — the built-in Google Workspace skill then does the editing itself. Also activate for Claude Artifacts kept as reference — "catalogue this Claude artifact", "attach this artifact link to the docs", "artifact card", "refresh the artifact cards", "REMOTE KEY", "REMOTE GONE", "LOCAL COPY STALE" — but not for publishing or editing an artifact. Also activate for what an attached folder is for — "what is this Drive folder for", "folder purpose", "set the purpose of the Drive folder", "is this folder read-only", "may I write to this Drive folder", "team folder", "company folder", "collaboration folder", "output folder", "scope of the folder", "PURPOSE?", "PURPOSE INCOMPLETE", "SCOPE UNKNOWN". Also activate when attaching a Drive folder or artifact and deciding what to ask once — "what should I ask when attaching", "attach without git", "Drive is our only docs store", "where should the cards live".
version: 1.0.0
---

# Remote Docs

A **remote card** (`<name>.gdrive.md`, `<name>.artifact.md`) sits under the docs root and says what a
remote file holds, when to open it and where inside it to look; Claude opens the provider only when the
card says the answer is there. `scripts/remote.sh` keeps the cards honest offline: it never calls a
provider.

**Read [`references/how-to-remote-docs.md`](references/how-to-remote-docs.md) in full before attaching,
refreshing, copying or answering from a remote document**, and work from that file. This file deliberately
states neither the card format nor the procedures.

## Commands

```bash
bash <PLUGIN_ROOT>/scripts/remote.sh check [root]    # what needs attention (default root: docs)
bash <PLUGIN_ROOT>/scripts/remote.sh list  [root]    # every remote card, git-ignored ones too
bash <PLUGIN_ROOT>/scripts/remote.sh purposes [root] # what each attached folder is for: run before working in one
```

The rest (`status`, `stamp`, `gone`, `copy-stamp`, `diff`, `purpose`) are in the how-to, with the step that uses each.

`<PLUGIN_ROOT>` is this plugin's directory — resolve it relative to this skill file.

## With docs-manager

When the docs-manager plugin is installed, its `_index.md` lists remote cards with ☁ and its link check
covers them; its `check` only counts them and leaves their validation to `remote.sh check`. Run both.
