---
title: Staleness — watch, stamp, check, bless, and the nudge hook
status: completed
type: feature
priority: medium
epic: diagram-support
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Requirements | done | Covered by PLUG-001 ## Requirements — R12–R16 |
| 20 | Assessment | done | Covered by PLUG-001 ## Assessment; cksum verified present |
| 30 | POC | skipped | Covered by PLUG-001 ## POC — skipped |
| 40 | Domain | done | PLUG-001 ## Domain — "stale" and "stamp"; 2 invariants bind this slice |
| 50 | Architecture | done | PLUG-001 D2 (no globs), D5 (cksum path+content) |
| 60 | Tests | done | PLUG-001 ## Tests — cases 10–17 |
| 70 | Subtasks | skipped | This task IS a slice of PLUG-001 |
| 80 | Implementation | done | 69 tests × 3 targets; 2 real bugs found by verification |
| 90 | Tech Debt | done | none new; documented DOCS_MANAGER_ROOT gap in place |
| 100 | Reflection | done | plugin docs + 2 cross-plugin lessons in repo CLAUDE.md |

## Description

The half that makes diagrams stay honest: a source declares what it depicts, and the
tool flags it as *suspect* when that changes. Includes the PostToolUse hook that
warns mid-session, while the change is fresh — the only moment a diagram actually
gets fixed.

**Full spec in PLUG-001** (R12–R16; Domain invariants "stale is a property of a
source" and "blessing is a human act"; Architecture D2/D5; Tests cases 10–17).

## Scope

- `watch:` — directory prefixes (trailing `/`) and exact paths, **no globs** (D2)
- `cksum` fingerprint over sorted path+content, so a rename counts (D5)
- `docs.sh diagram check` / `docs.sh diagram bless <name>`
- stale notice inside every embed's block
- `docs-manager/hooks/hooks.json` + hook script, modelled on `task-roadmap`'s
- hook always exits 0, never blocks a tool call

## Depends on

PLUG-002 (needs `fm_parse` and the block).
Independent of the refs and rendering slices.

## Acceptance

Cases 10–17 pass on both targets. Nothing but `bless` may ever write `stamp:`.

## Implementation

Delivered. **69 passed, 0 failed** on host (bash 3.2 + BSD), `bash:5` container (GNU)
and a standalone copy of the plugin directory. The 41 inherited assertions unchanged.

### Decisions

1. **No stamp = stale, reported as "never blessed."** Preserves the invariant that
   only `bless` writes `stamp:`. A newly watched diagram genuinely has not been
   reviewed against the code.
2. **The notice goes in the doc as well as `check` output** — the person misled by a
   stale diagram is the reader.
3. **`watch:` paths are source-relative**, consistent with PLUG-003's refs. Still no
   config file anywhere in this plugin.

### Two real bugs, both caught by verification rather than by review

**1. Deletion of the last watched file made a diagram permanently fresh.**
`fingerprint` returned empty when the watch set matched nothing, and the caller reads
empty as "no `watch:` declared → never stale" (R16). So deleting everything a diagram
depicted silently switched staleness *off* — at exactly the moment the diagram was
most likely wrong. Fixed by splitting `has_watch` (is the key declared?) from
`watch_files` (does it match anything?). Case 14b.

**2. Stamps were not portable — the feature would have been worse than useless.**
The digest included absolute paths, so a diagram blessed on one machine read as stale
on every other checkout. Since the stamp is committed, every contributor would have
seen permanent false staleness and learned to ignore the warning. Found by the
cross-platform check in the plan: blessed on the host, `check` in the container
reported STALE and the two stamps differed (`3975072916` vs `2493566287`). Fixed by
feeding paths **relative to the source** into the digest; both now yield
`4272921961`. Case 19 guards it.

Neither was visible from reading the code, and neither would have been caught by a
suite that only ran one target or only ran in one directory.

### A third finding — in the test, not the product

Case 12c failed in the container only: it asserted on `diff` output shape, and Alpine's
**busybox `diff` defaults to unified format** (`+`) while BSD/GNU default to normal
format (`>`). Rewritten to strip the stamp line and compare the remainder, which is
format-independent and a stronger assertion. Shipped code only ever uses `diff -q`
(exit status), so it was never affected.

### Files

| File | Change |
|---|---|
| `lib.sh` | ADD `fm_set` — set one frontmatter scalar, every other byte preserved |
| `diagram.sh` | ADD `watch_files`, `has_watch`, `fingerprint`, `stale_reason`, `find_source`, `cmd_diagram_check`, `cmd_diagram_bless`; notice appended in `build_diagram_block` |
| `docs.sh` | `diagram check`/`bless` dispatch; `cmd_check` runs `diagram check` |
| `hooks/hooks.json`, `hooks/diagram-watch-hook.sh` | NEW |
| `test/diagram.test.sh` | +28 assertions (41 → 69) |
| `README.md`, `CLAUDE.md` | staleness model, bless workflow, hook contract |

### Hook contract, enforced by tests

Always exits 0 (verified on match, non-match, missing docs dir, and malformed
payload), never writes, and returns after a single `find` when a project has no
diagram sources. One near-miss worth recording: the first draft wrapped the whole
body in `2>/dev/null`, which would have silenced the warning the hook exists to emit.

### Verified

- 69 cases × 3 targets
- cross-platform stamp: host bless → container check clean → container re-bless
  produces the identical stamp
- end-to-end lifecycle: bless → 0 notices → touch watched file → 2 notices (both
  embeds) → hook warns naming source and bless command → bless changes only the
  `stamp:` line → 0 notices

## Tech Debt

No new tickets. One gap found while closing out and fixed in place rather than
deferred: `DOCS_MANAGER_ROOT` was an **undocumented config surface**. A hook receives
no command-line arguments, so it is the only way to point the hook at a docs directory
other than `docs/` — but nothing said so in the README or CLAUDE.md, which would have
left anyone with a `documentation/` tree wondering why the hook never fired. Now
documented in both, with an explicit note not to grow it into a config file.

Carried forward, unchanged: **PLUG-006** (config conventions) and **PLUG-007** (skill
activation). Neither is touched by this slice.

## Reflection

**Plugin docs updated with the work:** `README.md` gained a Staleness section (the
`watch:`/`stamp:` format, the bless workflow, the five rules including stamp
portability) and a hook section; `CLAUDE.md` gained `fm_set`, a Staleness
don't-regress list naming both bugs found here, and the hook's non-negotiable contract.

**Repo `CLAUDE.md` — two cross-plugin lessons added to Shell Conventions**, because
both would bite any future plugin, not just this one:
- Never assert on `diff` **output shape** in tests: busybox diff (Alpine) defaults to
  unified format while BSD/GNU default to normal format. Use `diff -q` for exit status,
  or compare content directly.
- Never bake absolute paths into a value that gets **committed**. A digest containing
  a checkout path differs on every machine.

**Lessons worth keeping:**
- The dual-target suite paid for itself twice in one slice — once catching the busybox
  diff divergence, and the cross-platform stamp check catching a bug that would have
  made the whole feature worse than useless (contributors would have learned to ignore
  a permanently-on warning). Neither was findable by reading the code.
- "Empty result" and "not configured" are different states and conflating them is a
  silent-failure generator. `fingerprint` returned empty for both "no `watch:` key" and
  "watch matches nothing", which switched staleness off exactly when a diagram was most
  likely wrong. Worth checking for this shape wherever a function returns empty.
- A hook that swallows its own stderr is a hook that does nothing. Caught in review of
  my own first draft, but only because the contract had been written down first.
