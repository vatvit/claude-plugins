---
title: "kickoff — instructions for reaching an E2E test viewer: the per-test result store, the trace whitelist, the viewer page and run-and-watch"
status: approved
type: feature
priority: medium
related: [PLUG-087]
tags: ["kickoff", "quality", "e2e"]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | — | |
| 20 | Requirements | — | |
| 30 | Assessment | — | |
| 40 | POC | — | |
| 50 | Domain | — | |
| 60 | Architecture | — | |
| 70 | Tests | — | |
| 80 | Subtasks | — | |
| 90 | Implementation | — | |
| 100 | Tech Debt | — | |
| 110 | Reflection | — | |

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

## Context

(collected at step 10)

- `kickoff/scripts/scaffold.sh`, `kickoff/templates/` — how kickoff writes files today.
- `kickoff/scripts/ports.sh` — the port registry.
- [PLUG-087](PLUG-087.md) — the check and the gap rule this scaffold closes.

## Current State

2026-10-27: proposed. All nine hardening verdicts are recorded above; nothing blocks it now. Next: the user approves it,
then Context → Requirements → … → the instructions file, then the joint 0.9.0 release with PLUG-087.
