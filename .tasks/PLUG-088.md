---
title: "kickoff — instructions for reaching an E2E test viewer: the per-test result store, the trace whitelist, the viewer page and run-and-watch"
status: in-progress
type: feature
priority: medium
related: [PLUG-087]
tags: ["kickoff", "quality", "e2e"]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | a second reference file, read on demand; Node-only proven path |
| 20 | Requirements | done | a spec, not a build manual: Node proven, others named; no files; review, not a run |
| 30 | Assessment | done | references/ ready; pointers at SKILL.md steps 6–7 and the F13 bullet; nothing blocks |
| 40 | POC | skipped | the PoC was the proof |
| 50 | Domain | done | PLUG-087 §Domain terms: E2E viewer, trace, viewer ports, e2e:view |
| 60 | Architecture | done | one reference file, G1 sections; SKILL.md routes to it |
| 70 | Tests | done | 10a/10b: every reference SKILL.md links exists; seen red before the file |
| 80 | Subtasks | skipped | one file, one session |
| 90 | Implementation | done | references/e2e-viewer.md + pointers; fresh-agent review: 1 missing, 1 weakened, 4 unclear, 0 leaks, all fixed; 298 green host + bash:5 |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | kickoff CLAUDE.md layout names the guide |

## Description

The **instructions half** of the E2E test viewer in kickoff; the question and gap half is [PLUG-087](PLUG-087.md) (the
user's need and rulings are quoted there). The viewer is optional (the user, 2026-10-27: *"each project MAY have. the
Plugin can ask and provide instructions how to reach that."*). When a project says yes, or closes that gap, kickoff
**gives it the instructions**: what to build, in what order, and the pitfalls the PoC already hit, so the project does
not rediscover them. Whether kickoff also ships ready-made files is a Requirements question, not the default.

**The PoC's hardening pass is done (2026-10-27).** Its structured bug hunt gave a "safe to generalise" verdict for each
generic part (§Safe-to-generalise verdicts below), with the fixes the instructions must carry. Nothing waits on it now.

## What the PoC settled (generic — any Playwright project in Docker)

The user's rulings that shaped it:
- **Watching a new run is the main view.** A replay is a trace stepped at the user's pace, with nothing re-run. **No video.**
- **One stored result per test, overwritten by its next run** (passed / failed / flaky / skipped + when). No history.
- **A trace is kept only for a failed or flaky test, or a test on the whitelist**, toggled in the viewer, local to the
  machine, never committed. A test that passes and is not whitelisted loses its trace. Flaky counts as failed.
- **Local only:** every port published on `127.0.0.1`, because a trace holds the app's pictures and the viewer writes.

What it took:
- **A reporter writing one file per test on the final attempt, atomically**, so a run killed half-way still leaves every
  finished test's result. A trace is hard-linked into the store, not copied.
- **The whitelist read by the config at run start**, turned into a second project with `grep` / `grepInvert` and
  `trace: 'on'`; with an empty list the config is exactly the gate's. Tracing every test and deleting the passes was
  rejected: a trace measured ~45 MB median.
- **Playwright's trace viewer served from `playwright-core/lib/vite/traceViewer/`** on the same origin as the traces.
- **UI mode in a container:** ~~`--ui-host 0.0.0.0 --ui-port <p>`, published on `127.0.0.1` only~~ (not enough: see the Host and Origin check below; it must sit behind a checking proxy). UI mode runs **every**
  reporter of the config, so the report paths must be movable (an env var), or it overwrites the gate's reports.
- **Long-lived containers** by `docker compose run -d --rm --name … --publish 127.0.0.1:<p>:<p>`, no compose edit.
- **A canvas app** (WebGL) shows in a step's pane only with "Display canvas content" on (Playwright 1.50+, off by
  default); with it off, only in the screencast thumbnails. Below 1.50, black.
- **A CLI `--reporter=…` replaces the config's reporters**, so such a run feeds no store unless the store reporter is
  named too.
