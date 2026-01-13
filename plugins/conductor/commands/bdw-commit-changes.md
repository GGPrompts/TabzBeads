---
description: "Stage and commit changes with conventional commit format."
---

# Commit Changes

Stage all changes and commit with conventional commit format. This is a standalone atomic command.

## Usage

```
/conductor:bdw-commit-changes
/conductor:bdw-commit-changes <issue-id>
/conductor:bdw-commit-changes <issue-id> <commit-type>
```

**Commit types:** `feat`, `fix`, `docs`, `refactor`, `test`, `chore`

## Prerequisites

Run these first:
- `/conductor:bdw-verify-build` - Ensure build passes
- `/conductor:bdw-run-tests` - Ensure tests pass
- `/conductor:bdw-code-review` or `/conductor:bdw-codex-review` - Ensure review passes

## Execute

### 1. Check for Changes

```bash
echo "=== Commit Changes ==="

# Check if there are changes to commit
if git diff --quiet && git diff --cached --quiet; then
  echo "No changes to commit"
  echo '{"committed": false, "reason": "no changes"}'
  exit 0
fi

git status --short
echo ""
```

### 2. Stage Changes

```bash
# Stage all changes
git add .

echo "Staged files:"
git diff --cached --name-only
echo ""
```

### 3. Determine Commit Type

Analyze changes to determine appropriate commit type:

| Change Pattern | Type |
|----------------|------|
| New files/features | `feat` |
| Bug fixes | `fix` |
| Documentation only | `docs` |
| Code restructuring | `refactor` |
| Test additions | `test` |
| Build/config changes | `chore` |

### 4. Create Commit

Use the conventional commit format with Claude Code signature:

```bash
# Variables (set these based on context)
TYPE="${COMMIT_TYPE:-feat}"       # feat, fix, docs, refactor, test, chore
SCOPE="${SCOPE:-}"                # Optional: component/area affected
DESCRIPTION="${DESCRIPTION:-}"    # Brief description
ISSUE_ID="${ISSUE_ID:-}"         # Optional: beads issue ID

# Build commit message
if [ -n "$SCOPE" ]; then
  HEADER="$TYPE($SCOPE): $DESCRIPTION"
else
  HEADER="$TYPE: $DESCRIPTION"
fi

# Create commit with heredoc (unquoted EOF for variable expansion)
git commit -m "$(cat <<EOF
$HEADER

${ISSUE_ID:+Implements $ISSUE_ID}

Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

**Note:** Claude should construct the actual commit message based on the changes. The heredoc uses unquoted `EOF` to enable variable expansion.

### 5. Verify Commit

```bash
echo ""
echo "Commit created:"
git log -1 --oneline

echo ""
echo '{"committed": true, "sha": "'$(git rev-parse --short HEAD)'"}'
```

## Output Format

Returns JSON on last line:

```json
{"committed": true, "sha": "abc1234"}
{"committed": false, "reason": "no changes"}
```

## Error Handling

If commit fails:
1. Check `git status` for issues
2. Resolve any conflicts
3. Re-run `/conductor:bdw-commit-changes`

## Composable With

- `/conductor:bdw-verify-build` - Run before commit
- `/conductor:bdw-run-tests` - Run before commit
- `/conductor:bdw-code-review` - Run before commit
- `/conductor:bdw-close-issue` - Run after commit
- `/conductor:bdw-worker-done` - Full pipeline that includes this
