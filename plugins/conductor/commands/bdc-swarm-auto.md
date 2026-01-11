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
| 1.5 | Check for batches | `match-skills.sh --all-batches` |
| 2 | Calculate workers | 1 per batch (max 4) |
| 3 | Create worktrees | Parallel, wait for all |
| 4 | Spawn workers | TabzChrome API |
| 5 | Send prompts | Check prepared.prompt first, use **batch-aware prompts** |
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

### Batch-Aware Spawning

When issues have `batch.id` in notes (set by bd-plan "Group Tasks"):
- Group issues by batch ID
- Spawn 1 worker per batch (not per issue)
- Use batched prompt template listing all issues
- Worker commits each issue separately, then closes all

---

## EXECUTE NOW - Wave Loop

```bash
MATCH_SCRIPT="${CLAUDE_PLUGIN_ROOT:-./plugins/conductor}/scripts/match-skills.sh"

# Get ready issues (skip epics and gate issues)
READY=$(bd ready --json | jq -r '.[] | select(.type != "epic") | select(.title | test("GATE"; "i") | not) | .id')
[ -z "$READY" ] && echo "Backlog complete!" && exit 0

# Check for batch assignments
BATCHES=$($MATCH_SCRIPT --all-batches 2>/dev/null)

if [ -n "$BATCHES" ]; then
  echo "=== Batch Mode: Spawning by batch ==="
  WORKER_TARGETS="$BATCHES"
  IS_BATCH_MODE=true
else
  echo "=== Standard Mode: Spawning per issue ==="
  WORKER_TARGETS="$READY"
  IS_BATCH_MODE=false
fi

# Count and limit to max 4 workers
TARGET_COUNT=$(echo "$WORKER_TARGETS" | wc -l)
# 1-4: 1-2 workers, 5-8: 2-3 workers, 9+: 3-4 workers

# Create worktrees (parallel) - use first issue ID for batch worktrees
for TARGET in $WORKER_TARGETS; do
  if [ "$IS_BATCH_MODE" = true ]; then
    # For batches, use batch ID as worktree name, get first issue for branch
    FIRST_ISSUE=$($MATCH_SCRIPT --batch-issues "$TARGET" | head -1)
    ${CLAUDE_PLUGIN_ROOT}/scripts/setup-worktree.sh "$TARGET" &
  else
    ${CLAUDE_PLUGIN_ROOT}/scripts/setup-worktree.sh "$TARGET" &
  fi
done
wait

# Create agent beads for tracking
for TARGET in $WORKER_TARGETS; do
  if [ "$IS_BATCH_MODE" = true ]; then
    BATCH_ISSUES=$($MATCH_SCRIPT --batch-issues "$TARGET")
    AGENT_ID=$(bd create --type=agent --title="Worker: $TARGET" --labels="conductor:worker,batch" --json | jq -r ".id")
    bd agent state "$AGENT_ID" spawning
    # Link agent to all issues in batch
    for ISSUE_ID in $BATCH_ISSUES; do
      bd slot set "$AGENT_ID" hook "$ISSUE_ID"
      EXISTING_NOTES=$(bd show "$ISSUE_ID" --json 2>/dev/null | jq -r '.[0].notes // ""')
      bd update "$ISSUE_ID" --notes "${EXISTING_NOTES}
agent_id: $AGENT_ID"
    done
  else
    AGENT_ID=$(bd create --type=agent --title="Worker: $TARGET" --labels="conductor:worker" --json | jq -r ".id")
    bd agent state "$AGENT_ID" spawning
    bd slot set "$AGENT_ID" hook "$TARGET"
    bd update "$TARGET" --notes "agent_id: $AGENT_ID"
  fi
done

# Spawn workers, send prompts (use batched prompt template), monitor
# ... see "Batched Worker Prompt Template" section below

# After worker init completes, update agent state to running
# (Workers should call: bd agent state $AGENT_ID running)

# FULL CLOSEOUT: Use wave-done skill (recommended)
if [ "$IS_BATCH_MODE" = true ]; then
  # For batches, wave-done receives all issue IDs from all batches
  ALL_ISSUES=""
  for BATCH_ID in $BATCHES; do
    BATCH_ISSUES=$($MATCH_SCRIPT --batch-issues "$BATCH_ID")
    ALL_ISSUES="$ALL_ISSUES $BATCH_ISSUES"
  done
  /conductor:bdc-wave-done $ALL_ISSUES
else
  /conductor:bdc-wave-done $READY
fi
# Runs: verify workers → kill sessions → merge → build → review → cleanup → push → summary

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

## Context
[WHY this matters - helps Claude generalize and make good decisions]
This task involves [domain keywords: e.g., "FastAPI REST endpoint with PostgreSQL database"]

## Key Files
- path/to/file.ts (focus on lines X-Y)
- path/to/other.ts

## Approach
[Implementation guidance - include domain keywords for skill activation]

## When Done
Run `/conductor:bdw-worker-done ISSUE-ID`
```

