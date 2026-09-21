---
name: docs-manager
description: Use when creating or maintaining a markdown documentation set treated as a product — per-folder _index.md navigation, broken cross-doc link checks, the docs-as-product conventions (frontmatter, single source of truth, DRY via cross-links), and diagrams that live in text sources beside the docs they illustrate. Activate on "update the docs index", "regenerate _index.md", "check doc links", "are the docs consistent", or after adding/moving/removing docs. Also activate for diagrams in docs — "add a diagram to this doc", "draw the auth flow", "explain this with a picture", "update the diagram", "is the diagram still accurate", "bless the diagram" — and whenever a doc would be clearer as a picture than as prose. Also activate for rendering a diagram to a standalone image — "render the diagram", "export the diagram as SVG/PNG/HTML", "interactive diagram page", "why is nothing rendered", ".docs-manager-render", "set up a diagram renderer". Also activate for entity-relationship diagrams specifically — "draw an ERD", "erDiagram", "diagram the data model", "diagram the schema", "picture of these entities/tables/types and how they relate", "is this ERD still right" — and before drawing or changing any ERD, whether it depicts tables, interfaces, structs or JSON schemas. Also activate for the project's agent instruction file — "optimise CLAUDE.md", "CLAUDE.md is too long", "clean up AGENTS.md", "move this out of CLAUDE.md", "should this go in CLAUDE.md or the docs", "where does this rule belong" — and before adding anything to such a file.
version: 1.5.0
---

# Docs Manager

Maintain a markdown documentation set as a **product**: navigable, consistent, DRY, and always
reflecting the project's *current* state. Provides a runtime-free shell tool plus the conventions
that make it work.

## Conventions (docs-as-product)

