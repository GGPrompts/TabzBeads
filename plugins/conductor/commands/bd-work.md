---
description: "Pick the top ready beads issue and spawn a visible worker to complete it"
---

# Beads Work - Single Issue Worker

Spawn a visible worker to tackle one beads issue. Unlike bd-swarm, no worktree is created since there's only one worker.

## Quick Start

```bash
/conductor:bd-work              # Pick top priority ready issue
/conductor:bd-work TabzChrome-abc  # Work on specific issue
```

---

## Workflow

```
1. Select issue       →  bd ready (pick top) or use provided ID
2. Get issue details  →  bd show <id>
3. VERIFY SKILLS      →  scripts/match-skills.sh --available-full (MANDATORY)
4. Explore context    →  Task(Explore) for relevant files
5. Craft prompt       →  Follow worker-architecture.md template (VERIFIED skills only)
6. Spawn worker       →  TabzChrome API (no worktree)
7. Send prompt        →  tmux send-keys
8. User watches       →  Worker visible in sidebar
```

---

## Phase 1: Select Issue

If no issue ID was provided as an argument, present the ready issues to the user:

```bash
# Get ready issues
bd ready
```

Then use AskUserQuestion with the question: **"Here are the unblocked issues:"**

Present each ready issue as an option with format: `<id> (<priority>)` as label, description from issue title.

After user selects, get full details:
```bash
bd show <selected-id>
```

---

## Phase 2: Get Skill Keywords

Get keyword phrases for the issue to include in the worker prompt:

```bash
# Get keyword phrases for skill-eval hook activation
${CLAUDE_PLUGIN_ROOT}/scripts/match-skills.sh --issue "$ISSUE_ID"
# Returns: "xterm.js terminal, resize handling, FitAddon"

# Or match from issue content directly
${CLAUDE_PLUGIN_ROOT}/scripts/match-skills.sh --verify "$TITLE $DESCRIPTION"
```

**How it works:**
- The skill-eval hook (UserPromptSubmit) detects domain keywords in prompts
- Keywords like "xterm.js terminal" automatically activate the xterm-js skill
- No explicit `/plugin:skill` invocations needed - just include keywords in Context

Include domain-specific keywords to help skill identification:

| Domain | Keywords to Include |
|--------|---------------------|
| UI/Frontend | shadcn/ui, Tailwind CSS, Radix UI, React components |
| Terminal | xterm.js, resize handling, FitAddon, WebSocket PTY |
| Backend | FastAPI, REST API, Node.js, database patterns |
| Plugin dev | Claude Code plugin, skill creation, agent patterns |
| Browser | MCP tools, screenshots, browser automation |
| Auth | Better Auth, OAuth, JWT, session management |

**Note:** The skill-eval hook handles activation - just include relevant keywords in the prompt.

---

## Phase 3: Explore Context

Before crafting the prompt, understand what files are relevant:

```markdown
Task(
  subagent_type="Explore",
  model="haiku",
  prompt="Find files relevant to: '<issue-title>'
         Return: key files, patterns to follow"
)
```

---

## Phase 4: Craft Prompt

Follow the template from `references/worker-architecture.md`:

```markdown
Fix beads issue ISSUE-ID: "Title"

## Context
[WHY this matters, background from issue description]
This task involves [domain keywords: e.g., "React components with Tailwind CSS styling"]

## Key Files
[File paths as text - worker reads on-demand]
- path/to/relevant/file.ts
- path/to/pattern/to/follow.ts

## Approach
[Implementation guidance - what to do, not which skills to use]

After implementation, verify the build passes and test the changes work as expected.

## Conductor Session
CONDUCTOR_SESSION=<conductor-tmux-session>
(Worker needs this to notify conductor on completion)

## When Done
Run: /conductor:bdw-worker-done ISSUE-ID

This command will: build, run code review, commit changes, and close the issue.
```

