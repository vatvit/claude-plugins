---
title: Kickoff questionnaire
description: The questions asked when a new project starts — options, defaults, branching on earlier answers, and where each answer is written
status: agreed 2026-10-08
---

# Kickoff questionnaire

The standard set of questions the user answers when a new project starts. The questions are the
same every time; the answers may or may not be.

- **Pre-defined options** keep both sides precise: the question cannot be read two ways, and the
  answer cannot be misread. "Other" (free text) is always available on top of the listed options.
- **★ marks the default** — offered first, so a typical answer is one click.
- **Ask when** makes the questionnaire branch: a question whose condition is false is skipped, not
  answered by default.
- **Goes to** says where the answer is written. Nothing is lost into chat history.

## How it is asked

- **One section at a time.** Show the section's defaults together; the user accepts them all or picks
  which to change. Asking 40 questions one by one defeats the purpose.
- **At most 4 options per question** — the limit of the question UI. "Other" is added automatically.
- **Free-text questions** (name, one-liner, goal, non-goals) are asked in plain chat, never forced into options.
- **"Not decided yet" is always valid** and goes to the charter's *Open questions*, never filled with a guess.
- **`n/a`** retires a question that does not apply here (a judgement condition, or the user says so):
  it counts as answered and is written nowhere.
- **Defaults depend on earlier answers.** `A3 = PoC` changes the defaults in B, C and R. An option
  marked `(★ if <condition>)` is the default when the condition holds, and it overrides the plain ★.
- **Global rules are not asked** — Docker only, docs first, the roles, test policy, git approval,
  DRY. They already apply to every project. Only *exceptions* to them are asked (E4).
- **The end is a review screen**: every answer in one table, the user confirms, then files are written.

## Reading the tables

The kickoff scripts read this file, so the tables are the single source for both the skill and the
generated files. Keep to these forms when editing:

- **A question row** starts `| <letter><digit> |`. Its section is the `## X. Title` heading above it.
- **Options** are separated by ` · `. A leading `★ ` marks the plain default; a trailing
  `(★ if <condition>)` marks a conditional one.
- **A condition** is `always`, `<ID> = <option>`, `<ID> ≠ <option>` or `<ID> answered`. The option
  text matches an answer that starts with it, ignoring case. Parts joined by ` or ` hold when any part
  holds. Any other wording is a **judgement**: Claude decides from the conversation whether to ask.
- **Goes to** routes the answer: `charter` (the overview list), `charter §<Section>`, or
  `charter decision` (the decisions table). Other targets are written by the setup scaffold.

## A. What it is

| ID | Question | Options (★ default) | Ask when | Goes to |
|----|----------|---------------------|----------|---------|
| A0 | Starting point? | ★ New, empty repo · Existing code, no setup · Existing, partly set up | always | how the rest runs |
| A1 | Project name? | ★ the repo directory name | always | charter, CLAUDE.md |
| A2 | What it is, in one line? | free text | always | charter, CLAUDE.md |
| A3 | Kind of project? | ★ PoC / experiment · Product / app / service · Game · Library / plugin / tool | always | charter; drives defaults below |
| A4 | Whose project? | ★ derived from the git remote owner · Mine · A client's · My employer's | always | charter; identity rule |
| A5 | Git remote? | ★ the detected remote · No remote yet | always | CLAUDE.md |

- **A0** — for an existing project the skill reads what is there first and asks only about the gaps.
- **A4** — a remote owner other than the user's own account triggers the identity-isolation rule: the
  user's personal identity must not appear anywhere in the project. Confirming it here makes it explicit.

## B. Goal and success

| ID | Question | Options (★ default) | Ask when | Goes to |
|----|----------|---------------------|----------|---------|
| B1 | The goal? | "Try to solve the problem for real, and show a valuable result" (★ if A3 = PoC) · free text | always | charter §Goal |
| B2 | Who judges the result? | ★ Me · The client's stakeholders · My manager / internal · End users | always | charter |
| B3 | Deadline or milestones? | ★ None · A date (free text) | always | charter §Demo plan |
| B4 | A gate before it is shown? | ★ Yes — shown only if the result is good, otherwise kept internal · No | B2 ≠ Me | charter §Gate |
| B5 | Quality bar? | ★ High for the core result, simplest that works elsewhere · High everywhere · Good enough — exploring | always | charter decision |
| B6 | What is the "core result" the bar applies to? | free text (e.g. "the AI output: accuracy, citations, no invented facts") | B5 = High for the core result | charter decision |

