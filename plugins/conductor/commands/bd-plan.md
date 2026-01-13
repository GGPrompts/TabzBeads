---
name: "bd-plan"
description: "Prepare beads backlog before work: analyze state, match skills, estimate complexity, enhance prompts. Runs full pipeline automatically."
---

# Plan - Backlog Preparation

Prepare the beads backlog before spawning workers. Runs all preparation steps automatically.

## Usage

```bash
/conductor:bd-plan
```

---

## Execute Full Pipeline

Run all steps in sequence. No menu - just execute.

### Step 1: Analyze Backlog State

```bash
echo "═══════════════════════════════════════════════════════════════"
echo "  STEP 1: ANALYZE BACKLOG STATE"
echo "═══════════════════════════════════════════════════════════════"

bd stats
echo ""

echo "=== Ready Issues (Wave 1) ==="
bd ready
echo ""

echo "=== Blocked Issues ==="
bd blocked
echo ""

echo "=== High-Impact Blockers (prioritize these) ==="
bd list --all --json 2>/dev/null | jq -r '.[] | select(.blocks | length > 0) | "\(.id): blocks \(.blocks | length) issues - \(.title)"' | sort -t':' -k2 -rn | head -10

echo ""
echo "=== Priority Adjustments ==="

# Auto-adjust priorities based on blocking relationships
for ISSUE_ID in $(bd list --status=open --json 2>/dev/null | jq -r '.[].id'); do
  ISSUE_JSON=$(bd show "$ISSUE_ID" --json 2>/dev/null)
  BLOCKS_COUNT=$(echo "$ISSUE_JSON" | jq -r '.[0].blocks | length')
  CURRENT_PRIORITY=$(echo "$ISSUE_JSON" | jq -r '.[0].priority // 2')
  TITLE=$(echo "$ISSUE_JSON" | jq -r '.[0].title // ""')
  TITLE_LOWER=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]')

  NEW_PRIORITY=$CURRENT_PRIORITY
  REASON=""

  # Rule: Blocks 3+ issues → P1
  if [ "$BLOCKS_COUNT" -ge 3 ] && [ "$CURRENT_PRIORITY" -gt 1 ]; then
    NEW_PRIORITY=1
    REASON="blocks $BLOCKS_COUNT issues"
  # Rule: Blocks 1-2 issues → at least P2
  elif [ "$BLOCKS_COUNT" -ge 1 ] && [ "$CURRENT_PRIORITY" -gt 2 ]; then
    NEW_PRIORITY=2
    REASON="blocks $BLOCKS_COUNT issue(s)"
  # Rule: Bug in title → P1
  elif echo "$TITLE_LOWER" | grep -qE '\bbug\b|crash|broken|fail'; then
    if [ "$CURRENT_PRIORITY" -gt 1 ]; then
      NEW_PRIORITY=1
      REASON="bug/crash detected"
    fi
  fi

  if [ "$NEW_PRIORITY" != "$CURRENT_PRIORITY" ]; then
    bd update "$ISSUE_ID" --priority "$NEW_PRIORITY" 2>/dev/null
    echo "↑ $ISSUE_ID: P$CURRENT_PRIORITY → P$NEW_PRIORITY ($REASON)"
  fi
done

echo "(Priorities adjusted based on blocking relationships and keywords)"
```

### Step 2: Match Skills & Persist

```bash
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  STEP 2: MATCH SKILLS & PERSIST"
echo "═══════════════════════════════════════════════════════════════"

MATCH_SCRIPT="${CLAUDE_PLUGIN_ROOT:-./plugins/conductor}/scripts/match-skills.sh"

for ISSUE_ID in $(bd ready --json 2>/dev/null | jq -r '.[].id'); do
  ISSUE_JSON=$(bd show "$ISSUE_ID" --json 2>/dev/null)
  TITLE=$(echo "$ISSUE_JSON" | jq -r '.[0].title // ""')
  DESC=$(echo "$ISSUE_JSON" | jq -r '.[0].description // ""')
  LABELS=$(echo "$ISSUE_JSON" | jq -r '.[0].labels[]?' 2>/dev/null | tr '\n' ' ')

  # Match skills using central script
  SKILL_KEYWORDS=$($MATCH_SCRIPT --verify "$TITLE $DESC $LABELS" 2>/dev/null | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')

  if [ -n "$SKILL_KEYWORDS" ]; then
    $MATCH_SCRIPT --persist "$ISSUE_ID" "$SKILL_KEYWORDS" 2>/dev/null
    echo "$ISSUE_ID: $SKILL_KEYWORDS"
  else
    echo "$ISSUE_ID: (no skills matched)"
  fi
done

echo ""
echo "Skills persisted to issue notes."
```

