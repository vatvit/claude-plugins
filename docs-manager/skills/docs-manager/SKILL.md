---
name: docs-manager
description: Use when creating or maintaining a markdown documentation set treated as a product — generating/validating per-folder _index.md navigation, checking broken cross-doc links, or applying the docs-as-product conventions (frontmatter, single source of truth, DRY via cross-links). Activate on "update the docs index", "regenerate _index.md", "check doc links", "are the docs consistent", or after adding/moving/removing docs.
version: 1.0.0
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

# index --check + links combined
bash <PLUGIN_ROOT>/scripts/docs.sh check [root]
```

Notes:
- `index` processes folders **deepest-first**, so a parent index picks up freshly-written child
  descriptions in a single pass. Run is **idempotent** — re-running makes no further changes.
- Newly created `_index.md` files get a `description: TODO` placeholder — fill it in, then re-run so
  the parent listing updates.
- The tool is mechanical (no LLM tokens). For *semantic* consistency review across many docs, read
  via the `_index.md` tree and delegate bulk reading to a sub-agent so file dumps stay out of context.

## Workflow integration (optional)

Projects using a task workflow benefit from two steps:
- **context** (first step of every task) — walk the `_index.md` tree, read related docs, record what
  was found before doing the work.
- **publish/review** (docs work) — run `docs.sh index --write` and `docs.sh links`, and reconcile
  related docs for consistency before completing.
