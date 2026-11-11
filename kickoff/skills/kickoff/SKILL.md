---
name: kickoff
description: Use when the user starts a new project and its starting context has to be collected — walk them through the standard kickoff questionnaire (generic for any language or stack; questions branch on earlier answers, each with pre-defined options and a default; sibling plugins asked about only when installed) and turn the answers into decisions: the project's charter, its quality level and checks, and its CLAUDE.md. Activate on "kick off a project", "kickoff", "start a new project", "new project", "bootstrap a project", "project questionnaire", "fill in the project charter", "scaffold the project", "run kickoff on this existing project", "kick off an existing project", "what is missing from this project's setup", "close the gaps", "bring this project in line with the answers", "/kickoff:kickoff init", "starting context for this project", "which quality level should this project have", "which tests and checks should this project have", "quality gate for a new project", "which dev port should this project use", "port registry", "e2e viewer", "test viewer", "replay a test", "watch a test run", "what to do next after kickoff", "which tasks after kickoff", or when the user begins describing a new project's goal, client, hosting or constraints from scratch.
version: 0.10.2
---

# Kickoff

Kickoff collects what is known about a project and makes its starting decisions with the user. The
user answers the **same questionnaire** at the start of every project; the answers may or may not be
the same. It names no language, stack, vendor or tool: those come from the answers. Pre-defined
options keep both sides precise, defaults keep it fast, and the answers end up in files, not in chat
history.

- **The questions, and how they are asked:** [`references/questionnaire.md`](references/questionnaire.md).
  It is the single source. Read it before the first question (its §How it is asked and §F included),
  and never restate or invent questions.
- **The E2E viewer, when F13 = Yes:** [`references/e2e-viewer.md`](references/e2e-viewer.md) — what the project
  must have, its security rules, the acceptance scenarios and the recommended tool. Read it only for that task.
- **The answers:** `<project>/.kickoff-answers`, plain `ID: value` lines, written only by `answer.sh`.
- **The output:** `docs/project/charter.md` (`charter.sh`); `docs/project/quality.md`, the task setup
  and the project CLAUDE.md (`scaffold.sh`).

`<PLUGIN_ROOT>` below is this plugin's directory. Resolve it relative to this file.

## Commands

| Argument | Does |
|---|---|
| `init` | Kickoff for an **existing project**: the loop below, with step 0 in full |
| _(none)_ | The loop below; step 0 runs whenever the directory already has files |

Any other argument: say which ones exist, and do nothing else.

## The loop

0. **Collect before asking.** For an existing project (the directory already has files):
   - **With docs-manager installed and no `docs/_index.md` yet, onboard the docs first**
     (`/docs-manager:docs-manager init`): the judged pass below reads what it builds.
   - **Script pass:** `bash <PLUGIN_ROOT>/scripts/inspect.sh <project>`. Each row is
     `id · proposed answer · evidence`, read from files (git, task setup, manifests, compose, deploy and
     locale files), only for unanswered questions. It writes nothing.
   - **Judged pass:** for every question still without a proposal that the project can answer (the
     one-liner and kind, the goal, the users and non-goals, the data, login, outbound effects,
     external services, languages, constraints), read the README, `docs/` and the code, and propose
     an answer with the file and line it came from. Add what the user's standing instructions (their
     CLAUDE.md) already settle, with that as the evidence. Never propose from a guess: no evidence, no
     row.
   - **One table** for both passes: `id · proposal · evidence · script | judged`. Ask the user to
     *confirm all* or *change some*. An inference is never an answer until then.
   - **Record each confirmed row with its evidence:** `answer.sh --root <project> <ID> "<value>"`, then
     `answer.sh --root <project> <ID>.from "<evidence>"`. The charter marks those answers *recovered*.
     A list answer (F12, one `<check> → <tool>` row per tool) comes as several rows: record the first as
     above and each further one with `--add`.

