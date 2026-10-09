---
title: crew — adopt mid-project: config set, hold import, adoption guide
status: completed
type: feature
epic: crew-feedback
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | config.sh was read-only; holds had no bulk path |
| 20 | Requirements | done | acceptance criteria below; checklist reordered (join before import) |
| 30 | Assessment | done | config.sh + holds.sh (not hot); SKILL + README hot, held at the end |
| 40 | POC | skipped | not needed |
| 50 | Domain | skipped | no new concepts |
| 60 | Architecture | done | see Architecture |
| 70 | Tests | done | adopt.test.sh, red first |
| 80 | Subtasks | skipped | one slice |
| 90 | Implementation | done | applied to the tree, awaiting land |
| 100 | Tech Debt | done | none added |
| 110 | Reflection | done | see Reflection |

## Description

Feedback #4. Adopting crew mid-project has no import path. Today the hot spots live in the
project's CLAUDE.md, the holds in a hand-kept `_holds.md` bullet list, and `hotSpots` in crew is
empty.

- **`crew config set|unset [--user] <key> <value…>`** writes `.crew.json` (or the user file),
  validating key and layer. An array key such as `hotSpots` takes several values.
- **`crew hold import <file> [--dry-run]`**: one hold per bullet `- <path> — <holder> (…)`. The
  separators `—`, `-`, `:` and `by` are all accepted. A holder that is not in the crew is
  reported, not invented, and `--dry-run` shows the plan.
- **`references/adopt.md`:** the mid-project checklist:
  1. set the hot spots;
  2. import the holds;
  3. everyone joins (automatic with titled sessions);
  4. cut the hand-written session rules from the project's CLAUDE.md that crew now enforces,
     keeping the project-specific ones;
  5. pick the committer mode.
- SKILL pointer row; README.

## Acceptance criteria

- [x] `config set hotSpots a.ts 'src/*.ts'` writes a valid `.crew.json`, keeping other keys.
      `config set --user sharedBranch x` is refused, because the key is project-only.
- [x] `hold import` on a sample bullet file creates the holds. An unknown holder is listed, not
      held. `--dry-run` changes nothing.
- [x] `adopt.md` exists and SKILL points to it.
- [x] Suites pass on host + docker.

## Context

`config.sh` only printed the effective config, and holds were taken one path at a time. A project
adopting crew had to write `.crew.json` by hand and re-enter its holds.

## Architecture

- **`config set|unset [--user] <key> [value…]`** (`config.sh`). It refuses unknown keys, a
  project-only key with `--user`, a bad enum (`committer`, `hookMode`), a non-number for the
  numeric keys, several values for a scalar key, and `"` or `\` (which `cfg_parse` cannot read).
  `write_layer` re-reads the layer under the lock and re-emits it as typed JSON: `hotSpots` is
  an array, the three numeric keys are bare, and everything else is a string. A key crew does not
  know keeps its shape (array, bare number or `true`/`false`/`null`, or string). Writes are
  diff-guarded through `replace_file`.
  - **The lock only when a crew exists:** `with_lock` creates `$STATE`, and that would switch
    crew on for a repo just by setting config.
- **`hold import <file> [--dry-run]`** (`holds.sh`), coordinator only, because it takes holds for
  other sessions. `import_parse` reads a bullet (`-` or `*`). The earliest of ` — `, ` – `, ` - `,
  `: ` or ` by ` wins, so a path may contain a hyphen and the note may contain separators.
  Backticks and `*` are stripped and a leading `@` is dropped; a task id is taken from the
  parentheses. It emits a kind column (`ok`/`bad`), because `read` collapses empty
  tab-separated fields. `import_member` resolves a crew name, its slug (`name_for`) or a display
  name. The outcomes: unknown holder → listed, rc 1; held by another → REFUSED, rc 1; same holder
  → left; glob → skipped (it belongs in `hotSpots`); a bullet without a separator → skipped.
- **Checklist order changed** from the description: config → join → import → cut rules. An
  import needs an active crew and holders who have joined. **The coordinator's decision** (2026-10-09),
  on PLUG-W2's proposal.

## Tests

`crew/scripts/test/adopt.test.sh`, 52 checks, green on the host and in `crew-test`. Every suite is
green on both. Written first: 33 red on HEAD.

**Shown failing:**
- `locked` always taking the lock fails "…without switching crew on";
- dropping the dry-run guard in `_import` fails "dry run: nothing changed";
- the last separator winning instead of the earliest fails "the earliest separator wins". This
  check was added after that mutation first survived.

## Implementation

`crew/scripts/config.sh`, `crew/scripts/holds.sh`, `crew/scripts/test/adopt.test.sh`,
`crew/skills/crew/references/{adopt,config,holds}.md`, `crew/skills/crew/SKILL.md` (trigger phrases, pointer
row to adopt.md, config row), `crew/README.md` (config set/unset, hold import rows).

## Tech Debt

None added.

## Reflection

The adoption order lives in `references/adopt.md`. The "lock only when a crew exists" rule is in
the comment on `locked()`. A future config writer outside `config.sh` would need it too.
