---
description: "Fully autonomous backlog completion. Runs waves until `bd ready` is empty. Self-resumable after /wipe. Use when you want hands-off parallel issue processing."
---

# BD Swarm Auto - Autonomous Backlog Completion

**YOU are the conductor. Execute this workflow autonomously. Do NOT ask the user for input.**

## Architecture: Parallel Terminal Workers + Lookahead Enhancer

Spawn **3-4 terminal workers max**, each handling 1-2 issues with skill-aware prompts.
A **parallel enhancer** (Haiku) prepares prompts 1-2 waves ahead for efficiency.

```
BAD:  10 terminals x 1 issue each    -> statusline chaos
GOOD: 3-4 terminals with focused prompts -> smooth execution
BEST: 3-4 workers + 1 enhancer preparing ahead -> maximum throughput
```

---

## Quick Reference

| Step | Action | Reference |
|------|--------|-----------|
| 0 | Spawn enhancer | Parallel prompt preparation |
| 1 | Get ready issues | `bd ready --json` |
| 2 | Calculate workers | Max 4, distribute issues |
| 3 | Create worktrees | Parallel, wait for all |
| 4 | Spawn workers | TabzChrome API |
| 5 | Send prompts | Check prepared.prompt first |
| 6 | Poll status | Every 2 min, check context |
| 7 | Merge & cleanup | Kill sessions first |
| 8 | Visual QA | tabz-manager for UI waves |
| 9 | Next wave | Loop until empty, then kill enhancer |

---

## Step 0: Spawn Lookahead Enhancer

Before starting waves, spawn the enhancer in a parallel terminal (Haiku model).
The enhancer stays 1-2 waves ahead, preparing prompts while workers execute.

```bash
# Check if enhancer already running
ENHANCER_SESSION=$(tmux list-sessions -F '#S' 2>/dev/null | grep '^ctt-enhancer' | head -1)

if [ -z "$ENHANCER_SESSION" ]; then
  echo "Spawning lookahead enhancer..."
  TOKEN=$(cat /tmp/tabz-auth-token 2>/dev/null)

  RESPONSE=$(curl -s -X POST http://localhost:8129/api/spawn \
    -H "Content-Type: application/json" \
    -H "X-Auth-Token: $TOKEN" \
    -d '{
      "name": "Enhancer",
      "workingDir": "'"$(pwd)"'",
      "command": "'"${CLAUDE_PLUGIN_ROOT:-./plugins/conductor}"'/scripts/lookahead-enhancer.sh --max-ahead 8 --batch 4"
    }')

  ENHANCER_SESSION=$(echo "$RESPONSE" | jq -r '.terminal.ptyInfo.tmuxSession // empty')
  [ -n "$ENHANCER_SESSION" ] && echo "Enhancer spawned: $ENHANCER_SESSION"
fi

# Give enhancer a head start (prepares first batch while we set up)
sleep 5
```

**Note**: The enhancer script runs in a loop until killed. It marks issues with `enhancing: true` while processing, then stores `prepared.prompt` when done. This prevents race conditions with workers.

---

## EXECUTE NOW - Wave Loop

