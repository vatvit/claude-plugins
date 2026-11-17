// Markdown guide -> standalone HTML page. Runs inside the build container only (build.sh).
// Usage: render.mjs <in.md> <out.html> <css-file> <base-dir-url>
import { readFileSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";

const require = createRequire("/cache/node_modules/");
const { marked } = require("marked");

const [, , inPath, outPath, cssPath, baseUrl] = process.argv;
if (!inPath || !outPath || !cssPath || !baseUrl) {
  console.error("usage: render.mjs <in.md> <out.html> <css-file> <base-dir-url>");
  process.exit(2);
}

let src = readFileSync(inPath, "utf8");
// docs-manager frontmatter: kept in the source, never printed. Its title becomes <title>.
let title = "";
const fm = src.match(/^---\n([\s\S]*?)\n---\n/);
if (fm) {
  const t = fm[1].match(/^title:\s*"?(.*?)"?\s*$/m);
  if (t) title = t[1];
  src = src.slice(fm[0].length);
}

const escape = (s) => s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
const body = marked.parse(src);
const css = readFileSync(cssPath, "utf8");

writeFileSync(
  outPath,
  `<!doctype html>
<html lang="uk"><head><meta charset="utf-8">
<base href="${escape(baseUrl)}">
<title>${escape(title)}</title>
<style>${css}</style>
</head><body>
${body}
</body></html>
`,
);
