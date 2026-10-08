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
bash <PLUGIN_ROOT>/scripts/docs.sh index --write [root]     # lists cards under "External documents"
```

`status` emits `state<TAB>place<TAB>file<TAB>card`, with `-` for an empty field.
`state` is `ok | new | unstamped | changed | orphan`; `place` is `filed | unfiled | outside`.
`docs.sh check` runs `external check` with everything else.

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
   - **docx, xlsx, pptx and the other formats** cannot be read natively. If the user can give a PDF
     export or a short description, use it. Otherwise write a minimal card — `title`,
     `description`, `read-when` from what the user says, `## Where to look` holding the single row
     `| (not yet read) | — |` — and **leave it unstamped**, so `check` keeps reporting it rather
     than vouching for a card nobody checked.
   - A large file (more than ~50 pages, or several files at once): delegate the reading to a
     sub-agent that returns the drafted card, so the file's content never fills this context.
   - Scratch output — extracted text, notes — goes to a temp directory, never into the repo.

3. **Write the card** in the format above. For a `changed` file, re-check **every** `Where to look`
   row against the new version, not only the parts that look different — page numbers move when
   anything earlier changes. Say in your reply what changed in substance.

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

## Answering from an external file

Read the card first. Its `read-when` says whether the file is relevant at all; its
`## Where to look` says which pages, headings or sheets to open. Open only those, and cite the
location in the answer (`payments spec v3, p. 34`). If the card has no row for the question, read
more of the file — and add the row you found, so the next session does not repeat
the search.
