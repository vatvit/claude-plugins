# Adopting crew mid-project

A project that already runs parallel sessions by hand usually has crew's rules scattered over
three places:
- the hot spots are listed in the project's `CLAUDE.md`;
- the holds are a hand-kept bullet list (`_holds.md` or similar);
- the session rules ("never `git add -A`", "only the coordinator commits") are written as prose.

The coordinator moves them into crew in this order. Each step is safe to repeat.

1. **Set the hot spots.** Copy the globs from the project's notes:
   `config set hotSpots 'src/schema.ts' 'src/scenes/*.ts'`. This writes `.crew.json` and keeps
   any keys already there. It works before anyone has joined, and does not start a crew. Commit
   `.crew.json`.
2. **Ask the user how this project commits and pushes**, and record their answer:
   `config set committer human-approved` (the default: `land` prints the commit for the user),
   `coordinator` or `each-session`; `config set push human` (the default: the user pushes) or
   `committer`. Never pick these yourself. See [config.md](config.md). Your own habits across
   projects go in the user file instead: `config set --user hookMode warn`. Project-only keys
   (listed in [config.md](config.md)) are refused there.
3. **Everyone joins.** The coordinator runs `whoami "<name>" coordinator`. Each session the user
   puts in the crew runs `whoami "<name>"`; nobody joins by itself. This comes before the import, because a hold needs a holder who is in the
   crew.
4. **Import the holds:** `hold import _holds.md --dry-run`, read the plan, then run it without
   `--dry-run`. It reads one hold per bullet, for example `- <path> — <holder> (PLUG-12, since 09:00)`:
   - the separator can be `—`, `–`, `-`, `:` or `by`, and the first one in the line wins, so a path
     may contain a hyphen;
   - the holder can be a crew name or a display name;
   - a task id in the parentheses becomes the hold's task.

   A holder who is not in the crew is listed and not held. A path someone else already holds is
   refused, and a glob is skipped (globs belong in `hotSpots`). Fix the cause and import again.
   Holds that are already in place are left alone. Once the import is clean, delete the
   hand-kept file: the registry (`who`) is now the only list.
5. **Cut the rules crew now enforces from the project's `CLAUDE.md`.** These are the ones that
   go:
   - the hot-spot list (now `.crew.json`) and the holds list (now `who`);
   - "never `git add -A` / `commit -a` / `stash` / `reset --hard`", and "no branches, no worktrees":
     the guard hook enforces these;
   - "only the coordinator commits" (now `committer`) and the hand-off format (now `msg handoff`).

   Keep every rule that is about the project itself: how to build and test, its own
   conventions and its domain. Rules that apply only while a crew runs move to the `crewRules`
   file ([solo.md](solo.md)). If unsure, keep it. A duplicated rule costs a few tokens, while a
   lost one costs a night.

Then run `status`. It shows the crew, the holds and every dirty path by owner, so it is the
check that the adoption took.
