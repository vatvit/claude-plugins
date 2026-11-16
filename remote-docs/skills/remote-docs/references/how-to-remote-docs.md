# How to manage remote documents

A **remote document** stays with its provider (Google Drive, Claude Artifacts) and is never copied into
the repo as bytes. Its **remote card** is a markdown file under the docs root that says what the file
holds, when to open it and where inside it to look, so a later session opens the provider only when the
card says the answer is there, and only the part it names.

With the docs-manager plugin installed, cards are listed in `_index.md` with ☁ and their links are
checked there; without it, everything below still works.

## The card

Named `<name>.<provider>.md`. Frontmatter: `title`, `description` (what the file is *for*), `read-when`
(the situations that should send someone to it, written as tasks), `relates-to` (docs that depend on
it, relative to the card; optional), plus the `remote-*` fields below. Body: a `## Summary` of three to
six sentences, a `## Where to look` table (topic → location) and, where useful, `## Key terms`.

**`## Where to look` is the point of the card.** Locate by what the format has: page numbers for a PDF
(plus table or figure numbers), the heading path for a document (`§4.2 Termination`), sheet + range for
a spreadsheet (`Q3!A1:F40`), slide numbers for a deck. Every row must be something you actually found in
the file: a plausible location that is wrong is worse than none.

### Reading a file

Read only as much as the card needs: the first pages and any table of contents, then the sections they
point at, recording locations as you read them. A large file (more than ~50 pages, or several files at
once): delegate the reading to a sub-agent that returns the drafted card. Scratch output goes to a temp
directory, never into the repo.

## Commands

```bash
bash <PLUGIN_ROOT>/scripts/remote.sh status [root]               # one record per card or copy: state, place, file, card
bash <PLUGIN_ROOT>/scripts/remote.sh check  [root]               # REMOTE INCOMPLETE / REMOTE GONE / REMOTE KEY / LOCAL COPY …
bash <PLUGIN_ROOT>/scripts/remote.sh list   [root]               # every remote card, git-ignored ones too
bash <PLUGIN_ROOT>/scripts/remote.sh stamp <card> <time>         # record the provider's modified time
bash <PLUGIN_ROOT>/scripts/remote.sh gone <card>                 # mark a card whose file left the provider (never deletes)
bash <PLUGIN_ROOT>/scripts/remote.sh copy-stamp <card> <time>    # record the version a local copy was written from
bash <PLUGIN_ROOT>/scripts/remote.sh diff <dir> <listing.tsv>    # provider listing vs the attachment's cards
bash <PLUGIN_ROOT>/scripts/remote.sh purpose <path> [root]       # what a folder is for, and what that allows
bash <PLUGIN_ROOT>/scripts/remote.sh purposes [root]             # the same for every folder with a .source.md
bash <PLUGIN_ROOT>/scripts/remote.sh questions <dir> [root]      # what is still to be asked for an attachment folder
bash <PLUGIN_ROOT>/scripts/remote.sh guard <card> <time>         # right before a write: READ-ONLY / STALE / PROPOSE / OK
bash <PLUGIN_ROOT>/scripts/remote.sh repoint <card> <id> <url> <type> <time>   # the card follows a converted file
bash <PLUGIN_ROOT>/scripts/remote.sh pack <dir>                  # an attachment's card set as one text, for Drive
bash <PLUGIN_ROOT>/scripts/remote.sh unpack <text> <empty-dir>   # that text back into files
bash <PLUGIN_ROOT>/scripts/remote.sh extracted <card>            # its material was reviewed for decisions
```

`status` emits `state<TAB>place<TAB>file<TAB>card`, `-` for an empty field. `state` is `remote |
incomplete | gone | keyed | copy | copy-stale | copy-unstamped | copy-unasked | copy-orphan`; `place` is
`filed | unfiled | outside` (under `<root>/external/<topic>/`, at the top of `external/`, elsewhere).
The default root is `docs`.

## Folder purpose

