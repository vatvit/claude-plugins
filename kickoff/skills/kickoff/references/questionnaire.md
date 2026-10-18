---
title: Kickoff questionnaire
description: The questions asked when a project is kicked off — generic for any project, with options, defaults, proposed values, branching on earlier answers, and where each answer is written
status: agreed 2026-10-18
---

# Kickoff questionnaire

Kickoff is a process: **collect** what is known about a project, **ask** what is not, and **record
the decisions**. It works for any project, so the questionnaire is generic:

- **No stack, vendor, tool or domain is named in a question or an option.** Where one is needed (the
  stack, a database engine, an AI provider, a test tool, a domain check), the option is *proposed*:
  Claude works it out from the earlier answers and the user decides. A fixed list would go stale and
  push every project the same way.
- **No one's personal setup is assumed.** The user's own standing instructions, if they have any, are
  read and shown as already settled; kickoff asks only what they leave open.
- **Sibling plugins are optional.** A question that sets up crew, task, task-roadmap or docs-manager
  is asked only when that plugin is installed. Without it the capability is still asked about, in
  generic terms, and nothing is scaffolded for it.

- **Every question informs a decision.** Its answer either generates something (a file, a rule, a
  default) or is recorded for a decision Claude makes later that can be named (C2 non-goals stop
  Claude adding what was ruled out). A question whose answer informs no nameable decision is removed.
- **A proposed question may also replace free text** where Claude can read candidates from earlier
  answers (B6 from B1); "Other" keeps free text available.

The questions are the same every time; the answers may or may not be.

## How it is asked

- **Pre-defined options** keep both sides precise. "Other" (free text) is always available on top.
- **★ marks the default** — offered first, so a typical answer is one click.
- **Collect before asking.** For an existing project, what can be read from the project (inspect.sh)
  and from the user's standing instructions is shown as proposed answers with their evidence; the
  user confirms them in one go. Only the rest is asked.
- **One section at a time.** Show the section's defaults together; the user accepts them all or picks
  which to change.
- **Asked explicitly** (`explicitly` in *Ask when*): a real trade-off, never part of "accept all
  defaults". Asked on its own, its recommended option first, and the user picks.
- **At most 4 options per question** — the limit of the question UI. "Other" is added automatically.
- **Multi-select** questions say `(pick any)`. Where a level or a default set decides what is
  included, the question asks only for the difference, as **DROP — …** / **ADD — …** options; ticking
  nothing keeps the default set (see §F).
- **A multi-select option's label starts with what ticking it does**, in capitals: **DROP —**, **ADD —**,
  **OUT OF SCOPE —**, **USES —**. A bare tick reads as "yes, this", which is the opposite of an exclusion.
- **Free-text questions** are asked in plain chat, never forced into options.
- **"Not decided yet" is always valid** and goes to the charter's *Open questions*, never filled with a guess.
- **`n/a`** retires a question that does not apply here. It counts as answered and is written nowhere.
- **Defaults depend on earlier answers.** An option marked `(★ if <condition>)` is the default when
  the condition holds, and it overrides the plain ★.
- **Asked in dependency order.** A question whose condition, `(★ if …)` default or proposed options
  depend on a question not yet answered waits (*pending*), even inside one section: it is never on
  the same screen as what it depends on. A6 waits for A4; otherwise its default is computed against
  an empty A4 and the wrong option is recommended.
- **Answers are checked against each other** — after each section and again on the review screen.
  A conflict (hosted experiment tracking in E1 against self-hosted tracking chosen in I5) is shown
  with both answers, and the user resolves it before anything is written; the question that resolves
  it offers the reconciling option first.
- **The end is a review screen**: every answer in one table, the user confirms, then files are written.

## Reading the tables

The kickoff scripts read this file, so the tables are the single source for both the skill and the
generated files.

- **A question row** starts `| <letter><digit> |`. Its section is the `## X. Title` heading above it.
- **Options** are separated by ` · `. A leading `★ ` marks the plain default; a trailing
  `(★ if <condition>)` marks a conditional one.
