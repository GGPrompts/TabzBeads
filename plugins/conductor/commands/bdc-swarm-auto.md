---
description: "Fully autonomous backlog completion. Runs waves until `bd ready` is empty. Self-resumable after /wipe. Use when you want hands-off parallel issue processing."
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
| 2 | Check/prepare prompts | Use prepared or explore |
| 3 | Calculate workers | Max 4, distribute issues |
| 4 | Create worktrees | Parallel, wait for all |
| 5 | Spawn workers | TabzChrome API |
| 6 | Send prompts | Skill-aware prompts with issue context |
| 7 | Poll status | Every 2 min, check context |
| 8 | Merge & cleanup | Kill sessions first |
| 9 | Visual QA | tabz-expert for UI waves |
| 10 | Next wave | Loop until empty |

---

## Phase: Prepare Prompts

Before spawning workers, ensure each issue has a quality prompt. This is critical for worker success.

### Check for Prepared Prompts

```bash
for ISSUE_ID in $READY; do
  NOTES=$(bd show "$ISSUE_ID" --json | jq -r '.[0].notes // ""')
  if echo "$NOTES" | grep -q "prepared.prompt:"; then
    echo "$ISSUE_ID: Using prepared prompt"
    PREPARED_ISSUES="$PREPARED_ISSUES $ISSUE_ID"
  else
    echo "$ISSUE_ID: Needs exploration"
    UNPREPARED_ISSUES="$UNPREPARED_ISSUES $ISSUE_ID"
  fi
done
```

### For Unprepared Issues: Quick Exploration

Spawn parallel Explore agents (haiku, fast) to gather context before crafting prompts:

```
for ISSUE_ID in $UNPREPARED_ISSUES:
  ISSUE_TITLE=$(bd show "$ISSUE_ID" --json | jq -r '.[0].title')
  ISSUE_DESC=$(bd show "$ISSUE_ID" --json | jq -r '.[0].description // ""')

  Task(
    subagent_type: "Explore",
    model: "haiku",
    run_in_background: true,
    description: "Explore for $ISSUE_ID",
    prompt: "Find relevant files and context for this issue:
      Title: $ISSUE_TITLE
      Description: $ISSUE_DESC

      Return:
      1. Key files (max 5) with brief explanation
      2. Related patterns or existing code to follow
      3. Skill keywords that apply (e.g., 'shadcn/ui', 'xterm.js', 'FastAPI')

      Be concise - this feeds into a worker prompt."
  )
```

Wait for all Explore agents to complete, then use their findings to craft prompts.

### Craft Prompt from Exploration

For each unprepared issue, build a prompt using the explore results.

**Start with a role** based on the domain detected:

```markdown
You are a [role based on exploration findings] working on [project context].

## Task: ISSUE-ID - Title

[Explicit description of what to do, 2-3 sentences]

## Why This Matters

[Issue description with motivation]

## Key Files

- path/to/file.ts - [what to focus on here]
- path/to/related.ts - [why this is relevant]

## Guidance

Use the [matched-skill] skill to [specific purpose].
[Additional guidance based on patterns found]

If this task is complex, use subagents in parallel to explore further.

When you're done, run `/conductor:bdw-worker-done ISSUE-ID`
```

**Role examples by domain:**
- Frontend: "You are a frontend developer working on a React app with shadcn/ui"
- Backend: "You are a backend engineer implementing APIs with FastAPI"
- Plugin: "You are a Claude Code plugin developer creating skills and agents"
- Terminal: "You are a developer working on terminal integration with xterm.js"

### Use Prepared Prompt

For issues with `prepared.prompt` in notes, extract and use directly:

```bash
PROMPT=$(bd show "$ISSUE_ID" --json | jq -r '.[0].notes' | \
  sed -n '/prepared.prompt:/,/^[a-z_]*\.:/p' | sed '1d;$d')
```

The prepared prompt already contains skill keywords, key files, and approach from `/conductor:bd-plan`.

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
6. **VISUAL QA** - Spawn tabz-expert after UI waves
7. **MONITOR CONTEXT** - At 70%+, trigger `/restart` (NOT /wipe - needs hooks)

---

## Worker Prompt Best Practices

See `references/worker-prompt-guidelines.md` for full details. Key points:

### 1. Always Start with a Role

```markdown
You are a frontend developer working on a React dashboard with shadcn/ui.
```

### 2. Use Natural Skill Triggers

**Wrong:** `Load these skills: /frontend:ui-styling`

**Right:** "Use the ui-styling skill to ensure components match our design system."

### 3. Suggest Subagents for Complex Tasks

"If the scope is unclear, use subagents in parallel to explore the codebase first."

### 4. Example Complete Prompt

```markdown
You are a backend engineer implementing APIs with FastAPI.

## Task: TabzBeads-456 - Add user preferences endpoint

Create a GET/PUT endpoint for user preferences at /api/preferences.

## Why This Matters

Users need to persist settings like theme and notification preferences
across sessions. This enables the frontend dark mode toggle.

## Key Files

- src/api/routes/users.py - add the new route here
- src/models/user.py - preferences schema
- src/api/routes/settings.py - similar pattern to follow

## Guidance

Use the backend-development skill for FastAPI patterns.
Follow the existing route structure in users.py.
Include Pydantic validation for the preferences payload.

When you're done, run `/conductor:bdw-worker-done TabzBeads-456`
```

### Quick Reference: Skill Triggers

| Need | Natural Trigger |
|------|-----------------|
| UI styling | "Use the ui-styling skill to match our design patterns" |
| Plugin dev | "Use the plugin-dev skill to validate the manifest" |
| Terminal | "Use the xterm-js skill for resize handling" |
| Exploration | "Use subagents in parallel to find related files" |
| Deep thinking | Prepend "ultrathink" or "think step by step" |

---

## Visual QA with tabz-expert

After completing a wave with UI changes, spawn tabz-expert in a **separate terminal** for visual QA:

```bash
# Via TabzChrome API
curl -X POST http://localhost:8129/api/spawn \
  -H "X-Auth-Token: $(cat /tmp/tabz-auth-token)" \
  -d '{"name": "Visual QA", "command": "claude --agent tabz-expert --dangerously-skip-permissions"}'
```

tabz-expert can take screenshots, click elements, and verify UI changes work correctly.

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
