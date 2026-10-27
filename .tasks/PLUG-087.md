---
title: "kickoff — asks whether a project wants an E2E test viewer, and a gap rule that finds one wanted but missing"
status: in-progress
type: feature
priority: medium
related: [PLUG-088]
tags: ["kickoff", "quality", "e2e"]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | stack-neutral rule binds the wording; own F question fits the grammar; ports per service |
| 20 | Requirements | done | own F question, ★ No, named command, ports derived (app×10+1/+2) |
| 30 | Assessment | done | ready, no parser change; No recorded too; Yes → a first task; `ports.sh viewer` |
| 40 | POC | skipped | nothing uncertain; agreed with the user |
| 50 | Domain | done | E2E viewer, trace, viewer ports, e2e:view |
| 60 | Architecture | done | F13 after F7; ports.sh viewer; gap arm; first task; release with PLUG-088 |
| 70 | Tests | done | 4p–4s, ports 6a–6n, existing 9a–9d, scaffold 2n2/7a; all seen red, plants red |
| 80 | Subtasks | skipped | one change set, one session |
| 90 | Implementation | done | 296 tests green on host, bash:5 and a standalone copy |
| 100 | Tech Debt | done | none; release (bump, README, push) waits for PLUG-088 by design |
| 110 | Reflection | done | kickoff CLAUDE.md: check every port before writing any (6n) |

## Description

A PoC in another project proved an **E2E test viewer** worth having (the user, 2026-10-27: *"PoC works good"*). The
user's need, verbatim (2026-10-25):

> i want to see the list of test cases and their run results (at least last)
> i want to be able to play any of them in my browser and see the result
> not "i am repeat the steps, but the programm repeat, and i an observer"
> i should be able to see details. maybe pause OR at least do not close after finish.

The user ruled that it goes into **kickoff**, not a new plugin, and that it covers both of kickoff's paths: a **new
project** gets it from its answers, and an **existing project** gets it when its gaps are closed after the survey.

**Optional, never imposed** (the user, 2026-10-27): *"each project MAY have. the Plugin can ask and provide instructions
how to reach that."* kickoff **asks** whether the project wants the viewer and, if yes, **gives the instructions** to
build it; no level makes it mandatory.

This task is the **question and gap half**: kickoff asks, records the answer, and `gaps.sh` reports a project that said
yes but has no viewer. The instructions themselves are [PLUG-088](PLUG-088.md); the two touch different files and can
run in parallel.

## Proposed shape (negotiable at Requirements)

- **A question, not a fixed check:** "Do you want an E2E viewer — every E2E test's last result in the browser, a
  step-by-step replay of a kept trace, and run-and-watch for any one test, local only?" Options yes / no / later. Where it
  sits is a Requirements question: a follow-up question after the quality level, or an optional (dropped by default) row
  in §Generic checks by aspect, aspect *Tests* — mind the catalogue's rule that no aspect has more than 4 non-fixed checks.
- **Asked only when E2E runs in a browser**; the questionnaire already branches on earlier answers.
- **A yes points at the instructions** (PLUG-088): in the charter, and as the "do it now / make it a task" content when
  the gap is closed.
- **A gap rule** in `scripts/gaps.sh`, `F2:"E2E viewer"*` (or wherever the check's answer lands), looking for evidence
  of a viewer. What counts as evidence is a Requirements question: a dev command (`dev.sh e2e:view`), a per-test result
  store, a reporter file. It must not match a plain Playwright HTML report, which is not the viewer.
- **Ports from kickoff's port registry** (`scripts/ports.sh`): the viewer and run-and-watch need two local ports. The PoC
  derived them from the app's port (app × 10 + 1, + 2); decide whether kickoff registers them as named ports or keeps
  the derivation.
- **Trigger phrases:** "test viewer", "e2e viewer", "replay a test", "watch a test run" — checked against the other
  plugins' vocabularies (root CLAUDE.md). delay owns "run the tests later"; this is about *seeing* runs, not timing them.

## Acceptance criteria (draft)

1. A project kicked off with browser E2E is asked the question; a yes lands in its charter with a pointer to the
   instructions, a no leaves no trace of the viewer; one without browser E2E is not asked.
2. `gaps.sh` on a project that answered yes and has no viewer prints one gap row with its evidence paths; once a viewer
   exists, or the answer is no, it prints nothing (seen red first, as every gap rule).
3. The two ports are allocated through the port registry, never hard-coded, and never collide with another project's.
4. Skill description, plugin.json, marketplace.json and the root README in sync (root CLAUDE.md §Changing an Existing
   Plugin); version bumped.
5. Tests pass on the host and in the Alpine container.

## Context

Collected 2026-10-27.

**Prior decisions (do not re-litigate):**
- **kickoff names no stack, vendor or tool** in a question or option (PLUG-078; README line 5; kickoff CLAUDE.md
  "kickoff names no stack"). Such values are *proposed* (`*Claude proposes …*`) or named in an option's description as
  `→ <tool>` (questionnaire §How F is asked). So the question says "E2E viewer" in behaviour terms, never "Playwright";
  the tool shows up only as the proposal for the project's stack. **This also binds PLUG-088's instructions:** concept
  first, Playwright as the worked example.
- **gaps.sh reports, never fixes**; a closed gap disappears; the fix is Claude's, concrete for the stack (kickoff
  CLAUDE.md; SKILL.md step 7, the do-it-now / make-it-a-task / leave-it table). The viewer gap plugs into that as is.
