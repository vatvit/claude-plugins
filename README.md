# Claude Plugins

A collection of plugins for [Claude Code](https://claude.ai/code).

## Plugins

| Plugin | Description |
|--------|-------------|
| [session-storage](session-storage/) | Session-scoped key-value storage with automatic cleanup |
| [docs-manager](docs-manager/) | Docs-as-product: auto-generated `_index.md` navigation, link checks, conventions |
| [crew](crew/) | Several Claude Code sessions on one working tree and branch without lost edits |

## Installation

From within Claude Code:

```shell
# 1. Add the marketplace
/plugin marketplace add vatvit/claude-plugins

# 2. Install a plugin
/plugin install session-storage@vatvit-plugins
```

Choose **User scope** to enable for all projects, or **Project scope** to share with collaborators.

See each plugin's README for detailed usage.

## License

MIT
