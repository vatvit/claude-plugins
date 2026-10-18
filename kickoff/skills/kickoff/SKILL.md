---
name: kickoff
description: Use when the user starts a new project and its starting context has to be collected — walk them through the standard kickoff questionnaire (generic for any language or stack; questions branch on earlier answers, each with pre-defined options and a default; sibling plugins asked about only when installed) and turn the answers into decisions: the project's charter, its quality level and checks, and its CLAUDE.md. Activate on "kick off a project", "kickoff", "start a new project", "new project", "bootstrap a project", "project questionnaire", "fill in the project charter", "scaffold the project", "run kickoff on this existing project", "what is missing from this project's setup", "starting context for this project", "which quality level should this project have", "which tests and checks should this project have", "quality gate for a new project", "which dev port should this project use", "port registry", or when the user begins describing a new project's goal, client, hosting or constraints from scratch.
version: 0.7.0
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
- **The answers:** `<project>/.kickoff-answers`, plain `ID: value` lines, written only by `answer.sh`.
- **The output:** `docs/project/charter.md` (`charter.sh`); `docs/project/quality.md`, the task setup
  and the project CLAUDE.md (`scaffold.sh`).

`<PLUGIN_ROOT>` below is this plugin's directory. Resolve it relative to this file.

## The loop

0. **Collect before asking.** For an existing project (the directory already has files), run
   `bash <PLUGIN_ROOT>/scripts/inspect.sh <project>`. Each row is `id · proposed answer · evidence`. It
   is read from the project and covers only unanswered questions. Add what the user's standing
   instructions (their CLAUDE.md) already settle, with that as the evidence. Show the rows as one
   table and ask the user to *confirm all* or *change some*. Record only what is confirmed. An
   inference is never an answer until then. inspect.sh writes nothing.

1. **See what to ask now:**
   `bash <PLUGIN_ROOT>/scripts/plan.sh <project> --next`. Each row is
   `section · id · state · value · question · options`, where value is the default to offer. Empty
   output means every question is settled: go to step 4.
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
     A `(pick any)` question is multi-select, its labels starting DROP — / ADD — / OUT OF SCOPE — / USES —.
   - Free-text questions (name, one-liner, goal, those with no options) are asked in plain chat.
   - **Compute the computed defaults** (`*italics*`) before offering them, so the user confirms a concrete value:
     A1 is the repo directory name, A4 comes from the git remote owner, A5 is `git remote get-url origin`,
     D3 and K2 are the language of this conversation, R8 is 3–5 capital letters from A1, and I6 is
     `bash <PLUGIN_ROOT>/scripts/ports.sh next`. Once I6 is confirmed, reserve it with
     `ports.sh allocate <A1>`. Use `<A1>/<service>` for each further port. Then record the port.
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
6. **Set the project up:** `bash <PLUGIN_ROOT>/scripts/scaffold.sh <project>`. It writes the task config
   and workflow (when markdown task files were chosen, without the practices left out in R10), the
   quality doc (§F answers) and the project CLAUDE.md, one line per file. A refused CLAUDE.md or quality
   doc is handled like a refused charter: `scaffold.sh <project> --diff` shows the change and writes
   nothing, and `--force` applies it once the user agrees. Seeded files (task config, workflow) that
   already exist are never touched. Then:
   - the layout of `docs/` belongs to docs-manager. If it is installed, let it set `docs/` up and
     regenerate the indexes (`docs.sh index --write`); kickoff writes only into `docs/project/`;
   - create the first tasks that the output names with `/task create`, if the task plugin is installed.
     Their ids come from the task plugin, never from kickoff.

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