- **Two kinds of option are not literal answers**, both in `*italics*`:
  - **computed** — a value worked out from facts (*the repo directory name*, *the next free port*).
    Claude computes it and the user confirms the concrete value.
  - **proposed** — starts with *Claude proposes*: a judgement from the earlier answers (the stack, a
    database engine, a provider, domain checks, tools). Claude offers 2–4 concrete candidates as
    options, each with its reason, the recommended one first; the user picks.

  `answer.sh` refuses either italic text as an answer: the answer is always the concrete value.
- **A condition** is `always`, `explicitly`, `<ID> = <option>`, `<ID> ≠ <option>`, `<ID> answered`,
  `<ID> has <option>` (any value of a multi-select answer), or `<plugin> installed`. Parts join with
  ` or ` and ` and `. Any other wording is a **judgement**: Claude decides from what it knows.
- **Goes to** routes the answer: `charter`, `charter §<Section>`, `charter decision`, or `quality doc`
  (`docs/project/quality.md`). Other targets are written by the setup scaffold.

## A. What it is

| ID | Question | Options (★ default) | Ask when | Goes to |
|----|----------|---------------------|----------|---------|
| A0 | Starting point? | ★ New, empty repo · Existing code, no setup · Existing, partly set up | always | how the rest runs |
| A1 | Project name? | ★ *the repo directory name* | always | charter, CLAUDE.md |
| A2 | What it is, in one line? | free text | always | charter, CLAUDE.md |
| A3 | Kind of project? | ★ PoC / experiment · Product / app / service · Library / plugin / tool · Internal tool / automation | always | charter; drives defaults below |
| A4 | Whose project? | ★ *derived from the git remote owner* · Mine · A client's · My employer's | always | charter |
| A5 | Git remote? | ★ *the detected remote* · No remote yet | always | CLAUDE.md |
| A6 | Keep your personal identity out of it (author fields, emails, links, paths)? | Yes — use only the project owner's identity (★ if A4 ≠ Mine) · ★ No | always | CLAUDE.md |

- **A3** says how the project lives, not what it is about: the domain (a game, a model, an online
  shop) is in A2, and what it changes is proposed from there (F5 domain checks).
- **A6** — a client's or employer's repo often must not carry the user's own name or home path.

## B. Goal and success

| ID | Question | Options (★ default) | Ask when | Goes to |
|----|----------|---------------------|----------|---------|
| B1 | The goal? | *Claude proposes one sentence from A2 and A3* · free text | always | charter §Goal |
| B3 | Deadline or milestones? | ★ None · A date (free text) | always | charter §Milestones |
| B5 | Quality bar? | ★ High for the core result, simplest that works elsewhere · High everywhere · Good enough — exploring | always | charter decision |
| B6 | What is the "core result" the bar applies to? | *Claude proposes 2–3 readings from B1* (e.g. "the search results: relevant and complete") | B5 = High for the core result | charter decision |

- **B5/B6** — "high quality" without saying *of what* is read two ways: high for the core result,
  simplest for the rest is the usual meaning, and it has to be said.

## C. Scope

| ID | Question | Options (★ default) | Ask when | Goes to |
|----|----------|---------------------|----------|---------|
| C1 | Build approach? | Minimal, but functional end to end (★ if A3 = PoC) · ★ Production-grade from the start · Throwaway spike | always | charter §Scope |
| C2 | What is explicitly out of scope? (pick any) | *Claude proposes up to 4 likely exclusions from B1, each labelled OUT OF SCOPE —* · free text | always | charter §Non-goals |
| C4 | Build order of the areas? | free text, or "decide later" | the project has several areas | charter decision |
| C5 | When does backward compatibility start to apply? | Not needed yet — no consumers; change interfaces, formats and data freely (★ if A3 = PoC) · From the start — deprecate before removing, migrate stored data (★ if A3 = Library) · Later — from a trigger (first release, first client, v1 …) (★ if A3 = Product or A3 = Internal tool) · Never — always free to break | explicitly | charter decision, CLAUDE.md |

- **C5** — asked explicitly: keeping compatibility costs shims, deprecation paths and migrations, so
  a PoC with no consumers should not pay for it and a library cannot skip it. A *Later* answer is
  recorded as `Later — from <the trigger>`; the charter keeps the trigger as an open question.

## D. Data

