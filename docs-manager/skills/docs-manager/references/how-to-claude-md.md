# How to keep an agent instruction file small, using the project's docs

`CLAUDE.md` — and its equivalents (`AGENTS.md`, `.cursorrules`, a repo-level system prompt) — is the file
an agent reads **before every task, in full, every session**. That is its whole value, and the reason it
decays: everything learned feels worth putting somewhere that will definitely be read.

Read this before optimising one, and before deciding where a newly-learned rule should go.

## 1. The one test

> **Instruction, or knowledge?**
>
> - **Instruction** — a rule about *how to work*: how to talk to the user, what to run, what to never do,
>   what order to do things in, when to ask. It is addressed to the agent and is useless to anyone else.
> - **Knowledge** — anything true about the project: how a system works, why it was built that way, what a
>   module is called, what a test guards, what an invariant is. It is useful to the agent, to the user,
>   to a contributor, and to the agent's next session.

**Instructions stay in the file. Knowledge goes to `docs/`, and the file keeps a pointer.**

The test is not "is this important?" or "will the agent need it?" — by those tests everything stays, which
is how the file got big. Nor is it length: a one-line fact about the codebase is still knowledge.

## 2. Why the file decays, in the exact way it does

Three mechanisms, and recognising them is most of the job:

- **The convenient home.** A rule learned mid-task has a real home in `docs/`, but finding it costs a
  minute and appending to the instruction file costs nothing. It is the path of least resistance, and it
  is taken every time under deadline.
- **The "rules that bite" block.** Knowledge written *in the agent's voice* — *"the rule that bites here
  is…"*, *"never do X, it cost us a day"* — reads like an instruction. It is not. A project invariant
  stays an invariant when nobody is instructing anyone.
- **Compression into unfalsifiability.** Knowledge condensed for the file loses the reasoning that would
  let a reader tell whether it is still true. It then survives long after the code changed, because
  nothing in it can be checked and nobody is looking.

The result is the same in every project that has run a while: a file where the instructions are a minority
of the lines, buried in system descriptions that a doc already covers better.

## 3. Where knowledge goes

**Into the doc that owns the subject** — not into a new "agent notes" doc, which is only the instruction
file again under another name, and not into a single dumping doc, which dies the same death.

| What you are holding | Its home |
|---|---|
| how a system works, its model, its vocabulary | that system's doc |
| what shipping it settled, a correction, a decision and its consequences | that doc's `As built` / decision record, linking to the task that made it |
| the options weighed for a decision, a rejected alternative | the task that made the decision (history, not docs) |
| module names, function names, test ids, the invariants each guards | that doc, in a **§Code anchors** section (see rule 4) |
| how to run something, commands, ports, the gate | the setup / CI / dev-process doc |
| a rule about a tool or process with no doc at all | a **new doc**, registered in its `_index.md` |

**Create a new doc only when no owner exists** — and then it owns a subject a reader would look for by
name, never *"the leftovers from the instruction file"*.

## 4. `§Code anchors` — the section this job usually needs

