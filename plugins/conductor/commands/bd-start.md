---
description: "Grab a ready issue and start working on it directly (no worker spawn)"
---

# Beads Start - Standalone Issue Pickup

Grab a ready issue and start working on it directly in this session. Unlike `bd-work`, this doesn't spawn a worker - YOU are the worker.

## Quick Start

```bash
/conductor:bd-start              # Grab top priority ready issue
/conductor:bd-start TabzBeads-abc  # Start specific issue
```

---

## Workflow

```
1. Select issue       →  bd ready (pick top) or use provided ID
2. Claim issue        →  bd update <id> --status=in_progress
3. Load prepared prompt (if available)
4. Start working      →  You implement the fix/feature
5. Complete           →  /conductor:bdw-worker-done <id>
```

---

## Phase 1: Select Issue

If no issue ID provided, get the top ready issue:

```bash
# Get ready issues
bd ready

# Pick top priority
ISSUE_ID=$(bd ready --json | jq -r '.[0].id // empty')
```

If issue ID was provided as argument, use that directly.

---

## Phase 2: Get Issue Details and Claim

```bash
# Show full issue details
bd show "$ISSUE_ID"

# Claim the issue
bd update "$ISSUE_ID" --status=in_progress
```

---

## Phase 3: Check for Prepared Prompt

Issues prepared via `/conductor:bd-plan` have prompts stored in notes:

```bash
# Extract prepared prompt if available
NOTES=$(bd show "$ISSUE_ID" --json | jq -r '.[0].notes // ""')

if echo "$NOTES" | grep -q "prepared.prompt"; then
  echo "=== Prepared Prompt Found ==="
  # Extract and display the prepared prompt
  echo "$NOTES" | sed -n '/prepared.prompt:/,/^[a-z_]*:/p' | sed '1d;$d'
else
  echo "No prepared prompt - work from issue description"
fi
```

---

## Phase 4: Load Skills (if specified)

If the prepared prompt mentions skills, invoke them:

```bash
# Check for prepared skills
SKILLS=$(echo "$NOTES" | grep "prepared.skills:" | cut -d: -f2 | tr ',' '\n')

if [ -n "$SKILLS" ]; then
  echo "=== Skills to Load ==="
  echo "$SKILLS"
  echo ""
  echo "Invoke these skills before starting work."
fi
```

---

## Phase 5: Start Working

Now you have:
- Issue details from `bd show`
- Prepared prompt (if available)
- Skills to load (if specified)

**Start implementing the fix/feature.**

---

## Phase 6: Complete

When done, run the completion pipeline:

```bash
/conductor:bdw-worker-done <issue-id>
```

This will: verify build → run tests → commit → close issue.

Then push:
```bash
bd sync && git push
```

---

## Comparison

| Command | Who Works | Spawns Terminal | Use Case |
|---------|-----------|-----------------|----------|
| `/conductor:bd-start` | You | No | Standalone work in current session |
| `/conductor:bd-work` | Spawned worker | Yes | Conductor delegates to visible worker |
| `/conductor:bd-swarm` | Multiple workers | Yes | Parallel batch processing |

---

## Example Session

```
You: /conductor:bd-start

Claude: Found ready issue TabzBeads-xyz: "Add dark mode toggle"

=== Prepared Prompt ===
## Context
Add a dark mode toggle to the settings page.
This task involves: shadcn/ui components, Tailwind CSS styling, Radix UI

## Key Files
- src/components/Settings.tsx
- src/styles/theme.ts

## Approach
Add toggle component, wire to theme context...

=== Claimed ===
Issue marked as in_progress.

Starting work now...
```

---

Execute this workflow now.
