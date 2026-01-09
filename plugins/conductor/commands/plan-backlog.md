---
description: "Groom and organize beads issues into parallelizable waves for efficient multi-worker execution"
---

# Plan Backlog - Sprint Planning for Parallel Work

Analyze, organize, and prioritize beads issues to enable efficient parallel execution with multiple Claude workers.

## Quick Start

```bash
/conductor:plan-backlog
```

## Workflow Overview

| Phase | Purpose | Reference |
|-------|---------|-----------|
| 1. Analyze | Understand current state | `references/plan-backlog/analysis-phases.md` |
| 2. Parallelize | Find concurrent opportunities | `references/plan-backlog/analysis-phases.md` |
| 3. Break Down | Decompose epics | `references/plan-backlog/breakdown-prioritize.md` |
| 4. Prioritize | Optimize order | `references/plan-backlog/breakdown-prioritize.md` |
| 5. Plan | Generate sprint waves | `references/plan-backlog/sprint-planning.md` |
| 6. AI Analysis | Optional Codex insights | `references/plan-backlog/sprint-planning.md` |

---

## Quick Analysis

```bash
# Current state
bd stats
bd ready
bd blocked

# Count by status
echo "Open: $(bd list --status=open --json | jq 'length')"
echo "Ready: $(bd ready --json | jq 'length')"
echo "Blocked: $(bd blocked --json | jq 'length')"

# High-impact blockers (prioritize these)
bd list --all --json | jq -r '.[] | select(.blocks | length > 0) | "\(.id): blocks \(.blocks | length)"'

# Epic analysis - list children of an epic
bd list --filter-parent <epic-id>        # All issues under epic
bd ready --filter-parent <epic-id>       # Ready issues in epic
bd blocked --filter-parent <epic-id>     # Blocked issues in epic
```

---

## Parallelization Quick Check

```bash
# Independent issues - can run in parallel NOW
bd ready --json | jq -r '.[] | "\(.id): [\(.priority)] \(.title)"'
```

**Group by area:**
| Area | Indicators |
|------|------------|
| Frontend | UI, component, modal, style |
| Backend | API, server, endpoint |
| Terminal | xterm, pty, tmux |
| MCP | tool, mcp, browser |

---

## Generate Sprint Plan

### 1. Determine Workers

Ask: How many parallel workers? (2-5, recommend 3)

### 2. Match Issues to Skills & Persist

**Use the central skill matcher** (`scripts/match-skills.sh`) to analyze issues and persist skill hints:

```bash
# Find the script (works from project root or with CLAUDE_PLUGIN_ROOT)
MATCH_SCRIPT="${CLAUDE_PLUGIN_ROOT:-./plugins/conductor}/scripts/match-skills.sh"

# For each ready issue, match and persist skills
for ISSUE_ID in $(bd ready --json | jq -r '.[].id'); do
  ISSUE_JSON=$(bd show "$ISSUE_ID" --json)
  TITLE=$(echo "$ISSUE_JSON" | jq -r '.[0].title // ""')
  DESC=$(echo "$ISSUE_JSON" | jq -r '.[0].description // ""')
  LABELS=$(echo "$ISSUE_JSON" | jq -r '.[0].labels[]?' | tr '\n' ' ')

  # Match skills using central script (use --verify to filter to available skills)
  SKILLS=$($MATCH_SCRIPT --verify "$TITLE $DESC $LABELS")

  # Extract skill names for storage
  SKILL_NAMES=$(echo "$SKILLS" | grep -oE '[a-z]+-[a-z]+' | sort -u | tr '\n' ',' | sed 's/,$//')

  # Persist to beads notes (so bd-swarm can read them later)
  if [ -n "$SKILL_NAMES" ]; then
    $MATCH_SCRIPT --persist "$ISSUE_ID" "$SKILL_NAMES"
    echo "$ISSUE_ID: $SKILL_NAMES"
  fi
done
```

**Why persist?** Skills are matched once during planning and stored in issue notes. When bd-swarm spawns workers, it reads from notes instead of re-matching - ensuring consistency across the workflow.

### 3. Build Waves

- **Wave 1:** All `bd ready` issues (no blockers)
- **Wave 2:** Issues unblocked after Wave 1
- **Wave 3:** Issues unblocked after Wave 2

**Per-epic wave planning:**
```bash
# Plan waves for a specific epic
bd ready --filter-parent <epic-id>        # Wave 1 for this epic
bd blocked --filter-parent <epic-id>      # Future waves (resolve deps first)

# Example: Focus a swarm on one epic
bd ready --filter-parent TabzChrome-xyz --json | jq -r '.[].id' | xargs /conductor:bd-swarm
```

### 4. Output Format

```markdown
## Wave 1 (Start Now)
| Issue | Type | Priority | Skills (persisted) |
|-------|------|----------|--------------------|
| xxx | feature | P1 | ui-styling, backend-development |
| yyy | bug | P2 | xterm-js |

Skills have been persisted to issue notes. bd-swarm will read them automatically.

**Next steps:**
Spawn workers: `/conductor:bd-swarm xxx yyy`
```

---

## Epic Breakdown (Interactive)

```bash
# Find epics
bd list --all --json | jq -r '.[] | select(.type == "epic") | .id'

# Analyze epic children (use --filter-parent)
bd list --filter-parent <epic-id>         # All children of epic
bd ready --filter-parent <epic-id>        # Ready children (can start now)
bd blocked --filter-parent <epic-id>      # Blocked children (need deps resolved)

# Count children by status
echo "Total: $(bd list --filter-parent <epic-id> --json | jq 'length')"
echo "Ready: $(bd ready --filter-parent <epic-id> --json | jq 'length')"

# Create subtasks with deps
bd create --title="Design API" --type=task --priority=2
bd create --title="Implement backend" --type=task --priority=2
bd dep add impl-id design-id
```

---

## Priority Adjustments

| Criterion | Action |
|-----------|--------|
| Blocks 3+ issues | Raise to P1 |
| Quick win | Raise to P2 |
| No dependents | Lower to P3 |
| User-facing bug | Raise to P1 |

```bash
bd update <id> --priority 1
```

---

## AI-Assisted (Optional)

For large backlogs (10+ issues), use Codex for analysis:

```bash
# Analyze dependency graph
mcp-cli call codex/codex "$(bd list --all --json | jq -Rs '{prompt: "Analyze for parallelization: " + .}')"
```

See: `references/plan-backlog/sprint-planning.md` for full Codex prompts.

---

## Reference Files

| File | Content |
|------|---------|
| `analysis-phases.md` | Phase 1-2: State analysis, parallelization |
| `breakdown-prioritize.md` | Phase 3-4: Epic breakdown, priority tuning |
| `sprint-planning.md` | Phase 5-6: Wave generation, AI analysis |

---

## Notes

- Re-run after each wave completes to re-plan
- Use `bd comments <id> add "Progress: ..."` for status tracking
- Consider `/wipe` between major planning sessions
- For complex epics, use `ultrathink` prefix before breakdown

Execute this workflow now.