- **Named steps:** without `test.step()` a trace is a flat list of low-level calls; worth recommending in the template.
- **Pin the image and the package together.**
- **Host and Origin check — required; confirmed and fixed in the PoC's hardening pass (2026-10-27).** Binding to
  `127.0.0.1` alone is not enough: a DNS-rebinding page could read the list and the traces (any Host was served), and
  another site could flip the whitelist (any Origin, or none, was accepted, and a `text/plain` cross-site POST needs no
  preflight). The proven fix is one pure function, run first on every request; a refusal answers 403 with its reason:
  `requestRefusal({ method, host, origin }, viewPort) → reason | null`.
  - Allowed Host: exactly `127.0.0.1:<viewPort>` or `localhost:<viewPort>`. Any other Host, or none, is refused on
    every method and route.
  - GET / HEAD pass once the Host passes. Any other method needs `Origin === "http://" + <the request's allowed Host>`.
    A missing Origin is refused, because browsers send one on every POST.
  - Rejected: a CSRF token (more moving parts, and the Host check is still needed), and a JSON content-type rule (the
    Origin check covers it).
  - Tested on the real server: the handler factory returns a server that isn't listening yet, and the test runs it on
    a free port, sending crafted headers with `node:http` (fetch cannot set Host). S1: own hosts 200, rebinding hosts
    (`evil.example:<p>`, `evil.example`, `127.0.0.1:<other port>`) 403 with no trace bytes. S2: writes from another
    site, the same host on another port, or with no Origin 403, and the whitelist is unchanged byte for byte. S3: the
    page's own write lands. Each seen red by planting its defect back.
  - Also probed fine: path traversal (`..%2f`, `%2e%2e`, an encoded slash in the key, `%00`) → 404; a malformed
    escape → 400.
  - **Run-and-watch has the same hole (probed 2026-10-27, Playwright 1.64.1).** Playwright's UI-mode server checks
    neither Host nor Origin. `GET /` with a foreign Host returns a 302 to `./trace/uiMode.html?ws=<token>`, so a
    DNS-rebinding page can read the websocket token, and an upgrade to `/<token>` with a foreign Host and Origin gets
    101. A rebinding page can therefore drive UI mode: run tests and read what it shows. A plain cross-site page
    cannot, because it can't read the redirect.
  - **Its fix (tested and landed in the PoC, 2026-10-27):** one container runs two processes,
    `playwright test --ui-host 127.0.0.1 --ui-port <inner> & exec <proxy>`. The inner port (Playwright's default,
    9323) is unpublished. The proxy listens on `0.0.0.0:<published>`, and only that port is published, on `127.0.0.1`.
    - HTTP: `requestRefusal` (the Host allow-list) runs first, and a refused request gets 403. An allowed one is
      forwarded to `127.0.0.1:<inner>` with headers and body unchanged; if Playwright isn't up yet, the answer is 502.
    - Websocket upgrade: the same function with `upgrade: true`, so an upgrade counts as a write and Origin must be
      `http://<own host>`. A refusal is a raw `HTTP/1.1 403` on the socket. An allowed upgrade opens a raw TCP
      connection to the inner port, replays the request head from `rawHeaders`, forwards `head`, and pipes the two
      sockets both ways.
    - **Pitfall:** Node's HTTP-server socket allows half-open connections, so when the page leaves, the pair never
      closes and `server.close()` hangs. On the page socket's `end`, destroy the upstream; on either side's `close` or
      `error`, destroy the other.
    - Tests: a stand-in inner server copies Playwright as probed (`/` → 302 with a token; any upgrade → 101 plus an
      echo). S4: the own host passes through, while a rebinding host gets 403 and the token appears nowhere. S5: an
      own-origin upgrade gets 101 and the echo round-trips; another site, no Origin, or a rebinding host with a
      matching Origin all get 403. Each defect planted back went red. A shell check of the container command was red
      against the old `--ui-host 0.0.0.0`. Real run: own pages 200 / 302 and own websocket 101; a rebinding host 403
      and a foreign-Origin websocket 403. The UI-mode test tree loads in Chrome through the proxy.
  - **Verdict:** "UI mode in a container" is safe only in this shape. `--ui-host 0.0.0.0` published on
    `127.0.0.1` alone is not enough, so that piece of §What the PoC settled is superseded.
  - **Verdict:** the "long-lived container on `127.0.0.1`" piece is safe to generalise **only together with this check**.
- **Pausing a live run** needs a headed browser with the Inspector on a virtual display (noVNC); the PoC left it as a
  follow-up.

### Safe-to-generalise verdicts from the hardening pass (2026-10-27, all nine probes done)

1. **Per-test result reporter:** safe once its fixes are in.
   - It must **never throw**. On Playwright 1.64.1 a reporter error ends a passing run with exit 1, so a failed
     write prints `✗ <store>: <test> not stored — <why>` and the run goes on.
   - Temp file names use the pid **plus random bytes**: two containers on one store can share a pid.
   - The hard link falls back to a copy on `EXDEV` (another filesystem).
   - **One store only.** With several stores (one per environment), a trace superseded by a newer result in another
     store is never deleted: 44 of 53 traces, 2 GB, were unreachable. The instructions prescribe one store; the PoC's
     multi-store layout is its own (its design question stays open there).
