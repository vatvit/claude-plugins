#!/usr/bin/env bash
# Tests for the user's own defaults (defaults.sh, and the user layer in plan.sh).
#
#   bash kickoff/scripts/test/defaults.test.sh
#   docker run --rm -v "$PWD":/w -w /w bash:5 bash kickoff/scripts/test/defaults.test.sh
set -uo pipefail
. "$(dirname "$0")/helpers.sh"

export HOME="$TMP/home"; mkdir -p "$HOME"; unset CLAUDE_CONFIG_DIR
d() { bash "$S/defaults.sh" "$@"; }
a() { bash "$S/answer.sh" --root "$P" "$@"; }
value() { bash "$S/plan.sh" "$P" 2>/dev/null | awk -F'\t' -v id="$1" '$2 == id { print $4 }'; }

echo "== the user layer =="
P=$(fresh p1)
check "1a without a file the questionnaire's default applies" "PoC / experiment" "$(value A3)"
d set A3 Game
check "1b the file is per account, under ~/.claude" "yes" "$([ -f "$HOME/.claude/kickoff.json" ] && echo yes || echo no)"
check "1c a user default wins over the ★" "Game" "$(value A3)"
check "1d list shows it" "A3	Game" "$(d list)"
a A3 "Library / plugin / tool"
check "1e an answer still wins over every default" "Library / plugin / tool" "$(value A3)"

echo "== conditional defaults =="
P=$(fresh p2); a A4 "A client's"
check "2a where the file is silent, the (★ if …) still applies" "Outside the repo" "$(value R6)"
d set R6 'In the repo, `tasks/`'
check "2b a user default wins over a conditional one" 'In the repo, `tasks/`' "$(value R6)"
d unset R6
check "2c unset brings the conditional back" "Outside the repo" "$(value R6)"

echo "== two accounts =="
P=$(fresh p3)
CLAUDE_CONFIG_DIR="$HOME/work" d set A4 "My employer's"
check "3a the work account gets its own default" "My employer's" "$(CLAUDE_CONFIG_DIR="$HOME/work" value A4)"
check "3b the other account does not" "*derived from the git remote owner*" "$(value A4)"
check "3c the work file lives in its config dir" "yes" "$([ -f "$HOME/work/kickoff.json" ] && echo yes || echo no)"

echo "== the file itself =="
d set B1 'Ship a "real" thing \ fast'
check "4a quotes and backslashes round-trip" 'Ship a "real" thing \ fast' "$(P=$(fresh p4); value B1)"
check "4b the file stays one entry per line" "yes" "$(grep -q '^  "B1": "Ship a \\"real\\" thing \\\\ fast"' "$HOME/.claude/kickoff.json" && echo yes || echo no)"
d set Z9 x 2>/dev/null; check "4c an unknown id is refused" "2" "$?"
printf '{}\n' > "$HOME/.claude/kickoff.json"
P=$(fresh p5)
check "4d a file with no keys is fine (the pipefail trap)" "PoC / experiment" "$(value A3)"
printf '{\n  "comment": "mine",\n  "A3": "Game",\n  "Z9": "nope"\n}\n' > "$HOME/.claude/kickoff.json"
err=$(bash "$S/plan.sh" "$P" 2>&1 >/dev/null)
check "4e other keys are ignored" "Game" "$(value A3)"
check "4f an id that is not a question is reported, not fatal" "yes" "$(has 'Z9, which is not a question' "$err")"
rm -f "$HOME/.claude/kickoff.json"; d unset A3; check "4g unset with no file is fine" "0" "$?"

summary
