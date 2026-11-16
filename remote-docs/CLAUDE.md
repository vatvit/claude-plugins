# CLAUDE.md — remote-docs plugin

Guidance for working on this plugin.

## What it is

Remote documents (Google Drive files and folders, Claude Artifacts) kept as **remote cards** under the
docs root: a runtime-free shell tool (`scripts/remote.sh`) plus a skill (`skills/remote-docs/`). Only
Claude talks to a provider, through its MCP or tool; no script makes a network call. Split out of
docs-manager in PLUG-144 (epic `remote-docs`, PLUG-143) with behaviour unchanged.

## Layout

```
remote-docs/
├── .claude-plugin/plugin.json
├── scripts/
│   ├── lib.sh             ← this plugin's helpers: docs walk, frontmatter (copied from docs-manager)
│   ├── remote.sh          ← the CLI: status / check / list / stamp / gone / copy-stamp / diff
│   └── test/remote.test.sh
├── skills/remote-docs/
│   ├── SKILL.md
│   └── references/how-to-remote-docs.md   ← card format, attach / refresh / copy / artifact procedures
├── README.md
└── CLAUDE.md
```

## The contract with docs-manager

The two plugins never source each other. They share **data**: the file names `<name>.<provider>.md`,
`<name>.<provider>.local.md` and `.source.md`, and the card fields `title`, `description`, `read-when`,
`relates-to`. docs-manager lists cards with ☁ by those names and checks their links; this plugin owns
everything else. `REMOTE_PROVIDERS` exists in both, and each suite's CT1 pins the names: a new provider
changes both plugins.

`lib.sh` began as a copy of docs-manager's helpers (`docs_find`, `drop_git_ignored`, `AWK_FM_COMMENT`,
`fm_parse`, `fm_field`, `fm_list`, `fm_set`). That duplication is the price of independence (root
CLAUDE.md, *Plugin Independence*); a fix to one copy is checked against the other.

## Invariants (PLUG-112, epic `docs-gdrive`; artifacts PLUG-141; moved from docs-manager in PLUG-144)

A remote card (`<name>.<provider>.md`) describes a file kept with a provider — Google Drive (`gdrive`)
or a Claude Artifact (`artifact`) — with no local copy. Only the skill (Claude) talks to the provider;
the scripts stay offline.

- **One implementation, the provider as data.** `REMOTE_PROVIDERS` lists the names and `provider_data`
  holds everything that differs (the listing's container type, the URL key parameters). No other line
  may branch on a provider; a new provider is a name and, at most, a `provider_data` row.
- **`diff` has two modes, chosen by the attachment.** `.source.md` with `remote-id` mirrors a
  container: `new`/`changed`/`gone` in scope. Without it the cards were attached one by one (every
  artifact): only carded ids count, never `new`, because the listing holds everything the user can see.
  Only cards of `.source.md`'s `provider:` (default `gdrive`) are compared.
- **An access key never reaches a committed card.** `has_access_key` greps the whole card (a body link
  counts) for the provider's key parameters; outside a `publish: local` folder that is `keyed` /
  `REMOTE KEY`, and the key is never printed.

- **The name is the classifier.** `is_remote_card` matches `*.<provider>.md` for `REMOTE_PROVIDERS`;
  no script reads frontmatter to decide what a file is. docs-manager's index and orphan check rely on
  the same names (see *The contract with docs-manager* above).
- **The Drive id lives in the card** (`remote-id:`): a documented exception to "the file name is the
  link", since there is no local file. Do not add a `source:` key to local cards on its strength.
- **`stamp` is the only writer of `remote-modified:`**, as docs-manager's `external stamp` is of `digest:`, diff-guarded,
  shape-checked (RFC 3339, `Z` or a `±hh:mm` offset). The value comes from the provider through Claude.
- **`.source.md` is per-folder data, not config** (no plugin here takes a config file for it). It is a
  dot-file, so `docs_find` never lists it; scripts find it by path: `source_of` takes
  the nearest one from the card's folder up, since a folder attachment's sub-folders share one.
- **`RD_KEEP_IGNORED=1` is the one opt-out of `drop_git_ignored`**, used by `list`,
  `diff` and the local-copy listing, so a local-only (git-ignored) attachment stays findable
  while no committed `_index.md` names it.
- **`diff` matches by Drive id, never by name or path** (PLUG-113). A rename or move is
  `changed` at most, never gone + new. Ids are compared as strings (`$1 ""`, RF7), and so are times:
  `…11Z` and `…11.986Z` do not order, so a time is only equal or not. Never compare them with `<`.
- **A script never deletes a gone card.** `gone` marks it (`remote-gone: yes`), `check` fails
  with `REMOTE GONE` until the user decides, and `stamp` clears the mark when the file is back.
  A marked card is not reported `gone` again; a marked card whose id is listed again is `changed`.
- **The listing is Claude's, written to a temp file from the MCP.** `diff` validates it (4
  fields, non-empty id) before anything else and prints nothing on a bad line. Scope (`recursive`,
  `include`, `exclude` in `.source.md`) is applied with `case` globs in `remote_in_scope`, the one place.
