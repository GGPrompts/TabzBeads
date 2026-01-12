---
name: bdc-swarm-auto
description: "Fully autonomous backlog completion. Runs waves until `bd ready` is empty. Self-resumable after /wipe. Use when you want hands-off parallel issue processing."
user-invocable: false
---

# BD Swarm Auto - Autonomous Backlog Completion

**YOU are the conductor. Execute this workflow autonomously. Do NOT ask the user for input.**

> **Subagent-capable.** This workflow uses `/conductor:bdc-wave-done` which explicitly spawns subagents (like `conductor:code-reviewer`) for isolated tasks while maintaining wave context in the main session.

## Architecture: Parallel Terminal Workers

Spawn **3-4 terminal workers max**, each handling 1-2 issues with skill-aware prompts.

```
BAD:  10 terminals x 1 issue each    -> statusline chaos
GOOD: 3-4 terminals with focused prompts -> smooth execution
```

---

## Quick Reference

| Step | Action | Reference |
|------|--------|-----------|
| 1 | Get ready issues | `bd ready --json` |
| 2 | Calculate workers | Max 4, distribute issues |
| 3 | Create worktrees | Parallel, wait for all |
| 4 | Spawn workers | TabzChrome API |
| 5 | Send prompts | Skill-aware prompts with issue context |
| 6 | Poll status | Every 2 min, check context |
| 7 | Merge & cleanup | Kill sessions first |
| 8 | Visual QA | tabz-manager for UI waves |
| 9 | Next wave | Loop until empty |

---

## EXECUTE NOW - Wave Loop

```bash
# Get ready issues (skip epics and gate issues)
READY=$(bd ready --json | jq -r '.[] | select(.type != "epic") | select(.title | test("GATE"; "i") | not) | .id')
[ -z "$READY" ] && echo "Backlog complete!" && exit 0

# Count and distribute to max 4 workers
ISSUES_COUNT=$(echo "$READY" | wc -l)
# 1-4: 1-2 workers, 5-8: 2-3 workers, 9+: 3-4 workers

# Create worktrees (parallel)
for ISSUE_ID in $READY; do
  ${CLAUDE_PLUGIN_ROOT}/scripts/setup-worktree.sh "$ISSUE_ID" &
done
wait

# Spawn workers, send prompts, monitor
# ... see references/wave-execution.md

# FULL CLOSEOUT: Use wave-done skill (recommended)
/conductor:bdc-wave-done $READY
# Runs: verify workers → kill sessions → merge → build → review → cleanup → push → summary

# QUICK CLEANUP (alternative, skip review):
# ${CLAUDE_PLUGIN_ROOT}/scripts/completion-pipeline.sh "$READY"

# Check for next wave
NEXT=$(bd ready --json | jq 'length')
[ "$NEXT" -gt 0 ] && echo "Starting next wave..." # LOOP
```

---

## Key Rules

1. **NO USER INPUT** - Fully autonomous, no AskUserQuestion
2. **MAX 4 TERMINALS** - Never spawn more than 4 workers
3. **SKILL-AWARE PROMPTS** - Include skill hints in worker prompts
4. **YOU MUST POLL** - Check issue status every 2 minutes
5. **LOOP UNTIL EMPTY** - Keep running waves until `bd ready` is empty
6. **VISUAL QA** - Spawn tabz-manager after UI waves
7. **MONITOR CONTEXT** - At 70%+, trigger `/restart` (NOT /wipe - needs hooks)

---

## Worker Prompt Template

```markdown
## Task: ISSUE-ID - Title

## Context
[WHY this matters - helps Claude generalize and make good decisions]
This task involves [domain keywords from match-skills.sh, e.g., "React components with shadcn/ui and Tailwind CSS styling"]

## Key Files
- path/to/file.ts (focus on lines X-Y)
- path/to/other.ts

## Approach
[Implementation guidance - what to do]

## When Done
Run `/conductor:bdw-worker-done ISSUE-ID`

**CRITICAL: Always use the pipeline - do NOT commit directly.**
The pipeline sends notifications to the conductor via tmux.
```

**KEYWORD-BASED SKILL ACTIVATION:** The skill-eval hook automatically detects domain keywords and activates relevant skills. Include keywords naturally in the Context section.

To get keyword phrases for an issue, run:
```bash
./plugins/conductor/scripts/match-skills.sh --issue ISSUE-ID
# Or match from text:
./plugins/conductor/scripts/match-skills.sh "backend api terminal"
```

| Domain | Keywords to Include |
|--------|---------------------|
| UI/Frontend | shadcn/ui components, Tailwind CSS styling, Radix UI |
| Terminal | xterm.js terminal, resize handling, FitAddon |
| Backend | backend development, REST API, Node.js, FastAPI |
| Auth | Better Auth, OAuth, JWT, session management |
| Browser | browser automation, MCP tools, screenshots |

**Prompt Guidelines:**
- **Use keywords naturally** - "This involves xterm.js terminal patterns" not "/xterm-js:xterm-js"
- **Be explicit** - "Fix null reference on line 45" not "fix the bug"
- **Add context** - Explain WHY to help Claude make good decisions
- **Reference patterns** - Point to existing code for consistency
- **File paths as text** - Workers read files on-demand, avoids bloat

**Full guidelines:** `references/worker-architecture.md`

---

## Visual QA with tabz-manager

After completing a wave with UI changes, spawn tabz-manager in a **separate terminal** for visual QA:

```bash
# Via TabzChrome API
curl -X POST http://localhost:8129/api/spawn \
  -H "X-Auth-Token: $(cat /tmp/tabz-auth-token)" \
  -d '{"name": "Visual QA", "command": "claude --agent conductor:tabz-manager --dangerously-skip-permissions"}'
```

tabz-manager can take screenshots, click elements, and verify UI changes work correctly.

---

## Context Recovery

At 70% context, use `/restart` (NOT `/wipe` - restart triggers session hooks that re-inject PRIME.md and beads context).

Before restarting, note the active state:
```bash
# Get in-progress issues
bd list --status=in_progress --json | jq -r '.[].id'
```

After restart, Claude will have fresh context with hooks re-injected. Run:
```
/conductor:bdc-swarm-auto
```

The skill will pick up where it left off by checking `bd ready` and `bd list --status=in_progress`.

---

## Auto vs Interactive

| Aspect | Auto | Interactive |
|--------|------|-------------|
| Worker count | All ready | Ask user |
| Waves | Loop until empty | One wave |
| Questions | Make defaults | AskUserQuestion ok |
| Context | Auto /wipe | Manual |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Worker not responding | `tmux capture-pane -t SESSION -p -S -50` |
| Merge conflicts | Resolve manually, continue |
| Worker stuck | Nudge via tmux send-keys |
| Worker failed | Check logs, re-spawn or close with 'needs-review' |

---

Execute this workflow NOW. Start with getting ready issues.
