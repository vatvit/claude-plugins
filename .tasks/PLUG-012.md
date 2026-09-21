---
title: Diagram render port accepts an HTML artifact
status: completed
type: feature
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | Behaviour confirmed by experiment, not by reading — see ## Description |
| 20 | Requirements | skipped | Acceptance criteria are already the spec |
| 30 | Assessment | done | One list + one branch in diagram.sh; four docs enumerate the extensions |
| 40 | POC | skipped | Nothing unknown |
| 50 | Domain | skipped | No new terms — `artifact` already canonical |
| 60 | Architecture | done | html appended last; NO ARTIFACT warns, never fails — see ## Architecture |
| 70 | Tests | done | Cases 29/30/31, 9 assertions; 100/100 host + bash:5 |
| 80 | Subtasks | skipped | One slice |
| 90 | Implementation | done | diagram.sh + 4 docs + CLAUDE.md invariants; 1.4.0 -> 1.5.0 |
| 100 | Tech Debt | done | None raised; see ## Tech Debt |
| 110 | Reflection | done | See ## Reflection |

## Description

`docs-manager/scripts/diagram.sh:199` declares `ARTIFACT_EXTS="svg png pdf webp"`. A project
render script that emits `<out-basename>.html` — an interactive D2 page, a pan/zoom mermaid
wrapper — produces a file that `artifact_for` never finds, so no embedding doc ever links it.

Wanted: HTML as a first-class artifact extension, so an interactive per-diagram page is linked
the same way an SVG is.

## Why

Verified by experiment on 2026-09-22, not inferred:

```
# render script writes $2.html
docs.sh diagram render docs   → "RENDERED: "        (blank path)
ls docs/                      → f.html              (file IS created)
docs.sh diagram index --write → no link, ever

# same script writing $2.svg
                              → "RENDERED: docs/f.svg"
                              → [Open the rendered diagram](f.svg)
```

Two defects in one: HTML is unsupported, **and** an unrecognised extension reports success with
an empty path. The second is a bug independent of HTML — a failed lookup must not read as a win.

## Scope

- Add `html` to `ARTIFACT_EXTS`, appended last so existing precedence is unchanged.
- Make a successful script run that leaves no recognised artifact say so, naming the extensions
  looked for, instead of printing `RENDERED:` with nothing after it.
- Document the precedence rule — `artifact_for` returns the **first** match, so a source with both
  `f.svg` and `f.html` links the SVG. Today that ordering is undocumented and invisible.
- Update the contract comment (`diagram.sh:191`), `README.md`, `SKILL.md` and
  `references/how-to-render.md`, all of which currently enumerate four extensions.
- Note in the how-to what makes HTML unlike the other four: it is not self-contained (may pull
  CSS/JS siblings the plugin knows nothing about) and GitHub will not render it inline, so the
  link downloads rather than displays.

## Out of scope

- Rendering the whole docs set as a website. docs-manager maintains markdown and ships no build
  step; that is a static-site generator's job.
- Any change to what a render script receives, or to the fence-is-never-parsed rule.

## Acceptance criteria

- A render script writing `<base>.html` produces `RENDERED: <path>` and an
  `[Open the rendered diagram](…)` link in every embedding doc.
- With both `f.svg` and `f.html` present the SVG is linked — precedence unchanged and covered by
  a test.
- A script exiting 0 having written an unrecognised extension reports it; an intentional no-op
  script is **not** turned into a failure.
- Suite green on host and in `bash:5`.
- `plugin.json`, `marketplace.json` and `SKILL.md` versions agree after the bump.

## Notes

Raised from the docs-manager 1.4.0 render how-to work: the question "how do I render to HTML?"
had no answer in the plugin, and the empty `RENDERED:` line is what made it look like it had
worked.

## Architecture

- **`html` appended last, not inserted.** `artifact_for` returns the first match in
  `ARTIFACT_EXTS`, so the list order decides what gets linked when a project has more than one
  artifact. Appending makes the change strictly additive: no existing project's linked artifact
  can move. The ordering is now stated as a contract in the plugin's `CLAUDE.md` and pinned by
  case 30, because it was previously an accident of how the string was typed.
- **Precedence is documented rather than made configurable.** A `prefer:` key would reintroduce
  the config file the whole diagram format exists to avoid (same reasoning that killed the
  original `diagrams.render` config key). If a project wants the HTML linked, it writes only HTML.
- **`NO ARTIFACT:` warns on stderr and leaves rc alone.** Tempting to make it an error — the
  plugin already treats a non-executable script as fatal on "a silent skip is miserable to debug"
  grounds. Rejected: a render script may legitimately skip a source and exit 0, and turning that
  into a failure would break a working setup. Reporting it is enough; the old behaviour was bad
  because it claimed *success*, not because it was quiet.
- **No change to what the script receives.** Still `<source-path> <out-basename>`, still no fence
  parsing. HTML support costs the plugin no knowledge of any diagram language.

## Tests

Three cases added to `docs-manager/scripts/test/diagram.test.sh`, 9 assertions, dual-target:

- **29** — a script writing `.html` exits 0, the artifact lands, `RENDERED:` names the path, and
  every embedding doc gains the link.
- **30** — with both `x.svg` and `x.html` present the **SVG** is linked and the HTML is not.
  This is the case that makes the append-last decision enforceable rather than a comment.
- **31** — a script exiting 0 having written `.jpeg` reports `NO ARTIFACT`, does **not** fail the
  run, and never prints `RENDERED:`.

**Results:** 100/100 on the host and in `bash:5` (was 91 before this task).

## Tech Debt

None raised. One observation: `ARTIFACT_EXTS` is now enumerated in five places — `diagram.sh`
(the list plus the contract comment), `README.md`, `SKILL.md` and `how-to-render.md`. The list is
the source of truth and the prose is documentation of it, so this is not duplication that can be
collapsed in bash; but a sixth copy would be worth resisting. Case 29/30 fail loudly if the code
list is wrong, and nothing checks the prose.

## Reflection

**Test the thing you are about to claim.** The bug was found by running a render script that wrote
`.html` and watching what happened, not by reading `ARTIFACT_EXTS`. Reading would have found the
missing extension but not the empty `RENDERED:` line, which is the part that made the failure
*confusing* rather than merely present.

**A capability gap and a reporting bug look identical from outside.** "HTML doesn't work" was
really two defects, and the second one — success reported for a lookup that found nothing — would
have survived a fix that only added `html` to the list, waiting for the next unsupported extension.

**Shipping a how-to surfaces the questions the feature never answered.** This task exists only
because writing `how-to-render.md` (docs-manager 1.4.0) put the four supported extensions in front
of a reader, who immediately asked about the fifth.

## Current State

**Build status:** complete and green — docs-manager 100/100 on host and in `bash:5`;
`docs.sh links` clean; `marketplace.json` validates.

**Changed:** `diagram.sh` (list + contract comment + NO ARTIFACT branch), 3 test cases,
`README.md`, `SKILL.md` (+ HTML trigger phrases), `references/how-to-render.md`,
plugin `CLAUDE.md` invariants, `docs-manager` 1.4.0 → 1.5.0 across all three version sites.

**Known issues:** none.
