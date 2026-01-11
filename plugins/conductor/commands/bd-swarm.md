---
description: "Spawn multiple Claude workers with skill-aware prompts to tackle beads issues in parallel"
---

> **⚠️ DEPRECATED:** This command is deprecated. Use `/conductor:bdc-swarm-auto` instead.
> This command will be removed in a future version.

# Beads Swarm - Parallel Issue Processing

Spawn multiple Claude workers to tackle beads issues in parallel, with skill-aware prompting and environment preparation.

## Quick Start

```bash
# Interactive: select issues and worker count
/conductor:bd-swarm

# Auto mode: process entire backlog autonomously
/conductor:bd-swarm --auto
```

## Workflow Overview

```
1. Get ready issues      ->  bd ready
2. VERIFY SKILLS         ->  scripts/match-skills.sh --available-full (MANDATORY)
3. Create worktrees      ->  scripts/setup-worktree.sh (parallel)
4. Wait for deps         ->  All worktrees ready before workers spawn
5. Spawn workers         ->  TabzChrome /api/spawn (see below)
6. Send prompts          ->  tmux send-keys with VERIFIED skill hints only
7. Monitor               ->  scripts/monitor-workers.sh
8. Merge & review        ->  Merge branches, visual review (conductor only)
9. Cleanup               ->  scripts/completion-pipeline.sh
```

**Key insight:** TabzChrome spawn creates tmux sessions with `ctt-*` prefix. Cleanup is via `tmux kill-session`.

---

## MANDATORY: Verify Skills Before Spawning

**CRITICAL:** Before crafting prompts, verify which skills are actually available:

```bash
# List all available skills with descriptions
${CLAUDE_PLUGIN_ROOT}/scripts/match-skills.sh --available-full

# Or match and verify for specific keywords
${CLAUDE_PLUGIN_ROOT}/scripts/match-skills.sh --verify "terminal ui api"
```

**Only include skills in prompts that appear in `--available-full` output.**

