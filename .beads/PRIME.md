# Beads Workflow Context

> **Context Recovery**: Run `bd prime` after compaction, clear, or new session
> Hooks auto-call this in Claude Code when .beads/ detected

## Prefer MCP Over CLI

**FIRST: Set workspace context** (required for MCP to know which project):
```bash
mcp-cli call beads/context '{"action": "set", "workspace_root": "'$(pwd)'"}'
```

**Then use beads MCP tools instead of `bd` CLI:**

```bash
# Preferred: MCP (structured JSON, better integration)
mcp-cli call beads/ready '{"limit": 5}'
mcp-cli call beads/create '{"title": "...", "type": "task", "priority": 2}'
mcp-cli call beads/close '{"issue_id": "TabzBeads-xxx", "reason": "..."}'

# Fallback: CLI (if MCP unavailable)
bd ready
bd create --title="..." --type=task --priority=2
bd close TabzBeads-xxx --reason="..."
```

**Available MCP tools:** `beads/ready`, `beads/list`, `beads/show`, `beads/create`, `beads/update`, `beads/close`, `beads/reopen`, `beads/dep`, `beads/stats`, `beads/blocked`

**Check MCP availability:** `mcp-cli tools beads`

# 🚨 SESSION CLOSE PROTOCOL 🚨

**CRITICAL**: Before saying "done" or "complete", run the appropriate completion pipeline.

## Standalone Work (single session, you're the only one working)

### Standard Completion (with code review)
```bash
/conductor:bdw-verify-build      # Build and check for errors
/conductor:bdw-run-tests         # Run tests if available
/conductor:bdw-code-review       # Opus review with auto-fix (high confidence)
/conductor:bdw-commit-changes    # Stage + commit with conventional format
/conductor:bdw-close-issue <id>  # Close the beads issue
bd sync && git push              # Push everything
```

### Quick Completion (skip review, for trivial changes)
```bash
/conductor:bdw-verify-build
/conductor:bdw-commit-changes
/conductor:bdw-close-issue <id>
bd sync && git push
```

### Cost-Effective Review (use Codex instead of Opus)
```bash
/conductor:bdw-verify-build
/conductor:bdw-codex-review      # Cheaper read-only review via OpenAI Codex
/conductor:bdw-commit-changes
/conductor:bdw-close-issue <id>
bd sync && git push
```

## BD-Conduct Worker (spawned by /conductor:bd-conduct)

If you were spawned by `/conductor:bd-conduct`, use worker-done and DO NOT push:
```bash
/conductor:bdw-worker-done <id>  # Runs: verify → test → commit → close → NOTIFY
# STOP HERE - conductor handles merge, review, and push
```

**Workers skip code review** - the conductor runs unified review after merging all branches.

**NEVER skip verification.** Standalone work is not done until pushed.

## Core Rules
- Track strategic work in beads (multi-session, dependencies, discovered work)
- Use `bd create` for issues, TodoWrite for simple single-session execution
- When in doubt, prefer bd—persistence you don't need beats lost context
- Git workflow: hooks auto-sync, run `bd sync` at session end
- Session management: check `bd ready` for available work

## Essential Commands

### Finding Work
- `bd ready` - Show issues ready to work (no blockers)
- `bd list --status=open` - All open issues
- `bd list --status=in_progress` - Your active work
- `bd show <id>` - Detailed issue view with dependencies

### Creating & Updating
- `bd create --title="..." --type=task|bug|feature --priority=2` - New issue
  - Priority: 0-4 or P0-P4 (0=critical, 2=medium, 4=backlog). NOT "high"/"medium"/"low"
- `bd update <id> --status=in_progress` - Claim work
- `bd update <id> --assignee=username` - Assign to someone
- `bd close <id>` - Mark complete
- `bd close <id1> <id2> ...` - Close multiple issues at once (more efficient)
- `bd close <id> --reason="explanation"` - Close with reason
- **Tip**: When creating multiple issues/tasks/epics, use parallel subagents for efficiency

