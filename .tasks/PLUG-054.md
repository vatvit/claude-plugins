---
title: delay — several Claude accounts on one Mac: a version-aware "outdated" check, and the install refuses a downgrade
status: proposed
type: bug
priority: medium
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

The user runs several Claude accounts on one Mac (`~/.claude`, `~/.claude-z3k`, …). Each account
installs plugins into its own `$CLAUDE_CONFIG_DIR/plugins/cache/…`, so each has its **own copy and
version** of delay. delay's data is machine-wide by design: one queue, one registry, one window,
one runner, and one root-owned installed copy in `/Library/Application Support/claude-delay/bin/`.

`installed_current` (`delay/scripts/lib.sh`) byte-compares **the calling account's** plugin copy
with the installed copy. So when the two accounts hold different delay versions:

- the account that doesn't match reports `installed_current=no`, and every `add`/`list` prints
  "install.sh (update: the installed copy is outdated)", for ever;
- following that advice from the **older** account **downgrades** the installed copy. After
  2.0.0 that is worse than noise: a 1.x dispatcher cannot read the 2.0 registry (`jobs/<pair_id>`,
  `script=`), so approved jobs stop running;
- then the newer account complains, and the user re-installs back and forth.

Found 2026-10-10, while answering "how do I install delay on another PC" (after PLUG-053).

## Proposal (to agree at Requirements)

- The install records the version it installed (from `plugin.json`) next to the installed copy.
- `delay.sh` compares versions, not bytes:
  - this account's copy **newer** → the ACTION block asks for the re-install (as today);
  - **older** → no sudo line; tell the user to update the plugin in *this* account
    (`/plugin update delay@vatvit-plugins`), and keep running jobs with the installed copy;
  - **same version** → current. Open: same version but different bytes (a dev checkout vs the
    marketplace copy). Byte-compare as a tie-break, or trust the version?
- `install.sh` refuses to install an older version over a newer one, naming both versions;
  an explicit flag (`--downgrade`) allows it.

## Acceptance criteria

- Two plugin copies, one older and one newer than the installed copy: the newer one's
  `status` says `installed_current=no` and asks for the install; the older one's does not, and
  says to update the plugin in that account.
- An install from an older copy is refused (exit 1, both versions named), and leaves the installed
  copy untouched; `--downgrade` installs it.
- An install from a same-or-newer copy works as today.
- README "Several Claude accounts" paragraph and SKILL.md updated; the version-mismatch caveat
  added on 2026-10-10 removed.
- Tests: the suite passes on the host and in `bash:5`; each new check was seen red.
