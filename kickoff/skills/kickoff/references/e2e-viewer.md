---
title: E2E viewer
description: What a project that answered F13 = Yes must have — every E2E test's last result in the browser, a step-by-step replay of a kept trace, run-and-watch any one test, local only — with its security rules, the acceptance scenarios for its own tests, the recommended tool and the pitfalls already hit
status: proven once, on Playwright Test 1.64.1 (Node); agreed 2026-10-27
---

# E2E viewer

Read this only for the E2E viewer's task (F13 = Yes) or its gap (`gaps.sh` row `F13`). **kickoff asks and recommends;
the project builds the tooling and its config**, proves it with its own tests, and owns it from then on. This file
says what the viewer must do and what it must never do. How to code it is the project's call.

## 1. What it is

The user's need, in their words:

> i want to see the list of test cases and their run results (at least last)
> i want to be able to play any of them in my browser and see the result
> not "i am repeat the steps, but the programm repeat, and i an observer"
> i should be able to see details. maybe pause OR at least do not close after finish.

Three views, all in the user's browser:

| View | What the user sees |
|---|---|
| **The list** | Every E2E test with its **last** result (`passed` / `failed` / `flaky` / `skipped` / *not run*) and when it ran |
| **Replay** | A kept **trace** opened step by step: each step with a picture of the page, stepped back and forward at the user's pace. Nothing is re-run |
| **Run and watch** | Any one test run anew from the browser, its steps shown while it runs; the view stays on the last step when it ends |

It is **optional**: a project has it because the user said yes. It is **local only**: nothing on the network reaches it.

## 2. Behaviour the project must have

- **One stored result per test**, overwritten by its next run, by any run: a dev run, the gate, a scheduled run, a
  run-and-watch run. There is no history.