- The questionnaire **is code**: `lib.awk` parses its tables; never copy question text into a script or fixture
  (kickoff CLAUDE.md §The questionnaire is code too).

**Where the question fits — two candidates for Requirements:**
- **A row in §Generic checks by aspect** (aspect *Tests*), then it is an ADD option of F2. Problem: every row there is
  *included from* some level (or fixed); the viewer is to be asked, never included by a level. The table has no
  "never by level" value, and *Tests* already holds 4 non-fixed checks (Integration, E2E edge cases, Contract, UI),
  the catalogue's stated maximum per aspect.
- **Its own question in F** (e.g. `F13 | E2E viewer? | ★ No · Yes — … | F2 has E2E success path and <E2E runs in a
  browser> | quality doc, charter decision`). The condition grammar takes this as is: `F2 has …` is a parsed atom,
  the browser part is a *judgement* atom, and in `and` a false part wins over a judgement one (lib.awk `cond`, 4o).
  Fits screen 3 or 4 of §How F is asked. **Leaning: this one** — it keeps the level model untouched.

**Ports:** `ports.sh allocate <project>/<service>` already supports per-service names, and a port taken in any compose
file under the projects dir is never handed out. So the viewer's two ports can be `<project>/e2e-view` and
`<project>/e2e-ui` — no derivation rule needed. The PoC's app×10+1/+2 rule is that project's own (PLUG-088 §What the PoC
settled lists it as project-specific). I6 is the single-port precedent (`the project serves on a port`, judgement).

**Code to touch:**
- `kickoff/skills/kickoff/references/questionnaire.md` — the new row, §How F is asked (screen), §What the answers
  produce if a new output.
- `kickoff/scripts/gaps.sh` — a case arm beside `F2:"E2E success path"*`, matched by the start of the option text.
- `kickoff/scripts/quality.awk` / `charter.awk` — only if the row's *Goes to* needs new rendering (check at assessment).
- `kickoff/skills/kickoff/SKILL.md` — description triggers; step 7's gap list mentions "E2E".
- Tests: `kickoff/scripts/test/existing.test.sh` (gaps), `kickoff.test.sh` (questionnaire flow), `ports.test.sh`.
  Run: `bash kickoff/scripts/test/all.sh` and `docker run --rm -v "$PWD":/w -w /w bash:5 bash kickoff/scripts/test/all.sh`.

**Parallel-session collisions:** this repo's crew (delay coordinator, kickoff worker) has been silent 16–18 days;
no other open task touches kickoff. PLUG-088 will add a reference file under `kickoff/skills/kickoff/references/`
and touch nothing here.

## Requirements

Settled 2026-10-27 with the user (four questions; the rulings below supersede §Proposed shape where they differ).

### Rulings
- **Placement:** its own question in section F, not a row of §Generic checks by aspect. The levels are untouched.
- **Default:** ★ **No** — "each project MAY have".
- **Evidence of a viewer:** a **named command**. The instructions (PLUG-088) name the commands; the gap closes when a
  setup file (manifest, config, `scripts/`, CI — `set_up` in gaps.sh) defines one. Same rule as an F12 tool.
- **Ports: derived from the app's port** (the user chose this over registry entries): viewer = app port × 10 + 1,
  run-and-watch = app port × 10 + 2. Checked: injective (distinct app ports never share a derived one), and with app
  ports from 3030 up the derived ones (30301+) sit far above the app range. Limits, to be handled, not hidden:
  - needs an app port (I6); a project without one gets the viewer question but no ports, and the instructions say to
    pick two by hand with `ports.sh set`;
  - an app port above 6553 derives past 65535: refuse with a message naming the cause;
  - a derived port already published in some compose file: reported, like every port kickoff checks (the compose
    scan), never silently reused.

