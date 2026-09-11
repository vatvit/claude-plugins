---
title: Typed refs — resolution, References line, link checking
status: completed
type: feature
priority: high
epic: diagram-support
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Requirements | done | Covered by PLUG-001 ## Requirements — R9–R11 |
| 20 | Assessment | done | Covered by PLUG-001 ## Assessment; cmd_links already crawls *.diagram.md |
| 30 | POC | skipped | Covered by PLUG-001 ## POC — skipped |
| 40 | Domain | done | PLUG-001 ## Domain — "ref" vs "link" is canonical |
| 50 | Architecture | done | PLUG-001 D4 (fm_map records); resolver shape decided at Implementation |
| 60 | Tests | done | PLUG-001 ## Tests — cases 6–9 |
| 70 | Subtasks | skipped | This task IS a slice of PLUG-001 |
| 80 | Implementation | done | 41 tests green on host + container + standalone |
| 90 | Tech Debt | done | none raised |
| 100 | Reflection | done | README + CLAUDE.md updated with the work |

## Description

A diagram becomes navigable: each node can point at a file, doc, task, glossary term,
url or another diagram, rendered as a caption list under the fence and validated by
the existing link checker.

**Full spec in PLUG-001** (R9–R11; Domain "ref"; Tests cases 6–9).

## Scope

- ref schemes `file:` `doc:` `task:` `term:` `url:` `diagram:`
- resolver → href relative to **each** embedding doc (a source with two embeds at
  different depths yields different hrefs — case 7)
- `**References**` line inside the generated block, author order preserved
- extend `cmd_links` to crawl `refs:` in every `*.diagram.md`
- `url:` emitted but never resolved, never fetched

## Depends on

PLUG-002 (needs `fm_parse` map records and the generated block).
Independent of the staleness and rendering slices — can run in parallel with both.

## Acceptance

Cases 6–9 pass on both targets.

## Implementation

Delivered. **41 passed, 0 failed** on all three targets — host (bash 3.2 + BSD),
`bash:5` container (GNU), and the plugin directory copied out standalone. The 29
PLUG-002 assertions still pass unchanged.

### Decisions taken during planning

1. **Refs are source-relative — no config file.** A ref path resolves like any
   markdown link, relative to the `.diagram.md` declaring it. docs-manager gains no
   `projectRoot`/`tasksDir`/`glossary` settings and never learns that task tooling
   exists — the plugin-independence rule is satisfied by construction rather than by
   care. Cost: verbose paths.
2. **Optional quoted label.** The key stays the diagram's node id (PLUG-005 needs it);
   a trailing `"..."` overrides the caption label, otherwise the key renders in
   backticks.

### Honest consequence

With source-relative paths, `file:`, `doc:`, `task:`, `term:` and `diagram:` all
resolve **identically**. Only `url:` differs (emitted, never resolved). The schemes
are kept because they state intent and PLUG-005 keys click injection off them — but
they do no resolution work today, and both `diagram.sh` and CLAUDE.md say so rather
than implying more structure than exists.

### Files

| File | Change |
|---|---|
| `lib.sh` | ADD `relpath` (lexical relative path), `parse_ref` (scheme/path/label split) |
| `diagram.sh` | ADD `ref_href`, `refs_line`; `build_diagram_block` now takes the doc and appends the caption |
| `docs.sh` | `cmd_links` second pass over `refs:` in `*.diagram.md` → `BROKEN REF:` |
| `test/diagram.test.sh` | +12 assertions (29 → 41) |
| `README.md`, `CLAUDE.md` | References section, source-relative rule, url-never-fetched |

### Verified

- 41 cases × 3 targets
- end-to-end: one source embedded in `docs/auth.md` and `docs/deep/nested.md` produced
  `../src/api/gateway.ts` and `../../src/api/gateway.ts` respectively, and **both were
  confirmed to resolve from their own directory** — the point of `relpath`
- `url:https://example.invalid/...` → no check, no error, no network call
- `docs.sh check` on this repo: unchanged

## Tech Debt

None raised. No shortcuts were taken; the one piece of deliberate under-engineering
(schemes that do not vary resolution) is documented in the code rather than hidden,
and PLUG-005 is where it starts earning its keep.

## Reflection

**Docs updated with the work:** `README.md` gained a References sub-section (syntax,
the per-doc href rule, the scheme table, and *why* it is a caption and not clickable
nodes); `CLAUDE.md` gained the two new `lib.sh` helpers and a Refs don't-regress list.

**Lessons worth keeping:**
- Asking "where does a ref path resolve from?" removed a whole config file, a JSON
  reader and any knowledge of the task plugin. The cheapest dependency is the one the
  design never needs — worth asking that question before writing a config loader.
- Storing a resolved href would have been the obvious implementation and would have
  been wrong the moment a source was embedded at two depths. The failing case is
  invisible with one embed, which is why case 7 was specified in PLUG-001 before any
  code existed.
- The 29 inherited assertions caught nothing this time, but made changing generated
  output a non-event. That is what they are for.
