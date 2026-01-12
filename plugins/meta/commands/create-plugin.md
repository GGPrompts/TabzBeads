---
description: Guided end-to-end plugin creation workflow with component design, implementation, and validation
argument-hint: "[plugin description or name]"
---

# Plugin Creation Workflow

Guide the user through creating a complete, high-quality Claude Code plugin from initial concept to tested implementation.

## Core Principles

- **Ask clarifying questions** - Identify ambiguities before implementation
- **Load relevant skills** - Use Skill tool to load meta skills when needed
- **Use specialized agents** - Leverage plugin-validator, skill-reviewer, agent-creator agents
- **Follow marketplace patterns** - Use correct directory structure for your context
- **Progressive disclosure** - Create lean skills with references/ for details
- **Use TodoWrite** - Track progress throughout all phases

**Initial request:** $ARGUMENTS

---

## Phase 1: Discovery

**Goal**: Understand what plugin needs to be built

**Actions**:
1. Create todo list with all 8 phases
2. If plugin purpose is clear from arguments, summarize understanding
3. If unclear, ask:
   - What problem does this plugin solve?
   - Who will use it and when?
   - Any similar plugins to reference?
4. Determine context:
   - **Marketplace plugin** - Adding to existing marketplace (like TabzBeads)
   - **Standalone plugin** - Entire repo IS one plugin
5. Confirm understanding with user

**Output**: Clear statement of plugin purpose and deployment context

---

## Phase 2: Component Planning

**Goal**: Determine what plugin components are needed

Load the `plugin-development` skill first:
```
Skill(skill: "meta:plugin-development")
```

**Actions**:
1. Analyze requirements for each component type:

| Component | When Needed | Examples |
|-----------|-------------|----------|
| **Skills** | Specialized knowledge, workflows | PDF handling, API patterns |
| **Commands** | User-initiated actions | `/deploy`, `/validate` |
| **Agents** | Autonomous tasks | validation, generation |
| **Hooks** | Event-driven automation | lint on save, format on edit |
| **MCP Servers** | External integrations | databases, APIs |

2. Present component plan as table
3. Get user confirmation

**Output**: Confirmed list of components to create

---

## Phase 3: Detailed Design

**Goal**: Specify each component and resolve ambiguities

**CRITICAL**: Do NOT skip this phase.

**Actions**:
1. For each component, identify underspecified aspects:

| Component | Key Questions |
|-----------|---------------|
| Skills | What triggers it? How detailed? Scripts needed? |
| Commands | What arguments? Interactive or automated? |
| Agents | Proactive or reactive? What tools? Output format? |
| Hooks | Which events? Prompt or command based? |
| MCP | Authentication? Which operations? |

2. Present questions organized by component
3. Wait for user answers before implementation

**Output**: Detailed specification for each component

---

## Phase 4: Plugin Structure Creation

**Goal**: Create plugin directory structure and manifest

**Actions**:

### For Marketplace Plugins (adding to existing marketplace)

```bash
# Create plugin directory (NO .claude-plugin/ inside!)
mkdir -p plugins/my-plugin/{commands,agents,skills,hooks,scripts}

# Create plugin.json AT PLUGIN ROOT
cat > plugins/my-plugin/plugin.json << 'EOF'
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "What this plugin does"
}
EOF
```

**Critical**: For marketplace plugins, `plugin.json` goes at plugin root, NOT in `.claude-plugin/`.

### For Standalone Plugins (repo IS the plugin)

```bash
# Create structure with .claude-plugin/ at repo root
mkdir -p .claude-plugin
mkdir -p {commands,agents,skills,hooks,scripts}

# Create plugin.json in .claude-plugin/
cat > .claude-plugin/plugin.json << 'EOF'
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "What this plugin does"
}
EOF
```

### Directory Structure Reference

```
# Marketplace plugin (inside existing marketplace)
plugins/my-plugin/
├── plugin.json           # AT ROOT - not in .claude-plugin/!
├── commands/
│   └── command-name.md
├── agents/
│   └── agent-name.md
├── skills/
│   └── skill-name/       # ONE level deep only
│       └── SKILL.md
├── hooks/
│   └── hooks.json
└── scripts/

# Standalone plugin (repo = plugin)
my-plugin/
├── .claude-plugin/
│   └── plugin.json       # In .claude-plugin/ for standalone
├── commands/
├── agents/
├── skills/
├── hooks/
└── scripts/
```

**Output**: Plugin directory structure created

---

## Phase 5: Component Implementation

**Goal**: Create each component following best practices

### Skills Implementation

1. Load skill-creator skill: `Skill(skill: "meta:skill-creator")`
2. For each skill:
   - Create `skills/skill-name/SKILL.md`
   - Add YAML frontmatter with `name:` and `description:`
   - Write lean body (<200 lines, imperative form)
   - Create `references/` for detailed content
   - Create `scripts/` for utilities

**SKILL.md Template**:
```markdown
---
name: skill-name
description: "This skill should be used when [specific triggers]. Use when users say '[example phrases]'."
---

# Skill Name

Brief overview.

## When to Use
- Specific trigger condition 1
- Specific trigger condition 2

## Core Instructions
[Lean, imperative instructions]

## Resources
- `references/detailed-guide.md` - Full documentation
- `scripts/utility.sh` - Helper script
```

**Critical**: Skills must be ONE level deep. Never nest `skills/` inside `skills/`.

### Commands Implementation

