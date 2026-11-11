---
title: "EPIC: docs-manager — attach Google Drive docs and folders to docs/, through a connected Google Drive MCP"
status: completed
type: epic
epic-name: docs-gdrive
priority: low
created: 2026-11-11 15:58
tags: ["docs-manager-plugin"]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | done in the sub-tasks' Context sections (PLUG-112, 113, 115) and the POC |
| 40 | POC | done | 2026-11-11, claude.ai Google Drive connector, read-only calls on 1–2 files; see POC findings |
| 60 | Architecture | done | settled per sub-task: `.source.md` fields, card fields, listing TSV (PLUG-112/113/115); docs-manager/CLAUDE.md § Remote cards |
| 110 | Reflection | done | how-to, SKILL.md triggers, CLAUDE.md done per sub-task; **release deferred** by the user (see Closing) |

## Goal

Let a project **attach** a Google Drive doc or folder to its `docs/` tree, so Claude knows what
the remote material holds and opens it **only when needed**. This builds on docs-manager's external
docs (epic `external-docs`, `skills/docs-manager/references/how-to-external-docs.md`): every attached
file gets a **card** (summary, `read-when`, where to look), and `_index.md` lists it.

## Why

Reference material often lives in Drive, not in the repo. Today Claude either doesn't know it
exists or the user pastes it in by hand. A card per remote file tells Claude what is there and when
to fetch it, without loading whole documents into every session.

## Constraint that shapes the design

docs-manager is pure bash + awk, and **a script cannot call an MCP tool**; only Claude can.
- **The skill (Claude)** does everything that touches Drive: list, read, export, write.
- **The scripts** stay offline and tested: they read cards and `.source.md`, compare a
  listing Claude wrote to a temp file with the cards, and report in `index` / `check`.

It works only when a Google Drive MCP server is connected (`/mcp`). Without one, docs-manager
behaves as today; existing cards still serve as offline summaries.

## Agreed design (2026-11-11, with the user)

### Attachment

- An attachment is a folder under `docs/` (e.g. `docs/external/vendor-contracts/`) holding one
  `.source.md`: provider (`gdrive`), URL / id, and the settings below. The folder *is* the
  attachment; no central config.
- `provider:` field from the start, so another MCP (Confluence, Notion) can be added later. No
  abstraction layer beyond the field.

| Setting | Values | Meaning |
|---|---|---|
| content | `remote` / `sync` | `remote`: the file stays on Drive. `sync`: a copy goes into the repo, Google formats exported (Doc→docx/md, Sheet→xlsx/csv, Slides→pdf) |
| processed | `none` / `local` / `remote` | A readable `<doc>.md` text version of a complex file. `local` lets the user work **offline, at their own risk** (it may be stale). `remote` writes it to Drive and is the fallback for when `local` is not allowed |
| scope | doc / folder, recursive, include / exclude | What a folder attachment covers |

### Cards and index

- Every attached file has a local card, whatever the settings. Claude reads the card first and
  opens Drive only when the card says the answer is there.
- `_index.md` marks remote-only cards (e.g. `☁ remote`), so Claude knows that opening the file needs the MCP.
- Drive not connected or not signed in: Claude says the remote is unavailable, never answers
  from a card as if it had read the file. A card says when the file is reachable only by people with
  access to that Drive.

### Refresh

- Claude lists the attached folder through the MCP into a temp file; a script compares it with the
  cards (file id + modifiedTime) and reports new / changed / gone.
- A card whose Drive file is gone is marked orphaned, never silently deleted.
- Before a sync that would copy more than N files or X MB, Claude asks.

### Options that go against a docs-manager default: the plugin ASKS

These go against a docs-manager **default** (not a ban) or are outward-facing. Each is allowed, but
only after the plugin asks and the user says yes. The defaults rest on the plugin's own reasons;
they are not the maintainer's personal working rules, which never belong in a plugin. The answer
is recorded in the attachment's `.source.md`, so it is asked once per attachment, not on every refresh:

1. **A processed `.md` kept in the repo.** Goes against the default "only the card goes into the
   repo": a text copy can go stale while looking authoritative. Mitigation: stamp it with the source's
   modifiedTime; refresh reports it as stale.
2. **Cards or URLs in a repo with a public remote.** A summary of private material *is* private
   content. Default: ask, offer to gitignore the attachment's cards.
3. **Writing the processed `.md` to Drive.** That is publishing into the user's Drive, possibly a
   shared folder. Offered mainly when (1) is declined.

## POC findings (2026-11-11)

Run against the **claude.ai Google Drive connector** (`claude.ai Google Drive`, signed in through
`/mcp`). Read-only calls only, on one or two files; nothing written to Drive. No file names, ids or
contents are recorded here.

**Tools it exposes:** `search_files`, `list_recent_files`, `get_file_metadata`, `read_file_content`,
`download_file_content`, `get_file_permissions`, `create_file`, `update_file`, `copy_file`,
`trash_file`, `share_file`, `list_shared_drives`, `get_shared_drive_metadata`.

