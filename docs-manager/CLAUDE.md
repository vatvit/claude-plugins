# CLAUDE.md — docs-manager plugin

Guidance for working on this plugin.

## What it is

A documentation-maintenance plugin: a runtime-free shell tool (`scripts/docs.sh`) plus a skill
(`skills/docs-manager/`) that encodes the docs-as-product conventions.

## Layout

```
docs-manager/
├── .claude-plugin/plugin.json   ← plugin manifest
├── scripts/
│   ├── lib.sh                   ← shared helpers, sourced by the others
│   ├── docs.sh                  ← CLI front-end: index / links / diagram / check
│   ├── diagram.sh               ← diagram sources → generated blocks
│   └── test/diagram.test.sh     ← the suite (no framework, no dependencies)
├── skills/docs-manager/SKILL.md ← when-to-use + commands + conventions
├── README.md
└── CLAUDE.md                    ← this file
```

**`lib.sh` is this plugin's, not the repo's.** Plugins must work standalone and in any
combination, so nothing here may source another plugin's file and nothing here may be shared
across plugins. DRY applies *within* a plugin — two plugins each carrying a small helper is
correct, not debt.

## scripts/lib.sh

Sourced, never executed. Holds what more than one script in *this* plugin needs:

- `fm_parse <file>` — one awk pass over frontmatter, emitting tab-separated typed records
  (`scalar|list|map<TAB>key<TAB>…`) in author order. `fm_field`, `fm_list` and `fm_map` are thin
  wrappers over it — **do not add a second frontmatter reader.**
- `normalize_path`, `block_rewrite`, `has_marker`, `write_if_changed`.

A map is never held in bash: awk emits records, the shell reads them with
`while IFS=$'\t' read -r`. That is what keeps this working on bash 3.2, which has no
associative arrays.

## scripts/docs.sh

Subcommands: `index [--write|--check]`, `links`, `diagram index [--write|--check]`, `check`.
Default root `docs`.

Key behaviors (don't regress these):
- **Deepest-first** directory processing so a parent `_index.md` reads freshly-written child
  descriptions in a single pass.
- **Idempotent** — re-running `index --write` produces no further changes.
- Only the content between the `AUTO-INDEX:START` / `AUTO-INDEX:END` markers is regenerated; prose
  outside the markers is preserved.
- The generated block is passed to `awk` via a **temp file read with `getline`**, never `awk -v`
  (which cannot carry newlines — doing so reintroduces the "newline in string" bug).
- No GNU-only flags — must work with macOS/BSD `find`/`grep`/`sed` and bash 3.2.

## scripts/diagram.sh

A diagram source is `<name>.diagram.md`: frontmatter plus **exactly one** fenced block. A doc opts
in with `<!-- DIAGRAM:<name>.diagram.md -->`, which is the single declaration of the link and
carries position with it.

Key behaviors (don't regress these):
- **The fence is copied verbatim and never parsed.** The language tag is the author's choice and
  changes nothing. Rendering is the viewer's job — this plugin has no renderer and no dependency,
  and must never acquire one.
- Zero fences, two fences, or a missing language tag is an error naming the file.
- A marker pointing at a missing source reports and leaves any existing block **untouched**.
- `list_docs` excludes `*.diagram.md` — sources are input to a generated block, not documents.

## Testing

```bash
bash scripts/test/diagram.test.sh                                            # host
docker run --rm -v "$PWD":/w -w /w bash:5 bash scripts/test/diagram.test.sh  # container
```

**Run both, always.** The host target (macOS bash 3.2 + BSD userland) catches `declare -A`,
`globstar` and GNU-only flags; the container target (bash 5 + GNU coreutils) catches BSD-only
constructs. Either alone passes green while the other target is broken.

The suite builds throwaway fixtures under `mktemp -d` and never touches the real repo. It covers
the pre-existing `index`/`links` behaviour as well as diagrams — those cases are the guard that
made the `lib.sh` extraction safe, so keep them.

To prove plugin independence, copy the directory out on its own and run the suite there — it must
pass with no sibling plugin and no repo root present.