- **B5/B6** — "high quality" without saying *of what* is read two ways. sample-poc had to split it:
  high for what the AI produces, simplest for the UI.

## C. Scope

| ID | Question | Options (★ default) | Ask when | Goes to |
|----|----------|---------------------|----------|---------|
| C1 | Build approach? | Minimal code, simplest UI, but functional end to end (★ if A3 = PoC) · Production-grade from the start · Throwaway spike | always | charter §Scope |
| C2 | What is explicitly out of scope? | free text | always | charter §Non-goals |
| C3 | Source material to bring in? | ★ None · Client documents — ingest into `docs/external/` · Later | always | `docs/external/` (docs-manager) |
| C4 | Build order of the areas? | free text, or "decide later" | the project has several areas | charter decision |

## D. Data

| ID | Question | Options (★ default) | Ask when | Goes to |
|----|----------|---------------------|----------|---------|
| D1 | Data? | ★ Fake / generated · Real · Fake now, real later | A3 ≠ Library | charter decision |
| D2 | Fake data from one coherent "world"? | ★ Yes — one fact file feeds every generated document · No — independent per feature | D1 ≠ Real | charter decision |
| D3 | Languages of the data and UI? | ★ English · Another single language · Bilingual (which, and is one right-to-left?) | A3 ≠ Library | charter decision |
| D4 | Personal or sensitive data? | ★ None · Yes — residency and handling are open questions | D1 ≠ Fake / generated | charter §Open questions |

- **D2** — when features cross-reference each other, independently generated fake data contradicts
  itself. A single fact file also gives an answer key for scoring (F2).

## X. Demo shortcuts

| ID | Question | Options (★ default) | Ask when | Goes to |
|----|----------|---------------------|----------|---------|
| X1 | Login? | ★ None — one demo user · Simple login · Real auth | A3 = PoC | charter decision |
| X2 | Outbound effects (email, payments, messages)? | ★ Previews only — nothing is really sent · Real, through a sandbox · Real | A3 = PoC | charter decision |
| X3 | UI look? | ★ Simplest that works · Designed / branded | A3 = PoC | charter decision |

## I. Infra and hosting

| ID | Question | Options (★ default) | Ask when | Goes to |
|----|----------|---------------------|----------|---------|
| I1 | Where it runs later? | ★ Undecided — do not lock any option out · The client's own hosting · A cloud (AWS / Azure / GCP) · Nowhere — local or a packaged release | always | charter decision |
| I2 | Infra shape? | ★ One container, one monolith · A few services (compose) · Serverless / managed | A3 ≠ Library | charter decision |
| I3 | Storage? | ★ SQLite / files · PostgreSQL · None | A3 ≠ Library | charter decision |
| I4 | Stack? | Claude proposes 2–3 stacks fitting A3, I2 and the external services, each with its reason; the user picks | always | charter decision, architecture doc |
| I5 | Dev port? | ★ The next free port from the port registry | the project serves HTTP | port registry, CLAUDE.md, compose |

