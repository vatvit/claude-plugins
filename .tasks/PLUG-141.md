---
title: "docs-manager: catalogue Claude Artifacts as remote cards"
status: completed
type: feature
priority: medium
tags: ["docs-manager-plugin"]
created: 2026-11-16 12:45
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | ## Context |
| 20 | Requirements | done | ## Requirements (approved by the user 2026-11-16) |
| 30 | Assessment | done | most remote-card code was already provider-generic; Drive-only: remote-diff, time shape, messages |
| 40 | POC | skipped | no Artifact tool in this session; listing shape left to the procedure (any 4-field row) |
| 50 | Domain | skipped | n/a |
| 60 | Architecture | done | ## Architecture |
| 70 | Tests | done | AR1–AR5, RF11b changed; red before, mutation-checked |
| 80 | Subtasks | skipped | one change |
| 90 | Implementation | done | ## Implementation |
| 100 | Tech Debt | done | ## Tech Debt |
| 110 | Reflection | done | plugin + root CLAUDE.md, README, SKILL triggers |

## Description

Team members publish Claude Artifacts (claude.ai/artifact/… pages: prototypes, dashboards, write-ups)
that become project reference material. Today they are shared as bare links: nothing records that an
artifact exists, what it holds or when to open it, and every session re-reads it from scratch.

docs-manager already catalogues Google Drive files as **remote cards** (`<name>.gdrive.md`, PLUG-113):
the file stays remote, the card says what it holds and where to look, `remote-modified` makes a change
detectable. Extend the same model to Claude Artifacts, reusing that machinery rather than cloning it
(one remote-card implementation, the provider as data).

Facts to design around (observed with the Artifact tool):
- Claude reads an artifact with the Artifact tool's `read` action. An artifact owned by someone else
  comes back as an isolated summary plus the raw HTML saved to a local file; an owned one as raw HTML.
- Some pages are bundled and unpack in the browser: the summary then shows only a loader
  ("Unpacking…"), so the card must be written from the unpacked HTML, not the summary.
- `list` (scope `shared` / `all`) returns title, URL and last-updated time — the analogue of Drive's
  `modifiedTime`. Artifacts shared from another organisation may be missing from the listing.
- A share link can carry an `sk=` key: it is an access secret and must not be committed by default.
- Artifacts have comment threads (ArtifactComments tool) — possibly worth a pointer in the card.

## Acceptance criteria

- A card format `<name>.artifact.md` (or a provider field on the existing remote card), with
  `remote-url`, owner role, `remote-modified` written only by a stamp command; listed by `index`,
  validated by `check` (incomplete / changed / gone), found by `external remote`.
- A documented procedure in `how-to-external-docs.md`: attach an artifact from a link, read it
  (including bundled pages), write the card, stamp; refresh: list, diff by URL/id, re-card the changed.
- The `sk=` key: decided and documented (stored only in local-only folders, or stripped and the
  reader asked for access) — never committed silently.
- The Drive and artifact remote cards share one implementation; no duplicated diff/stamp logic.
- Tests for the format, the stamp, `check` states and the diff, failing before the change.

## Context

**Epic:** none, but this extends epic `docs-gdrive` (PLUG-110; PLUG-112 remote cards, 113 folder
attach + refresh, 114 rejected binary copies, 115 local copies, 116). Read their Reflections before
architecture.

**Prior decisions (do not re-litigate):**
- **The name is the classifier** (plugin CLAUDE.md, *Remote cards*): `is_remote_card` matches
  `*.<provider>.md` for `REMOTE_PROVIDERS`, and no script reads frontmatter to decide what a file is.
  So the acceptance criterion's "or a provider field on the existing remote card" is ruled out:
  `<name>.artifact.md` it is.
- No config file (`.docs-manager.json` rejected twice); `.source.md` is per-folder data.
- Scripts are offline: only Claude talks to the provider; listings arrive as a temp file.
- One writer per stamp (`remote-stamp` → `remote-modified`), diff-guarded, shape-checked.
- Ids and times compare as strings; a time is only equal or not (`…11Z` vs `…11.986Z`).
- Never delete a gone card: `remote-gone` marks it and `check` fails until the user decides.
- No bytes through an MCP (PLUG-114): relevant if anyone proposes saving an artifact's HTML as a copy.

