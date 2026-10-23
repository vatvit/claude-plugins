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
│   ├── docs.sh                  ← CLI front-end: index / links / diagram / external / check
│   ├── diagram.sh               ← diagram sources → generated blocks, staleness
│   ├── external.sh              ← external files (pdf, docx, …) and their cards
│   ├── extract.sh               ← docx/xlsx → outline / plain text (unzip + awk)
│   └── test/
│       ├── *.test.sh            ← the suites (no framework, no dependencies)
│       └── fixtures/            ← built OOXML fixtures; XML sources in src/, rebuilt by build.sh
├── hooks/
│   ├── hooks.json               ← PostToolUse registration
│   └── diagram-watch-hook.sh    ← warns when an edited file is watched
├── skills/docs-manager/
│   ├── SKILL.md                 ← when-to-use + commands + conventions
│   └── references/              ← loaded on demand, only for the job each one covers
│       ├── how-to-erd.md
│       ├── how-to-claude-md.md
│       ├── how-to-render.md
│       └── how-to-external-docs.md
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
- `docs_find <root> <maxdepth|""> <tests…>` — **every walk of the docs tree goes through it**, so
  all commands skip the same things: any dot-entry at any depth (`.git/` when `docs/` is its own
  repository, `.obsidian/`, a hidden file), pruned with what is under it; the root itself is never
  pruned. Do not add a bare `find` over the docs tree. The one exception is `diagram.sh`'s walk of a
  ref's *target* folder, which is usually code and feeds stored digests (PLUG-079).
- `normalize_path`, `block_rewrite`, `has_marker`, `write_if_changed`.
- `relpath <from-dir> <to-path>` — lexical relative path. Exists because a ref is written relative
  to the source but must link correctly from every doc that embeds it, at any depth.
- `parse_ref <value>` — splits `scheme:path "optional label"` into three tab-separated fields.
- `fm_set <file> <key> <value>` — set one frontmatter scalar, preserving every other byte. Writes
  via temp file + `mv`; never `sed -i`.
- `doc_links <root>` — `file<TAB>link<TAB>target` for every relative markdown link, paths
  normalized. **The only markdown link parser** — `links` checks targets exist, `external related`
  matches targets against a card; do not grep for `](` anywhere else. Destinations come from
  `md_link_dests` (CommonMark: `<…>`, balanced parens, `"title"` dropped) and `%XX` is decoded by
  `url_decode` in the shell — awk's `%c` is multibyte-unsafe under gawk. It was a
  `\]\([^)]+\)` regex, which failed every name containing `(` or an escaped space.
- `md_dest <path>` — **every link this plugin writes goes through it.** Wraps in `<…>` only when the
  name has a space or parenthesis, so ordinary names stay byte-identical (no DRIFT on upgrade) and
  odd ones render as links on GitHub/GitLab.
- **Never `exit` early in awk that reads a pipe under `pipefail`** — the writer can take SIGPIPE
  and the caller dies with rc 141, intermittently. `fm_field` did this until the container suite
  caught it; read to the end and keep the first match instead.

A map is never held in bash: awk emits records, the shell reads them with
`while IFS=$'\t' read -r`. That is what keeps this working on bash 3.2, which has no
associative arrays.

## scripts/docs.sh

Subcommands: `index [--write|--check]`, `links`, `diagram …`, `external …`, `check`.
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
- **`ARTIFACT_EXTS` is ordered and the order is a contract.** `artifact_for` returns the *first*
  match, so a source with both `x.svg` and `x.html` links the SVG. `html` was appended last (PLUG-012)
  precisely so adding it could not change which artifact an existing project links — never reorder
  this list to express a preference, and never prepend. Case 30 pins it.
- **Script exits 0 having written nothing recognised → `NO ARTIFACT:` on stderr, rc unchanged.**
  It was printing `RENDERED:` with an empty path, which read as success while `index` linked nothing
  — the exact failure mode that made "why is my .html not showing up?" hard to answer. It is a
  warning and not a failure because a script may legitimately skip a source; case 31 pins both halves.
- **`set -e` trap:** a helper whose last command is a failing test (`[ -f … ]`) propagates non-zero
  out through `x="$(helper)"` and kills the run. `render_script` and `artifact_for` both end in an
  explicit `return 0` for this reason — "absent" is the normal case, not an error. This bit once.

## scripts/external.sh

An external file is one with an extension in `EXTERNAL_EXTS`; its card is `<file>.md` beside it.
Sourced by `docs.sh`, like `diagram.sh`.

