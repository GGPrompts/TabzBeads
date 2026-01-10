# TabzBeads - Plugin Marketplace for Claude Code

A collection of plugins for development workflows, browser automation, and multi-session orchestration.

## Features

- **Prefix taxonomy**: `bd-` (user), `bdc-` (conductor), `bdw-` (worker)
- **Beads integration**: AI-native issue tracking with `bd` CLI
- **Multi-session orchestration**: Spawn parallel workers via TabzChrome
- **10 conductor skills**: Synced from TabzChrome

## Quick Start

```bash
# User entry points
/conductor:bd-work [issue-id]   # Single-session: you do the work
/conductor:bd-plan              # Prepare backlog
/conductor:bd-swarm             # Spawn parallel workers
/conductor:bd-status            # View issue state
```

## Installation

```bash
./install.sh
```

## Documentation

- [Conductor Workflows](docs/conductor-workflows.md) - Complete workflow reference
- [CLAUDE.md](CLAUDE.md) - Project structure and patterns
