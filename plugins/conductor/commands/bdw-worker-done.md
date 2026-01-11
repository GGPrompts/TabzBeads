---
description: "Complete worker task: verify build, run tests, commit, and close issue. Supports batched mode with multiple issue IDs. Invoke with /conductor:worker-done <issue-id> [issue-id2] [issue-id3]"
---

# Worker Done - Task Completion Orchestrator

Orchestrates the full task completion pipeline by composing atomic commands.

## Usage

```bash
# Single issue
/conductor:worker-done TabzChrome-abc

# Multiple issues (batched worker)
/conductor:worker-done TabzChrome-abc TabzChrome-def TabzChrome-ghi

# Or if issue ID is in your task header:
/conductor:worker-done
```

**Batched Mode:** When multiple issue IDs are provided, assumes commits are already done for each issue (as per batched prompt template). Runs build/test once, then closes all issues.

## Pipeline Overview

| Step | Command | Blocking? | Mode-specific |
|------|---------|-----------|---------------|
| 0 | Detect execution mode | No | Sets EXECUTION_MODE |
| 0.1 | Detect batched mode | No | Sets IS_BATCHED, ISSUE_IDS array |
| 0.5 | Detect change types | No | Sets DOCS_ONLY |
| 0.6 | Detect complexity | No | Sets COMPLEXITY (simple/complex) |
| 1 | `/conductor:verify-build` | Yes - stop on failure | Skip if DOCS_ONLY |
| 1a | `plugin-validator` agent | Yes - stop on failure | ONLY if DOCS_ONLY |
| 2 | `/conductor:run-tests` | Yes - stop on failure | Skip if DOCS_ONLY |
| 3 | `/conductor:commit-changes` | Yes - stop on failure | **Skip if batched** (commits done per-task) |
| 4 | `/conductor:create-followups` | No - log and continue | Always run |
| 5 | `/conductor:update-docs` | No - log and continue | Always run |
| 5.5 | Record completion info | No - best effort | Includes COMPLEXITY |
| 5.6 | Update agent bead state | No - best effort | **Worker mode only** |
| 6 | `/conductor:close-issue` | Yes - report result | Closes all issues if batched |
| 6.5 | Complexity-aware review | No - standalone only | **Standalone only** |
| 7 | Notify conductor | No - best effort | **Worker mode only** |
| 8 | Standalone next steps | No - informational | **Standalone mode only** |

**CRITICAL: You MUST execute Step 7 after Step 6.** Workers that skip Step 7 force the conductor to poll, wasting resources.

**DOCS_ONLY mode:** When all changes are markdown files (`.md`, `.markdown`), steps 1-2 are replaced with the `plugin-validator` agent. This validates markdown structure and content without running expensive build/test steps.

**Code review happens at conductor level:** Workers do NOT run code review. The conductor runs unified code review after merging all worker branches (see `/conductor:wave-done`). This prevents conflicts when multiple workers run in parallel.

---

## Execute Pipeline

### Step 0: Detect Execution Mode

**CRITICAL: Run this FIRST before any other steps.**

```bash
echo "=== Step 0: Detecting Execution Mode ==="

# Detection function
is_worker_mode() {
  # Method 1: CONDUCTOR_SESSION env var (set by bd-work/bd-swarm)
  [ -n "$CONDUCTOR_SESSION" ] && return 0

  # Method 2: Inside git worktree (bd-swarm creates these)
  COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null)
  GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)
  [ "$COMMON_DIR" != "$GIT_DIR" ] && return 0

  return 1  # Standalone mode
}

# Run detection
if is_worker_mode; then
  EXECUTION_MODE="worker"
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║  WORKER MODE DETECTED                                        ║"
  echo "║  • Skipping code review (conductor handles after merge)      ║"
  echo "║  • Skipping push (conductor handles after merge)             ║"
  echo "║  • Will notify conductor on completion                       ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
else
  EXECUTION_MODE="standalone"
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║  STANDALONE MODE DETECTED                                    ║"
  echo "║  • Full pipeline with optional code review                   ║"
  echo "║  • You should push changes when done                         ║"
  echo "║  • No conductor to notify                                    ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
fi
```

