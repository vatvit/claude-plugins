---
description: Set or clear a custom status line notation for this session
argument-hint: [set <text> | clear | get]
allowed-tools: [Bash, Read]
---

# Session Notation Command

Manage the status line notation for the current session.

The user invoked: `/notation $ARGUMENTS`

## Instructions

1. You must know your `session_id` (injected by the SessionStart hook at session start). If you don't have it, read `/tmp/claude-notations/.current_session` as a fallback.

2. Parse the arguments:
   - `set <text>` — Set the notation to `<text>`
   - `clear` — Remove the notation
   - `get` — Show the current notation
   - No arguments — Show the current notation

3. Run the appropriate command:
   ```bash
   # Set
   bash <PLUGIN_ROOT>/scripts/notation.sh set <session_id> <text>

   # Clear
   bash <PLUGIN_ROOT>/scripts/notation.sh clear <session_id>

   # Get
   bash <PLUGIN_ROOT>/scripts/notation.sh get <session_id>
   ```

4. Confirm the action to the user. The notation will appear in the status line after the next assistant message.

Replace `<PLUGIN_ROOT>` with the actual plugin installation path.
