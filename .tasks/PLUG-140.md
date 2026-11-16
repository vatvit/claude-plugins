---
title: "docs-manager: an inline # comment after a frontmatter value breaks it silently"
status: completed
type: bug
priority: medium
tags: ["docs-manager-plugin"]
created: 2026-11-16 12:41
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | ## Context |
| 20 | Requirements | done | acceptance criteria were already testable; comment support chosen over reporting |
| 30 | Assessment | done | one parser, four value sites + comment lines; fm_set drops comments today |
| 40 | POC | skipped | nothing risky |
| 50 | Domain | skipped | n/a |
| 60 | Architecture | done | ## Architecture |
| 70 | Tests | done | FC1–FC17 in docs.test.sh, red before the fix |
| 80 | Subtasks | skipped | one change |
| 90 | Implementation | done | ## Implementation |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | plugin CLAUDE.md lib.sh bullet; root CLAUDE.md awk trap |

## Description

`fm_parse` (scripts/lib.sh) does not handle a YAML inline comment after a value. Found on a Drive
folder attachment (docs-manager 1.12.1): an `exclude:` list in `.source.md` with a trailing comment
excluded nothing, and `external remote-diff` reported the excluded files as `new`, with no warning.

Reproduce:

```
---
exclude: [a.zip, */b]   # note
foo: bar   # note
---
```

`fm_parse` emits:

```
scalar	exclude	[a.zip, */b]   # note
scalar	foo	bar   # note
```

- A flow list followed by a comment is parsed as a **scalar**, so `fm_list` returns nothing: every
  `include:` / `exclude:` / `watch:` / `relates-to:` written that way is silently empty.
- A scalar keeps the comment as part of its value (`bar   # note`): a `publish: local   # why`
  would not equal `local`.

The how-to examples themselves show inline comments (`publish: commit        # or local: …`,
`recursive: true                # false: …`), so a user copying them hits this.

## Acceptance criteria

- An unquoted ` #` (space-hash) and the rest of the line are stripped from scalars and flow lists;
  a `#` inside quotes or without a preceding space is kept (URLs with `#anchor`).
- A flow list with a trailing comment parses as a list.
- Or, if comments are not supported: a frontmatter line with one is reported (by `check`), never
  silently misread. Either way, the how-to examples match what the parser accepts.
- Tests: the reproduction above, failing before the fix.

## Context

**Epic:** none. The bug surfaced in the Drive folder attachment (epic `docs-gdrive`, PLUG-113), but it
lives in the shared parser.

**Code to touch:**
- `docs-manager/scripts/lib.sh` `fm_parse` (one awk program, lines ~83–136), the **only** frontmatter
  reader (plugin CLAUDE.md: "do not add a second frontmatter reader"). `fm_field` / `fm_list` / `fm_map`
  wrap it, so a fix there reaches every caller: diagram `refs:`/`watch:`/`stamp:`, external card fields,
  `.source.md` `include`/`exclude`/`recursive`/`publish`/`processed`, remote-card fields.
- Values pass through `trim` and then `unquote` in four places: scalar, inline list item, block list
  item (`  - x`), map value (`  sub: x`). Strip the comment between them, while the quotes are still
  there to tell a quoted `#` from a comment.
- A full-line comment (`# …`, or indented inside a block list/map) falls to `{ pending = "" }`
  today, which **ends** the pending block list: items after it are dropped. This is the same bug, so
  it belongs in the fix.
- `fm_set` replaces a whole `key: value` line, so it would drop a trailing comment on the line it
  rewrites. Only the stamp keys (`stamp`, `digest`, `remote-modified`, `copy-modified`, `remote-gone`)
  are written that way, and the how-to examples put comments on exactly those lines (`digest: … # written by
  external stamp`). That decides whether `fm_set` keeps the comment: an assessment question.

**Docs whose examples carry inline comments** (they must parse after the fix):
`skills/docs-manager/references/how-to-external-docs.md` lines 52, 263–266, 310–314, 355–356;
`skills/docs-manager/SKILL.md` 131–135; `README.md` 188.

**Tests:** `scripts/test/*.test.sh`, no framework. No suite tests `lib.sh` directly; `docs.test.sh`
is the general one. Run on the host and with `docker run --rm -v "$PWD":/w -w /w bash:5 bash …`
(plugin CLAUDE.md, README line ~364). awk must hold for BSD awk, gawk and busybox (root CLAUDE.md
awk traps: no `substr` on multibyte, walk chars with `substr(s,i,1)` only on ASCII-delimited checks).

**Parallel-session collisions:** a crew (delay coordinator, kickoff worker) runs in this repo; neither
touches `docs-manager/`. PLUG-141 (this session) also touches docs-manager: `external.sh` and the
how-to, not `lib.sh`'s `fm_parse`. Do PLUG-140 first; 141's new cards then parse comments correctly.

## Decisions

- 2026-11-16, user: `fm_set` **keeps** a trailing ` # comment` when it rewrites a value (it promises to
  preserve every byte it does not own).

## Architecture

- One awk helper `AWK_FM_COMMENT` in `lib.sh` (`fm_cpos`, `fm_cut`, `fm_blank`), prepended to both
  `fm_parse` and `fm_set`, so reader and writer agree on where a value ends. A second copy in either
  would be the duplication the plugin CLAUDE.md forbids.
- `fm_cut` runs on the raw text after `key:` / `-` / `sub:`, before `trim` and `unquote`, while the
  quotes still tell a quoted `#` from a comment.
- A quote opens only where a value starts (first character; after `[` or `,` in a flow list), so
  `it's # x` cuts at the comment, as YAML does.
- Comment lines (`^[ \t]*#`) are skipped with `next`, so a block list survives one between items.
- Chosen over "report comments in `check`": the how-to examples already use comments, and support
  is what makes them correct as written.

## Implementation

- `docs-manager/scripts/lib.sh`: `AWK_FM_COMMENT`; `fm_parse` and `fm_set` use it, both under
  `LC_ALL=C`. The first version used `~ /[ \t]/` on single characters and macOS awk aborted on
  `1AbC…` from the how-to (`towc: multibyte conversion failure`), silently, because `fm_parse` sends
  stderr to `/dev/null`. FC14 caught it; FC16/FC17 pin it.
- `docs-manager/scripts/test/docs.test.sh`: FC1–FC17. Before the fix 11 failed (FC3, FC5, FC11 and FC13
  hold either way); after it, all pass on the host (bash 3.2, BSD awk), in `bash:5` (busybox awk), with
  git, and with no HOME. Other suites unchanged: diagram 100, external 181, onboard 34.
- docs-manager 1.12.1 → 1.12.2 (plugin.json, marketplace.json); `check-descriptions.sh` ok. Released
  together with PLUG-141 as 1.13.0.

## Current State

Implemented and verified (all suites green on both targets). Not committed. Next: commit on the user's
request; the status stays `in-progress` until then.

Committed 2026-11-16 with the version left at 1.12.1: the user deferred the release (version bump) so
several features ship together; the planned 1.13.0 bump happens at release.