### In scope
- **Q1** · A new F question, "E2E viewer?" in behaviour words (no tool named): every E2E test's last result in the
  browser, a step-by-step replay of a kept trace, run-and-watch any one test, local only. Options ★ No · Yes; the Yes
  option's description carries the `→ <tool>` proposal for the I4 stack, as other F options do.
- **Q2** · Asked when `F2 has E2E success path` **and** E2E runs in a browser (a judgement atom). Not asked otherwise.
- **Q3** · Goes to the quality doc (and charter decision). A Yes there points at the instructions (PLUG-088) and names
  the two derived ports.
- **G1** · gaps.sh: answered Yes and no setup file defines the viewer's command → one gap row, its evidence paths; once
  one does, or the answer is No, nothing.
- **P1** · The derivation lives in one place in kickoff (ports.sh or lib.sh), used by the quality doc / charter and the
  instructions; the limits above are its tests.
- **T1** · Trigger phrases for the skill description: "e2e viewer", "test viewer", "replay a test", "watch a test
  run". Checked against the other plugins' vocabularies (root CLAUDE.md lists them; none claims these). Record the new
  words in that list.
- Sync plugin.json (version, description, keywords), marketplace.json, SKILL.md description, root README.

### Out of scope
- The instructions themselves and any ready-made files — PLUG-088.
- Making the viewer part of any quality level.

### Acceptance (replaces the draft)
1. A kickoff with browser E2E asks the viewer question, ★ No preselected; without browser E2E, or with F1 = None, it is
   not asked.
2. Yes → the quality doc names the viewer, its two derived ports and the pointer to the instructions; No → no trace of it.
3. gaps.sh: Yes + no command defined → one row; command defined → nothing; No → nothing. Each seen red first.
4. Derivation: 3036 → 30361 / 30362; an app port > 6553 refused with its cause; no app port → no ports, the manual way
   named; a derived port found in a compose file reported.
5. Triggers added and recorded; versions and descriptions in sync.
6. `kickoff/scripts/test/all.sh` green on the host and in `bash:5`.

## Assessment

2026-10-27. **Ready; no parser change.** Findings:

- **The condition works as is.** `F2 has E2E success path and <judgement>` → `cond`: the `has` atom is parsed, the
  wording atom returns `judge`, and a false part wins (`lib.awk` atom/cond, test 4o). With F1 = None, F2 is skipped, so
  `has` is false and the question is skipped — acceptance 1's "F1 = None → not asked" needs no extra clause.
- **Tests that autofill will see the new question** (`helpers.sh` autofill answers every `--next` row, a judge row with
  its default). ★ No settles it, so no fixture breaks; their quality docs gain one section.
- **The quality doc records No too — acceptance 2 is relaxed.** `quality.awk` renders every settled answer whose *Goes
  to* names the quality doc, verbatim, with no per-question code; the precedent is "level None is still recorded"
  (scaffold 6e). A per-question exception for No would be the first special case in a generic renderer, so the
  decision is recorded either way: "E2E viewer? — No". (Acceptance 2 was my wording, not a ruling.)
- **No pointer and no port numbers in the quality doc.** It lives in the user's project; a path into the plugin is not
  portable, and the renderer computes nothing. Instead a Yes becomes **a first task** — "build the E2E viewer, following
  kickoff's instructions" — the way the output already names first tasks (questionnaire §What the answers produce;
  `scaffold.sh` line 94; SKILL.md step 6). The task carries the ports.
- **The derivation fits ports.sh as one new command,** e.g. `ports.sh viewer <name>`: reads `<name>`'s registered port,
  derives ×10+1 / +2, refuses > 6553 and a derived port another name holds or a compose file publishes, then records
  them as `<name>/e2e-view` and `<name>/e2e-ui` under the registry lock (`with_lock`, `do_set`). One place, testable in
  `ports.test.sh`; `list` then shows them, so another project's allocation sees them. `next_free` climbs from 3030 and
  never reaches 30301+ in practice; the scan guards the rest. No app port registered → refused, naming
  `ports.sh set` as the manual way.
- **Gap evidence:** `set_up` (gaps.sh) greps the setup files for a string. The command name must be fixed by the
  instructions; accept `e2e:view` and `e2e-view` (a Makefile target cannot hold `:`). PLUG-088 must use that name.
- **Answer matching:** gaps.sh matches by the start of the option text (`F13:Yes*`), as every arm does.

