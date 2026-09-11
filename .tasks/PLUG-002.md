---
title: Diagram sources render into docs (AUTO-DIAGRAM block)
status: completed
type: feature
priority: high
epic: diagram-support
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Requirements | done | Covered by PLUG-001 ## Requirements — R1–R8, R20–R22 |
| 20 | Assessment | done | Covered by PLUG-001 ## Assessment |
| 30 | POC | skipped | Covered by PLUG-001 ## POC — skipped |
| 40 | Domain | done | Covered by PLUG-001 ## Domain — 7 canonical terms |
| 50 | Architecture | done | Covered by PLUG-001 D1, D3, D4 |
| 60 | Tests | done | Covered by PLUG-001 ## Tests — T1 harness, cases 1–5, 20–26 |
| 70 | Subtasks | skipped | This task IS a slice of PLUG-001 |
| 80 | Implementation | done | 29 tests green on host + container + standalone |
| 90 | Tech Debt | done | PLUG-007 raised; PLUG-006 amended under independence constraint |
| 100 | Reflection | done | README + CLAUDE.md updated during the work |

## Description

The first valuable slice: put a fenced diagram in a `*.diagram.md` source, name the
docs that embed it, and have the fence appear and stay current in those docs.

Carries the enabling work (`lib.sh` extraction, `fm_parse`, the test harness) because
this is its first consumer — no foundation-only ticket.

**Full spec lives in PLUG-001** (Requirements R1–R8, R20–R22; Domain; Architecture
D1/D3/D4; Tests T1, cases 1–5 and 20–26). Do not duplicate it here.

## Scope

- `*.diagram.md` source format: frontmatter + exactly one fence
- `fm_parse` — one awk pass emitting the typed tab-separated stream (D4)
- `lib.sh` extraction; `fm_field` re-implemented over `fm_parse`, not beside it (D3)
- `docs.sh diagram index [--write|--check]` — AUTO-DIAGRAM block, diff-guarded
- `list_docs` excludes `*.diagram.md`
- test harness `scripts/test/diagram.test.sh`, dual-target (T0)

## Out of scope

Refs, staleness, rendering — separate sub-tasks.

## Acceptance

Cases 1–5 and 20–26 from PLUG-001 pass on both targets. Case 26 (existing `index` /
`links` unchanged) is the guard on the `lib.sh` extraction and must be written first.

## Notes

Riskiest change in the epic: D3 moves working, currently untested code. Write the
no-regression cases before touching it.

## Implementation

Delivered. Verified on three targets — host (bash 3.2 + BSD), container (`bash:5` +
GNU), and the plugin directory copied out standalone — **29 passed, 0 failed** on each.

### Files

| File | Change |
|---|---|
| `docs-manager/scripts/lib.sh` | NEW — `fm_parse`/`fm_field`/`fm_list`/`fm_map`, `normalize_path`, `block_rewrite`, `has_marker`, `write_if_changed` |
| `docs-manager/scripts/diagram.sh` | NEW — `extract_fence`, `build_diagram_block`, `doc_marker_source`, `cmd_diagram_index` |
| `docs-manager/scripts/docs.sh` | MOD — sources lib+diagram; `cmd_index` refactored onto shared helpers; `list_docs` excludes `*.diagram.md`; `diagram` subcommand; `cmd_check` extended |
| `docs-manager/scripts/test/diagram.test.sh` | NEW — 29 assertions |
| `docs-manager/README.md`, `docs-manager/CLAUDE.md` | MOD — diagram format, commands, testing, independence rule |

### Deviations from plan

1. **`cmd_check` resolves the root once.** Before, a missing root printed "No such
   root" from each sub-command; adding a third would have made it three lines. One
   check, one message, early return. Behaviour on a *valid* root is unchanged.
2. **`fm_list`/`fm_map` are shipped but unread by this slice.** Written because
   `fm_parse` produces the records anyway and the wrappers are one line each;
   PLUG-003/004 consume them without reopening `lib.sh`.
3. **No `--check` mode flag on `build_diagram_block`.** The refs line and stale
   notice hook in after the fence; the function already takes the shape those slices
   need, so they should not have to modify it.

### Verified

- 29 cases across all three targets (host / container / standalone copy)
- end-to-end by hand: marker + source → fence spliced below the marker, prose either
  side preserved, second run silent
- `docs.sh check` on this repo: unchanged behaviour (no `docs/` dir here, so it
  reports the missing root — as it did before this change)
- `git status`: only the intended files touched

### Not done

`docs-manager/skills/docs-manager/SKILL.md` was not updated — the skill's trigger
description should mention diagrams so it activates on "add a diagram to this doc".
Deliberately left: it changes when the skill fires, which is worth deciding
separately rather than folding into an implementation commit.

## Tech Debt

- **PLUG-007** raised — the docs-manager skill does not activate on diagram requests.
  Its `description:` still lists only index/links/check triggers. Held back from this
  commit deliberately: changing a skill's description changes *when it fires* in every
  project that installs the plugin, which is a behavioural change, not documentation.
- **PLUG-006 amended, not inherited.** The user's plugin-independence constraint ruled
  out its "one shared reader each plugin sources" direction mid-flight. Rather than
  leave a task whose premise is now wrong, it was re-scoped in place: duplication
  *across* plugins is correct, duplication *inside* one plugin (task-roadmap's
  `json_str` in two files) is the part still worth fixing.

No shortcuts were taken in this slice that warrant new debt. `fm_list`/`fm_map` ship
unused, which is deliberate (PLUG-003/004 consume them) and costs two lines.

## Reflection

**Docs updated as part of the work, not after:**
- `docs-manager/README.md` — a Diagrams section (source format, marker, why the fence
  is never parsed), `diagram index` in Usage, and a Testing section naming both targets.
- `docs-manager/CLAUDE.md` — the new script layout, `lib.sh`'s contract with an
  explicit "do not add a second frontmatter reader", `diagram.sh`'s don't-regress list,
  and the dual-target testing instruction.
- Both now carry the **plugin-independence rule**: nothing sources another plugin's
  file, DRY applies within a plugin, and the standalone-copy test proves it.

**Repo `CLAUDE.md`** already gained the Shell Conventions section during PLUG-001;
nothing further needed here.

**Lessons worth keeping:**
- The `lib.sh` extraction was safe only because the no-regression cases were written
  *first* and pinned behaviour that had never been tested before. Writing them took
  minutes; without them the refactor would have been unverifiable.
- `cat -A` failed on macOS mid-session — a live reminder that the GNU-only-flag trap
  is real and catches you in throwaway commands, not just shipped code.
- Running the suite in the `bash:5` container *and* on the host cost one extra command
  and is the only thing that would catch a BSD/GNU divergence. Cheap; keep it.
