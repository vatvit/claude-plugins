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
│   ├── diagram.sh               ← diagram sources → generated blocks, staleness
│   └── test/diagram.test.sh     ← the suite (no framework, no dependencies)
├── hooks/
│   ├── hooks.json               ← PostToolUse registration
│   └── diagram-watch-hook.sh    ← warns when an edited file is watched
├── skills/docs-manager/
│   ├── SKILL.md                 ← when-to-use + commands + conventions
│   └── references/
│       └── how-to-erd.md        ← loaded on demand, only when an ERD is being drawn
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
- `relpath <from-dir> <to-path>` — lexical relative path. Exists because a ref is written relative
  to the source but must link correctly from every doc that embeds it, at any depth.
- `parse_ref <value>` — splits `scheme:path "optional label"` into three tab-separated fields.
- `fm_set <file> <key> <value>` — set one frontmatter scalar, preserving every other byte. Writes
  via temp file + `mv`; never `sed -i`.

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

### Refs

`refs:` in a source's frontmatter becomes a `**References**` caption below the fence.

- **Paths are source-relative and the href is computed per embedding doc.** Never store a resolved
  href: one source may be embedded at several depths, and case 7 in the suite exists to prove they
  differ. This is why `relpath` exists.
- **`url:` is emitted and never resolved.** No command in this plugin makes a network call, ever.
- All other schemes resolve identically today — the scheme states intent and is where PLUG-005 will
  key click injection. Do not add resolution logic that varies by scheme without a reason to.
- A source with no `refs:` emits **no** caption line, not an empty one.
- `cmd_links` checks refs at their point of declaration; the markdown pass separately validates the
  caption links in each embedding doc, so a break is caught twice.

### Staleness

- **`bless` is the only writer of `stamp:`.** If any other command ever re-stamps as a side effect,
  staleness stops meaning anything. This is the invariant the whole feature rests on.
- **Stale is a property of the source, not the embed.** Computed once per source; the notice is
  repeated into each embedding doc, never recomputed per doc.
- **The fingerprint uses paths RELATIVE TO THE SOURCE.** Absolute paths would bake the checkout
  location into a committed stamp, so every contributor would compute a different value and every
  diagram would read as permanently stale. Case 19 exists to catch a regression here; it was a real
  bug found by blessing on the host and checking in the container.
- **`has_watch` ≠ "watch matches files".** No `watch:` key means never stale (R16); `watch:` present
  but matching zero files means everything it depicted was deleted, which must still be flagged.
  Case 14b covers it.
- Renames and deletions both change the digest, by design.

### The hook

`hooks/diagram-watch-hook.sh` is the only thing this plugin runs automatically, in someone else's
project, on every edit. Non-negotiable:

- **Always `exit 0`.** Never block the tool call — no diagrams, no docs dir, malformed payload,
  unreadable file, all exit 0.
- **Never write.** It reports; blessing stays a human act.
- **Cheap when idle.** No `docs/`, or no `*.diagram.md` under it → return after one `find`.
- Do **not** wrap its body in `2>/dev/null` — the warning it exists to emit goes to stderr.
- `DOCS_MANAGER_ROOT` (default `docs`) is the **only** setting this plugin has, and it exists purely
  because a hook receives no arguments. Do not grow it into a config file: every path in the diagram
  format is source-relative precisely so that none is needed.

### The render port

`<root>/.docs-manager-render <source> <out-basename>` — an executable the **project** supplies. The
plugin ships no renderer, pulls nothing, installs nothing.

- **Convention, not config.** This was originally specced as a `diagrams.render` config key with a
  placeholder grammar; that was dropped because it reintroduced the config file the rest of the
  format exists to avoid. Do not re-add one.
- **The script gets the source path**, so everything language-specific — Mermaid `click`, D2 `link:`,
  theming — lives there. Nothing here may learn a diagram language; that is what keeps R2/R4 true.
- **`render` is explicit, linking is automatic.** `index` must never shell out to someone's container
  on a routine run. It only links an artifact that already exists next to the source.
- Absent script → success, silent. Non-executable → reported, non-zero (a silent skip is
  undebuggable). Failing script → reported, prior artifact untouched, `index` still writes the block.
- **`set -e` trap:** a helper whose last command is a failing test (`[ -f … ]`) propagates non-zero
  out through `x="$(helper)"` and kills the run. `render_script` and `artifact_for` both end in an
  explicit `return 0` for this reason — "absent" is the normal case, not an error. This bit once.

## skills/docs-manager/references/

Long-form guidance that is only worth context when a specific job comes up. `SKILL.md` points at a
reference and **states no rules of its own about it** — a summary good enough to act on is a second
source of truth, and it is the copy that gets acted on, so it is the copy that drifts.

- `how-to-erd.md` — how to draw an entity-relationship diagram. It exists because **no command here
  can check an ERD**: a picture that invents a column, empties a box or draws an unjoinable edge
  passes `diagram index --check`, `links` and `check` while lying to the reader. The rules are
  scar tissue; do not trim one without knowing which picture taught it.
- `how-to-claude-md.md` — how to keep a project's agent instruction file (`CLAUDE.md`, `AGENTS.md`)
  to instructions, by moving project knowledge into the docs this plugin maintains. It exists for the
  same reason as the ERD how-to: **no command here can see the problem** — an instruction file that
  has become a duplicate, drifting copy of the docs passes every check. Keep the residue-check command
  in rule 6 runnable as written; it is what makes "nothing was lost" evidence rather than a claim.

Adding a reference means: the file, a pointer from `SKILL.md`, trigger phrases in the skill
`description:` (or it is unreachable), and a row here.

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
