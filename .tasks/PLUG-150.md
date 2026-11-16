---
title: "Upgrading notes: what a project must do after a plugin update, per release"
status: completed
type: feature
priority: medium
tags: ["quality"]
created: 2026-11-16 17:41
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | conversation 2026-11-16 after the remote-docs, docs-manager, task and kickoff releases |
| 20 | Requirements | done | Acceptance Criteria above; the optional check was built |
| 30 | Assessment | done | ready, no dependencies |
| 40 | POC | skipped | doc text and one awk check |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | ## Architecture |
| 70 | Tests | done | UP1–UP6 in check-descriptions.test.sh, 4 seen red; a repo copy without docs-manager's 2.0.0 entry fails |
| 80 | Subtasks | skipped | one change |
| 90 | Implementation | done | ## Implementation |
| 100 | Tech Debt | done | name kept: see ## Implementation |
| 110 | Reflection | done | root CLAUDE.md step 5 and check text; root README Update steps and Development |

## Problem

After `/plugin` updates, a user has no place to read what each release needs in their projects. The
README says what a plugin does, not what changed for an existing project. Example: docs-manager 2.0.0
stopped managing remote cards (remote-docs must be installed), and remote-docs 1.1.0 makes `check` fail
on existing artifact cards until they are reviewed for decisions. Both were known only in conversation.

## Goal

Every plugin README has an **Upgrading** section: one entry per release that needs action in a project
(nothing for a release that needs none), saying what to do and which check reports it. The release
rule in the root CLAUDE.md requires the entry, so it is not forgotten.

## Scope

- An `## Upgrading` section in each plugin's README, newest first: `### <version>` + what to do.
- Backfill the releases of 2026-11-16: docs-manager 2.0.0, remote-docs 1.1.0 (PURPOSE?, EXTRACT?,
  per-key `.source.md`), task 1.7.0 and kickoff 0.12.0 (nothing required; how to opt in).
- Root README: a short *Updating the plugins* paragraph — update, `/reload-plugins` in every running
  session, run each plugin's check in each project, read the Upgrading section.
- Root CLAUDE.md, *Changing an Existing Plugin*: a step requiring the Upgrading entry when a release
  changes what a project must do (a breaking change, a check that newly fails, a moved capability).
- Consider: `scripts/check-descriptions.sh` (or a sibling) failing a major bump with no Upgrading entry
  for that version.

## Out of Scope

- A full changelog of every change (git history holds that).
- Automated migration scripts.

## Acceptance Criteria

- Each plugin README has an Upgrading section; the four releases above are covered.
- Root README tells a user how to update and where to read what to do.
- Root CLAUDE.md release steps include the Upgrading entry.
- If the check is added: it fails a major bump without an entry, with a test seen failing first.

## Architecture

- Each plugin README: `## Upgrading` (before `## License` where there is one), a short intro (a release
  not listed needs nothing beyond updating and `/reload-plugins`), then `### <version>` entries, newest
  first.
- `scripts/check-descriptions.sh` gains the check (`upgrading_entry`, `major_release`): every README has
  the section; a major release X.0.0 with X ≥ 2 has its entry inside it. 1.0.0 is a first release and
  needs none. Extended rather than a sibling script, so the marketplace parsing stays one copy.

## Implementation (2026-11-16)

As designed. Backfilled entries: docs-manager 2.0.0, remote-docs 1.1.0, task 1.7.0, kickoff 0.12.0;
the other four have the section with no entries. Root README *Update* now lists reload every session,
read Upgrading, run the checks. Root CLAUDE.md *Changing an Existing Plugin* step 5.

Name kept as `check-descriptions.sh` although it now checks READMEs too: renaming would break the
command other sessions run from CLAUDE.md for no gain in behaviour. Rename it in a quiet moment if the
name starts to mislead. Tests 13/13 on host and `bash:5`.

## Current State

Completed 2026-11-16.