### Step 3: Estimate Complexity (S/M/L)

```bash
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  STEP 3: ESTIMATE COMPLEXITY"
echo "═══════════════════════════════════════════════════════════════"

for ISSUE_ID in $(bd ready --json 2>/dev/null | jq -r '.[].id'); do
  ISSUE_JSON=$(bd show "$ISSUE_ID" --json 2>/dev/null)
  TITLE=$(echo "$ISSUE_JSON" | jq -r '.[0].title // ""' | tr '[:upper:]' '[:lower:]')
  DESC=$(echo "$ISSUE_JSON" | jq -r '.[0].description // ""' | tr '[:upper:]' '[:lower:]')
  TEXT="$TITLE $DESC"

  # Estimate complexity based on keywords
  COMPLEXITY="M"  # Default to Medium

  # Check for Large indicators first
  if echo "$TEXT" | grep -qE '(consolidate|audit|redesign|migrate|overhaul|refactor.*major|complete.*rewrite)'; then
    COMPLEXITY="L"
  # Check for Simple indicators
  elif echo "$TEXT" | grep -qE '(fix|typo|icon|rename|update|bump|tweak|adjust|minor|simple|quick)'; then
    COMPLEXITY="S"
  fi

  # Get current notes and update complexity
  CURRENT_NOTES=$(echo "$ISSUE_JSON" | jq -r '.[0].notes // ""')
  NEW_NOTES=$(echo "$CURRENT_NOTES" | grep -v '^complexity:' || true)
  NEW_NOTES="complexity: $COMPLEXITY
$NEW_NOTES"

  bd update "$ISSUE_ID" --notes "$NEW_NOTES" 2>/dev/null

  DISPLAY_TITLE=$(echo "$ISSUE_JSON" | jq -r '.[0].title // ""')
  echo "[$COMPLEXITY] $ISSUE_ID: $DISPLAY_TITLE"
done

echo ""
echo "=== Complexity Summary ==="
echo "Simple (S):  $(bd ready --json 2>/dev/null | jq '[.[] | select(.notes | test("complexity: S"))] | length' 2>/dev/null || echo 0) - can batch together"
echo "Medium (M):  $(bd ready --json 2>/dev/null | jq '[.[] | select(.notes | test("complexity: M"))] | length' 2>/dev/null || echo 0) - standard execution"
echo "Large (L):   $(bd ready --json 2>/dev/null | jq '[.[] | select(.notes | test("complexity: L"))] | length' 2>/dev/null || echo 0) - isolated execution"
```

### Step 4: Enhance Prompts (Find Files & Build)

```bash
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  STEP 4: ENHANCE PROMPTS"
echo "═══════════════════════════════════════════════════════════════"

MATCH_SCRIPT="${CLAUDE_PLUGIN_ROOT:-./plugins/conductor}/scripts/match-skills.sh"

for ISSUE_ID in $(bd ready --json 2>/dev/null | jq -r '.[].id'); do
  ISSUE_JSON=$(bd show "$ISSUE_ID" --json 2>/dev/null)
  TITLE=$(echo "$ISSUE_JSON" | jq -r '.[0].title // ""')
  DESC=$(echo "$ISSUE_JSON" | jq -r '.[0].description // ""')
  CURRENT_NOTES=$(echo "$ISSUE_JSON" | jq -r '.[0].notes // ""')

  echo "=== $ISSUE_ID: $TITLE ==="

  # Get already-persisted skills
  SKILL_KEYWORDS=$(echo "$CURRENT_NOTES" | grep -oP '^skills:\s*\K.*' | head -1)

  # Find key files (quick search, max 10 files)
  KEY_FILES=""
  for keyword in $(echo "$TITLE $DESC" | tr ' ' '\n' | grep -E '^[a-z]{4,}$' | head -5); do
    FOUND=$(find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.py" -o -name "*.md" \) \
      -not -path "*/node_modules/*" -not -path "*/.venv/*" -not -path "*/.git/*" 2>/dev/null | \
      xargs grep -l "$keyword" 2>/dev/null | head -3)
    [ -n "$FOUND" ] && KEY_FILES="$KEY_FILES $FOUND"
  done
  KEY_FILES=$(echo "$KEY_FILES" | tr ' ' '\n' | sort -u | head -10 | tr '\n' ',' | sed 's/,$//')

  [ -n "$KEY_FILES" ] && echo "Files: $KEY_FILES"

  # Build enhanced prompt
  SKILL_CONTEXT=""
  [ -n "$SKILL_KEYWORDS" ] && SKILL_CONTEXT="

## Relevant Skills
$SKILL_KEYWORDS"

  PREPARED_PROMPT="Fix beads issue $ISSUE_ID: \"$TITLE\"

## Context
$DESC$SKILL_CONTEXT

## Key Files
$KEY_FILES

## When Done
Run: /conductor:bdw-worker-done $ISSUE_ID"

  # Store in notes (preserve existing complexity)
  COMPLEXITY_LINE=$(echo "$CURRENT_NOTES" | grep '^complexity:' | head -1)
  SKILLS_LINE=$(echo "$CURRENT_NOTES" | grep '^skills:' | head -1)

  NEW_NOTES="$COMPLEXITY_LINE
$SKILLS_LINE
prepared.files: $KEY_FILES
prepared.prompt: |
$(echo "$PREPARED_PROMPT" | sed 's/^/  /')"

  bd update "$ISSUE_ID" --notes "$NEW_NOTES" 2>/dev/null
  echo "Stored prepared prompt"
  echo ""
done
```

