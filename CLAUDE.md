# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

## What This Is

A multi-plugin collection for Claude Code. Each plugin lives in its own sub-directory with its own CLAUDE.md, hooks, scripts, and skills.

## Repository Structure

```
claude-plugins/
├── .claude-plugin/
│   └── marketplace.json      ← marketplace registry (name: vatvit-plugins)
├── session-storage/           ← plugin: session-scoped key-value storage
│   ├── .claude-plugin/
│   │   └── plugin.json
│   ├── hooks/
│   ├── scripts/
│   ├── skills/
│   ├── CLAUDE.md              ← plugin-specific guidance
│   └── README.md              ← plugin-specific docs
├── CLAUDE.md                  ← this file (repo-level)
├── README.md                  ← repo-level overview
└── LICENSE
```

## Plugins

| Plugin | Directory | Description |
|--------|-----------|-------------|
| session-storage | `session-storage/` | Session-scoped key-value storage with auto-cleanup |
| docs-manager | `docs-manager/` | Docs-as-product: auto `_index.md` navigation, link checks, conventions |

## Adding a New Plugin

1. Create a new directory at root level (e.g., `my-plugin/`)
2. Add `.claude-plugin/plugin.json` inside it
3. Add entry to `.claude-plugin/marketplace.json` plugins array with `"source": "my-plugin"`
4. Add hooks, scripts, skills, CLAUDE.md, README.md as needed

## Working on a Specific Plugin

Refer to the plugin's own `CLAUDE.md` for architecture, conventions, and testing instructions.
