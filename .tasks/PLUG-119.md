---
title: "crew — work with the project folder only: project-scoped names and slots, machine scope optional"
status: completed
type: feature
priority: medium
epic: cowork
created: 2026-11-11 18:05
tags: ["crew-plugin"]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | below |
| 20 | Requirements | done | acceptance criteria above + epic round 2 |
| 30 | Assessment | done | below |
| 40 | POC | skipped | no unknowns; the home.test.sh modes (unset / missing / file) were the probe |
| 60 | Architecture | done | below |
| 70 | Tests | done | crew/scripts/test/home.test.sh, red first (48 of 75 failed), then green |
| 90 | Implementation | done | lib.sh, slot.sh, whoami.sh, config.sh, end.sh, time.sh |
| 100 | Tech Debt | done | none new: one helper per concern (crew_home_ok, name_prefix, slot_scope, crew_config_dir) |
| 110 | Reflection | done | crew/CLAUDE.md, README, references/slots.md, config.md, SKILL.md |

## Description

Requirement and decisions: epic PLUG-117, *Decisions, round 2*. Facts about the environment: PLUG-111.
This task no longer waits for PLUG-111. The requirement does not depend on Cowork internals, so it can start now.

What it keeps in HOME today: `~/.claude/crew/names` (a machine-unique session-name registry), `crew/slots` and `slots.log` (the machine-wide
slot queue), and `crew/ended`; plus the optional `crew.json` user layer and transcripts under `~/.claude*/projects/` (`crew time`).
`lib.sh:13-18` defines `CREW_HOME` and `CREW_USER_CONFIG`.

Decided (user):
- **Session names** get a project-based prefix or hash suffix, so they are unique without the machine registry.
  Choose prefix vs hash, and its length, at Architecture. Names must stay short enough to type in SendMessage.
- **Slots get a scope: project and/or machine.** Project scope lives in the project folder and needs no HOME. Machine
  scope needs HOME, and keeps today's cross-repo and cross-account coordination (PLUG-074, PLUG-101).

To decide: the config key for the scope and its default, which must keep today's behaviour when HOME is there; where
project-scoped state lives in the repo and that it is git-ignored; what `crew time` does without transcripts.
Check crew holds first: a crew is active in this repo.

## Acceptance criteria (common to the project-folder-only sub-tasks of the epic)

- **Project folder only:** with HOME unavailable (unset, missing or not writable) and only the project folder writable, every
  capability works. The exception is a capability the user explicitly chose to keep in HOME: it says plainly that it
  needs HOME and does nothing else.
- **HOME available:** existing behaviour and defaults are unchanged unless the epic says otherwise, and the existing suite passes.
- **Upgrade needs no action:** a user moving from the previous version keeps working with no migration step, no new prompt and no
  lost state. A test runs the new version against state written by the old one (a fixture copied from the current format).
  crew: a crew that is running during the upgrade keeps its names. The new naming applies only to the next `whoami`, and a peer that addresses an old name still reaches it. The slot default stays machine scope.
- Tests simulate project-folder-only by running with HOME pointed at a missing or read-only dir, in the Alpine container.
- Plugin Independence: the plugin carries its own fallback logic. No code is shared with another plugin.

## Context

Where crew touched HOME: `CREW_HOME` (`names/` registry, `slots`, `slots.log`, `slots.seq`, `slots.wait`, `ended`), the user layer
`crew.json`, and `crew time` reading transcripts under `~/.claude*/projects`. Under `set -u` a bare `$HOME` also aborted every
script when HOME was unset. Crew held no other machine state.

## Assessment

Names: crew cannot rename a Claude session. `whoami "<name>"` records the name peers type in SendMessage (the *display*, slugged to the
crew name); uniqueness came only from the registry check in `whoami`. Slot ownership is by name, and a slot's liveness came from the
registry (`reg_live`), so dropping the registry also needed a liveness rule inside one crew.

## Architecture (decisions)

- **One test, `crew_home_ok`** (lib.sh): can make `CREW_HOME` and a temp file in it. Kept per process. Everything in HOME is used only after it.
- **Names: prefix, not hash.** Peers type names; `myproj-ann` says whose it is, a hash suffix does not. The prefix is `<crewId>-` (crewId
  defaults to the repo folder, and the user can shorten it). It is applied to the typed display, since peers address the display.
  `namePrefix` (project key): `auto` (default: only when there is no usable HOME), `always`, `never`. With a HOME nothing changes
  (names stay as typed, the registry still guards them), so the upgrade needs no action. A member already in keeps its name (no rename
  on a re-join), and the pre-bash hook's parked session id is looked up under the name as typed, before the prefix.
- **No HOME, no registry:** `reg_set/get/drop` do nothing, `reg_live` is "the session file is in this crew's `sessions/`" (the sid check
  only mattered across crews), `reg_other` is empty.
- **Slots: `slotScope` (project key) `machine` (default) | `project`.** `slots_dir` is `CREW_HOME` or `$STATE`. Machine without a usable HOME
  falls back to project and says `slots: project scope — HOME not writable ...` once per crew (marker `$STATE/slot-scope-said`).
  `STATE` is removed at `crew end`, so project queue, log and marker leave with the crew; nothing needs a .gitignore line.
  `slot.sh` finds its files with `slot_paths`, because the area is sourced before `crew_init` in places.
- **Out of scope in HOME on purpose:** `ended` (a machine log) is simply not written without a HOME; `config set --user` dies naming HOME and
  pointing at the project layer; `crew time` reads no transcripts without a HOME (it already tolerated a member with none).
- `time.sh` and the config dir share `crew_config_dir` (one place for `CLAUDE_CONFIG_DIR` or `~/.claude`).

## Result

New `home.test.sh`: 78 checks (HOME unset, HOME under a plain file, HOME uncreatable; HOME-usable defaults; upgrade fixture: old
names registry, old slot row, old sessions, then the same crew with HOME gone). Before the code 48 of 75 failed. Whole crew suite
939 checks green on the host and in the Alpine container (861 before). Recommended: crew 2.6.0 (new config keys, new behaviour).

## Current State

Implemented and verified (see Result); not committed, task status left as `proposed` for the caller. Open: version bump, marketplace and
root README text (recommended in the hand-off), and the caller's decision on status.

## Current State (original)

Created 2026-11-11 as a Cowork placeholder. Reshaped the same day into a project-folder-only task after the user's round-2 decisions. Not started.

## Review (epic coordinator, 2026-11-11)

- Re-ran `crew/scripts/test/run.sh` on the host (bash 3.2, BSD) and in the `crew-test` image: 939 passed, 0 failed on both.
- Third red check, which the implementer could not finish: in a temp copy outside the repo, `slot_scope` ignored
  `slotScope: project`. home.test.sh: 1 red ("slotScope=project keeps the queue in the project"), 77 green.
- Accepted trade-off: without HOME, two repos on one machine do not see each other's slot queue (each is
  project-scoped). This follows from the user's decision that machine scope requires HOME.
- Release: crew 2.5.0 → 2.6.0 (new keys `slotScope`, `namePrefix`), done in the epic's release step.
