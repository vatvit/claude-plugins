---
title: delay — Claude queues a (container, .sh) pair with params; the user approves the pair; dedupe on pair + params
status: completed
type: feature
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | prior work PLUG-013; live registry has one 1.x entry (smoke), live queue empty |
| 20 | Requirements | done | acceptance criteria below, agreed 2026-10-10 |
| 30 | Assessment | done | all of delay/scripts + docs; 2.0.0 (CLI change) |
| 40 | POC | skipped | no unknowns: argv append and set -- already proven in dispatch |
| 50 | Domain | skipped | no new domain terms beyond pair / params, defined in Decisions |
| 60 | Architecture | done | see Architecture |
| 70 | Tests | done | suite rewritten: 232 checks, 111 red before the change |
| 80 | Subtasks | skipped | one plugin, one session; no split needed |
| 90 | Implementation | done | 232/232 host + bash:5; new checks seen red by mutation |
| 100 | Tech Debt | done | usage-header awk in delay.sh + approve.sh unified as lib `header`; install script list is lib `DELAY_SCRIPTS` |
| 110 | Reflection | done | see Outcome |

## Description

The user asked for delay to stop duplicate jobs. Agreeing what counts as a duplicate reshaped how
jobs are named and approved. All decisions below were agreed with the user on 2026-10-10.

## Decisions

- **A job is a pair: container + `.sh`.**
  - The *container* is a compose file plus a service in the project. Delay starts it itself:
    `docker compose -f <compose> run --rm -T <service> <script.sh> <params…>`.
  - The `.sh` is a script inside the project and runs **inside** that container, so it contains no
    `docker` command itself.
  - Claude never queues a raw command (`docker …`, `npm …`), only a pair. Raw docker args can reach
    the whole Mac, for example `-v /:/host`.
- **Job names go away.** The pair itself is the key. Today's names (`tests`) were a safe key for the
  untrusted queue, a bundle of compose + service + command, and a way to approve variants. Path
  validation (`inside_project`) now does the first job, the pair the second, and params the third.
- **The user approves the pair, once.** The registry pins the `.sh`, the compose file and the
  Dockerfile by sha256, as today; any edit means re-approve. The existing red flags stay (privileged,
  host mounts outside the project, docker socket, host namespaces). Params are never approved.
- **Params are free.** `add <compose> <service> <script.sh> [-- param…]`. The exact CLI shape is
  settled at Architecture, with short forms if one pair per project is the norm. Params are stored one
  per line and passed as argv, never through a shell, never globbed, never eval'd. Each param must be
  non-empty, one line, with no NUL; at most 64 params and 4096 bytes in total.
- **Duplicate = same pair + same params as a multiset.** Order is ignored, and each param is compared
  as an exact string: `a b` = `b a`, but `filter=p1,p2` ≠ `filter=p2,p1`. A duplicate `add`
  **exits 0** and prints "already queued <id> — not added again". `test.sh -- full` and
  `test.sh -- smoke` are two jobs.
- **A param used as a command is the script author's problem (Claude's), not the approver's.** The
  rule lives in the user's global CLAUDE.md, added 2026-10-10. As a safety net, `approve.sh` scans the
  `.sh` and **refuses** param-as-command patterns (`eval`, `sh -c`/`bash -c` on a param,
  `npm run "$1"`-style, an unquoted `$@`/`$*` in command position), unless `--accept-risks` is given,
  the same as the other red flags. It points at the line.
- **Migration:** an existing registry entry already records `compose`, `service` and `wrapper`, so it
  becomes a pair without re-approval. A built-in `command=` with extra words (`test.sh full`) becomes
  the pair `test.sh`. Those words were approved, so they are kept as the leading params of that pair.
  An old queue entry that names a job is translated through the registry once.
- **Shown everywhere:** `list`, `show`, the result meta, the approve list and the ACTION block print
  the pair and its params.

## Trust boundary change (agreed)

Until now, Claude chose only *which* approved job runs. Now Claude also chooses its params. The
container still bounds the damage (pins, red flags, no host mounts outside the project). The
param-as-command scan stops the one way a script turns params into arbitrary code. delay/CLAUDE.md,
"Trust boundaries", must say this.

## Kickoff

No kickoff change is needed. The epic PLUG-049 rule is that kickoff never copies global rules into
project files, and kickoff does not generate scripts or a docker env. Revisit if kickoff ever scaffolds
a standard docker env.

## Out of scope

- Concurrent `add` of the same entry (check-then-write has no lock).
- `add` while the same entry is running (the dispatcher has already moved it out of the queue).
- One standard docker env per project (an idea discussed, not chosen).

## Acceptance criteria

- [ ] `add` of a pair queues it; `approve.sh` approves the pair; the dispatcher runs
      `docker compose -f C run --rm -T S script.sh <params…>`.
