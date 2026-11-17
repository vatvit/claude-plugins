---
title: "Short user guide in Ukrainian (PDF) for Claude Desktop: install the marketplace, docs-manager, remote-docs and task — why, when, how"
status: completed
type: docs
priority: medium
tags: ["docs-manager-plugin", "remote-docs-plugin", "task-plugin"]
created: 2026-11-17 12:59
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | ## Context |
| 20 | Requirements | done | ## Requirements — decisions; topics in ## Context |
| 30 | Assessment | done | ## Assessment |
| 40 | POC | done | ## POC |
| 50 | Domain | skipped | a user guide, no domain model |
| 60 | Architecture | done | ## Architecture, approved by the user 2026-11-17 |
| 70 | Tests | done | spec in ## Architecture → Tests; run at implementation |
| 80 | Subtasks | skipped | two files, one session |
| 90 | Implementation | done | guides + PDFs built, reviewed with the user; screenshot slots → PLUG-153 |
| 100 | Tech Debt | done | PLUG-152 (docs-manager NO CARD on built PDFs), PLUG-153 (screenshots) |
| 110 | Reflection | done | docs/guides/building.md; root README links the guides; root CLAUDE.md structure gains docs/ |

## Problem

A Ukrainian-speaking user of **Claude Desktop** (not the CLI) has no short, non-technical guide to
adding the vatvit-plugins marketplace and the three plugins most useful outside coding:
docs-manager, remote-docs and task. The plugin READMEs are in English and written for Claude Code
in a terminal.

## Goal

A short PDF in Ukrainian that a Claude Desktop user can follow alone:

1. **Install** — add the marketplace, then install docs-manager, remote-docs and task, step by step
   in the Claude Desktop UI, with screenshots.
2. **Why** — one paragraph per plugin: what problem it solves.
3. **When** — typical moments to reach for each plugin (and when not to).
4. **How to use** — a few example phrases / commands per plugin that trigger it, and what the user
   sees as a result.

## Inputs

- Screenshots of the Claude Desktop install flow — **the user will provide them**.
- Plugin READMEs and SKILL.md trigger phrases (`docs-manager/`, `remote-docs/`, `task/`).

## Acceptance Criteria

- One PDF, in Ukrainian, short (target: a few pages), readable without any other doc.
- Covers install of the marketplace and all three plugins, with the user's screenshots in place.
- For each plugin: why, when, how — with example phrases that actually activate its skill.
- Every install step is verified against the screenshots / the current Claude Desktop UI; no step
  invented from the CLI flow.
- Nothing names a private project (the repo is public).

## Open questions

- Where the source and the PDF live: in this repo (e.g. `docs/guides/uk/`, source as markdown and a
  generated PDF) or outside it. If in the repo, the PDF build is a script run in docker, not ad hoc.
- PDF toolchain (e.g. pandoc + a Cyrillic-capable font in a container).
- One PDF for all three plugins, or one per plugin.

## Context

**Prior work:** none on user guides; no task touches Claude Desktop onboarding. `docs/` holds only
`images/` (the README picture, PLUG-058). No parallel in-progress task touches these files.

**User's topic list (2026-11-17, at `/task do`)** — audience: people new to Claude and non-technical.
Part 1 (docs-manager + remote-docs): why (collect and organise context for Claude); how they work and
together; why Claude Desktop, not the web version; adding the marketplace; installing; questions asked
after install (what to answer, when); usage examples; benefits; remote-docs features, limits, warnings
(Word/Excel → Google conversion and why; `.md` files, why and where; local vs remote; commit or not,
only with git; commenting limits; conflict limits); tips (Artifacts for simultaneous team + AI work,
Drive for archiving, separate Drive folders per purpose). Part 2 (bonus, maybe a separate file), task:
plan work for a human or AI, track progress, park ideas; solo use: no commit, files in a local or home folder.

**Facts the guide rests on (sources):**
- Install: `/plugin marketplace add vatvit/claude-plugins`, then `/plugin install <name>@vatvit-plugins`
  (root `README.md` § Install). The Desktop UI path comes from the user's screenshots.
- docs-manager has **no config and asks nothing at install** (`docs-manager/README.md`). It keeps
  `docs/` navigable (`_index.md`), checks links, and gives files in `docs/external/` a *card*
  (what it holds, when to read it, where inside to look). It lists remote cards with ☁.