| ID | Question | Options (★ default) | Ask when | Goes to |
|----|----------|---------------------|----------|---------|
| D1 | Data it works with? | ★ Generated / fake · Real · Generated now, real later · None | the project handles data | charter decision |
| D2 | How is the generated data made? | *Claude proposes 2–3 ways fitting A2* (e.g. one fact file every generated item is derived from, so the data never contradicts itself) | D1 = Generated | charter decision |
| D3 | Languages of the content and UI? | ★ *the language of this conversation* · Several (which; is one right-to-left?) · None — no human-language content | the project has content or a UI | charter decision |
| D4 | Personal or sensitive data? | ★ None · Yes — residency and handling are open questions | D1 = Real or D1 = Generated now | charter §Open questions |

## X. PoC shortcuts

| ID | Question | Options (★ default) | Ask when | Goes to |
|----|----------|---------------------|----------|---------|
| X1 | Login? | ★ None — one demo user · Simple login · Real auth | A3 = PoC and the project has users | charter decision |
| X2 | Outbound effects (messages, payments, …)? | ★ Previews only — nothing is really sent · Real, through a sandbox · Real | A3 = PoC and the project sends anything out | charter decision |
| X3 | UI look? | ★ Simplest that works · Designed / branded | A3 = PoC and the project has a UI | charter decision |

## E. External services and approvals

| ID | Question | Options (★ default) | Ask when | Goes to |
|----|----------|---------------------|----------|---------|
| E1 | External services it uses (AI models, payments, email, maps …)? (pick any) | ★ None · *Claude proposes up to 4 likely services from A2 and D2, each labelled USES —* · free text | always | charter decision |
| E2 | Which provider for each? | *Claude proposes 2–3 providers per service in E1, fitting I1 and I4* · Decide later | E1 ≠ None | charter decision |
| E3 | May development and tests call them? | ★ Yes, the providers chosen in E2 — anything new asks first · Only sandboxes or fakes · Ask each time | E1 ≠ None | charter decision, CLAUDE.md |
| E4 | Rules for this project that differ from how you usually work? | ★ None · free text (what, and why) | always | CLAUDE.md |

- **E2** waits for I1 and I4: a provider is proposed for where the project runs and its stack. E1
  comes before I because a service (a hosted AI model, say) can change the stack.
- **E3** — recording the approval once, with its date, saves asking in every session.
- **E4** — the user's standing instructions apply unless the project says otherwise; this is where
  it says so.

## I. Infra and stack

| ID | Question | Options (★ default) | Ask when | Goes to |
|----|----------|---------------------|----------|---------|
| I0 | Where does it run during development? | ★ In containers — nothing installed on the machine but the container runtime · Directly on the machine · A remote dev environment | always | CLAUDE.md |
| I1 | Where it runs later? | ★ Undecided — do not lock any option out · The client's own hosting · A cloud · Nowhere — local, or a packaged release | always | charter decision |
| I2 | Infra shape? | ★ One deployable · A few services · Serverless / managed · Not deployed — a library, a CLI, an app package | A3 ≠ Library | charter decision |
| I3 | State it keeps? | ★ None · Files · A database · Several stores (database + cache, queue …) | A3 ≠ Library | charter decision |
| I7 | Special compute? | ★ None · GPUs / accelerators · Large memory or storage · A cluster | always | charter decision |
| I4 | Stack? | *Claude proposes 2–3 stacks fitting A3, I2, I3, I7 and E1, each with its reason* | always | charter decision |
| I5 | Engines for the state? | *Claude proposes the engine for each store in I3, fitting I4* | I3 = A database or I3 = Several | charter decision |
| I6 | Dev port? | ★ *the next free port from the port registry* | the project serves on a port | port registry, CLAUDE.md |

- **I4, I5** have no fixed options on purpose: a list of stacks or engines would go stale.

## F. Quality and testing

Section F holds the **process** and **generic checks**. Which tool runs a check, and which checks the
domain needs, Claude works out from the earlier answers and the user decides.

1. **Level** (F1) — one question; it decides which checks each aspect starts with.
2. **Aspects** (F2–F7) — per aspect, drop what the level included, add what it left out. One aspect,
   Domain checks, is proposed by Claude for this project.
