---
description: "Run a conductor wave from the mol-conductor-wave template. Instantiate with: /conductor:bdc-run-wave <issue-ids>"
---

# Run Conductor Wave - Template-Based Wave Execution

Instantiate the `conductor-wave` molecule template to execute a wave of parallel workers.

## Usage

```bash
# Instantiate wave as wisp (ephemeral - recommended for normal use)
/conductor:bdc-run-wave TabzBeads-abc TabzBeads-def TabzBeads-ghi

# Instantiate wave as pour (persistent - for audit trail)
/conductor:bdc-run-wave --pour TabzBeads-abc TabzBeads-def
```

## Quick Reference

```bash
# Verify template exists
bd formula list

# Show template details
bd formula show conductor-wave

# Dry run (preview what will be created)
bd mol wisp conductor-wave --dry-run --var issues="TabzBeads-abc TabzBeads-def"
```

## What This Command Does

This command provides a convenient interface to the `conductor-wave` formula template.
It wraps `bd mol wisp/pour conductor-wave` with proper variable binding.

### Template Steps

The conductor-wave formula defines 17 steps across 3 phases:

**Phase 1 - Setup:**
1. Validate issue IDs
2. Check for batch assignments
3. Create worktrees (parallel)
4. Create agent beads for tracking

**Phase 2 - Execution:**
5. Spawn terminal workers
6. Send skill-aware prompts
7. Monitor worker status

**Phase 3 - Completion:**
8. Verify all workers completed
9. Review worker discoveries
10. Capture session transcripts
11. Kill worker sessions
12. Merge branches to main
13. Cleanup worktrees and branches
14. Build verification
15. Unified code review
16. Visual QA (if UI changes)
17. Sync and push

## Execute Now

Parse the issue IDs from the command arguments:

```bash
# Get issue IDs (passed as arguments or from bd ready)
ISSUES="$@"

if [ -z "$ISSUES" ]; then
  echo "No issues provided. Fetching ready issues..."
  ISSUES=$(bd ready --json | jq -r '.[].id' | head -4 | tr '\n' ' ')

  if [ -z "$ISSUES" ]; then
    echo "No ready issues found. Run 'bd ready' to check backlog."
    exit 1
  fi

  echo "Ready issues: $ISSUES"
fi

# Default to wisp (ephemeral) unless --pour flag present
if [[ "$*" == *"--pour"* ]]; then
  echo "Creating persistent wave (pour)..."
  bd mol pour conductor-wave --var issues="$ISSUES"
else
  echo "Creating ephemeral wave (wisp)..."
  bd mol wisp conductor-wave --var issues="$ISSUES"
fi
```

## Working with the Molecule

After instantiation, the molecule appears in beads as a set of linked issues:

```bash
# Show molecule structure
bd mol show <mol-id>

# Show current step
bd mol current <mol-id>

# View progress
bd mol progress <mol-id>
```

## When to Use This vs Direct Commands

| Scenario | Use |
|----------|-----|
| Want step-by-step tracking | This command (creates tracked molecule) |
| Want simple execution | `/conductor:bdc-swarm-auto` (embedded logic) |
| Debugging wave issues | This command with `--pour` for audit trail |
| Standard production run | `/conductor:bdc-swarm-auto` |

## Options

| Option | Description |
|--------|-------------|
| `--pour` | Create persistent molecule (syncs with git) |
| (default) | Create ephemeral wisp (auto-cleanup) |

## Variables

The conductor-wave template accepts these variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `issues` | Space-separated issue IDs | (required) |
| `max_workers` | Maximum concurrent workers | 4 |
| `skip_review` | Skip unified code review | false |
| `skip_visual_qa` | Skip visual QA step | true |

## Customizing Variables

```bash
# Via bd mol directly for full control
bd mol wisp conductor-wave \
  --var issues="TabzBeads-abc TabzBeads-def" \
  --var max_workers="2" \
  --var skip_review="true"
```

## Cleanup

Wisps (ephemeral) auto-cleanup on squash or burn:

```bash
# Complete molecule (creates digest)
bd mol squash <mol-id>

# Discard molecule (no trace)
bd mol burn <mol-id>
```

## Related Commands

| Command | Purpose |
|---------|---------|
| `/conductor:bdc-swarm-auto` | Autonomous wave loop (embedded, not templated) |
| `/conductor:bdc-wave-done` | Complete a wave (merge, review, cleanup) |
| `bd formula list` | List available templates |
| `bd mol progress` | Check molecule progress |
