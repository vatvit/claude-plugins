# CLAUDE.md — kickoff plugin

Guidance for working on this plugin. What it does for the user is in [README.md](README.md).

## Layout

```
kickoff/
├── .claude-plugin/plugin.json
├── skills/kickoff/
│   ├── SKILL.md                       ← the interview loop Claude follows
│   └── references/questionnaire.md    ← THE questions: the one source for the skill and the scripts
├── scripts/
│   ├── lib.awk        ← the questionnaire model: parse, conditions, defaults, states
│   ├── lib.sh         ← locating files, the installed plugins, running a program over the model, diff-guarded writes
│   ├── plan.awk / plan.sh        ← what to ask now (--next), the review table (--review)
│   ├── answer.sh                 ← the only writer of .kickoff-answers
│   ├── charter.awk / charter.sh  ← docs/project/charter.md from the answers
│   ├── scaffold.sh               ← CLAUDE.md (claude.awk), quality doc (quality.awk), task config + workflow (workflow.awk)
│   ├── inspect.sh / infer.awk    ← existing project: proposed answers with evidence (writes nothing)
│   ├── gaps.sh / settled.awk     ← existing project: what the answers say is missing (writes nothing)
│   ├── get.awk                   ← settled answers for shell scripts
│   ├── computed.awk              ← answer.sh: is this value a computed default (*italics*)?
│   ├── defaults.sh               ← the user layer: per-account defaults (kickoff.json)
│   ├── json.awk                  ← json_q(), the one JSON string writer (defaults-write.awk, registry-insert.awk)
│   ├── ports.sh                  ← the machine-wide dev-port registry (~/.claude/kickoff/ports.json)
│   └── test/                     ← all.sh runs every *.test.sh; helpers.sh is shared by them
├── templates/                     ← the task workflows scaffold.sh seeds (profiles, minimal)
└── README.md
```

## The questionnaire is code too

The scripts parse `questionnaire.md`'s tables, so editing it changes behaviour. Its §Reading the
tables is the contract, and `lib.awk` is that contract's only implementation. Never copy question
text, options or conditions into a script or a test fixture. Tests assert behaviour through the
real file, so a broken edit fails them.

## Don't regress

- **Multibyte markers.** `★`, `≠`, `·` and `§` are several bytes in byte-oriented awks (busybox, mawk,
  BSD awk in the C locale) and one character in gawk. So strip them with patterns, never with
  `substr` offsets. Any internal marker you generate is ASCII (`S:<section>`). A slip shows as a
  half-character `�` in headings, which only the container target catches.
- **Evaluation order.** `a[++n] = "x" n` gives different `n` on BSD awk and busybox. Increment in its own
  statement. Found as `D0` in the decisions table on the host run only.
- **`pending` is not `skip`.** A condition on a question still to be asked waits. Evaluating it against
  an empty answer would ask it too early (`≠` holds for an empty string). So does a question whose
  `(★ if …)` default depends on one still to be asked (`default_waits`): asked on the same screen as A4,
  A6 recommended the wrong option (kickoff 1i–1l). In `and`, a false part wins over a pending one (4o).
- **`explicit` is not `ask`.** A question whose *Ask when* is `explicitly` (C5) is never settled by
  accepting defaults; its value column is a recommendation. The test helper `autofill` fails on it
  without an override, which is what pins it (kickoff 9c).
- **`n/a` counts as answered** (so `--next` moves on) but never reaches the charter. It is how a
  *judge* question is retired.
- **The charter refuses to overwrite** a differing file (exit 3). After kickoff it is edited by hand.
- **Two kinds of generated file.** Seeded files (`.task-config.json`, WORKFLOW.md) are written
  once and are the user's from then on. Regenerated files (charter, quality doc, CLAUDE.md) are rewritten
  only while unchanged, and refused once edited. Never let `scaffold.sh` overwrite a seeded file (3c).
  The layout of `docs/` is docs-manager's: kickoff writes only into `docs/project/`.
