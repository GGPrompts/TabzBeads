# Conductor Plugin

Multi-session orchestration for Claude Code with beads-native issue tracking.

## Overview

The Conductor plugin enables parallel Claude Code workflows through:
- **Worker spawning** via TabzChrome terminals
- **Beads integration** for issue tracking and state management
- **Wave-based execution** for parallel task processing
- **Automated code review** and completion pipelines

## Installation

```bash
# Clone TabzBeads marketplace
git clone https://github.com/GGPrompts/TabzBeads.git

# Copy to Claude plugins
cp -r TabzBeads/plugins/conductor ~/.claude/plugins/
```

Or add to your `.claude/plugins/` symlink path.

## Commands

| Command | Purpose |
|---------|---------|
| `/conductor:bd-plan` | Prepare backlog: refine, enhance prompts, match skills |
| `/conductor:bd-start` | Work directly on an issue (no spawn) |
| `/conductor:bd-status` | View issue state (open, blocked, ready) |
| `/conductor:bd-conduct` | Interactive orchestration: select issues, terminals (1-4), mode |
| `/conductor:bd-new-project` | Template-based project scaffolding |

## Skills

### Conductor Internal (bdc-*)
- `bdc-orchestration` - Multi-session coordination
- `bdc-swarm-auto` - Autonomous waves until backlog empty
- `bdc-wave-done` - Merge branches, unified review, cleanup
- `bdc-visual-qa` - Visual QA between waves
- `bdc-run-wave` - Run wave from template
- `bdc-prompt-enhancer` - Enhance issue prompts with skills
- `bdc-analyze-transcripts` - Review worker session transcripts

### Worker Steps (bdw-*)
- `bdw-verify-build` - Run build and report errors
- `bdw-run-tests` - Run tests if available
- `bdw-code-review` - Opus code review with auto-fix
- `bdw-codex-review` - Cost-effective read-only review via OpenAI Codex
- `bdw-commit-changes` - Stage + commit with conventional format
- `bdw-close-issue` - Close a beads issue
- `bdw-create-followups` - Create follow-up beads issues
- `bdw-update-docs` - Update README, CHANGELOG, CLAUDE.md
- `bdw-worker-init` - Initialize worker context
- `bdw-worker-done` - Full completion pipeline

### Reference Skills
- `tabz-mcp` - Browser automation MCP reference (70 tools)
- `terminal-tools` - tmux and TUI tool control reference

## Agents

| Agent | Purpose |
|-------|---------|
| `conductor` | Main orchestrator for multi-session workflows |
| `code-reviewer` | Read-only Sonnet code review |
| `skill-picker` | Find and install skills from skillsmp.com |
| `silent-failure-hunter` | Error handling audit |

## Scripts

| Script | Purpose |
|--------|---------|
| `setup-worktree.sh` | Git worktree creation |
| `match-skills.sh` | Issue-to-skill matching |
| `lookahead-enhancer.sh` | Parallel prompt preparation |
| `completion-pipeline.sh` | Automated wave completion |
| `wave-summary.sh` | Generate wave summaries |
| `capture-session.sh` | Capture session transcripts |
| `discover-skills.sh` | Runtime skill discovery |

## Workflow Example

```bash
# 1. Check available work
bd ready

# 2. Start interactive orchestration
/conductor:bd-conduct

# 3. Select issues, terminal count, mode
# Workers spawn and execute in parallel

# 4. When workers complete, conductor merges and reviews
/conductor:bdc-wave-done V4V-abc V4V-def
```

## Requirements

- Claude Code with Task tool
- beads CLI (`bd`) for issue tracking
- TabzChrome for terminal spawning (optional)
- tmux for session management

## License

MIT License - see LICENSE file