Most instruction files accumulate one thing the docs genuinely lack: **the mapping from a documented rule
to the code and tests that carry it** (*"this is enforced by `foo.test.ts` §S1"*, *"the one conversion
site is `units.ts`"*). Docs describe models; they often name no symbols at all.

Add it to the owning doc as a section — a table or a short list — under this contract:

- **The rule lives in the doc's prose; the anchor only says where to look.** If the anchor is the only
  place a rule is stated, it is not an anchor, it is the doc's missing paragraph — write that instead.
- **Link each row to the section it belongs to**, so the two cannot drift apart unnoticed.
- **Name the test and what it catches**, not just the file. *"A test covers this"* is not an anchor.

This is also the answer to *"but the agent needs the symbol names in context"*: it does not need them
before the task. It needs to know **which doc to open**, which is one line in the instruction file.

## 5. The extraction procedure

Work **block by block**, and never delete before the destination exists.

1. **Inventory.** List every block in the file with its subject and line span. Sort them into *instruction*
   / *knowledge* / *mixed* by rule 1. Mixed blocks split — most do.
2. **Find the owner** for each knowledge block. If there is none, note it; those become new docs.
3. **Diff, do not assume.** Open the owning doc and check **what it already says**. Typically most of the
   block is already there in fuller form — the file was a condensed restatement. Grep the doc for the
   block's distinctive symbols and phrases; what comes back empty is the actual gap.
4. **Migrate the gap** into the owning doc, in that doc's voice — not as a quoted block from the
   instruction file, and not labelled as having come from it. Where it lands is rule 3's table.
5. **Delete the block** and replace it with **one line** in the instruction file, or with nothing if the
   pointer table (rule 7) already covers it.
6. **Verify** (rule 6) before moving on to the next file-wide pass.

Do this in one sitting per file if you can. A half-migrated instruction file is worse than either end
state: two homes, and no rule about which is authoritative.

## 6. Verify that nothing was lost — mechanically

Judgement does not scale over hundreds of lines, and "I moved everything" is a claim. Make it evidence:

```bash
# every `backticked identifier` the old file named, checked against the new state
git show HEAD:CLAUDE.md | grep -o '`[A-Za-z_][A-Za-z0-9_.:/ ()-]*`' | tr -d '`' | sort -u > /tmp/old.txt
while IFS= read -r s; do
  [ ${#s} -lt 4 ] && continue
  grep -rqF -- "$s" docs CLAUDE.md || echo "MISSING: $s"
done < /tmp/old.txt
```

Then **read every hit**. Most will be legitimate: names the old file mentioned only to say they were
retired, incidental words, paths that exist as files. The rest are rules you dropped — migrate them.

Do the same for prose facts the grep cannot see (a rule with no symbol in it) by re-reading the old
version against the new docs once, end to end. Keep the pre-edit copy until that pass is done.

Then verify nothing **broke**:

- `docs.sh check` — indexes current, no broken file links.
- The project's own anchor/fence checks, if it has them — a migration creates many new cross-links, and
  a link into a heading that does not exist lands silently at the top of the page.
- **Every link in the rewritten instruction file resolves.** Nothing checks that file; do it by hand.
- The formatter, if docs are formatted. A file written wholesale by a tool usually is not clean.

## 7. What the file looks like afterwards

- **A short statement of what the file is** — instructions only; knowledge lives in `docs/`; if a section
  starts growing into project content, move it and leave a pointer. This is what stops the regrowth.
- **Orientation**: a few lines on what the project is, and the link to the docs root and the glossary.
- **The working agreements**: roles, how decisions are made, what to verify before claiming something
  works, when to ask rather than assume, the test/bug protocol.
- **Process**: the task workflow, the git workflow, what to run and what never to run.
- **One pointer table**: subject → the doc that owns its rules. This replaces every system block, and it
  is the part that earns its place in every session's context.
- **A closing instruction**: *when you learn something that bites, write it into that doc — not here.*

A file that used to be a thousand-plus lines commonly lands in the low hundreds. The number is not a
target; **the composition is** — if a section is describing the project rather than instructing the agent,
it is still in the wrong file.

## 8. Traps

- **Do not delete on the assumption that "the doc surely covers it."** Open the doc. This is the one step
  that makes the whole job safe, and the one most tempting to skip on block forty.
- **Stale claims will surface.** The instruction file will assert things the docs contradict — a system
  described as unbuilt that shipped, a renamed symbol, a rule since reversed. Each is a **finding**: check
  which is right, fix the doc if the doc is wrong, and drop the stale claim rather than carrying it over.
- **Docs may cite the instruction file** (*"a standing rule in CLAUDE.md"*). After the move, some of those
  are wrong. Grep the docs for the filename and repoint each one at the doc that now owns the rule.
- **Knowledge in the agent's voice is still knowledge.** Rewrite it in the doc's voice as you move it; a
  paragraph addressed to "you" in the middle of a design doc is the tell that it was pasted.
- **Do not tidy neighbouring content while you are in there.** A migration is already a large diff; mixing
  in edits nobody asked for makes it unreviewable. File them.
- **In a repo where several agent sessions share one working tree**, only touch files you are editing, and
  check what a repo-wide formatter run would rewrite before running one.

## Checklist before calling it done

- [ ] Every remaining section passes rule 1 — it instructs, it does not describe.
- [ ] Every knowledge block has a home in `docs/`, and you **opened** that doc to confirm it.
- [ ] Gaps were migrated in the owning doc's voice, not pasted.
- [ ] New docs (if any) are registered in their `_index.md` and have frontmatter.
- [ ] The identifier residue check was run **and every hit was read**.
- [ ] `docs.sh check` passes; the project's anchor/fence checks pass; the formatter is clean.
- [ ] Every link in the rewritten instruction file resolves.
- [ ] Docs that cited the instruction file now cite the doc that owns the rule.
- [ ] Stale claims found during the move were resolved, not carried over.
- [ ] The file states that knowledge belongs in `docs/`, and carries the subject → doc pointer table.
