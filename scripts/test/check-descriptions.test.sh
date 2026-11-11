#!/usr/bin/env bash
# Tests for scripts/check-descriptions.sh. Dual-target:
#   bash scripts/test/check-descriptions.test.sh
#   docker run --rm -v "$PWD":/w -w /w bash:5 bash scripts/test/check-descriptions.test.sh
set -uo pipefail
D="$(cd "$(dirname "$0")" && pwd -P)"
CHECK="$D/../check-descriptions.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; failn=0
ok()  { pass=$((pass + 1)); echo "  ok $1"; }
bad() { failn=$((failn + 1)); echo "  FAIL $1"; }

# fixture <dir> <market-desc> <market-ver> <pj-desc> <pj-ver>
fixture() {
  rm -rf "$1"; mkdir -p "$1/.claude-plugin" "$1/p1/.claude-plugin"
  printf '{\n  "name": "m",\n  "owner": {\n    "name": "Owner"\n  },\n  "plugins": [\n    {\n      "name": "p1",\n      "source": "./p1",\n      "description": "%s",\n      "version": "%s"\n    }\n  ]\n}\n' "$2" "$3" > "$1/.claude-plugin/marketplace.json"
  printf '{\n  "name": "p1",\n  "description": "%s",\n  "version": "%s",\n  "author": {\n    "name": "Owner"\n  }\n}\n' "$4" "$5" > "$1/p1/.claude-plugin/plugin.json"
}
run() { out="$(bash "$CHECK" "$1" 2>&1)"; code=$?; }

S='Short pitch — with a \"quote\" and an em dash.'
fixture "$T/a" "$S" 1.0.0 "$S" 1.0.0
run "$T/a"
[ "$code" -eq 0 ] && echo "$out" | grep -q 'descriptions ok: 1 plugins' && ok "in sync and short passes" || bad "in sync and short passes: $code $out"

# 250 em dashes: 750 bytes, 250 characters — the limit counts characters.
E=""; i=0; while [ $i -lt 250 ]; do E="${E}—"; i=$((i + 1)); done
fixture "$T/b" "$E" 1.0.0 "$E" 1.0.0
run "$T/b"
[ "$code" -eq 0 ] && ok "250 multibyte characters is at the limit" || bad "250 multibyte characters: $out"

L="$(printf 'x%.0s' $(seq 1 251))"
fixture "$T/c" "$L" 1.0.0 "$L" 1.0.0
run "$T/c"
[ "$code" -eq 1 ] && echo "$out" | grep -q 'FAIL p1: marketplace description is 251 characters' && ok "251 characters fails, names the plugin" || bad "251 characters: $code $out"

fixture "$T/d" "$S" 1.0.0 "Something else" 1.0.0
run "$T/d"
[ "$code" -eq 1 ] && echo "$out" | grep -q 'FAIL p1: plugin.json description differs' && ok "description mismatch fails" || bad "description mismatch: $code $out"

fixture "$T/e" "$S" 1.0.1 "$S" 1.0.0
run "$T/e"
[ "$code" -eq 1 ] && echo "$out" | grep -q 'FAIL p1: version: plugin.json 1.0.0, marketplace.json 1.0.1' && ok "version mismatch fails" || bad "version mismatch: $code $out"

mkdir -p "$T/f"
run "$T/f"
[ "$code" -eq 2 ] && ok "no marketplace.json is an error" || bad "no marketplace.json: $code $out"

# The repo itself.
run "$D/../.."
[ "$code" -eq 0 ] && ok "this repo passes" || bad "this repo: $out"

echo "check-descriptions: $pass passed, $failn failed"
[ "$failn" -eq 0 ]
