---
title: docs-manager skill should activate on diagram requests
status: completed
type: docs
priority: low
epic: diagram-support
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Requirements | done | Trigger phrases + no collision with task-roadmap |
| 20 | Assessment | done | Compared all 3 plugin skill descriptions — no shared vocabulary |
| 30 | POC | skipped | Frontmatter + prose edit; nothing to prototype |
| 40 | Domain | done | PLUG-001 ## Domain — use the canonical terms verbatim |
| 50 | Architecture | skipped | No structural decision; SKILL.md links out rather than restating |
| 60 | Tests | skipped | Skill activation is not scriptable; verified by inspection |
| 70 | Subtasks | skipped | This task IS a slice of PLUG-001 |
| 80 | Implementation | done | skill triggers + Diagrams guidance; plugin 1.0.0 → 1.1.0 |
| 90 | Tech Debt | done | none; stale manifest fixed in place |
| 100 | Reflection | done | repo CLAUDE.md gained "Changing an Existing Plugin" |

## Description

Raised by PLUG-002. `docs-manager/skills/docs-manager/SKILL.md` documents `index`,
`links` and `check`, and its `description:` frontmatter lists only those triggers. The
`diagram` subcommand shipped in PLUG-002 is invisible to the skill, so asking "add a
diagram to this doc" or "update the diagram" will not activate docs-manager.

Held back from the PLUG-002 commit deliberately: changing a skill's `description:`
changes *when the skill fires* across every project that installs the plugin. That is
a behavioural change to activation, not documentation, and deserves its own decision.

## Scope

- extend the SKILL.md `description:` with diagram triggers
- document the source format and `diagram index` in the skill body
- keep the conventions section authoritative — link, do not restate the README

## Open question

How aggressive should activation be? "generate the roadmap"-style phrasing risks
colliding with the `task-roadmap` plugin's triggers, and the two must not fight over
the same prompts. Worth checking `task-roadmap`'s description before widening this one.

## Depends on

PLUG-002 (shipped).

## Implementation

Delivered. The skill now activates on diagram work, and the plugin advertises what it
actually does.

### The open question, resolved

The task flagged a risk of trigger collision with `task-roadmap`. Audited all three
plugin skill descriptions word by word:

| trigger | docs-manager | task-roadmap | session-storage |
|---|---|---|---|
| diagram / picture / draw | ✅ | — | — |
| roadmap / gantt / timeline | — | ✅ | — |
| docs index | ✅ | — | — |
| storage | — | — | ✅ |

**Zero overlap.** Every trigger word is exclusive to one plugin, so diagram vocabulary
could be added freely — only the words "roadmap", "gantt" and "timeline" had to be
avoided, and they were.

### Changes

| File | Change |
|---|---|
| `skills/docs-manager/SKILL.md` | `description:` gains diagram triggers; new `## Diagrams` section; `diagram` commands in the Tool block; skill version → 1.1.0 |
| `.claude-plugin/plugin.json` | version → 1.1.0, description rewritten, `diagrams`/`mermaid` keywords |
| `.claude-plugin/marketplace.json` | docs-manager entry synced to match |
| `README.md` | headline feature list gains refs and staleness bullets |

### Beyond the ticket, deliberately

The version bump and manifest refresh were not in scope, but the plugin was
advertising itself at **1.0.0 with a description written before the entire diagram
feature existed** — in the marketplace, which is how people decide whether to install
it. Leaving that stale while adding the skill triggers would have been odd. Flagged
rather than silent.

### Behavioural guidance, not just command listing

The `## Diagrams` section tells the agent what to *do*, not only what to run:
- Reach for a diagram when prose is doing a picture's job.
- `bless` is the only writer of `stamp:` — never re-stamp to silence a warning without
  checking the diagram.
- When the hook fires, treat it as a real task. "Regenerating without looking is how a
  diagram becomes a lie the docs vouch for."
- Use the canonical glossary terms verbatim, per the plugin's own conventions.

### Verified

- trigger-word audit across all three plugins: no collisions
- both JSON manifests brace/bracket balanced and re-read after editing
- 85/85 suite still green after every edit

## Tech Debt

None raised. The one thing that could have become debt — the plugin advertising a
stale description and version in the marketplace — was fixed here rather than
ticketed, since it is two lines and leaving it would have shipped a 1.1.0 feature set
under a 1.0.0 label.

## Reflection

**Repo `CLAUDE.md` gained a "Changing an Existing Plugin" section.** This task exposed
a gap in the repo's own process: `Adding a New Plugin` was documented, *changing* one
was not — so four slices shipped a major capability while `plugin.json`,
`marketplace.json` and `SKILL.md` all still described the 1.0 feature set.

Those three files share a property that makes them easy to forget: **none is exercised
by any test.** The suite was green at 85/85 the whole time the plugin was mis-advertised
and unreachable by its own trigger words. The new section lists them as a unit and
records the current trigger-vocabulary split so the next change can check for
collisions in one place.

**Lessons worth keeping:**
- **A capability nobody can trigger does not exist.** Four slices of work sat behind a
  skill description that never mentioned diagrams. Worth asking "what makes this
  reachable?" as part of the last slice of any feature, not after it.
- **Trigger words are a shared namespace across installed plugins**, and nothing warns
  you about a collision — it just resolves arbitrarily. A one-minute grep across sibling
  descriptions is the whole check.
- Skill descriptions should carry *behaviour*, not just a command list. The `## Diagrams`
  section tells the agent when to reach for a picture and that blessing without looking
  is dishonest — guidance a command reference cannot express.