1. **See what to ask now:**
   `bash <PLUGIN_ROOT>/scripts/plan.sh <project> --next`. Each row is
   `section · id · state · value · question · options`, where value is the default to offer. Empty
   output means every question is settled: go to step 4. So does a row of section N: it comes only after the
   docs are written (steps 5–6) and is asked in step 7; it shows up here early only when a charter exists from an earlier run.
   - **ask:** ask it.
   - **explicit:** ask it on its own, never inside *accept all defaults*. Offer the value as the
     recommended option, first. The user picks, even when they pick the recommendation (C5, F1).
   - **judge:** its condition is prose (*"the project serves on a port"*). Decide from what you know. If it
     does not apply, record `n/a` without asking; if unsure, ask.
   - **pending** rows are not listed. They wait for an answer in this round — their condition or
     their default depends on it — and come up in the next one.
   Which sibling plugins count as installed is read from Claude Code's own record; a question about
   a plugin that is not installed is skipped.
2. **Ask the whole section in one go.** First show its questions with their defaults as a short list,
   then offer *accept all defaults* or *change some*. The defaults cover only the *ask* rows. Ask only the questions the user wants to change.
   - Questions with options go through the question UI, up to 4 per call. The default comes first,
     marked "(Recommended)". Keep each label short and put the full option text in its description.
     A `(pick any)` question is multi-select, its labels starting DROP — / ADD — / OUT OF SCOPE — / USES — /
     CREATE — / REVIEW —.
   - Free-text questions (name, one-liner, goal, those with no options) are asked in plain chat.
   - **Compute the computed defaults** (`*italics*`) before offering them, so the user confirms a concrete value:
     A1 is the repo directory name, A4 comes from the git remote owner, A5 is `git remote get-url origin`,
     D3 and K2 are the language of this conversation, R8 is 3–5 capital letters from A1, and I6 is
     `bash <PLUGIN_ROOT>/scripts/ports.sh next`. **Before the first port**, run `ports.sh scope`: on `ask` (HOME is
     usable and nobody has chosen) ask the user whether to keep the port list in HOME, shared by every project on
     the machine, or in this project's folder, and record the answer with `ports.sh scope home|project`. Never
     write to HOME unasked. On `project-no-home` HOME is not usable: say once that the ports are kept in the
     project folder and see only this project's own compose files, and do not ask. `home` and `project`
     are settled already (an existing `~/.claude/kickoff/ports.json` counts as an earlier yes). Once I6 is confirmed, reserve it with
     `ports.sh allocate <A1>`. Use `<A1>/<service>` for each further port. Then record the port.
     F13 = Yes (the E2E viewer) takes two more: `ports.sh viewer <A1>` derives and registers them from the
     app's port; they go into the viewer's task if one is created (step 7).
   - **Work out the proposed options** (`*Claude proposes …*`: B1, B6, C2, D2, E1, E2, I4, I5, the Domain
     checks and the tools in §F) from the answers so far, and offer them as ordinary options.
   - `answer.sh` refuses the italic text of a computed or proposed option.
   - **Section F:** F1 sets the level; each aspect (F2–F7) then asks only for the difference from it,
     as DROP — / ADD — options. Ticking nothing keeps the level's checks.
   - **"Not decided yet" is always a valid answer.** Record it as that; never fill in a guess.
   - **After each section, check the answers against each other.** Show a conflict with both answers
     and let the user resolve it before going on.
3. **Record every answer as it comes:**
   `bash <PLUGIN_ROOT>/scripts/answer.sh --root <project> <ID> "<value>"`.
   - Record **the option's full text exactly as the questionnaire spells it**, not your short label.
     Later conditions match on its start (`A3 = PoC` matches `PoC / experiment`).
   - A multi-select answer is recorded as the resulting set: the first value plain, each further one
     with `--add`. For an §F aspect that is the level's checks with the drops removed and the adds added,
     by check name; a `has` condition (`F2 has Integration`) matches any of them.
   - When the user gives a reason, record it with `<ID>.why`. It becomes the Why column of the decision.
   - Then go back to step 1.
4. **Review screen:** `bash <PLUGIN_ROOT>/scripts/plan.sh <project> --review`. Show the table, run the
   cross-check once more, and ask *write the files* or *change answers*. An answer marked *no longer
   applies* was given to a question that a later answer made irrelevant. It is kept, and it is not written.