- If a skill doesn't exist, workers will fail trying to invoke it
- The `--verify` flag filters to only available skills
- MCP tools (like shadcn/*) are NOT skills - they're called directly via `mcp-cli`

---

## Spawn Workers - Copy-Paste Example

**IMPORTANT**: Use this exact pattern to spawn workers via TabzChrome:

```bash
# 0. Setup worktree FIRST (installs deps + builds)
ISSUE_ID="TabzChrome-xxx"
./plugins/conductor/scripts/setup-worktree.sh "$ISSUE_ID"
# Output: READY: /path/to/TabzChrome-worktrees/TabzChrome-xxx
WORKTREE_PATH="$(pwd)-worktrees/$ISSUE_ID"

# 1. Get auth token and conductor session
TOKEN=$(cat /tmp/tabz-auth-token)
CONDUCTOR_SESSION=$(tmux display-message -p '#{session_name}')

# 2. Spawn worker with env vars (creates ctt-worker-ISSUE-xxxx tmux session)
# BD_SOCKET isolates beads daemon per worker (prevents conflicts in parallel workers)
RESPONSE=$(curl -s -X POST http://localhost:8129/api/spawn \
  -H "Content-Type: application/json" \
  -H "X-Auth-Token: $TOKEN" \
  -d "{\"name\": \"worker-$ISSUE_ID\", \"workingDir\": \"$WORKTREE_PATH\", \"command\": \"BD_SOCKET=/tmp/bd-worker-$ISSUE_ID.sock CONDUCTOR_SESSION='$CONDUCTOR_SESSION' claude --dangerously-skip-permissions\"}")

# 3. Extract session name from response
SESSION_NAME=$(echo "$RESPONSE" | jq -r '.terminal.ptyInfo.tmuxSession // .terminal.id')
echo "Spawned: $SESSION_NAME"

# 4. Record session IDs in beads for audit trail
bd update "$ISSUE_ID" --notes "conductor_session: $CONDUCTOR_SESSION
worker_session: $SESSION_NAME
started_at: $(date -Iseconds)"

# 5. Wait for Claude to initialize, then send prompt
sleep 4
# Skills are already loaded in worker context - send prompt directly
tmux send-keys -t "$SESSION_NAME" -l 'Your prompt here...'
sleep 0.3
tmux send-keys -t "$SESSION_NAME" C-m
```

**The setup-worktree.sh script:**
- Creates worktree with proper locking (safe for parallel workers)
- Installs dependencies (npm/pnpm/yarn based on lockfile)
- Runs initial build
- Output: `READY: /path/to/worktree`

**Alternative - Direct tmux** (simpler, no TabzChrome UI):
```bash
# Setup worktree first
ISSUE_ID="TabzChrome-xxx"
./plugins/conductor/scripts/setup-worktree.sh "$ISSUE_ID"
WORKTREE_PATH="$(pwd)-worktrees/$ISSUE_ID"

SESSION="worker-$ISSUE_ID"
CONDUCTOR_SESSION=$(tmux display-message -p '#{session_name}')
tmux new-session -d -s "$SESSION" -c "$WORKTREE_PATH"
# BD_SOCKET isolates beads daemon per worker (prevents conflicts in parallel workers)
tmux send-keys -t "$SESSION" "BD_SOCKET=/tmp/bd-worker-$ISSUE_ID.sock CONDUCTOR_SESSION='$CONDUCTOR_SESSION' claude --dangerously-skip-permissions" C-m

# Record session IDs in beads for audit trail
bd update "$ISSUE_ID" --notes "conductor_session: $CONDUCTOR_SESSION
worker_session: $SESSION
started_at: $(date -Iseconds)"

sleep 4
# Skills are already loaded in worker context - send prompt directly
tmux send-keys -t "$SESSION" -l 'Your prompt here...'
sleep 0.3
tmux send-keys -t "$SESSION" C-m
```

---

## Worker Completion Notifications

Workers notify the conductor when done via API (push-based, no polling, no session corruption):

```
Worker completes → /conductor:bdw-worker-done
                 → POST /api/notify with worker-complete type
                 → WebSocket broadcasts to conductor
                 → Conductor receives and cleans up immediately
```

**How it works:**
1. Worker completes task and runs `/conductor:bdw-worker-done`
2. Worker calls `POST /api/notify` with completion details
3. Backend broadcasts via WebSocket to all connected clients
4. Conductor receives notification and can cleanup immediately
5. No polling needed - workers push completion status via API

**Why API over tmux send-keys:** The old tmux-based notification could corrupt the conductor's Claude session if it was mid-output or mid-prompt. The API broadcasts via WebSocket, which the conductor receives cleanly without interrupting its session.

**API notification pattern:**
```bash
TOKEN=$(cat /tmp/tabz-auth-token)
curl -s -X POST http://localhost:8129/api/notify \
  -H "Content-Type: application/json" \
  -H "X-Auth-Token: $TOKEN" \
  -d "{\"type\": \"worker-complete\", \"issueId\": \"$ISSUE_ID\", \"summary\": \"commit message\", \"session\": \"$WORKER_SESSION\"}"
```

**Spawn command (BD_SOCKET isolates beads daemon per worker):**
```bash
"command": "BD_SOCKET=/tmp/bd-worker-$ISSUE_ID.sock claude --dangerously-skip-permissions"
```

---

## Fallback: Polling (if notifications fail)

See: `references/bd-swarm/monitoring.md`

```bash
# Poll status
${CLAUDE_PLUGIN_ROOT}/scripts/monitor-workers.sh --summary
# Output: WORKERS:3 WORKING:2 IDLE:0 AWAITING:1 STALE:0
```

| Status | Action |
|--------|--------|
| `AskUserQuestion` | Don't nudge - waiting for user |
| `<other tool>` | Working, leave alone |
| `idle` / `awaiting_input` | Check if issue closed or stuck |
| Issue closed | Ready for cleanup |

---

## Interactive Mode

**See full details:** `references/bd-swarm/interactive-mode.md`

1. Get ready issues: `bd ready`
2. Ask user for worker count (2-5)
3. Create worktrees in parallel:
   ```bash
   for ISSUE in $ISSUES; do
     ${CLAUDE_PLUGIN_ROOT}/scripts/setup-worktree.sh "$ISSUE" &
   done
   wait
   ```
4. Spawn workers via TabzChrome API or direct tmux
5. Send skill-aware prompts with issue context
6. Monitor via `monitor-workers.sh --summary` every 2 min
7. Run completion pipeline when all issues closed

---

## Auto Mode (`--auto`)

**See full details:** `references/bd-swarm/auto-mode.md`

Fully autonomous backlog completion. Runs waves until `bd ready` is empty.

**Conductor behavior:** No user questions, make reasonable defaults, loop until backlog empty.

| Aspect | Interactive | Auto |
|--------|-------------|------|
| Worker count | Ask user | All ready issues |
| Waves | One wave | Loop until empty |
| Decisions | AskUserQuestion ok | No questions |
| Context | Manual check | Auto /wipe at 75% |

---

## Completion Pipeline

**See full details:** `references/bd-swarm/completion-pipeline.md`

### Full Closeout (Recommended)

Use the wave-done skill for comprehensive closeout with code review:

```bash
# Full pipeline: verify -> merge -> build -> review -> cleanup -> push -> summary
/conductor:bdc-wave-done $ISSUES
```

This runs all 9 steps: verify workers closed, kill sessions, merge branches, build verification, unified code review, cleanup worktrees, visual QA (if UI changes), sync & push, comprehensive summary.

### Quick Cleanup (Skip Review)

For trivial changes or when you want to review manually:

```bash
# Quick: kill sessions -> merge -> cleanup -> audio notification
${CLAUDE_PLUGIN_ROOT}/scripts/completion-pipeline.sh "$ISSUES"
```

**When to use which:**

| Scenario | Use |
|----------|-----|
| Production work, multiple workers | `/conductor:bdc-wave-done` (full) |
| Trivial changes, single worker | `completion-pipeline.sh` (quick) |
| Need to review manually | `completion-pipeline.sh` then manual review |

**Visual review happens at conductor level** (after merge):
- Conductor opens browser tabs for UI verification
- No tab conflicts since workers are done
- Full context of all merged changes

---

## Worker Expectations

Each worker will:
1. Read issue: `bd show <id>`
2. Implement feature/fix
3. Build and test
4. Complete: `/conductor:bdw-worker-done <issue-id>`

**Workers do NOT do visual review.** Visual review (browser-based UI verification) happens at the conductor level after merge. This prevents parallel workers from fighting over browser tabs.

### Self-Service Optimization (Optional)

Workers can self-optimize before starting real work:

```
1. Worker receives basic prompt from conductor
2. Worker runs /conductor:bdw-worker-init (or spawns prompt-enhancer agent)
3. Issue is analyzed, skills identified, enhanced prompt crafted
4. Context reset (/clear) and enhanced prompt auto-submitted
5. Worker now has full context budget for implementation
```

**When to use:** Complex issues where context optimization helps. Skip for simple fixes.

See `commands/worker-init.md` and `agents/prompt-enhancer.md`.

---

## Worker Architecture

Workers are vanilla Claude sessions that receive skill-aware prompts:

```
Worker (vanilla Claude via tmux/TabzChrome)
  ├─> Gets context from `bd show <issue-id>`
  ├─> Receives skill hint in prompt (e.g., "use /xterm-js:xterm-js skill")
  ├─> Invokes skill directly when needed
  └─> Completes with /conductor:bdw-worker-done
```

Workers share the same plugin context as the conductor, so all skills are available.

---

## Skill Matching & Prompt Enhancement

**Key insight:** Workers need detailed prompts with skill hints woven naturally into guidance, not listed as sidebars.

### Reading Skills from Beads

Skills are persisted by `plan-backlog` in issue notes. Read them using the central script:

```bash
# The script self-locates (checks CLAUDE_PLUGIN_ROOT, script dir, project, plugin cache)
MATCH_SCRIPT="${CLAUDE_PLUGIN_ROOT:-./plugins/conductor}/scripts/match-skills.sh"

# Get skill trigger text for an issue (reads from notes first, falls back to matching)
SKILL_HINTS=$($MATCH_SCRIPT --issue "$ISSUE_ID")

# Or for runtime-verified matching (only available skills):
SKILL_HINTS=$($MATCH_SCRIPT --verify --issue "$ISSUE_ID")
```

**The workflow:**
1. `plan-backlog` analyzes issues and persists skills to notes
2. `bd-swarm` reads skills from notes (or matches on-the-fly if not persisted)
3. Workers receive natural skill trigger language in their prompts

### Skill Mappings

See `scripts/match-skills.sh` for the complete, authoritative list of skill mappings. Key patterns:

The skill-eval hook (meta plugin) automatically activates relevant skills based on keywords.
Include domain keywords in prompts to help skill identification:

| Domain | Keywords to Include |
|--------|---------------------|
| Terminal | xterm.js, resize handling, FitAddon, WebSocket PTY |
| UI/Frontend | shadcn/ui components, Tailwind CSS, Radix UI |
| Backend | FastAPI, REST API, Node.js, database patterns |
| Plugin dev | Claude Code plugin, skill creation, agent patterns |
| Browser | (use tabz_* MCP tools directly via mcp-cli) |

### Enhanced Prompt Structure

All worker prompts should follow this structure:

```markdown
Fix beads issue ISSUE-ID: "Title"

## Context
[Description from bd show - explains WHY]
This task involves [domain keywords: e.g., "React components with Tailwind CSS styling"]

## Key Files
[Relevant file paths, or "Explore as needed"]

## Approach
[Implementation guidance - include domain keywords for skill activation]

After implementation, verify the build passes and test the changes work as expected.

## Conductor Session
CONDUCTOR_SESSION=<conductor-tmux-session>
(Worker needs this to notify conductor on completion)

## When Done
Run: /conductor:bdw-worker-done ISSUE-ID

This command will: build, run code review, commit changes, and close the issue.
```

**Note:** The skill-eval hook handles activation - just include relevant domain keywords in the prompt. No explicit skill invocation commands needed.

**Exception:** Project-level skills (in `.claude/skills/`) can use shorthand: `/tabz-guide`

**The `/conductor:bdw-worker-done` instruction is mandatory** - without it, workers don't know how to signal completion and the conductor can't clean up.

**The conductor session is in the prompt text** (not just env var) so workers can reliably notify completion even if CONDUCTOR_SESSION env var is lost.

See `references/bd-swarm/interactive-mode.md` for the `match_skills()` function that auto-generates skill hints.

---

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/setup-worktree.sh` | Create worktree + install deps |
| `scripts/monitor-workers.sh` | Spawn/poll tmuxplexer watcher |
| `scripts/completion-pipeline.sh` | Quick cleanup: kill sessions, merge, cleanup |
| `scripts/wave-summary.sh` | Comprehensive wave summary with stats |

---

## Reference Files

| File | Content |
|------|---------|
| `references/bd-swarm/monitoring.md` | Worker status monitoring details |
| `references/bd-swarm/interactive-mode.md` | Full interactive workflow |
| `references/bd-swarm/auto-mode.md` | Auto mode wave loop |
| `references/bd-swarm/completion-pipeline.md` | Cleanup steps |

---

## Notes

- Workers run in isolated worktrees (prevents conflicts)
- **BD_SOCKET isolates beads daemon per worker** - prevents daemon conflicts when multiple workers run `bd` commands simultaneously (beads v0.45+)
- Monitor via tmuxplexer background window (no watcher subagent)
- Check actual pane content before nudging idle workers
- Sessions MUST be killed before removing worktrees
- **Visual review happens at conductor level only** - workers skip it to avoid browser tab conflicts (see TabzChrome-s19)
