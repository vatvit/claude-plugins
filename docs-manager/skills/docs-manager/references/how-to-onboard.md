# How to onboard a legacy project

A project that grew without this plugin still has documentation: a README with run instructions, a
`doc/` folder, an ADR folder, notes beside the code, a vendor PDF, CI and compose files that say how
it is built. Onboarding finds all of it, agrees a plan with the user, and builds `docs/` as if this
plugin had kept the docs from the start.

Two commands do the mechanical part; the judgement is yours.

```bash
bash <PLUGIN_ROOT>/scripts/docs.sh survey [project]          # read-only: prints the plan
bash <PLUGIN_ROOT>/scripts/docs.sh onboard <plan> [project]  # applies an approved plan
```

## The plan

`survey` prints one tab-separated row per source: `action  kind  source  destination  bytes`.

| action | means | onboard does |
|---|---|---|
| `move` | the doc belongs in `docs/` | moves it (`git mv` when tracked, so history follows), rewrites links both ways, adds frontmatter |
| `link` | it stays where it is (README, a module's notes, an OpenAPI file, `CLAUDE.md`) | lists it in the **sources block** of `docs/_index.md` |
| `ignore` | not documentation (a PDF the app serves) | lists it in that block under *Not documentation* |
| `adopt` | already under `docs/`, but no frontmatter | adds frontmatter in place |
| `write` | a doc nothing covers yet: overview, architecture, how to run | nothing; reports it for you to write |
| `cite` | evidence for a `write` row: Makefile, compose, CI | nothing |

The survey's defaults are conservative: a documentation folder (`doc/`, `documentation/`, `wiki/`, an
ADR folder) moves wholesale, images included, so its relative links keep working; a root-level doc
moves; a doc beside code stays and is linked; an office file outside a doc folder is `ignore`, since
it may be something the app serves. A `.txt` doc moves as `.md`, since it reads as markdown as it
is. It skips dot-folders, `.gitignore`d files, and dependency, build and fixture folders.

A link to a moved folder (`[docs](doc/)`) is re-pointed at the folder most of its files went to.

A source is **handled** once it is under `docs/` with frontmatter, or linked from a doc under `docs/`.
That is why `link` and `ignore` rows are recorded as links in the sources block: a second survey sees
them as handled and proposes nothing. `write` and `cite` rows appear only before the first onboard.

## Procedure

1. **Survey.** Run `survey` on the project. It writes nothing, so it needs no approval.
2. **Read before proposing.** Open each source whose default you doubt: is a root `NOTES.md` project
   knowledge or a scratch file? Is `public/terms.pdf` reference material or served by the app? Is an
   office file reference material the project did not write? Then it is external: change the row to
   `move` with a destination under `docs/external/`.
3. **Show the plan as a table** (action, source, destination, and one line of why for every row you
   changed from the default), with the `write` rows and the `cite` files each will be written from.
   Say plainly that **nothing is moved before they approve**.
4. **Write the approved plan to a temp file outside the project** (`mktemp`), never into the project:
   it is scratch, and a plan file in the tree would itself be surveyed.
5. **Onboard.** `onboard` checks the whole plan first and changes nothing if any row is wrong: an
   unknown action, a missing source, a destination outside `docs/` or one that exists, two sources to
   one destination. Report its output: `MOVED`, `RELINKED`, `FRONTMATTER`, `CREATED`, `TO WRITE`, and any
   `REVIEW` or `BROKEN LINK`.
6. **Finish what the script cannot:**
   - Fix every `BROKEN LINK`. A link that was dead before onboarding is left as the author wrote it, so
     the report names it; fix or remove it, never invent a target.
   - Act on every `REVIEW` line; onboard reports these and changes nothing:
     - *`<doc> is not markdown`*: an `.rst` or `.adoc` moved into `docs/`. It has no frontmatter and
       `_index.md` does not list it. Offer to convert it to markdown; otherwise link it from the doc
       that covers its subject, so a reader can find it.
     - *`<file> names <old path>, now <new path>`*: a code comment, an `.rst` or an HTML page names a
       moved doc by its old path. Onboard cannot parse those links. Show each one to the user and
       update it once they agree.
   - Fill every `description: TODO` (moved docs, new `_index.md` files), then `index --write` so the
     parent listings pick them up.
   - Card every file moved into `docs/external/`: follow
     [`how-to-external-docs.md`](how-to-external-docs.md).
   - Write each `TO WRITE` doc from the code and the `cite` files. **Every fact names the file it came
     from**, and anything inferred says so ("inferred from `docker-compose.yml`; not confirmed").
     Never invent a fact to make a doc complete; leave the gap marked.
   - If the project has a `CLAUDE.md` or `AGENTS.md` holding project knowledge, that is a separate job:
     [`how-to-claude-md.md`](how-to-claude-md.md), after the docs exist to move it into.
7. **Check.** `docs.sh check docs` must pass, and a second `survey` must propose nothing.

## What onboarding never does

- Touch the project before the plan is approved.
- Delete a source. `ignore` leaves it in place, and a move keeps git history.
- Fetch anything. Exported wiki pages or Confluence spaces dropped into the project are sources like
  any other; fetching them is out of scope.

## Checklist

- [ ] Survey run, plan shown, approved by the user
- [ ] Plan written to a temp file outside the project
- [ ] `onboard` reported no `PLAN:` errors
- [ ] Every `BROKEN LINK` fixed or removed
- [ ] Every `REVIEW` line acted on
- [ ] No `description: TODO` left
- [ ] Every file under `docs/external/` carded and stamped
- [ ] Every `TO WRITE` doc written, each fact sourced, inferences marked
- [ ] `docs.sh check docs` passes; a second `survey` proposes nothing