- [ ] `add … test.sh -- full`, then `-- smoke` → two entries.
- [ ] `-- a b`, then `-- b a` → one entry. The second exits 0 with "already queued <id>".
- [ ] `-- filter=p1,p2`, then `-- filter=p2,p1` → two entries.
- [ ] A param with a space or `*` reaches the script as one word, unglobbed.
- [ ] Bad params (empty, newline, >64, >4096 bytes) are refused by `add`.
- [ ] `add` of a raw command or a path outside the project is refused.
- [ ] `approve.sh` refuses a `.sh` with `eval "$1"`, `sh -c "$1"`, or `npm run "$1"` unless given
      `--accept-risks`. A clean `case "$1" in full) … ;; smoke) … ;; *) exit 2 ;; esac` passes.
- [ ] Editing the `.sh` after approval → the run is `needs-reapproval`, as today.
- [ ] An existing registry entry and queue entry from 1.x still run after the upgrade, without
      re-approval.
- [ ] Each new check was seen red before the fix. Suites pass on host + `bash:5` docker.
- [ ] README, SKILL.md (vocabulary: *job*, never *task*), delay/CLAUDE.md (trust boundaries)
      updated. plugin.json + marketplace.json bumped to 2.0.0, since the CLI changes.

## Current State

Completed 2026-10-10. delay 2.0.0: 232/232 on host and `bash:5`. Not committed (the coordinator commits).
The user must re-run `sudo bash delay/scripts/install.sh` once: the installed copies are 1.x, and the
install moves the live `smoke` approval to its pair. Nothing else is open.

## Context

**Prior work:** PLUG-013 built delay 1.0.0 and is the source of the trust boundaries in
`delay/CLAUDE.md`, which must not regress. No other task touches `delay/`. The crew session
`claude-plugins-kickoff` works only in `kickoff/` and `.tasks/PLUG-049..052`, so nothing collides.

**Code to touch:** all of `delay/scripts/` (lib.sh, delay.sh, approve.sh, dispatch.sh, start.sh
via `approved_queued`, install.sh for the migration) plus `scripts/test/delay.test.sh` (140 checks,
run on host + `bash:5` docker), README.md, SKILL.md, CLAUDE.md, plugin.json, marketplace.json.

**Facts that shape the design:**
- The dispatcher already splits the approved `command` with `set -f; set -- $command`: argv, no
  shell, no glob. Params can be appended to that same `set --`.
- `docker compose run [opts] SERVICE [COMMAND] [ARGS…]`: everything after SERVICE goes to the
  container, so docker never parses a param as its own option.
- **`command` ≠ script path in real use.** The live registry's one job (`smoke`, from
  `delay/examples/smoke`) has `wrapper=delay/examples/smoke/smoke.sh` but
  `command=bash /work/smoke.sh`, because the container mounts the dir at `/work`. So `command` stays
  an approval-time field (how the container calls the script); it is not part of the pair's identity.
- The live queue is empty, and the registry holds one entry (`smoke`). Migration is real but small.
- `kv` returns the first match only; params need a multi-value reader.
- bash 3.2 + `set -u`: `"${arr[@]}"` of an empty array is "unbound". Build argv with `set --`, not
  arrays.

## Architecture

**Files.** Registry: `registry/<enc-project>/jobs/<pair_id>` with `compose=`, `service=`, `script=`,
`command=`, `timeout=`, `approved_by=`, `pin=`. The 1.x key `wrapper=` becomes `script=`. Queue
entry: `id=`, `project=`, `created=`, `compose=`, `service=`, `script=`, then one `arg=` line per
param in the given order, then the optional `proposed_timeout=` / `proposed_command=`.

**Identity, one helper each in lib.sh:**
- `rel_inside <root> <path>` → the normalised project-relative path of a regular, non-symlink file
  inside the root. It replaces approve.sh's local `relpath`, and `add` uses it too, so both
  normalise the same way.
- `pair_id <compose> <service> <script>` → 12 hex of sha256. It names the registry file and passes
  `valid_name`.
- `entry_pair <file>` → `pair_id` of a queue entry's fields. `registry_pair <root> <pair_id>` →
  the approved file (it replaces `registry_job`).
- `entry_args <file>` → the params, one per line. `entry_sig <file>` → sha256 of the `pair_id`
  plus the `arg=` lines sorted with `LC_ALL=C`. This is the dedupe key: order is ignored, and each
  param is compared as an exact string.
- `job_desc <file>` → `script params… (compose / service)`. Every place that shows a job uses it.
- The approve ID stays `job_id <project> <pair_id>` (6 hex), so a pending pair and its approval
  share one ID, as today.
- `installed_current` moves out of `delay.sh status` into lib, so the ACTION block can also ask for
  the re-install that the 2.0 migration needs.

