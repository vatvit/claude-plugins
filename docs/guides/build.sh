#!/usr/bin/env bash
# Build every guide docs/guides/<lang>/*.md into a PDF beside it, in Docker (Chromium from the
# Playwright image, Markdown via a pinned `marked`, cached in a named volume after the first run).
# Takes no arguments.
set -euo pipefail

IMAGE="mcr.microsoft.com/playwright:v1.57.0-jammy"
MARKED="marked@12.0.2"
CACHE_VOLUME="claude-plugins-guides-npm"

if [ "$#" -ne 0 ]; then
  echo "usage: bash docs/guides/build.sh   (no arguments: builds every docs/guides/*/*.md)" >&2
  exit 2
fi

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"

docker run --rm \
  -v "$root":/w \
  -v "$CACHE_VOLUME":/cache \
  -w /w \
  -e MARKED="$MARKED" \
  "$IMAGE" bash -c '
set -euo pipefail
if [ ! -f /cache/.installed ] || [ "$(cat /cache/.installed)" != "$MARKED" ]; then
  npm install --silent --no-audit --no-fund --prefix /cache "$MARKED" >/dev/null
  printf "%s" "$MARKED" > /cache/.installed
fi
# Chromium varies per print: CreationDate/ModDate and the node ids of the accessibility tags. Mask both.
unstable() { LC_ALL=C sed -E -e "s/D:[0-9]{14}[^)]*\)/D:)/g" -e "s/node[0-9]{8}/node/g" "$1"; }
chrome="$(ls -d /ms-playwright/chromium-*/chrome-linux/chrome | head -n 1)"
tmp="$(mktemp -d)"
found=0
for md in docs/guides/*/*.md; do
  [ -f "$md" ] || continue
  case "$(basename "$md")" in _index.md) continue ;; esac
  found=1
  dir="$(dirname "$md")"
  name="$(basename "$md" .md)"
  html="$tmp/$name.html"
  node docs/guides/render.mjs "$md" "$html" docs/guides/guide.css "file:///w/$dir/"
  "$chrome" --headless --no-sandbox --disable-gpu --no-pdf-header-footer \
    --print-to-pdf="$tmp/$name.pdf" "file://$html" 2>/dev/null
  # An unchanged guide is never rewritten.
  if [ -f "$dir/$name.pdf" ] && cmp -s <(unstable "$tmp/$name.pdf") <(unstable "$dir/$name.pdf"); then
    echo "unchanged: $dir/$name.pdf"
  else
    mv "$tmp/$name.pdf" "$dir/$name.pdf"
    echo "built: $dir/$name.pdf"
  fi
done
[ "$found" -eq 1 ] || { echo "no guides found under docs/guides/*/" >&2; exit 1; }
rm -rf "$tmp"
'
