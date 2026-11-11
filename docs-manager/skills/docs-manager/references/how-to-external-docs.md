# How to catalogue external docs

An **external file** is reference material the project did not write and never edits: a vendor
spec, a contract, a standard, a spreadsheet someone sent. Its extensions are fixed —
`pdf doc docx xls xlsx ppt pptx odt ods odp rtf epub`, any case.

Such a file is opaque to an agent: it cannot be grepped, it is expensive to read whole, and
nothing says when it matters. The **card** fixes that. It is an ordinary doc beside the file that
says what the file holds, when to open it, and **where inside it to look** — so a later session
opens pages 31–38 instead of a 200-page PDF.

## Layout

```
docs/
├── architecture/…              ← authored: we edit these
└── external/                   ← external: we replace these, never edit them
    ├── payments-spec.pdf       ← drop zone: just added, not yet filed
    ├── vendor-api/             ← one folder per topic
    │   ├── payments-spec-v3.pdf
    │   └── payments-spec-v3.pdf.md     ← its card
    └── finance/
        ├── budget-2026.xlsx
        └── budget-2026.xlsx.md
```

- **`<root>/external/` is a convention, not a setting.** Files land at its top level; cataloguing
  files each one into `external/<topic>/`.
- An external file found anywhere else under the docs root is still detected, and reported as
  `outside`. Offer to move it into `external/`; a user may keep it where it is — that is a
  choice, not a defect, and `check` does not fail on it.
- Authored docs **link out** to a card, never copy from the file:
  `see [payments spec, error codes pp. 31–38](../external/vendor-api/payments-spec-v3.pdf.md)`.
  A name with spaces or parentheses goes in angle brackets — `[spec](<Spec (v2) EN.docx.md>)` —
  or percent-encoded (`Spec%20%28v2%29%20EN.docx.md`); `links` accepts both, and `index` writes
  the angle-bracket form.
- A file the user placed in the project is committed as it is. Never gitignore, LFS-route or
  delete it, and never write anything but its card into the repo — extracted text and other
  scratch output go to a temp directory.

## The card

Named `<file>.md` — `payments-spec-v3.pdf.md`. **The name is the link to the file**; there is no
`source:` key to drift from it.

```markdown
---
title: Payments API spec v3 (Acme)
description: Acme's REST contract for payments — auth, endpoints, error codes, limits
read-when: changing payment flows, mapping Acme error codes, tuning retries
relates-to: [../../architecture/payments.md]
digest: sha256:9f2c…                    # written by `external stamp`, never by hand
---

# Payments API spec v3 (Acme)

[payments-spec-v3.pdf](payments-spec-v3.pdf) — 212 pages, Acme Corp, March 2026.

## Summary

Three to six sentences: what the document is, what it decides, what it is authoritative for.

## Where to look

| Topic | Location |
|---|---|
| OAuth client-credentials flow | pp. 4–9 |
| Error codes | pp. 31–38, table 7 |
| Rate limits | p. 40 |

## Key terms

- **Settlement window** — p. 12; ours is called *payout delay*.
```

| Field | Rule |
|---|---|
| `title`, `description` | As for every doc. `description` is what `_index.md` shows next to the file name, so it must say *what this file is for*, not "a PDF". |
| `read-when` | The situations that should send someone to this file. Write them as tasks, not topics. |
| `relates-to` | Authored docs that depend on this file, as paths **relative to the card**. Optional. |
| `digest` | Written only by `docs.sh external stamp`. Never edit it, never stamp without having reviewed the card against the file — that is what makes "changed" trustworthy. |

**`## Where to look` is the point of the card.** Locate by what the format has:

| Format | Location unit |
|---|---|
| pdf | page numbers (`pp. 31–38`), plus table/figure numbers where the document has them |
| docx, odt, rtf | heading path (`§4.2 Termination`) — page numbers move between viewers |
| xlsx, ods | sheet name + columns or range (`Q3!A1:F40`, sheet `Rates`, cols `region, rate`) |
| pptx, odp | slide numbers |

