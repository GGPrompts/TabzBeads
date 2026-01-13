---
description: "Grab a ready issue and start working on it directly (no worker spawn)"
---

# Beads Start - Standalone Issue Pickup

Grab a ready issue and start working on it directly in this session. Unlike `bd-conduct`, this doesn't spawn a worker - YOU are the worker.

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
  echo "No prepared prompt found"
fi
```

### If No Prepared Prompt

When no prepared prompt exists, you have options:

**Option A: Fork Enhancement (Recommended)**

Spawn a background sonnet Task to enhance while you continue:

```
Task(
  subagent_type: "general-purpose",
  model: "sonnet",
  run_in_background: true,
  description: "Enhance issue prompt",
  prompt: "Enhance beads issue $ISSUE_ID following the bdc-prompt-enhancer command.
    1. Get issue details: bd show $ISSUE_ID
    2. Match skills using scripts/match-skills.sh
    3. Find key files (max 10)
    4. Build structured prompt with Context, Skills, Files, When Done
    5. Store in notes as prepared.prompt
    Return 'Enhanced' when done."
)
```

Continue reading issue details while enhancement runs. Check notes after ~60s.

**Option B: Haiku Explorers (Complex Tasks)**

For tasks needing extensive codebase exploration:

```
Task(
  subagent_type: "Explore",
  model: "haiku",
  description: "Find relevant files for $ISSUE_ID",
  prompt: "Find all files relevant to: [issue title/description].
    Focus on: implementation files, tests, related components.
    Return file paths with brief explanations."
)
```

Use Explore agents when the issue spans multiple domains or you need deep codebase understanding before starting.

**Option C: Work from Description**

Skip enhancement and work directly from `bd show` output. Best for simple, well-described issues.

---

## Phase 4: Note Skill Keywords

The prepared prompt includes keyword phrases that trigger the skill-eval hook:

```bash
# Check for skill keywords in prepared notes
SKILL_KEYWORDS=$(echo "$NOTES" | grep "prepared.skills:" | cut -d: -f2)

if [ -n "$SKILL_KEYWORDS" ]; then
  echo "=== Skill Keywords ==="
  echo "$SKILL_KEYWORDS"
  echo ""
  echo "These keywords will activate relevant skills via the skill-eval hook."
fi
```

**Note:** Skills activate automatically based on keywords in your prompts - no explicit invocation needed.

---

## Phase 5: Start Working

Now you have:
- Issue details from `bd show`
- Prepared prompt with skill keywords (if available)

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
| `/conductor:bd-conduct` | Spawned worker(s) | Yes | Interactive orchestration (1-4 workers) |
| `/conductor:bdc-swarm-auto` | Spawned workers | Yes | Fully autonomous parallel processing |

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
