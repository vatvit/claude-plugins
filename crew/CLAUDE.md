# CLAUDE.md — crew plugin

Guidance for working on this plugin. The repo-wide rules (shell conventions, plugin
independence, how to change a plugin) live in the repo root `CLAUDE.md` and apply here.

## Layout

```
crew/
├── .claude-plugin/plugin.json
├── bin/crew                `crew` on the Bash tool's PATH (a plugin's bin/ is added while it is enabled)
├── hooks/
│   ├── hooks.json          SessionStart + PreToolUse(Edit|Write|MultiEdit|NotebookEdit) + PreToolUse(Bash) + PostToolUse + Stop
│   ├── fast.sh             builtins-only "is there a crew here?" — sourced first by every hook
│   ├── session-start.sh    ~2 lines of context; silent in a repo without a crew
│   ├── pre-edit.sh         holds guard → snapshot → claim (each from its area script, if present)
│   ├── pre-bash.sh         whoami id pick-up → git guard (land area)
│   └── mail.sh             post | stop: unread-mail notice after a tool call, one held Stop per message
├── skills/crew/
│   ├── SKILL.md            roles + non-negotiables + pointer table (keep it under ~120 lines)
│   └── references/         one file per area, read only when that area is in play
└── scripts/
    ├── crew.sh             the one entry point; `help` is built from each script's `# help:` lines
    ├── lib.sh              the ONE place for project/state, config layers, identity, claims, locks, hook decisions
    ├── whoami.sh config.sh status.sh msg.sh
    ├── holds.sh slot.sh copy.sh snapshot.sh land.sh inbox.sh watch.sh one area each: functions when sourced, CLI when executed
    ├── status.d/  msg.d/   per-area parts, so adding an area never edits status.sh / msg.sh
    └── test/               helpers.sh, run.sh, <area>.test.sh, Dockerfile (bash:5 + git)