2. **Whitelist as a second project via `grep` / `grepInvert`:** safe. The grep target was re-proven on 1.64.1.
3. **Trace viewer served on the traces' origin:** safe, behind the request check.
4. **Host allow-list on every route and Origin check on writes:** safe. It is the fix itself (above).
5. **UI mode in a container:** safe **only behind the proxy** (above). Published as it is, not safe.
6. **Long-lived containers by `compose run -d --publish 127.0.0.1:…`:** safe once fixed. Docker publishes over a host
   process already listening on the port with no error, and the URL then reaches that process. So the start
   checks the port first: if `(exec 3<>/dev/tcp/127.0.0.1/$P)` connects, refuse and name the port. Check "already
   running" before the port check, because the project's own container holds the port.
7. **"Display canvas content" off by default:** a fact, safe. The trace viewer keeps its settings in the serving
   origin's localStorage; on 1.64.1 the key is `shouldPopulateCanvasFromScreenshot`. A viewer page on the same origin
   can therefore turn it on by default (pending the user's ruling in the PoC). Pin the key with a test, since it is
   Playwright-internal.
8. **A CLI `--reporter` replaces the config's reporters:** a fact, safe.
9. **New, for the list:** one spec that doesn't compile empties Playwright's whole `--list` (exit 1, `suites: []`,
   the error in `errors`). The page shows `errors[0]` and never shows an empty list as "no tests".

Project-specific in the PoC, **not** to template: its dev lock, its night-gate folder layout, its script dispatcher, its
port numbers, its Playwright upgrade.

## Proposed shape (negotiable at Requirements)

- **A reference in kickoff** (e.g. `skills/kickoff/references/e2e-viewer.md`): the goal in the user's words, the
  pieces (result store reporter, whitelist as a second project, served trace viewer, UI mode in a container,
  `127.0.0.1` ports), the order to build them in, acceptance scenarios a project can turn into its tests, and the
  pitfalls above. Claude follows it in the project; kickoff points at it from the charter and the gap row.
- **The viewer's command is named `e2e:view` (or `e2e-view` where `:` cannot be used, e.g. a Makefile).** PLUG-087's
  gap rule recognises a viewer by that name in a setup file, so the instructions must use it. Its ports come from
  `ports.sh viewer <project>` (PLUG-087). A Yes reaches the project as a first task that follows these instructions.
- **Concept first, Playwright as the worked example.** kickoff names no stack or tool in a question or option
  (PLUG-078; see PLUG-087 §Context), so the instructions describe the pieces as behaviour and name Playwright only as
  the proven implementation.
- **Language-neutral where it can be:** the pieces are Playwright concepts; the PoC's code is TypeScript. Decide at
  Requirements how a non-Node E2E stack (Playwright for Python / .NET / Java) is served: the same instructions with
  that runner's equivalents, or "not covered".
- **Ready-made files only if Requirements asks for them** (`kickoff/templates/e2e-viewer/`, copied by `scaffold.sh`,
  never run by kickoff, which stays bash + awk). Instructions first; files are a later step if projects keep rebuilding
  the same code.

## Acceptance criteria (draft)

1. Following the instructions in a fresh fixture project with Playwright E2E in Docker gives a working viewer and
   run-and-watch on `127.0.0.1` ports derived from the app's port (app × 10 + 1 / + 2, ruled in PLUG-087), with its own
   tests passing in Docker — proved once, by a
   Claude session that had only the instructions.
2. The instructions' scenarios cover: a run killed half-way leaves every finished test's result; a passing
   non-whitelisted test keeps no trace; a whitelisted one does.
3. The charter (PLUG-087's yes) and the gap row point at the instructions; a project that said no gets nothing.
4. kickoff's suite passes on the host and in the Alpine container; docs and versions synced.

## Requirements

Settled 2026-10-27 with the user. Supersedes §Proposed shape and the draft acceptance where they differ.

### The user's rulings
- **Other stacks:** a proven path for Playwright on Node; for other stacks the concept, and a plain "no proven path
  yet", so Claude asks the user before inventing one.
- **Instructions only**, no ready-made files.
- **Proof by review, not a run** (no image pull, no npm install). The user's context, verbatim: *"the kickoff asks and
  recommend some tools. the project's responsibility to implement the according and necessary tooling and config"*.

Read as: the guide is **what to have, not how to code it**. kickoff asks (F13), recommends a tool, and hands the
project a spec. The project builds the tooling and the config and proves it with its own tests.

### In scope
- **G1** · `kickoff/skills/kickoff/references/e2e-viewer.md`, read on demand. Sections:
  1. **What it is:** the user's need, verbatim (from PLUG-087), and the three views (last results, replay of a kept
     trace, run-and-watch). It's optional and local only.
  2. **Behaviour the project must have:** one stored result per test, overwritten by its next run and written as
     each test ends; a trace kept only for a failed or flaky test, or for one on the machine-local whitelist; no
     video; no history; the command `e2e:view` (or `e2e-view`), and the ports from `ports.sh viewer <project>`.
  3. **Security requirements, non-negotiable:** the Host allow-list on every route; the Origin check on every write and
     every websocket upgrade; run-and-watch only behind a proxy that applies them; ports published on `127.0.0.1` only;
     a port check before publishing.
  4. **Acceptance scenarios** the project turns into its own tests (the store, the whitelist, a killed run, replay, the
     security cases S1–S5, the port refusal, a spec that doesn't compile).
  5. **Recommended tool:** Playwright Test on Node, with what the proven implementation used (a reporter, the
     whitelist as a second project, the served trace viewer, UI mode behind the proxy).
  6. **Pitfalls** from the verdicts, each with its symptom.
  7. **Other stacks:** the concept maps; there is no proven path yet, so ask the user.
- **G2** · Pointers: SKILL.md step 6 (the first task) and step 7 (the F13 gap's "do it now") send Claude to the guide,
  and the questionnaire's §How F is asked bullet names it.
- **G3** · No project, tool or person named beyond Playwright; nothing that identifies the source PoC (public repo).

### Out of scope
- Code, templates, a scaffold step. Running the viewer anywhere.

### Acceptance (replaces the draft)
1. The guide covers G1's seven sections, and every §Safe-to-generalise verdict appears in it as a requirement or a
   pitfall.
2. A fresh review agent, given only the guide (not this task), finds no requirement missing against the verdicts and
   nothing that names the source project. Its findings are fixed or answered.
3. SKILL.md and the questionnaire point at the guide; the kickoff suite stays green on the host and in `bash:5`.
4. Release with PLUG-087: kickoff 0.9.0, plugin.json, marketplace.json, root README in sync; the push only on the
   user's OK.

## Context

Collected 2026-10-27 (most of kickoff's context is already in PLUG-087 §Context and §Assessment; not repeated).

- **Where it goes:** `kickoff/skills/kickoff/references/` holds only `questionnaire.md` today. A second reference,
  `e2e-viewer.md`, is read on demand like the command detail (PLUG-010 made SKILL.md a router), so it costs nothing
  until a project says Yes.
- **Who reads it:** Claude, inside the user's project, at the "E2E viewer" first task (scaffold.sh `next:` line) or at
  the F13 gap's "do it now" (SKILL.md step 7). So it is written as a build guide for Claude: pieces, order, acceptance
  scenarios, pitfalls. It is not user documentation.
- **What PLUG-087 already fixed:** the command name `e2e:view` / `e2e-view`, the ports from `ports.sh viewer <A1>`
  (app × 10 + 1 / + 2), and the wording rule (kickoff names no tool; the guide may name Playwright as the proven
  implementation, since it is reference material, not a question or option).
- **Source of truth for the pieces:** §What the PoC settled and §Safe-to-generalise verdicts above. The PoC's own
  doc is in another, private project and is not linked from this public repo.
- **Stack limits, worth knowing:** UI mode and the `Reporter` API belong to Playwright Test, the Node runner.
  Playwright for Python / .NET / Java have neither in the same form, so the proven path is Node-only.
- **Release:** PLUG-087 is committed locally (07f5b27) and waits for this task; one 0.9.0 bump for both.
- **Collisions:** none. Only this session touches kickoff; the source PoC's hardening is in another repo.

## Current State

2026-10-27: proposed. All nine hardening verdicts are recorded above; nothing blocks it now. Next: the user approves it,
then Context → Requirements → … → the instructions file, then the joint 0.9.0 release with PLUG-087.

2026-10-27 (later): implementation done. `references/e2e-viewer.md` written and linked from SKILL.md (references,
steps 6 and 7) and questionnaire.md's F13 bullet. Acceptance 2, a fresh agent given only the guide and the verdicts,
found: the proxy's half-open socket teardown missing; the uncompilable-spec `--list` weakened; four unclear points
(upgrade judged before the read rule, store rules only in Playwright sections, the grep/grepInvert split, where the
proxy listens in the container); no leaks. All fixed, plus scenarios A11–A13 and S6. Release prep done with PLUG-087:
descriptions and keywords, a README line; the version stays 0.8.1 by the user's call until the stream ends (then 0.9.0). 298 tests green
on the host and in `bash:5`. Uncommitted, waiting for the user's OK; push needs a separate OK. Status stays in-progress
until the release; then completed. Open: the source PoC's shapes for the canvas-key test and the stale-bundle check
may refine A13 and the stale-bundle pitfall row; an append, not a blocker.
They arrived and are folded in: A13 keeps a user's choice, A14 pins the key against the installed bundle, A15 and the
pitfall row make the stale-bundle check warn-only, naming the file and the restart command.
