---
title: "EPIC: plugins usable in Claude Desktop Cowork (no access to ~/.claude)"
status: completed
type: epic
epic-name: cowork
priority: medium
created: 2026-11-11 18:05
tags: ["crew-plugin", "delay-plugin", "docs-manager-plugin", "kickoff-plugin", "session-storage-plugin", "task-plugin", "task-roadmap-plugin"]
---

## Goal

A marketplace user who chooses to run the plugins in **Claude Desktop's Cowork** mode can do so. Cowork is a sandboxed VM that only sees the folders the user mounts, so it has no access to the host's `~/.claude`.

## Why

Today every plugin that keeps state assumes `~/.claude` (or `$CLAUDE_CONFIG_DIR`) on the host. In Cowork that location is either missing or local to the VM, and some plugins also need host tools (launchd, pmset, docker) that the VM lacks.

## Decisions (user, 2026-11-11)

- **Opt-in through detection.** The plugins detect Cowork themselves and change behaviour only inside it. The user opts in by installing the plugins in Cowork, with no setting to turn on. A manual override env var is allowed only if detection proves unreliable.
- **The CLI does not change.** Paths, behaviour and tests stay the same for users on the host.
- **Standalone in the VM.** A Cowork session does not coordinate with host sessions: it shares no crew, port registry or delay queue with them.
- **Unsupported means a plain message, never a half run.**

## Scope

- Research and POC on a real Cowork session (PLUG-111). Every other sub-task depends on it.
- One sub-task per affected plugin. They are independent of each other and can run in parallel once PLUG-111 is done.
- This repo's own `.tasks/` workflow usable from Cowork. It does not depend on PLUG-111.

## Out of Scope

- Sharing state between Cowork and host sessions.
- How a user brings their own global CLAUDE.md or memory into Cowork. That is the user's own setup, not plugin behaviour.
- The Code tab of Claude Desktop, which runs on the host and already works.

## Success Criteria

- Each plugin installed in Cowork either works or plainly reports what it can't do there.
- No behaviour change and no test change on the CLI.
- The Cowork facts (detection signal, writable paths, hooks, docker) are documented once and referenced by each plugin.

## Decisions, round 2 (user, 2026-11-11, after PLUG-111's documentation research)

This section supersedes the Goal and Decisions above wherever they disagree.

- **The requirement is project-folder-only operation.** Every plugin **except delay and session-storage MUST work with
  access to the project folder only**: no `$HOME`, no `~/.claude`. Cowork's local VM is what prompted this, but the
  requirement holds wherever HOME is unavailable. delay and session-storage are exempt because they are host-bound by design.
- **crew:** session names get a project-based prefix or hash suffix, so a name is unique without the machine-wide
  registry. Slots get a scope, **project and/or machine**. Machine scope requires access to HOME; project scope must not.
- **kickoff:** the port registry gets a project-folder fallback, and kickoff **asks the user** whether to keep the port list in HOME.
- **task:** a project `.task-config.json` already avoids the global config. The open gap is the workflow step definitions,
  which are read from `~/.claude/project-tasks/_workflow/` when the project lacks them. PLUG-118 decides their project-folder-only source.
- **docs-manager, task-roadmap:** need nothing from HOME; PLUG-123 only confirms it.
- **Consequence (confirmed by user, 2026-11-11):** where a plugin uses HOME is now decided by an explicit
  choice (crew's slot scope, kickoff's question) plus a fallback when HOME is missing or unwritable. Automatic Cowork
  detection is dropped entirely: no plugin checks for Cowork.
- **Out of scope:** support for cloud Cowork. Its sandbox has no project folder for a script to work in (see PLUG-111, POC part 1).

## Current State (2026-11-11 19:04)

- Completed: PLUG-111 (research), 118 (task), 120 (delay), 121 (kickoff), 122 (session-storage), 123 (docs-manager,
  task-roadmap), 124 (WORKFLOW.md note). Each was verified on the host and in `bash:5`, with the test seen red on a reverted copy.
- In progress: PLUG-119 (crew), with an agent implementing it. It then needs review, the same checks, and the crew release.
- Release (uncommitted): delay 2.1.1, session-storage 1.0.1, kickoff 0.11.0 (plugin.json + marketplace). The task fix
  goes out in 1.6.0, which another session's work already bumped. docs-manager and task-roadmap: docs only, no bump.
- Follow-ups outside the epic: PLUG-131 (one-line `.task-config.json` misread), PLUG-132 (session-storage hardening).
- Nothing committed.

## Result (2026-11-11)

Every sub-task is completed, and each plugin's suite passes on the host and in its container.
- task 1.6.0: the fix goes out in that release, bumped by other work.
- delay 2.1.1 and session-storage 1.0.1.
- kickoff 0.11.0 and crew 2.6.0.
- docs-manager and task-roadmap: docs only.

Root README has a new *The project folder is enough* bullet.

Success criteria, checked:
- **Works or plainly says what it can't:** met. Five plugins work from the project folder. delay refuses to queue
  with one sentence. session-storage never used HOME and now fails plainly when its tmp can't be written.
- **No behaviour change on the CLI:** met, with two changes the user asked for (round 2):
  - kickoff asks once before keeping the port list in HOME, for a project with no existing `ports.json`. An existing
    one counts as "yes", so upgrades are silent. `ports.test.sh` setup now records that choice, and its case bodies are unchanged.
  - crew gains `slotScope` and `namePrefix`. Both default to today's behaviour while HOME is usable.
- **Cowork facts documented once:** superseded by round 2. Detection was dropped, so there is no detection signal to
  document. The facts are in PLUG-111, and the rule they led to is root `CLAUDE.md` *Without HOME*. Each plugin's
  CLAUDE.md points at that rule instead of repeating it.

Follow-ups: PLUG-131 (one-line `.task-config.json`), PLUG-132 (session-storage hardening). Nothing committed.

## Commit (2026-11-11)

- At the user's request, no version is bumped. The bumps listed in *Current State* and *Result* were reverted, and
  the marketplace and every `plugin.json` stay at their released versions. Bumping is left to a release.
- Committed: crew, kickoff, delay and session-storage code, docs and tests; the docs-manager and task-roadmap notes;
  WORKFLOW.md; the root CLAUDE.md *Without HOME* rule; the README bullet; the epic's task files.
- Not committed: PLUG-118's task plugin code, which is entangled with in-flight task work (see PLUG-118 *Commit note*).
