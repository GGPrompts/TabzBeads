---
name: orchestration
description: "Multi-session Claude workflow orchestration. Spawn workers via TabzChrome, coordinate parallel tasks, use subagents for monitoring/exploration, manage beads issues. Use this skill when coordinating multiple Claude sessions or managing complex multi-step workflows."
---

# Orchestration Skill - Multi-Session Workflows

Orchestrate multiple Claude Code sessions, spawn workers, and coordinate parallel work.

> **Subagent support.** Conductor skills that need Task tool (like code-review) use `context: fork` to run in a forked sub-agent with full Task tool access, even when the parent was launched with `--agent`.

## Architecture

```
Vanilla Claude Session (you)
├── Task tool -> can spawn subagents
│   ├── conductor:code-reviewer (sonnet) - autonomous review
│   ├── conductor:skill-picker (haiku) - find/install skills
│   ├── conductor:prompt-enhancer (haiku) - enhance prompts for workers
│   └── conductor:docs-updater (opus) - update docs after merges
├── Worktree setup via scripts/setup-worktree.sh
├── Monitoring via beads agent tracking
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

---

## Core Capabilities

### Tabz MCP Tools (46 Tools)

```bash
mcp-cli info tabz/<tool>  # Always check schema before calling
```

| Category | Tools |
|----------|-------|
| **Tabs (5)** | tabz_list_tabs, tabz_switch_tab, tabz_rename_tab, tabz_get_page_info, tabz_open_url |
| **Tab Groups (7)** | tabz_list_groups, tabz_create_group, tabz_update_group, tabz_add_to_group, tabz_ungroup_tabs, tabz_claude_group_add, tabz_claude_group_remove |
| **Windows (7)** | tabz_list_windows, tabz_create_window, tabz_update_window, tabz_close_window, tabz_get_displays, tabz_tile_windows, tabz_popout_terminal |
| **Screenshots (2)** | tabz_screenshot, tabz_screenshot_full |
| **Interaction (4)** | tabz_click, tabz_fill, tabz_get_element, tabz_execute_script |
| **DOM/Debug (4)** | tabz_get_dom_tree, tabz_get_console_logs, tabz_profile_performance, tabz_get_coverage |
| **Network (3)** | tabz_enable_network_capture, tabz_get_network_requests, tabz_clear_network_requests |
| **Downloads (5)** | tabz_download_image, tabz_download_file, tabz_get_downloads, tabz_cancel_download, tabz_save_page |
| **Bookmarks (6)** | tabz_get_bookmark_tree, tabz_search_bookmarks, tabz_save_bookmark, tabz_create_folder, tabz_move_bookmark, tabz_delete_bookmark |
| **Audio/TTS (3)** | tabz_speak, tabz_list_voices, tabz_play_audio |

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

Workers need explicit skill triggers to activate capabilities.

### Prompt Template

```markdown
## Task: ISSUE-ID - Title

[Explicit, actionable description - what exactly to do, not just "fix the bug"]

## Context
[WHY this matters - helps Claude generalize and make good decisions]

## Key Files
- path/to/file.ts (focus on lines X-Y)
- path/to/other.ts

## Guidance
Use the `/skill-name` skill for [specific aspect].
Follow the pattern in [existing-file.ts] for consistency.

## When Done
Run `/conductor:bdw-worker-done ISSUE-ID`
```

### Skill Triggers

| Need | Trigger Phrase |
|------|---------------|
| Terminal UI | "use the xterm-js skill" |
| UI components | "use the shadcn-ui skill" |
| Complex reasoning | "use the sequential-thinking skill" |
| Exploration | "use subagents in parallel to explore" |
| Deep thinking | Prepend `ultrathink` |
| Code review | Run `/conductor:bdw-code-review` |
| Build verification | Run `/conductor:bdw-verify-build` |

### Prompt Guidelines (Lessons Learned)

- **Be explicit** - "Fix null reference on line 45" not "fix the bug"
- **Add context** - Explain WHY to help Claude make good decisions
- **Reference patterns** - Point to existing code for consistency
- **Avoid ALL CAPS** - Claude 4.x overtriggers on aggressive language
- **File paths as text** - Workers read files on-demand, avoids bloat
- **Include completion** - Always end with "Run `/conductor:bdw-worker-done ISSUE-ID`"

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
| 5 | Unified code review | Yes - uses Task(conductor:code-reviewer) |
| 6 | Cleanup worktrees/branches | No |
| 7 | Visual QA (if UI changes) | Optional |
| 8 | Sync and push | Yes |

**Why unified review at wave level:** Workers do NOT run code review (to avoid conflicts when running in parallel). The conductor does the sole code review after merge, catching cross-worker interactions and ensuring combined changes work together.

---

## Subagents (via Task Tool)

| Subagent | Model | Purpose |
|----------|-------|---------|
| `conductor:code-reviewer` | sonnet | Autonomous review, quality gate |
| `conductor:skill-picker` | haiku | Search/install skills |
| `conductor:prompt-enhancer` | haiku | Enhance prompts for workers |
| `conductor:docs-updater` | opus | Update docs after merges |

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
| `/conductor:bd-work` | Single-session workflow (YOU do the work) |
| `/conductor:bd-plan` | Prepare backlog (refine, enhance prompts) |
| `/conductor:bd-swarm` | Spawn parallel workers |
| `/conductor:bdc-swarm-auto` | Fully autonomous parallel execution |
| `/conductor:bdc-wave-done` | Complete a wave of parallel workers |
| `/conductor:bdw-worker-done` | Complete individual worker (auto-detects mode) |
| `tabz:tabz-manager` | Browser automation agent |

### Beads Commands Used

| Command | Purpose |
|---------|---------|
| `bd worktree create` | Create worktree with beads redirect |
| `bd create --type=agent` | Create agent bead for worker |
| `bd agent state <id>` | Set agent state (spawning/running/done) |
| `bd slot set <agent> hook <issue>` | Attach work to agent |
| `bd list --type=agent` | Monitor worker states |