- remote-docs: a Drive file, a Drive folder or a Claude Artifact gets a **remote card**
  (`*.gdrive.md`, `*.artifact.md`). The file stays with Google/Claude, and Claude opens it only when the card says the answer is there.
  Needs the Google Drive connector. Questions are asked **on the first attach to a folder**, not at
  install (`remote.sh questions`): purpose (reference / agreements / collaboration / output / own words),
  for own words also writes + truth; where the cards live (local / Drive); with git and a public remote, commit
  or local-only. With no git there is no publish question.
  Limits: Docs writes are guarded (rejected if someone wrote in between), **Sheets are last-write-wins**,
  Slides untested; **Office files cannot be edited in place**, so they are converted to Google format
  (new file, new link, complex formatting/macros/tracked changes may be lost); comments on Artifacts are
  read before answering; decisions in working material (artifacts, collaboration folders) must be
  extracted into an agreements doc (`EXTRACT?`). Local copies (`*.gdrive.local.md`) are opt-in per
  folder and may fall behind Drive. Source: `remote-docs/skills/remote-docs/references/how-to-remote-docs.md`.
- task: tasks are `.md` files; config `.task-config.json` asks `tasksDir`, `prefix`, assignees (team
  or solo) on first use (`task/README.md`, SKILL.md). `tasksDir` may be absolute or `~`, so solo use
  outside the project or git works.
- Without a usable HOME (Cowork sandbox) docs-manager, remote-docs and task keep state in the project folder (root `README.md`).

**Open for requirements:** where the guide lives, PDF toolchain, one file or two, which Desktop mode
(Code tab / Cowork) the screenshots show, and the "why not web" reasoning.

## Requirements — decisions (2026-11-17)

- **Desktop mode: Cowork.** The guide describes Claude Desktop's Cowork mode only.
- **Location: `docs/guides/uk/`.** Markdown source and the built PDFs are committed (public repo).
- **Two PDFs:** Part 1 docs-manager + remote-docs; Part 2 task.
- **Toolchain: Playwright** (user, 2026-11-17). `mcr.microsoft.com/playwright:v1.57.0-jammy`, already on the
  machine: Markdown → HTML → PDF via Chromium, from a repeatable `docs/guides/build.sh`. (Nothing in this
  repo built a PDF before.)

## Assessment

- **Image fits.** `playwright:v1.57.0-jammy` carries Chromium (`/ms-playwright/chromium-1200`) and fonts with
  Ukrainian coverage (Liberation Sans/Serif, FreeSans). Chromium alone prints HTML to PDF
  (`--headless --print-to-pdf`), so the Playwright npm package is not needed.
