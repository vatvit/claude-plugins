---
title: kickoff plugin — the new-project questionnaire
status: in-progress
type: epic
epic-name: kickoff
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | — | |
| 20 | Requirements | — | |
| 30 | Assessment | — | |
| 40 | POC | — | |
| 50 | Domain | — | |
| 60 | Architecture | — | |
| 70 | Tests | — | |
| 80 | Subtasks | — | |
| 90 | Implementation | — | |
| 100 | Tech Debt | — | |
| 110 | Reflection | — | |

## Goal

A new plugin, **kickoff**: when the user starts a project, it walks them through one standard
questionnaire. The questions branch on earlier answers, offer pre-defined options with a default,
and turn the answers into the project's starting context. That saves time, avoids
misunderstanding in both directions, and makes the user's projects and the way they work with
Claude consistent.

## Why

At every kickoff the user types much the same starting context by hand (for example the
sample-poc kickoff, 2026-10-08). The questions repeat; the answers may or may not. Free-text
context is slow and can be read two ways on either side.

## Source material

- **The questionnaire (agreed 2026-10-08):** `kickoff/skills/kickoff/references/questionnaire.md`.
  It is the spec: sections, options, ★ defaults, branching, outputs, and where kickoff keeps its own data.
- **Template outputs:** sample-poc `docs/project/poc-charter.md` (a charter with a numbered decisions table).
- **Survey of 19 project CLAUDE.md files (2026-10-08).** The generic rules are already in the global
  CLAUDE.md, so kickoff never asks about them. Only exceptions are asked (E5).

## Scope

- A skill that runs the questionnaire one section at a time, with "accept all defaults" or change some.
- It writes the outputs: `docs/project/charter.md`, the `docs/` skeleton, a small project CLAUDE.md,
  `.task-config.json` and the workflow, and the first tasks.
- Port registry `~/.claude/kickoff/ports.json` (machine-wide), with a fallback that scans compose files.
- Per-account defaults `${CLAUDE_CONFIG_DIR:-~/.claude}/kickoff.json`, which override the ★ answers.
- Existing projects (A0): read what is there and ask only about the gaps.
- It uses task, docs-manager, crew and task-roadmap when they are installed, and works without them
  (plugin independence).

## Out of scope

- Copying global rules into project files.
- Choosing the stack from a fixed list. I4 is a proposal by Claude, the user picks.
- Cleaning up old projects. This could be a later use of the "existing project" mode.
- Crew's parallel-session rules. Kickoff only switches crew on (R5).

## Success criteria

- A new empty repo, after one kickoff run, has a charter, a docs skeleton, a CLAUDE.md, a task config and its
  first tasks. The run needs no free-text context from the user beyond the free-text questions.
- Replaying the sample-poc kickoff through the questionnaire reproduces its charter decisions D1–D5 and D7.
- Re-running kickoff on the same project changes nothing (idempotent).
- Two Claude accounts on one machine never get the same dev port.
- The test suite passes in Docker, and also from a copy of the plugin with no siblings.

## Design notes (negotiable, settle at Architecture)

- **Answers are a file.** The interview writes the answers to a file (for example
  `docs/project/kickoff-answers.*`); scaffold scripts read that file and generate the outputs.
  This makes generation deterministic and testable in bash without driving an interview, and it gives
  re-runs and the existing-project mode something to diff against.
- **Trigger words:** *kickoff / new project / start a project / bootstrap / set up a project*. Never *init*,
  which belongs to the built-in `/init`. Check against the other plugins' vocabularies (repo CLAUDE.md).

## Slices

1. **Interview → charter.** Plugin skeleton and marketplace entry; the skill runs sections A–F and writes
   `docs/project/charter.md` with the decisions table and open questions. This is the first vertical slice.
2. **Setup scaffold.** Sections R and K produce `.task-config.json`, the workflow, the `docs/` skeleton, the
   project CLAUDE.md and the first tasks. Needs slice 1.
3. **Port registry.** Allocate and list ports, machine-wide, with the compose-file scan fallback. Its own
   script and tests. **Can run in parallel with slice 1.**
4. **Per-account defaults.** `kickoff.json` overrides the ★ answers. Needs slice 1.
5. **Existing project mode** (A0). Audits the gaps and asks only those. Needs slices 1 and 2.

Chain: 1 → {2, 4} → 5. Slice 3 is independent of all of them. The hot spots shared by every slice are
`plugin.json`, `marketplace.json` and `SKILL.md`.

## Sub-tasks

- PLUG-035: interview to charter: plugin skeleton, sections A–F (first)
- PLUG-036: setup scaffold: sections R and K (needs 035)
- PLUG-037: machine-wide port registry (independent: parallel with 035)
- PLUG-038: per-account defaults, kickoff.json (needs 035)
- PLUG-039: existing-project mode, A0 (needs 035 and 036)

## Current State

All five sub-tasks are completed (PLUG-035..039). kickoff 0.5.0 ships the interview, the charter, the setup scaffold, the port registry, per-account defaults and existing-project mode, with 172 checks green on both test targets.

Deviations from the epic text, each recorded in its task:
- The compose scan always runs (PLUG-037).
- The first tasks are created through /task, not by kickoff (PLUG-036).
- sample-poc D1 is a global rule, so it is never asked (PLUG-035).

Not yet done: a live kickoff run by Claude through the skill. The scripts are tested end to end; the SKILL.md loop is not.