**What reuse gets for free** by adding `artifact` to `REMOTE_PROVIDERS` (`scripts/external.sh:40`):
`is_remote_card`, `is_remote_copy`, `list_remote_cards`, index `☁` listing, `external_status`
(`remote` / `incomplete` / `gone`), `check`, `remote-stamp`, `remote-gone`, `copy-stamp`, `external
remote`. The provider loop is already the single place.

**What is Drive-shaped and needs design:**
- `remote-diff <dir> <listing>` requires `.source.md` with a Drive folder `remote-id`, filters by
  path scope and skips the Drive folder mimeType. Artifacts have no folder: an artifact `list` returns
  every artifact the user can see, so a diff against it must not report all of them `new`, and an
  artifact missing from the listing (another organisation's) must not read as `gone` without care.
- `valid_rfc3339` checks Drive's time shape; the artifact listing's time format is unverified.
- `remote-url` with `sk=`: a secret, so where it may be written is a requirements decision.
- The Artifact tool is **not available in this session's tool list**; the facts in the Description
  were observed elsewhere. Anything that depends on the listing's exact shape (time format, id field)
  needs a POC in a session that has the tool, or the user's sample.

**Docs:** `skills/docs-manager/references/how-to-external-docs.md` § *Remote documents (Google Drive)*
(lines ~235–395) is the procedure to generalise. Plugin `CLAUDE.md` § *Remote cards* records the
invariants. Trigger phrases: docs-manager owns *remote card*; "artifact" collides with nothing in the
root CLAUDE.md vocabulary list (diagram "render artifact" is internal wording, not a trigger).

**Code to touch:** `scripts/external.sh` (providers, diff, stamp shape), `scripts/test/external.test.sh`
(RC*/RF* cases, the `rcard` helper is gdrive-only), the how-to, SKILL.md triggers, plugin.json/marketplace.

**Parallel-session collisions:** none outside this session. PLUG-140 (this session) changes
`lib.sh` `fm_parse`; do it first.

## Decisions

User, 2026-11-16:
- **Diff scope: carded only.** A refresh diff reports `changed` and `gone` for artifacts that already
  have a card, never `new`: an artifact is attached by its link, one at a time. Because an artifact from
  another organisation can be absent from the listing, absence is confirmed by reading the artifact
  before `remote-gone` is set.
- **`sk=`: stripped, local keeps it.** `remote-url` is always stored without `sk=`. In a `publish: local`
  (git-ignored) folder the card may also carry the full link (`remote-key-url:`). `check` fails on any
  `sk=` in a card outside a local-only folder.
- **Access route — open.** The user asked what "the Artifact tool" is. This session has no `Artifact` /
  `ArtifactComments` tool; it has the Claude Docs MCP, which reads only Docs-type artifacts by link and
  cannot list (its guide: "no lookup by name here"). So the procedure must name the capability (read an
  artifact by link, list the user's artifacts), not a tool, as the Drive procedure does.
- **An artifact is never where a decision lives.** User: an artifact is an intermediate document, a
  team collaboration item or an output, not documentation and not a decision. A decision made while
  working on an artifact is extracted from it into the doc it belongs to, and the card treats the
  artifact as illustration or evidence.

## Requirements

User, 2026-11-16: *"the task is to manage the Artifacts related to the project as other docs; docs-manager
should provide the instructions/scripts to do it in the same generic/common way."* So an artifact is one
more **remote provider**, and the provider-specific parts of the Drive design become data, not code.

- R1 `artifact` joins `REMOTE_PROVIDERS`; a card is `<name>.artifact.md` and gets everything a
  `.gdrive.md` card gets (index `☁`, `status`, `check`, `remote-stamp`, `remote-gone`, `external remote`,
  local copies) with no provider branch in that code.
- R2 **One diff, two modes, chosen by the attachment, not the provider.** `remote-diff` takes the same
  listing (`id<TAB>path<TAB>type<TAB>modified`). When `.source.md` names a container (`remote-id`, a Drive
  folder) it reports `new` / `changed` / `gone` in scope, as today. When it names none, the cards were
  attached one by one: it reports only `changed` and `gone` for carded ids, never `new`. Artifacts are
  always the second mode; a single Drive file attachment gains a refresh this way too.
- R3 A `gone` in the carded-only mode is a candidate: the procedure confirms by reading the artifact by
  its link before `remote-gone` (a listing can miss another organisation's artifacts).
- R4 Provider data, one table in `external.sh`: the container type to skip in a listing (Drive folder
  mimeType), the access-key query parameters (`sk` for artifacts). No `if provider = …` elsewhere.
- R5 `remote-url` never carries an access key; `check` fails (`REMOTE KEY`) on a card whose `remote-url`
  or any field has one, unless its `.source.md` says `publish: local`. There a card may hold
  `remote-key-url:`.
- R6 Times: `remote-stamp` accepts RFC 3339 with `Z` or a `±hh:mm` offset (the artifact listing's shape
  is not yet seen; equality stays string equality, the shape check only stops typos).
- R7 The how-to's *Remote documents* section is written once for every provider (attach, read, card,
  stamp, refresh, local copy), with a short per-provider table: how Claude reads one (Drive MCP; the
  Artifact tool, or the Claude Docs MCP for a Doc artifact), what the listing is, what a bundled page
  needs (read the unpacked HTML, not the loader summary), where comments are.
- R8 SKILL.md trigger phrases: *Claude artifact*, *catalogue an artifact*, *refresh the artifacts*.
- R9 The how-to states the decision above: when cataloguing or refreshing an artifact, Claude looks for
  decisions or facts the project relies on and proposes writing each into its doc under `docs/`
  (applied on approval); the card cites the artifact, never stands in for the doc.

Not in scope: saving an artifact's HTML as a local copy of bytes (PLUG-114 rule); creating or publishing
artifacts.

## Architecture

- `artifact` joins `REMOTE_PROVIDERS`; everything the name classifier drives (index ☁, status, check,
  stamps, `external remote`, local copies) works unchanged.
- `provider_data <provider> <field>` is the one table of differences: `container` (Drive folder
  mimeType, skipped in listings) and `keys` (`sk` for artifacts). `remote_provider <card>` reads the
  provider from the name; `is_remote_card` now uses it, so the provider loop exists once.
- `remote-diff`: provider from `.source.md` `provider:` (default `gdrive`, so older `.source.md` files
  keep working); container mode iff `remote-id`; carded mode suppresses `new` and skips scope; only
  cards of that provider are compared.
- `has_access_key` greps the whole card for `[?&]<key>=`; `external_status` emits `keyed` before any
  other remote state unless the card's `.source.md` says `publish: local`; `check` → `REMOTE KEY`.
- `valid_rfc3339` also accepts a `±hh:mm` offset; equality stays string equality.

## Implementation

- `docs-manager/scripts/external.sh`: the above; messages say "provider" instead of "Drive".
- `docs-manager/scripts/test/external.test.sh`: AR1–AR5 (21 checks). Before the change 10 of them
  failed, and so did RF11b once it was rewritten for the new rule. AR3c, AR4a, AR5f and AR5g were then
  proven by mutation: dropping the provider filter, forcing container mode, ignoring `publish: local`,
  giving every provider `sk` each turned the matching test red. AR4a and AR5g were sharpened after a
  mutation showed they could pass or fail for the wrong reason.
- Found on the way: `docs.test.sh` RC9a used `grep --include`, which busybox lacks, so the check
  passed vacuously in the container. Fixed with `find -exec grep`.
- Docs: how-to section renamed *Remote documents (Google Drive, Claude Artifacts)* with a provider
  table and a *Claude Artifacts* procedure (find the tool, bundled pages, key, carded refresh, confirm
  gone by reading); SKILL.md triggers; plugin CLAUDE.md *Remote cards*; root CLAUDE.md vocabulary;
  docs-manager README and root README bullets; plugin.json keyword `claude-artifacts`.
- docs-manager 1.13.0 (carries PLUG-140's 1.12.2 fix). `check-descriptions.sh` ok; no new broken links
  against HEAD. Suites: host, `bash:5` with git, `bash:5` without HOME, and a standalone copy all green:
  diagram 100, docs 56, external 201, onboard 34.

## Tech Debt

- The artifact listing's real shape (time format, id) is unverified: no Artifact tool in this session
  (`enableArtifact: false` in the user's settings). `remote-stamp` accepts RFC 3339 with an offset; if
  the tool reports another shape, `valid_rfc3339` is the one place to widen. Verify on first real use;
  no task filed yet, since it may need no change at all.

## Current State

Implemented and verified; not committed (PLUG-140 and PLUG-141 share docs-manager 1.13.0 and should be
committed together). Next: commit on the user's request; first real artifact attach verifies the
listing shape (Tech Debt).

Committed 2026-11-16 with the version left at 1.12.1: the user deferred the release (version bump) so
several features ship together; the planned 1.13.0 bump happens at release.
