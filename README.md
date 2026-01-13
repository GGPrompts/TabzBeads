# TabzBeads - Plugin Marketplace for Claude Code

A collection of plugins for development workflows, browser automation, and multi-session orchestration.

## Features

- **Prefix taxonomy**: `bd-` (user commands), `bdc-` (conductor skills), `bdw-` (worker skills)
- **Beads integration**: AI-native issue tracking with `bd` CLI
- **Multi-session orchestration**: Spawn parallel workers via TabzChrome
- **Auto-discovered skills**: Commands in `commands/`, internal skills in `skills/`

## Quick Start

```bash
# User entry points (commands)
/conductor:bd-start [issue-id]  # Single-session: you do the work (no spawn)
/conductor:bd-plan              # Prepare backlog
/conductor:bd-conduct           # Interactive orchestration (1-4 workers)
/conductor:bd-auto              # Fully autonomous (all ready, no prompts)
/conductor:bd-status            # View issue state
/conductor:bd-new-project       # Project scaffolding
```

## Installation

```bash
./install.sh
```

## Documentation

- [Conductor Workflows](docs/conductor-workflows.md) - Complete workflow reference
- [CLAUDE.md](CLAUDE.md) - Project structure and patterns
