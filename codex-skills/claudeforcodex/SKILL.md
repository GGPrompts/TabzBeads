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

Claude Code extends via plugins containing:

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json      # Required manifest
├── commands/            # Slash commands (/name)
│   └── my-command.md
├── agents/              # Subagents (--agent name)
│   └── my-agent.md
├── skills/              # Auto-loaded knowledge
│   └── my-skill/
│       └── SKILL.md
├── hooks/               # Event hooks
│   └── hooks.json
└── .mcp.json            # MCP server definitions
```

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

## Reference Files

- `references/plugin-structure.md` - Complete plugin layout
- `references/permissions.md` - Permission system deep dive
- `references/hooks.md` - Hook configuration guide
- `references/mcp-integration.md` - MCP server setup
