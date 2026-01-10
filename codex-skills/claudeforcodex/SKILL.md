---
name: claudeforcodex
description: "Claude Code CLI configuration guide for Codex. Use when users ask about: claude code config, ~/.claude/settings.json, claude plugins, claude agents, claude skills, claude hooks, claude mcp servers, or integrating tools with Claude Code."
---

# Claude Code CLI Configuration Guide

Configure and extend Anthropic's Claude Code CLI for optimal development workflows.

## Quick Reference

| Task | Command/Location |
|------|------------------|
| Config file | `~/.claude/settings.json` |
| Project config | `.claude/settings.json` (in project root) |
| Plugins | `~/.claude/plugins/` or marketplace |
| Add MCP server | Edit `.mcp.json` or plugin |
| Skills location | Plugin `skills/` directories |

## Core Configuration

Edit `~/.claude/settings.json` for global settings:

```json
{
  "permissions": {
    "allow": ["Bash(*)", "Read(*)", "Write(*)"],
    "deny": []
  },
  "env": {
    "ANTHROPIC_API_KEY": "sk-..."
  }
}
```

**Project-level:** Create `.claude/settings.json` in project root to override.

## Permission System

Claude Code uses explicit tool permissions:

```json
{
  "permissions": {
    "allow": [
      "Bash(*)",           // All bash commands
      "Read(*)",           // All file reads
      "Write(~/projects/*)", // Write only in projects
      "mcp:server_name:*"  // All tools from MCP server
    ],
    "deny": [
      "Bash(rm -rf *)"     // Block dangerous commands
    ]
  }
}
```

**Permission patterns:**
- `Tool(*)` - Allow all uses of tool
- `Tool(/path/*)` - Allow with path prefix
- `mcp:server:tool` - Specific MCP tool

## Plugin System

Claude Code has two plugin patterns:

### Standalone Plugin (entire repo = one plugin)

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json      # Required for standalone
├── commands/
├── agents/
├── skills/
│   └── my-skill/
│       └── SKILL.md     # ONE level deep only!
├── hooks/
└── .mcp.json
```

### Marketplace Plugin (repo contains multiple plugins)

```
my-marketplace/
├── .claude-plugin/
│   └── marketplace.json     # Lists all plugins
└── plugins/
    ├── plugin-a/
    │   ├── plugin.json      # AT ROOT (not .claude-plugin/)
    │   └── skills/
    │       └── skill-name/
    │           └── SKILL.md
    └── plugin-b/
        └── plugin.json
```

**Critical Rules:**
1. **Marketplace plugins:** `plugin.json` at plugin root, NOT in `.claude-plugin/`
2. **Skills ONE level deep:** `skills/name/SKILL.md` - NO `skills/a/skills/b/`
3. **No plugin.json per skill** - only one per plugin
4. **Explicit skills array** in marketplace.json (recommended)

**Install plugin:**
```bash
claude plugins add /path/to/plugin
claude plugins add https://github.com/user/plugin
```

## Commands (Slash Commands)

Create `commands/name.md`:

```markdown
---
description: Brief description for autocomplete
---

# Command Name

Instructions Claude follows when user types /name
```

**Invoke:** `/plugin-name:command-name` or `/command-name`

## Agents (Subagents)

Create `agents/name.md`:

```markdown
---
name: agent-name
description: What this agent specializes in
model: opus|sonnet|haiku
tools: Bash, Read, Write, Edit, Glob, Grep
---

# Agent Name

System prompt and instructions for the agent.
```

**Invoke:** `claude --agent plugin-name:agent-name`

**Spawn from Claude:**
```
Task(subagent_type="plugin:agent", prompt="Do something")
```

## Skills (Auto-Knowledge)

Create `skills/name/SKILL.md`:

```markdown
---
name: skill-name
description: "When to trigger this skill. Be specific about keywords and contexts."
---

# Skill Name

Knowledge and instructions loaded when skill triggers.
```

**Critical:** Skills must be **ONE level deep**:
```
skills/
├── skill-a/          # ✅ Correct
│   └── SKILL.md
└── skill-b/          # ✅ Correct
    └── SKILL.md

# ❌ WRONG - nested skills won't be discovered:
skills/
└── parent/
    └── skills/       # Nesting breaks discovery!
        └── child/
            └── SKILL.md
```

**Note:** Skills auto-load based on conversation context matching the description.

## Hooks (Event Handlers)

Create `hooks/hooks.json`:

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Write|Edit",
      "hooks": [{
        "type": "command",
        "command": "/path/to/script.sh $FILE"
      }]
    }],
    "UserPromptSubmit": [{
      "hooks": [{
        "type": "command",
        "command": "/path/to/pre-prompt.sh"
      }]
    }]
  }
}
```

**Hook types:**
- `PreToolUse` - Before tool execution
- `PostToolUse` - After tool execution
- `UserPromptSubmit` - Before processing user message

## MCP Server Integration

Create `.mcp.json` in plugin or project root:

```json
{
  "mcpServers": {
    "my-server": {
      "command": "npx",
      "args": ["-y", "@company/mcp-server"],
      "env": {
        "API_KEY": "xxx"
      }
    }
  }
}
```

**Use MCP tools:**
```bash
mcp-cli tools                    # List all MCP tools
mcp-cli info server/tool         # Get tool schema
mcp-cli call server/tool '{}'    # Call tool
```

## Claude Code vs Codex

| Aspect | Claude Code | Codex |
|--------|-------------|-------|
| Provider | Anthropic | OpenAI |
| Config | `~/.claude/settings.json` | `~/.codex/config.toml` |
| Plugins | Full plugin system | Skills only |
| Skills | Plugin-based | `~/.codex/skills/` |
| Agents | Plugin agents | N/A |
| Hooks | Plugin hooks | N/A |
| MCP | `.mcp.json` or plugin | `config.toml` sections |
| Permissions | JSON allow/deny | Sandbox modes |

## Common Workflows

### Run with Full Permissions
```bash
claude --dangerously-skip-permissions
```

### Use Specific Agent
```bash
claude --agent conductor:code-reviewer
```

### Install Marketplace Plugin
```bash
claude plugins add marketplace-name
```

### Debug Plugin Loading
```bash
claude --debug
```

## Auditing Plugin Structure

When auditing a Claude Code plugin/marketplace for issues:

```bash
# Find all SKILL.md files
find plugins -name "SKILL.md" | sort

# Find nested skills (WRONG structure)
find plugins -path "*/skills/*/skills/*" -name "SKILL.md"

# Find all plugin.json files
find plugins -name "plugin.json" | sort

# Find orphaned plugin.json in skill dirs (should be 0)
find plugins -path "*/skills/*/plugin.json" | wc -l

# Check marketplace.json has skills arrays
cat .claude-plugin/marketplace.json | jq '.plugins[].skills'
```

**Common Issues:**
| Issue | Symptom | Fix |
|-------|---------|-----|
| Nested skills | Skills not loading | Flatten to `skills/name/SKILL.md` |
| plugin.json in skill dirs | Confusion | Remove, only one per plugin |
| Missing skills array | Skills not discovered | Add to marketplace.json |
| Wrong plugin.json location | Plugin not loading | Move to plugin root |

## Reference Files

- `references/plugin-structure.md` - Complete plugin layout