**Mode determines pipeline behavior:**

| Aspect | Worker Mode | Standalone Mode |
|--------|-------------|-----------------|
| Code review | Skip (conductor handles) | Optional (user choice) |
| Push | Skip (conductor handles) | User should push |
| Notify conductor | Yes (Step 7) | No |

---

### Step 0.1: Detect Batched Mode

**CRITICAL: Parse arguments to detect if multiple issue IDs were provided.**

```bash
echo "=== Step 0.1: Detecting Batched Mode ==="

# Parse arguments - all args are issue IDs
ISSUE_IDS=($@)  # Array of issue IDs
ISSUE_COUNT=${#ISSUE_IDS[@]}

if [ "$ISSUE_COUNT" -gt 1 ]; then
  IS_BATCHED=true
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║  BATCHED MODE DETECTED                                       ║"
  echo "╠══════════════════════════════════════════════════════════════╣"
  echo "║  Issues in batch: $ISSUE_COUNT"
  for ID in "${ISSUE_IDS[@]}"; do
    echo "║    - $ID"
  done
  echo "║                                                              ║"
  echo "║  • Commits assumed done per-task (step 3 skipped)           ║"
  echo "║  • Build/test runs once for all changes                     ║"
  echo "║  • All issues closed together                               ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
else
  IS_BATCHED=false
  ISSUE_ID="${ISSUE_IDS[0]:-$ISSUE_ID}"  # Use parsed or from context
  echo "Single issue mode: $ISSUE_ID"
fi
```

**Batched mode behavior:**
- **Step 3 (commit)**: Skipped - batched prompt template instructs per-task commits
- **Step 5.5 (record)**: Records completion for all issues in batch
- **Step 6 (close)**: Uses `bd close <id1> <id2> ...` to close all at once
- **Step 7 (notify)**: Notifies conductor with all issue IDs

---

### Step 0.5: Detect Change Types
```bash
echo "=== Step 0.5: Detecting Change Types ==="
# Check if only markdown files changed (staged + unstaged)
git diff --cached --name-only
git diff --name-only
```

**Detection logic:**
1. Get list of all changed files (staged and unstaged)
2. Check if ALL changes are markdown files (`.md`, `.markdown`)
3. Set `DOCS_ONLY=true` if only markdown, otherwise `DOCS_ONLY=false`

```bash
# Detection check - if ANY file is non-markdown, run full pipeline
if git diff --cached --name-only | grep -qvE '\.(md|markdown)$' 2>/dev/null; then
  DOCS_ONLY=false
elif git diff --name-only | grep -qvE '\.(md|markdown)$' 2>/dev/null; then
  DOCS_ONLY=false
else
  # Check if there are actually any changes at all
  if [ -z "$(git diff --cached --name-only)$(git diff --name-only)" ]; then
    DOCS_ONLY=false  # No changes = run normal pipeline
  else
    DOCS_ONLY=true
  fi
fi
```

If `DOCS_ONLY=true`: Run **Step 1a** (plugin-validator), then skip to **Step 3**.
If `DOCS_ONLY=false`: Continue with full pipeline (Steps 1, 2, 3...).

---

### Step 0.6: Detect Complexity

**Run after change type detection to determine verification intensity.**

