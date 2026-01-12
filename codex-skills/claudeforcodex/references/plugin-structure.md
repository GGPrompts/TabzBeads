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
description: Brief autocomplete description (<60 chars)
argument-hint: "[optional args]"
model: sonnet
allowed-tools:
  - Bash
  - Read
context: fork
hooks:
  PostToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh"
---

# Command Title

Instructions for Claude when this command is invoked.

## Usage

Describe how to use the command.

## Steps

1. First step
2. Second step
```

**Frontmatter fields:**
| Field | Required | Description |
|-------|----------|-------------|
| `description` | Yes | Help text (<60 chars) |
| `argument-hint` | No | Document expected arguments |
| `model` | No | Override model (opus/sonnet/haiku) |
| `allowed-tools` | No | Restrict tools (YAML list) |
| `context` | No | `fork` to run in forked sub-agent |
| `agent` | No | Agent type for execution |
| `hooks` | No | Command-scoped hooks |
| `disable-model-invocation` | No | Prevent SlashCommand tool |

**Dynamic arguments:**
- `$ARGUMENTS` - All arguments as string
- `$1`, `$2`, `$3` - Positional arguments
- `@$1` - Include file contents

**Invocation:** `/plugin:my-command` or `/my-command`

## Agent Files

`agents/my-agent.md`:

```markdown
---
name: my-agent
description: "Detailed description of agent capabilities and when to use"
model: sonnet
tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
skills:
  - skill-name
permissionMode: default
disallowedTools:
  - WebSearch
hooks:
  Stop:
    - hooks:
        - type: prompt
          prompt: "Verify work is complete."
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
| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Agent identifier (lowercase, hyphens) |
| `description` | Yes | When to use, include trigger phrases |
| `model` | No | opus/sonnet/haiku (default: inherit) |
| `tools` | No | YAML list of allowed tools (omit for all) |
| `skills` | No | Auto-load specific skills |
| `permissionMode` | No | default/acceptEdits/plan/bypassPermissions |
| `disallowedTools` | No | Explicitly block tools |
| `hooks` | No | Agent-scoped hooks (PreToolUse, PostToolUse, Stop) |

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
user-invocable: true
model: sonnet
context: fork
allowed-tools:
  - Read
  - Write
hooks:
  PostToolUse:
    - matcher: "Write"
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/validate.sh"
---

# Skill Title

Core knowledge (500-1500 words recommended).

## Quick Reference

Essential information.

## Reference Files

For detailed information:
- `references/topic-one.md`
- `references/topic-two.md`
```

**Frontmatter fields:**
| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Skill identifier (lowercase, hyphens) |
| `description` | Yes | Trigger phrases and usage context |
| `user-invocable` | No | Show in `/` menu (default: true) |
| `model` | No | Override model (opus/sonnet/haiku) |
| `context` | No | `fork` to run in forked sub-agent |
| `agent` | No | Agent type for execution |
| `allowed-tools` | No | Restrict available tools (YAML list) |
| `hooks` | No | Skill-scoped hooks |

**Key features:**
- **Hot-reload** (v2.1.0+): Skills reload without restart
- **Unified with commands** (v2.1.3+): Skills visible in `/` menu by default
- **Progress display**: Tool uses shown while skill executes

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
        "command": "${CLAUDE_PLUGIN_ROOT}/scripts/validate.sh",
        "timeout": 30000
      }]
    }],
    "PostToolUse": [{
      "matcher": "Write|Edit",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/scripts/lint.sh"
      }]
    }],
    "Stop": [{
      "hooks": [{
        "type": "prompt",
        "prompt": "Verify all tests pass before stopping.",
        "model": "haiku"
      }]
    }]
  }
}
```

**Hook events:**
| Event | When | Special Features |
|-------|------|------------------|
| `PreToolUse` | Before tool execution | Can modify `updatedInput`, return `ask` |
| `PostToolUse` | After tool execution | Access `tool_use_id` |
| `PermissionRequest` | Permission dialog | Can auto-approve/deny |
| `UserPromptSubmit` | User submits prompt | `additionalContext` output |
| `Notification` | Notifications sent | Supports `matcher` values |
| `Stop` | Claude attempts to stop | Prompt-based hooks supported |
| `SubagentStop` | Subagent stops | `agent_id`, `agent_transcript_path` |
| `SubagentStart` | Subagent starts | - |
| `SessionStart` | Session begins | `agent_type` if `--agent` used |
| `SessionEnd` | Session ends | `systemMessage` supported |
| `PreCompact` | Before history compacted | - |

**Hook types:**
- `command` - Execute shell scripts
- `prompt` - LLM-driven evaluation (can specify `model`)

**Hook configuration:**
- `matcher` - Tool/event pattern (regex, `*` wildcard)
- `timeout` - Timeout in ms (default: 10 minutes)
- `once: true` - Run only once per session
- `model` - Model for prompt-based hooks

**Variables:**
- `${CLAUDE_PLUGIN_ROOT}` - Plugin directory
- `$CLAUDE_PROJECT_DIR` - Project root

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