Every attached folder says what it is for, so Claude knows whether to read it only, write to it, and
whether a decision may live there. **Run `remote.sh purposes` before working in an attached folder**,
and `remote.sh purpose <path>` for the one you are about to touch. Never guess a folder's purpose from
its name or its files.

The answers live in the folder's `.source.md`. A folder without one takes them from the nearest folder
above, **key by key**: a sub-folder's `.source.md` may say only `purpose:` and keep the parent's
`publish:` and `provider:`. Describe the attached folder and, where they differ, a few folders one
level down; never every folder.

```markdown
purpose: agreements        # reference | agreements | collaboration | output | your own words
writes: propose            # never | propose | free         (a suggested purpose sets these three,
truth: yes                 # yes: decisions live here       an explicit key overrides it)
cards: files               # files: one card per file | pointer: one card for the whole folder
scope: team                # user | project | team | company | a scope listed in scopes:
scopes: [user, project, client, team, company]   # optional: the order, narrowest first
```

| Suggested purpose | It is | writes | truth | cards |
|---|---|---|---|---|
| `reference` | material read as it is: specs, contracts, vendor docs | never | no | files |
| `agreements` | agreements and context; where decisions live | propose | yes | files |
| `collaboration` | working files, temporary, changed often | free | no | pointer |
| `output` | what the work produces; lasting, read back too | free | no | files |

**Acting on the settings:**
- `writes: never` — read only. Never change, rename, move or trash a file there.
- `writes: propose` — show the exact change first and apply it only when the user approves.
- `writes: free` — write as the task needs, and say what you changed.
- `truth: yes` — decisions live here; when a decision changes, it changes here.
- `truth: no` — never treat what is here as decided. A decision made here is extracted into a
  `truth: yes` doc (*Extracting decisions*).