Every row must be something you actually found in the file. A plausible-looking location that is
wrong is worse than none: the next session trusts it and reads the wrong pages.

## Commands

```bash
bash <PLUGIN_ROOT>/scripts/docs.sh external status [root]   # one record per file: state, place, file, card
bash <PLUGIN_ROOT>/scripts/docs.sh external check  [root]   # NO CARD / UNSTAMPED / CHANGED / ORPHAN CARD / REMOTE INCOMPLETE / REMOTE GONE / LOCAL COPY …
bash <PLUGIN_ROOT>/scripts/docs.sh external stamp <file>    # record the reviewed digest
bash <PLUGIN_ROOT>/scripts/docs.sh external move <file> <dest-dir> [root]   # file + card together
bash <PLUGIN_ROOT>/scripts/docs.sh external related <file> [root]  # docs that depend on the file
bash <PLUGIN_ROOT>/scripts/docs.sh external outline <file>  # headings / sheets + header row / slide titles
bash <PLUGIN_ROOT>/scripts/docs.sh external text <file>     # paragraphs / rows as TSV / slide text
bash <PLUGIN_ROOT>/scripts/docs.sh index --write [root]     # lists cards under "External documents"
bash <PLUGIN_ROOT>/scripts/docs.sh external remote [root]   # every remote card, git-ignored ones too
bash <PLUGIN_ROOT>/scripts/docs.sh external remote-stamp <card> <time>   # record the provider's modifiedTime
bash <PLUGIN_ROOT>/scripts/docs.sh external remote-diff <dir> <listing.tsv>   # Drive folder listing vs its cards: new / changed / gone
bash <PLUGIN_ROOT>/scripts/docs.sh external remote-gone <card>   # mark a card whose file left Drive (never deletes)
bash <PLUGIN_ROOT>/scripts/docs.sh external copy-stamp <card> <time>   # record the Drive version a local copy was written from
```

`status` emits `state<TAB>place<TAB>file<TAB>card`, with `-` for an empty field.
`state` is `ok | new | unstamped | changed | orphan | remote | incomplete | gone | copy | copy-stale |
copy-unstamped | copy-unasked | copy-orphan`; `place` is `filed | unfiled | outside`. `remote`,
`incomplete` and `gone` are remote cards (see *Remote documents* below), whose `file` is always `-`;
the `copy…` states are their local copies, whose `file` is the copy.
`docs.sh check` runs `external check` with everything else; under each `CHANGED` file it prints a
`REVIEW:` line per dependent doc.

`related` emits `relates-to<TAB>doc` (named in the card's `relates-to:`) and `links<TAB>doc` (links
to the card or the file), each doc once. Generated `_index.md` listings are not dependants.

`outline` emits `heading<TAB>level<TAB>text` for a docx or odt,
`sheet<TAB>name<TAB>range<TAB>A:header | B:header …` for an xlsx or ods, and
`slide<TAB>number<TAB>title` (`-` for a slide with no title) for a pptx or odp. `text` emits a
document as one paragraph per line with headings as markdown `#`, a workbook as
`## <sheet> (<range>)` followed by `row<TAB>A<TAB>B…`, and a deck as `## Slide <n>: <title>`
followed by the slide's other text. Any other file — or no `unzip`, or a package that will not open — gives the
single record `none<TAB>reason` and exit 0: it is the fallback, not an error.

### What `outline` and `text` miss

The reader is a small unzip + awk program, tested on minimal hand-made files. Real Office files
carry things it does not interpret:

| In the file | What the output shows |
|---|---|
| A text box or shape with text (Word stores it twice, new and legacy form) | its text twice, run into the paragraph it is anchored to |
| Auto-numbered headings or lists (the number lives in `numbering.xml`) | `Scope`, not `4.2 Scope`; list items without their numbers |
| A custom heading style that only inherits from *Heading N* (`basedOn`) | an ordinary paragraph: missing from `outline`, no `#` in `text` |
| A numeric character reference (`&#10;`, `&#x2014;`) | the reference as written, not the character |
| A table in a docx or odt | one line per cell, the table shape lost |
| Headers, footers, footnotes, comments, speaker notes | nothing: only the document body and the slides are read |
| A date or formatted number in an xlsx | the stored value: `45231` for a date, `0.25` for 25 % (an ods shows the displayed text) |
| A slide title that is not in the title placeholder (a plain text box) | the slide as untitled (`-`), the title among its text |