- **I4** has no fixed options on purpose: a fixed stack list would go stale and push every project the same way.
- **I5** — the chosen port is recorded in the port registry (see [Where kickoff keeps its own data](#where-kickoff-keeps-its-own-data)).

## E. External services and approvals

| ID | Question | Options (★ default) | Ask when | Goes to |
|----|----------|---------------------|----------|---------|
| E1 | Uses an AI model? | ★ Yes, via an API · Yes, a local model · No | always | charter |
| E2 | Which provider? | OpenAI · Anthropic · Azure OpenAI · Decide later (Claude proposes with reasons) | E1 = Yes, via an API | charter decision |
| E3 | Is calling it approved for development and tests? | ★ Yes, this provider only — anything else needs its own approval · Ask me each time | E1 = Yes, via an API | charter decision, CLAUDE.md |
| E4 | Other external services? | ★ None · List them (each needs its own approval) | always | charter decision |
| E5 | Exceptions to the global rules? | ★ None · Something must run on the host (what, why) · Other | always | CLAUDE.md |

- **E3** — the global rule forbids runtime external calls without approval. Recording the approval
  once, with its date, saves asking in every session.

## F. Quality and testing

| ID | Question | Options (★ default) | Ask when | Goes to |
|----|----------|---------------------|----------|---------|
| F1 | Test layers beyond the global "unit + E2E success path"? | ★ None · Visual regression · Result-quality evaluation · Both | always | testing doc |
| F2 | How is result quality scored? | ★ By hand review now, automated against an answer key later · Automated from the start · Not scored | B6 answered | charter decision |

## R. Repo and process

| ID | Question | Options (★ default) | Ask when | Goes to |
|----|----------|---------------------|----------|---------|
| R1 | Branching? | ★ Trunk — one branch, no feature branches · GitFlow (★ if A3 = Library) · Feature branches + merge requests | always | CLAUDE.md |
| R2 | Commit messages? | ★ Conventional Commits with the task id · Free form | always | CLAUDE.md |
| R3 | Remote quirks? | ★ None · VPN needed · Protected branches (who changes them) | A5 ≠ No remote yet | CLAUDE.md |
| R4 | One entry point for commands? | ★ `scripts/dev.sh` (up, down, test, e2e, sh) · `make` · `docker compose` directly | A3 ≠ Library or the library needs a runtime | CLAUDE.md, `scripts/` |
| R5 | Several Claude sessions at once? | ★ Yes — set up crew · No, one session | always | crew config, CLAUDE.md |
| R6 | Where do tasks live? | ★ In the repo, `tasks/` · Outside the repo (★ if A4 ≠ Mine) | always | `.task-config.json` |
| R7 | Task prefix? | ★ 3–5 letters derived from A1 | always | `.task-config.json` |
| R8 | Task workflow? | ★ Code and docs profiles · One minimal profile | always | `tasks/_workflow/` |
| R9 | Roadmap? | ★ Yes (task-roadmap) · No | always | `.task-roadmap.json` |

- **R6** — tasks hold the user's deliberation and history. In a client's repo that is usually not
  meant for the client, so they live outside it.

## K. Docs

| ID | Question | Options (★ default) | Ask when | Goes to |
|----|----------|---------------------|----------|---------|
| K1 | Docs skeleton? | ★ `project/` `architecture/` `dev/` (+ `external/` if C3, + `design/` if A3 = Game) · Minimal: `project/` only | always | `docs/` (docs-manager) |
| K2 | Language of docs and of our collaboration? | ★ English · Other | always | CLAUDE.md |

## What the answers produce

| Output | Holds |
|--------|-------|
| `docs/project/charter.md` | A–F: what it is, goal, demo plan, gate, scope, non-goals, and a numbered **decisions table** (D1, D2, … each with its *why*); every "not decided yet" under *Open questions* |
| `docs/` skeleton + `_index.md` | K1, generated with docs-manager |
| project `CLAUDE.md` | instructions only: pointer to the charter, R1–R5, E3, E5 — never project knowledge |
| `.task-config.json`, `tasks/_workflow/` | R6–R8 |
| crew / task-roadmap config | R5, R9 |
| first tasks | agree the charter · architecture overview · dev harness with the first vertical slice and its tests |

## Where kickoff keeps its own data

Never in a CLAUDE.md — that file holds instructions and stays small.

| What | Scope | Path |
|------|-------|------|
| **Port registry** — every project's dev ports | machine-wide: all accounts share one Docker | `~/.claude/kickoff/ports.json` — deliberately ignores `CLAUDE_CONFIG_DIR`, or two accounts would hand out the same port |
| **The user's defaults** — overrides of the ★ answers above | per account: a work account defaults to *employer's project*, *tasks outside the repo* | `${CLAUDE_CONFIG_DIR:-~/.claude}/kickoff.json` |

Both files are optional; without them the ★ defaults above apply. A port is free only when neither
the registry nor any compose file under `~/projects` publishes it, so a port that a project took
without kickoff is never handed out. Ports used outside compose (today listed in project-e's
CLAUDE.md) are recorded once with `scripts/ports.sh set <name> <port>`.

## Open questions about this questionnaire

- **Is anything missing?** Topics the user typed by hand at a past kickoff that are not covered here.
