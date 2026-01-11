# CLAUDE.md - TabzBeads

## Overview

TabzBeads is a **Claude Code plugin marketplace** - a collection of plugins for development workflows, browser automation, and multi-session orchestration.

| | |
|--|--|
| **Type** | Plugin Marketplace (multiple plugins) |
| **Core Tool** | beads (bd) - AI-native issue tracking |
| **Key Command** | `/conductor:bd-work` - single-session workflow entry point |

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
├── commands/                    # Slash commands with prefix taxonomy
│   ├── bd-*.md                  # User entry points (bd-work, bd-plan, bd-swarm, bd-status)
│   ├── bdc-*.md                 # Conductor internal (bdc-swarm-auto, bdc-wave-done)
│   └── bdw-*.md                 # Worker steps (bdw-verify-build, bdw-commit-changes)
├── agents/                      # Spawnable subagents
│   ├── conductor.md             # Main orchestrator
│   ├── code-reviewer.md         # Autonomous code review
│   ├── docs-updater.md          # Update documentation
│   ├── skill-picker.md          # Find skills for issues
│   └── prompt-enhancer.md       # Optimize prompts
├── skills/
│   ├── bd-conduct/              # Interactive orchestration
│   ├── bd-swarm-auto/           # Autonomous swarm execution
│   ├── code-review/             # Code review patterns
│   ├── new-project/             # Project scaffolding
│   ├── orchestration/           # Multi-session coordination
│   ├── tabz-artist/             # Visual asset generation
│   ├── tabz-mcp/                # Browser automation
│   ├── terminal-tools/          # TUI tool control
│   ├── wave-done/               # Wave completion
│   └── worker-done/             # Worker completion
└── scripts/                     # Shell automation
    ├── setup-worktree.sh        # Git worktree creation
    ├── match-skills.sh          # Issue-to-skill matching
    ├── lookahead-enhancer.sh    # Parallel prompt preparation
    ├── completion-pipeline.sh   # Automated wave completion
    ├── wave-summary.sh          # Generate wave summaries
    ├── capture-session.sh       # Capture session transcripts
    └── discover-skills.sh       # Runtime skill discovery
```

---

## Development Goals

### Phase 1: Consolidation ✅
- Prefix-based taxonomy: `bd-` (user), `bdc-` (conductor), `bdw-` (worker)
- User entry points: bd-work, bd-plan, bd-swarm, bd-status
- Internal steps clearly namespaced (no hiding needed during testing)

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

### Prefix Taxonomy
```
bd-*    = User entry points (visible in menu)
bdc-*   = Conductor internal (orchestration)
bdw-*   = Worker internal (execution steps)
```

### Skill Invocation Formats

Skills use different invocation formats depending on their scope:

| Scope | Format | Example |
|-------|--------|---------|
| Conductor skills | `/conductor:skill-name` | `/conductor:tabz-mcp` |
| Plugin skills | `/plugin-name:skill-name` | `/frontend:ui-styling` |
| Project skills | `/skill-name` | `/tabz-guide` |

When matching skills to issues (via `match-skills.sh`), the script outputs explicit invocation commands that workers can use directly.

### Completion Pipeline
```
/conductor:bdw-worker-done <issue-id>
  1. bdw-verify-build
  2. bdw-run-tests (if available)
  3. bdw-commit-changes
  4. bdw-close-issue
```

### Beads-Native Features to Use
- `bd worktree create` - auto-configures beads redirect
- `bd create --type agent` - track workers as agents
- `bd agent spawn/done` - state machine for workers
- `bd mol pour/wisp` - spawn from workflow templates

### Molecule Templates

Reusable workflow templates are stored in `.beads/formulas/`:

| Formula | Purpose |
|---------|---------|
| `conductor-wave` | Complete wave lifecycle (setup → execute → complete) |

```bash
# List available formulas
bd formula list

# Show formula details
bd formula show conductor-wave

# Instantiate as ephemeral wisp (recommended)
bd mol wisp conductor-wave --var issues="TabzBeads-abc TabzBeads-def"

# Instantiate as persistent pour (for audit trail)
bd mol pour conductor-wave --var issues="TabzBeads-abc TabzBeads-def"

# Or use the command
/conductor:bdc-run-wave TabzBeads-abc TabzBeads-def
```

---

## Commands Reference

### User Entry Points (bd-)
| Command | Purpose |
|---------|---------|
| `/conductor:bd-work` | Single-session: you implement an issue |
| `/conductor:bd-plan` | Prepare backlog: refine, enhance, match skills |
| `/conductor:bd-swarm` | Multi-session: spawn parallel workers |
| `/conductor:bd-status` | View issue state (open, blocked, ready) |

### Conductor Internal (bdc-)
| Command | Purpose |
|---------|---------|
| `/conductor:bdc-swarm-auto` | Autonomous waves until backlog empty |
| `/conductor:bdc-wave-done` | Merge branches, unified review, cleanup |
| `/conductor:bdc-run-wave` | Run wave from conductor-wave template |
| `/conductor:bdc-orchestration` | Multi-session coordination |
| `/conductor:bdc-analyze-transcripts` | Review worker session transcripts |

### Worker Internal (bdw-)
| Command | Purpose |
|---------|---------|
| `/conductor:bdw-verify-build` | Run build, report errors |
| `/conductor:bdw-run-tests` | Run tests if available |
| `/conductor:bdw-code-review` | Opus review with auto-fix |
| `/conductor:bdw-codex-review` | Cost-effective Codex review (read-only) |
| `/conductor:bdw-commit-changes` | Stage + commit |
| `/conductor:bdw-close-issue` | Close beads issue |
| `/conductor:bdw-create-followups` | Create follow-up beads issues |
| `/conductor:bdw-update-docs` | Check and update documentation |
| `/conductor:bdw-worker-init` | Initialize worker context |
| `/conductor:bdw-worker-done` | Full completion pipeline |

### Additional Commands
| Command | Purpose |
|---------|---------|
| `/conductor:new-project` | Multi-phase project scaffolding |
| `/conductor:tabz-artist` | Generate images via DALL-E and videos via Sora |
| `/conductor:tabz-mcp` | Browser automation MCP tool discovery |
| `/conductor:terminal-tools` | Reference for tmux and TUI tool control |

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
