# Wave Execution - BD Swarm Auto

Detailed step-by-step wave execution for autonomous backlog processing.

## Step 1: Get Ready Issues

```bash
bd ready --json | jq -r '.[] | "\(.id): \(.title)"'
```

If empty, announce "Backlog complete!" and stop.

Store the issue IDs and count them.

## Step 2: Calculate Worker Distribution

Determine how many terminal workers to spawn (max 4):

```
Issues: 1-4   -> 1-2 workers (1-2 issues each)
Issues: 5-8   -> 2-3 workers (2-3 issues each)
Issues: 9-12  -> 3-4 workers (3 issues each)
Issues: 13+   -> 4 workers (batch remaining)
```

Example for 10 issues:
- Worker 1: SAAS-001, SAAS-002, SAAS-003
- Worker 2: SAAS-004, SAAS-005, SAAS-006
- Worker 3: SAAS-007, SAAS-008
- Worker 4: SAAS-009, SAAS-010

## Step 3: Create Worktrees and Install Dependencies

```bash
PROJECT_DIR=$(pwd)
WORKTREE_BASE="$(dirname "$PROJECT_DIR")"  # Worktrees created as siblings

# Use setup-worktree.sh for each issue (parallel, handles deps and beads redirect)
for ISSUE_ID in <all-issue-ids>; do
  ${CLAUDE_PLUGIN_ROOT}/scripts/setup-worktree.sh "$ISSUE_ID" "$PROJECT_DIR" &
done
wait
```

The script:
1. Uses `bd worktree create` (beads-native, auto-configures beads redirect)
2. Installs dependencies (pnpm/yarn/npm based on lockfile)
3. Runs initial build if package.json has build script
4. Worktrees created at `../${ISSUE_ID}` (e.g., `/home/user/projects/ISSUE-123`)

**WAIT for ALL worktrees to be ready before Step 4.**

## Step 4: Spawn Terminal Workers

Spawn only 3-4 terminal workers. Each worker runs in its worktree directory:

```bash
TOKEN=$(cat /tmp/tabz-auth-token)
CONDUCTOR_SESSION=$(tmux display-message -p '#{session_name}')
WORKTREE_BASE="$(dirname "$PROJECT_DIR")"

# For each issue, spawn a worker in its worktree
for ISSUE_ID in <assigned-issue-ids>; do
  WORKTREE_PATH="${WORKTREE_BASE}/${ISSUE_ID}"

  RESPONSE=$(curl -s -X POST http://localhost:8129/api/spawn \
    -H "Content-Type: application/json" \
    -H "X-Auth-Token: $TOKEN" \
    -d "$(jq -n \
      --arg name "worker-${ISSUE_ID}" \
      --arg dir "$WORKTREE_PATH" \
      --arg cmd "CONDUCTOR_SESSION='$CONDUCTOR_SESSION' claude --dangerously-skip-permissions" \
      '{name: $name, workingDir: $dir, command: $cmd}')")

  SESSION_NAME=$(echo "$RESPONSE" | jq -r '.terminal.ptyInfo.tmuxSession // .terminal.id')
  echo "Spawned: $ISSUE_ID -> $SESSION_NAME (at $WORKTREE_PATH)"

  # Record in beads
  bd update "$ISSUE_ID" --status in_progress
  bd update "$ISSUE_ID" --notes "conductor_session: $CONDUCTOR_SESSION
worker_session: $SESSION_NAME
worktree: $WORKTREE_PATH
started_at: $(date -Iseconds)"
done
```

**Note:** Max 4 terminal workers. If more than 4 issues, distribute issues across workers (2-3 per worker).

## Step 5: Send Skill-Aware Prompts

Wait 5 seconds for Claude to initialize, then send each worker its prompt.

**First, check for prepared prompt (from bd-plan):**
```bash
NOTES=$(bd show "$ISSUE_ID" --json | jq -r '.[0].notes // ""')
PREPARED_PROMPT=$(echo "$NOTES" | sed -n '/^prepared\.prompt:/,/^[a-z_]*\.[a-z]*:/p' | sed '1d;$d' | sed 's/^  //')

if [ -n "$PREPARED_PROMPT" ]; then
  # Use the prepared prompt from bd-plan
  echo "Using prepared prompt for $ISSUE_ID"
  FINAL_PROMPT="$PREPARED_PROMPT"
else
  # Craft prompt dynamically
  MATCH_SCRIPT="${CLAUDE_PLUGIN_ROOT:-./plugins/conductor}/scripts/match-skills.sh"
  SKILL_KEYWORDS=$($MATCH_SCRIPT --issue "$ISSUE_ID")
  # Build prompt below...
fi
```

