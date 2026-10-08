---
name: kickoff
description: Use when the user starts a new project and its starting context has to be collected — walk them through the standard kickoff questionnaire (questions branch on earlier answers, each with pre-defined options and a default) and turn the answers into the project's charter. Activate on "kick off a project", "kickoff", "start a new project", "new project", "bootstrap a project", "project questionnaire", "fill in the project charter", "scaffold the project", "run kickoff on this existing project", "what is missing from this project's setup", "starting context for this project", "which dev port should this project use", "port registry", or when the user begins describing a new project's goal, client, hosting or constraints from scratch.
version: 0.5.0
---

# Kickoff

The user answers the **same questionnaire** at the start of every project; the answers may or may
not be the same. Pre-defined options keep both sides precise, defaults keep it fast, and the answers
end up in files, not in chat history.

- **The questions:** [`references/questionnaire.md`](references/questionnaire.md). It is the single
  source. Read it before the first question, and never restate or invent questions.
- **The answers:** `<project>/.kickoff-answers`, plain `ID: value` lines, written only by `answer.sh`.
- **The output:** `docs/project/charter.md`, generated from the answers by `charter.sh`.

`<PLUGIN_ROOT>` below is this plugin's directory. Resolve it relative to this file.

## The loop

0. **An existing project first** (the directory already has files): run
   `bash <PLUGIN_ROOT>/scripts/inspect.sh <project>`. Each row is `id · proposed answer · evidence`. It
   is read from the project and covers only unanswered questions. Show the rows as one table, the
   evidence included, and ask the user to *confirm all* or *change some*. Record only what is
   confirmed. An inference is never an answer until then. inspect.sh writes nothing.

1. **See what to ask now:**
   `bash <PLUGIN_ROOT>/scripts/plan.sh <project> --next`. Each row is
   `section · id · state · value · question · options`, where value is the default to offer. Empty
   output means every question is settled: go to step 4.
   - **ask:** ask it.
   - **judge:** its condition is prose (*"the project serves HTTP"*). Decide from what you know. If it
     does not apply, record `n/a` without asking; if unsure, ask.
   - **pending** rows are not listed. They depend on an answer in this round and come up in the next one.
2. **Ask the whole section in one go.** First show its questions with their defaults as a short list,
   then offer *accept all defaults* or *change some*. Ask only the questions the user wants to change.
   - Questions with options go through the question UI, up to 4 per call. The default comes first,
     marked "(Recommended)". Keep each label short and put the full option text in its description.
   - Free-text questions (name, one-liner, goal, non-goals, those with no options) are asked in plain chat.
   - **Compute the computed defaults** before offering them, so the user confirms a concrete value:
     A1 is the repo directory name, A4 comes from the git remote owner, A5 is `git remote get-url origin`,
     and I5 is `bash <PLUGIN_ROOT>/scripts/ports.sh next`. Once I5 is confirmed, reserve it with
     `ports.sh allocate <A1>`. Use `<A1>/<service>` for each further port. Then record the port.
   - **"Not decided yet" is always a valid answer.** Record it as that; never fill in a guess.
3. **Record every answer as it comes:**
   `bash <PLUGIN_ROOT>/scripts/answer.sh --root <project> <ID> "<value>"`.
   - Record **the option's full text exactly as the questionnaire spells it**, not your short label.
     Later conditions match on its start (`A3 = PoC` matches `PoC / experiment`).
   - Lists (non-goals C2, services E4) take one `--add` per item.
   - When the user gives a reason, record it with `<ID>.why`. It becomes the Why column of the decision.
   - Then go back to step 1.
4. **Review screen:** `bash <PLUGIN_ROOT>/scripts/plan.sh <project> --review`. Show the table and ask
   *write the files* or *change answers*. An answer marked *no longer applies* was given to a question
   that a later answer made irrelevant. It is kept, and it is not written.
5. **Write the charter:** `bash <PLUGIN_ROOT>/scripts/charter.sh <project>`. It prints `created`,
   `unchanged`, or `refused` (exit 3) when an existing charter differs. Then show the difference
   (`charter.sh <project> --diff`) and ask before `--force`, because the charter may have been
   edited by hand since kickoff.
6. **Set the project up:** `bash <PLUGIN_ROOT>/scripts/scaffold.sh <project>`. From sections R and K it
   writes the `docs/` skeleton, the task config and workflow, and the project CLAUDE.md, one line per file.
   A refused CLAUDE.md is handled like a refused charter: `scaffold.sh <project> --diff` shows the change
   and writes nothing, and `--force` applies it once the user agrees. Seeded files (`_index.md`, task
   config, workflow) that already exist are never touched. Then:
   - if docs-manager is installed, regenerate the indexes (`docs.sh index --write`) and fill in any
     `description: TODO` it leaves;
   - create the first tasks that the output names with `/task create`, if the task plugin is installed.
     Their ids come from the task plugin, never from kickoff.

## Rules

- **Never ask about the global rules** (Docker only, docs first, roles, test policy, git approval,
  DRY). They already apply. Only exceptions are asked (E5).
- **A4 decides identity.** If the project is not the user's own, their personal identity must not
  appear anywhere in it. Say so when A4 is answered.
- **Resuming is free.** `plan.sh --next` starts from what `.kickoff-answers` already holds, so a
  kickoff interrupted by a context reset just continues.
- **The user's own defaults.** When the user changes a default and says it should be their default from
  now on, or changes the same default at a second kickoff, offer to save it:
  `bash <PLUGIN_ROOT>/scripts/defaults.sh set <ID> "<value>"`. It is kept for this Claude account only, so a
  work account and a personal one keep different defaults. `defaults.sh list` shows them.
- **A changed answer** is recorded again with `answer.sh`: it replaces the old one, and the plan
  re-evaluates everything that depends on it.
