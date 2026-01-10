---
description: "Prepare beads backlog before work: refine priorities, enhance prompts with skill hints, match skills to issues, review ready tasks. Optional preparation phase before /conductor:bd-work or /conductor:bdc-swarm-auto."
---

# Plan - Backlog Preparation

Prepare the beads backlog before spawning workers. This is an **optional** phase that improves worker efficiency.

## Usage

```bash
/conductor:bd-plan
```

## Step 1: Select Planning Activity

Use AskUserQuestion to determine what planning activity to perform:

```
AskUserQuestion(
  questions: [{
    question: "What backlog planning activity do you want to perform?",
    header: "Activity",
    multiSelect: false,
    options: [
      {
        label: "Refine Backlog (Recommended)",
        description: "Analyze priorities, identify blockers, organize into waves"
      },
      {
        label: "Enhance Prompts",
        description: "Find relevant files and skills for ready issues"
      },
      {
        label: "Match Skills",
        description: "Run skill matcher and persist hints to issue notes"
      },
      {
        label: "Review Ready",
        description: "Show issues ready to work with no blockers"
      }
    ]
  }]
)
```

---

## Activity: Refine Backlog

Analyze the current backlog state and prepare for parallel work.

### Commands

```bash
# Current state overview
bd stats
echo ""

# Show ready issues (no blockers)
echo "=== Ready Issues (Wave 1) ==="
bd ready

# Show blocked issues
echo ""
echo "=== Blocked Issues ==="
bd blocked

# Find high-impact blockers (issues blocking others)
echo ""
echo "=== High-Impact Blockers (prioritize these) ==="
bd list --all --json | jq -r '.[] | select(.blocks | length > 0) | "\(.id): blocks \(.blocks | length) issues - \(.title)"' | sort -t':' -k2 -rn | head -10
```

### Wave Planning

After analyzing:
1. **Wave 1**: All issues from `bd ready` (can start immediately)
2. **Wave 2**: Issues unblocked after Wave 1 completes
3. **Wave 3**: Issues unblocked after Wave 2 completes

### Priority Adjustments

| Criterion | Action |
|-----------|--------|
| Blocks 3+ issues | Raise to P1 |
| Quick win (simple) | Raise to P2 |
| No dependents | Lower to P3 |
| User-facing bug | Raise to P1 |

```bash
# Adjust priority example
bd update <issue-id> --priority 1
```

---

## Activity: Enhance Prompts

Find relevant files and skills for ready issues, then **store prepared prompts in notes**.

### Commands

```bash
MATCH_SCRIPT="${CLAUDE_PLUGIN_ROOT:-./plugins/conductor}/scripts/match-skills.sh"

# For each ready issue, find skills, key files, and store prepared prompt
for ISSUE_ID in $(bd ready --json | jq -r '.[].id'); do
  ISSUE_JSON=$(bd show "$ISSUE_ID" --json)
  TITLE=$(echo "$ISSUE_JSON" | jq -r '.[0].title // ""')
  DESC=$(echo "$ISSUE_JSON" | jq -r '.[0].description // ""')
  LABELS=$(echo "$ISSUE_JSON" | jq -r '.[0].labels[]?' | tr '\n' ' ')

  echo "=== $ISSUE_ID: $TITLE ==="

  # Match skills (verified against available)
  SKILLS=$($MATCH_SCRIPT --verify "$TITLE $DESC $LABELS" 2>/dev/null)
  SKILL_NAMES=$(echo "$SKILLS" | grep -oE '/[a-z-]+:[a-z-]+' | sed 's|^/||' | tr '\n' ',' | sed 's/,$//')
  if [ -n "$SKILL_NAMES" ]; then
    echo "Skills: $SKILL_NAMES"
  fi

  # Find key files (based on keywords in title/description)
  KEY_FILES=""
  for keyword in $(echo "$TITLE $DESC" | tr ' ' '\n' | grep -E '^[a-z]{4,}$' | head -5); do
    FOUND=$(find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.md" \) 2>/dev/null | xargs grep -l "$keyword" 2>/dev/null | head -3)
    if [ -n "$FOUND" ]; then
      KEY_FILES="$KEY_FILES $FOUND"
    fi
  done
  KEY_FILES=$(echo "$KEY_FILES" | tr ' ' '\n' | sort -u | head -10 | tr '\n' ',' | sed 's/,$//')
  [ -n "$KEY_FILES" ] && echo "Files: $KEY_FILES"

  # Build skill load instructions (explicit /plugin:skill format)
  SKILL_LOADS=""
  for skill in $(echo "$SKILL_NAMES" | tr ',' ' '); do
    [ -n "$skill" ] && SKILL_LOADS="$SKILL_LOADS
- /$skill"
  done

  # Craft prepared prompt
  PREPARED_PROMPT="Fix beads issue $ISSUE_ID: \"$TITLE\"

## Skills to Load$SKILL_LOADS

## Context
$DESC

## Key Files
$KEY_FILES

## When Done
Run: /conductor:bdw-worker-done $ISSUE_ID"

  # Store prepared data in issue notes (YAML-like format)
  NOTES="prepared.skills: $SKILL_NAMES
prepared.files: $KEY_FILES
prepared.prompt: |
$(echo "$PREPARED_PROMPT" | sed 's/^/  /')"

  bd update "$ISSUE_ID" --notes "$NOTES"
  echo "Stored prepared prompt in notes"
  echo ""
done
```

