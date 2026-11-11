---
title: "kickoff — switching the port-list scope moves this project's ports, so its ports stay the same"
status: completed
type: bugfix
priority: medium
tags: ["kickoff-plugin"]
created: 2026-11-11 19:37
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | PLUG-121 Open; entries named <A1>, <A1>/<service> (SKILL.md step 7) |
| 20 | Requirements | done | acceptance criteria in task |
| 30 | Assessment | done | `set_scope` only wrote .kickoff.json; registry helpers reusable |
| 40 | POC | skipped | nothing risky |
| 50 | Domain Lens | skipped | n/a |
| 60 | Architecture | done | see Result: one merge, checked before written; clash refuses |
| 70 | Tests | done | home.test.sh 9a–9n (14), red first (9 failed) |
| 80 | Subtasks | skipped | small |
| 90 | Implementation | done | ports.sh `do_merge`, `merge_ports`, `set_scope` |
| 100 | Tech Debt | done | none filed; see Result for the awk trap |
| 110 | Reflection | done | README Dev ports, kickoff CLAUDE.md HOME bullet, ports.sh header |

## Description

Accepted gap from PLUG-121 (epic cowork, PLUG-117). `ports.sh scope home|project` only records the choice in
`.kickoff.json`. Entries already registered stay in the old list, so after a switch `allocate <A1>` reads the other
list. It can then hand the project a different port, or hand its port to another project.

Entries belong to the project by name: `<A1>` and `<A1>/<service>` (SKILL.md, step 7). The project registry
(`.git/kickoff/ports.json` or `.kickoff/ports.json`) only ever holds this project's entries.

## Acceptance criteria

- **project → home:** every entry of the project registry is added to `~/.claude/kickoff/ports.json`. All of them are
  checked before any is written: a name HOME already gives another port, or a port HOME gives another name, refuses
  the switch. The refusal lists each clash, writes nothing, and leaves the scope unchanged (the rule `viewer` follows,
  PLUG-087). When the switch succeeds, the project registry is removed, so the project keeps one list.
- **home → project:** the HOME entries named `<A1>` or `<A1>/…` are copied into the project registry. They stay in
  HOME too, so other projects on this machine still see those ports as taken. Without a settled A1, nothing is copied,
  and stderr says so.
- Re-running the same `scope` is a no-op. `allocate <A1>` returns the same port before and after a switch.
- Tests in `home.test.sh`, seen red first. Host and `bash:5`.

## Result (2026-11-11)

`ports.sh scope home|project` now takes the project's ports along.
- **Into HOME:** every entry of the project list is merged into `~/.claude/kickoff/ports.json`, and then the project
  list is removed.
- **Out of HOME:** HOME's entries named `<A1>` and `<A1>/…` are copied into the project list and stay in HOME. Without
  a settled A1, nothing is copied, and stderr says so.
- **Clashes:** every entry is checked before any is written. A clash (same name with another port, or same port with
  another name) exits 3, lists the clashes, and leaves both lists and the choice as they were. A repeated switch writes nothing.
- **Override:** with `KICKOFF_PORTS_FILE` set there is one list, so nothing moves. This also keeps the tests away from a real HOME.

Tests: `kickoff/scripts/test/home.test.sh` 9a–9n. 9d and 9l are built so that an unmoved port shows up as a different
number, not as 3030 by coincidence. All 6 suites are green on the host, in `bash:5` (busybox awk) and in the git image (4× repeated).
Red: 9 failed before the code. Dropping the A1 filter fails 9j.

Caught while writing it: `awk 'NR == FNR { … }' list entries` treats the entries as the list when the list is empty,
so a merge into an empty HOME would have added nothing. Fixed by comparing `FILENAME` with a named temp file, and noted in
kickoff/CLAUDE.md. It is a general awk trap and could go into root CLAUDE.md *awk portability traps*.
