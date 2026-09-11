---
title: Optional render port (project-supplied command)
status: completed
type: feature
priority: low
epic: diagram-support
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Requirements | done | PLUG-001 R17–R19, AMENDED — see ## Amendment |
| 20 | Assessment | done | Covered by PLUG-001 ## Assessment |
| 30 | POC | skipped | Covered by PLUG-001 ## POC — skipped |
| 40 | Domain | done | PLUG-001 ## Domain — plugin owns sources, not pixels |
| 50 | Architecture | done | Convention-over-config script hook; decided at Implementation |
| 60 | Tests | done | PLUG-001 ## Tests — cases 18–19, adapted |
| 70 | Subtasks | skipped | This task IS a slice of PLUG-001 |
| 80 | Implementation | done | 85 tests × 3 targets; convention over config; set -e bug caught by the no-op case |
| 90 | Tech Debt | done | none deferred; set -e audit found + fixed a second latent instance |
| 100 | Reflection | done | README render port + recipes; CLAUDE.md don't-regress list |

## Description

For projects that want a standalone artifact with clickable nodes: the project
supplies a render command, the plugin substitutes placeholders and shells out. The
plugin ships no renderer, pulls nothing, installs nothing.

**Full spec in PLUG-001** (R17–R19; Tests cases 18–19).

## Scope

- `diagrams.render` config with `{in} {out} {dir} {name} {uid} {gid}` substitution
- absent `render` → every command succeeds, no artifact, no error
- failing `render` → reported, prior artifact untouched, block still written
- refs additionally injected as the renderer's own link directives
- README recipes for mermaid-cli / D2 / Kroki — **knowledge, not a dependency**

## Depends on

PLUG-002; best after PLUG-003 (refs) since injection reuses the resolver.
Deliberately last — the only part that shells out, and nothing depends on it.

## Acceptance

Case 18 (no render configured) and case 19 (`render` set to `false`) pass. The
no-dependency acceptance test AC2 must still hold with this slice merged.

## Amendment (decided before implementation)

The ticket specified a `diagrams.render` **config key** with a
`{in} {out} {dir} {name} {uid} {gid}` substitution grammar. Not buildable as written:
PLUG-003 made every path source-relative *to delete the config surface*, and PLUG-004
documented `DOCS_MANAGER_ROOT` as "the only setting this plugin has — do not grow it
into a config file."

Replaced with **convention over configuration**: an executable script at
`<root>/.docs-manager-render`. The project still owns the renderer, its pinning and its
security surface, so independence holds — without a config file or a grammar to
specify, parse and document. User chose this over reinstating config.

**Second amendment: refs are NOT injected as renderer link directives.** That requires
knowing Mermaid spells it `click X href` and D2 spells it `link:` — breaking R2 ("the
fence is never parsed") and R4 ("behaviour must not differ between language tags").
The render script receives the source path and has the whole file, so it can do any
language-specific injection itself. Deliberate scope reduction; the plugin stays
language-agnostic.

## Implementation

Delivered. **85 passed, 0 failed** on host, `bash:5` container and standalone copy.
The 69 inherited assertions unchanged.

### Contract

```
<root>/.docs-manager-render  <source-path>  <out-basename>
```

Writes `<out-basename>.{svg,png,pdf,webp}`, exits non-zero on failure. Invoked only
if the file exists and is executable.

**`render` is explicit; linking is automatic.** `docs.sh diagram render` runs the
script; `diagram index` links any artifact it finds next to the source, resolved per
embedding doc via `relpath`. Deliberately not fused — `index` must never silently
shell out to someone's container on a routine run.

### Bug found by the most important test

Case 18a — "no render script → exits 0", the state nearly every project is in — failed
immediately. `docs.sh` runs under `set -euo pipefail`, and `render_script` ended in a
failing `[ -f … ]`. That non-zero status propagated out through
`script="$(render_script "$root")"` and killed the whole run, silently and with no
output. `artifact_for` had the identical latent bug.

Both now end in an explicit `return 0`, with a comment saying why. The general shape —
**a helper whose "not found" case is normal must not return non-zero under `set -e`** —
is recorded in the plugin's CLAUDE.md.

Worth noting the test that caught it was the one testing *nothing happening*. The
feature paths all passed.

### Files

| File | Change |
|---|---|
| `diagram.sh` | ADD `render_script`, `out_basename`, `artifact_for`, `artifact_line`, `cmd_diagram_render`; artifact link in `build_diagram_block` |
| `docs.sh` | `diagram render` dispatch |
| `test/diagram.test.sh` | +16 assertions (69 → 85) |
| `README.md` | the contract, explicit/automatic split, and collapsed recipes for mermaid-cli / D2 / Kroki |
| `CLAUDE.md` | render-port don't-regress list including the `set -e` trap |

### Verified

- 85 cases × 3 targets
- end-to-end: a stub script, one source embedded at two depths → `render` → `index` →
  `auth-flow.svg` from the top doc and `../auth-flow.svg` from the nested one, both
  confirmed to resolve from their own directory
- **no renderer was installed or pulled anywhere in this slice**, including in the
  tests, which use two-line shell stubs. That is the point of the design.

## Tech Debt

None deferred. The `set -e` bug prompted an **audit of every helper in `lib.sh` and
`diagram.sh`** for the same shape — a function whose last command can legitimately
return non-zero, invoked as `x="$(fn)"`. It found one more latent instance:

`find_source` used `grep -c` to count matches, and **`grep -c` exits non-zero when the
count is zero** — so looking up a name that does not exist would have aborted the run
instead of reaching the "not found" message. It survived only by accident: its single
call site sits on the left of `||`, which suppresses `set -e` inside the whole
invocation. Any future caller without `||` would have hit it. Fixed with `|| true`
and a comment. `watch_files` got a defensive `return 0` for the same reason.

Everything else checked clean: predicates (`has_watch`, `has_marker`) are only used in
conditional context, and the rest end in awk pipelines or explicit returns.

Carried forward untouched: **PLUG-006** (config conventions, re-scoped) and
**PLUG-007** (skill activation).

## Reflection

**Docs updated with the work:** `README.md` gained the render-port contract, the
explicit-render/automatic-linking split, and collapsed copy-paste recipes for
mermaid-cli / D2 / Kroki explicitly labelled *"examples to adapt, not supported
integrations"*. `CLAUDE.md` gained a render-port don't-regress list including the
`set -e` trap and a "do not re-add a config file" note.

**Lessons worth keeping:**
- **The test for "nothing happens" found the bug that every feature test missed.**
  Case 18a — no render script, the state nearly every project is in — was the only
  failing case, and the failure was total: the run died silently with no output. When
  a feature is opt-in, the opt-out path is the one most users experience and the least
  likely to be exercised by hand.
- **`set -e` plus `x="$(fn)"` turns "not found" into "abort".** Any helper whose
  absent/empty case is *normal* needs an explicit `return 0`. Worth grepping for the
  pattern whenever a script has `set -e` and helper functions — the audit took two
  minutes and found a second instance the tests could not have caught, because the
  only existing call site masks it.
- Three slices in a row have now added content to `build_diagram_block`'s trailing
  seam (refs, stale notice, artifact link) without restructuring it. Shaping that
  extension point in PLUG-002, before there was a second occupant, paid off three times.