```bash
# Get ready issues (skip epics and gate issues)
READY=$(bd ready --json | jq -r '.[] | select(.type != "epic") | select(.title | test("GATE"; "i") | not) | .id')
[ -z "$READY" ] && echo "Backlog complete!" && exit 0

# Count and distribute to max 4 workers
ISSUES_COUNT=$(echo "$READY" | wc -l)
# 1-4: 1-2 workers, 5-8: 2-3 workers, 9+: 3-4 workers

# Create worktrees (parallel)
for ISSUE_ID in $READY; do
  ${CLAUDE_PLUGIN_ROOT}/scripts/setup-worktree.sh "$ISSUE_ID" &
done
wait

# Create agent beads for tracking (parallel)
for ISSUE_ID in $READY; do
  AGENT_ID=$(bd create --type=agent --title="Worker: $ISSUE_ID" --labels="conductor:worker" --json | jq -r ".id")
  bd agent state "$AGENT_ID" spawning
  bd slot set "$AGENT_ID" hook "$ISSUE_ID"
  bd update "$ISSUE_ID" --notes "agent_id: $AGENT_ID"
done

# Spawn workers, send prompts, monitor
# ... see references/wave-execution.md

# After worker init completes, update agent state to running
# (Workers should call: bd agent state $AGENT_ID running)

# FULL CLOSEOUT: Use wave-done skill (recommended)
/conductor:wave-done $READY
# Runs: verify workers → kill sessions → merge → build → review → cleanup → push → summary

# QUICK CLEANUP (alternative, skip review):
# ${CLAUDE_PLUGIN_ROOT}/scripts/completion-pipeline.sh "$READY"

# Check for next wave
NEXT=$(bd ready --json | jq 'length')
if [ "$NEXT" -gt 0 ]; then
  echo "Starting next wave..."
  # LOOP back to wave start (enhancer keeps running)
else
  echo "Backlog complete! Cleaning up..."
  # Kill enhancer terminal
  ENHANCER_SESSION=$(tmux list-sessions -F '#S' 2>/dev/null | grep '^ctt-enhancer' | head -1)
  [ -n "$ENHANCER_SESSION" ] && tmux kill-session -t "$ENHANCER_SESSION" && echo "Killed enhancer session"
fi
```

---

## Key Rules

1. **NO USER INPUT** - Fully autonomous, no AskUserQuestion
2. **MAX 4 TERMINALS** - Never spawn more than 4 workers
3. **ENHANCER PARALLEL** - Spawn lookahead enhancer at start, it runs continuously
4. **CHECK PREPARED FIRST** - Always check `prepared.prompt` before crafting dynamically
5. **SKILL-AWARE PROMPTS** - Include skill hints in worker prompts
6. **YOU MUST POLL** - Check issue status every 2 minutes
7. **LOOP UNTIL EMPTY** - Keep running waves until `bd ready` is empty
8. **VISUAL QA** - Spawn tabz-manager after UI waves
9. **MONITOR CONTEXT** - At 70%+, trigger `/wipe:wipe`
10. **CLEANUP** - Kill enhancer terminal when backlog complete

---

## Worker Prompts: Prepared vs Dynamic

**Before crafting a prompt, check if the issue has a prepared prompt in notes.**
The lookahead enhancer runs in parallel, preparing prompts ahead of time.

### Check for Prepared Prompt (with optional wait)

```bash
get_prompt_for_issue() {
  local ISSUE_ID="$1"
  local MAX_WAIT="${2:-10}"  # Max seconds to wait for enhancer
  local WAITED=0

  while [ "$WAITED" -lt "$MAX_WAIT" ]; do
    NOTES=$(bd show "$ISSUE_ID" --json | jq -r '.[0].notes // ""')

    # Check if enhancer is currently processing this issue
    if echo "$NOTES" | grep -q "^enhancing: true"; then
      echo "Waiting for enhancer to finish $ISSUE_ID..." >&2
      sleep 2
      WAITED=$((WAITED + 2))
      continue
    fi

    # Check for prepared prompt
    PREPARED_PROMPT=$(echo "$NOTES" | sed -n '/^prepared\.prompt: |/,/^[a-z]*\./{ /^prepared\.prompt: |/d; /^[a-z]*\./d; s/^  //p; }')

    if [ -n "$PREPARED_PROMPT" ]; then
      echo "Using prepared prompt from notes" >&2
      echo "$PREPARED_PROMPT"
      return 0
    fi

    # No prepared prompt and not enhancing - break and craft dynamically
    break
  done

  # Fall back to dynamic crafting
  echo "Crafting prompt dynamically..." >&2
  return 1
}

# Usage in worker prompt construction
WORKER_PROMPT=$(get_prompt_for_issue "$ISSUE_ID" 10)
if [ $? -ne 0 ]; then
  # Dynamic crafting (see template below)
  WORKER_PROMPT="..."
fi
```