**Metadata (every listing and `get_file_metadata`):** `id`, `title`, `mimeType`, `modifiedTime`
(RFC 3339, ms), `createdTime`, `etag`, `parentId` (one), `viewUrl`, `resourceUri`
(`googledrive://file/<id>`), `owner`, `fileSize` (native Google files too), `fileExtension` (only
for uploaded files, absent for native Docs / Sheets / Slides), `capabilities`, `trashed`.
- **The change stamp is `modifiedTime`.** No revision id or md5 in the listing; `etag` is just
  `modifiedTime` base64-encoded, so it adds nothing. → A remote card records `id` + `modifiedTime`.
- Native files are told apart by `mimeType` `application/vnd.google-apps.{document,spreadsheet,presentation,folder}`.

**Folder listing:** `search_files` with `parentId = '<folder id>'`, `excludeContentSnippets: true`,
paginated (`nextPageToken`). Sub-folders come back as items with the folder mimeType, so a recursive
attachment is one call per folder (plus pages). Fits PLUG-113's "Claude lists into a temp file".

**Reading content:** `read_file_content` returns a text rendering of Docs / Sheets / Slides, pdf,
docx / xlsx / pptx, odf, text, images: the right call for writing a card. `download_file_content`
returns **base64 in Claude's context**; for native files `exportMimeType` picks the format, and
**`text/markdown` export works for a Google Doc** (checked). Consequences:
- **sync (PLUG-114) costs context tokens per byte**: a downloaded file passes through Claude's
  context as base64 before Claude can write it to disk. The size ask must be in bytes, set low by
  default, and binary sync of large PDFs is expensive. (Upload has a file-reference shortcut,
  download does not.)
- **processed (PLUG-115):** for a native Doc, the markdown export *is* the processed copy; no extractor needed.

**Writing (PLUG-116):** `create_file` creates a file (text or base64, optional `parentId`).
**`update_file` changes metadata only (title, parent, flags), never content.** So a processed copy on
Drive cannot be updated in place: each refresh creates a new file and `trash_file`s the old one, and its
id changes every time. PLUG-116 must design for that, or reconsider remote processed copies.

**Found in PLUG-112's e2e:** a file created with `create_file` (text converted to a Google Doc) reports
one `modifiedTime` in the create response and a later one seconds afterwards, once Drive finishes the
conversion. Record `remote-modified` from a fresh `get_file_metadata`, never from a create/upload
response, or the card reads as out of date at once (matters for PLUG-116).

**Portability:** these tool names are the claude.ai connector's. Another user may have a different
Google Drive MCP server with other names. The skill must detect Drive by capability (a server whose
tools search, read and list Drive files), not by a fixed tool name; scripts never see tool names at all.

## Scope

- Attach a single Drive doc, remote-only, with card, index entry and the public-repo ask
- Attach a folder and refresh it (new / changed / orphaned)
- `content: sync`: copy and export into the repo
- `processed: local` and `processed: remote`, each asked once per attachment

## Out of Scope

- Publishing authored `docs/` pages to Drive (write-back of our own docs)
- Providers other than Google Drive (only the `provider:` field is reserved)
- Creating or editing Google files as such: that is the built-in google-workspace skill's job

## Success Criteria

- No Drive MCP connected: no behaviour change; all existing docs-manager tests pass.
- Attaching a Drive doc produces `.source.md` and a card that `index` lists as remote and `links` / `check` accept.
- Every option that goes against a default is asked before it happens, and the answer is recorded and not asked again.
- Scripts are tested offline against fixture cards and listings; no test needs network or an MCP.
- Trigger phrases do not collide with the built-in google-workspace skill; docs-manager owns
  *attaching Drive files as reference material*.
- The plugin works standalone (repo rule: copy it alone and run its suite).

## Decision: no content: sync (2026-11-11, the user)

PLUG-114 rejected: the connector delivers a file only as base64 in Claude's context, so a copy means
retyping it, with no checksum to catch corruption. Text copies of native files are PLUG-115's
`processed: local`; binaries stay remote, or the user downloads them into `docs/external/` by hand.
The `content` setting therefore has one value, `remote`, for now.

## Closing (2026-11-11)

Success criteria:
- No Drive MCP: no behaviour change; every existing docs-manager suite passes unchanged (E2, RC3 pin it).
- Attaching a doc gives `.source.md` + a card that `index` lists as ☁ and `links` / `check` accept (PLUG-112).
- Options against a default are asked once and recorded in `.source.md`: `publish`, `processed: local` +
  `copy-publish`; `copy-stamp` itself refuses an unagreed copy (PLUG-115). Writing to Drive was dropped (PLUG-116).
- Scripts tested offline on fixture cards and listings; no test needs network or an MCP.
- Triggers: docs-manager owns attaching Drive material as reference; its description says "not for creating
  or editing Google files, which is the built-in Google Workspace skill's job".
- Standalone: all suites green from a copy of the plugin alone, on the host, `bash:5` and without HOME.

Delivered: remote cards, folder attach + refresh, local copies. Dropped: `content: sync` (PLUG-114),
processed copies on Drive (PLUG-116).

**Release deferred (the user, 2026-11-11):** docs-manager stays 1.11.0 while other features gather. The
release then bumps `docs-manager/.claude-plugin/plugin.json` (version, description, keywords: Google
Drive, remote cards, local copies), `.claude-plugin/marketplace.json`, and the docs-manager section of
the root `README.md` (remote Drive material).

## Current State

Completed; the release is pending (see Closing). Throwaway Drive test items (`dm-e2e-*`) stay in the
user's test folder (location in session memory, not here).
