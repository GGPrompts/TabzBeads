---
name: "bdw-close-issue"
user-invocable: false
description: "Close a beads issue with completion reason."
---

# Close Issue

Close a beads issue after work is complete. This is a standalone atomic command.

## Usage

```
/conductor:bdw-close-issue <issue-id>
/conductor:bdw-close-issue <issue-id> <reason>
```

## Prerequisites

Before closing, ensure:
- Build passes (`/conductor:bdw-verify-build`)
- Tests pass (`/conductor:bdw-run-tests`)
- Code reviewed (`/conductor:bdw-code-review` or `/conductor:bdw-codex-review`)
- Changes committed (`/conductor:bdw-commit-changes`)
- Follow-ups created (`/conductor:bdw-create-followups`)
- Docs updated (`/conductor:bdw-update-docs`)

## Execute

### 1. Verify Issue Exists

```bash
echo "=== Close Issue ==="

ISSUE_ID="${1:-$ISSUE_ID}"

if [ -z "$ISSUE_ID" ]; then
  echo "ERROR: No issue ID provided"
  echo "Usage: /conductor:bdw-close-issue <issue-id>"
  echo '{"closed": false, "error": "no issue ID"}'
  exit 1
fi

echo "Closing issue: $ISSUE_ID"
bd show "$ISSUE_ID" 2>/dev/null || {
  echo "ERROR: Issue $ISSUE_ID not found"
  echo '{"closed": false, "error": "issue not found"}'
  exit 1
}
echo ""
```

### 2. Generate Completion Summary

Summarize what was done:

```bash
# Get commit message as summary
SUMMARY=$(git log -1 --format="%s" 2>/dev/null || echo "Implemented")
echo "Summary: $SUMMARY"
```

### 3. Close the Issue

```bash
bd close "$ISSUE_ID" --reason "$SUMMARY"

if [ $? -eq 0 ]; then
  echo ""
  echo "Issue $ISSUE_ID closed"
  echo '{"closed": true, "issue": "'$ISSUE_ID'"}'
else
  echo ""
  echo "ERROR: Failed to close issue"
  echo '{"closed": false, "error": "bd close failed"}'
  exit 1
fi
```

### 4. Final Status

```bash
echo ""
echo "=== Task Complete ==="
echo "Issue: $ISSUE_ID"
echo "Branch: $(git branch --show-current)"
echo "Commit: $(git log -1 --oneline)"
```

## Output Format

```json
{"closed": true, "issue": "TabzChrome-abc"}
{"closed": false, "error": "issue not found"}
{"closed": false, "error": "bd close failed"}
```

## Error Handling

If close fails:
1. Check `bd show <issue-id>` to verify issue exists
2. Check issue status (may already be closed)
3. Check beads database connectivity

## After Closing

**The conductor is responsible for:**
- Merging the feature branch to main
- Killing worker's tmux session
- Removing the worktree
- Deleting the feature branch

**Workers do NOT:**
- Push to remote (unless explicitly asked)
- Kill their own session
- Merge branches

## Composable With

- `/conductor:bdw-commit-changes` - Run before closing
- `/conductor:bdw-create-followups` - Run before closing
- `/conductor:bdw-update-docs` - Run before closing
- `/conductor:bdw-worker-done` - Full pipeline that includes this