**CLI.**
- `delay.sh add <script.sh> [--compose F --service S] [--timeout N] [--command C] [-- params…]`.
  - The script must be `*.sh` and inside the project.
  - Omit `--compose`/`--service` when the script is approved with exactly one container. Zero
    matches → "name the container"; several → the list of choices.
  - Anything else before `--` is refused with the existing "no time argument" message.
  - Params: non-empty, one line, ≤64 params, ≤4096 bytes in total.
  - A duplicate (`entry_sig` equal) exits 0 and prints `already queued <id>: <desc> — not added
    again`. If it carries `--timeout`/`--command`, those update the existing entry's proposal.
- `approve.sh <project> <script.sh> --compose F --service S [--command] [--timeout] [--pin]…`
  replaces the name form. `approve.sh <ID>` is unchanged. `--revoke <ID>` is now the only revoke
  form, since there are no names to type.
- `delay.sh jobs` lists the approved pairs.

**Param-as-command scan** (approve.sh, a red flag that refuses without `--accept-risks`). It
covers non-comment lines of the script only, and reports the line number:
- `eval`
- `sh|bash|zsh|dash|ksh -c` with a `$` after it
- a positional param in command position: `$1`, `"$@"`, `${2}` at line start or after
  `; & | ( then do else exec`
- a package/build runner (the node ones, `make`, `just`, optionally `run`) taking a positional
  param as its target
- `source`/`.` of a positional param

It does not follow other files, and it does not catch a param copied into a variable that is
later run. Both limits are written in the README; the global CLAUDE.md rule covers them.

**Dispatcher.** It reads the pair from the entry and looks up `registry_pair`. It runs the
**registry's** compose, service and command (never the queue's), then `set -- "$@" "$arg"` for
each param. A queue entry from 1.x (`job=` only, no `script=`) → `invalid`, and the log says
"queued by delay 1.x — re-queue it".

**Migration** (install.sh, which already runs as root and which every update needs, because
launchd runs the installed copies): each `jobs/<file>` that has `wrapper=` is rewritten to
`jobs/<pair_id>` with `script=`. A collision (two 1.x names with the same pair) keeps the first,
and the report names the dropped one. No re-approval is needed: the pins are copied unchanged.

**Deviation from the acceptance criteria, decided here:** old *queue* entries are not translated.
They become `invalid` with a clear log line instead. The live queue is empty, and a translation
table kept only for this would be a second naming system.

## Outcome

- **Built as in Architecture.** `delay.sh add <script.sh> [--compose F --service S] [-- params…]`; pair
  registry `jobs/<pair_id>`; dedupe on `entry_sig` (pair + params sorted with `LC_ALL=C`); dispatcher
  appends params as argv after SERVICE and runs only the registry's command; `approve.sh` full form takes
  the script, `--revoke <ID>` only, and `scan_params` refuses param-as-command lines; install migrates 1.x
  names to pairs (collision keeps the first, reports the dropped one).
- **Acceptance criteria:** all met. The one deviation is the one recorded in Architecture: 1.x *queue* entries
  are not translated, they end `invalid` with "queued by delay 1.x — re-queue it" (9c).
- **Tests:** suite rewritten to 232 checks (111 red before the code). New sections: params and duplicates
  (20a–s), the scan (21a–k), 1.x migration (22a–e), plus argv exactness (6h) and queue-command ignored (6j).
  21 defects were injected one at a time on a standalone copy of `delay/` (which also proves the plugin
  runs without its siblings); each turned its check red.
- **Docs:** README (pairs, params, duplicates, the scan and its limits, upgrading from 1.x), SKILL.md
  (2.0.0, "writing the script" rule, new triggers), delay/CLAUDE.md trust boundaries (params are data;
  the registry's command only), plugin.json + marketplace.json 2.0.0.
- **Reflection:** the security rule for script authors went to the user's global CLAUDE.md (done during
  design). A tooling pitfall (the host-runtime hook matching runner names inside heredoc text) went to
  memory. No repo CLAUDE.md change: no new shell-portability trap was hit.

## Follow-up 2026-10-10 — install instructions (same uncommitted 2.0.0)

User asked how to install delay on another PC. The commands the user runs now come from one place,
`install_cmd`/`sys_cmd` in `delay.sh`: full, quoted paths in the ACTION block, `jobs` and `window:`, and
`status` prints `install_cmd=`, `approve_cmd=`, `start_cmd=`. README *Setup* covers `/plugin install`, where
the full path comes from, and several accounts; SKILL.md gains install triggers and a full-path rule. No short
command on PATH (user's decision). Tests 5e2, 5t2, 13h6, each seen red; 235/235 on the host and in bash:5.
The multi-account version back-and-forth is filed as PLUG-054.