```bash
echo "=== Step 0.6: Detecting Complexity ==="

# Get change statistics
STATS=$(git diff --cached --stat 2>/dev/null; git diff --stat 2>/dev/null)
FILE_COUNT=$(echo "$STATS" | grep -E '^\s*\S+\s+\|' | wc -l)
INSERTIONS=$(echo "$STATS" | grep -oP '\d+(?= insertion)' | awk '{s+=$1}END{print s+0}')
DELETIONS=$(echo "$STATS" | grep -oP '\d+(?= deletion)' | awk '{s+=$1}END{print s+0}')
LOC_CHANGED=$((INSERTIONS + DELETIONS))

# Check for new files vs modifications
NEW_FILES=$(git diff --cached --diff-filter=A --name-only 2>/dev/null | wc -l)
MODIFIED_FILES=$(git diff --cached --diff-filter=M --name-only 2>/dev/null | wc -l)

# Check if tests are touched
TOUCHES_TESTS=false
if git diff --cached --name-only 2>/dev/null | grep -qE '(test|spec|__tests__)'; then
  TOUCHES_TESTS=true
elif git diff --name-only 2>/dev/null | grep -qE '(test|spec|__tests__)'; then
  TOUCHES_TESTS=true
fi

# Complexity scoring
COMPLEXITY_SCORE=0
[ "$FILE_COUNT" -ge 3 ] && COMPLEXITY_SCORE=$((COMPLEXITY_SCORE + 1))
[ "$FILE_COUNT" -ge 6 ] && COMPLEXITY_SCORE=$((COMPLEXITY_SCORE + 1))
[ "$LOC_CHANGED" -ge 100 ] && COMPLEXITY_SCORE=$((COMPLEXITY_SCORE + 1))
[ "$LOC_CHANGED" -ge 300 ] && COMPLEXITY_SCORE=$((COMPLEXITY_SCORE + 1))
[ "$NEW_FILES" -ge 2 ] && COMPLEXITY_SCORE=$((COMPLEXITY_SCORE + 1))
[ "$TOUCHES_TESTS" = "false" ] && [ "$LOC_CHANGED" -ge 50 ] && COMPLEXITY_SCORE=$((COMPLEXITY_SCORE + 1))

# Determine complexity level
if [ "$COMPLEXITY_SCORE" -ge 3 ]; then
  COMPLEXITY="complex"
else
  COMPLEXITY="simple"
fi

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  COMPLEXITY: $COMPLEXITY (score: $COMPLEXITY_SCORE/6)"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Files changed: $FILE_COUNT (new: $NEW_FILES, modified: $MODIFIED_FILES)"
echo "║  Lines changed: $LOC_CHANGED (+$INSERTIONS/-$DELETIONS)"
echo "║  Touches tests: $TOUCHES_TESTS"
echo "╚══════════════════════════════════════════════════════════════╝"
```

**Complexity signals:**

| Signal | Simple | Complex |
|--------|--------|---------|
| File count | 1-2 files | 3+ files |
| LOC changed | <100 lines | 100+ lines |
| New files | 0-1 new | 2+ new |
| Test coverage | Tests included | No tests with 50+ LOC |

**Pipeline adaptation based on complexity:**

| Complexity | Tests | Review (standalone) |
|------------|-------|---------------------|
| Simple | run-tests | quick review |
| Complex | run-tests | thorough review |

---

### Step 1: Verify Build (skip if DOCS_ONLY)
```bash
echo "=== Step 1: Build Verification ==="
```
Run `/conductor:verify-build`. If `passed: false` -> **STOP**, fix errors, re-run.

### Step 1a: Plugin Validator (ONLY if DOCS_ONLY)

When `DOCS_ONLY=true`, run the `plugin-validator` agent instead of build/test:

```bash
echo "=== Step 1a: Plugin Validation (markdown-only changes) ==="
```

**Invoke the plugin-validator agent** to validate the changed markdown files:

```
Task(subagent_type="plugin-dev:plugin-validator", prompt="Validate the following changed markdown files: <list files from git diff>. Check for: broken links, invalid YAML frontmatter, missing required sections, and consistent formatting.")
```

The agent will:
1. Check YAML frontmatter syntax in skill/agent files
2. Verify required fields are present (name, description, etc.)
3. Check for broken internal links
4. Validate markdown structure

If validation fails -> **STOP**, fix issues, re-run.
If validation passes -> Skip to **Step 3** (commit).

### Step 2: Run Tests (skip if DOCS_ONLY)
```bash
echo "=== Step 2: Test Verification ==="
```
Run `/conductor:run-tests`. If `passed: false` -> **STOP**, fix tests, re-run.

### Step 3: Commit Changes (skip if batched)

