---
name: docs-updater
description: "DEPRECATED - Use /conductor:bdw-update-docs skill instead. Kept for backwards compatibility."
model: haiku
---

# Docs Updater - DEPRECATED

**This agent is deprecated.** Use the `/conductor:bdw-update-docs` skill instead.

## Migration

| Old (agent) | New (skill) |
|-------------|-------------|
| `Task(subagent_type="conductor:docs-updater", ...)` | `/conductor:bdw-update-docs` |

## Why Deprecated?

The skill:
- Runs in forked context (no spawn overhead)
- Includes beads metadata verification
- Enforces anti-bloat rules
- Creates missing core docs (README.md, CHANGELOG.md, CLAUDE.md)
- Archives CHANGELOG.md at 500 lines

## If You're Here

Just run:
```
/conductor:bdw-update-docs [issue-id]
```