### Step 5: Generate Wave Plan

```bash
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  STEP 5: WAVE PLAN"
echo "═══════════════════════════════════════════════════════════════"

echo ""
echo "## Wave 1 (Start Now)"
echo ""
echo "| Issue | Type | Priority | Complexity | Skills |"
echo "|-------|------|----------|------------|--------|"

for ISSUE_ID in $(bd ready --json 2>/dev/null | jq -r '.[].id'); do
  ISSUE_JSON=$(bd show "$ISSUE_ID" --json 2>/dev/null)
  TITLE=$(echo "$ISSUE_JSON" | jq -r '.[0].title // ""' | cut -c1-40)
  TYPE=$(echo "$ISSUE_JSON" | jq -r '.[0].type // "task"')
  PRIORITY=$(echo "$ISSUE_JSON" | jq -r '.[0].priority // 2')
  NOTES=$(echo "$ISSUE_JSON" | jq -r '.[0].notes // ""')
  COMPLEXITY=$(echo "$NOTES" | grep -oP '^complexity:\s*\K[SML]' | head -1)
  SKILLS=$(echo "$NOTES" | grep -oP '^skills:\s*\K.*' | head -1 | cut -c1-30)

  echo "| $ISSUE_ID | $TYPE | P$PRIORITY | $COMPLEXITY | $SKILLS |"
done

echo ""
echo "## Parallelization Groups (can run simultaneously)"
echo ""
echo "Issues in different groups have no file overlap - safe to run in parallel workers."
echo ""

# Group by detected area based on title/skills
declare -A FRONTEND_ISSUES=()
declare -A BACKEND_ISSUES=()
declare -A INFRA_ISSUES=()
declare -A OTHER_ISSUES=()

for ISSUE_ID in $(bd ready --json 2>/dev/null | jq -r '.[].id'); do
  ISSUE_JSON=$(bd show "$ISSUE_ID" --json 2>/dev/null)
  TITLE=$(echo "$ISSUE_JSON" | jq -r '.[0].title // ""')
  TITLE_LOWER=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]')
  NOTES=$(echo "$ISSUE_JSON" | jq -r '.[0].notes // ""')
  SKILLS=$(echo "$NOTES" | grep -oP '^skills:\s*\K.*' | head -1 | tr '[:upper:]' '[:lower:]')

  AREA="other"

  # Detect area from title and skills
  if echo "$TITLE_LOWER $SKILLS" | grep -qE 'frontend|react|component|ui|css|tailwind|next|page|modal|button'; then
    AREA="frontend"
  elif echo "$TITLE_LOWER $SKILLS" | grep -qE 'backend|api|endpoint|fastapi|django|database|sql|model|connector|etl'; then
    AREA="backend"
  elif echo "$TITLE_LOWER $SKILLS" | grep -qE 'docker|ci|deploy|infra|kubernetes|terraform|github|workflow'; then
    AREA="infra"
  fi

  case "$AREA" in
    frontend) FRONTEND_ISSUES["$ISSUE_ID"]="$TITLE" ;;
    backend) BACKEND_ISSUES["$ISSUE_ID"]="$TITLE" ;;
    infra) INFRA_ISSUES["$ISSUE_ID"]="$TITLE" ;;
    *) OTHER_ISSUES["$ISSUE_ID"]="$TITLE" ;;
  esac
done

# Output groups
if [ ${#FRONTEND_ISSUES[@]} -gt 0 ]; then
  echo "**Frontend** (${#FRONTEND_ISSUES[@]} issues):"
  for ID in "${!FRONTEND_ISSUES[@]}"; do
    echo "  - $ID: ${FRONTEND_ISSUES[$ID]}"
  done
  echo ""
fi

if [ ${#BACKEND_ISSUES[@]} -gt 0 ]; then
  echo "**Backend** (${#BACKEND_ISSUES[@]} issues):"
  for ID in "${!BACKEND_ISSUES[@]}"; do
    echo "  - $ID: ${BACKEND_ISSUES[$ID]}"
  done
  echo ""
fi

if [ ${#INFRA_ISSUES[@]} -gt 0 ]; then
  echo "**Infrastructure** (${#INFRA_ISSUES[@]} issues):"
  for ID in "${!INFRA_ISSUES[@]}"; do
    echo "  - $ID: ${INFRA_ISSUES[$ID]}"
  done
  echo ""
fi

if [ ${#OTHER_ISSUES[@]} -gt 0 ]; then
  echo "**Other** (${#OTHER_ISSUES[@]} issues):"
  for ID in "${!OTHER_ISSUES[@]}"; do
    echo "  - $ID: ${OTHER_ISSUES[$ID]}"
  done
  echo ""
fi

TOTAL_GROUPS=0
[ ${#FRONTEND_ISSUES[@]} -gt 0 ] && ((TOTAL_GROUPS++))
[ ${#BACKEND_ISSUES[@]} -gt 0 ] && ((TOTAL_GROUPS++))
[ ${#INFRA_ISSUES[@]} -gt 0 ] && ((TOTAL_GROUPS++))
[ ${#OTHER_ISSUES[@]} -gt 0 ] && ((TOTAL_GROUPS++))

echo "→ Can spawn up to $TOTAL_GROUPS parallel workers (one per group)"

echo ""
echo "## Wave 2+ (After Dependencies Resolve)"
echo ""

BLOCKED_COUNT=$(bd blocked --json 2>/dev/null | jq 'length' 2>/dev/null || echo 0)
if [ "$BLOCKED_COUNT" -gt 0 ]; then
  bd blocked --json 2>/dev/null | jq -r '.[] | "- \(.id): \(.title) (blocked by: \(.depends_on | join(", ")))"'
else
  echo "No blocked issues - Wave 1 covers everything!"
fi
```

