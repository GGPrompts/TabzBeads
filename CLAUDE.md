# CLAUDE.md - TabzBeads

## Overview

TabzBeads is a **Claude Code plugin marketplace** - a collection of plugins for development workflows, browser automation, and multi-session orchestration.

| | |
|--|--|
| **Type** | Plugin Marketplace (multiple plugins) |
| **Core Tool** | beads (bd) - AI-native issue tracking |
| **Key Command** | `/conductor:work` - unified workflow entry point |

---

## Plugin Structure (IMPORTANT)

This repo uses the **marketplace pattern** - one marketplace containing multiple plugins.

### Directory Layout

```
TabzBeads/
├── .claude-plugin/
│   └── marketplace.json         # Lists all plugins (ONLY file here)
├── plugins/
│   ├── conductor/               # Plugin: orchestration
│   │   ├── plugin.json          # Plugin manifest (at plugin root, NOT in .claude-plugin/)
│   │   ├── commands/            # Slash commands (.md files)
│   │   ├── agents/              # Subagents (.md files)
│   │   ├── skills/              # Skills (dirs with SKILL.md)
│   │   │   └── bd-conduct/
│   │   │       └── SKILL.md
│   │   └── scripts/             # Shell automation
│   ├── frontend/                # Plugin: frontend dev
│   │   ├── plugin.json
│   │   └── skills/
│   │       ├── ui-styling/
│   │       │   └── SKILL.md
│   │       └── web-frameworks/
│   │           └── SKILL.md
│   └── ...
└── CLAUDE.md
```

### Critical Rules

1. **Marketplace root has `.claude-plugin/marketplace.json`** - Lists all available plugins
2. **Each plugin has `plugin.json` at its root** - NOT in `.claude-plugin/` subfolder
3. **Skills are `skills/<name>/SKILL.md`** - One level deep, NOT nested skills inside skills
4. **Commands are `commands/<name>.md`** - Markdown files with optional frontmatter
5. **Agents are `agents/<name>.md`** - Markdown files with frontmatter

### marketplace.json Format

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "tabz-beads",
  "plugins": [
    {
      "name": "frontend",
      "description": "Frontend development skills",
      "source": "./plugins/frontend",
      "skills": ["./skills/ui-styling", "./skills/web-frameworks"]  // Explicit skill paths
    }
  ]
}
```

### Common Mistakes

| Mistake | Correct |
|---------|---------|
| `plugins/X/.claude-plugin/plugin.json` | `plugins/X/plugin.json` |
| `skills/parent/skills/child/SKILL.md` | `skills/child/SKILL.md` (flatten) |
| Missing `skills` array in marketplace.json | Add explicit skill paths |
| Individual `plugin.json` per skill | Only one `plugin.json` per plugin |

---

## Plugin Categories

| Plugin | Purpose |
|--------|---------|
| `conductor` | Multi-session orchestration, beads workflows |
| `tabz` | Browser automation (71 MCP tools) |
| `frontend` | React, TypeScript, Tailwind, shadcn/ui |
| `backend` | Node.js, Python, databases, DevOps |
| `visual` | Canvas, Gemini multimodal, FFmpeg |
| `docs` | PDF, Word, PowerPoint, Excel |
| `meta` | Plugin/skill creation, MCP builders |
| `tools` | Debugging, code review, problem solving |
| `tmux` | Terminal session management |
| `specialized` | Shopify, Bubble Tea, xterm.js |

---

## Conductor Plugin Architecture

The conductor plugin orchestrates multi-session Claude workflows:

```
plugins/conductor/
├── plugin.json
├── commands/                    # Atomic slash commands
│   ├── verify-build.md
│   ├── run-tests.md
│   ├── code-review.md
│   ├── commit-changes.md
│   ├── close-issue.md
│   └── worker-done.md
├── agents/                      # Spawnable subagents
│   ├── conductor.md             # Main orchestrator
│   ├── code-reviewer.md
│   └── ...
├── skills/
│   └── bd-conduct/              # Interactive orchestration
│       └── SKILL.md
└── scripts/                     # Shell automation
    └── setup-worktree.sh
```

---

## Development Goals

### Phase 1: Consolidation
- Merge `bd-work`, `bd-swarm`, `bd-swarm-auto` into unified `/conductor:work`
- Replace flags with AskUserQuestion interactive prompts
- Add guardrails for commonly missed steps

### Phase 2: Beads-Native Integration
- Use `bd worktree` instead of `git worktree`
- Track workers as agent beads with state machine
- Define workflow templates as molecules (protos)

### Phase 3: Token Efficiency
- Haiku explorers for backlog refinement via pmux
- Pre-baked prompts stored in beads issues
- Execution workers start with full context

---

## Key Patterns

### Unified Work Command
```
/conductor:work
  → AskUserQuestion: which issues?
  → AskUserQuestion: how many workers?
  → AskUserQuestion: which completion steps?
  → Execute based on configuration
```

### Completion Guardrails
```
/conductor:complete <issue-id>
  1. ALWAYS verify build
  2. Auto-detect standalone vs parallel mode
  3. If parallel: notify conductor, DON'T push
  4. If standalone: prompt for review + push
```

### Beads-Native Features to Use
- `bd worktree create` - auto-configures beads redirect
- `bd create --type agent` - track workers as agents
- `bd agent spawn/done` - state machine for workers
- `bd mol run` - spawn from workflow templates

---

## Commands Reference

| Command | Purpose |
|---------|---------|
| `/conductor:work` | Unified entry point (interactive) |
| `/conductor:refine` | Prepare backlog with Haiku explorers |
| `/conductor:complete` | Task completion with guardrails |
| `/conductor:verify-build` | Build verification |
| `/conductor:run-tests` | Test runner |
| `/conductor:code-review` | Opus code review |
| `/conductor:commit-changes` | Conventional commit |
| `/conductor:close-issue` | Close beads issue |

---

## Documentation

| Doc | Purpose |
|-----|---------|
| `docs/conductor-workflows.md` | Complete workflow reference + proposals |
| `docs/PRIME-template.md` | Template for project PRIME.md |

---

## Installation

```bash
# From TabzBeads directory
./install.sh

# Or manually copy to Claude plugins
cp -r plugins/* ~/.claude/plugins/
```
