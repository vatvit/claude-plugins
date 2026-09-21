# How to render a diagram to a standalone artifact

docs-manager's default output is the **fence itself**, copied verbatim into the doc and drawn by
the viewer — GitHub, VS Code, JetBrains, Obsidian all do it. That needs no toolchain and is the
right answer almost always.

Rendering produces an *additional* file (`.svg`, `.png`, `.pdf`, `.webp`, `.html`) next to the
source. It is opt-in, per project, and the project supplies the renderer.

## HTML is not like the other four

An HTML artifact — an interactive D2 page, a pan/zoom mermaid wrapper — is supported and linked
like any other, but it behaves differently in two ways worth knowing before you choose it:

- **It is not necessarily self-contained.** If your generator emits sibling CSS/JS, the plugin
  knows nothing about those files: it links the `.html` and nothing else. Prefer a generator that
  inlines its assets into the single file, or commit the siblings yourself.
- **GitHub will not render it inline.** An SVG committed next to a doc displays in the GitHub UI;
  an HTML file offers a download instead. If the docs are read mainly on GitHub, SVG is the better
  artifact and HTML is for locally-served or published docs.

The fence itself is still in the doc either way, so the diagram is never *only* reachable through
the artifact.

## Why the plugin ships no renderer

Not an omission — three deliberate consequences:

1. **The fence is never parsed.** docs-manager copies the source block verbatim and never learns
   what a node is, which is what keeps it dependency-free and language-agnostic (`mermaid`, `d2`,
   `dot`, `plantuml` all behave identically). Rendering is the one operation that *must* understand
   the syntax, so it lives outside.
2. **Nothing shells out behind your back.** `render` is a separate explicit command. `index` never
   invokes it, so a routine `diagram index --write` can never silently start a container.
3. **Pinning and security stay with the project.** A renderer means Node + Chromium, a Go binary or
   a self-hosted service. The project owns that choice, its version pinning and its attack surface.

**Absent is a supported state.** With no render script every command still succeeds, nothing is
rendered, and the fence still appears in the doc. Never treat a missing script as an error to fix.

## The contract

An **executable** script at the docs root:

```
<root>/.docs-manager-render  <source-path>  <out-basename>
```

- `<source-path>` — the `.diagram.md` source file, whole. Not the fence body.
- `<out-basename>` — path with no extension. Write `<out-basename>.<ext>` where `<ext>` is one of
  **`svg`, `png`, `pdf`, `webp`, `html`** — in that order of precedence.
- Exit **non-zero** on failure.

**Precedence, when more than one exists.** The first match in that list wins, so a source with both
`x.svg` and `x.html` beside it links the SVG. If you want the HTML linked, do not also write an
SVG. `html` sits last because it was added after the other four and must not change which artifact
an existing project links.

**A script that exits 0 having written none of those** is reported as `NO ARTIFACT: …` naming the
extensions looked for. It is a warning, not a failure — a script may legitimately skip a source —
but it almost always means a wrong extension, so do not ignore it.

It receives the *path*, not the diagram body, precisely so the script can decide what to do with
the file — some renderers parse the fence themselves, others need it stripped first. That decision
is language-specific, so it belongs in your script.

Then:

```bash
bash <PLUGIN_ROOT>/scripts/docs.sh diagram render        # run your script over every source
bash <PLUGIN_ROOT>/scripts/docs.sh diagram index --write # link any artifact found, per doc
```

Rendering is explicit; **linking is automatic**. Each embedding doc links the artifact at its own
relative path.

## Failure semantics

A failing render is reported and then ignored: the previous artifact is left alone and `index`
still writes the block. Rendering is never on the critical path for a readable doc — which is also
why a broken renderer must never be worked around by editing generated blocks by hand.

## Recipes

Examples to adapt, **not supported integrations**. docs-manager does not know or care which you
use. Note the first passes the file straight through while the others strip the fence first — that
difference is exactly why the contract passes a path.

**Mermaid via mermaid-cli.** Heavy (Node + Chromium); pin the digest.

```sh
#!/bin/sh
exec docker run --rm --user "$(id -u):$(id -g)" \
  -v "$(dirname "$1")":/w minlag/mermaid-cli:<pinned> \
  -i "/w/$(basename "$1")" -o "/w/$(basename "$2").svg"
```

**D2.** Single Go binary; links come from `link:` in the source.

```sh
#!/bin/sh
sed -n '/^```/,/^```$/p' "$1" | sed '1d;$d' > /tmp/d.d2
exec d2 --layout elk /tmp/d.d2 "$2.svg"
```

**Kroki, self-hosted.** One container fronting many engines.

```sh
#!/bin/sh
sed -n '/^```/,/^```$/p' "$1" | sed '1d;$d' \
  | curl -sf -X POST --data-binary @- http://localhost:8000/mermaid/svg > "$2.svg"
```

## Checklist

Before telling anyone rendering is set up:

1. `chmod +x <root>/.docs-manager-render` — it must be executable, not merely present.
2. Run it by hand once on a real source; confirm the artifact lands at `<out-basename>.<ext>`.
3. Confirm it exits non-zero on a deliberately broken source.
4. `docs.sh diagram render` — expect `RENDERED:` lines, not `No .docs-manager-render in …`.
5. `docs.sh diagram index --write` — confirm each embedding doc gained its artifact link.
6. Pin the version (image digest, binary release, service tag). An unpinned renderer changes the
   committed artifact for reasons nobody will be able to reconstruct later.
