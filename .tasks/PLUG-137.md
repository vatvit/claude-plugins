---
title: "Short plugin descriptions with a length limit and a sync check"
status: completed
type: bugfix
priority: medium
tags: ["quality"]
created: 2026-11-11 20:39
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | rule source: root CLAUDE.md *Changing an Existing Plugin* step 1; no prior length rule; task, task-roadmap files out of sync |
| 20 | Requirements | skipped | acceptance criteria in task |
| 30 | Assessment | done | only delay reads plugin.json (version, any value); no test pins a description |
| 40 | POC | skipped | nothing risky |
| 50 | Domain Lens | skipped | n/a |
| 60 | Architecture | done | repo-root `scripts/` as release tooling, not a plugin; awk reads one field per line; characters counted by dropping UTF-8 continuation bytes |
| 70 | Tests | done | scripts/test/check-descriptions.test.sh, 7 cases; repo case red on the old descriptions (5 over limit, 2 mismatches) |
| 80 | Subtasks | skipped | small |
| 90 | Implementation | done | check script; 7 descriptions rewritten; patch bumps in both files |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | rule + check in root CLAUDE.md; README Development; scripts/ in repo tree |

## Description

The `/plugin` marketplace screen shows each plugin's description in full, and five of seven had grown into
changelogs (crew 2570 chars, kickoff 2380, docs-manager 1116, delay 822, task 805). Cause: root `CLAUDE.md`,
*Changing an Existing Plugin*, step 1 says "refresh `description`" on every capability change, which each release
read as "append the new feature", with no limit. task and task-roadmap had also drifted: `plugin.json` and
`marketplace.json` no longer said the same thing.

The feature detail already lives in the root `README.md` and each plugin's README; the description is a pitch.

## Acceptance criteria

- Every plugin's description is at most 250 characters and says what the plugin is for, not what releases added.
- `plugin.json` and `marketplace.json` carry the identical description and version for each plugin.
- A repo-level check script fails (non-zero, names the plugin) on a description over the limit or a mismatch
  between the two files, and passes on the repo as it is. Seen red on a reintroduced long description.
- Root `CLAUDE.md` states the rule: a description is a pitch with a hard limit; new capabilities go to the README and
  the SKILL.md trigger phrases; run the check before a release.
- Each plugin gets a patch version bump so installed users see the new text.

## Result (2026-11-11)

- `scripts/check-descriptions.sh` (bash + awk): fails with `FAIL <plugin>: …` on a description over 250
  characters or a description/version mismatch between `plugin.json` and `marketplace.json`; exit 2 when
  there is no marketplace file. Characters, not bytes, so an em dash counts once on BSD and busybox.
- `scripts/test/check-descriptions.test.sh`: 7 cases, green on the host and in `bash:5`. The repo case was
  seen red before the rewrite (task, docs-manager, delay, crew, kickoff over the limit; task and
  task-roadmap out of sync).
- Descriptions rewritten to the agreed drafts (100–181 characters); patch bumps: task 1.6.1,
  session-storage 1.0.2, docs-manager 1.12.1, task-roadmap 1.1.1, delay 2.1.2, crew 2.6.1, kickoff 0.11.1.
- Root CLAUDE.md: step 1 no longer says "refresh description"; new paragraph states the 250-character
  pitch rule and to run the check before a release. README *Development* names the check.

## Current State

Completed. Nothing committed: the change waits for the user's commit approval.
