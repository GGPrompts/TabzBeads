---
description: "Standard single-session workflow: claim issue, implement, verify, test, commit, close, push. YOU do the work - no spawning workers."
---

# Work - Single-Session Issue Workflow

Complete a beads issue in this session. You ARE the worker - no spawning, no orchestration.

## Usage

```bash
/conductor:work              # Select from ready issues
/conductor:work TabzBeads-abc  # Work on specific issue
```

---

## When to Use

Use this skill when:
- You want to work on an issue yourself (not spawn a worker)
- Single-session focus on one task
- Standard development workflow with full verification

For spawning workers to work in parallel, use `/conductor:bd-swarm` instead.

---

## Workflow Overview

```
1. Select issue       → bd ready (pick) or use provided ID
2. Claim issue        → bd update <id> --status=in_progress
3. Implement          → Write code, follow PRIME.md patterns
4. Verify build       → /conductor:verify-build
5. Run tests          → /conductor:run-tests
6. Commit changes     → /conductor:commit-changes
7. Close issue        → /conductor:close-issue <id>
8. Push               → bd sync && git push
```

---

## Phase 1: Select Issue

**If issue ID provided as argument:** Use it directly.

**If no issue ID provided:** Present ready issues to user:

```bash
bd ready
```

Then use AskUserQuestion:
- Question: "Which issue would you like to work on?"
- Header: "Issue"
- Options: Top 3-4 ready issues with format `<id> (P<priority>)` as label, issue title as description

After selection, get full details:
```bash
bd show <selected-id>
```

---

## Phase 2: Claim Issue

Mark the issue as in progress so others know you're working on it:

```bash
bd update <issue-id> --status=in_progress
```

---

## Phase 3: Implement

Do the actual work:

1. **Understand the task** - Read issue details, explore relevant files
2. **Follow project patterns** - Check PRIME.md or CLAUDE.md for conventions
3. **Write the code** - Implement the solution
4. **Self-review** - Check your changes make sense before verification

Use the Explore agent for context gathering if needed:
```markdown
Task(
  subagent_type="Explore",
  prompt="Find files relevant to: '<issue-title>'"
)
```

---

## Phase 4: Verification Pipeline

Run the atomic commands in sequence. Stop on any failure.

### Step 1: Verify Build
```bash
echo "=== Verify Build ==="
```
Run `/conductor:verify-build`. If it fails, fix errors and re-run.

### Step 2: Run Tests
```bash
echo "=== Run Tests ==="
```
Run `/conductor:run-tests`. If tests fail, fix them and re-run.

### Step 3: Commit Changes
```bash
echo "=== Commit Changes ==="
```
Run `/conductor:commit-changes`. Creates conventional commit with issue reference.

### Step 4: Close Issue
```bash
echo "=== Close Issue ==="
```
Run `/conductor:close-issue <issue-id>`.

### Step 5: Push
```bash
echo "=== Push ==="
bd sync && git push
```

---

## Atomic Commands Reference

| Command | Purpose |
|---------|---------|
| `/conductor:verify-build` | Run build, report errors |
| `/conductor:run-tests` | Run tests if available |
| `/conductor:commit-changes` | Stage + commit with conventional format |
| `/conductor:close-issue` | Close beads issue |

---

## Error Handling

| Phase | On Failure |
|-------|------------|
| Build | Fix errors, re-run verify-build |
| Tests | Fix tests, re-run run-tests |
| Commit | Resolve git issues, retry |
| Push | Resolve conflicts, retry |

The workflow is idempotent - safe to re-run after fixing issues.

---

## Comparison with Other Commands

| Command | Who does work? | Workers? | Use case |
|---------|---------------|----------|----------|
| `/conductor:work` | You (this session) | No | Standard single-session development |
| `/conductor:bd-work` | Spawned worker | 1 | Delegate to visible worker |
| `/conductor:bd-swarm` | Spawned workers | Multiple | Parallel batch processing |
| `/conductor:worker-done` | You (as worker) | N/A | Complete task when spawned by conductor |

---

## Example Session

```
> /conductor:work

[Runs bd ready, presents issues via AskUserQuestion]
User selects: TabzBeads-xyz "Add dark mode toggle"

[Claims issue]
$ bd update TabzBeads-xyz --status=in_progress

[Implements the feature - writes code, tests locally]

[Runs verification]
> /conductor:verify-build
Build passed!

> /conductor:run-tests
Tests passed!

> /conductor:commit-changes
Created commit: feat(ui): add dark mode toggle

> /conductor:close-issue TabzBeads-xyz
Issue closed.

[Pushes]
$ bd sync && git push
Done!
```

---

Execute this workflow now.
