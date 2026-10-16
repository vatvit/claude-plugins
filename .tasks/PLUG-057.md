---
title: crew — commits and pushes are the user's call per project; by default nobody commits or pushes
status: completed
type: feature
priority: high
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | the default committer=coordinator plus the skill ("lands hand-offs, pushes") let a marketplace install commit and push on its own |
| 20 | Requirements | done | user, 2026-10-16: ask the human per project; by default no commit, no push. Agreed: a direct commit is not denied; a user-layer value counts as decided |
| 30 | Assessment | done | push is skill text plus the guard; the default lives in cfg_default; land.test.sh relied on the old default |
| 40 | POC | skipped | a default and one key |
| 50 | Domain | skipped | no new concept |
| 60 | Architecture | done | key push (human / committer); crew_pushes in land.sh; git_policy_note in lib.sh, printed by status and the coordinator SessionStart line |
| 70 | Tests | done | land (16 new), core, adopt; red before the change (13 + 3) and under two mutations (old defaults: 9 + 3; push rule gone: 6) |
| 80 | Subtasks | skipped | one slice |
| 90 | Implementation | done | crew 1.6.0 -> 2.0.0; 492/492 on host bash 3.2 and on bash:5 |
| 100 | Tech Debt | done | none added |
| 110 | Reflection | done | crew CLAUDE.md design rule; SKILL.md, references (config, land, playbook, adopt — also its stale auto-join line), crew README, root README, plugin.json, marketplace.json |

## Description

The user, 2026-10-16: "the crew should ask the human how to on this particular project to do.
by default - do not commit, do not push".

Today `committer` defaults to `coordinator`, and the skill gives the coordinator the job
"lands hand-offs (`land`), pushes, and checks the push". So a crew installed from the public
marketplace commits and pushes on its own unless the user's own rules say otherwise. Nothing
in crew pushes by script; the push comes from the skill text, and the guard allows it for the
coordinator.

## Proposal (to agree before coding)

1. **Default: nobody commits, nobody pushes.** `committer` defaults to `human-approved`
   (`land` runs its checks and prints the exact `git add` / `git commit` for the user).
2. **A new key `push`**: `human` (default) | `committer`. Under `human`, the guard denies
   `git push` for every member, and `land prepush` ends with the command for the user to run.
   Under `committer`, whoever may commit may push (today's behaviour). A separate key because
   "commits on its own, pushes only when I say" is a real combination.
3. **Undecided is visible and asked once.** When neither layer (project `.crew.json`, user
   `crew.json`) sets `committer` or `push`, the coordinator's SessionStart line and `status`
   say: commits/pushes for this project are not decided — ask the user, then
   `crew config set committer <mode>` / `crew config set push <mode>`. The skill: the coordinator
   asks the user once per project and records only the user's answer, never its own choice.
4. **Skill text**: the coordinator role "lands and pushes **as `committer` / `push` allow**";
   task status closes after the work is landed and verified (pushed only if `push` lets the crew
   push).
5. **Existing crews**: an explicit `committer` in a config keeps working; `push` is new, so a
   crew that pushed before stops pushing until the user sets `push committer`. A changed
   default → crew 2.0.0.

## Open questions

- Under `human-approved`, should the guard also deny a direct `git commit` by members? Today it
  does not (only `committer=coordinator` restricts it), so a session could bypass `land`. If it
  denies, "the user approves and Claude runs it" stops working — the user would run it with
  `! git commit …`.
- Does a value in the **user** layer count as decided for every project, or must each project
  decide (keys made project-only, like `sharedBranch`)?

## Current State

Implemented and verified (492/492, host and bash:5); not committed. This repo's own `.crew.json` sets
`committer: coordinator` but no `push`, so its crew can no longer push until the user sets `push`.