3. **Details and gate** (F8–F11) — what integration tests run against, what a red check stops,
   when the checks start, how the core result is checked.
4. **Tools** (F12) — the tools named along the way, confirmed in one table.

### Levels

| Level | Means |
|-------|-------|
| None | No automated checks yet, or one smoke test |
| Basic | Unit tests, an E2E success path, formatter and linter, one command runs them |
| Standard | Basic + integration tests, type checks, security audit, coverage floor, pre-commit and CI |
| Full | Standard + E2E edge cases, contract, UI, performance, accessibility, architecture rules, mutation, a scheduled heavy run |

### Generic checks by aspect

**Included from** is the lowest level that includes the check; above it, it is included too. A
**fixed** check is part of every level from Basic up and is never offered for dropping — dropping
it means choosing None.

| Aspect | Check | Included from |
|--------|-------|---------------|
| Tests | Unit | fixed |
| Tests | E2E success path | fixed |
| Tests | Integration / functional — several modules together, through their real interfaces | Standard |
| Tests | E2E: failure paths and edge cases too — not only the success path | Full |
| Tests | Contract — between services, or of the public API | Full |
| Tests | UI / visual — key screens rendered headless and compared with approved screenshots; E2E run in each target browser | Full |
| Code checks | Formatter / code style | Basic |
| Code checks | Linter / static analysis | Basic |
| Code checks | Type checks | Standard |
| Code checks | Complexity and architecture rules — size limits, layer and module boundaries | Full |
| Non-functional | Security — dependency audit, secret scan, static security analysis | Standard |
| Non-functional | Performance — load or benchmark against a budget | Full |
| Non-functional | Accessibility | Full |
| Test strength | Coverage floor — the number is set with the tools | Standard |
| Test strength | Mutation testing — on the core logic | Full |
| Automation | One local command runs every check | fixed |
| Automation | Pre-commit hook — the fast checks | Standard |
| Automation | CI on push and merge request | Standard |
| Automation | Scheduled run — the heavy checks, overnight | Full |

No aspect has more than 4 checks that are not fixed, so at any level its drops and adds together
fit one question.

### Domain checks

The generic aspects check the code. What makes *this* project's result right or wrong is
domain-specific, and the questionnaire names none of it. Claude proposes **up to 4 domain checks**
from A2, A3, B6, E1 and I4, each with the level it is included from and its `→ tool`, asked in the
same DROP / ADD form.

- **A domain check protects the core result (B6) or a risk the user named.** Never a list padded
  to 4. With nothing to protect, the aspect is skipped.
- **The answer records the check's own wording**, so the quality doc carries it as proposed.

Examples, not part of the questionnaire: an app calling an LLM — output scored against an answer
key, citations present, no invented facts; training a model — data validated on load, no leakage
between splits, a threshold on a frozen test set, reproducible metrics; a game — deterministic
replay, frame-time budget, save/load round-trip; a library — public API compatibility, the examples
in the docs compile; a CRUD product — often none.

### The questions

