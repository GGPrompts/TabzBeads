---
description: "Prepare beads backlog before work: refine priorities, enhance prompts with skill hints, match skills to issues, review ready tasks. Optional preparation phase before /conductor:bd-work or /conductor:bdc-swarm-auto."
---

# Plan - Backlog Preparation

Prepare the beads backlog before spawning workers. This is an **optional** phase that improves worker efficiency.

## Usage

```bash
/conductor:bd-plan
```

## Step 0: Show Backlog Status

Before presenting options, show the current state of ready issues:

```bash
echo "=== Backlog Preparation Status ==="

# Count ready issues and their preparation state
READY_JSON=$(bd ready --json 2>/dev/null || echo "[]")
TOTAL=$(echo "$READY_JSON" | jq 'length')

if [ "$TOTAL" -eq 0 ]; then
  echo "No ready issues found. Run 'bd ready' to check for blockers."
else
  # Count prepared vs unprepared
  PREPARED=0
  UNPREPARED=0

  for ISSUE_ID in $(echo "$READY_JSON" | jq -r '.[].id'); do
    NOTES=$(bd show "$ISSUE_ID" --json 2>/dev/null | jq -r '.[0].notes // ""')
    if echo "$NOTES" | grep -q "prepared.prompt"; then
      PREPARED=$((PREPARED + 1))
    else
      UNPREPARED=$((UNPREPARED + 1))
    fi
  done

  echo "Ready: $TOTAL issues | Prepared: $PREPARED | Unprepared: $UNPREPARED"

  if [ "$UNPREPARED" -gt 0 ]; then
    echo "Tip: Run 'Enhance Prompts' to prepare $UNPREPARED issues for workers"
  else
    echo "All ready issues have prepared prompts - ready for /conductor:bd-swarm"
  fi
fi
echo ""
```