```bash
echo "=== Step 3: Commit ==="

if [ "$IS_BATCHED" = true ]; then
  echo "BATCHED MODE: Skipping commit step (commits done per-task in batched prompt)"
  echo "Verifying commits exist for all batched issues..."
  for ID in "${ISSUE_IDS[@]}"; do
    if git log --oneline --all | grep -q "$ID"; then
      echo "  ✓ $ID - commit found"
    else
      echo "  ✗ $ID - WARNING: no commit found with issue ID"
    fi
  done
else
  # Single issue mode - run commit command
  /conductor:commit-changes $ISSUE_ID
fi
```

**Single issue:** Run `/conductor:commit-changes <issue-id>`. Creates conventional commit with Claude signature.
**Batched:** Skip (commits already done per-task by worker following batched prompt template).

### Step 4-5: Non-blocking
```bash
echo "=== Step 4: Follow-up Tasks ==="
echo "=== Step 5: Documentation Check ==="
```
Run `/conductor:create-followups` and `/conductor:update-docs`. Log and continue.

### Step 5.5: Record Completion Info
```bash
echo "=== Step 5.5: Record Completion Info ==="

COMMIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
COMPLETED_AT=$(date -Iseconds)

# Function to record completion for a single issue
record_completion() {
  local ID="$1"
  local EXISTING_NOTES=$(bd show "$ID" --json 2>/dev/null | jq -r '.[0].notes // ""')

  # Append completion info to existing notes (includes complexity metrics)
  local NEW_NOTES="${EXISTING_NOTES}
completed_at: $COMPLETED_AT
commit: $COMMIT_SHA
complexity: $COMPLEXITY (score: $COMPLEXITY_SCORE)
files_changed: $FILE_COUNT
loc_changed: $LOC_CHANGED"

  bd update "$ID" --notes "$NEW_NOTES"
  echo "  Recorded completion for $ID"
}

if [ "$IS_BATCHED" = true ]; then
  echo "Recording completion for ${#ISSUE_IDS[@]} batched issues..."
  for ID in "${ISSUE_IDS[@]}"; do
    record_completion "$ID"
  done
else
  record_completion "$ISSUE_ID"
fi
```

This creates an audit trail with start time (from spawn), completion time, commit, and complexity metrics for analysis.

### Step 5.6: Update Agent Bead (WORKER MODE ONLY)

**Skip this step if EXECUTION_MODE=standalone.**

If this worker has an associated agent bead, update its state:

```bash
echo "=== Step 5.6: Update Agent Bead ==="

# Get agent ID from issue notes (set by bd-swarm-auto)
AGENT_ID=$(bd show "$ISSUE_ID" --json 2>/dev/null | grep -oP 'agent_id:\s*\K[^\s"]+' || echo "")

if [ -n "$AGENT_ID" ]; then
  # Set agent state to done
  bd agent state "$AGENT_ID" done

  # Clear the hook slot (detach from issue)
  bd slot clear "$AGENT_ID" hook

  echo "Agent $AGENT_ID marked as done"
else
  echo "No agent bead associated with this worker (standalone or legacy)"
fi
```

This enables monitoring workers via `bd list --type=agent` and dead detection via heartbeat.

### Step 6: Close Issue(s)
```bash
echo "=== Step 6: Close Issue(s) ==="

if [ "$IS_BATCHED" = true ]; then
  echo "Closing ${#ISSUE_IDS[@]} batched issues..."
  # bd close supports multiple IDs in a single command (more efficient)
  bd close "${ISSUE_IDS[@]}" --reason="Completed in batch"
  echo "  Closed: ${ISSUE_IDS[*]}"
else
  # Single issue - use close-issue command for standard behavior
  /conductor:close-issue "$ISSUE_ID"
fi
```

**Single issue:** Run `/conductor:close-issue <issue-id>`. Reports final status.
**Batched:** Use `bd close <id1> <id2> ...` to close all issues atomically.

### Step 6.5: Complexity-Aware Review (STANDALONE MODE ONLY)

**Skip this step if EXECUTION_MODE=worker.** Workers don't run code review - conductor handles unified review after merge.

In standalone mode, run complexity-aware code review:

```bash
if [ "$EXECUTION_MODE" = "standalone" ]; then
  echo "=== Step 6.5: Complexity-Aware Code Review ==="

  if [ "$COMPLEXITY" = "complex" ]; then
    echo "Complex changes detected - running thorough review..."
    # Run /conductor:code-review --thorough
  else
    echo "Simple changes detected - running quick review..."
    # Run /conductor:code-review --quick
  fi
fi
```

**Review mode selection:**

| Complexity | Review Mode | What It Does |
|------------|-------------|--------------|
| Simple | `--quick` | Lint + types + secrets only |
| Complex | `--thorough` | Parallel specialized reviewers |

**Invoke the appropriate review:**

For **simple** changes:
```
/conductor:code-review --quick
```

For **complex** changes:
```
/conductor:code-review --thorough
```

Review is non-blocking for the close step (already completed), but any blockers found should be addressed before pushing.

### Step 7: Notify Conductor (WORKER MODE ONLY)

**Skip this step if EXECUTION_MODE=standalone.**

**DO NOT SKIP THIS STEP in worker mode.** After closing the issue, notify the conductor:

**IMPORTANT:** Do not use `#` or other special shell characters at the START of notification messages. Shell interprets `#` as a comment, causing the message to not be submitted properly via tmux send-keys.

```bash
echo "=== Step 7: Notify Conductor ==="

# Get commit subject, strip newlines, truncate to 80 chars (prevents tmux corruption)
SUMMARY=$(git log -1 --format='%s' 2>/dev/null | tr -d '\n' | head -c 80 || echo 'committed')
WORKER_SESSION=$(tmux display-message -p '#{session_name}' 2>/dev/null || echo 'unknown')

# Build notification message based on batched mode
if [ "$IS_BATCHED" = true ]; then
  ISSUE_LIST="${ISSUE_IDS[*]}"
  NOTIFY_MSG="BATCH COMPLETE: ${ISSUE_IDS[*]} ($ISSUE_COUNT issues)"
else
  ISSUE_LIST="$ISSUE_ID"
  NOTIFY_MSG="WORKER COMPLETE: $ISSUE_ID - $SUMMARY"
fi

# Primary method: tmux send-keys (Claude Code queues messages, safe even mid-output)
CONDUCTOR_SESSION="${CONDUCTOR_SESSION:-}"
if [ -n "$CONDUCTOR_SESSION" ]; then
  # CRITICAL: -l for literal, sleep before C-m, no special chars at start
  tmux send-keys -t "$CONDUCTOR_SESSION" -l "$NOTIFY_MSG"
  sleep 0.5  # Increased delay - prevents race condition
  tmux send-keys -t "$CONDUCTOR_SESSION" C-m
  echo "Notified conductor via tmux"
fi

# Secondary: API broadcast for browser UIs (WebSocket - conductor can't receive this)
TOKEN=$(cat /tmp/tabz-auth-token 2>/dev/null)
if [ -n "$TOKEN" ]; then
  if [ "$IS_BATCHED" = true ]; then
    # Send batch notification with all issue IDs
    curl -s -X POST http://localhost:8129/api/notify \
      -H "Content-Type: application/json" \
      -H "X-Auth-Token: $TOKEN" \
      -d "{\"type\": \"batch-complete\", \"issueIds\": [$(echo "${ISSUE_IDS[@]}" | sed 's/ /","/g' | sed 's/^/"/;s/$/"/')], \"count\": $ISSUE_COUNT, \"session\": \"$WORKER_SESSION\"}" >/dev/null
  else
    curl -s -X POST http://localhost:8129/api/notify \
      -H "Content-Type: application/json" \
      -H "X-Auth-Token: $TOKEN" \
      -d "{\"type\": \"worker-complete\", \"issueId\": \"$ISSUE_ID\", \"summary\": \"$SUMMARY\", \"session\": \"$WORKER_SESSION\"}" >/dev/null
  fi
fi
```

**Why tmux is primary:** Claude Code in tmux can receive messages via tmux send-keys. The API broadcast is for browser UIs that have WebSocket listeners - tmux-based Claude sessions cannot receive WebSocket messages.

**Avoiding tmux corruption:**
- Always use `-l` flag (literal mode)
- Strip newlines from message content
- Include `sleep 0.5` before C-m
- Don't start messages with `#` (shell comment)