| ID | Question | Options (★ default) | Ask when | Goes to |
|----|----------|---------------------|----------|---------|
| F1 | Quality level? | None — no automated checks yet, or one smoke test (★ if C1 = Throwaway spike) · ★ Basic — unit tests, E2E success path, formatter and linter, one command runs them · Standard — Basic + integration tests, type checks, security audit, coverage floor, pre-commit and CI (★ if A3 = Product or A3 = Library or C1 = Production-grade) · Full — Standard + E2E edge cases, contract, UI, performance, accessibility, architecture rules, mutation, a scheduled run | explicitly | charter decision, quality doc, CLAUDE.md |
| F2 | Tests? (pick any) | *the Tests checks of the level, adjusted* | F1 ≠ None | quality doc |
| F3 | Code checks? (pick any) | *the Code checks of the level, adjusted* | F1 ≠ None | quality doc |
| F4 | Non-functional checks? (pick any) | *the Non-functional checks of the level, adjusted* | F1 ≠ None | quality doc |
| F5 | Domain checks? (pick any) | *Claude proposes up to 4 checks for this project, adjusted* | F1 ≠ None | quality doc, charter decision |
| F6 | Test strength? (pick any) | *the Test strength checks of the level, adjusted* | F1 ≠ None | quality doc |
| F7 | Automation? (pick any) | *the Automation checks of the level, adjusted* | F1 ≠ None | quality doc, CLAUDE.md |
| F8 | What do integration tests run against? | ★ The real engines, started fresh for each run — never production data · Fakes / in-memory substitutes — fast, but miss what the real engine does differently · Decide with the tools (F12) | F2 has Integration | quality doc |
| F9 | What does a red check stop? | ★ Everything blocks — no commit or merge on red · Fast checks block; heavy ones only report (★ if F1 = Full) · Report only — nothing blocks | F1 ≠ None | quality doc, CLAUDE.md |
| F10 | When do the checks start? | ★ All from the start · Later — from a trigger (first release, first client, v1 …); Basic until then | F1 = Standard or F1 = Full | charter decision |
| F11 | How is the core result checked? | ★ By hand review now, automated later · Automated from the start · Not checked | B6 answered | charter decision |
| F12 | Tools for the chosen checks? | *Claude proposes the tool of every chosen check for the I4 stack, in one table, each with its reason* | I4 answered and F1 ≠ None | quality doc |

### How F is asked

The question UI cannot pre-tick a checkbox, so an aspect is never shown as a full list to re-tick.
Each aspect F2–F7 is **one multi-select question** about the **difference** from the level —
"<Aspect>: change anything?" — always in this form:

- **DROP — <check>** for each check the level includes, fixed ones left out;
- **ADD — <check>** for each check the level leaves out.

Ticking nothing keeps the level as it is. The answer recorded for the aspect is the **resulting
set** — one `ID: value` line per check — so the answers say what the project has, not how it was clicked.

| Screen | Shows |
|--------|-------|
| 1 | F1 alone — single choice, explicit |
| 2 | F2–F5: Tests, Code checks, Non-functional, Domain checks |
| 3 | F6 Test strength, F7 Automation, F8 (when Integration is kept), F9 |
| 4 | F10 (when Standard or Full), F11 (when B6 is answered), then F12 — a table in chat, approved or changed through the question UI |

- **A check that cannot apply is left out** (a judgement): UI and Accessibility on a project without
  a UI, Contract on a single service with no public API, CI with no remote (A5).
- **An aspect left with fewer than 2 options** is not a question: its one change is offered inside
  the next aspect's question, still prefixed DROP or ADD.
- **None skips F2–F10 and F12.** The level is written to CLAUDE.md as the project's test policy.
- **Changing F1 later** re-derives F2–F7 from the new level, keeping the drops and adds the user made.

**Tools are named as soon as the stack is known.** I4 comes before F, so every DROP / ADD option's
description ends with the tool Claude would use on that stack (`→ <tool>`), and the level question
names the tools of each level. They are a proposal until F12 confirms them; with I4 undecided, the
descriptions carry no tools and F12 waits. Any language works the same way:

- **The language already does it** — say so instead of a tool ("→ the compiler, warnings as errors").
- **No established tool** — say so ("→ no established tool: a custom script", "→ immature: <name>").
  The user may drop the check knowing why.
- **Not sure a tool exists or is maintained** — "→ to check", never a guessed name. F12 resolves it
  before the dev harness task; a lookup on the web is an external call and needs approval.

## R. Repo and process