### Enhancer Status Check

```bash
# Quick check on enhancer progress
${CLAUDE_PLUGIN_ROOT:-./plugins/conductor}/scripts/lookahead-enhancer.sh --status
```

### When Prepared Prompt Exists

Use it **verbatim**. The prompt was crafted during `/conductor:bd-plan "Enhance Prompts"` with:
- Skills already matched and verified
- Key files already identified
- Context already prepared

This saves tokens and ensures consistency across workers.

### When No Prepared Prompt (Dynamic Crafting)

Fall back to the template below:

```markdown
## Task: ISSUE-ID - Title

## Skills to Load
**FIRST**, invoke these skills before starting work:
- /backend-development:backend-development
- /conductor:orchestration

These load patterns and context you'll need.

## Context
[WHY this matters - helps Claude generalize and make good decisions]

## Key Files
- path/to/file.ts (focus on lines X-Y)
- path/to/other.ts

## Approach
[Implementation guidance - what to do]

## When Done
Run `/conductor:worker-done ISSUE-ID`
```

**CRITICAL: Use full `plugin:skill` format for skill invocation.**

To find actual available skills, run:
```bash
./plugins/conductor/scripts/discover-skills.sh "backend api terminal"
```

| ❌ Wrong format | ✅ Correct format |
|-----------------|-------------------|
| `/backend-development` | `/backend-development:backend-development` |
| `/xterm-js` | `/xterm-js:xterm-js` |
| "Use the X skill" | Explicit `/plugin:skill` invocation |

**Prompt Guidelines:**
- **Be explicit** - "Fix null reference on line 45" not "fix the bug"
- **Add context** - Explain WHY to help Claude make good decisions
- **Reference patterns** - Point to existing code for consistency
- **Avoid ALL CAPS** - Claude 4.x overtriggers on aggressive language
- **File paths as text** - Workers read files on-demand, avoids bloat

**Full guidelines:** `references/worker-architecture.md`

---

## Visual QA with tabz-manager

After completing a wave with UI changes, spawn tabz-manager in a **separate terminal** for visual QA:

```bash
# Via TabzChrome API
curl -X POST http://localhost:8129/api/spawn \
  -H "X-Auth-Token: $(cat /tmp/tabz-auth-token)" \
  -d '{"name": "Visual QA", "command": "claude --agent tabz:tabz-manager --dangerously-skip-permissions"}'
```

tabz-manager can take screenshots, click elements, and verify UI changes work correctly.

---

## Context Recovery

At 70% context, run `/wipe:wipe` with handoff:

```
## BD Swarm Auto In Progress
**Active Issues:** [list in_progress IDs]
**Action:** Run `/conductor:bd-swarm-auto` to continue
```

---

## Auto vs Interactive

| Aspect | Auto | Interactive |
|--------|------|-------------|
| Worker count | All ready | Ask user |
| Waves | Loop until empty | One wave |
| Questions | Make defaults | AskUserQuestion ok |
| Context | Auto /wipe | Manual |

---

## Monitoring Workers

Use native beads agent tracking instead of custom scripts:

```bash
# List all running workers
bd list --type=agent --label="conductor:worker" --status=open

# Watch agents in real-time
bd list --type=agent --watch

# Show specific agent details
bd agent show <agent-id>

# Check agent state
bd agent state <agent-id>
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Worker not responding | `bd agent show <agent-id>` to check state, then `tmux capture-pane -t SESSION -p -S -50` for details |
| Worker stuck | `bd agent state <agent-id> stalled`, then nudge via tmux send-keys |
| Worker failed | `bd agent state <agent-id> failed --reason="..."`, re-spawn or close with 'needs-review' |
| Merge conflicts | Resolve manually, continue |
| Find all workers | `bd list --type=agent --label="conductor:worker"` |

---

Execute this workflow NOW. Start with getting ready issues.
