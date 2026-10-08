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
│   ├── lib.sh         ← locating files, running a program over the model, diff-guarded writes
│   ├── plan.awk / plan.sh        ← what to ask now (--next), the review table (--review)
│   ├── answer.sh                 ← the only writer of .kickoff-answers
│   ├── charter.awk / charter.sh  ← docs/project/charter.md from the answers
│   ├── scaffold.sh               ← docs/ skeleton, CLAUDE.md (claude.awk), task config + workflow
│   ├── get.awk                   ← settled answers for shell scripts
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
  an empty answer would ask B4 before B2 was known (`≠` holds for an empty string).
- **`n/a` counts as answered** (so `--next` moves on) but never reaches the charter. It is how a
  *judge* question is retired.
- **The charter refuses to overwrite** a differing file (exit 3). After kickoff it is edited by hand.
- **Two kinds of generated file.** Seeded files (`_index.md`, `.task-config.json`, WORKFLOW.md) are written
  once and are the user's from then on. Regenerated files (charter, CLAUDE.md) are rewritten only while
  unchanged, and refused once edited. Never let `scaffold.sh` overwrite a seeded file (3c).
- **A client's repo carries nothing of the user.** For tasks outside the repo, CLAUDE.md says so in prose
  and never prints the tasks path, which contains the home directory (4h). The task registry entry is
  inserted into the existing file, keeping the other projects (4d, 4l).
- **The user layer is per account** (follows `CLAUDE_CONFIG_DIR`, 3b/3c); the port registry is per
  machine. Precedence: answer > user default > `(★ if …)` > ★.
- **JSON strings go through `json_q()`** in json.awk, a character loop. busybox treats the backslashes
  in a `gsub` replacement differently from gawk and BSD awk (defaults test 4a/4b).
- **Generators write only settled answers** (`settled()` in lib.awk): a pending, stale, undecided or
  `n/a` answer produces nothing.
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
fixtures under `mktemp -d` and replays the sample-poc kickoff as a regression case.