Create `commands/command-name.md`:
```markdown
---
description: Brief description for autocomplete (<60 chars)
argument-hint: "[optional args]"
---

# Command Name

Instructions FOR Claude (not TO user).

## Actions
1. Step one
2. Step two

## Arguments
- `$ARGUMENTS` - All arguments as string
- `$1`, `$2` - Positional arguments
```

**Key**: Commands are instructions for Claude, written in imperative form.

### Agents Implementation

1. Use agent-creator agent: `Task(subagent_type: "agent-creator", prompt: "Create an agent for...")`
2. Or create manually in `agents/agent-name.md`:

```markdown
---
name: agent-name
description: "Use this agent when [specific triggers]. Invoke with phrases like '[examples]'."
model: sonnet
tools:
  - Read
  - Grep
  - Glob
---

# Agent Name

System prompt defining agent behavior.

## Capabilities
- What this agent can do

## Guidelines
- How to approach tasks

## Output Format
- Expected output structure
```

### Hooks Implementation

Create `hooks/hooks.json`:
```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Write|Edit",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/scripts/lint.sh"
      }]
    }]
  }
}
```

**Available Events**: `PreToolUse`, `PostToolUse`, `Stop`, `SubagentStop`, `UserPromptSubmit`, `SessionStart`, `SessionEnd`, `PreCompact`, `Notification`

**Critical**: Use `${CLAUDE_PLUGIN_ROOT}` for portable paths.

### MCP Servers Implementation

Create `.mcp.json`:
```json
{
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["@org/mcp-server"],
      "cwd": "${CLAUDE_PLUGIN_ROOT}"
    }
  }
}
```

**Output**: All components implemented

---

## Phase 6: Validation

**Goal**: Ensure plugin meets quality standards

**Actions**:

1. **Run plugin-validator agent**:
```
Task(subagent_type: "plugin-validator", prompt: "Validate plugin at plugins/my-plugin")
```

2. **For each skill, run skill-reviewer**:
```
Task(subagent_type: "skill-reviewer", prompt: "Review skill at plugins/my-plugin/skills/skill-name")
```

3. **Run verify-plugin command** (if in TabzBeads):
```bash
/meta:verify-plugin plugins/my-plugin
```

4. **Fix issues**:
   - Critical: Must fix before proceeding
   - Warnings: Should fix for quality

5. **Common issues to check**:

| Issue | Fix |
|-------|-----|
| `plugin.json` in wrong location | Move to plugin root (marketplace) or `.claude-plugin/` (standalone) |
| Nested skills | Flatten to `skills/name/SKILL.md` |
| Missing frontmatter | Add `---` block with required fields |
| Scripts not executable | Run `chmod +x script.sh` |
| Hardcoded paths | Use `${CLAUDE_PLUGIN_ROOT}` |

**Output**: Plugin validated, issues fixed

---

## Phase 7: Testing

**Goal**: Verify plugin works in Claude Code

**Actions**:

1. **Restart Claude Code** to load new plugin

2. **Test each component**:

| Component | How to Test |
|-----------|-------------|
| Skills | Ask questions with trigger phrases |
| Commands | Run `/plugin:command` |
| Agents | Use Task tool or trigger phrases |
| Hooks | Use `claude --debug` to see execution |
| MCP | Check `/mcp` for servers |

3. **Verification checklist**:
- [ ] Plugin appears in `/plugins` output
- [ ] Skills trigger on expected phrases
- [ ] Commands appear in autocomplete
- [ ] Agents invoke when triggered
- [ ] Hooks fire on events
- [ ] No errors in debug output

4. **Debug if needed**:
```bash
claude --debug
```

**Output**: Plugin tested and working

---

## Phase 8: Documentation

**Goal**: Finalize documentation for distribution

**Actions**:

1. **Create/update README.md**:
   - Overview and purpose
   - Installation instructions
   - Component list with descriptions
   - Usage examples
   - Configuration (if any)

2. **For marketplace plugins**, update marketplace.json:
```json
{
  "plugins": [
    {
      "name": "my-plugin",
      "description": "What it does",
      "source": "./plugins/my-plugin",
      "skills": ["./skills/skill-a", "./skills/skill-b"]
    }
  ]
}
```

3. **Add to .gitignore** (if settings used):
```
.claude/*.local.md
```

4. **Final summary**:
   - List all components created
   - Highlight key features
   - Suggest next steps

**Output**: Complete, documented plugin

---

## Quick Reference

### Skill Invocation Formats

| Scope | Format |
|-------|--------|
| Meta skills | `/meta:skill-name` |
| Plugin skills | `/plugin:skill-name` |
| Project skills | `/skill-name` |

### Component Locations

| Component | Location |
|-----------|----------|
| Skills | `skills/<name>/SKILL.md` |
| Commands | `commands/<name>.md` |
| Agents | `agents/<name>.md` |
| Hooks | `hooks/hooks.json` |
| MCP | `.mcp.json` |

### Available Agents

| Agent | Purpose |
|-------|---------|
| `plugin-validator` | Validate structure and manifests |
| `skill-reviewer` | Review skill quality |
| `agent-creator` | Create new agents |

### Common Mistakes to Avoid

| Mistake | Correct |
|---------|---------|
| `plugins/X/.claude-plugin/plugin.json` | `plugins/X/plugin.json` |
| `skills/parent/skills/child/` | `skills/child/` (flatten) |
| Hardcoded `/home/user/...` paths | `${CLAUDE_PLUGIN_ROOT}/...` |
| Commands TO user | Commands FOR Claude |
| Vague skill descriptions | Specific trigger phrases |

---

**Begin with Phase 1: Discovery**