Key behaviors (don't regress these):
- **Convention, not config.** `<root>/external/` and `EXTERNAL_EXTS` are fixed, for the same reason
  the render port is a convention — see `DOCS_MANAGER_ROOT` above. PLUG-016 originally specced a
  `.docs-manager.json` with an `externalDir` key; it was dropped against that rule. Do not re-add it.
- **The file name is the link.** A card has no `source:` key; `is_card` and `external_source` derive
  one from the other. A second place recording the pairing is a second thing to drift.
- **`stamp` is the only writer of `digest:`**, exactly as `bless` is for `stamp:`, and it is
  diff-guarded. The digest is sha256 of the file's **bytes** — never a path (case S3).
- **The `### External documents` section is emitted only when a folder has externals**, so every
  existing `_index.md` regenerates byte-identical on upgrade. Case E2 pins it.
- **A diagram's render artifact is not external.** `x.pdf` beside `x.diagram.md` is skipped (E3) —
  without that every project rendering to PDF would fail `check`.
- **`status` writes `-` for an empty field.** Tab is whitespace to `read`, so consecutive tabs
  collapse and shift every field after them — an orphan's card path landed in the wrong variable
  until this was fixed.
- **Placement never fails `check`.** `outside` and `unfiled` are reported by `status` only; a carded
  file kept beside the doc that uses it is a choice.
- **`move` reports broken links, never rewrites them.**
- **A dependant is `relates-to:` or a link, never `_index.md`.** `external related` reads the card's
  `relates-to:` (card-relative) plus `doc_links`, deduplicated. The generated index links every
  card, so counting it would put a `REVIEW:` line under every change. `check` parses the tree's links
  once however many files changed. A missing `relates-to:` target is reported by `links` as
  `BROKEN REF`, not by `related` — one place per breakage.

## scripts/extract.sh

`external outline|text <file>`: docx and xlsx are zip packages of XML, read by `unzip -p` + awk
with `RS = "<"` (one tag per record). Sourced by `docs.sh`.

- **`extract_kind` is the one capability check.** Everything unreadable — pdf (read natively),
  legacy binary, other formats, no `unzip`, a package that will not open — is a `none<TAB>reason`
  record and exit 0. A missing *file* is the only error.
- **"Empty" is the portable missing-member test.** Info-ZIP exits 11 on a missing member, busybox
  exits 0 silently; `ooxml_part` swallows both.
- **Two parts, one awk pass, joined by a sentinel record** (`<@@DOC@@>`). `FNR==NR` breaks when the
  first input is empty, and `styles.xml` / `sharedStrings.xml` are optional.
- **xlsx sheets come in workbook order** via `workbook.xml.rels`, never by file name; element names
  compare without their namespace prefix (`x:row` exists in the wild). Sheet names reach awk through
  `ENVIRON`, not `-v`, which would interpret backslashes.
- Nothing here writes. Callers keeping output put it in a temp dir, never the repo.

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

- `how-to-render.md` — how to supply the optional `.docs-manager-render` script: the argument
  contract, the failure semantics, recipes for mermaid-cli, D2 and Kroki, and a setup checklist.
  It exists because the render port was **knowledge with no route to it** — the recipes sat in
  `README.md`, which an agent working in a consuming project never reads, so a session that hit
  "needs a `.docs-manager-render` and there is none" had nothing to suggest. The recipes now live
  here only; `README.md` links to this file rather than repeating them.

- `how-to-external-docs.md` — the card format, the `docs/external/` layout and the cataloguing
  procedure. It exists because **a card's value is in what no command can check**: whether the
  `## Where to look` rows point at the right pages. `check` proves a card exists and is current, not
  that it is true.

Adding a reference means: the file, a pointer from `SKILL.md`, trigger phrases in the skill
`description:` (or it is unreachable), and a row here.

## Testing

```bash
bash scripts/test/diagram.test.sh                                             # host
docker run --rm -v "$PWD":/w -w /w bash:5 bash scripts/test/diagram.test.sh   # container
bash scripts/test/external.test.sh                                            # host (also index/check: dot-folders)
docker run --rm -v "$PWD":/w -w /w bash:5 bash scripts/test/external.test.sh  # container
```

**Run both, always.** The host target (macOS bash 3.2 + BSD userland) catches `declare -A`,
`globstar` and GNU-only flags; the container target (bash 5 + GNU coreutils) catches BSD-only
constructs. Either alone passes green while the other target is broken.

The suite builds throwaway fixtures under `mktemp -d` and never touches the real repo. The
exception is the OOXML files in `scripts/test/fixtures/`: busybox has `unzip` but no `zip`, so
they are built once from `fixtures/src/` by `fixtures/build.sh` and committed — edit the XML, rerun
it, commit both. It covers
the pre-existing `index`/`links` behaviour as well as diagrams — those cases are the guard that
made the `lib.sh` extraction safe, so keep them.

To prove plugin independence, copy the directory out on its own and run the suite there — it must
pass with no sibling plugin and no repo root present.