### Output

For each issue:
- Matched skills to load (verified available)
- Key files relevant to the task
- **Stored in notes**: `prepared.skills`, `prepared.files`, `prepared.prompt`

Workers read `prepared.prompt` directly from notes - no exploration needed.

---

## Activity: Match Skills

Run the central skill matcher and persist results to beads issue notes.

### Commands

```bash
MATCH_SCRIPT="${CLAUDE_PLUGIN_ROOT:-./plugins/conductor}/scripts/match-skills.sh"

echo "=== Matching and Persisting Skills ==="

for ISSUE_ID in $(bd ready --json | jq -r '.[].id'); do
  ISSUE_JSON=$(bd show "$ISSUE_ID" --json)
  TITLE=$(echo "$ISSUE_JSON" | jq -r '.[0].title // ""')
  DESC=$(echo "$ISSUE_JSON" | jq -r '.[0].description // ""')
  LABELS=$(echo "$ISSUE_JSON" | jq -r '.[0].labels[]?' | tr '\n' ' ')

  # Match skills using central script (verified against available skills)
  SKILLS=$($MATCH_SCRIPT --verify "$TITLE $DESC $LABELS" 2>/dev/null)

  # Extract skill names for storage (e.g., "ui-styling, backend-development")
  SKILL_NAMES=$(echo "$SKILLS" | grep -oE '/[a-z-]+:[a-z-]+' | sed 's|^/||' | tr '\n' ',' | sed 's/,$//')

  if [ -n "$SKILL_NAMES" ]; then
    # Persist to beads notes
    $MATCH_SCRIPT --persist "$ISSUE_ID" "$SKILL_NAMES"
    echo "$ISSUE_ID: $SKILL_NAMES"
  else
    echo "$ISSUE_ID: (no skills matched)"
  fi
done

echo ""
echo "Skills persisted to issue notes. bd-swarm will read them automatically."
```

### Why Persist?

Skills are matched once during planning and stored in issue notes. When bd-swarm spawns workers, it reads from notes instead of re-matching - ensuring consistency across the workflow.

---

## Activity: Review Ready

Show issues ready to work with no blockers.

### Commands

```bash
echo "=== Issues Ready to Work ==="
bd ready

echo ""
echo "=== Summary by Priority ==="
echo "P0 (Critical): $(bd ready --json | jq '[.[] | select(.priority == 0)] | length')"
echo "P1 (High):     $(bd ready --json | jq '[.[] | select(.priority == 1)] | length')"
echo "P2 (Medium):   $(bd ready --json | jq '[.[] | select(.priority == 2)] | length')"
echo "P3 (Low):      $(bd ready --json | jq '[.[] | select(.priority == 3)] | length')"
echo "P4 (Backlog):  $(bd ready --json | jq '[.[] | select(.priority == 4)] | length')"

echo ""
echo "=== Ready Issues Detail ==="
bd ready --json | jq -r '.[] | "[\(.priority)] \(.id): \(.title)"' | sort -n
```

### Next Steps

After reviewing:
- Run `/conductor:bd-work <issue-id>` for single issue (YOU do the work)
- Run `/conductor:bdc-swarm-auto` for autonomous parallel work
- Run `/conductor:bd-plan` again with "Enhance Prompts" to prepare prompts

---

## Flow Summary

```
/conductor:bd-plan
  │
  ├─> AskUserQuestion: "What planning activity?"
  │
  ├─> Refine Backlog
  │     └── bd stats, bd ready, bd blocked, priority analysis
  │
  ├─> Enhance Prompts
  │     └── Find files/skills for each ready issue
  │
  ├─> Match Skills
  │     └── Run match-skills.sh --persist for each ready issue
  │
  └─> Review Ready
        └── bd ready with priority breakdown
```

---

## Related

| Resource | Purpose |
|----------|---------|
| `/conductor:bd-work` | Single-session workflow (YOU do the work) |
| `/conductor:bdc-swarm-auto` | Autonomous parallel execution |
| `bd ready` | List issues ready to work |
| `bd blocked` | List blocked issues |

---

Execute the AskUserQuestion now to select an activity.