- **A client's repo carries nothing of the user.** For tasks outside the repo, CLAUDE.md says so in prose
  and never prints the tasks path, which contains the home directory (4h). The task registry entry is
  inserted into the existing file, keeping the other projects (4d, 4l).
- **The user layer is per account** (follows `CLAUDE_CONFIG_DIR`, 3b/3c); the port registry is per
  machine. Precedence: answer > user default > `(★ if …)` > ★.
- **inspect.sh proposes, never records.** It writes nothing (2l), skips answered questions (2m), and
  maps each hint to the questionnaire's option text via infer.awk, so no option wording lives in the
  shell script. It reads `.git` as files: no git binary, so it runs in a bare container.
- **One hint per question, the first.** inspect.sh hints the stronger evidence first and infer.awk keeps
  the first per id (existing 6l): serverless.yml before compose for I2, the dev script before a Makefile.
- **A confirmed proposal keeps its evidence** as `<ID>.from`, and the charter marks it *recovered* (7d–7g).
  A decision taken at kickoff is never marked.
- **gaps.sh reports, never fixes**, and a closed gap disappears (8h, 8i). Fixes depend on the stack, so
  Claude makes them; kickoff names no stack. A tool counts as set up only when a manifest, config,
  script or CI file names it; prose (a README) does not. The `docs/` gap exists only with docs-manager
  installed: `docs/` is docs-manager's (8j).
- **`set -e` and `$( … grep … )`.** An assignment from a substitution whose last command is a missed
  `grep` kills inspect.sh. End such a substitution with `; true`. And `[ \t]` in a `sed` bracket is
  space, backslash or `t` on BSD sed: use `[[:space:]]` (it cut `vitest` to `vites`, host only).
- **`starts_ci` lowercases whole strings.** macOS awk cuts `substr` by bytes but `tolower` rejects
  a broken UTF-8 sequence, so `tolower(substr(…))` aborted with "illegal byte sequence" whenever a prefix
  cut through `—`. Only the host target sees it (existing test 2c–2j).
- **JSON strings go through `json_q()`** in json.awk, a character loop. busybox treats the backslashes
  in a `gsub` replacement differently from gawk and BSD awk (defaults test 4a/4b).
- **A computed or proposed option is never an answer.** An `*italic*` option (A1, A4, A5, D3, K2, I6, R8;
  *Claude proposes …* in B1, B6, C2, D2, E1, E2, I4, I5, F2–F7) says how to work the value out. `answer.sh`
  refuses it, with or without the asterisks, and with an example after it (6i–6n): a live run once wrote
  the task prefix as "3–5 letters derived from A1", because the skill listed only four of them.
- **Generators write only settled answers** (`settled()` in lib.awk): a pending, stale, undecided or
  `n/a` answer produces nothing.
- **Installed plugins are data, not a guess.** `<plugin> installed` reads Claude Code's
  `plugins/installed_plugins.json`: user scope counts everywhere, local and project scope only in their own
  project (4p–4s). Tests pin `KICKOFF_PLUGINS` in helpers.sh, so the machine running them never decides.
- **A practice is one sentence.** In the workflow templates each R10 practice is `<Tag>: ….` ending in a
  full stop, so workflow.awk removes a dropped one and the step still reads (scaffold 6a–6d).
- **The port registry is machine-wide** and must never follow `CLAUDE_CONFIG_DIR`; test 3a/3b pins
  it. The compose scan runs on *every* allocation, not only for a new registry, so a port a project
  took without kickoff is never handed out (2a). Writes happen under a `mkdir` lock whose pid file
  lets a dead holder's lock be broken (4d).

## Testing

```bash
bash kickoff/scripts/test/all.sh                                            # host
docker run --rm -v "$PWD":/w -w /w bash:5 bash kickoff/scripts/test/all.sh  # container
```

Run both. Each target has already caught a bug the other missed (see above). The suite builds
fixtures under `mktemp -d` and replays a client PoC kickoff as a regression case. Read a plan row with
`cut -f`, never `IFS=$'\t' read`: tab is IFS whitespace, so an empty value column collapses and the
question text is read as the value (it once recorded R10's question as its answer).
