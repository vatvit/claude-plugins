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
│   └── test/kickoff.test.sh
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

## Testing

```bash
bash kickoff/scripts/test/kickoff.test.sh                                            # host
docker run --rm -v "$PWD":/w -w /w bash:5 bash kickoff/scripts/test/kickoff.test.sh  # container
```

Run both. Each target has already caught a bug the other missed (see above). The suite builds
fixtures under `mktemp -d` and replays the sample-poc kickoff as a regression case.