### Step 8: Standalone Next Steps (STANDALONE MODE ONLY)

**Skip this step if EXECUTION_MODE=worker.**

When running in standalone mode, display guidance for completing the workflow:

```bash
if [ "$EXECUTION_MODE" = "standalone" ]; then
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║  STANDALONE COMPLETION - Next Steps                          ║"
  echo "╠══════════════════════════════════════════════════════════════╣"
  echo "║  Issue closed. Complexity-aware review completed.            ║"
  echo "║  Complexity: $COMPLEXITY (score: $COMPLEXITY_SCORE/6)"
  echo "║                                                              ║"
  echo "║  Changes are committed but NOT pushed.                       ║"
  echo "║  Next step: bd sync && git push                              ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
fi
```

**Why standalone doesn't auto-push:** In standalone mode, you may want to make additional changes before pushing. The conductor handles push automatically for workers, but standalone users have full control.

---

## Atomic Commands Reference

| Command | Description |
|---------|-------------|
| `/conductor:verify-build` | Run build, report errors |
| `/conductor:run-tests` | Run tests if available |
| `/conductor:commit-changes` | Stage + commit with conventional format |
| `/conductor:create-followups` | Create follow-up beads issues |
| `/conductor:update-docs` | Check/update documentation |
| `/conductor:close-issue` | Close beads issue |

**Note:** `/conductor:code-review` is NOT used by workers. Code review runs at conductor level after merge (see `/conductor:wave-done`).

---

## Custom Pipelines

Compose commands for custom workflows:

**Standard worker completion:**
```
/conductor:verify-build
/conductor:run-tests
/conductor:commit-changes
/conductor:close-issue <id>
```

**Quick commit (skip tests):**
```
/conductor:verify-build
/conductor:commit-changes
/conductor:close-issue <id>
```

---

## Error Handling

| Step | On Failure |
|------|------------|
| Build | Show errors, stop pipeline |
| Tests | Show failures, stop pipeline |
| Commit | Show git errors, stop pipeline |
| Follow-ups | Non-blocking - log and continue |
| Docs | Non-blocking - log and continue |
| Close | Show beads errors |
| Notify | Non-blocking - log and continue |

---

## Re-running After Fixes

If the pipeline stopped:
1. Fix the issues
2. Run `/conductor:worker-done` again

The pipeline is idempotent - safe to re-run.

---

## After Completion

### Worker Mode

When `/conductor:worker-done` succeeds in worker mode:
- Issue is closed in beads
- Commit is on the feature branch
- Conductor notified via tmux
- Worker's job is done

**The conductor then:**
- Merges the feature branch to main
- Kills this worker's tmux session
- Removes the worktree (if bd-swarm)
- Deletes the feature branch

Workers do NOT kill their own session - the conductor handles cleanup after receiving the notification.

### Standalone Mode

When `/conductor:worker-done` succeeds in standalone mode:
- Issue is closed in beads
- Commit is on current branch (not pushed)
- No conductor to notify

**User should then:**
- Optionally run `/conductor:code-review` for code review
- Run `bd sync && git push` to push changes

---

## Review Policy

**Workers do NOT do code review or visual review.** All reviews happen at the conductor level after merge, not in individual workers.

### Why reviews are conductor-level only:

**Code Review:**
- Parallel workers running code review simultaneously causes resource contention
- Unified review after merge catches cross-worker interactions and combined code patterns
- Avoids duplicate review effort (workers reviewed individually, then conductor reviews again)

**Visual Review:**
- Parallel workers opening browser tabs fight over the same browser window
- Workers cannot create isolated tab groups (tabz_claude_group_* uses a single shared group)
- Unified visual review after merge provides better coverage with no conflicts

### Division of Responsibility

**Worker focus:** Implementation → Tests → Build → Commit → Close

**Conductor handles:** Merge → Unified Code Review → Visual QA → Final Push

See `/conductor:wave-done` for the full conductor pipeline.

---

## Reference Files

| File | Content |
|------|---------|
| `references/example-sessions.md` | Example output for different scenarios |

Execute this pipeline now.
