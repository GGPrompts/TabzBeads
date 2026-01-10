# Codex Skills

Skills for OpenAI Codex CLI that complement the Claude Code plugins.

## Installation

### Symlink (Recommended for Development)

Symlinks let you iterate on skills without reinstalling - edits take effect immediately.

```bash
# Ensure skills directory exists
mkdir -p ~/.codex/skills

# Idempotent symlink (replaces existing link/folder)
ln -sfn /home/marci/projects/TabzBeads/codex-skills/claudeforcodex ~/.codex/skills/claudeforcodex

# Verify installation
ls -la ~/.codex/skills/claudeforcodex  # Should show SKILL.md
```

**Note:** If Codex doesn't pick up new skills dynamically, restart your Codex CLI session.

### Copy (For Stable Installs)

```bash
mkdir -p ~/.codex/skills
cp -r /path/to/TabzBeads/codex-skills/claudeforcodex ~/.codex/skills/
```

### Project-Level

For project-specific skills, place in `.codex/skills/`:

```bash
mkdir -p .codex/skills
ln -sfn /path/to/TabzBeads/codex-skills/claudeforcodex .codex/skills/claudeforcodex
```

## Available Skills

| Skill | Description |
|-------|-------------|
| `claudeforcodex` | Claude Code CLI configuration guide - teaches Codex about Claude plugins, agents, skills, hooks, and MCP integration |

## Complementary Skills

These Codex skills are designed to work alongside the Claude Code plugins:

| Codex Skill | Claude Code Counterpart | Purpose |
|-------------|-------------------------|---------|
| `claudeforcodex` | `codexforclaude` | Cross-tool configuration knowledge |

## Usage

Once installed, Codex will auto-trigger skills based on context:

```
Codex> How do I configure Claude Code plugins?
# claudeforcodex skill activates automatically
```

Or reference explicitly:

```
Codex> Use $claudeforcodex to explain Claude Code hooks
```
