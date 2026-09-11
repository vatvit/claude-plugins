---
title: Optional render port (project-supplied command)
status: proposed
type: feature
priority: low
epic: diagram-support
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Requirements | — | |
| 20 | Assessment | — | |
| 30 | POC | — | |
| 40 | Domain | — | |
| 50 | Architecture | — | |
| 60 | Tests | — | |
| 70 | Subtasks | — | |
| 80 | Implementation | — | |
| 90 | Tech Debt | — | |
| 100 | Reflection | — | |

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
