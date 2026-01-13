---
description: "Multi-session Claude workflow orchestration. Spawn workers via TabzChrome, coordinate parallel tasks, use subagents for monitoring/exploration, manage beads issues. Use this skill when coordinating multiple Claude sessions or managing complex multi-step workflows."
---

# Orchestration Skill - Multi-Session Workflows

Orchestrate multiple Claude Code sessions, spawn workers, and coordinate parallel work.

> **Subagent pattern.** Orchestration skills (like wave-done, code-review) run in the main session to maintain conversation context. They explicitly spawn subagents (like `conductor:code-reviewer`) for isolated tasks that don't need parent context.

## Architecture

```
Vanilla Claude Session (you)
├── Task tool -> can spawn subagents
│   ├── conductor:code-reviewer (sonnet) - autonomous review
│   ├── conductor:silent-failure-hunter (sonnet) - error handling audit
│   └── conductor:skill-picker (haiku) - search/install from skillsmp.com
├── Commands for execution (invoked directly)
│   ├── /conductor:bdw-code-review - code review workflow
│   ├── /conductor:bdw-update-docs - update README/CHANGELOG/CLAUDE.md
│   └── /conductor:bdc-prompt-enhancer - enhance prompts for workers
├── Worktree setup via bd worktree create
├── Monitoring via beads agent tracking (bd agent, bd slot)
└── Terminal Workers via TabzChrome spawn API
    └── Each has full Task tool, can spawn own subagents
```

**Spawn subagent example:**
```
Task(
  subagent_type="conductor:code-reviewer",
  prompt="Review changes in feature/TabzChrome-abc branch"
)
```

### When to Use Main Session vs Subagents vs Commands

| Task Type | Run As | Why |
|-----------|--------|-----|
| **Orchestration** (wave-done, bd-conduct) | Main session | Needs conversation context, coordinates multiple steps |
| **Interactive** (bd-start, bd-plan) | Main session | User interaction, decisions, back-and-forth |
| **Code review** | Command `/bdw-code-review` | Runs in context, spawns code-reviewer subagent internally |
| **Docs update** | Command `/bdw-update-docs` | Runs in context, self-contained with anti-bloat rules |
| **Visual QA** | Subagent `tabz-expert` | Isolated: separate browser session, returns findings |
| **Skill search** | Subagent `skill-picker` | Isolated: searches skillsmp.com, installs to project |
| **Error audit** | Subagent `silent-failure-hunter` | Isolated: scans for swallowed errors |

**Key insight:** Commands run in your session (fast, maintains context). Subagents are for truly isolated tasks that benefit from fresh context.

---

## Terminal Management

### Spawning Claude Workers

```bash
TOKEN=$(cat /tmp/tabz-auth-token)
CONDUCTOR_SESSION=$(tmux display-message -p '#{session_name}')

# BD_SOCKET isolates beads daemon per worker (prevents conflicts in parallel workers)
RESPONSE=$(curl -s -X POST http://localhost:8129/api/spawn \
  -H "Content-Type: application/json" \
  -H "X-Auth-Token: $TOKEN" \
  -d "{\"name\": \"Claude: Task Name\", \"workingDir\": \"/path/to/project\", \"command\": \"BD_SOCKET=/tmp/bd-worker-ISSUE.sock CONDUCTOR_SESSION='$CONDUCTOR_SESSION' claude --dangerously-skip-permissions\"}")

SESSION=$(echo "$RESPONSE" | jq -r '.terminal.ptyInfo.tmuxSession')
```

- Always include "Claude:" in the name (enables status tracking)
- Always use `--dangerously-skip-permissions`
- Set `BD_SOCKET` to isolate beads daemon per worker (prevents daemon conflicts)
- Set `CONDUCTOR_SESSION` so workers can notify completion
- Response includes `terminal.ptyInfo.tmuxSession` - save for sending prompts

### Worker Completion Notifications

Workers notify the conductor via tmux send-keys:

```
Worker completes → /conductor:bdw-worker-done
                 → tmux send-keys to CONDUCTOR_SESSION
                 → Conductor receives message and processes
```

**How it works:**
1. Worker completes task and runs `/conductor:bdw-worker-done`
2. Worker sends message via `tmux send-keys -t "$CONDUCTOR_SESSION"`
3. Conductor receives the message in their Claude session

**Avoiding tmux corruption:**
- Use `-l` flag for literal mode
- Strip newlines from message content (`tr -d '\n'`)
- Include `sleep 0.5` before pressing enter (C-m)
- Don't start messages with `#` (interpreted as shell comment)