- **Docs reflect the ACTUAL current state**, not history. Historical context (changelogs, "we used
  to…", rejected options, decisions) belongs in task/issue files, not in `docs/`. Link to them if needed.
- **Change → update docs in the same change.** Stale docs are a defect.
- **Consistency on every edit.** When you change a doc, review related docs (follow `_index.md` and
  cross-links) and reconcile anything that no longer agrees. The edit isn't done until they agree.
- **DRY — define once, link everywhere.** Each fact/term/decision has one canonical home; everywhere
  else cross-links to it. Cross-links + shared terms are the "variables."
- **Single glossary** of canonical terms; use them verbatim, no synonyms.

## Required structure

- **Frontmatter on every doc and `_index.md`:**
  ```yaml
  ---
  title: Short title
  description: One line — harvested into the parent _index.md listing.
  ---
  ```
- **Every folder and sub-folder has an `_index.md`.** It carries a generated `AUTO-INDEX` block that
  lists the folder's sub-folders (name + description) and docs (filename + description). Prose you
  write outside the markers is preserved; only the block between the markers is regenerated.

## Tool

Runtime-free (`bash` + `awk` only; safe to run in restricted/Docker setups). Default root is `docs`.

```bash
# Regenerate every _index.md AUTO-INDEX block (creates missing _index.md as needed)
bash <PLUGIN_ROOT>/scripts/docs.sh index --write [root]

# Verify indexes are current without writing (CI / pre-commit) — non-zero exit on drift
bash <PLUGIN_ROOT>/scripts/docs.sh index --check [root]

# Report broken relative markdown links — non-zero exit if any
bash <PLUGIN_ROOT>/scripts/docs.sh links [root]

# Diagrams — regenerate the AUTO-DIAGRAM block in every doc carrying a marker
bash <PLUGIN_ROOT>/scripts/docs.sh diagram index --write [root]
bash <PLUGIN_ROOT>/scripts/docs.sh diagram index --check [root]

# Diagrams — report ones whose watched files changed, and record a review
bash <PLUGIN_ROOT>/scripts/docs.sh diagram check [root]
bash <PLUGIN_ROOT>/scripts/docs.sh diagram bless <name> [root]

# Diagrams — run the project's own render script, if it has one
bash <PLUGIN_ROOT>/scripts/docs.sh diagram render [root]

# index --check + diagram index --check + diagram check + links combined
bash <PLUGIN_ROOT>/scripts/docs.sh check [root]
```

Notes:
- `index` processes folders **deepest-first**, so a parent index picks up freshly-written child
  descriptions in a single pass. Run is **idempotent** — re-running makes no further changes.
- Newly created `_index.md` files get a `description: TODO` placeholder — fill it in, then re-run so
  the parent listing updates.
- The tool is mechanical (no LLM tokens). For *semantic* consistency review across many docs, read
  via the `_index.md` tree and delegate bulk reading to a sub-agent so file dumps stay out of context.

## Diagrams

When prose is doing a picture's job — a flow, a state machine, a set of components and their
relationships — put a diagram in the doc. It lives in its own **source** file next to the doc:
`<name>.diagram.md`, frontmatter plus **exactly one** fenced code block. The doc opts in with a
marker where the picture should appear:

```markdown
<!-- DIAGRAM:auth-flow.diagram.md -->
```

Then `docs.sh diagram index --write` splices the fence in below it, between `AUTO-DIAGRAM` markers.

**Nothing is rendered and nothing is installed.** A fenced block is already drawn by the viewer
(GitHub, VS Code, JetBrains, Obsidian), so the fence is copied verbatim and never parsed — the
language tag is the author's choice, and `mermaid`, `d2`, `dot` and `plantuml` all behave
identically. Prefer `mermaid`: it has the widest free viewer support.

A standalone artifact (`.svg`/`.png`/`.pdf`/`.webp`/`.html`) is optional and comes from a render script the
**project** supplies at `<root>/.docs-manager-render`. Its absence is a supported state, not a
fault to diagnose — so "nothing is rendered" is never on its own a problem to fix.

**So: read [`references/how-to-render.md`](references/how-to-render.md) in full before setting up,
changing or diagnosing a render script**, and work from that file. This paragraph deliberately
states no part of the contract, so there is nothing here to hand-write a script from.

Two optional frontmatter keys make a diagram pull its weight:

```yaml
---
title: Auth flow
refs:                                       # what the picture points at
  api:   file:../src/api/gateway.ts "API gateway"
  store: term:./glossary.md#refresh-token
watch: [../src/auth/]                       # what the picture depicts
stamp: 4272921961                           # written by `bless`, never by hand
---
```

- **`refs:`** become a `**References**` caption of real links below the fence, validated by
  `docs.sh links`. Paths are relative to the *source*; each embedding doc gets its own href.
- **`watch:`** makes the diagram flag itself as *suspect* when what it depicts changes. `diagram
  check` reports it and every embedding doc grows a notice; `diagram bless <name>` records a review.
  **`bless` is the only thing that writes `stamp:`** — never edit it, and never re-stamp to silence
  a warning without actually checking the diagram.

**When you edit code a diagram watches**, a hook says so. Treat that as a real task: open the
diagram, check it still describes reality, fix it if not, then bless it. Regenerating without
looking is how a diagram becomes a lie the docs vouch for.

Use the canonical terms verbatim when talking about this: *diagram source*, *fence*, *embed*,
*generated block*, *ref*, *stamp*, *stale*.

### ERDs

An **ERD** (`erDiagram`) is the form for *what a model is made of* — tables, interfaces, structs or
JSON schemas alike. Its rules are non-obvious, every one of them costs a rewrite when missed, and
**none of them is checkable by any command here**: a wrong ERD passes `diagram index --check`,
`links` and `check` while telling the reader something false.

**So: read [`references/how-to-erd.md`](references/how-to-erd.md) in full before drawing or changing
an ERD**, and work from that file — not from a recollection of it, and not from this paragraph, which
deliberately lists no rules so there is nothing here to work from. It ends in a checklist; run the
checklist before `diagram bless`, and `bless` before `diagram index --write`.

Reading it is not optional for "a quick one" — a small ERD breaks the same rules as a large one, and
a shipped picture is what the docs then vouch for.

## The agent instruction file

A project's `CLAUDE.md` (or `AGENTS.md`, `.cursorrules`, a repo-level system prompt) is read in full
before every task, so everything anyone learns is tempting to put there. That is why it ends up holding
the project's knowledge — system descriptions, module names, invariants — which is **this docs set's job**,
stated once, in the doc that owns the subject, where the user and contributors can read it too.

Nothing here can detect that: a thousand-line instruction file duplicating the docs passes `index`,
`links` and `check`, and the duplicate is the copy that drifts.

**So: read [`references/how-to-claude-md.md`](references/how-to-claude-md.md) in full before optimising
such a file, before moving anything out of one, and before deciding that a newly-learned rule belongs in
one.** Work from that file — not from a recollection of it, and not from this section, which deliberately
states no rules so there is nothing here to work from. It ends in a checklist; run it before calling the
job done.

The same reading applies to the small case — *"where does this one rule go?"* — because the small case
repeated is exactly how the large one is built.

## Workflow integration (optional)

Projects using a task workflow benefit from two steps:
- **context** (first step of every task) — walk the `_index.md` tree, read related docs and the
  diagrams they embed, and record what was found *in the task file* (a `## Context` section), so a
  resumed session reads that instead of exploring the repo again. Reading a diagram counts: if it
  turns out to be wrong, that is a finding, not a detour.
- **publish/review** (docs work) — run `docs.sh index --write`, `docs.sh links` and `docs.sh check`,
  and reconcile related docs for consistency before completing.

Two ways the task workflow and diagrams are coupled, both easy to miss:
- **A diagram marker naming a task id cannot be written before that id exists.** When a review raises
  a question about a row, create the task in the same breath — otherwise the row reads as settled and
  the finding is lost. See rule 3 of the ERD how-to.
- **Editing a watched file mid-task is diagram work**, not a separate ticket: review, fix, `bless`.