### Step 6: Summary & Next Steps

```bash
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  PLANNING COMPLETE"
echo "═══════════════════════════════════════════════════════════════"

READY_COUNT=$(bd ready --json 2>/dev/null | jq 'length' 2>/dev/null || echo 0)
BLOCKED_COUNT=$(bd blocked --json 2>/dev/null | jq 'length' 2>/dev/null || echo 0)

echo ""
echo "Ready to work: $READY_COUNT issues"
echo "Blocked:       $BLOCKED_COUNT issues"
echo ""
echo "All ready issues have:"
echo "  - Skills matched and persisted"
echo "  - Complexity estimated (S/M/L)"
echo "  - Prompts enhanced with key files"
echo ""
echo "Next steps:"
echo "  /conductor:bd-start <id>     - Work on single issue (YOU do it)"
echo "  /conductor:bd-conduct        - Interactive worker spawning"
echo "  /conductor:bdc-swarm-auto    - Autonomous parallel execution"
```

---

## Optional: Codex Second Opinion

For large backlogs (10+ issues), get external review:

```bash
# Check if worth running Codex
OPEN_COUNT=$(bd list --status=open --json 2>/dev/null | jq 'length' 2>/dev/null || echo 0)

if [ "$OPEN_COUNT" -ge 10 ]; then
  echo ""
  echo "Large backlog detected ($OPEN_COUNT issues). Consider running Codex review:"
  echo "  mcp-cli call codex/codex '{\"prompt\": \"Review priorities: $(bd list --status=open --json | jq -c)\"}'
fi
```

---

## Complexity Heuristics

| Complexity | Keywords | Batching |
|------------|----------|----------|
| **S** (Simple) | fix, typo, rename, update, bump | Batch 2-3 together |
| **M** (Medium) | implement, add, create, extend | One per worker |
| **L** (Large) | consolidate, audit, redesign, migrate | Isolated, full context |

---

## Related

| Command | Purpose |
|---------|---------|
| `/conductor:bd-start` | Single-session workflow (YOU do the work) |
| `/conductor:bd-conduct` | Interactive worker spawning |
| `/conductor:bdc-swarm-auto` | Autonomous parallel execution |

---

Execute the full pipeline now.
