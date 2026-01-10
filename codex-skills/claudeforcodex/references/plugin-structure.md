# Claude Code Plugin Structure

Complete reference for building Claude Code plugins.

## Directory Layout

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json         # REQUIRED: Plugin manifest
├── commands/               # Slash commands
│   ├── command-one.md
│   └── command-two.md
├── agents/                 # Subagents for Task tool
│   ├── agent-one.md
│   └── agent-two.md
├── skills/                 # Auto-triggered knowledge
│   ├── skill-one/
│   │   ├── SKILL.md
│   │   └── references/
│   └── skill-two/
│       └── SKILL.md
├── hooks/
│   └── hooks.json          # Event hook definitions
├── scripts/                # Supporting scripts
│   └── helper.sh
├── .mcp.json               # MCP server definitions
└── README.md               # Documentation
```

## plugin.json (Required)

Minimal:
```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "What this plugin does"
}
```

Full:
```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "What this plugin does",
  "author": "Your Name",
  "homepage": "https://github.com/you/plugin",
  "keywords": ["keyword1", "keyword2"],
  "dependencies": {
    "other-plugin": "^1.0.0"
  }
}
```

## Command Files

`commands/my-command.md`:

```markdown
---
description: Brief autocomplete description (required)
---

# Command Title

Instructions for Claude when this command is invoked.

## Usage

Describe how to use the command.

## Steps

1. First step
2. Second step

## Examples

Show example usage.
```

**Invocation:** `/plugin:my-command` or `/my-command`

## Agent Files

`agents/my-agent.md`:

```markdown
---
name: my-agent
description: "Detailed description of agent capabilities and when to use"
model: opus|sonnet|haiku
tools: Bash, Read, Write, Edit, Glob, Grep, WebFetch, mcp:server:*
---

# Agent Title

You are a specialized agent for [purpose].

## Capabilities

- Capability 1
- Capability 2

## Instructions

Detailed instructions for the agent...
```

**Frontmatter fields:**
- `name` (required) - Agent identifier
- `description` (required) - When to use this agent
- `model` (optional) - opus, sonnet, or haiku (default: sonnet)
- `tools` (optional) - Comma-separated tool list

**Tool options:**
- `Bash` - Shell commands
- `Read` - File reading
- `Write` - File writing
- `Edit` - File editing
- `Glob` - File pattern matching
- `Grep` - Content searching
- `WebFetch` - HTTP requests
- `WebSearch` - Web searches
- `mcp:server:*` - All tools from MCP server
- `mcp:server:tool` - Specific MCP tool

## Skill Directories

`skills/my-skill/SKILL.md`:

```markdown
---
name: my-skill
description: "Trigger conditions. Include keywords, contexts, scenarios."
---

# Skill Title

Core knowledge (500-1500 words recommended).

## Quick Reference

Essential information.

## Common Tasks

How to accomplish typical tasks.

## Reference Files

For detailed information:
- `references/topic-one.md`
- `references/topic-two.md`
```

**Structure:**
```
skills/my-skill/
├── SKILL.md              # Main content (always loaded)
├── references/           # Detailed docs (loaded on demand)
│   ├── advanced.md
│   └── api-reference.md
├── scripts/              # Helper scripts
│   └── validate.sh
└── assets/               # Templates, configs
    └── template.json
```

## hooks.json

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "/path/to/validate.sh"
      }]
    }],
    "PostToolUse": [{
      "matcher": "Write|Edit",
      "hooks": [{
        "type": "command",
        "command": "/path/to/lint.sh $FILE"
      }]
    }],
    "UserPromptSubmit": [{
      "hooks": [{
        "type": "command",
        "command": "/path/to/pre-process.sh"
      }]
    }]
  }
}
```

**Hook events:**
- `PreToolUse` - Before tool execution
- `PostToolUse` - After tool execution
- `UserPromptSubmit` - Before processing user input

**Variables:**
- `$FILE` - File path (for Write/Edit)
- `$TOOL` - Tool name
- `$CLAUDE_PLUGIN_ROOT` - Plugin directory

## .mcp.json

```json
{
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "@company/mcp-server"],
      "env": {
        "API_KEY": "${API_KEY}"
      },
      "cwd": "${CLAUDE_PLUGIN_ROOT}"
    }
  }
}
```

## Marketplace Bundle

For distributing multiple plugins:

```
my-marketplace/
├── .claude-plugin/
│   └── marketplace.json    # Lists all plugins (ONLY file here)
└── plugins/
    ├── plugin-one/
    │   ├── plugin.json     # AT PLUGIN ROOT (not .claude-plugin/)
    │   └── skills/
    │       └── skill-a/
    │           └── SKILL.md
    └── plugin-two/
        ├── plugin.json     # AT PLUGIN ROOT
        └── skills/
```

**Critical:** Marketplace plugins have `plugin.json` at their root, NOT inside `.claude-plugin/`.

`marketplace.json`:
```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "my-marketplace",
  "version": "1.0.0",
  "description": "Collection of plugins",
  "plugins": [
    {
      "name": "plugin-one",
      "description": "First plugin",
      "source": "./plugins/plugin-one",
      "category": "tools",
      "skills": [
        "./skills/skill-a",
        "./skills/skill-b"
      ]
    }
  ]
}
```

**Note:** The `skills` array explicitly lists skill paths for reliable discovery.

## Critical Rules

1. **Standalone plugins:** `plugin.json` in `.claude-plugin/`
2. **Marketplace plugins:** `plugin.json` at plugin root (NOT `.claude-plugin/`)
3. **Skills ONE level deep:** `skills/name/SKILL.md` - NO nesting
4. **No plugin.json per skill** - Only one per plugin
5. **Explicit skills array** in marketplace.json (recommended)

## Common Mistakes

| Mistake | Correct |
|---------|---------|
| `plugins/X/.claude-plugin/plugin.json` | `plugins/X/plugin.json` |
| `skills/parent/skills/child/SKILL.md` | `skills/child/SKILL.md` (flatten) |
| Missing `skills` array in marketplace.json | Add explicit skill paths |
| Individual `plugin.json` per skill | Only one `plugin.json` per plugin |

## Auditing Commands

```bash
# Find nested skills (should return 0)
find plugins -path "*/skills/*/skills/*" -name "SKILL.md"

# Find orphaned plugin.json in skill dirs (should return 0)
find plugins -path "*/skills/*/plugin.json" | wc -l

# Verify plugin.json at correct locations
find plugins -maxdepth 2 -name "plugin.json"
```

## Best Practices

1. **Keep SKILL.md lean** - Move details to references/
2. **Use descriptive triggers** - Skill descriptions determine activation
3. **Make scripts executable** - `chmod +x scripts/*.sh`
4. **Use relative paths** - All paths relative to plugin root
5. **Test with --debug** - `claude --debug` shows plugin loading
6. **Skills flat** - Never nest skills inside skills
