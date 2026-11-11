---
title: "crew — crew time with an unusable HOME: confirm transcript reads degrade, and pin it"
status: completed
type: bugfix
priority: low
tags: ["crew-plugin"]
created: 2026-11-11 19:37
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | time.sh `time_dirs`; home.test.sh checked only exit codes for `crew time` |
| 20 | Requirements | skipped | criteria in task |
| 30 | Assessment | done | reads only; `${HOME:+…}` guards unset; a file or missing HOME matches no dir |
| 40 | POC | skipped | nothing risky |
| 50 | Domain Lens | skipped | n/a |
| 60 | Architecture | skipped | no code change |
| 70 | Tests | done | home.test.sh: no shell error + plain sentence (3 modes); CLAUDE_CONFIG_DIR transcript read with HOME a file |
| 80 | Subtasks | skipped | small |
| 90 | Implementation | skipped | no code change needed |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | see Result; no doc change (crew CLAUDE.md already states the rule) |

## Description

Left open by PLUG-119 (epic cowork, PLUG-117). `time_dirs` in `crew/scripts/time.sh` reads transcripts from
`crew_config_dir` and, when HOME is set, from `$HOME/.claude*`. These are reads only. The root rule *Without HOME* says
a missing or unreadable per-account file means defaults, so the likely outcome is "no change". It still has to be
checked for a HOME that is set but useless: a regular file, a missing dir, or a throwaway home with no transcripts.

## Acceptance criteria

- With HOME a file, a missing dir, or an empty dir, `crew time` exits 0, prints no shell error, and reports the
  members it has (with no transcript time).
- Transcripts found through `CLAUDE_CONFIG_DIR` are still read when HOME is unusable.
- Whatever is not already covered by `home.test.sh` / `time.test.sh` gets a check, seen red if code changes.

## Result (2026-11-11)

No code change: `crew time` already degrades as the rule asks. The tests now pin it.
- One criterion was corrected: with no transcript, `crew time` prints "no transcript found for this crew's sessions", the same
  sentence it prints with HOME. It does not list members.
- New checks in `crew/scripts/test/home.test.sh`: no shell error and that sentence, for HOME unset, missing and a file; a transcript
  under `CLAUDE_CONFIG_DIR` is read while HOME is a plain file. The suite has 86 checks, green on the host and in `crew-test`.
- Red: dropping `crew_config_dir` from `time_dirs` fails the transcript check. A bare `"$HOME"` expansion fails "no shell
  error", though it still exits 0, so the old exit-code check had missed it.
