#!/usr/bin/env bash
# build.sh — rebuild the committed OOXML fixtures from their XML under src/.
#
#   src/report.docx/word/document.xml  ->  report.docx
#
# The built files are committed because the container target (busybox) has `unzip` but no
# `zip`, so the suite cannot build them itself. Run this after editing anything under src/,
# on any machine with `zip` (macOS ships it), and commit both.
set -euo pipefail

cd "$(dirname "$0")"
command -v zip >/dev/null 2>&1 || { echo "build.sh needs zip" >&2; exit 1; }
for d in src/*; do
  out="$(basename "$d")"
  rm -f "$out"
  (cd "$d" && zip -q -X -r "../../$out" .)
  echo "BUILT: $out"
done