- **Gap: Markdown → HTML.** The image has npm but no Markdown converter. Options: fetch a pinned
  converter from npm inside the container (network, needs approval), or a small awk converter for the
  subset the guide uses (offline, matches the repo's bash + awk style).
- **Blocked on input:** Cowork screenshots (install, marketplace, Drive connector). The text can be
  written first with marked image slots.
- `docs/` has no `_index.md` yet: adding `docs/guides/` is the first docs-manager use in this repo's own docs.

## POC

`docs/guides/build.sh` (kept as the real build) renders every `docs/guides/<lang>/*.md` to a PDF beside it:
`render.mjs` (marked 12.0.2, pinned, npm-installed once into the Docker volume `claude-plugins-guides-npm`)
→ HTML with `guide.css` → Chromium `--print-to-pdf` from the Playwright image. Verified on a Ukrainian
sample page (deleted): ґ ї є ’, bold, lists, a blockquote note, a table and a PNG all render on A4.
- Chromium stamps `CreationDate`/`ModDate` on every print, and those are the only bytes that differ between
  two builds. The build compares PDFs with the dates masked, so an unchanged guide is never rewritten
  (two runs → `unchanged`; an edit → `built`).
- An `img` with a border needs `box-sizing: border-box`, or it is clipped at the right margin.

## Architecture (approved 2026-11-17)

**Files** (`docs/guides/`, docs-manager frontmatter on each `.md`, `_index.md` regenerated):
- `uk/01-docs-manager-remote-docs.md` → `.pdf` — Part 1, target 6–8 A4 pages.
- `uk/02-task.md` → `.pdf` — Part 2, target 3–4 pages.
- `uk/images/` — the user's Cowork screenshots, named by step (`01-marketplace-add.png` …).
- `build.sh`, `render.mjs`, `guide.css` — shared by every guide (POC).

**Writing rules:** plain Ukrainian, no jargon without a one-line explanation (Markdown, git, connector);
every "how" is a phrase to type to Claude, never a terminal command; every limitation says what to do
about it; no private project names.

**Part 1 outline:**
1. Для кого цей посібник
2. Навіщо: Claude знає лише те, що бачить — зібрати контекст і впорядкувати його
3. Як це працює простими словами: папка проєкту → `docs/` → картки; docs-manager тримає порядок, remote-docs — картки файлів, що лишаються на Drive / в Artifacts
4. Чому Claude Desktop (Cowork), а не веб-версія
5. Встановлення: маркетплейс → два плагіни → підключити Google Drive [screenshots]
6. Що Claude спитає і що відповідати (table: question → when → recommended answer): purpose of a folder, where the cards live, commit or local-only (git only), local copies
7. Приклади: фрази → що ви отримаєте (benefits)
8. Google Drive: можливості, обмеження, застереження — the two plugins together; Word/Excel → Google format and why; `.md` files, why and where; local vs remote; commit or not (git only); comments; conflicts
9. Поради: Artifacts for simultaneous team + AI work, Drive for the archive, separate Drive folders per purpose
10. Шпаргалка фраз

**Part 2 outline:** навіщо (plan for a human or AI, progress, parked ideas) → як працює (a task is a
file, the workflow table) → встановлення → перше налаштування (questions: tasks folder, prefix, team?) →
solo use (tasks folder in the home or a local folder, never committed) → приклади фраз → поради.

**To verify, not guess:** how Cowork shows plugins and slash commands (screenshots); whether the Drive
connector reads Google Docs comments.

**Tests:** `build.sh` twice → `unchanged`; each PDF read back and checked against its outline
(every section present, images shown, no English left in the prose).

## Implementation

- `docs/guides/uk/01-docs-manager-remote-docs.md` → `.pdf` (8 A4 pages) and `02-task.md` → `.pdf`
  (3 pages), written to the approved outline. Screenshot slots are marked blockquotes
  `[Знімок екрана: …]`: 4 in Part 1, 1 in Part 2.
- `build.sh` → `unchanged` on three runs in a row. Chromium varies two things per print, and the comparison masks both:
  `CreationDate`/`ModDate`, and the `nodeNNNNNNNN` ids of the PDF accessibility tags (kept for screen
  readers). Tables may split between rows (`tr { break-inside: avoid }`). Splitting the whole table left half-empty pages.
- docs-manager indexes created for `docs/` (`docs/_index.md`, `guides/`, `guides/uk/`, `images/`);
  `links` clean. `check` reports `NO CARD` for the two guide PDFs: docs-manager has no rule that a PDF
  built from a `.md` beside it is output. Filed **PLUG-152** rather than writing cards that duplicate the guides.
- Both PDFs read back: every outline section present, Ukrainian text and the ☁ glyph render.
- Written as a hedge, to verify: "Claude, як правило, не бачить коментарі Google Документа". The user
  has not confirmed which comments limitation they meant.
- Solo `task` advice deviates from the brief ("home folder"): in Cowork Claude only sees the chosen folder (and
  a sandbox HOME may be throwaway, root README), so the guide says tasks go in a sub-folder of the
  project folder, and the home folder only where Claude can reach it.

## Implementation — style rewrite (2026-11-17)

The user asked for a less formal voice. The text is now a running instruction: "we suggest plugins A and B, this
lets you…, to do it do A, B, C", with a screenshot slot at each step. The formal blocks are gone ("Для кого цей посібник",
question tables, cheat sheet). Headings are now actions ("Встановлюємо", "Підключаємо Google Drive", "Починаємо").
Same facts and topics. Part 1 is 4 pages with 11 screenshot slots; Part 2 has 4 slots. Rebuild → `unchanged` on the second run; links clean.

## Implementation — corrections (2026-11-17, user review)

- Claude does not cite its source by default. The text no longer says it does: it now says "ask, and Claude names the document".
- Examples made abstract (`…теми…`, `…що зробити…`, `…ідея…`, `…велика мета…`, «зробити Х»), with no
  clients, contracts or prices. Category examples of `reference` material (contracts, specs) kept.
- "Only in Claude Desktop" was wrong: the user says plugins install in the web version too. The guide now
  *recommends* Desktop/Cowork because Claude works with a folder on the user's computer. Open: the user's
  reason for preferring Desktop, if there is more to it.

## Implementation — refresh behaviour (2026-11-17)

Part 1 now says how remote-docs refreshes (how-to, *Refreshing a Drive folder*): an attached folder is synced with
Drive the first time it is used in a conversation; nothing runs between conversations; "Онови картки з Drive" only
mid-conversation. A local copy is never refreshed before reading, only together with its card, so it may lag.

## Implementation — Artifacts for collaboration (2026-11-17)

