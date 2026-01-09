# CLAUDE.md - TabzBeads

## Overview

TabzBeads is a **Claude Code plugin collection** for orchestrating multi-session development workflows using beads issue tracking.

| | |
|--|--|
| **Purpose** | Conductor plugin for parallel Claude worker orchestration |
| **Core Tool** | beads (bd) - AI-native issue tracking |
| **Key Command** | `/conductor:work` - unified workflow entry point |

---

## Architecture

```
plugins/
├── conductor/                   # Main orchestration plugin
│   ├── agents/                  # Spawnable subagents
│   │   ├── code-reviewer.md
│   │   ├── conductor.md
│   │   ├── tabz-manager.md
│   │   └── ...
│   ├── skills/
│   │   ├── work/                # Unified entry point (NEW)
│   │   ├── refine/              # Backlog refinement (NEW)
│   │   ├── complete/            # Task completion
│   │   └── ...
│   ├── commands/                # Atomic slash commands
│   │   ├── verify-build.md
│   │   ├── run-tests.md
│   │   ├── code-review.md
│   │   └── ...
│   └── scripts/                 # Shell automation
│       ├── setup-worktree.sh
│       ├── monitor-workers.sh
│       └── ...
├── ctthandoff/                  # Handoff summary generator
└── page-reader/                 # Page capture + TTS
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
