# docs-manager

Treat your markdown documentation as a **product**: auto-generated navigation, link checking, and a
small set of conventions that keep docs DRY and always reflecting the current state.

## What it gives you

- **`_index.md` navigation tree** — every folder gets an auto-generated index of its sub-folders and
  docs (with one-line descriptions harvested from frontmatter).
- **Link checking** — finds broken relative cross-doc links.
- **Conventions** — docs reflect current state (history lives in tasks), single source of truth,
  cross-link instead of duplicate, frontmatter on every doc.

Runtime-free: the tool uses only `bash` + `awk`, so it runs anywhere (including restricted/Docker
environments where no language runtime is allowed).

## Usage

```bash
# Regenerate all _index.md files (default root: ./docs)
bash scripts/docs.sh index --write

# Verify only (CI / pre-commit) — non-zero exit on drift
bash scripts/docs.sh index --check

# Report broken relative links
bash scripts/docs.sh links

# Both checks
bash scripts/docs.sh check
```

Pass a different root as the last argument, e.g. `bash scripts/docs.sh check documentation`.

## Doc frontmatter

```yaml
---
title: Short title
description: One line — shown in the parent _index.md listing.
---
```

## Install

```shell
/plugin marketplace add vatvit/claude-plugins
/plugin install docs-manager@vatvit-plugins
```

When installed, invoke the tool as `bash <PLUGIN_ROOT>/scripts/docs.sh …` (the skill resolves the path).

## License

MIT