- **Written as each test ends**, on its final attempt, so a run killed half-way still leaves every finished test's result.
- **A trace is kept only for a test that failed or was flaky** (the failing attempt's trace), **or one on the
  whitelist**. A passing test that is not whitelisted keeps none, and a trace it had is deleted. One trace per test,
  overwritten by its next run. **No video.**
- **The whitelist** is a toggle beside each test in the list. It is local to the machine and never committed. It takes
  effect from the next run's start, and the page says so.
- **One store.** Every run writes to the same place. Several stores (one per environment) leak traces: see §6.
- **The store write never breaks a run.** Each result is written atomically (a temp file named from the pid **plus
  random bytes**, then a rename); a trace is hard-linked, copied when the link crosses filesystems. A failure to
  store prints which test was not stored and why, and never changes the run's exit code.
- **A test is its file plus its titles**, not the runner's project. A whitelisted run and a normal run of one test
  give one stored result.
- **The list comes from the runner's own listing**, so a never-run test shows as *not run*. If the listing fails (one
  file doesn't compile), the page shows the runner's error, never an empty list that reads as "no tests".
- **The gate is unchanged.** With an empty whitelist, the runner's config is exactly what it was before the viewer.
- **Commands:** `e2e:view` starts the list and replay, `e2e:ui` starts run-and-watch, and each has a `stop`. Where a `:`
  cannot be used (a Makefile target), use `e2e-view` / `e2e-ui`. kickoff's gap check looks for these names.
- **Ports:** `bash <PLUGIN_ROOT>/scripts/ports.sh viewer <project name>` (`<PLUGIN_ROOT>` is kickoff's directory, the
  project name is the questionnaire's A1) registers and prints them: the app's port × 10 + 1 for the viewer, × 10 + 2
  for run-and-watch. If it refuses, its message names the cause and the manual way.

## 3. Security — non-negotiable

Binding to `127.0.0.1` is **not enough**. A DNS-rebinding page reaches a local server under a foreign Host, and any
site open in the same browser can send a cross-site POST (`text/plain` needs no preflight). Both were real holes in
the proven implementation, and both are closed by the rules below.

- **One check, run first on every request,** as a pure function, refusing with 403 and its reason:
  `requestRefusal({ method, host, origin, upgrade }, port) → reason | null`
  - **Host:** exactly `127.0.0.1:<port>` or `localhost:<port>`. Any other Host, or none, is refused on every method
    and every route.
  - **Websocket upgrades** are judged next, by the Origin rule below, **never by the read rule**: an upgrade is a GET.
  - **Reads** (GET, HEAD, not an upgrade) pass once the Host passes.
  - **Writes** (any other method) **and upgrades** need `Origin === "http://" + <the request's allowed Host>`.
    A missing Origin is refused: browsers send one on every POST.
  - Not instead: a CSRF token (more moving parts, and the Host check is still needed) or a content-type rule (the
    Origin check covers it).
- **Run-and-watch sits behind a proxy.** The runner's own UI server checks neither Host nor Origin (Playwright 1.64.1:
  a foreign Host gets the redirect carrying its websocket token, and an upgrade with a foreign Origin gets 101). So:
  - the runner listens on `127.0.0.1:<inner>` inside the container, unpublished;
  - a small proxy listens on the published port and applies `requestRefusal` to every HTTP request and every upgrade.
    Inside the container it listens on all interfaces so Docker can reach it; only the host side of the publish is
    pinned to `127.0.0.1`. A refused upgrade gets a raw `HTTP/1.1 403` on the socket; an allowed one gets a raw
    connection to the inner port, with the request head replayed and the two sockets piped both ways;
  - **no half-open sockets**: when the page's socket ends, destroy the upstream one; when either side closes or errors,
    destroy the other. Otherwise the proxy's server never finishes closing and `stop` hangs;
  - if the runner isn't up yet, the proxy answers 502.
- **Publish on `127.0.0.1` only** (`--publish 127.0.0.1:<p>:<p>`), never `0.0.0.0`.
- **Check the port before publishing.** Docker publishes over a host process already listening on the port, with no
  error, and the URL then reaches that process. Check "already running" (the project's own container holds the port)
  first, then refuse if anything answers on the port, naming it.
- **Routes look a key up, never join it into a path.** Traversal (`..%2f`, `%2e%2e`, an encoded slash, `%00`) gives
  404; a malformed escape gives 400.

## 4. Acceptance scenarios — the project's own tests

Turn these into the project's tests (unit where the logic is pure, the real server on a free port for HTTP), and see
each one fail once by planting its defect back.

| # | Given / when | Then |
|---|---|---|
| A1 | a run of some tests | those show the new result and time; every other test keeps its earlier one |
| A2 | a run killed after some tests finished | those show the new result; the rest keep their earlier one |
| A3 | a test fails, then later passes (not whitelisted) | *failed* with a trace, then *passed* with none |
| A4 | a test fails, then passes on a retry | *flaky*, with the failing attempt's trace |
| A5 | a test is whitelisted, runs and passes | it keeps a trace; unticked, its next pass drops it |
| A6 | a kept trace is opened | each step with its picture; back, forward, pause; nothing runs |
| A7 | one test is started from run-and-watch | its steps show while it runs; the view stays at the end; its stored result updates |
| A8 | the whitelist is empty | the runner's config equals the gate's |
| A9 | one test file doesn't compile | the list shows the runner's error, not "no tests" |
| A10 | the port is taken by another process | the start refuses, naming the port |
| A11 | the viewer is started while it already runs | it says so and leaves it running, not "port taken" |
| A12 | the store cannot be written during a passing run | each unstored test is named; the run still exits 0 |
| A13 | the viewer page is opened on a fresh origin / after the user turned the canvas setting off | it is on / it stays off |
| A14 | the installed runner's trace-viewer bundle is read | the canvas key is still that checkbox's setting, off by default, read as JSON from the origin's localStorage (pins the internal key, §5) |
| A15 | run-and-watch is asked for again after a build input changed / after nothing changed | its URL plus a warning naming the first changed file and the restart command / its URL only; it never restarts on its own |
| S1 | the viewer is requested under its own hosts / under `evil.example:<p>`, `evil.example`, `127.0.0.1:<other port>` | 200 on every read route / 403 with no trace bytes |
| S2 | a write from another site, from the same host on another port, or with no Origin | 403, and the whitelist file is unchanged byte for byte |
| S3 | the page's own write | it lands |
| S4 | run-and-watch under its own host / a rebinding host | passed through / 403, and its token appears nowhere |
| S5 | an upgrade from its own origin / another site, no Origin, or a rebinding host with a matching Origin | 101 and the traffic round-trips / 403 |
| S6 | a page's upgraded socket ends, then run-and-watch is stopped | the stop completes |

For S1–S5, send crafted `Host` / `Origin` headers with a raw HTTP client: `fetch` cannot set Host. Test the proxy
against a stand-in inner server that behaves like the probed runner (a redirect carrying a token, 101 on any upgrade).

## 5. Recommended tool — Playwright Test on Node (the proven path)

Name it in F13's Yes option as `→ Playwright Test`. How the proven implementation mapped each piece:

| Piece | How |
|---|---|
| Result store | A custom **reporter** in the config's reporter list, writing one file per test on its final attempt, atomically (temp file and rename); the trace **hard-linked** from the run's artifacts, a copy only on `EXDEV` |
| Whitelist | Read by the config at run start and turned into a **second project** with `trace: 'on'` whose `grep` matches the whitelisted tests; the default project keeps `retain-on-failure` and gets a `grepInvert` matching the same tests, so each test runs in exactly one. Playwright's grep target is `<project> <file relative to testDir> <describe…> <title>`, followed by ` @tag`s: escape the titles into the regex, and allow for the leading project name. With an empty whitelist neither the second project nor the `grepInvert` exists (an empty `grep` matches everything) |
| The list | `playwright test --list --reporter=json`: the suites, or the error in `errors[0]` (see §6: exit 1 still prints the JSON) |
| Replay | Playwright's own **trace viewer**, served from `playwright-core/lib/vite/traceViewer/` on the **same origin** as the traces; its static files go through the same `requestRefusal` as everything else |
| The app in each step | A canvas app (WebGL) shows in a step's pane only with the trace viewer's "Display canvas content" on (1.50+, off by default, and a checkerboard while off; below 1.50 the canvas is black whatever the setting). The setting lives in the serving origin's localStorage, key `shouldPopulateCanvasFromScreenshot` on 1.64.1, so the viewer page sets it to `'true'` **only while it is unset**, keeping a choice the user made. The key is internal: pin it with a test that reads the installed bundle and asserts, by regex, that the key belongs to that checkbox, defaults off and is read as JSON (report a mismatch with a message, never by printing the minified bundle) |
| Run and watch | **UI mode** behind the proxy (§3): `playwright test --ui --ui-host 127.0.0.1 --ui-port <inner> & exec <proxy>` in one long-lived container |
| Long-lived containers | `docker compose run -d --rm --name … --publish 127.0.0.1:<p>:<p> <service> …`, with no compose edit |

Trace size, measured: ~45 MB median, 66 MB max. Tracing every test and deleting the passes costs that much per test
per run, which is why only failures and the whitelist are traced.

## 6. Pitfalls — already hit once

| Pitfall | Symptom | Rule |
|---|---|---|
| A reporter that throws | on 1.64.1 a reporter error ends a **passing** run with exit 1 | never throw: print `✗ <store>: <test> not stored — <why>` and go on |
| Temp names from the pid alone | two containers on one store share a pid and overwrite each other | pid **plus random bytes** |
| Hard link across filesystems | `EXDEV`, and the trace is lost | fall back to a copy |
| Several stores | a trace superseded by a newer result in another store is never deleted (44 of 53, 2 GB) | one store |
| Docker over a busy port | publish succeeds, and the URL reaches the other process | check the port first (§3) |
| `--reporter=…` on the command line | it replaces the config's reporters, so nothing is stored | name the store reporter too |
| UI mode runs every reporter | its run overwrites the gate's reports | make report paths movable (an env var) and point UI mode elsewhere |
| A stale bundle in run-and-watch | the bundle it serves is the one built when it opened, so a code change looks like a bug | build at start; when it is asked for again, compare each build input's mtime with the built entry file (a missing one is stale; leave out what the runner reads live, such as specs, and files another build rewrites) and warn, naming the first changed file and the restart command. Restarting stays the user's call |
| "Display canvas content" off (1.50+) | the canvas is a checkerboard; the app shows only in the thumbnails | default it on (§5) |
| One spec that doesn't compile | `--list` exits 1 with valid JSON: `suites` is `[]` for **every** file, the error is in `errors[0]` | read the JSON whatever the exit code; show `errors[0]`, never "no tests" |
| Half-open sockets in the proxy | `stop` hangs: the proxy's server never finishes closing | destroy the other side on end, close and error (§3) |
| No `test.step()` | a trace is a flat list of low-level calls | name the steps after the scenario |
| Image and package drift | the browsers don't match and nothing starts | pin the runner's image and its package to one version |
| A paused or tick-driven app clock | a watched run jumps between steps and never plays smoothly | expected; say so before the user judges it |

## 7. Other stacks

The pieces are concepts: a per-test result written as each test ends, a trace kept by rule, a whitelist, a listing,
a replay viewer, run-and-watch behind a checking proxy. The proven path uses two things only Playwright Test on Node
has, the `Reporter` API and UI mode. Playwright for Python, .NET or Java, and other E2E runners, have **no proven path
yet**: tell the user which pieces their runner covers and which it doesn't, and ask before inventing one. §2, §3 and §4
apply to any stack; §5 and §6 are Playwright's, though most pitfalls have a twin elsewhere.
