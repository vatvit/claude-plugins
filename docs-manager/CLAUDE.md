# CLAUDE.md — docs-manager plugin

Guidance for working on this plugin.

## What it is

A documentation-maintenance plugin: a runtime-free shell tool (`scripts/docs.sh`) plus a skill
(`skills/docs-manager/`) that encodes the docs-as-product conventions.

## Layout

```
docs-manager/
├── .claude-plugin/plugin.json   ← plugin manifest
├── scripts/docs.sh              ← the tool (bash + awk only, no language runtime)
├── skills/docs-manager/SKILL.md ← when-to-use + commands + conventions
├── README.md
└── CLAUDE.md                    ← this file
```

## scripts/docs.sh

Subcommands: `index [--write|--check]`, `links`, `check`. Default root `docs`.

Key behaviors (don't regress these):
- **Deepest-first** directory processing so a parent `_index.md` reads freshly-written child
  descriptions in a single pass.
- **Idempotent** — re-running `index --write` produces no further changes.
- Only the content between the `AUTO-INDEX:START` / `AUTO-INDEX:END` markers is regenerated; prose
  outside the markers is preserved.
- The generated block is passed to `awk` via a **temp file read with `getline`**, never `awk -v`
  (which cannot carry newlines — doing so reintroduces the "newline in string" bug).
- No GNU-only flags — must work with macOS/BSD `find`/`grep`/`sed` and bash 3.2.

## Testing

No host runtime needed. Build a throwaway docs fixture in a temp dir and assert:
1. `index --write` creates `_index.md` per folder with frontmatter descriptions harvested.
2. A second `index --write` is a no-op (idempotent).
3. `links` flags a deliberately broken relative link and exits non-zero.
4. `index --check` exits non-zero when a description changes but the index isn't regenerated.
