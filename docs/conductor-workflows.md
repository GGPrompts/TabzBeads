# Conductor Plugin - Complete Workflow Reference

This document maps all conductor plugin workflows, their components, and relationships. Use this to understand how the orchestration system works.

**Last Updated**: 2026-01-09 (v2 implementation complete)

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Entry Points](#entry-points)
3. [Single-Session Workflow (work)](#single-session-workflow-work)
4. [Multi-Session Workflow (bd-swarm-auto)](#multi-session-workflow-bd-swarm-auto)
5. [Worker Pipeline](#worker-pipeline)
6. [worker-done Pipeline](#worker-done-pipeline)
7. [wave-done Pipeline](#wave-done-pipeline)
8. [Atomic Commands](#atomic-commands)
9. [Agents](#agents)
10. [Beads Integration](#beads-integration)
11. [Quick Reference](#quick-reference)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CONDUCTOR                                    │
│            (orchestrates multi-session Claude work)                  │
│                                                                      │
│  Entry Points:                                                       │
│    /conductor:work       - Single session (YOU do the work)         │
│    /conductor:bd-plan    - Prepare backlog                          │
│    /conductor:bd-swarm-auto - Autonomous parallel execution          │
└─────────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
   ┌─────────┐          ┌─────────┐          ┌─────────┐
   │ Worker  │          │ Worker  │          │ Worker  │
   │ (agent  │          │ (agent  │          │ (agent  │
   │  bead)  │          │  bead)  │          │  bead)  │
   └─────────┘          └─────────┘          └─────────┘
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              ▼
                    ┌─────────────────┐
                    │   wave-done     │
                    │ (merge+review)  │
                    └─────────────────┘
                              │
                              ▼
                         git push
```

### Legend

| Symbol | Meaning |
|--------|---------|
| `/conductor:X` | Slash command (skill) |
| `bd X` | Beads CLI command |
| `{agent}` | Subagent via Task() |
| `→` | Flow direction |
| `⛔` | Blocking (stops on failure) |
| `✅` | Implemented |
| `🔮` | Proposed/Future |

---

## Entry Points

```
┌─────────────────────────────────────────────────────────────────────┐
│                        USER ENTRY POINTS                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ✅ Single Session:   /conductor:work [issue-id]                    │
│                            ↓                                        │
│                    YOU do the work (no spawning)                    │
│                    Full pipeline: build → test → commit → push      │
│                                                                     │
│  ✅ Plan Backlog:     /conductor:bd-plan                            │
│                            ↓                                        │
│                    Refine, enhance prompts, match skills            │
│                    Stores prepared.* in issue notes                 │
│                                                                     │
│  ✅ Auto Parallel:    /conductor:bd-swarm-auto                      │
│                            ↓                                        │
│                    Spawns workers, loops until bd ready empty       │
│                    Agent beads track state                          │
│                                                                     │
│  ✅ Worker Complete:  /conductor:worker-done <id>                   │
│                            ↓                                        │
│                    Detects mode (worker vs standalone)              │
│                    Adapts pipeline accordingly                      │
│                                                                     │
│  ⚠️ DEPRECATED:                                                     │
│     /conductor:bd-work   → Use /conductor:work                      │
│     /conductor:bd-swarm  → Use /conductor:bd-swarm-auto             │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### When to Use Each

| Entry Point | Use Case | Who Works? | Code Review By |
|-------------|----------|------------|----------------|
| `work` | Single issue, you working | You | You (optional) |
| `bd-plan` | Prepare before execution | You (prep only) | N/A |
| `bd-swarm-auto` | Batch autonomous work | Spawned workers | Conductor (unified) |
| `worker-done` | Complete current task | You (as worker) | Mode-dependent |

---

## Single-Session Workflow (work)

**Skill**: `/conductor:work`

```
┌─────────────────────────────────────────────────────────────────────┐
│                    /conductor:work [issue-id]                        │
│                    (YOU are the worker)                              │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ 1. Select Issue │
                    │ AskUserQuestion │◀──── If no ID provided
                    │ or use argument │
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ 2. Claim Issue  │
                    │ bd update <id>  │
                    │ --status=       │
                    │   in_progress   │
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ 3. IMPLEMENT    │
                    │ (you write code)│◀──── Follow PRIME.md patterns
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ 4. verify-build │⛔
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ 5. run-tests    │⛔
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ 6. commit-      │⛔
                    │    changes      │
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ 7. close-issue  │⛔
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ 8. Push         │
                    │ bd sync &&      │
                    │ git push        │
                    └─────────────────┘
```

### Key Differences from bd-swarm

| Aspect | /conductor:work | /conductor:bd-swarm-auto |
|--------|----------------|--------------------------|
| Who works | You | Spawned workers |
| Worktrees | No | Yes (per worker) |
| Code review | Optional (you decide) | Conductor (unified after merge) |
| Push | You do it | Conductor does it |

---

## Multi-Session Workflow (bd-swarm-auto)

**Skill**: `/conductor:bd-swarm-auto`

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CONDUCTOR (bd-swarm-auto)                        │
└─────────────────────────────────────────────────────────────────────┘
                              │
     ┌────────────────────────┼────────────────────────┐
     ▼                        ▼                        ▼
┌─────────────┐        ┌─────────────┐         ┌─────────────┐
│ 1. bd ready │        │ 2. Check    │         │ 3. Create   │
│   --json    │───────▶│   prepared. │────────▶│  Worktrees  │
│             │        │   prompt?   │         │ bd worktree │
└─────────────┘        └─────────────┘         │   create    │
                              │                └─────────────┘
                              ▼                       │
               ┌─────────────────────────┐            │
               │ Use prepared prompt     │            │
               │ OR craft dynamically    │            │
               └─────────────────────────┘            │
                              │                       │
                              └───────────────────────┘
                                        │
                                        ▼
                              ┌─────────────────┐
                              │ 4. Create Agent │
                              │    Beads        │◀──── bd create --type=agent
                              │ Set: spawning   │      bd agent state <id> spawning
                              └─────────────────┘
                                        │
                                        ▼
                              ┌─────────────────┐
                              │ 5. Spawn        │
                              │    Workers      │◀──── TabzChrome /api/spawn
                              │ Attach: hook    │      bd slot set <agent> hook <issue>
                              └─────────────────┘
                                        │
                                        ▼
                              ┌─────────────────┐
                              │ 6. Send Prompts │
                              │  (skill-aware)  │◀──── tmux send-keys
                              │ Set: running    │      bd agent state <id> running
                              └─────────────────┘
                                        │
                                        ▼
                              ┌─────────────────┐
                              │ 7. Monitor      │◀──── bd list --type=agent
                              │  Agent States   │      (replaces monitor-workers.sh)
                              └─────────────────┘
                                        │
                    Workers notify via tmux send-keys
                                        │
                                        ▼
                              ┌─────────────────┐
                              │ 8. wave-done    │◀──── /conductor:wave-done
                              │  (full cleanup) │
                              └─────────────────┘
                                        │
              ┌─────────────────────────┴────────────────┐
              ▼ (auto mode)                              │
       ┌─────────────┐                                   │
       │ LOOP: Check │                                   │
       │  bd ready   │───▶ more issues? ─┐               │
       └─────────────┘                   │               │
              ▲                          ▼               │
              └──────────── START NEXT WAVE              │
                                                         │
              bd ready empty? ───────────────────────────┘
                      ▼
                BACKLOG COMPLETE
```

### Beads-Native Features Used

| Feature | Command | Purpose |
|---------|---------|---------|
| Worktrees | `bd worktree create` | Auto-configures beads redirect |
| Agent beads | `bd create --type=agent` | Track worker state |
| State machine | `bd agent state <id> running` | spawning → running → done |
| Work attachment | `bd slot set <agent> hook <issue>` | Link worker to issue |
| Monitoring | `bd list --type=agent` | Query worker states |
| Prepared prompts | `bd show <id> --json \| jq .notes` | Read pre-crafted prompts |

---

## Worker Pipeline

Each spawned worker follows this flow:

```
┌─────────────────────────────────────────────────────────────────────┐
│                    WORKER (spawned Claude session)                  │
│                    Tracked as: Agent Bead                           │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Receive Prompt  │◀──── From conductor via tmux
                    │ (skill-aware)   │      May be from prepared.prompt
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Load Skills     │
                    │ /plugin:skill   │◀──── Full format required!
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Read Issue      │
                    │ bd show <id>    │
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   IMPLEMENT     │
                    │  (code changes) │
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────────────────────────────┐
                    │       /conductor:worker-done            │
                    │  (auto-detects worker vs standalone)    │
                    └─────────────────────────────────────────┘
```

### Worker Prompt Template

```markdown
Fix beads issue ISSUE-ID: "Title"

## Skills to Load
**FIRST**, invoke these skills before starting work:
- /backend-development:backend-development
- /conductor:orchestration

## Context
[WHY this matters]

## Key Files
- path/to/file.ts

## Approach
[Implementation guidance]

## Conductor Session
CONDUCTOR_SESSION=<session-id>

## When Done
Run: /conductor:worker-done ISSUE-ID

Do NOT use # or special symbols at the START of your notification message.
```

---

## worker-done Pipeline

**Skill**: `/conductor:worker-done`

The pipeline now **auto-detects execution mode**:

```
┌─────────────────────────────────────────────────────────────────────┐
│                 /conductor:worker-done <issue-id>                   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Step 0: DETECT EXECUTION MODE                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ is_worker_mode() {                                           │   │
│  │   [ -n "$CONDUCTOR_SESSION" ] && return 0  # Env var set     │   │
│  │   # OR inside git worktree                                   │   │
│  │   [ "$COMMON_DIR" != "$GIT_DIR" ] && return 0                │   │
│  │   return 1  # Standalone mode                                │   │
│  │ }                                                            │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┴───────────────────┐
          ▼                                       ▼
┌──────────────────────┐              ┌──────────────────────┐
│    WORKER MODE       │              │   STANDALONE MODE    │
│ ╔════════════════╗   │              │ ╔════════════════╗   │
│ ║ Skip review    ║   │              │ ║ Optional review║   │
│ ║ Skip push      ║   │              │ ║ You push       ║   │
│ ║ Notify conductor║   │              │ ║ No notification║   │
│ ╚════════════════╝   │              │ ╚════════════════╝   │
└──────────────────────┘              └──────────────────────┘
                              │
            ┌─────────────────┴─────────────────┐
            ▼ (code changes)                   ▼ (DOCS_ONLY)
   ┌─────────────────┐                ┌─────────────────┐
   │ Step 1: ⛔      │                │ Step 1a: ⛔     │
   │ verify-build    │                │ plugin-validator│
   └─────────────────┘                └─────────────────┘
            │                                  │
            ▼                                  │
   ┌─────────────────┐                         │
   │ Step 2: ⛔      │                         │
   │ run-tests       │                         │
   └─────────────────┘                         │
            │                                  │
            └─────────────────┬────────────────┘
                              ▼
                    ┌─────────────────┐
                    │ Step 3: commit  │⛔
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Step 4-5:       │
                    │ followups, docs │  (non-blocking)
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Step 5.5:       │
                    │ Update agent    │◀──── bd agent state <id> done
                    │ bead state      │      bd slot clear <id> hook
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Step 6: close   │⛔
                    └─────────────────┘
                              │
         ┌────────────────────┴────────────────────┐
         ▼ (worker mode)                          ▼ (standalone)
┌─────────────────────┐                 ┌─────────────────────┐
│ Step 7: NOTIFY      │                 │ Step 8: Show next   │
│ tmux send-keys      │                 │ steps (push, etc.)  │
│ API broadcast       │                 │                     │
└─────────────────────┘                 └─────────────────────┘
```

---

## wave-done Pipeline

**Skill**: `/conductor:wave-done`

```
┌─────────────────────────────────────────────────────────────────────┐
│              /conductor:wave-done <issue-ids>                       │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Step 1: Verify  │⛔
                    │ all workers done│◀──── All issues must be closed
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Step 2: Kill    │
                    │ sessions, merge │◀──── tmux kill-session
                    │ branches        │      git merge (per branch)
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Step 3:         │⛔
                    │ verify-build    │◀──── Verify merged code
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Step 4:         │⛔
                    │ UNIFIED review  │◀──── All changes together
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Step 5: Cleanup │
                    │ worktrees +     │◀──── bd worktree remove
                    │ branches        │      git branch -d
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Step 6: Push    │⛔
                    │ bd sync &&      │
                    │ git push        │
                    └─────────────────┘
```

---

## Atomic Commands

| Command | Purpose | Blocking? | Status |
|---------|---------|-----------|--------|
| `/conductor:verify-build` | Run build, check errors | ⛔ Yes | ✅ |
| `/conductor:run-tests` | Run test suite | ⛔ Yes | ✅ |
| `/conductor:code-review` | Opus review (auto-fix) | ⛔ Yes | ✅ |
| `/conductor:codex-review` | Cheaper Codex review | ⛔ Yes | ✅ |
| `/conductor:commit-changes` | Stage + commit | ⛔ Yes | ✅ |
| `/conductor:create-followups` | Create beads issues | No | ✅ |
| `/conductor:update-docs` | Check/update docs | No | ✅ |
| `/conductor:close-issue` | Close beads issue | ⛔ Yes | ✅ |

---

## Agents

| Agent | Purpose | Model | Status |
|-------|---------|-------|--------|
| `conductor:conductor` | Orchestrate workflows | opus | ✅ |
| `conductor:tabz-manager` | Browser automation | opus | ✅ |
| `conductor:code-reviewer` | Autonomous review | opus | ✅ |
| `conductor:skill-picker` | Find skills | haiku | ✅ |
| `code-review:reviewer` | Code review (in my-plugins) | opus | ✅ |
| `frontend-development:frontend-expert` | Frontend guidance | sonnet | ✅ |
| `backend-development:backend-expert` | Backend guidance | sonnet | ✅ |

---

## Beads Integration

### Agent Bead State Machine

```
idle → spawning → running → done
                     ↓
                  stuck (needs help)
```

### Commands Used

```bash
# Create agent for worker
bd create --type=agent --title="Worker: TabzBeads-abc"

# State transitions
bd agent state <id> spawning
bd agent state <id> running
bd agent state <id> done

# Attach/detach work
bd slot set <id> hook <issue-id>
bd slot clear <id> hook

# Query states
bd list --type=agent
bd agent show <id>
```

### Prepared Prompts (in issue notes)

```bash
# Store after refinement
bd update <id> --notes "prepared.skills: ui-styling,backend
prepared.files: src/Button.tsx
prepared.prompt: |
  Full prompt here..."

# Read before spawning
bd show <id> --json | jq -r '.[0].notes'
```

---

## Quick Reference

### For Standalone Work (you're the worker)

```bash
/conductor:work [issue-id]
# Does: select → claim → implement → verify → test → commit → close → push
```

### For Parallel Work (spawning workers)

```bash
/conductor:bd-swarm-auto
# Does: loops waves until bd ready empty
# Each wave: worktrees → agents → spawn → monitor → wave-done
```

### For Worker Completion (spawned by conductor)

```bash
/conductor:worker-done <id>
# Auto-detects mode, adapts pipeline
# Worker mode: NO review, NO push, notifies conductor
```

### For Wave Completion (conductor runs this)

```bash
/conductor:wave-done <issue-ids>
# Does: verify done → kill → merge → build → review → cleanup → push
```

---

## File Locations

| Component | Location |
|-----------|----------|
| Commands | `plugins/conductor/commands/*.md` |
| Skills | `plugins/conductor/skills/*/SKILL.md` |
| Agents | `plugins/conductor/agents/*.md` |
| Scripts | `plugins/conductor/scripts/*.sh` |
| My-Plugins Copy | `my-plugins/` |

---

## Implementation Status

### Completed (v2)

| Feature | Status |
|---------|--------|
| `/conductor:work` skill | ✅ |
| `/conductor:bd-plan` skill | ✅ |
| Auto-detect worker vs standalone | ✅ |
| `bd worktree` integration | ✅ |
| Agent bead tracking | ✅ |
| Prepared prompt storage | ✅ |
| Removed monitor-workers.sh | ✅ |
| Deprecation notices | ✅ |
| my-plugins conductor | ✅ |
| code-review plugin expansion | ✅ |
| frontend-expert agent | ✅ |
| backend-expert agent | ✅ |

### Future (Proposed)

| Feature | Status |
|---------|--------|
| Molecules (workflow templates) | 🔮 |
| `/conductor:refine` with Haiku | 🔮 |
| Cross-project deps (bd ship) | 🔮 |
| Visual QA automation | 🔮 |