**When one of these touches the work, tell the user.** Name the construct and what it does to the
output — "the headings in this spec are auto-numbered, so the outline shows *Scope* where the file
says *4.2 Scope*" — so they know why the result looks off and that it is the reader, not the file.
Then offer the way around it: a **PDF export** (read natively, with page numbers, and best for a
card's `Where to look`), or reading the file with Claude's built-in document skill when one is
available. Never cite a location the output did not show; a section number the reader dropped is
not one you can add from memory.

## Cataloguing — the procedure

Run this when the user adds reference files, asks to catalogue or ingest them, or `check` reports
`NO CARD`, `UNSTAMPED` or `CHANGED`.

1. **Get the work list.** `external status`. Every `new`, `unstamped` and `changed` record is a
   card to write or review; every `unfiled` or `outside` place is a move to propose. `orphan` means
   a file was removed or renamed — find out which before deleting its card, since a rename should
   carry the card along (`external move` does that).

2. **Read the file — only as much as the card needs.**
   - **pdf:** read it natively in page ranges (at most 20 pages per read). Start with the first few
     pages and any table of contents, then read the sections the contents point at. Record page
     numbers *as you read them*; do not reconstruct them afterwards.
   - **docx, xlsx, pptx, odt, ods, odp:** `external outline <file>` first — it is small and gives
     the location units directly: the heading path for a document, the sheet name, range and
     header columns for a workbook, the slide numbers and titles for a deck.
     Then `external text <file> > <tmpdir>/<name>.txt` and read that in parts for the summary; a
     big workbook's rows do not belong in context, so for a workbook the outline is often enough.
     Every `Where to look` row still has to be something the output actually showed. If the output
     hits one of the limits in *What `outline` and `text` miss*, say so to the user, as that section
     describes.
   - **Anything else** — doc, xls, ppt, rtf, epub — or `outline` answering `none`: if the user can
     give a PDF export or a short description, use it. Converting the file in a container (e.g.
     LibreOffice headless) is an option **only with the user's explicit approval** — never install
     anything. Otherwise write a minimal card — `title`, `description`, `read-when` from what the
     user says, `## Where to look` holding the single row `| (not yet read) | — |` — and **leave it
     unstamped**, so `check` keeps reporting it rather than vouching for a card nobody checked.
   - A large file (more than ~50 pages, or several files at once): delegate the reading to a
     sub-agent that returns the drafted card, so the file's content never fills this context.
   - Scratch output — extracted text, notes — goes to a temp directory, never into the repo.

3. **Write the card** in the format above. For a `changed` file, re-check **every** `Where to look`
   row against the new version, not only the parts that look different — page numbers move when
   anything earlier changes. Say in your reply what changed in substance, then refresh the docs
   that depend on it — see *Refreshing docs from a changed source* below.

4. **Propose placement** for each `unfiled` and `outside` file, as one list the user approves:

   ```
   external/payments-spec.pdf    → external/vendor-api/      (joins payments-spec-v2.pdf)
   arch/rates.xlsx               → external/finance/         (new topic folder)
   ```

   Reuse an existing topic folder before inventing one. Placement is a proposal, never silent.
   On approval run `external move <file> <dest-dir> [root]` per file. It moves the card with the
   file, refuses to overwrite, and prints every link the move broke — fix those links in the
   authored docs that hold them, and say which you fixed.

5. **Stamp** each card once it has been checked against the file: `external stamp <file>`. Stamping
   is the statement "this card is true of this exact file". Never stamp to silence `check`.

6. **Index and verify.** `index --write`; a new topic folder's `_index.md` is created with
   `description: TODO` — fill it in and run `index --write` again. Then `docs.sh check` must be clean.

7. **Then offer, do not do:** authored docs the new material affects. Name them and what would
   change; link them to the card (`relates-to:` on the card, a link in the doc) once the user agrees.

Never gitignore, LFS-route, rename or delete a file the user placed. The plugin writes cards only.
(The one `.gitignore` entry it ever adds is a local-only Drive folder of its own cards, on the user's
answer; see *Remote documents*.)

## Refreshing docs from a changed source

A changed file can make an authored doc wrong without any link breaking: the doc still points at
"pp. 31–38", which now hold something else. `check` lists those docs as `REVIEW:` lines under the
`CHANGED` file; `external related <file>` gives the same list on its own.

1. **Re-card first** (step 3 above), so you know what changed and the card's locations are current.
2. **For each doc listed, find what it takes from the source** — every link to the card or the
   file, and every claim beside one. Compare each against the new version.
3. **Propose concrete edits, one doc at a time, and apply each only once the user approves it.**
   Show the sentence as it is and as it would be. A doc that is still right needs no edit — say so.
4. **Cite, do not copy.** A fixed doc points at the card with the new location
   (`[payments spec v3, p. 36](../external/vendor-api/payments-spec-v3.pdf.md)`); it never pastes
   the source's text, which would be a second copy to go stale next time.
5. A doc that depends on the source but was not listed means a missing `relates-to:` entry — offer
   to add it to the card. Then stamp, and `docs.sh check` must be clean.

## Remote documents (Google Drive)

A **remote card** describes a file that stays on Google Drive, with no copy in the repo. It is a
card like any other (same sections, same rules for `## Where to look`), so Claude can tell from the
card whether the file matters and opens Drive only when it does. Only Claude talks to Drive, through
a Drive MCP server; no command here makes a network call.

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
- **`remote-modified` is written only by `external remote-stamp <card> <time>`**, with the
  `modifiedTime` Drive reported for the version the card was written from. Never edit it by hand.
  `check` fails on a remote card without `remote-id` or `remote-modified` (`REMOTE INCOMPLETE`).
- **The card body** opens with the link and where the file lives:
  `[payments-spec-v3.pdf](<remote-url>) — on Google Drive, 212 pages; readable only with access to that Drive.`
- **`.source.md`**, one per folder, holds the answers that apply to every Drive attachment in it:

  ```markdown
  ---
  provider: gdrive
  content: remote        # the file stays on Drive
  processed: none
  publish: commit        # or local: the folder is git-ignored (see step 3)
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
   as text; read only as much as the card needs, as in *Cataloguing* step 2. For a large file,
   delegate the reading to a sub-agent that returns the drafted card.
3. **Ask about publishing, once per folder.** If the folder has no `.source.md` yet, look at
   `git remote -v`. With a public remote (or one you cannot tell), ask before writing anything: a
   card's summary of a private file *is* private content, and its URL names the file. Offer two
   answers: **commit** the cards, or keep the folder **local-only** (git-ignored, so it never reaches the
   remote). Record the answer as `publish:` in a new `.source.md`; for `local`, add the folder to
   `.gitignore`, which is part of what the user chose. Never ask again for that folder.
4. **Write the card** in the folder the user chose (propose `external/<topic>/` as for any external),
   in the format above, then `external remote-stamp <card> <modifiedTime>`.
5. **Index and verify.** `index --write` (a local-only folder is not indexed: that is the point), then
   `docs.sh check` must be clean.

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

Ask the publish question as in step 3 above, write `.source.md`, then run **Refreshing** below: on a
new attachment every file is `new`.

### Refreshing a Drive folder

Run this when the user asks to refresh the Drive docs, or the first time in a session that an attached
folder's material is used.

1. **List the folder through the MCP** into a temp file outside the repo, never into it: every page of
   results, and every sub-folder when `recursive` is not `false`. One row per Drive item, tab-separated:
   `id<TAB>path<TAB>mimeType<TAB>modifiedTime`, where `path` is relative to the attached folder
   (`specs/payments-spec.pdf`). Take `modifiedTime` as Drive reports it; never reformat it.
2. **`external remote-diff <dir> <listing>`** compares it with the attachment's cards, matching by Drive
   id, so a renamed or moved file is not gone + new. It skips folders and out-of-scope rows, and rejects
   a malformed listing by line number. Nothing printed means in sync.
3. **Act on each record:**
   - `new<TAB>id<TAB>path<TAB>mime<TAB>time`: read the file, write its card at the mirrored path, then
     `remote-stamp <card> <time>`. **More than 20 new files: ask first**, saying how many; above a few,
     delegate the reading to sub-agents that return drafted cards.
   - `changed<TAB>id<TAB>card<TAB>time`: re-read the file, update the card (rename or move it when the
     Drive title or folder changed), then `remote-stamp <card> <time>` with **that** time. If the card has
     a local copy, rewrite it too (*Keeping a local copy*) and `copy-stamp <card> <time>`.
   - `gone<TAB>id<TAB>card`: the file was deleted, moved out of the folder or out of scope.
     `external remote-gone <card>`, then ask the user whether to delete the card. Never delete it on
     your own: `check` fails with `REMOTE GONE` until the user decides, and if the file comes back, it
     shows up as `changed` and stamping it clears the mark.
4. **Index and verify:** `index --write`, then `docs.sh check` must be clean, apart from `REMOTE GONE`
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
public remote, say plainly that `commit` publishes the files' contents.

Writing a copy:

1. **Read the file's text rendering** through the MCP (the call that returns a file's content as text,
   not the base64 download). Above about 200 KB of text, ask first.
2. **Write it verbatim** to `<name>.gdrive.local.md`: never summarise, reorder or fix it; it is a copy,
   and the card is where judgement goes. No frontmatter: the stamp lives in the card.
3. **`external copy-stamp <card> <modifiedTime>`**, the same time the card was stamped with. It refuses
   when `.source.md` does not say `processed: local`, or the copy is missing. With `copy-publish:
   commit`, link the copy from the card body: `Local copy: [<name>.gdrive.local.md](<name>.gdrive.local.md)
   (may be behind Drive).` With `local`, **do not link it**: the copy is git-ignored, so the link would
   be broken in every other clone. `external remote` names it either way.

`check` reports `LOCAL COPY STALE` when the card was restamped and the copy was not,
`UNSTAMPED`, `NOT AGREED` for a copy in a folder that never allowed one (ask, or delete it), and
`ORPHAN` for a copy without its card. A git-ignored copy is checked all the same.

**Binary files are never copied through the MCP.** A Drive download arrives as base64 that would have
to be retyped, with no checksum to catch a wrong byte (PLUG-114). If the user wants the original file,
they download it into `docs/external/` themselves; it is then an ordinary external file with its own
card and digest.

### Finding and reading remote material

- **Run `external remote [root]`** when looking for reference material: it lists every remote card,
  local-only ones included (`card<TAB>publish<TAB>remote-modified<TAB>description<TAB>read-when<TAB>local-copy`), which
  `_index.md` never shows for a git-ignored folder.
- **Open Drive only when the card says the answer is there**, and only the part `## Where to look` names.
- **Compare `modifiedTime`.** When you open the file and Drive's `modifiedTime` is newer than the card's
  `remote-modified`, tell the user the card is out of date and offer to refresh it (re-read, rewrite
  the card, `remote-stamp`), as for a `changed` local file.
- **A local copy** (sixth field of `external remote`) can be read without Drive. When you answer from it,
  say so and give its date: "from the local copy of 2026-11-11; Drive may be newer".
- **Drive not reachable** (no MCP, signed out, no access): say so. Never answer from the card as if
  you had read the file; the card says where to look, not what is there now.

## Answering from an external file

Read the card first. Its `read-when` says whether the file is relevant at all; its
`## Where to look` says which pages, headings or sheets to open. Open only those, and cite the
location in the answer (`payments spec v3, p. 34`). If the card has no row for the question, read
more of the file — and add the row you found, so the next session does not repeat
the search.
