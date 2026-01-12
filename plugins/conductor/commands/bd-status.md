---
name: "bd-status"
description: "Show beads issue tracker status overview"
---

# Beads Status - Quick Overview

Show a summary of the beads issue tracker status.

## Execute These Commands

```bash
echo "=== Beads Status ==="
echo ""

echo "📊 Summary:"
echo "  Open: $(bd list --status=open --json | jq length)"
echo "  In Progress: $(bd list --status=in_progress --json | jq length)"
echo "  Closed: $(bd list --status=closed --json | jq length)"

echo ""
echo "📋 Ready to Work (no blockers):"
bd ready 2>/dev/null || echo "  (no beads database found)"

echo ""
echo "🔧 In Progress:"
bd list --status=in_progress 2>/dev/null || echo "  (none)"

echo ""
echo "⏰ Recently Closed:"
bd list --status=closed --json | jq -r '.[] | "\(.id): \(.title)"' | tail -5 || echo "  (none)"
```

## After Running

Present the output in a clean format:

| Status | Count |
|--------|-------|
| Open | X |
| In Progress | Y |
| Closed | Z |

Then list ready work and in-progress items.

## Quick Commands Reference

```
bd ready              # What to work on next
bd show <id>          # View issue details
bd update <id> --status=in_progress  # Claim issue
bd close <id>         # Mark complete
perles                # Visual kanban board
```

Execute this workflow now.
