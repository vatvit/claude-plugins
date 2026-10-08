---
title: docs-manager external docs — staleness check (new / changed / orphaned)
status: completed
type: feature
priority: medium
epic: external-docs
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | PLUG-017 Context covers it (same session, same files) |
| 20 | Requirements | skipped | ACs specific enough |
| 30 | Assessment | done | mirrors `diagram check`/`bless`; `fm_set` already preserves bytes |
| 40 | POC | skipped | sha tools known: `shasum` (BSD/macOS), `sha256sum` (GNU/busybox) |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | see Architecture |
| 70 | Tests | done | S1–S4 in `external.test.sh` |
| 80 | Subtasks | skipped | small enough |
| 90 | Implementation | done | 40/40 host + bash:5 |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | covered by PLUG-017's doc updates |

## Description

`docs.sh check` (and a dedicated subcommand) reports external files that are **new** (no
card), **changed** (card `digest` ≠ file sha256) and **orphaned** cards (source missing).
sha256 via `shasum -a 256` / `sha256sum`, one helper in `lib.sh`. Never hashes a path.

## Acceptance criteria

1. Each of the three states is reported with the file path; clean tree reports nothing.
2. A `--stamp` (or similar) writes the current digest into a card, diff-guarded.
3. Which extensions count as "external" is one list, configurable via `.docs-manager.json`
   with a working default.
4. Tests for all states; host + container.

## Context

Same session as PLUG-017 — its `## Context` applies unchanged. In particular the config-file rule:
AC 3's `.docs-manager.json` is replaced by the built-in `EXTERNAL_EXTS` list (one list, one place).

## Architecture

- `docs.sh external status [root]` — machine records `state<TAB>place<TAB>file<TAB>card`, `-` for an
  empty field. States: `ok | new | unstamped | changed | orphan`. Places: `filed | unfiled | outside`.
- `docs.sh external check [root]` — human lines `NO CARD` / `UNSTAMPED` / `CHANGED` / `ORPHAN CARD`,
  each naming the path and the next command; silent and rc 0 when clean. Part of `docs.sh check`.
- `docs.sh external stamp <file-or-card>` — the **only** writer of `digest: sha256:<hex>`; the
  `bless` pattern. Diff-guarded (`UNCHANGED:` and no write when current); `fm_set` keeps every
  other byte of the card.
- `unstamped` is a fourth state beyond the AC's three: a hand-written card with no digest is
  neither new nor changed, and must not pass `check` silently.
- Placement is reported by `status` only and never fails `check` (a carded file kept beside the doc
  using it is a choice).
- `sha256_of` lives in `external.sh`, not `lib.sh` as the description said: `lib.sh` holds what
  more than one script needs, and only `external.sh` hashes bytes.

## Implementation

`scripts/external.sh` (`external_status`, `cmd_external_{status,check,stamp}`, `sha256_of`,
`external_place`). Tests S1 (four states, three places, upper-case extension, `docs.sh check`
integration), S2 (stamp, idempotence, byte preservation, change detection, silent clean check),
S3 (digest survives moving the checkout — the committed-path rule), S4 (stamp errors).
`external.test.sh` 40/40 on host bash 3.2 and bash:5.

Found while testing: `read` with `IFS=$'\t'` collapses consecutive tabs (tab is whitespace), so
an orphan's empty fields shifted its card path into the wrong variable. Fixed with `-` placeholders;
recorded in docs-manager `CLAUDE.md`.

## Current State

Done; ACs 1, 2, 4 met; AC 3 met as a built-in list (no config file — see Context). Not committed.
