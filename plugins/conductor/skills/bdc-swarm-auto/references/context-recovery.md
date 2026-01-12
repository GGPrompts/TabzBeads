# Context Recovery - BD Swarm Auto

How to handle context limits during autonomous execution.

## Monitor Your Context

Your context percentage is visible in your status bar.

**During every poll cycle (Step 6), check your context:**
- **Below 70%:** Continue normally
- **At 70% or above:** IMMEDIATELY trigger restart

## Why /restart Instead of /wipe

`/wipe` uses `/clear` which does NOT re-trigger SessionStart hooks. After `/clear`:
- PRIME.md is NOT re-injected
- Beads workflow context is NOT re-injected
- Skill-eval hook still works, but you lose project context

`/restart` exits and restarts Claude entirely, which DOES trigger SessionStart hooks.

## How to Restart with Recovery

1. First, save current wave state:
```bash
# Note which issues are still in progress
bd list --status=in_progress --json | jq -r '.[].id'
```

2. Then invoke `/restart`:

```
/restart
```

This will:
1. Exit Claude Code
2. Restart with `--continue` flag
3. SessionStart hooks re-inject PRIME.md and beads context
4. You get fresh context with all hooks active

3. After restart, continue the swarm:

```
/conductor:bdc-swarm-auto
```

The skill will:
1. Check issue statuses (some may have closed during restart)
2. Resume polling for remaining in_progress issues
3. Merge and cleanup when done
4. Start next wave if more issues ready

**Beads tracks all state** - nothing is lost during restart.

**DO NOT wait until you run out of context.** Restart proactively at 70%.

## Troubleshooting

**Workers not responding:**
```bash
tmux capture-pane -t "<session>" -p -S -50
```

**Merge conflicts:**
Resolve manually, then continue.

**Worker stuck:**
```bash
tmux send-keys -t "<session>" "Please continue with your task" C-m
```

**Subagent failed:**
Worker should retry or mark issue for manual review.