### Sending Prompts

**For multi-line prompts** (use load-buffer to avoid terminal corruption):

```bash
SESSION="ctt-claude-xxx"
sleep 4  # Wait for Claude to initialize

# Write prompt to temp file (handles special chars, code blocks safely)
PROMPT_FILE=$(mktemp)
cat > "$PROMPT_FILE" << 'PROMPT_EOF'
Your multi-line prompt here...
Can include backticks, quotes, code blocks.
PROMPT_EOF

# Load and paste (bypasses shell quoting issues)
tmux load-buffer "$PROMPT_FILE"
tmux paste-buffer -t "$SESSION"
sleep 0.3
tmux send-keys -t "$SESSION" C-m
rm "$PROMPT_FILE"
```

**For short one-liners** (send-keys is fine):

```bash
tmux send-keys -t "$SESSION" -l 'Simple prompt here'
sleep 0.3
tmux send-keys -t "$SESSION" C-m
```

### Kill and List

```bash
# Kill via API
curl -X DELETE http://localhost:8129/api/agents/ctt-xxx

# List active terminals
curl -s http://localhost:8129/api/agents | jq '.data[] | {id, name, state}'

# Kill all orphans directly
tmux ls | grep "^ctt-" | cut -d: -f1 | xargs -I {} tmux kill-session -t {}
```

---

## Crafting Skill-Aware Prompts

See `references/worker-prompt-guidelines.md` for full details. Key principles:

### 1. Always Start with a Role

Prime Claude for the task domain:

```markdown
You are a frontend developer working on a React dashboard with shadcn/ui.
```

### 2. Use Natural Skill Triggers

**Wrong:** Prescriptive skill loading
```markdown
Load these skills:
- /frontend:ui-styling
```

**Right:** Natural trigger phrases
```markdown
Use the ui-styling skill to ensure components match our design system.
If the scope is unclear, use subagents in parallel to explore first.
```

### 3. Complete Prompt Example

```markdown
You are a plugin developer creating Claude Code skills and agents.

## Task: TabzBeads-789 - Add validation to skill manifest

Add JSON schema validation for SKILL.md frontmatter.

## Why This Matters

Invalid manifests cause silent failures during skill loading. Validation
catches errors early and provides helpful error messages.

## Key Files

- src/skills/loader.ts - add validation here
- src/schemas/skill.json - schema definition
- tests/skills/validation.test.ts - add test cases

## Guidance

Use the plugin-dev skill to understand manifest requirements.
Follow the existing validation pattern in agents/loader.ts.

If you need to understand the full skill loading flow, use subagents
in parallel to trace through the codebase.

When you're done, run `/conductor:bdw-worker-done TabzBeads-789`
```

### Quick Reference: Natural Triggers

| Need | Trigger Phrase |
|------|----------------|
| UI styling | "Use the ui-styling skill to match our design patterns" |
| Plugin dev | "Use the plugin-dev skill to validate the manifest" |
| Terminal | "Use the xterm-js skill for terminal integration" |
| Exploration | "Use subagents in parallel to find related files" |
| Deep thinking | Prepend "ultrathink" or "think step by step" |
| Complex tasks | "If the scope is unclear, explore the codebase first" |

---

## Worker Completion

Workers should complete their tasks with the full pipeline:

```markdown
## When Done
Run `/conductor:bdw-worker-done ISSUE-ID`
```

This executes: verify-build → run-tests → commit → close-issue → notify-conductor

**Workers skip code review** - the conductor does unified review after merge (wave-done step 4).

The pipeline auto-detects mode:
- **Worker mode** (CONDUCTOR_SESSION set or in worktree): Skip review, skip push, notify conductor
- **Standalone mode**: Optional review, you push

---

## Parallel Workers

### Max 4 Terminals

```
BAD:  10 terminals x 1 issue each    -> statusline chaos
GOOD: 3-4 terminals with focused prompts -> smooth execution
```

### Use Worktrees for Isolation

```bash
# Create worktree (installs deps + builds)
${CLAUDE_PLUGIN_ROOT:-./plugins/conductor}/scripts/setup-worktree.sh "ISSUE_ID"
# Output: READY: /path/to/worktree

# Or use beads directly
bd worktree create TabzBeads-abc --branch feature/TabzBeads-abc
```

### Monitor Workers

```bash
# List running workers
bd list --type=agent --label="conductor:worker" --status=open

# Or use monitor script
${CLAUDE_PLUGIN_ROOT}/scripts/monitor-workers.sh --summary
```

---

## Wave Completion

After a wave of parallel workers finishes, use `/conductor:bdc-wave-done` to orchestrate completion:

```bash
# Complete a wave with specific issues
/conductor:bdc-wave-done TabzChrome-abc TabzChrome-def TabzChrome-ghi
```

**Pipeline:**
| Step | Description | Blocking? |
|------|-------------|-----------|
| 1 | Verify all workers completed | Yes - all issues must be closed |
| 2 | Kill worker sessions | No |
| 3 | Merge branches to main | Yes - stop on conflicts |
| 4 | Build verification | Yes |
| 5 | Unified code review | Yes - via /bdw-code-review command |
| 6 | Cleanup worktrees/branches | No |
| 7 | Visual QA (if UI changes) | Optional |
| 8 | Sync and push | Yes |

**Why unified review at wave level:** Workers do NOT run code review (to avoid conflicts when running in parallel). The conductor does the sole code review after merge, catching cross-worker interactions and ensuring combined changes work together.

---

## Subagents (via Task Tool)

| Subagent | Model | Purpose |
|----------|-------|---------|
| `conductor:code-reviewer` | sonnet | Autonomous review when spawned as subagent |
| `conductor:silent-failure-hunter` | sonnet | Scan for swallowed errors, empty catch blocks |
| `conductor:skill-picker` | haiku | Search/install skills from skillsmp.com (28k+ skills) |
| `tabz-expert` | opus | Browser automation (70+ MCP tools) - user-scope plugin |

> **Note:** Most review/docs tasks now use **commands** (bdw-code-review, bdw-update-docs) which run faster in your session. Use subagents only when you need truly isolated execution.

### Visual QA Between Waves

For UI changes, run visual QA before the next wave:

```
/conductor:bdc-visual-qa http://localhost:3000/dashboard http://localhost:3000/settings
```

This spawns `tabz-expert` in a forked context to:
- Screenshot changed pages
- Check browser console for errors
- Report findings before proceeding

**Example:**
```
Task(
  subagent_type="conductor:code-reviewer",
  prompt="Review changes in feature/beads-abc branch"
)
```

---

## Best Practices

1. **Use skill triggers** - Workers need explicit skill activation
2. **Include completion command** - Always end prompts with `/conductor:bdw-worker-done`
3. **Include conductor session in prompt** - Workers need this to notify completion
4. **Set BD_SOCKET per worker** - Isolates beads daemon, prevents conflicts
5. **Max 4 terminals** - Prevents statusline chaos
6. **Use worktrees** - Isolate workers to prevent file conflicts
7. **Use wave-done after parallel work** - Unified merge, review, cleanup
8. **Be explicit** - "Fix X on line Y" not "fix the bug"
9. **Clean up** - Kill sessions and remove worktrees when done

---

## Error Handling

```bash
# Backend not running
curl -s http://localhost:8129/api/health || echo "Start TabzChrome backend"

# Auth token missing
cat /tmp/tabz-auth-token || echo "Token missing - restart backend"

# Session not found
tmux has-session -t "$SESSION" 2>/dev/null || echo "Session does not exist"

# Worker stuck
tmux send-keys -t "$SESSION" -l 'Are you stuck? Please continue with the task.'
sleep 0.3
tmux send-keys -t "$SESSION" C-m
```

---

## Related Commands

| Command | Purpose |
|---------|---------|
| `/conductor:bd-start` | Single-session workflow (YOU do the work) |
| `/conductor:bd-plan` | Prepare backlog (refine, enhance prompts) |
| `/conductor:bd-conduct` | Interactive orchestration (1-4 workers) |
| `/conductor:bd-auto` | Fully autonomous (all ready, no prompts) |
| `/conductor:bdc-swarm-auto` | Internal: autonomous wave execution |
| `/conductor:bdc-wave-done` | Complete a wave of parallel workers |
| `/conductor:bdc-visual-qa` | Visual QA check (spawns tabz-expert) |
| `/conductor:bdw-code-review` | Code review command (spawns code-reviewer) |
| `/conductor:bdw-update-docs` | Update README/CHANGELOG/CLAUDE.md |
| `/conductor:bdw-worker-done` | Complete individual worker (auto-detects mode) |
| `tabz-expert` | Browser automation agent (user-scope plugin) |

### Beads Commands Used

| Command | Purpose |
|---------|---------|
| `bd worktree create` | Create worktree with beads redirect |
| `bd create --type=agent` | Create agent bead for worker |
| `bd agent state <id>` | Set agent state (spawning/running/done) |
| `bd slot set <agent> hook <issue>` | Attach work to agent |
| `bd list --type=agent` | Monitor worker states |