- `cards: pointer` — the folder has **one card**, for the folder itself (its `remote-id` is the folder's),
  saying what the folder is for and how it is organised. `diff` then reports the folder as `changed`
  when any file in it changed, never single files as `new` or `gone`. Use per-file cards
  (`cards: files`) only where the files are lasting material.

**Custom purpose.** Anything other than the four suggestions is the user's own words: follow them as an
instruction. It implies no settings, so ask once for `writes` and `truth` and record both; `check`
fails with `PURPOSE INCOMPLETE` until they are there.

**Scope** says whose material it is, narrowest first: `user > project > team > company`. The user may add
their own scope by listing the full order in `scopes:` (`check` fails with `SCOPE UNKNOWN` on a scope it
does not list). The narrower scope wins a conflict. The wider the scope, the more careful a write: in a
team or company folder, propose even where `writes: free`, unless the user said otherwise, and **never put
project-specific content in a wider scope**: it belongs in the project's folder.

**Nothing declared** (no `.source.md` up the chain sets a purpose): the folder is read-only and not where
decisions live (`writes: never`, `truth: no`, `scope: project`). `check` prints a `PURPOSE?` note for such
an attachment, without failing: ask the user once what the folder is for, and record the answer.

## Remote documents


A **remote card** describes a file that stays with its provider, with no copy in the repo. It is a
card like any other (same sections, same rules for `## Where to look`), so Claude can tell from the
card whether the file matters and opens the provider only when it does. Only Claude talks to the
provider, through the tool the session has for it; no command here makes a network call.

Everything below is written for Google Drive and holds for every provider. What differs:

| | Google Drive (`gdrive`) | Claude Artifact (`artifact`) |
|---|---|---|
| The thing | a Drive file, or a folder of them | a page published at `claude.ai/…/artifact/…`: a prototype, dashboard, write-up, doc |
| Claude reads it with | a Drive MCP (search, metadata, content as text) | the Artifact tool (read by link, list); a Doc artifact also through the Claude Docs MCP (`read`) |
| `remote-id` | the Drive file id | the artifact id: the last path segment of its URL |
| `remote-modified` | `modifiedTime` | the listing's last-updated time, as given |
| Attached as | a file, or a folder (`.source.md` `remote-id`) | one by one, by link: never a container |
| Refresh reports | `new`, `changed`, `gone` for a folder | `changed`, `gone` only (*Claude Artifacts* below) |
| Access keys | none | `sk=` in a share link (*Claude Artifacts* below) |

`.source.md` says which provider a folder's cards come from (`provider:`; absent means `gdrive`). A
folder may hold cards of both; `diff` compares only those of its `.source.md`'s provider.

### Layout and format

```
docs/external/vendor-api/
├── .source.md                     ← settings of this folder's Drive attachments
├── payments-spec-v3.pdf.gdrive.md ← remote card of an uploaded PDF (its extension kept)
└── pricing-model.gdrive.md        ← remote card of a native Google Doc / Sheet / Slides (no extension)
```

- **The name classifies it:** `<name>.gdrive.md`. `<name>` is the Drive title in kebab-case, keeping an
  uploaded file's extension; a native Google file has none. Same title twice in a folder: append `-2`.
  `index` lists it under *External documents* as `☁`, and it is never an orphan.
- **Frontmatter:** the card fields above (`title`, `description`, `read-when`, `relates-to`) plus
  `remote-id` (Drive file id), `remote-url` (its view URL), `remote-type` (its mimeType) and
  `remote-modified`. There is no `digest`. The id lives in the card because there is no local file whose
  name could be the link.
- **`remote-modified` is written only by `remote.sh stamp <card> <time>`**, with the
  `modifiedTime` Drive reported for the version the card was written from. Never edit it by hand.
  `check` fails on a remote card without `remote-id` or `remote-modified` (`REMOTE INCOMPLETE`).
- **The card body** opens with the link and where the file lives:
  `[payments-spec-v3.pdf](<remote-url>) — on Google Drive, 212 pages; readable only with access to that Drive.`
- **`.source.md`**, one per folder, holds the answers that apply to every Drive attachment in it and
  every folder below it (each key from the nearest `.source.md` that sets it; *Folder purpose* above):

  ```markdown
  ---
  provider: gdrive
  content: remote        # the file stays on Drive
  processed: none
  publish: commit        # or local: the folder is git-ignored (see step 3)
  purpose: reference     # see Folder purpose
  ---
  ```

  It is per-folder data, like a card, not a config file. Being a dot-file, it is never indexed.

### Attaching — the procedure

Run this when the user asks to attach, link or catalogue a Google Drive doc (a URL or an id) as
reference material.

1. **Find the Drive MCP.** Recognise it by what its tools do (search Drive, read a file's content,
   get a file's metadata), not by a tool name: names differ between servers. If there is none, or it
   asks for authentication, tell the user to connect or sign in with `/mcp`, and **write nothing**.
2. **Read the file.** Get its metadata (id, title, mimeType, modifiedTime, view URL), then its content
   as text; read only as much as the card needs, as in *Reading a file* below. For a large file,
   delegate the reading to a sub-agent that returns the drafted card.
3. **Ask what is still open, once per folder.** Run `remote.sh questions <folder>` and ask **only** what
   it prints, in that order, before writing any card. Record each answer in the folder's `.source.md`
   (create it if needed); an answer recorded in a `.source.md` above counts too, so nothing is asked
   twice. Ask them together in one message where you can.
   - `purpose`: offer the four suggestions with a line each (*Folder purpose*) and **other**, in the
     user's words. A suggestion settles `writes` and `truth`.
   - `writes`, `truth`: only for a purpose in the user's own words. Ask both.
   - `cards-at`: where the cards live. **`local`** (the default: under the docs root, in this
     project) or **`drive`** (one shared document on Drive, so every teammate's Claude reads the same
     cards; *Cards on Drive* below). Without git, say that `drive` is the way to share them.
   - `publish`: printed only in a git repository. Look at `git remote -v`. With a private remote,
     record `publish: commit` without asking. With a public remote (or one you cannot tell), ask: a
     card's summary of a private file *is* private content, and its URL names the file. Offer
     **commit** the cards, or keep the folder **local-only** (git-ignored, so it never reaches the
     remote); for `local`, add the folder to `.gitignore`, which is part of what the user chose.
   - **No git, no publish question**, and never write a `.gitignore`: nothing is published, and no one
     reads it.
4. **Write the card** in the folder the user chose (propose `external/<topic>/` as for any external),
   in the format above, then `remote.sh stamp <card> <modifiedTime>`.
5. **Verify.** `remote.sh check` must be clean. With docs-manager installed, also its `index --write`
   (a local-only folder is not indexed: that is the point) and its `check`.

### Attaching a Drive folder

When the user attaches a Drive **folder** rather than one file, the local folder mirrors it: one card
per Drive file, and each Drive sub-folder becomes a sub-folder of the attachment, its name in kebab-case,
so `index` and the topic layout work unchanged. Its `.source.md` also records the Drive folder and the scope:

```markdown
---
provider: gdrive
content: remote
processed: none
publish: commit
remote-id: 1AbC…               # the Drive folder's id
remote-url: https://drive.google.com/drive/folders/1AbC…
recursive: true                # false: only the files directly in the folder
include: [specs/*, *.pdf]      # optional; globs on the listing path, `*` also matches `/`
exclude: [*draft*]             # optional; an exclude always wins
---
```

Ask what `questions` prints, as in step 3 above, write `.source.md`, then run **Refreshing** below: on a
new attachment every file is `new` (with `cards: pointer`, the folder itself is).

### Refreshing a Drive folder

Run this when the user asks to refresh the Drive docs, or the first time in a session that an attached
folder's material is used.

1. **List the folder through the MCP** into a temp file outside the repo, never into it: every page of
   results, and every sub-folder when `recursive` is not `false`. One row per Drive item, tab-separated:
   `id<TAB>path<TAB>mimeType<TAB>modifiedTime`, where `path` is relative to the attached folder
   (`specs/payments-spec.pdf`). Take `modifiedTime` as Drive reports it; never reformat it.
2. **`remote.sh diff <dir> <listing>`** compares it with the attachment's cards, matching by Drive
   id, so a renamed or moved file is not gone + new. It skips folders and out-of-scope rows, and rejects
   a malformed listing by line number. Nothing printed means in sync.
3. **Act on each record:**
   - `new<TAB>id<TAB>path<TAB>mime<TAB>time`: read the file, write its card at the mirrored path, then
     `remote.sh stamp <card> <time>`. **More than 20 new files: ask first**, saying how many; above a few,
     delegate the reading to sub-agents that return drafted cards.
   - `changed<TAB>id<TAB>card<TAB>time`: re-read the file, update the card (rename or move it when the
     Drive title or folder changed), then `remote.sh stamp <card> <time>` with **that** time. If the card has
     a local copy, rewrite it too (*Keeping a local copy*) and `remote.sh copy-stamp <card> <time>`.
   - `gone<TAB>id<TAB>card`: the file was deleted, moved out of the folder or out of scope.
     `remote.sh gone <card>`, then ask the user whether to delete the card. Never delete it on
     your own: `check` fails with `REMOTE GONE` until the user decides, and if the file comes back, it
     shows up as `changed` and stamping it clears the mark.
4. **Verify:** `remote.sh check` must be clean (with docs-manager, its `index --write` and `check` too), apart from `REMOTE GONE`
   cards the user chose to keep for now.

### Keeping a local copy

A remote card is the default: the file stays on Drive. A **local copy** (`<name>.gdrive.local.md` beside
the card) lets the user read the material offline, at their own risk: it can fall behind Drive, and a
committed copy puts the file's content in the repo. It goes against the default, so **ask once per
folder** before writing any, and record the answer in `.source.md`:

```markdown
processed: local         # local copies allowed in this folder (absent or `none`: no copies)
copy-publish: local      # local: git-ignore the copies; commit: commit them with the cards
```

For `copy-publish: local`, add `<folder>/*.gdrive.local.md` to `.gitignore`, as for `publish: local`. With a
public remote, say plainly that `commit` publishes the files' contents. Without git, `questions` does not
print `copy-publish`: ask only whether copies are wanted (`processed:`).

Writing a copy:

1. **Read the file's text rendering** through the MCP (the call that returns a file's content as text,
   not the base64 download). Above about 200 KB of text, ask first.
2. **Write it verbatim** to `<name>.gdrive.local.md`: never summarise, reorder or fix it; it is a copy,
   and the card is where judgement goes. No frontmatter: the stamp lives in the card.
3. **`remote.sh copy-stamp <card> <modifiedTime>`**, the same time the card was stamped with. It refuses
   when `.source.md` does not say `processed: local`, or the copy is missing. With `copy-publish:
   commit`, link the copy from the card body: `Local copy: [<name>.gdrive.local.md](<name>.gdrive.local.md)
   (may be behind Drive).` With `local`, **do not link it**: the copy is git-ignored, so the link would
   be broken in every other clone. `remote.sh list` names it either way.

`check` reports `LOCAL COPY STALE` when the card was restamped and the copy was not,
`UNSTAMPED`, `NOT AGREED` for a copy in a folder that never allowed one (ask, or delete it), and
`ORPHAN` for a copy without its card. A git-ignored copy is checked all the same.

**Binary files are never copied through the MCP.** A Drive download arrives as base64 that would have
to be retyped, with no checksum to catch a wrong byte (PLUG-114). If the user wants the original file,
they download it into `docs/external/` themselves; it is then an ordinary external file with its own
card and digest.

### Claude Artifacts

Run this when the user gives a `claude.ai/…/artifact/…` link to keep as reference material, or asks to
catalogue or refresh the project's artifacts. It is *Attaching — the procedure* with these changes.

1. **Find the tool.** The Artifact tool (read an artifact by link, list the user's artifacts), or for a
   Doc artifact the Claude Docs MCP. Neither available: say so and **write nothing**. In Claude Code the
   Artifact tool is off when a settings file has `"enableArtifact": false` (`/config` → Artifacts) or the
   session is not signed in to claude.ai.
2. **Read it.** An artifact someone else owns may come back as a summary plus the raw HTML saved to a
   file; read the HTML. A **bundled page** shows only a loader in the summary ("Unpacking…"): the card
   is written from the unpacked HTML, never from the loader. A large page: delegate the reading.
3. **Ask what `questions` prints**, as in step 3 there, and write `.source.md` with
   `provider: artifact` and no `remote-id`: artifacts are attached one by one.
4. **Write the card** `<name>.artifact.md` (`<name>` = the artifact's title in kebab-case), with
   `remote-id` (the id from the URL), `remote-url` and `remote-type` (`html`, `doc`, … as the tool says),
   then `remote.sh stamp <card> <last-updated>`. If the artifact has comment threads, add a
   `## Comments` line saying what they discuss; read them before answering from the artifact.
5. **Verify**, as in step 5 there.

**An artifact is never where a decision lives.** It is an intermediate document, a collaboration item or
an output, not documentation. When cataloguing or refreshing one, look for decisions or facts the
project relies on and extract them (*Extracting decisions*). The card then cites the artifact as
illustration or evidence, never stands in for the doc.

**The access key.** A share link may carry `sk=…`, which lets anyone holding the link open the
artifact. **Strip it**: `remote-url` and every link in the card are written without it. In a
`publish: local` folder (git-ignored) the card may keep the full link as `remote-key-url:`, so the
user's own sessions can open it. `check` fails with `REMOTE KEY` on a card holding a key anywhere
(frontmatter or body) outside such a folder, and never prints the key.

**Refreshing.** List the user's artifacts through the tool into a temp file outside the repo, one row
each: `id<TAB>title<TAB>type<TAB>last-updated`. Then `remote.sh diff <dir> <listing>`. Without a
container it compares only carded ids, so the hundreds of artifacts the project never used are not
`new`:
- `changed`: re-read the artifact, update the card, `remote.sh stamp` it with that time.
- `gone`: the listing may simply not show it (artifacts shared from another organisation can be
  missing). **Read it by its link first.** Readable: it is not gone; leave the card, or restamp it if
  its time differs. Not readable: `remote.sh gone <card>` and ask the user, as for a Drive file.

### Finding and reading remote material

- **Run `remote.sh list [root]`** when looking for reference material: it lists every remote card,
  local-only ones included (`card<TAB>publish<TAB>remote-modified<TAB>description<TAB>read-when<TAB>local-copy`), which
  `_index.md` never shows for a git-ignored folder.
- **Open Drive only when the card says the answer is there**, and only the part `## Where to look` names.
- **Compare `modifiedTime`.** When you open the file and Drive's `modifiedTime` is newer than the card's
  `remote-modified`, tell the user the card is out of date and offer to refresh it (re-read, rewrite
  the card, `remote.sh stamp`), as for a `changed` local file.
- **A local copy** (sixth field of `remote.sh list`) can be read without Drive. When you answer from it,
  say so and give its date: "from the local copy of 2026-11-11; Drive may be newer".
- **Drive not reachable** (no MCP, signed out, no access): say so. Never answer from the card as if
  you had read the file; the card says where to look, not what is there now.

### Writing to a remote file

Claude may change a file on Drive only where its folder's purpose allows it (*Folder purpose*). The
connectors differ in what they can do, and in how well they protect a teammate's change.

1. **Load the `google-workspace` skill** before the first call that creates or changes a Google file. It
   owns the *how* (Docs positions, Sheets value parsing, Slides layout, helper scripts); this file decides
   *whether* and *where*. Connector tools may be deferred: load them first.
2. **Read the file again, now**, and take its modified time from the provider.
3. **`remote.sh guard <card> <time>`**, and do what it says:
   - `READ-ONLY` (exit 3): no write. If the user wants one, the folder's purpose has to change first:
     propose that, never write around it.
   - `STALE` (exit 1): the file changed since the card was written. Tell the user, read what changed,
     and re-plan the edit against the current text. Never apply an edit planned on the old one.
   - `PROPOSE`: show the exact change and apply it only when the user approves (`writes: propose`, or a
     team or company folder, where `writes: free` still proposes).
   - `OK`: write, and say what you changed.
4. **Write, guarded by the connector where it can:**

   | File | Edit in place with | Guard against a teammate's change |
   |---|---|---|
   | Google Doc | Docs `update_doc` | `writeControl.requiredRevisionId` from the `read_doc` just done: a write after someone else's is **rejected**. Read again, re-plan, retry; never reuse the revision id a reply returns. `replaceAllText` matches text, so it cannot land at a stale position. |
   | Google Sheet | Sheets `update_values`, `append_values` | **none**: the same cell is last write wins, silently. Prefer `append_values` on a shared sheet, keep off a tab another session is editing, and run `guard` right before. |
   | Google Slides | Slides connector | **not tested yet**: treat it as unguarded, like a Sheet, until it is. |
   | Office file (`.docx`, `.xlsx`, `.pptx` …) | **nothing**: no connector edits one in place | see *Converting* below |

5. **Stamp the card** with the file's new modified time (`remote.sh stamp`), and update the card's text
   if what the file holds changed. A local copy, if any, is rewritten and `copy-stamp`ed too.

A write refused by the connector with *"requires additional permissions"* means the connector needs
reconnecting with full access (`/mcp` or the connector settings), not that the write is impossible.

**Converting an Office file.** To edit a `.docx` or `.xlsx` kept on Drive, ask the user to convert it to
Google format first; in a folder that allows writes, offer this by default whenever an edit is wanted.
Converting uploads the file again with conversion on: the result is a **new file with a new link**, and
complex formatting, macros and tracked changes may not survive. Then:
- `remote.sh repoint <card> <new-id> <new-url> <new-type> <time>`: the card takes the new id, link and
  type, records `converted-from:` the old id, and drops the Office extension from its name
  (`plan.docx.gdrive.md` becomes `plan.gdrive.md`); its local copy follows.
- **Ask what to do with the original.** Keep it unless the user says otherwise; trash cannot be undone
  through the connector. Tell teammates the link changed if the file was shared.

### Cards on Drive

With `cards-at: drive` (step 3 of attaching), an attachment's cards live **on Drive, in one Google Doc**
shared with the team, so every teammate's Claude reads the same map, and a project without git can keep
its whole docs set there. The doc holds the folder's `.source.md` files (so the purposes travel too) and
every card, each opened by a marker line `<!-- remote-docs: <path> -->`. Text before the first marker,
such as a title, is ignored. **Never edit or remove a marker line**, and never add a local copy to it:
copies are one user's offline text.

The local folder keeps only its `.source.md`, recording where the doc is:

```markdown
cards-at: drive
cards-id: 1XyZ…            # the Google Doc holding the cards
cards-url: https://docs.google.com/document/d/1XyZ…/edit
```

The scripts never talk to Drive, so the cards are worked on in a temp folder:

1. **Pull.** `read_doc` the cards doc (or read it as text) and **keep its `revisionId`**. Write the text
   to a temp file outside the repo, and `remote.sh unpack <file> <empty-temp-dir>`. It refuses a marker
   naming anything other than a `.source.md` or a card, or a path outside the folder, and then writes
   nothing.
2. **Work** in the temp folder exactly as on local cards: `check`, `diff`, `stamp`, `gone`, `guard`,
   `purpose`, editing a card's text.
3. **Push.** `remote.sh pack <temp-dir>` prints the doc's new text, in a fixed order. Replace the doc's
   whole body with it in one `update_doc`, guarded by `writeControl.requiredRevisionId` from step 1.
4. **Rejected** (someone wrote the cards in between): pull again, re-apply your change to the fresh
   cards, push again. Never push a set pulled before the rejection: that would silently overwrite a
   teammate's change. Unchanged after step 2 (`pack` output equals the pulled text): push nothing.

Creating the doc for a new attachment: write the cards in a temp folder, `pack` them, and create a Google
Doc in the attached Drive folder (or where the user says) with that text; record its id and URL as
above. With docs-manager installed, these cards are not in `_index.md` (they are not in the repo);
`remote.sh purposes` still names the attachment.

### Extracting decisions

Working material is never where a decision lives: a decision made in a draft, a meeting note or an
artifact is only safe once it is in the doc where decisions live. `check` asks for this:

```
EXTRACT?: docs/external/team/drafts.gdrive.md (changed since it was last reviewed for decisions: …)
```

It asks for **every artifact card**, and for every card in a folder that **declares** `truth: no` and is
not `reference` material (a `collaboration` or `output` folder, or a custom purpose saying `truth: no`).
An undeclared folder is not asked. It asks again whenever the file has changed since the last review,
because `stamp` moves `remote-modified` and never `extracted-at`.

1. **Read the file** (its current version) and look for decisions, and for facts the project relies on:
   a choice made, a scope cut, a date agreed, a number fixed.
2. **For each, find the doc it belongs to**: a `truth: yes` doc under the docs root, or in an attached
   `agreements` folder. Propose the exact text and where it goes, citing the source. Apply it only once
   the user approves; writing to an attached doc follows *Writing to a remote file*.
3. **Record it on the card**, in a section listing what was extracted and where:

   ```markdown
   ## Extracted

   - Launch moved to March → [roadmap](../../roadmap.md#launch)
   ```

   A decision the user declined is not listed. docs-manager, where installed, checks these links.
4. **`remote.sh extracted <card>`**, which records the card's current `remote-modified` as
   `extracted-at:`. Run it also when nothing was found: the review is what it records.