The user stressed that Claude reads artifact comments. Part 1 now contrasts the two: Google Doc margin comments are
not seen, while artifact comments are always read before answering and summarised on the card (how-to, *Claude
Artifacts* step 4). The Artifacts tip is expanded into the recommended way to collaborate: share the link, colleagues
comment, Claude reads the comments and changes the artifact on request. It is still a draft, so decisions are extracted.

## Implementation — Part 2 additions (2026-11-17, user review)

- **Team use, git only** (new section): ids reserved through git (`idSource git`, "Перемкни номери задач на git") so two
  machines never share a number; concurrent edits surface as git conflicts instead of silent loss; assignees ("Увімкни
  відповідальних за задачі"). Without git, everyone keeps their own tasks.
- **Tips:**
  - Tasks outside the project folder: an absolute or `~` `tasksDir` (task `references/configuration.md`), e.g. one
    folder for all projects. Claude must have access to it (in Cowork, open that folder too).
  - Workflow customisation: `<tasksDir>/_workflow/WORKFLOW.md`, with non-programmer step examples (marketing, legal, analytics).
  - Custom task types: verified in a temp project that `type: звіт` is accepted and `/task list type=звіт` filters by it.
    There is one workflow per tasks folder, not one per type, and the guide says so.

## Implementation — task configuration (2026-11-17)

New Part 2 section "Налаштування: на що звернути увагу", from task `references/configuration.md`, `commands/assign.md`
and README. It covers:
- where tasks live: a sub-folder, or a full path outside the project. The outside-folder tip moved here, so it is said once.
- the prefix: chosen once, since old tasks are not renamed; one prefix per project.
- solo or team: `assignees` `unassigned` (new tasks have no owner) vs `self` (owned by their creator). The user's id is
  the Claude account email, or asked once and kept out of git.
- id source local vs git, renumbering a clash, switching back.
- never hand-edit `nextId`.
- In Cowork `.task-config.json` stays in the project folder, because the global registry needs a usable HOME.
The team section now points to this section instead of repeating it.

## Implementation — tasks outside a project as the headline (2026-11-17)

The user calls tasks outside a project folder a killer feature: task works for any kind of task, project-related or not.
The Part 2 intro now says so ("І головне: задачі не прив'язані до проєкту", with non-software examples). How to set it up
stays in one place, the configuration section, which the intro points to.

## Implementation — Part 2 review (2026-11-17)

Checked against task `commands/do.md`, `finish.md`, `workflow.md`, `references/configuration.md`, `assign.md`.

**Untrue or misleading, fixed:**
- "Claude marks each step and asks before the next" was stated for every task. That is `/task do` only; `/task finish`
  confirms once and then runs every remaining step without pausing. Both are now described.
- "The user's id is stored only with you and never reaches the shared history" was misleading. The private part is
  the per-project override; the `assignee:` value is written into each task, so the team sees it. The guide now says so.
- "In Cowork `.task-config.json` always lives in the project folder" depends on HOME, which is not known for Cowork, and a user
  does not need it. Replaced with "in the folder Claude works with".
- "Status changes only by your decision" was absolute, but "Візьмися…"/"Заверши…" change the status. These are named as the user asking.

**Duplicates removed:** the subfolder, gitignore and team features were in three places (config, solo, team); id source and
assignee modes were in two (config, team). Now each fact is said once.

**New structure:** intro → install with the three first-run questions → usage → "Налаштовуємо під себе" (steps and types,
moved out of the tips because they are configuration) → "Сам чи з командою" (solo; team with git: ids, conflicts,
assignees, identity) → tips (the `nextId` warning is now a tip). Added: steps are one per tasks folder, so different
step lists need different folders. 4 screenshot slots, unchanged.

## Reflection

- How to build, and Chromium's two unstable parts (dates, accessibility-tag node ids), are now in `docs/guides/building.md`.
  The task no longer holds them alone.
- Root `README.md` (Install) links both PDFs for non-programmers; root `CLAUDE.md` structure lists `docs/`.
- Lesson: claims about another product's UI or behaviour (Cowork plugin screens, whether web supports plugins, whether Claude
  cites sources) were wrong or unverifiable from this repo. The user corrected two. Write such claims as recommendations, or
  leave a slot for the screenshot, rather than state them as fact.

## Current State

Completed 2026-11-17. Both guides and PDFs are in `docs/guides/uk/`, and `build.sh` is idempotent. Follow-ups: PLUG-153 (screenshots,
waiting on the user), PLUG-152 (docs-manager: a PDF built from a `.md` beside it is output, independent).
