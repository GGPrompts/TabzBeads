---
description: "Interactive multi-session orchestration. Select issues, choose terminal count, pick mode (interactive/autonomous), then spawn workers. Use when you want guided parallel issue processing."
---

# BD Conduct - Interactive Multi-Session Orchestration

Spawn parallel workers with interactive configuration. You select issues, terminal count, and execution mode.

## Usage

```bash
/conductor:bd-conduct
```

## Workflow Overview

```
1. Get ready issues     → bd ready
2. Select issues        → AskUserQuestion (multiSelect)
3. Choose terminals     → AskUserQuestion (2-4)
4. Choose mode          → AskUserQuestion (Interactive/Autonomous)
5. Create worktrees     → scripts/setup-worktree.sh (parallel)
6. Spawn workers        → TabzChrome API
7. Send prompts         → Skill-aware prompts
8. Execute mode         → Interactive: monitor | Autonomous: wave loop
9. Complete             → /conductor:bdc-wave-done
```

---

## Phase 1: Get Ready Issues

```bash
bd ready --json | jq -r '.[] | "[\(.priority)] \(.id): \(.title)"'
```

---

## Phase 2: Interactive Configuration

Present three AskUserQuestion prompts in sequence:

### Issue Selection (multiSelect: true)

```
question: "Which issues should workers tackle in parallel?"
header: "Issues"
options: [
  // Build from bd ready: { label: "<id> (P<priority>)", description: "<title>" }
  { label: "PROJ-abc (P1)", description: "Fix critical bug in auth" },
  { label: "PROJ-def (P2)", description: "Add dark mode toggle" }
]
```

### Terminal Count

```
question: "How many worker terminals should I spawn?"
header: "Terminals"
options: [
  { label: "2 terminals", description: "Conservative - less resource usage" },
  { label: "3 terminals (Recommended)", description: "Balanced performance" },
  { label: "4 terminals", description: "Maximum parallelism" }
]
```

### Execution Mode

```
question: "How should I run the workers?"
header: "Mode"
options: [
  { label: "Interactive (Recommended)", description: "You monitor, can intervene" },
  { label: "Autonomous", description: "Runs waves until backlog empty" }
]
```

---

## Phase 3: Setup Workers

After user configuration:

```bash
CONDUCTOR_SESSION=$(tmux display-message -p '#{session_name}')

# Verify skills before prompting
${CLAUDE_PLUGIN_ROOT}/scripts/match-skills.sh --available-full

# Create worktrees (parallel)
for ISSUE_ID in $SELECTED_ISSUES; do
  ${CLAUDE_PLUGIN_ROOT}/scripts/setup-worktree.sh "$ISSUE_ID" &
done
wait
```

Spawn workers via TabzChrome API:

```bash
TOKEN=$(cat /tmp/tabz-auth-token)
WORKTREE_PATH="$(pwd)-worktrees/$ISSUE_ID"

RESPONSE=$(curl -s -X POST http://localhost:8129/api/spawn \
  -H "Content-Type: application/json" \
  -H "X-Auth-Token: $TOKEN" \
  -d "{\"name\": \"worker-$ISSUE_ID\", \"workingDir\": \"$WORKTREE_PATH\", \"command\": \"BD_SOCKET=/tmp/bd-worker-$ISSUE_ID.sock CONDUCTOR_SESSION='$CONDUCTOR_SESSION' claude --dangerously-skip-permissions\"}")

SESSION_NAME=$(echo "$RESPONSE" | jq -r '.terminal.ptyInfo.tmuxSession // .terminal.id')

# Record in beads
bd update "$ISSUE_ID" --status in_progress
bd update "$ISSUE_ID" --notes "conductor_session: $CONDUCTOR_SESSION
worker_session: $SESSION_NAME
started_at: $(date -Iseconds)"
```

Send skill-aware prompt (after 4s init):

```bash
sleep 4
tmux send-keys -t "$SESSION_NAME" -l "$WORKER_PROMPT"
sleep 0.3
tmux send-keys -t "$SESSION_NAME" C-m
```

Worker prompt structure - see `references/worker-architecture.md`.

---

## Phase 4: Execute Mode

### Interactive Mode

- Poll status every 2 min: `${CLAUDE_PLUGIN_ROOT}/scripts/monitor-workers.sh --summary`
- Check if closed: `bd show $ISSUE_ID --json | jq -r '.[0].status'`
- Answer worker questions if they arise
- When all done, proceed to completion

### Autonomous Mode

- Loop waves until `bd ready` returns empty
- Auto-wipe at 75% context with handoff
- Make reasonable defaults, no user input

---

## Phase 5: Complete Wave

When all selected issues are closed:

```bash
/conductor:bdc-wave-done $SELECTED_ISSUES
```

This runs: verify → kill sessions → merge → build → review → cleanup → push → summary

---

## Key Differences from bd-swarm-auto

| Aspect | bd-conduct | bd-swarm-auto |
|--------|------------|---------------|
| Issue selection | User picks (multiSelect) | All ready issues |
| Terminal count | User chooses (2-4) | Auto-calculated |
| Mode | User chooses | Always autonomous |
| Entry point | Interactive prompts first | Immediate execution |

---

## Related Commands

| Command | Purpose |
|---------|---------|
| `/conductor:bdc-swarm-auto` | Fully autonomous, no prompts |
| `/conductor:bd-work` | Single-session, YOU implement the issue |
| `/conductor:bdc-wave-done` | Complete a wave of workers |

---

Execute this workflow now. Start by getting ready issues.