---

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
        label: "Estimate Complexity",
        description: "Assign S/M/L complexity to issues for batching"
      },
      {
        label: "Group Tasks",
        description: "Batch simple issues together for efficient worker spawning"
      },
      {
        label: "Review Ready",
        description: "Show issues ready to work with no blockers"
      },
      {
        label: "Codex Second Opinion",
        description: "Get GPT review of backlog priorities and issue quality"
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

  # Match skills (keyword phrases for skill-eval hook activation)
  SKILL_KEYWORDS=$($MATCH_SCRIPT --verify "$TITLE $DESC $LABELS" 2>/dev/null | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')
  if [ -n "$SKILL_KEYWORDS" ]; then
    echo "Skills: $SKILL_KEYWORDS"
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

  # Build skill context for prompt (uses keyword phrases directly)
  SKILL_CONTEXT=""
  [ -n "$SKILL_KEYWORDS" ] && SKILL_CONTEXT="

## Relevant Skills
$SKILL_KEYWORDS"

  # Craft prepared prompt (keyword phrases help skill-eval hook identify relevant skills)
  PREPARED_PROMPT="Fix beads issue $ISSUE_ID: \"$TITLE\"

## Context
$DESC$SKILL_CONTEXT

## Key Files
$KEY_FILES

## When Done
Run: /conductor:bdw-worker-done $ISSUE_ID"

  # Store prepared data in issue notes (YAML-like format)
  # Skills stored as keyword phrases (hook handles activation via natural language)
  NOTES="prepared.skills: $SKILL_KEYWORDS
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

  # Match skills using central script (returns keyword phrases)
  SKILL_KEYWORDS=$($MATCH_SCRIPT --verify "$TITLE $DESC $LABELS" 2>/dev/null | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')

  if [ -n "$SKILL_KEYWORDS" ]; then
    # Persist keyword phrases to beads notes
    $MATCH_SCRIPT --persist "$ISSUE_ID" "$SKILL_KEYWORDS"
    echo "$ISSUE_ID: $SKILL_KEYWORDS"
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

## Activity: Estimate Complexity

Analyze ready issues and assign complexity (S/M/L) for intelligent batching. Simple tasks can be grouped together, complex tasks stay isolated.

### Complexity Heuristics

| Complexity | Keywords | File Count | Description |
|------------|----------|------------|-------------|
| **S** (Simple) | fix, typo, icon, rename, update, bump | 1-2 files | Quick wins, can batch multiple |
| **M** (Medium) | implement, add, create, extend, refactor | 3-5 files | Standard tasks |
| **L** (Large) | consolidate, audit, redesign, migrate, overhaul | 6+ files | Complex, isolated execution |

### Commands

```bash
echo "=== Estimating Complexity for Ready Issues ==="

for ISSUE_ID in $(bd ready --json | jq -r '.[].id'); do
  ISSUE_JSON=$(bd show "$ISSUE_ID" --json)
  TITLE=$(echo "$ISSUE_JSON" | jq -r '.[0].title // ""' | tr '[:upper:]' '[:lower:]')
  DESC=$(echo "$ISSUE_JSON" | jq -r '.[0].description // ""' | tr '[:upper:]' '[:lower:]')
  TEXT="$TITLE $DESC"

  # Estimate complexity based on keywords
  COMPLEXITY="M"  # Default to Medium

  # Check for Large indicators first (highest priority)
  if echo "$TEXT" | grep -qE '(consolidate|audit|redesign|migrate|overhaul|refactor.*major|complete.*rewrite)'; then
    COMPLEXITY="L"
  # Check for Simple indicators
  elif echo "$TEXT" | grep -qE '(fix|typo|icon|rename|update|bump|tweak|adjust|minor|simple|quick)'; then
    COMPLEXITY="S"
  # Check for Medium indicators (explicit)
  elif echo "$TEXT" | grep -qE '(implement|add|create|extend|refactor|feature|enhance)'; then
    COMPLEXITY="M"
  fi

  # Get current notes and append/update complexity
  CURRENT_NOTES=$(echo "$ISSUE_JSON" | jq -r '.[0].notes // ""')

  # Remove existing complexity line if present, then add new one
  NEW_NOTES=$(echo "$CURRENT_NOTES" | grep -v '^complexity:' || true)
  NEW_NOTES="complexity: $COMPLEXITY
$NEW_NOTES"

  # Store in beads notes
  bd update "$ISSUE_ID" --notes "$NEW_NOTES"

  # Display result
  DISPLAY_TITLE=$(echo "$ISSUE_JSON" | jq -r '.[0].title // ""')
  echo "[$COMPLEXITY] $ISSUE_ID: $DISPLAY_TITLE"
done

echo ""
echo "=== Summary ==="
echo "Simple (S):  $(bd ready --json | jq '[.[] | select(.notes | test("complexity: S"))] | length' 2>/dev/null || echo 0) - can batch together"
echo "Medium (M):  $(bd ready --json | jq '[.[] | select(.notes | test("complexity: M"))] | length' 2>/dev/null || echo 0) - standard execution"
echo "Large (L):   $(bd ready --json | jq '[.[] | select(.notes | test("complexity: L"))] | length' 2>/dev/null || echo 0) - isolated execution"
```

### Batching Strategy

After estimation:
- **Simple (S)**: Can batch 2-3 together per worker session
- **Medium (M)**: One issue per worker session
- **Large (L)**: Dedicated worker with full context, no batching

Workers spawned by `/conductor:bd-swarm` can read `complexity` from notes to adjust execution strategy.

---

## Activity: Group Tasks

Combine simple issues into batches for efficient worker spawning. Reads complexity from notes (set by "Estimate Complexity" activity). Also detects file overlap to prevent merge conflicts.

### Grouping Rules

| Configuration | Worker Count | Notes |
|---------------|--------------|-------|
| 3 Simple (S) | 1 worker | Max efficiency, sequential commits |
| 2 Simple (S) | 1 worker | Good efficiency |
| 1 Medium + 1 Simple | 1 worker | Medium leads, simple follows |
| 1 Medium (M) | 1 worker | Standard execution |
| 1 Large (L) | 1 worker | Isolated, full context |
| Overlapping issues | Same batch OR separate waves | Prevent merge conflicts |

### Overlap Detection

Issues that may touch the same files are detected via:
- **Explicit files**: `prepared.files` in issue notes
- **Title keywords**: PascalCase components → `Component.tsx`
- **Skill overlap**: Same frontend/backend skill = conflict risk

Overlapping issues are grouped together (sequential execution) or assigned to different waves.

### Commands

```bash
MATCH_SCRIPT="${CLAUDE_PLUGIN_ROOT:-./plugins/conductor}/scripts/match-skills.sh"

echo "=== Grouping Ready Issues by Complexity + Overlap ==="

# Get all ready issue IDs
ALL_READY_IDS=$(bd ready --json | jq -r '.[].id' | tr '\n' ' ')

# Step 1: Detect file overlap FIRST
echo ""
echo "--- Checking for file overlap ---"
OVERLAP_PAIRS=$($MATCH_SCRIPT --detect-overlap "$ALL_READY_IDS" 2>/dev/null | grep -v "^No overlapping")

if [ -n "$OVERLAP_PAIRS" ]; then
  echo "Found overlapping issues (will group together):"
  echo "$OVERLAP_PAIRS" | while IFS='|' read -r ID1 ID2 REASON; do
    [ -z "$ID1" ] && continue
    echo "  $ID1 <-> $ID2 ($REASON)"
  done
else
  echo "No overlapping issues detected - safe for parallel execution"
fi
echo ""

# Step 2: Get overlap groups (issues that must run together)
OVERLAP_GROUPS=$($MATCH_SCRIPT --overlap-groups "$ALL_READY_IDS" 2>/dev/null | grep -v "^Issue groups")
declare -A ISSUE_OVERLAP_GROUP
GROUP_NUM=1
while read -r GROUP; do
  [ -z "$GROUP" ] && continue
  for ID in $GROUP; do
    ISSUE_OVERLAP_GROUP["$ID"]="$GROUP_NUM"
  done
  ((GROUP_NUM++))
done <<< "$OVERLAP_GROUPS"

# Step 3: Get complexity for each issue
declare -A SIMPLE_ISSUES=()
declare -A MEDIUM_ISSUES=()
declare -A LARGE_ISSUES=()

for ISSUE_ID in $ALL_READY_IDS; do
  [ -z "$ISSUE_ID" ] && continue
  ISSUE_JSON=$(bd show "$ISSUE_ID" --json)
  NOTES=$(echo "$ISSUE_JSON" | jq -r '.[0].notes // ""')
  TITLE=$(echo "$ISSUE_JSON" | jq -r '.[0].title // ""')

  # Extract complexity (default to M if not set)
  COMPLEXITY=$(echo "$NOTES" | grep -oP '^complexity:\s*\K[SML]' | head -1)
  [ -z "$COMPLEXITY" ] && COMPLEXITY="M"

  case "$COMPLEXITY" in
    S) SIMPLE_ISSUES["$ISSUE_ID"]="$TITLE" ;;
    M) MEDIUM_ISSUES["$ISSUE_ID"]="$TITLE" ;;
    L) LARGE_ISSUES["$ISSUE_ID"]="$TITLE" ;;
  esac
done

SIMPLE_COUNT=${#SIMPLE_ISSUES[@]}
MEDIUM_COUNT=${#MEDIUM_ISSUES[@]}
LARGE_COUNT=${#LARGE_ISSUES[@]}

echo "Found: $SIMPLE_COUNT Simple, $MEDIUM_COUNT Medium, $LARGE_COUNT Large"
echo ""

# Step 4: Create batches respecting overlap groups
BATCH_NUM=1
declare -A ASSIGNED_ISSUES=()

# Helper to check if issue is already assigned
is_assigned() {
  [ -n "${ASSIGNED_ISSUES[$1]}" ]
}

# Process overlap groups first - they MUST stay together
echo "--- Batching by overlap groups ---"
while read -r GROUP; do
  [ -z "$GROUP" ] && continue
  GROUP_SIZE=$(echo "$GROUP" | wc -w)

  # Skip single-issue groups (no overlap)
  [ "$GROUP_SIZE" -lt 2 ] && continue

  BATCH_ID="batch-$(printf '%03d' $BATCH_NUM)"
  echo "[$BATCH_ID] Overlap group ($GROUP_SIZE issues - sequential execution):"

  POSITION=1
  for ID in $GROUP; do
    if ! is_assigned "$ID"; then
      TITLE=""
      [ -n "${SIMPLE_ISSUES[$ID]}" ] && TITLE="${SIMPLE_ISSUES[$ID]} [S]"
      [ -n "${MEDIUM_ISSUES[$ID]}" ] && TITLE="${MEDIUM_ISSUES[$ID]} [M]"
      [ -n "${LARGE_ISSUES[$ID]}" ] && TITLE="${LARGE_ISSUES[$ID]} [L]"
      echo "  - $ID: $TITLE"
      $MATCH_SCRIPT --persist-batch "$ID" "$BATCH_ID" "$POSITION"
      ASSIGNED_ISSUES["$ID"]=1
      ((POSITION++))
    fi
  done

  ((BATCH_NUM++))
done <<< "$OVERLAP_GROUPS"

echo ""
echo "--- Batching remaining isolated issues ---"

# Process remaining Simple issues (batch up to 3 together)
SIMPLE_IDS=(${!SIMPLE_ISSUES[@]})
i=0
while [ $i -lt $SIMPLE_COUNT ]; do
  ID="${SIMPLE_IDS[$i]}"
  ((i++))

  # Skip if already assigned to overlap group
  is_assigned "$ID" && continue

  BATCH_ID="batch-$(printf '%03d' $BATCH_NUM)"
  BATCH_TITLES="  - $ID: ${SIMPLE_ISSUES[$ID]}"
  $MATCH_SCRIPT --persist-batch "$ID" "$BATCH_ID" "1"
  ASSIGNED_ISSUES["$ID"]=1
  COUNT=1

  # Try to add more simple issues (up to 3 total)
  while [ $COUNT -lt 3 ] && [ $i -lt $SIMPLE_COUNT ]; do
    NEXT_ID="${SIMPLE_IDS[$i]}"
    ((i++))

    is_assigned "$NEXT_ID" && continue

    BATCH_TITLES="$BATCH_TITLES\n  - $NEXT_ID: ${SIMPLE_ISSUES[$NEXT_ID]}"
    ((COUNT++))
    $MATCH_SCRIPT --persist-batch "$NEXT_ID" "$BATCH_ID" "$COUNT"
    ASSIGNED_ISSUES["$NEXT_ID"]=1
  done

  echo "[$BATCH_ID] Simple batch ($COUNT issues):"
  echo -e "$BATCH_TITLES"
  ((BATCH_NUM++))
done

# Process Medium issues
MEDIUM_IDS=(${!MEDIUM_ISSUES[@]})
for ID in "${MEDIUM_IDS[@]}"; do
  is_assigned "$ID" && continue

  BATCH_ID="batch-$(printf '%03d' $BATCH_NUM)"

  # Check if any unassigned simple issues can be paired
  PAIRED_SIMPLE=""
  for SID in "${SIMPLE_IDS[@]}"; do
    if ! is_assigned "$SID"; then
      PAIRED_SIMPLE="$SID"
      break
    fi
  done

  if [ -n "$PAIRED_SIMPLE" ]; then
    echo "[$BATCH_ID] Medium + Simple batch:"
    echo "  - $ID: ${MEDIUM_ISSUES[$ID]} (lead)"
    echo "  - $PAIRED_SIMPLE: ${SIMPLE_ISSUES[$PAIRED_SIMPLE]} (follow)"
    $MATCH_SCRIPT --persist-batch "$ID" "$BATCH_ID" "1"
    $MATCH_SCRIPT --persist-batch "$PAIRED_SIMPLE" "$BATCH_ID" "2"
    ASSIGNED_ISSUES["$ID"]=1
    ASSIGNED_ISSUES["$PAIRED_SIMPLE"]=1
  else
    echo "[$BATCH_ID] Medium (solo):"
    echo "  - $ID: ${MEDIUM_ISSUES[$ID]}"
    $MATCH_SCRIPT --persist-batch "$ID" "$BATCH_ID" "1"
    ASSIGNED_ISSUES["$ID"]=1
  fi

  ((BATCH_NUM++))
done

# Process Large issues (always isolated)
LARGE_IDS=(${!LARGE_ISSUES[@]})
for ID in "${LARGE_IDS[@]}"; do
  is_assigned "$ID" && continue

  BATCH_ID="batch-$(printf '%03d' $BATCH_NUM)"
  echo "[$BATCH_ID] Large (isolated):"
  echo "  - $ID: ${LARGE_ISSUES[$ID]}"
  $MATCH_SCRIPT --persist-batch "$ID" "$BATCH_ID" "1"
  ASSIGNED_ISSUES["$ID"]=1
  ((BATCH_NUM++))
done

echo ""
echo "=== Summary ==="
echo "Total batches: $((BATCH_NUM - 1))"
echo "Workers needed: $((BATCH_NUM - 1)) (vs $((SIMPLE_COUNT + MEDIUM_COUNT + LARGE_COUNT)) without batching)"

OVERLAP_BATCH_COUNT=$(echo "$OVERLAP_PAIRS" | grep -c '|' 2>/dev/null || echo 0)
if [ "$OVERLAP_BATCH_COUNT" -gt 0 ]; then
  echo "Overlap groups: $OVERLAP_BATCH_COUNT pairs detected and grouped"
fi

echo ""
echo "Batch IDs persisted to issue notes. Run /conductor:bdc-swarm-auto to spawn."
```

### Output Format

Each issue gets a `batch.id` field in its notes:
```yaml
complexity: S
batch.id: batch-001
batch.position: 1  # Position within batch (1, 2, or 3)
```

Workers read `batch.id` to know which issues to complete together. Position determines commit order.

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

## Activity: Codex Second Opinion

Get an external GPT review of your backlog for a fresh perspective. Useful for:
- Validating priorities
- Checking issue clarity
- Finding missing dependencies
- Suggesting improvements

### Commands

```bash
echo "=== Codex Backlog Review ==="

# Export current backlog state
BACKLOG=$(bd list --status=open --json | jq -c '.')
READY=$(bd ready --json | jq -c '.')
BLOCKED=$(bd blocked --json | jq -c '.' 2>/dev/null || echo '[]')

# Create review prompt
REVIEW_PROMPT="Review this project backlog and provide feedback:

OPEN ISSUES:
$BACKLOG

READY TO WORK:
$READY

BLOCKED:
$BLOCKED

Please analyze:
1. Are priorities appropriate? Any P3/P4 that should be higher?
2. Are issue descriptions clear enough to implement?
3. Are there missing dependencies between issues?
4. Any issues that could be combined or split?
5. Suggested order for tackling ready issues?

Be concise and actionable."
```

Then call Codex (check schema first with `mcp-cli info codex/codex`):

```bash
# Get Codex opinion
mcp-cli call codex/codex "{
  \"prompt\": $(echo "$REVIEW_PROMPT" | jq -Rs .)
}"
```

### Review Areas

| Area | What Codex Checks |
|------|-------------------|
| **Priorities** | P0-P4 assignments, urgency vs importance |
| **Clarity** | Can issues be implemented as described? |
| **Dependencies** | Missing blockers, implicit orderings |
| **Batching** | Issues that could be combined |
| **Gaps** | Missing follow-up work |

### When to Use

- Before starting a swarm (validate priorities)
- When backlog grows large (fresh eyes)
- After major feature completion (what's next?)
- When blocked on prioritization decisions

### Limitations

- Codex doesn't know your codebase deeply
- May suggest impractical combinations
- Treat as advisory, not authoritative

---

## Flow Summary

```
/conductor:bd-plan
  │
  ├─> Step 0: Show Backlog Status
  │     └── Ready: N issues | Prepared: X | Unprepared: Y
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
  ├─> Estimate Complexity
  │     └── Assign S/M/L complexity for batching strategy
  │
  ├─> Group Tasks
  │     └── Combine S/M/L issues into batches (3S, 1M+1S, 1L)
  │
  └─> Review Ready
        └── bd ready with priority breakdown
```

### Recommended Planning Flow

For optimal batching:
1. Run **Estimate Complexity** to assign S/M/L to issues
2. Run **Group Tasks** to create batches
3. Run `/conductor:bdc-swarm-auto` to spawn workers by batch

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