**The `/conductor:bdw-worker-done` instruction is mandatory** - without it, workers don't know how to signal completion.

---

## Phase 5: Spawn Worker

First, get the conductor's tmux session name:
```bash
CONDUCTOR_SESSION=$(tmux display-message -p '#{session_name}')
```

Then spawn the worker with `CONDUCTOR_SESSION` env var:
```bash
TOKEN=$(cat /tmp/tabz-auth-token)
ISSUE_ID="<issue-id>"
PROJECT_DIR=$(pwd)

RESPONSE=$(curl -s -X POST http://localhost:8129/api/spawn \
  -H "Content-Type: application/json" \
  -H "X-Auth-Token: $TOKEN" \
  -d "{\"name\": \"$ISSUE_ID-worker\", \"workingDir\": \"$PROJECT_DIR\", \"command\": \"CONDUCTOR_SESSION=$CONDUCTOR_SESSION claude --dangerously-skip-permissions\"}")

# Response: {"success":true,"terminal":{"id":"ctt-xxx","ptyInfo":{"tmuxSession":"ctt-xxx"}}}
SESSION=$(echo "$RESPONSE" | jq -r '.terminal.ptyInfo.tmuxSession')
echo "Spawned: $SESSION"

# Record session IDs in beads for audit trail
bd update "$ISSUE_ID" --notes "conductor_session: $CONDUCTOR_SESSION
worker_session: $SESSION
started_at: $(date -Iseconds)"
```

**Why CONDUCTOR_SESSION?** When worker runs `/conductor:bdw-worker-done`, it sends a completion notification back to the conductor via tmux. No polling needed - push-based.

**Why record session IDs?** Enables later audit of which Claude session worked on which issue. Can review chat histories to improve prompts/workflows.

**No worktree needed** - single worker, no conflict risk.

---

## Phase 6: Send Prompt

Wait for Claude to load (~8 seconds), then send using `$SESSION` from Phase 5.

**Use load-buffer for multi-line prompts** (prevents terminal corruption):

```bash
sleep 8

# Write prompt to temp file (handles special chars safely)
PROMPT_FILE=$(mktemp)
cat > "$PROMPT_FILE" << 'PROMPT_EOF'
<crafted-prompt-here>
PROMPT_EOF

# Load and paste (bypasses shell quoting issues)
tmux load-buffer "$PROMPT_FILE"
tmux paste-buffer -t "$SESSION"
sleep 0.3
tmux send-keys -t "$SESSION" C-m

# Cleanup
rm "$PROMPT_FILE"
```

**Why not `send-keys -l`?** Multi-line content with code blocks, backticks, or nested quotes can trigger tmux copy mode ("jump to backward" in status bar). `load-buffer` + `paste-buffer` bypasses shell processing entirely.

**Short messages still work with send-keys:**
```bash
tmux send-keys -t "$SESSION" -l "Simple one-liner"
sleep 0.3
tmux send-keys -t "$SESSION" C-m
```

---

## Phase 7: Monitor

User watches worker progress in TabzChrome sidebar. Worker will:
1. Read issue details
2. Explore codebase as needed
3. Implement the fix/feature
4. Run `/conductor:bdw-worker-done <issue-id>`

---

## Cleanup

After worker completes:

```bash
# Kill the worker session (use $SESSION from Phase 5)
tmux kill-session -t "$SESSION"
```

---

## Comparison with bd-swarm

| Aspect | bd-work | bd-swarm |
|--------|---------|----------|
| Workers | 1 | Multiple |
| Worktree | No | Yes (per worker) |
| Conflict risk | None | Managed via isolation |
| Use case | Single issue focus | Batch parallel processing |
| Cleanup | Just kill session | Merge branches + cleanup |

---

## Notes

- Conductor crafts the prompt, worker executes
- Worker is visible in TabzChrome sidebar
- No worktree = simpler cleanup
- Worker completes with `/conductor:bdw-worker-done`

Execute this workflow now.
