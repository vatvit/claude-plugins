---
title: "Cowork research: what the plugins can rely on inside Claude Desktop Cowork, and how to detect it"
status: completed
type: research
priority: medium
epic: cowork
created: 2026-11-11 17:08
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | no prior Cowork work; inventory verified, 3 corrections — see Context |
| 30 | Assessment | done | ready: lib.sh per plugin + env overrides; not ready: kickoff triplicated registry path, delay host guard |
| 40 | POC | done | part 1 (docs) done; part 2 (probe on a device) dropped after round 2: the requirement no longer depends on Cowork internals |
| 60 | Architecture | done | per-project location in .git/<plugin>/, HOME usable = writable, fall back + say so, tests without HOME |
| 90 | Implementation | done | root CLAUDE.md: Per-project location + "Without HOME" rule under Config convention |
| 110 | Reflection | done | the rule lives in root CLAUDE.md; no memory entry needed; task files keep only the history |

## Description

The first sub-task of the `cowork` epic (PLUG-117), where the goal and the user's decisions are recorded. **Research only.**
It finds out what a plugin can rely on inside Cowork and writes that down once, so that the per-plugin
sub-tasks PLUG-118…123 can run in parallel without each one re-researching it. Those sub-tasks are
placeholders until this task finishes. PLUG-124 (this repo's own workflow) does not wait for it.


## Context

**Epic:** PLUG-117 `cowork`. Siblings PLUG-118…124 are placeholders that wait for this task, except 124.

**Prior work:** no earlier task touches Cowork, Desktop or any sandbox. Related decisions, already summarised
in root `CLAUDE.md` under *Config convention → Per account or per machine*, and not to be re-decided here:
- PLUG-033 (crew) and PLUG-038 (kickoff): per-account data follows `${CLAUDE_CONFIG_DIR:-~/.claude}`.
- PLUG-037 (kickoff ports), PLUG-074 (crew machine-wide slots), PLUG-054 (delay, several accounts):
  machine-wide state lives in `~/.claude/<plugin>/` and deliberately ignores `CLAUDE_CONFIG_DIR`.
  Cowork is the first case where "the machine" (the VM) is not the machine the resources belong to (the host).

**Docs:** this repo has no `docs/` tree. The knowledge lives in root `CLAUDE.md` (shell conventions, config
convention) and in each plugin's `CLAUDE.md`. Nothing there mentions Cowork or a sandbox.

**Code, verified 2026-11-11 (shipped scripts, not tests). Three corrections to the inventory above:**
- **session-storage** never touches `~/.claude`. It keeps its data in `${CLAUDE_CODE_TMPDIR:-/tmp}/claude-session-storage`
  and depends entirely on its SessionStart hook to hand out the session id. In Cowork the question is
  whether hooks run and `/tmp` is writable, not where a config lives.
- **Docker in crew and kickoff is optional and already guarded.** crew `lib.sh:126` does `command -v docker || return 0`
  (it is used only to read compose ports). kickoff only looks for compose files and never runs docker. The claim
  above that "crew watch/slots and kickoff checks call docker" was wrong. **Only delay requires docker**
  (`dispatch.sh`, `approve.sh`), together with `launchctl`, `pmset` and `caffeinate`, so delay is host-only by design.
- **kickoff** also defaults `KICKOFF_PROJECTS_DIR` to `$HOME/projects` (`ports.sh:26`) for its port scan.
  In the VM that folder will probably be empty or missing.
- crew `land.sh` uses `lsof` when it exists (guarded). docs-manager and task-roadmap have no `HOME` path, no
  host tool and only a PostToolUse hook each. No shipped script calls the `claude` CLI.

**Hooks per plugin** (the POC must confirm that each kind fires in Cowork):
session-storage SessionStart and SessionEnd; crew SessionStart, PreToolUse, PostToolUse and Stop;
docs-manager and task-roadmap PostToolUse; task, delay and kickoff none.

**Parallel-session collisions:** a crew is running in this repo (delay and kickoff sessions). This task
writes only task files and, at Implementation, a root doc, so there is no overlap with plugin code. The
sub-tasks will touch `crew/`, `delay/` and `kickoff/` scripts, so check crew holds before starting them.

## Assessment

How ready is the code to gain a Cowork branch without changing the CLI? (2026-11-11)

**Ready:**
- **One place per plugin where paths are decided:** `lib.sh` in task, crew and delay. A detection function and a
  Cowork branch fit there without touching the callers.
- **Env overrides already exist** for most locations: `CREW_HOME`, `CREW_USER_CONFIG`, `DELAY_HOME`,
  `KICKOFF_PORTS_FILE`, `KICKOFF_PROJECTS_DIR`, `KICKOFF_PLUGINS` (sibling list), and `CLAUDE_CODE_TMPDIR`
  (session-storage). Tests use them already, so a Cowork test can simulate the VM through the same mechanism.
- **Linux userland is already exercised.** Every suite runs in an Alpine `bash:5` container
  (for example `crew/CLAUDE.md:190`, `delay/CLAUDE.md:75`), so the GNU/busybox code paths are proven. The
  bash 3.2 and BSD+GNU conventions in root `CLAUDE.md` cover a Linux VM.
- crew and kickoff already degrade when docker or lsof are missing (`command -v … || return 0`).

**Not ready (each one is input to its sub-task):**
- **kickoff locates the task plugin's global registry in three places, and they disagree.** `gaps.sh:50`
  and `scaffold.sh:61` use `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`, while `inspect.sh:53` uses `${CLAUDE_CONFIG_DIR:-}` plus a
  `$HOME/.claude` fallback. This is duplication inside one plugin. **PLUG-121 must first move it into one helper in
  `kickoff/scripts/lib.sh`** and only then add the Cowork branch, or the branch gets added three times.
- **The task plugin has no override of its own** for its global dir; only `CLAUDE_CONFIG_DIR` changes it
  (`task/scripts/lib.sh:5-12`). It needs a branch in that function, not a new env var.
- **crew `time.sh:38` scans `~/.claude*`** for transcripts outside `lib.sh`. Check whether this is a second
  copy of the config-dir logic when PLUG-119 starts.
- **delay has no notion of "this host can't run me"** apart from its install checks. It needs one guard at
  the entry of every command (PLUG-120).
- **No plugin has a Cowork test fixture.** The detection signal from the POC defines what a test sets.

**Correction to Context:** a top-level `docs/` does exist, but it holds only the README pictures (`docs/images/`),
not project knowledge. The conclusion stands: no doc covers Cowork, and the new shared doc will be the first one.

## POC, part 1: documentation research (2026-11-11)

Read from official docs, issues and the changelog through sub-agents. Each label says how firm the fact is.
Probe script: `PLUG-111/cowork-probe.sh` (read-only; prints allow-listed env values and only the names of
other variables; tested in an Alpine container).

**The finding that reshapes the epic: since 2026-10-06, Cowork on Pro, Max and Ultra runs in the cloud.**
- *Docs:* "On October 6, 2026, new Cowork tasks on Pro, Max, and Ultra plans run in the cloud." The "Only on your
  computer" setting was removed. A local VM remains only for "existing desktop deployments" and for tasks started
  before that date. Team and Enterprise are not covered by that cutoff text.
  (support.claude.com articles 14479288 "Cowork architecture overview" and 15520349 "Use Claude Cowork on web, desktop and mobile")
- *Docs, cloud mode:* each session gets an "isolated, temporary sandbox" on Anthropic's infrastructure.
  Connected folders on the user's computer are reachable **only through the Desktop app's file tools**, only
  while the app is open, and "Claude fetches a copy of just that file". **The project tree is not a filesystem
  that a plugin's bash script can walk:** no `.tasks/` directory to scan, no git repo, no `docker`.
- *Docs:* "Local MCP servers don't run in sessions in the cloud." Skills and plugins are listed as available on
  Desktop, Web and Mobile.

**Plugins in Cowork** (claude.com/docs/plugins/platform-support):
- Docs: installed by zip upload or by adding a marketplace from a Git URL. Skills, commands and agents load. A top-level `bin/`
  makes the install fail (none of our plugins has one).
- **Hooks are contested.** The docs table says "Loads", but issues #27398, #40495 (open, `area:cowork`) and #63047 report
  that plugin SessionStart, PreToolUse and PostToolUse hooks never fire in the local VM. The changelog (2.1.314, 2.1.321)
  shows PostToolUse running in cloud sessions. Treat every hook as *unreliable* until a probe shows it firing.
  That hits session-storage hardest (it lives on SessionStart) and crew's guards.

**Local VM facts** (relevant only to existing desktop deployments and Team/Enterprise; issue #40495 plus a third-party gist):
Ubuntu 22.04, bubblewrap isolation, `HOME=/sessions/<name>`, connected folders under `/sessions/<name>/mnt/`, no
docker. Env: `CLAUDE_CODE_IS_COWORK=1`, `CLAUDE_CODE_ENTRYPOINT=local-agent`, and
`CLAUDE_CONFIG_DIR=/sessions/<name>/mnt/.claude`. That would give the plugins a ready-made `CLAUDE_CONFIG_DIR`,
**but these variables are undocumented** (they are absent from the env-vars reference). The VM filesystem is said to
reset between tasks, apart from mounted folders.

**Still unknown** (needs a probe on the device): which mode the user's account actually gets, tool versions, whether
hooks fire, and where `CLAUDE_PLUGIN_DATA` resolves.

**Team and Enterprise** (articles 14479288, 12622667, 17444462 and 15520349, read 2026-11-11):
- The cloud is the default on every plan: "Cowork sessions run in the cloud by default." Team cloud is in beta; Enterprise cloud is
  available "when an owner enables it".
- Local stays for "existing desktop deployments". Enterprise owners can "Turn sessions in the cloud on or off for the
  organization, while leaving local desktop Cowork available". No end date is given for local on Team or Enterprise. No page says
  whether a *new* org can still run Cowork locally, and no MDM key chooses between local and cloud.
- Enterprise's "new unified Claude experience" ("Agentic work runs in an isolated cloud sandbox") turns on by default in
  existing orgs on 2026-11-16.
- Direction: cloud everywhere, with local kept for organisations that already run it.
- **Observation:** in the local VM, `CLAUDE_CONFIG_DIR` points at a mounted `.claude` (per issue #40495), which every plugin
  already honours for per-account files, and `HOME` is a writable `/sessions/<name>`, so machine-wide state would
  simply be per-VM. **The local VM may need little or no code**; the real gaps are hooks and delay. This is not
  verified, and we have no Team or Enterprise account to verify it on.

**Decision needed before Architecture:** see Current State.

## Architecture (2026-11-11)

One rule for every plugin that must work with the project folder only (all except delay and session-storage). Recorded in
root `CLAUDE.md`, *Config convention → Without HOME*. Per-plugin choices stay in each sub-task.

1. **A third kind of location: per-project.** Next to per-account and machine-wide, add per-project state at
   `$(git rev-parse --git-common-dir)/<plugin>/`, or `<project>/.<plugin>/` outside git. Model: crew's existing
   `.git/crew/` (claims, holds, mail). It is inside the project folder, never committed, and shared by every worktree.
2. **HOME is "usable" only if the plugin can write there.** Test by creating the plugin's own dir and a temp file in it,
   once per run, through one helper in the plugin's `lib.sh`. A set `$HOME` proves nothing: in a VM or sandbox it may be
   read-only or thrown away.
3. **Reading HOME:** missing or unreadable means defaults. This is already true for every per-account file. Keep it, and
   test it.
4. **Writing machine-wide state when HOME is not usable:** fall back to the per-project location, say so once in the output
   (for example `slots: project scope — HOME not writable`), and never fail. With HOME usable, today's behaviour stays the default.
5. **A scope the user chooses is recorded in the project's own config** (`.crew.json`, the kickoff answers), never in HOME.
   That way the choice is still there when HOME is not.
6. **Reading from `${CLAUDE_PLUGIN_ROOT}` is allowed.** The host provides it, read-only, wherever the plugin is installed. That
   makes it the place for shipped defaults (an option for PLUG-118's step definitions). Never write there.
7. **Tests:** every affected suite gets a case with `HOME` pointed at a missing dir and one with a read-only HOME, run in the
   container. A project-only fallback that has never run without HOME counts as untested.

Rejected: Cowork detection (user, epic round 2); one shared helper across plugins (Plugin Independence); a new env var
per plugin to point at the project (rule 4 makes it unnecessary, and the existing overrides stay for tests).

## Open questions (answer at POC, on a real Cowork session)

1. **How does a script tell that it runs in Cowork?** It needs a signal that is reliable, cheap and impossible
   to trigger on the CLI by accident: an env var, a path, a hostname, or something in the hook's stdin JSON.
   The detection decision depends on this answer (PLUG-117).
2. What `$HOME`, `$CLAUDE_CONFIG_DIR`, `${CLAUDE_PLUGIN_ROOT}` and the plugin cache path are inside the VM,
   and which of them are writable and persist across restarts.
3. Do plugin hooks (SessionStart, PreToolUse) run there, and do they get the same JSON on stdin?
4. Is `installed_plugins.json` (or an equivalent) visible, so that a plugin can detect its siblings?
5. Which tools exist in the VM: docker, git, bash version, awk flavour, `date` and `stat`?

Expected answers, written before any test (verify each one):
- The VM's `~` is not the host's `~/.claude`, so per-account files are absent and plugins fall back to their defaults.
- Machine-wide state (crew registry and slots, kickoff ports, delay queue) is per-VM. Host sessions can't see it, and it may not survive a restart.
- delay needs launchd and pmset on the host, so it most likely can't work in Cowork.
- docker is unlikely to exist. Any feature that calls it must report that it is unavailable instead of failing obscurely.
- The userland is GNU on Linux, which the BSD+GNU shell conventions already cover.

## First inventory of ~/.claude dependencies (from grep, 2026-11-11; verify at Context)

| Plugin | Reads/writes | Kind | Sub-task |
|---|---|---|---|
| task | `${CLAUDE_CONFIG_DIR:-~/.claude}/project-tasks/config.json` (global config layer), `project-tasks/_workflow/steps/` (global step definitions) | per account | PLUG-118 |
| crew | `~/.claude/crew/` (CREW_HOME: name registry, slot queue), `${CLAUDE_CONFIG_DIR:-~/.claude}/crew.json`, transcripts under `~/.claude*/projects/` (time.sh) | machine + account | PLUG-119 |
| delay | `~/.claude/delay/` (DELAY_HOME: queue, per-project stores, results); launchd, pmset, docker | machine | PLUG-120 |
| kickoff | `kickoff.json` user defaults, `~/.claude/kickoff/ports.json` port registry, `plugins/installed_plugins.json` (sibling detection), `project-tasks/` (scaffold, inspect, gaps) | machine + account | PLUG-121 |
| session-storage | none found in scripts; check where storage.sh keeps its data | ? | PLUG-122 |
| docs-manager, task-roadmap | none found | — | PLUG-123 |

Already in place: most paths use `${CLAUDE_CONFIG_DIR:-$HOME/.claude}` or an env override
(`CREW_HOME`, `DELAY_HOME`, `KICKOFF_PORTS_FILE`, `CREW_USER_CONFIG`). Find out whether a plugin can
point those overrides at a writable dir by itself once it detects Cowork. Nobody else will set them for it.

## Expected output

- The answers above, written once in a doc, not in this task. Because the plugins share no code, the
  shared knowledge goes in a root doc (for example a "Cowork" section in root `CLAUDE.md`, or a page it links to).
  Each plugin's `CLAUDE.md` links to it.
- The fallback location for state in Cowork. Keep the per-account vs. machine-wide distinction from root `CLAUDE.md`.
- A per-plugin verdict: works as-is / needs a fallback location / not available in Cowork.
- PLUG-118…123 filled in from that verdict, or rejected where it shows no change is needed.

## Acceptance criteria

- Every `~/.claude` / `CLAUDE_CONFIG_DIR` reference in shipped scripts is listed with a verdict.
- Each open question has an answer backed by a real Cowork session, not by assumptions.
- The detection signal is documented, along with how to simulate it in tests.

## Current State

2026-11-11 18:40. Every workflow step is done. The deliverable is the *Without HOME* rule and the per-project location in root
`CLAUDE.md` (Config convention). The status is still in-progress; completing it is left to the user. Next: PLUG-118, 119, 121 and 123 can
run in parallel, each following that rule. PLUG-120 and 122 are exempt: reject them or keep the plain-message part. Then PLUG-124.