| ID | Question | Options (★ default) | Ask when | Goes to |
|----|----------|---------------------|----------|---------|
| R1 | Branching? | ★ Trunk — one branch, no feature branches · GitFlow (★ if A3 = Library) · Feature branches + merge requests | always | CLAUDE.md |
| R2 | Commit messages? | ★ Conventional Commits, with the task id when there is one · Free form | always | CLAUDE.md |
| R3 | Remote quirks? | ★ None · VPN needed · Protected branches (who changes them) | A5 ≠ No remote yet | CLAUDE.md |
| R4 | One entry point for commands? | ★ One script, `scripts/dev.sh` (up, down, test, sh) · A task runner (make, just …) · The stack's own tool (its package manager or build tool) | A3 ≠ Library or the library needs a runtime | CLAUDE.md, `scripts/` |
| R5 | Several Claude sessions at once? | ★ Yes — set up crew · No, one session | crew installed | crew config, CLAUDE.md |
| R6 | Task tracking? | Markdown task files (task plugin) (★ if task installed) · The remote's issues · An external tracker · ★ None | always | CLAUDE.md |
| R7 | Where do the task files live? | ★ In the repo, `tasks/` · Outside the repo (★ if A4 ≠ Mine) | R6 = Markdown task files and task installed | `.task-config.json` |
| R8 | Task prefix? | ★ *3–5 letters derived from A1* | R6 = Markdown task files and task installed | `.task-config.json` |
| R9 | Task workflow? | ★ Code and docs profiles · One minimal profile | R6 = Markdown task files and task installed | `tasks/_workflow/` |
| R10 | Practices built into the workflow? (pick any) | INVEST — a task of more than one behaviour is split into small vertical slices · Tests first — watch each test fail before the code exists · SOLID — one responsibility per module, depend on abstractions · DRY — reuse or refactor, never clone; leftover duplication becomes a task | R9 answered | `tasks/_workflow/` |
| R11 | Roadmap? | ★ Yes · No | task-roadmap installed and R6 = Markdown task files | `.task-roadmap.json` |

- **R6–R11** — the questions that set up a sibling plugin are asked only when it is installed. Task
  tracking itself is asked always, in generic terms.
- **R7** — tasks hold the user's deliberation and history. In a client's repo that is usually not
  meant for the client, so they live outside it.
- **R10** is asked in the DROP form of §F: every practice is in the workflow unless the user drops it.
  Nothing ticked (or `n/a`) keeps them all; the answer recorded is the resulting set, `None` when all
  are dropped. The scaffold removes a dropped practice's sentence from the seeded workflow.

## K. Docs

| ID | Question | Options (★ default) | Ask when | Goes to |
|----|----------|---------------------|----------|---------|
| K2 | Language of docs and of our collaboration? | ★ *the language of this conversation* · Other | always | CLAUDE.md |

- **The layout of `docs/` is not asked here.** It belongs to docs-manager. Kickoff writes only its own
  documents, in `docs/project/`; with docs-manager installed, the rest of `docs/` is set up by it,
  from the charter. K1 is retired, not renumbered, so old answer files stay readable.

## What the answers produce

| Output | Holds |
|--------|-------|
| `docs/project/charter.md` | A–F: what it is, goal, milestones, gate, scope, non-goals, a numbered **decisions table** (each with its *why*); every "not decided yet" under *Open questions* |
| `docs/project/quality.md` | F1–F12: level, checks by aspect, gate, tools |
| the rest of `docs/` | not kickoff's: docs-manager sets it up when installed |
| project `CLAUDE.md` | instructions only: pointer to the charter, A6, I0, R1–R6, C5, E3, E4, F1, F7, F9 — never project knowledge |
| `.task-config.json`, `tasks/_workflow/` | R7–R10, when the task plugin is installed |
| crew / task-roadmap config | R5, R11, when installed |
| first tasks | agree the charter · architecture overview · dev harness with the first vertical slice and the F12 checks |

## Where kickoff keeps its own data

Never in a CLAUDE.md — that file holds instructions and stays small.

| What | Scope | Path |
|------|-------|------|
| **Port registry** — every project's dev ports | machine-wide: all accounts on the machine share its ports | `~/.claude/kickoff/ports.json` — deliberately ignores `CLAUDE_CONFIG_DIR` |
| **The user's defaults** — overrides of the ★ answers above | per account | `${CLAUDE_CONFIG_DIR:-~/.claude}/kickoff.json` |

Both files are optional; without them the ★ defaults apply. A port is free only when neither the
registry nor any compose file under the projects directory (`KICKOFF_PROJECTS_DIR`) publishes it.
A port used outside compose is recorded once with `scripts/ports.sh set <name> <port>`.

## Open questions about this questionnaire

- A3: are the four kinds right, or should *Internal tool* give way to something else?
- I0 ★ containers: a good generic default, or should it be proposed from I4?
- R10: which practices are listed, and which are on by default?
- F: is each generic check at the right level? Accessibility under Tests next to UI?
