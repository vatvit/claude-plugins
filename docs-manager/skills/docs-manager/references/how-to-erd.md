# How to draw an ERD

An entity-relationship diagram is the form for **what a model is made of**. Read this before drawing one,
and again before changing one. It applies whether the thing being drawn is relational tables, TypeScript
interfaces, structs, or JSON schemas — an object graph has props, types and nested sub-structures exactly
as tables have columns and keys.

Everything here is learned the hard way: each rule exists because a picture that broke it was shipped,
passed every automated check, and taught a reader something false.

## 1. Is an ERD the right form?

One notation per question. Forcing a subject into the wrong one loses the thing you were explaining:

| The question the reader brings | Form |
|---|---|
| *What exists, and what is made of what?* | **`erDiagram`** |
| *How is a decision reached? What happens next?* | `flowchart` |
| *What state is this thing in?* | `stateDiagram-v2` |
| *Who calls whom?* | `sequenceDiagram` (architecture, not domain — sparingly) |

A subject can legitimately need two. **Two pictures means two host docs** — the tooling allows exactly one
fence per source and resolves one marker per doc — so split on *subject*, not on tooling: each doc must own
something a reader would look for by name. A doc that exists only to hold a picture is the failure case.

**When changing form, list what the old form was doing and check the new one still does it.** Switching
notation silently drops whatever the old one expressed for free.

## 2. The core rule: an ERD is a transcription, not a selection

**If the type declares it, it is drawn.** Every prop, its type, whether it is optional. Not "the
interesting ones", not "the ones that earn a box".

Curating columns has two failure modes, and both are expensive:

- **Every prop becomes a negotiation.** Reviews turn into *"why is this one here and that one not"*,
  round after round, with no rule to settle it.
- **Curation drifts into invention.** A curated diagram grows columns no type declares while omitting ones
  that do — and nothing can catch it, because there is nothing to compare against. A transcription is
  checkable in both directions.

So: **read the declarations, then transcribe them.** Do not draw from memory, from prose, or from the
previous version of the picture.

## 3. Draw the designed model, and mark what is not built

A diagram that only shows today's code cannot express intent, and gets deleted and redrawn every time the
model moves. Draw the **designed** model and mark the gaps. Three markers, and they mean three different
things:

- **a dashed box** — the whole entity is designed and not built;
- **`NOT BUILT - <task id>`** on a row — the entity is built, that column is not;
- **`REVIEW <task id>`** — both built, drawn as the code really is, but a task may move this row.

Anything unmarked is built and settled.

Two rules that come with the markers:

- **A row under review is still drawn as it really is.** The marker says *expect this to move*, never
  *here is what we wish it were*. That is what stops the picture becoming a wishlist.
- **A marker cannot be written until the task exists**, so a question raised in review is not recorded
  until it has an id. Create the id in the same breath as the finding — otherwise the row reads as settled
  and the finding is lost.

## 4. Every relation is carried by a visible column — so no box is ever empty

This is the rule most easily got wrong when drawing an object graph, because a nested object *feels* like
it needs no column.

- The **holder** shows the prop that holds it (`Permission.when`, `Trace.evaluated`, `Order.lines`), **or**
- the **referrer** shows the id that points back (`Permission.on`, `TraceEntry.rule_id`, `Line.order_id`),
  exactly as a foreign key would be.

**The edge's label names that column**, so a reader can always tell which end holds the relation.

A box with a name and no rows is a defect, not a style: it means every field was turned into an edge and
the prop names vanished. It also reads identically to a genuinely empty type, and no legend can rescue
that — the reader simply asks *"what does a box with only a name mean?"*.

**The one exception is a call**, where neither side stores the other. Say so in the label, in capitals
(`decide() RETURNS`, `evaluate() IS GIVEN`), so the exception is visibly an exception.

**Containment is not scope, and readers will assume it is.** A box holding *a list of rules* and *a list
of things* next to each other invites the reading that the rules apply to the things. They do not — what a
record applies to is whatever its own column names. Wherever a picture puts two sibling collections in one
container, say in the legend that membership means only *where a record is declared*. This is the single
most common wrong inference drawn from an otherwise correct ERD.

## 5. Two kinds of relation, and the line says which

Use ER's own semantics rather than inventing a convention:

- **solid / identifying = CONTAINED** — the child has no id of its own, lives inside its parent, and cannot
  exist alone. This is what makes an object graph drawable as an ERD at all, and it usually carries a real
  consequence (a contained value cannot be shared or referenced, only nested).
- **dashed / non-identifying = REACHED** — a stored key that must be looked up, or a value a call takes or
  returns.

**Therefore "not built" lives on the BOX, never on a line.** A dashed line already means something in ER
notation; borrowing it for a second meaning breaks both. One style, one meaning — and the meaning is
declared per picture, in the legend.

## 6. An edge is a JOIN — check the keys at both ends

Before drawing any edge, name the column on each end and check they can actually match. An edge whose ends
share no comparable key asserts a link the model does not have, and **every automated check will stay
green** while it lies — a reader finds it by asking *"I see the line, but where is the connection?"*.

The usual cause is a **collapsed hop**, and the fix is never a better label:

> A reference carries an **instance** id; a definition is keyed by a **content id**. Those never match, so
> `REFERENCE → DEFINITION` cannot be joined. The missing entity is the **instance record** that holds
> both. Draw it.