**Changes to make:** questionnaire.md (the row, §How F is asked screen 3, §What the answers produce first tasks),
ports.sh (`viewer`), gaps.sh (one arm), scaffold.sh line 94 and SKILL.md step 6 (the conditional first task), SKILL.md
description, versions. Tests: kickoff.test.sh (asked / skipped), ports.test.sh (derivation and its limits),
existing.test.sh (the gap), scaffold.test.sh (first task named on Yes only).

## Domain

- **E2E viewer** — the Term, in kickoff's words: one browser page with every E2E test's last result, a step-by-step
  replay of a kept trace, and run-and-watch for any one test; local only. Never a tool's name (kickoff names no stack).
- **Trace** — the recorded run a replay steps through. Not *recording*: a project may own that word (the PoC's did).
- **Viewer ports** — `<project>/e2e-view` (app × 10 + 1) and `<project>/e2e-ui` (app × 10 + 2): registry names, the
  `<project>/<service>` form ports.sh already documents.
- **`e2e:view`** — the command name a gap check looks for (`e2e-view` where `:` cannot be used).
- Vocabulary for triggers: *e2e viewer / test viewer / replay a test / watch a test run* — kickoff's; delay keeps *run
  the tests later*. Recorded in the root CLAUDE.md vocabulary list.

## Architecture

1. **The question** is `F13`, placed in the F table after F7 (so on screen 3 of §How F is asked, beside F8/F9; the
   table order is the ask order). Row: `F13 | E2E viewer? | ★ No · Yes — every E2E test's last result in the browser,
   a step-by-step replay of a kept trace, run-and-watch any one test, local only | F2 has E2E success path and the E2E
   runs in a browser | quality doc, charter decision`. The `→ <tool>` proposal goes in the option's *description* in
   the question UI, as the other F options, not in the table.
2. **Ports:** `ports.sh viewer <name>` — derive, check, `set` both under the lock; prints `e2e-view TAB p` and
   `e2e-ui TAB p`. Exit codes as the others: 2 usage, 3 a port held by another name or published in a compose file,
   1 no port registered for `<name>` / app port > 6553. Run again → the same ports (idempotent: `do_set` on an existing
   own name is a no-op).
3. **Gap:** gaps.sh arm `F13:Yes*)` → `set_up e2e:view || set_up e2e-view || gap F13 "$v" "no E2E viewer command"
   "manifests and config at the root, scripts/, .github/"`.
4. **First task:** scaffold.sh's `next:` line appends `· the E2E viewer, from kickoff's instructions` when F13 is Yes
   (read with get.awk, as scaffold.sh reads R9). SKILL.md step 6 and §What the answers produce say the same.
5. **The instructions file** `skills/kickoff/references/e2e-viewer.md` is PLUG-088's. So that a Yes never points at
   nothing, **kickoff is not pushed between the two tasks**: PLUG-087 is committed locally, and the version bump and
   push happen once PLUG-088 lands. Parallel work is unaffected; only the release waits.
6. **Versions:** one minor bump (0.8.1 → 0.9.0) for the pair, at PLUG-088's landing; PLUG-087 updates descriptions and
   triggers in the same commit chain.

## Implementation (2026-10-27)

- `questionnaire.md`: F13 after F7 (★ No · Yes — …; asked when `F2 has E2E success path and the E2E tests run in a
  browser`), screen 3, a §How F is asked bullet, the first task in §What the answers produce.
- `ports.sh viewer <name>`: derives × 10 + 1 / + 2, checks both (registry holder, compose scan, own ports exempt)
  before writing either, refuses no port / > 6553 (exit 1) and a used port (exit 3), idempotent.
- `gaps.sh`: `F13:Yes*` → `set_up e2e:view || set_up e2e-view`, else one gap row.
- `scaffold.sh`: reads F13; the `next:` line adds the viewer's first task on Yes.
- `SKILL.md`: triggers, the ports in step 3's computed defaults, the gap list; root `CLAUDE.md` vocabulary.
- Plant found a real hole: without the up-front holder check, `do_set` still refused but after writing the first
  port. Test 6n added; recorded in kickoff CLAUDE.md.
- **Not done here, by design:** version bump, plugin.json / marketplace.json / README — with PLUG-088, at release.

## Current State

2026-10-27: implementation done, all 296 kickoff tests green on host, `bash:5` and standalone. Uncommitted, waiting
for the user's OK to commit (local only). Not released: the bump, README sync and push wait for PLUG-088, so a Yes
never points at missing instructions. Status stays in-progress until the release; then completed.

2026-10-27 (later): PLUG-088 done; the release prep is in (see PLUG-088 Current State), the version held at 0.8.1 for now.
Committed locally in 07f5b27; the release commit and the push wait for the user.