- **A local copy is `<name>.<provider>.local.md`, classified by name** (`is_remote_copy`), never a card and
  never a document (`list_docs` skips it). Its stamp is the card's `copy-modified`, written only by
  `copy-stamp`, which refuses unless `source_of` the card says `processed: local`: the agreement is
  checked by the script, not only by the skill (PLUG-115). Stale = `copy-modified` ≠ `remote-modified`,
  string inequality. Copies are listed with `RD_KEEP_IGNORED=1`, so a git-ignored copy is still checked.
- **No bytes through the MCP.** Copies are Drive's text rendering, written as text; a binary download is
  base64 that would be retyped with no checksum, so `content: sync` was rejected (PLUG-114).

## Folder purpose (PLUG-145)

- **Settings live in `.source.md`, resolved per key** (`src_key`): the nearest `.source.md` from the folder
  up to the root that sets a key wins. A suggested purpose sets `writes`, `truth`, `cards` at its own
  level (`purpose_default`, the one table); an explicit key at that level overrides it. A custom purpose
  implies nothing. Do not go back to "nearest file wins as a whole" (`source_of`): a purpose-only
  sub-folder file would then hide its parent's `publish:` (PP1e).
- **The fallback is read-only**: `writes: never`, `truth: no`, `scope: project`, `cards: files`. Never make
  an undeclared folder writable by default.
- **`PURPOSE?` never fails `check`**; it is a note for attachments made before purposes existed.
  `PURPOSE INCOMPLETE`, `BAD SETTING` and `SCOPE UNKNOWN` do fail.
- **`.source.md` is a dot-file, so `docs_find` prunes it**: `source_dirs` walks folders and tests for it.
- **Pointer mode** (`cards: pointer`): `diff_pointer` compares the newest in-scope time with the pointer
  card's `remote-modified`. "Newest" is a string maximum, used only for equality, never to order cards.
  A deleted file does not change it; accepted, since a collaboration folder's files are temporary.

## Attachment questions (PLUG-146)

- **`questions` is the one list of what to ask**, and an answer is anything recorded in the `.source.md`
  chain (`src_key`), so a question is never asked twice. The how-to says "ask only what it prints"; do
  not add a question in prose without adding it here.
- **No git, no publish question** (`in_git`: the nearest existing folder in a work tree; git not
  installed counts as no repo). Nothing then writes a `.gitignore`.

## Testing

```bash
bash scripts/test/remote.test.sh                                             # host (git cases too)
docker run --rm -v "$PWD":/w -w /w bash:5 bash scripts/test/remote.test.sh   # container (git cases skipped)
docker run --rm -v "$PWD":/w -w /w bash:5 sh -c 'apk add -q git && git config --global --add safe.directory "*" && bash scripts/test/remote.test.sh'
docker run --rm -v "$PWD":/w -w /w bash:5 sh -c 'env -u HOME bash scripts/test/remote.test.sh'   # no HOME
```

Run host and container both: each catches what the other misses (root CLAUDE.md, *Shell Conventions*).
The plugin reads nothing from HOME. To prove independence, copy `remote-docs/` alone somewhere and run
the suite there.