**A collapsed hop is a missing entity.** Restoring it usually pays for itself immediately — it is what
makes visible that two instances share one definition and therefore share everything defined on it.

## 7. A box asserts that a type exists

That is the whole meaning of a box, and it constrains what may be one:

- **A thing that is not a separate type is an edge label, never a box** — a role something plays, a value
  object with no identity, a convenience name for a group of fields.
- **If the project keeps a glossary, every box is a glossary term spelled verbatim.** Where a picture must
  name something the glossary does not define, mark it as *engine vocabulary* rather than passing it off as
  a term — and file the glossary gap.
- **An abstraction over several real types is not a box.** Draw the real types. Inventing a supertype box
  puts a name in the model that nothing declares.

## 8. Unions, maps, calls, and foreign types

Four shapes that need a stated convention, or each reader invents their own:

- **A union: one box per variant**, plus the union's own box, with edges reading *"is exactly one of"*. Per
  variant is what makes visible that a field exists in one case and not another. The union's own box
  carries whatever belongs to the union rather than to a variant (a derived key, or a note that the variant
  is decided structurally by **which key is present** rather than by a stored discriminator). If some
  variants are field-identical, collapsing them into one box with the values enumerated is allowed — but
  say so in the legend, or it reads as an inconsistency.
- **A map: its columns are its KEYS**, with one edge carrying the value type. Required keys get their own
  row; an open key set gets one row standing for the rest, which also documents that no closed list exists.
- **A call is not a field.** Mark such rows (`A CALL`), and let the edges say what the call is asked about
  and what it returns. A type that is nothing but calls is often the point — it is what *enforces* that
  nothing else can be read.
- **A type another diagram owns is a stub**: its id plus the props carrying the relations drawn *here*,
  and a pointer to the diagram that owns it. Repeating its full field list is a second source of truth,
  and the two copies will drift.

## 9. The legend goes in the host doc, never in the fence

A `%%` comment **does not render**. Anything a reader needs in order to read the picture — the markers,
what solid and dashed mean, the union and map conventions, what is deliberately *not* drawn — is invisible
to exactly the reader who is lost, while the markers themselves are perfectly visible.

Put the legend in the host doc's prose. The fence keeps a **pointer**, never a second copy: two statements
of one fact is how one of them drifts. The fence's comments are for whoever edits the source.

**State what is deliberately absent, and why.** Under a transcription rule, absence is otherwise read as an
oversight, and the next author "completes the set".

## 10. `erDiagram` gotchas (mermaid)

Each of these is a parse or a lie, not a nitpick:

- **A bare `%%` line breaks the parse.** A comment marker with no text after it. `flowchart` tolerates it;
  `erDiagram` does not. Write `%% .` for a blank comment line.
- **A trailing `;` on `classDef` / `class` breaks the parse.** Same asymmetry.
- **`subgraph` DOES work** — clusters and their labels render. Grouping by *who writes each part* (authored
  content · supplied per request · state · results) is usually more useful than grouping by topic.
- **`direction TB` does nothing** in `erDiagram`. Do not spend time on it.
- **`PK, FK` on one attribute is supported**, for a column that is both identity and reference.
- **An attribute-less entity parses** — which is exactly how rule 4 gets broken. Do not rely on it.
- **`classDef` + `class` reach entities**, so a per-entity style (the dashed *not built* box) works.
- **`mermaid.parse()` is not `mermaid.render()`**, and neither is *readable*. Parsing proves the viewer
  will draw something rather than an error box. Rendering under a headless browser proves a layout exists.
  Only a human proves it reads.

## 11. Render and read it after every structural change

Not once at the end. Layout defects — a box stranded in a corner, a lane shoved sideways by one long edge,
a cluster of text duplicating the host's prose — are invisible to every check and obvious on sight.

**Read the SVG's text, not a downscaled screenshot.** A character lost in a scaled-down PNG reads as a
syntax error and costs a round trip; SVG text is exact and greppable. Grepping it is also how you confirm
every entity you wrote actually rendered, exactly once.

## 12. When it gets big

A complete transcription of a real model is large. In order:

1. **Tighten the cell comments and edge labels.** They drive box width, and the *structure* is the column
   name and type — the comment is a hint. Long reasoning belongs in the host doc's prose. This is the only
   lever that costs no content, and it is worth a third of the width.
2. **Merge one-box clusters.** A cluster containing a single entity renders as a stranded island and
   widens the whole canvas.
3. **Then stop, and show it.** Whether the density justifies **splitting the doc** is a decision for
   whoever owns the doc set, made with the picture in hand. It is never a reason to quietly drop rows —
   that silently reverts rule 2.

## Checklist before blessing

- [ ] Every declared prop of every owned type is a column or is carried by an edge whose label names it.
- [ ] **No box has zero rows.**
- [ ] Every edge's two ends have columns that could actually join — no collapsed hops.
- [ ] Every box is a real type (and a glossary term, where the project keeps one).
- [ ] Designed-and-unbuilt parts are drawn and marked, and every marker names a task id that exists.
- [ ] Solid vs dashed used consistently; "not built" is on boxes only.
- [ ] The legend is in the host doc; the fence carries a pointer, not a copy.
- [ ] What is deliberately not drawn is stated, with its reason.
- [ ] The fence parses, and the picture has been **rendered and looked at**.
- [ ] `bless` **before** `diagram index --write` — the other order generates a *"may be stale"* notice that
      is already false.