**Note:** The skill-eval hook handles skill activation - just include relevant domain keywords in the prompt (e.g., "shadcn/ui components", "FastAPI REST API", "xterm.js terminal").

**Prompt Guidelines:**
- **Be explicit** - "Fix null reference on line 45" not "fix the bug"
- **Add context** - Explain WHY to help Claude make good decisions
- **Reference patterns** - Point to existing code for consistency
- **Avoid ALL CAPS** - Claude 4.x overtriggers on aggressive language
- **File paths as text** - Workers read files on-demand, avoids bloat

**Full guidelines:** `references/worker-architecture.md`

---

## Batched Worker Prompt Template

When spawning a worker for a batch of issues, use this template:

```markdown
## Batch Task: BATCH-ID

You have been assigned multiple tasks to complete in sequence. Complete each task and commit separately.

These tasks involve [domain keywords from matched skills: e.g., "React components with Tailwind CSS styling"].

---

## Task 1: ISSUE-1-ID - Title 1
### Context
[Description from issue 1]

### When Done with Task 1
```bash
git add -A && git commit -m "fix(scope): description

Closes: ISSUE-1-ID
Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 2: ISSUE-2-ID - Title 2
### Context
[Description from issue 2]

### When Done with Task 2
```bash
git add -A && git commit -m "fix(scope): description

Closes: ISSUE-2-ID
Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 3: ISSUE-3-ID - Title 3 (if present)
### Context
[Description from issue 3]

### When Done with Task 3
```bash
git add -A && git commit -m "fix(scope): description

Closes: ISSUE-3-ID
Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## When All Tasks Complete
Run `/conductor:bdw-worker-done ISSUE-1-ID ISSUE-2-ID ISSUE-3-ID`
```

### Generating Batched Prompts

```bash
MATCH_SCRIPT="${CLAUDE_PLUGIN_ROOT:-./plugins/conductor}/scripts/match-skills.sh"

generate_batched_prompt() {
  local BATCH_ID="$1"
  local ISSUES=$($MATCH_SCRIPT --batch-issues "$BATCH_ID")
  local TASK_NUM=1

  echo "## Batch Task: $BATCH_ID"
  echo ""
  echo "You have been assigned multiple tasks to complete in sequence. Complete each task and commit separately."
  echo ""

  # Collect all skills from batch issues
  ALL_SKILLS=""
  for ISSUE_ID in $ISSUES; do
    ISSUE_SKILLS=$($MATCH_SCRIPT --issue "$ISSUE_ID" 2>/dev/null)
    ALL_SKILLS="$ALL_SKILLS $ISSUE_SKILLS"
  done
  UNIQUE_SKILLS=$(echo "$ALL_SKILLS" | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' ')

  if [ -n "$UNIQUE_SKILLS" ]; then
    echo "## Skills to Load"
    echo "**FIRST**, invoke these skills before starting work:"
    for skill in $UNIQUE_SKILLS; do
      echo "- $skill"
    done
    echo ""
  fi

  echo "---"
  echo ""

  # Generate task sections
  local ISSUE_LIST=""
  for ISSUE_ID in $ISSUES; do
    ISSUE_JSON=$(bd show "$ISSUE_ID" --json)
    TITLE=$(echo "$ISSUE_JSON" | jq -r '.[0].title // ""')
    DESC=$(echo "$ISSUE_JSON" | jq -r '.[0].description // ""')

    echo "## Task $TASK_NUM: $ISSUE_ID - $TITLE"
    echo "### Context"
    echo "$DESC"
    echo ""
    echo "### When Done with Task $TASK_NUM"
    echo '```bash'
    echo "git add -A && git commit -m \"fix(scope): $TITLE"
    echo ""
    echo "Closes: $ISSUE_ID"
    echo 'Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"'
    echo '```'
    echo ""
    echo "---"
    echo ""

    ISSUE_LIST="$ISSUE_LIST $ISSUE_ID"
    ((TASK_NUM++))
  done

  echo "## When All Tasks Complete"
  echo "Run \`/conductor:bdw-worker-done$ISSUE_LIST\`"
}

# Usage: generate_batched_prompt "batch-001" > /tmp/prompt.md
```

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
