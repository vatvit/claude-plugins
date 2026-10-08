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
bash <PLUGIN_ROOT>/scripts/docs.sh external check  [root]   # NO CARD / UNSTAMPED / CHANGED / ORPHAN CARD
bash <PLUGIN_ROOT>/scripts/docs.sh external stamp <file>    # record the reviewed digest
bash <PLUGIN_ROOT>/scripts/docs.sh external move <file> <dest-dir> [root]   # file + card together
bash <PLUGIN_ROOT>/scripts/docs.sh external related <file> [root]  # docs that depend on the file
bash <PLUGIN_ROOT>/scripts/docs.sh external outline <file>  # docx headings / xlsx sheets + header row
bash <PLUGIN_ROOT>/scripts/docs.sh external text <file>     # docx paragraphs / xlsx rows as TSV
bash <PLUGIN_ROOT>/scripts/docs.sh index --write [root]     # lists cards under "External documents"
```

`status` emits `state<TAB>place<TAB>file<TAB>card`, with `-` for an empty field.
`state` is `ok | new | unstamped | changed | orphan`; `place` is `filed | unfiled | outside`.
`docs.sh check` runs `external check` with everything else; under each `CHANGED` file it prints a
`REVIEW:` line per dependent doc.

`related` emits `relates-to<TAB>doc` (named in the card's `relates-to:`) and `links<TAB>doc` (links
to the card or the file), each doc once. Generated `_index.md` listings are not dependants.

`outline` emits `heading<TAB>level<TAB>text` for a docx and
`sheet<TAB>name<TAB>range<TAB>A:header | B:header …` for an xlsx. `text` emits a docx as one
paragraph per line with headings as markdown `#`, and an xlsx as `## <sheet> (<range>)` followed by
`row<TAB>A<TAB>B…`. Any other file — or no `unzip`, or a package that will not open — gives the
single record `none<TAB>reason` and exit 0: it is the fallback, not an error.

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
   - **docx, xlsx:** `external outline <file>` first — it is small and gives the location units
     directly: the heading path for a docx, the sheet name, range and header columns for an xlsx.
     Then `external text <file> > <tmpdir>/<name>.txt` and read that in parts for the summary; a
     big workbook's rows do not belong in context, so for an xlsx the outline is often enough.
     Every `Where to look` row still has to be something the output actually showed.
   - **Anything else** — pptx, doc, xls, odt, … — or `outline` answering `none`: if the user can
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

## Answering from an external file

Read the card first. Its `read-when` says whether the file is relevant at all; its
`## Where to look` says which pages, headings or sheets to open. Open only those, and cite the
location in the answer (`payments spec v3, p. 34`). If the card has no row for the question, read
more of the file — and add the row you found, so the next session does not repeat
the search.