5. **Write the charter:** `bash <PLUGIN_ROOT>/scripts/charter.sh <project>`. It prints `created`,
   `unchanged`, or `refused` (exit 3) when an existing charter differs. Then show the difference
   (`charter.sh <project> --diff`) and ask before `--force`, because the charter may have been
   edited by hand since kickoff.
6. **Write the docs.** Kickoff's goal is to collect; this step records it all, without asking whether to.
   - `bash <PLUGIN_ROOT>/scripts/scaffold.sh <project>` writes the task config and workflow (when markdown task
     files were chosen, without the practices left out in R10), the quality doc (§F answers) and the project
     CLAUDE.md, one line per file. A refused CLAUDE.md or quality doc is handled like a refused charter:
     `scaffold.sh <project> --diff` shows the change and writes nothing, and `--force` applies it once the user
     agrees. Seeded files (task config, workflow) that already exist are never touched.
   - The layout of `docs/` belongs to docs-manager. If it is installed, let it set `docs/` up and regenerate the
     indexes (`docs.sh index --write`); kickoff writes only into `docs/project/`.
   - **What has no question still gets written.** Write `docs/project/architecture.md`, the overview the answers
     imply (kind, stack, hosting, data, external services, entry point), and `docs/project/notes.md`, what the
     user said during kickoff that no answer holds. Both are Claude's prose, not generated: the user edits them.
7. **What next.** `bash <PLUGIN_ROOT>/scripts/plan.sh <project> --next` now offers one question of section N: N1
   for a new project, N2 for an existing one (A0). Ask it as any `(pick any)` question; nothing ticked is `None`.
   Each ticked option is a list of tasks Claude works out, shows (title and one line each) and creates only on
   the user's OK, with `/task create` when the task plugin is installed, otherwise as a list for the user's
   tracker (R6). Their ids come from the task plugin, never from kickoff. **Never create a task the user did not
   pick here: kickoff does not plan the project.**
   - **Infra and tooling, new project:** the foundation the answers call for, as §N lists. The E2E viewer's task
     (F13 = Yes) carries its two ports and points at [`references/e2e-viewer.md`](references/e2e-viewer.md): the
     project builds the tooling, the guide says what it must do.
   - **Features and business logic** (new project only): one first vertical slice from the goal and scope; more
     only when the user asks.
   - **Infra and tooling, existing project:** one task per gap. `bash <PLUGIN_ROOT>/scripts/gaps.sh <project>`
     prints `id · answer · gap · where it looked`, one row per gap a file can show (the entry point, containers,
     tests, E2E, the E2E viewer, CI, pre-commit, each F12 tool, the quality doc, CLAUDE.md, `docs/`). It writes
     nothing. Each task names its answer and a concrete action for this stack ("add `scripts/dev.sh` with up,
     down, test, sh").
   - **Review the legacy code** (existing project only): read the code against the answers and find what only
     reading shows: a check in `docs/project/quality.md` that nothing runs, an answer the code contradicts (*no
     login* with a login form), one command that does not run every check. One task per finding, naming its
     answer and the file it is seen in.
   - A gap or finding the user does not want as a task is a decision: record why with `answer.sh <ID>.why` (a gap
     with id `-` has no question: say it in chat), so the charter says so.

## Rules

- **Never re-ask what the user's standing instructions already settle.** Propose it from them in
  step 0. Only how this project differs is asked (E4).
- **A6 decides identity.** When the user wants their personal identity kept out (the default for a
  project that is not theirs, A4), it must not appear anywhere in it. Say so when A6 is answered.
- **Resuming is free.** `plan.sh --next` starts from what `.kickoff-answers` already holds, so a
  kickoff interrupted by a context reset just continues.
- **The user's own defaults.** When the user changes a default and says it should be their default from
  now on, or changes the same default at a second kickoff, offer to save it:
  `bash <PLUGIN_ROOT>/scripts/defaults.sh set <ID> "<value>"`. It is kept for this Claude account only, so a
  work account and a personal one keep different defaults. `defaults.sh list` shows them.
- **A changed answer** is recorded again with `answer.sh`: it replaces the old one, and the plan
  re-evaluates everything that depends on it.
