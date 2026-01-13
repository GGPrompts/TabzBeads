---
description: "Interactive multi-session orchestration. Select issues, choose terminal count (1-4), pick mode (interactive/autonomous), then spawn workers. Main entry point for spawning workers."
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
3. Choose terminals     → AskUserQuestion (1-4)
4. Choose mode          → AskUserQuestion (Interactive/Autonomous)
5. Ensure enhanced      → Check/run bdc-prompt-enhancer for unprepared issues
6. Create worktrees     → scripts/setup-worktree.sh (parallel)
7. Spawn workers        → TabzChrome API
8. Send prompts         → Skill-aware prompts from prepared.prompt
9. Execute mode         → Interactive: monitor | Autonomous: wave loop
10. Complete            → /conductor:bdc-wave-done
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
  { label: "1 terminal", description: "Single worker - focused execution (like old bd-work)" },
  { label: "2 terminals", description: "Conservative - less resource usage" },
  { label: "3 terminals (Recommended)", description: "Balanced performance" },
  { label: "4 terminals", description: "Maximum parallelism" }
]
```

**Note:** With 1 terminal selected, behavior is identical to the deprecated `bd-work` command - a single worker handles one issue at a time.

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

## Phase 2.5: Ensure Prompts Enhanced

Before spawning workers, check if selected issues have prepared prompts:

```bash
UNPREPARED=""
for ISSUE_ID in $SELECTED_ISSUES; do
  NOTES=$(bd show "$ISSUE_ID" --json | jq -r '.[0].notes // ""')
  if ! echo "$NOTES" | grep -q "prepared.prompt"; then
    UNPREPARED="$UNPREPARED $ISSUE_ID"
  fi
done
```

If any unprepared, enhance them:

**Option A: Batch Enhancement (Recommended)**

```bash
if [ -n "$UNPREPARED" ]; then
  echo "Enhancing $UNPREPARED..."
  ${CLAUDE_PLUGIN_ROOT}/scripts/lookahead-enhancer.sh --once --batch 4
fi
```

**Option B: Parallel Task Agents**

For faster parallel enhancement, spawn sonnet Tasks:

```
for ISSUE_ID in $UNPREPARED:
  Task(
    subagent_type: "general-purpose",
    model: "sonnet",
    run_in_background: true,
    description: "Enhance $ISSUE_ID",
    prompt: "Enhance beads issue $ISSUE_ID following bdc-prompt-enhancer command..."
  )
```

Wait for all Tasks to complete before proceeding.

**Option C: Skip Enhancement**

Proceed without enhancement - workers will craft prompts dynamically from issue description. Less efficient but works for well-described issues.

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

## Key Differences from Other Commands

| Aspect | bd-conduct | bdc-swarm-auto | bd-start |
|--------|------------|----------------|----------|
| Issue selection | User picks (multiSelect) | All ready issues | Top ready or specified |
| Terminal count | User chooses (1-4) | Auto-calculated | N/A (you work) |
| Mode | User chooses | Always autonomous | N/A |
| Who works? | Spawned workers | Spawned workers | YOU directly |
| Entry point | Interactive prompts | Immediate execution | Immediate |

---

## Related Commands

| Command | Purpose |
|---------|---------|
| `/conductor:bd-start` | YOU work on issue directly (no spawn) |
| `/conductor:bd-plan` | Prepare backlog before spawning |
| `/conductor:bdc-swarm-auto` | Fully autonomous waves, no prompts |
| `/conductor:bdc-wave-done` | Complete a wave of workers |

---

Execute this workflow now. Start by getting ready issues.
