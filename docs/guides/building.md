---
title: Building the guide PDFs
description: How docs/guides/<lang>/*.md become PDFs (Docker, Chromium, marked), and why an unchanged guide is never rewritten.
---

# Building the guide PDFs

Each guide is a Markdown file in `docs/guides/<lang>/`, with its PDF committed beside it. Edit the `.md`, never the PDF,
then rebuild:

```bash
bash docs/guides/build.sh     # no arguments: builds every docs/guides/*/*.md
```

It prints `built:` or `unchanged:` per guide.

## How it works

- Everything runs in Docker, in the image `mcr.microsoft.com/playwright:v1.57.0-jammy`, which carries Chromium and fonts
  with Cyrillic coverage (Liberation, FreeSans). The Playwright npm package itself is not used.
- `render.mjs` turns the Markdown into an HTML page styled by `guide.css`. The converter is `marked`, pinned in `build.sh`.
  It is installed from the npm registry on the first run into the Docker volume `claude-plugins-guides-npm`, and reused after that.
- Chromium prints the HTML to an A4 PDF (`--print-to-pdf`). The frontmatter is dropped, and its `title` becomes the PDF title.
- Images are referenced relative to the guide (`images/…`), and `render.mjs` sets the base URL for them.

## Unchanged guides are never rewritten

Chromium changes two things on every print even when the input is identical: `CreationDate`/`ModDate`, and the
`nodeNNNNNNNN` ids of the PDF's accessibility tags. `build.sh` compares the new PDF with the committed one after masking
both, so a rebuild with no changes leaves the file untouched and git sees no diff. The tags stay, because they serve screen readers.

## Layout notes

- Tables may split across pages, but never inside a row (`tr { break-inside: avoid }`). Keeping a whole table on one page
  left half-empty pages.
- An image with a border needs `box-sizing: border-box`, or it is clipped at the right margin.
- A screenshot not yet available is a blockquote: `> **[Знімок екрана: …]**`.
