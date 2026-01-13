---
name: bdw-worker-done
description: "Complete worker task: verify build, run tests, commit, and close issue. Code review happens at conductor level after merge. Invoke with /conductor:bdw-worker-done <issue-id>"
user-invocable: false
---

# Worker Done - Task Completion Orchestrator

Orchestrates the full task completion pipeline by composing atomic commands.

## Usage

```bash
/conductor:bdw-worker-done TabzChrome-abc

# Or if issue ID is in your task header:
/conductor:bdw-worker-done
```

## Pipeline Overview

| Step | Command | Blocking? | When |
|------|---------|-----------|------|
| 0 | Detect change types | No | Always |
| 0.5 | Detect complexity | No | Always |
| 1 | `/conductor:bdw-verify-build` | Yes | CHANGE_TYPE=code |
| 1a | `plugin-validator` agent | Yes | CHANGE_TYPE=plugin |
| 2 | `/conductor:bdw-run-tests` | Yes | CHANGE_TYPE=code |
| 3 | `/conductor:bdw-commit-changes` | Yes | Always |
| 4 | `/conductor:bdw-create-followups` | No | Always |
| 5 | `/conductor:bdw-update-docs` | No | Always |
| 5.5 | Record completion info | No | Always |
| 6 | `/conductor:bdw-close-issue` | Yes | Always |
| 6.5 | Complexity-aware review | No | Standalone only |
| 7 | Notify conductor | No | Worker only |

**CRITICAL: You MUST execute Step 7 after Step 6.** Workers that skip Step 7 force the conductor to poll, wasting resources.

**Plugin changes:** When changes are only markdown files or plugin config (`plugin.json`, `marketplace.json`, `hooks.json`), steps 1-2 are replaced with the `plugin-validator` agent. This validates plugin structure without running build/test.

**Code review happens at conductor level:** Workers do NOT run code review. The conductor runs unified code review after merging all worker branches (see `/conductor:bdc-wave-done`). This prevents conflicts when multiple workers run in parallel.

---

## Execute Pipeline

### Step 0: Detect Change Types
```bash
echo "=== Step 0: Detecting Change Types ==="
# Check what types of files changed (staged + unstaged)
git diff --cached --name-only
git diff --name-only
```

**Detection logic:**
1. Get list of all changed files (staged and unstaged)
2. Categorize: docs-only, plugin-only, or code changes
3. Set mode accordingly

**File categories:**

| Category | Extensions/Patterns | Validation |
|----------|-------------------|------------|
| Docs | `.md`, `.markdown` | plugin-validator |
| Plugin config | `plugin.json`, `marketplace.json`, `hooks.json` | plugin-validator |
| Plugin content | `plugins/**/*.md`, `skills/**/*.md`, `agents/**/*.md`, `commands/**/*.md` | plugin-validator |
| Code | Everything else | build + test |

```bash
# Get all changed files
CHANGED_FILES=$(git diff --cached --name-only; git diff --name-only)

if [ -z "$CHANGED_FILES" ]; then
  CHANGE_TYPE="none"
elif echo "$CHANGED_FILES" | grep -qvE '\.(md|markdown|json)$'; then
  # Has non-doc/non-json files = code changes
  CHANGE_TYPE="code"
elif echo "$CHANGED_FILES" | grep -qE '\.(json)$' | grep -qvE '(plugin|marketplace|hooks)\.json$'; then
  # Has JSON but not plugin config = code changes
  CHANGE_TYPE="code"
else
  # Only markdown and/or plugin config files
  CHANGE_TYPE="plugin"
fi
```

| CHANGE_TYPE | Action |
|-------------|--------|
| `none` | Skip to commit (no changes) |
| `plugin` | Run **Step 1a** (plugin-validator), skip build/test |
| `code` | Run full pipeline (Steps 1, 2, 3...) |

---

### Step 0.5: Detect Complexity

After detecting change types, analyze complexity to adapt the verification pipeline.

**Complexity signals:**

| Signal | Simple | Complex |
|--------|--------|---------|
| File count | 1-2 files | 3+ files |
| LOC changed | <100 lines | 100+ lines |
| New files | 0-1 new | 2+ new |
| Test coverage | Tests included | No tests with 50+ LOC |

**Pipeline adaptation:**

| Complexity | Review (standalone) |
|------------|---------------------|
| Simple | `--quick` (lint + types) |
| Complex | `--thorough` (parallel reviewers) |

Workers don't run code review - conductor handles unified review after merge.

---

### Step 1: Verify Build (CHANGE_TYPE=code)
```bash
echo "=== Step 1: Build Verification ==="
```
Run `/conductor:bdw-verify-build`. If `passed: false` -> **STOP**, fix errors, re-run.

### Step 1a: Plugin Validator (CHANGE_TYPE=plugin)

When only plugin files changed (markdown, `plugin.json`, `marketplace.json`, `hooks.json`), run the `plugin-validator` agent instead of build/test:

```bash
echo "=== Step 1a: Plugin Validation ==="
```

**Invoke the plugin-validator agent:**

```
Task(subagent_type="plugin-development:plugin-validator", prompt="Validate the plugin changes:

Changed files:
$CHANGED_FILES

Check for:
1. YAML frontmatter syntax in skill/agent/command files
2. Required fields present (name, description, etc.)
3. plugin.json/marketplace.json valid JSON with required fields
4. Correct directory structure (skills/<name>/SKILL.md pattern)
5. No orphaned references
")
```