**If no prepared prompt, get keyword phrases for skill activation:**
```bash
MATCH_SCRIPT="${CLAUDE_PLUGIN_ROOT:-./plugins/conductor}/scripts/match-skills.sh"
SKILL_KEYWORDS=$($MATCH_SCRIPT --issue "$ISSUE_ID")
# Returns phrases like: "xterm.js terminal, resize handling, FitAddon"
```

**Then send the prompt using load-buffer (handles multi-line safely):**
```bash
SESSION="<session-name>"
ISSUE_ID="<issue-id>"
TITLE="<issue-title>"
DESC=$(bd show $ISSUE_ID --json | jq -r '.[0].description // "No description"')

sleep 5

# Write prompt to temp file
PROMPT_FILE=$(mktemp)
cat > "$PROMPT_FILE" << PROMPT_EOF
## Task: ${ISSUE_ID} - ${TITLE}

## Context
${DESC}
This task involves ${SKILL_KEYWORDS}

## Key Files
- path/to/relevant/file.ts
- path/to/other/file.ts

## Approach
[Implementation guidance based on issue description]

## When Done
Run \`/conductor:bdw-worker-done ${ISSUE_ID}\`
PROMPT_EOF

# Load and paste (bypasses shell quoting issues)
tmux load-buffer "$PROMPT_FILE"
tmux paste-buffer -t "$SESSION"
sleep 0.3
tmux send-keys -t "$SESSION" C-m
rm "$PROMPT_FILE"
```

**Why keywords instead of `/plugin:skill`?** The skill-eval hook automatically detects domain keywords and suggests relevant skills. Natural language like "xterm.js terminal patterns" triggers the same skills without explicit invocation.

**Note:** List file paths as text, not @file references. Workers read files on-demand.

## Step 6: Poll Until All Issues Closed

**YOU must poll every 2 minutes. Do NOT wait for user input.**

```bash
while true; do
  echo "[$(date '+%H:%M')] Checking issue status..."

  ALL_CLOSED=true
  CLOSED_COUNT=0
  TOTAL_COUNT=<number-of-issues>

  for ISSUE_ID in <all-issue-ids>; do
    STATUS=$(bd show "$ISSUE_ID" --json | jq -r '.[0].status')
    if [ "$STATUS" = "closed" ]; then
      CLOSED_COUNT=$((CLOSED_COUNT + 1))
    else
      ALL_CLOSED=false
    fi
  done

  echo "Progress: $CLOSED_COUNT/$TOTAL_COUNT closed"

  if [ "$ALL_CLOSED" = "true" ]; then
    echo "All issues closed! Proceeding to merge."
    break
  fi

  echo "Waiting 2 minutes before next poll..."
  sleep 120
done
```

## Step 7: Kill Sessions and Merge

```bash
# Kill worker sessions (only 3-4 to kill)
for SESSION in <worker-session-names>; do
  tmux kill-session -t "$SESSION" 2>/dev/null
  echo "Killed: $SESSION"
done

# Merge each feature branch
cd "$PROJECT_DIR"
for ISSUE_ID in <all-issue-ids>; do
  git merge --no-edit "feature/${ISSUE_ID}" || {
    git checkout --theirs . 2>/dev/null
    git add -A
    git commit -m "feat: merge ${ISSUE_ID}" || true
  }
done

# Cleanup worktrees (created as siblings to project)
WORKTREE_BASE="$(dirname "$PROJECT_DIR")"
for ISSUE_ID in <all-issue-ids>; do
  git worktree remove --force "${WORKTREE_BASE}/${ISSUE_ID}" 2>/dev/null
  git branch -d "feature/${ISSUE_ID}" 2>/dev/null
done

# Audio announcement
curl -s -X POST http://localhost:8129/api/audio/speak \
  -H "Content-Type: application/json" \
  -d '{"text": "Wave complete. Branches merged.", "voice": "en-GB-SoniaNeural", "priority": "high"}' &
```

## Step 8: Visual QA (After UI Waves)

If wave included UI changes, spawn tabz-expert subagent:

```
Task(subagent_type="tabz-expert",
     prompt="Visual QA after wave completion.
       1. Start dev server: npm run dev
       2. Screenshot at 1920x1080
       3. Check console for errors
       4. Create beads issues for bugs found
       5. Kill dev server when done")
```

**Skip if wave was backend/config only.**

## Step 9: Sync and Check Next Wave

```bash
bd sync
git push origin main 2>/dev/null || echo "Push skipped"

NEXT_COUNT=$(bd ready --json | jq 'length')
echo "Next wave: $NEXT_COUNT issues ready"
```

**If more issues ready, GO BACK TO STEP 1.**

**If no more issues, announce completion:**

```bash
curl -s -X POST http://localhost:8129/api/audio/speak \
  -H "Content-Type: application/json" \
  -d '{"text": "Backlog complete! All waves finished.", "voice": "en-GB-SoniaNeural", "priority": "high"}' &

echo "=== BD SWARM AUTO COMPLETE ==="
```