```

## Design rules (don't regress these)

- **No crew, no cost.** Every hook exits early unless `<git-common-dir>/crew/` exists. In a repo
  without a crew the plugin prints nothing and adds no tokens. A crew starts with the first
  `whoami`.
- **State lives in `<git-common-dir>/crew/`.** Every session on the tree shares it, it is never
  committed, and it needs no `.gitignore` entry. Every mutation goes through `with_lock` and
  `replace_file` (temp + `mv`).
- **Name vs display name.** Peers address a session by its SendMessage name, which may contain
  spaces. crew keeps that as `display=` and keys everything by `name_for` (the name itself when it
  is valid, else a lowercase slug), so `PLUG-W1` stays `PLUG-W1` and `Max Coordinator` becomes
  `max-coordinator`. Messages show display names, and `CREW_AS` accepts either form. SessionStart
  auto-joins a titled session (`session_title`) as a worker. It never takes a name already bound, and
  it never makes a coordinator.
- **A crew name is the identity.** Holds, slots and claims are all keyed by name. The Claude
  session id only maps a hook payload to a name (`sessions/<name>`: `sid= role= since= display=`).
  Scripts learn the caller via `caller_name`, which takes `CREW_AS` (a name or a display name) when it
  is set, and otherwise `CREW_SID`. SessionStart exports `CREW_SID` through `CLAUDE_ENV_FILE`, the
  preamble Claude Code runs before every Bash command. That mechanism is documented for SessionStart
  hooks but not explicitly for plugin hooks, so when the file is absent SessionStart teaches the
  `CREW_AS=<name> crew` form instead. The live check is PLUG-040. `bin/crew` puts the command on PATH.
- **Per account vs per machine** (the repo rule in the root `CLAUDE.md` Config convention):
  - The user config `crew.json` is per account. It follows `${CLAUDE_CONFIG_DIR:-~/.claude}`.
  - The name registry (`CREW_HOME`, `~/.claude/crew`) is per machine. It deliberately ignores
    `CLAUDE_CONFIG_DIR`, because SendMessage spans accounts.
  - `core.test.sh` asserts both.
- **Names are unique on the machine, not just in the crew.** SendMessage addresses sessions
  machine-wide, and several crews (one per repo) can run at once. `whoami` checks
  `~/.claude/crew/names/<name>` (`CREW_HOME`) and refuses a name a live session of another crew
  holds. An entry is live while that crew's `sessions/<name>` still has the same sid; a stale one
  is taken over silently. Every message and the SessionStart line carry `[<crewId>]`.
- **Nobody types a session id.** The pre-bash hook sees the session id of the
  `crew.sh whoami <name>` call and leaves it in `<git-common-dir>/crew-pending/<name>` for `whoami.sh` to bind. It is outside `crew/` on purpose:
  a join that never completes must not switch crew on for the repo and put peer sessions under the guard.
  `--sid` is the fallback for when the hooks are not installed.
- **Area scripts are dual-use.** `holds.sh`, `slot.sh` and the rest define functions when
  sourced (by hooks and other scripts) and run their CLI when executed (`is_main`). Hooks load
  them with `load_area`, so a missing area degrades instead of failing.
- **Guard hooks deny, which is the plugin's exception to "hooks never block".** A warning
  arrives after `git add -A` has already staged a peer's files. They still always exit 0: the
  denial is a JSON `permissionDecision`, never an exit code. `hookMode=warn` turns them into
  warnings.
- **Hooks pay nothing where there is nothing to do.** They run on every Bash call and every edit,
  in every repo. `hooks/fast.sh` reads the payload with `read` and walks up to `.git` with pure bash.
  With no `crew/` there, the hook exits without a single fork. pre-bash also exits early unless the
  payload names a guarded git subcommand or `whoami`. Measured: 47 → 3 ms per Bash call. Keep any new
  hook logic behind these checks.
- **Config is parsed once per process.** `crew_try_init` runs one `git rev-parse` (it needs git
  2.31 or later for `--path-format=absolute`) and one awk pass over both config files into `CREW_CFG`.
  After that, `cfg` forks nothing. The pre-edit hook reads config several times per edit, and this
  took it from ~95 ms to ~50 ms. Never read a config file directly anywhere else.
- **lib.sh owns the one EXIT trap.** It drops a lock left by a dying process and then runs
  `CREW_ON_EXIT` (for example, `slot run` releasing its slot). A script that sets its own `trap … EXIT`
  silently disables both, so it sets `CREW_ON_EXIT` instead. That includes tests that source `lib.sh`.
- **Silence is measured, not guessed.** Every tool call bumps `<state>/seen/<sid>` (fast.sh: `crew_fast_seen`,
  a redirection on a builtin, so no fork), and `watch.sh` reads its mtime. A session counts as silent only
  while it owns something (hold, slot, claimed dirty path). An idle session that owns nothing is just idle.
  The stale-slot rule lives once, in `slots_plan` (field 13); `slot list` and `watch` both read it.
- **Mail is a file before it is a message.** `msg --send` files a copy under `<state>/mail/<name>/`,
  and the mail hooks repeat the notice until it is read. They find "no mail for me" without a fork:
  sending leaves `<state>/unread/<sid>` for the recipient (fast.sh: `crew_fast_unread`), and the slow
  path removes a stale marker. `whoami` and SessionStart re-arm it for a session's new id.
- **Claims are advisory.** The pre-edit hook records which session touched which path. A path
  written another way (Bash, a generator) shows as *unclaimed* in `status`, which is the point:
  `status` surfaces it instead of guessing.
- **Scripts do the mechanics, the skill does judgement.** Before adding prose to the skill,
  check whether a script could print the answer instead. That is how `status`, `msg` and the
  denial texts came about.

## Testing

```bash
bash crew/scripts/test/run.sh                                   # host: bash 3.2 + BSD userland
docker build -t crew-test crew/scripts/test                     # once: bash:5 (Alpine/busybox) + git
docker run --rm -v "$PWD":/w -w /w crew-test bash crew/scripts/test/run.sh
```

**Run both.** The plain `bash:5` image has no git, and every crew script needs it, hence the
Dockerfile. Hooks are tested by piping a JSON payload into them (`helpers.sh: payload, hook`).
`join` goes through the real path, so the hook leaves the id and `whoami` binds it. The suites
never read the real `~/.claude/crew.json` (`CREW_USER_CONFIG` points into the fixture).

What the suites cannot prove: that Claude Code honours the `permissionDecision: deny` JSON and
injects SessionStart stdout. Both are documented hook contracts. Check them by hand once per
Claude Code upgrade: join a crew in a scratch repo and try `git add -A`.