The agent validates:
- Frontmatter syntax and required fields
- JSON config files (plugin.json, marketplace.json)
- Directory structure matches plugin patterns
- Internal references are valid

If validation fails -> **STOP**, fix issues, re-run.
If validation passes -> Skip to **Step 3** (commit).

### Step 2: Run Tests (CHANGE_TYPE=code)
```bash
echo "=== Step 2: Test Verification ==="
```
Run `/conductor:bdw-run-tests`. If `passed: false` -> **STOP**, fix tests, re-run.

### Step 3: Commit Changes
```bash
echo "=== Step 3: Commit ==="
```
Run `/conductor:bdw-commit-changes <issue-id>`. Creates conventional commit with Claude signature.

### Step 4-5: Non-blocking
```bash
echo "=== Step 4: Follow-up Tasks ==="
echo "=== Step 5: Documentation Check ==="
```
Run `/conductor:bdw-create-followups` and `/conductor:bdw-update-docs`. Log and continue.

### Step 5.5: Record Completion Info
```bash
echo "=== Step 5.5: Record Completion Info ==="

# Get existing notes and append completion info
EXISTING_NOTES=$(bd show "$ISSUE_ID" --json 2>/dev/null | jq -r '.notes // ""')
COMMIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Append completion info to existing notes
NEW_NOTES="${EXISTING_NOTES}
completed_at: $(date -Iseconds)
commit: $COMMIT_SHA"

bd update "$ISSUE_ID" --notes "$NEW_NOTES"
```

This creates an audit trail with start time (from spawn) and completion time + commit.

### Step 6: Close Issue
```bash
echo "=== Step 6: Close Issue ==="
```
Run `/conductor:bdw-close-issue <issue-id>`. Reports final status.

### Step 7: Notify Conductor (REQUIRED)

**DO NOT SKIP THIS STEP.** After closing the issue, notify the conductor:

```bash
echo "=== Step 7: Notify Conductor ==="

SUMMARY=$(git log -1 --format='%s' 2>/dev/null || echo 'committed')
WORKER_SESSION=$(tmux display-message -p '#{session_name}' 2>/dev/null || echo 'unknown')

# Primary method: tmux send-keys (Claude Code queues messages, safe even mid-output)
CONDUCTOR_SESSION="${CONDUCTOR_SESSION:-}"
if [ -n "$CONDUCTOR_SESSION" ]; then
  tmux send-keys -t "$CONDUCTOR_SESSION" -l "WORKER COMPLETE: $ISSUE_ID - $SUMMARY"
  sleep 0.3
  tmux send-keys -t "$CONDUCTOR_SESSION" C-m
  echo "Notified conductor via tmux"
fi

# Secondary: API broadcast for browser UIs (WebSocket - conductor can't receive this)
TOKEN=$(cat /tmp/tabz-auth-token 2>/dev/null)
if [ -n "$TOKEN" ]; then
  curl -s -X POST http://localhost:8129/api/notify \
    -H "Content-Type: application/json" \
    -H "X-Auth-Token: $TOKEN" \
    -d "{\"type\": \"worker-complete\", \"issueId\": \"$ISSUE_ID\", \"summary\": \"$SUMMARY\", \"session\": \"$WORKER_SESSION\"}" >/dev/null
fi
```

**Why tmux is primary:** Claude Code queues incoming messages even during output, so tmux send-keys is safe. The API broadcasts via WebSocket which browser UIs can receive, but tmux-based Claude sessions cannot.

---

## Atomic Commands Reference

| Command | Description |
|---------|-------------|
| `/conductor:bdw-verify-build` | Run build, report errors |
| `/conductor:bdw-run-tests` | Run tests if available |
| `/conductor:bdw-commit-changes` | Stage + commit with conventional format |
| `/conductor:bdw-create-followups` | Create follow-up beads issues |
| `/conductor:bdw-update-docs` | Check/update documentation |
| `/conductor:bdw-close-issue` | Close beads issue |

**Note:** `/conductor:bdw-code-review` is NOT used by workers. Code review runs at conductor level after merge (see `/conductor:bdc-wave-done`).

---

## Custom Pipelines

Compose commands for custom workflows:

**Standard worker completion:**
```
/conductor:bdw-verify-build
/conductor:bdw-run-tests
/conductor:bdw-commit-changes
/conductor:bdw-close-issue <id>
```

**Quick commit (skip tests):**
```
/conductor:bdw-verify-build
/conductor:bdw-commit-changes
/conductor:bdw-close-issue <id>
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
2. Run `/conductor:bdw-worker-done` again

The pipeline is idempotent - safe to re-run.

---

## After Notification

When `/conductor:bdw-worker-done` succeeds:
- Issue is closed in beads
- Commit is on the feature branch
- Conductor notified (if CONDUCTOR_SESSION set)
- Worker's job is done

**The conductor then:**
- Merges the feature branch to main
- Kills this worker's tmux session
- Removes the worktree (if bd-swarm)
- Deletes the feature branch

Workers do NOT kill their own session - the conductor handles cleanup after receiving the notification.

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

See `/conductor:bdc-wave-done` for the full conductor pipeline.

---

## Reference Files

| File | Content |
|------|---------|
| `references/example-sessions.md` | Example output for different scenarios |

Execute this pipeline now.