### Dependencies & Blocking
- `bd dep add <issue> <depends-on>` - Add dependency (issue depends on depends-on)
- `bd blocked` - Show all blocked issues
- `bd show <id>` - See what's blocking/blocked by this issue

### Sync & Collaboration
- `bd sync` - Sync with git remote (run at session end)
- `bd sync --status` - Check sync status without syncing

### Project Health
- `bd stats` - Project statistics (open/closed/blocked counts)
- `bd doctor` - Check for issues (sync problems, missing hooks)

## Common Workflows

**Starting work:**
```bash
bd ready           # Find available work
bd show <id>       # Review issue details
bd update <id> --status=in_progress  # Claim it
```

**Completing work (standalone):**
```bash
# Full pipeline with review
/conductor:bdw-verify-build
/conductor:bdw-code-review
/conductor:bdw-commit-changes
/conductor:bdw-close-issue <id>
bd sync && git push

# Or use worker-done for quick path (skips review):
/conductor:bdw-worker-done <id>  # verify → test → commit → close
bd sync && git push
```

**Creating dependent work:**
```bash
# Run bd create commands in parallel (use subagents for many items)
bd create --title="Implement feature X" --type=feature
bd create --title="Write tests for X" --type=task
bd dep add beads-yyy beads-xxx  # Tests depend on Feature (Feature blocks tests)
```

## Conductor Commands - Prefix Taxonomy

Commands use prefixes to indicate their purpose:
- `bd-*` = User entry points (you invoke these)
- `bdc-*` = Conductor internal (orchestration)
- `bdw-*` = Worker steps (execution pipeline)

### User Entry Points (bd-)
| Command | Purpose |
|---------|---------|
| `/conductor:bd-plan` | Prepare backlog: refine, enhance prompts, match skills |
| `/conductor:bd-start` | YOU work directly on an issue (no spawn) |
| `/conductor:bd-status` | View issue state (open, blocked, ready) |
| `/conductor:bd-conduct` | Interactive orchestration: select issues, terminals (1-4), mode |
| `/conductor:bd-new-project` | Template-based project scaffolding |

### Conductor Internal (bdc-)
| Command | Purpose |
|---------|---------|
| `/conductor:bdc-swarm-auto` | Autonomous waves until backlog empty |
| `/conductor:bdc-wave-done` | Merge branches, unified review, cleanup |

### Worker Steps (bdw-)
| Command | Purpose |
|---------|---------|
| `/conductor:bdw-verify-build` | Run build and report errors |
| `/conductor:bdw-run-tests` | Run tests if available |
| `/conductor:bdw-code-review` | Opus code review with auto-fix |
| `/conductor:bdw-codex-review` | Cost-effective read-only review via OpenAI Codex |
| `/conductor:bdw-commit-changes` | Stage + commit with conventional format |
| `/conductor:bdw-close-issue` | Close a beads issue with completion reason |
| `/conductor:bdw-worker-done` | Full completion pipeline: verify → test → commit → close → notify |

## Terminal Communication (for workers)

When sending multi-line prompts or notifications via tmux, use `load-buffer` + `paste-buffer` to avoid terminal corruption:

```bash
# WRONG: Can trigger copy mode with special chars
tmux send-keys -t "$SESSION" -l "$LONG_PROMPT"

# RIGHT: Reliable for multi-line content
printf '%s' "$PROMPT" | tmux load-buffer -
tmux paste-buffer -t "$SESSION"
sleep 0.3
tmux send-keys -t "$SESSION" C-m
```

**Short one-liners** (like notifications) can still use `send-keys -l`:
```bash
tmux send-keys -t "$CONDUCTOR_SESSION" -l "DONE: issue-id"
sleep 0.5
tmux send-keys -t "$CONDUCTOR_SESSION" C-m
```

For full tmux patterns, see `/conductor:terminal-tools`.
