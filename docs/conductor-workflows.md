# Conductor Plugin - Complete Workflow Reference

This document maps all conductor plugin workflows, their components, and relationships. Use this to understand how the orchestration system works.

**Last Updated**: 2026-01-11 (commands/skills reorganization)

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prefix Taxonomy](#prefix-taxonomy)
3. [Entry Points](#entry-points)
4. [Single-Session Workflow (bd-work)](#single-session-workflow-bd-work)
5. [Multi-Session Workflow (bdc-swarm-auto)](#multi-session-workflow-bdc-swarm-auto)
6. [Worker Pipeline](#worker-pipeline)
7. [bdw-worker-done Pipeline](#bdw-worker-done-pipeline)
8. [bdc-wave-done Pipeline](#bdc-wave-done-pipeline)
9. [Atomic Skills](#atomic-skills)
10. [Agents](#agents)
11. [Beads Integration](#beads-integration)
12. [Quick Reference](#quick-reference)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CONDUCTOR                                    │
│            (orchestrates multi-session Claude work)                  │
│                                                                      │
│  Entry Points (bd-*):                                                │
│    /conductor:bd-work      - Single session (YOU do the work)       │
│    /conductor:bd-plan      - Prepare backlog                        │
│    /conductor:bd-swarm     - Spawn parallel workers                 │
│    /conductor:bd-status    - View issue state                       │
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
                    │ bdc-wave-done   │
                    │ (merge+review)  │
                    └─────────────────┘
                              │
                              ▼
                         git push
```

### Legend

| Symbol | Meaning |
|--------|---------|
| `bd-*` | User entry point (command) |
| `bdc-*` | Conductor internal (skill) |
| `bdw-*` | Worker step (skill) |
| `bd X` | Beads CLI command |
| `{agent}` | Subagent via Task() |
| `⛔` | Blocking (stops on failure) |

---

## Prefix Taxonomy

Prefixes indicate purpose and component type:

| Prefix | Type | Purpose | Example |
|--------|------|---------|---------|
| `bd-` | Command | User entry points (visible in menu) | bd-work, bd-plan, bd-swarm |
| `bdc-` | Skill | Conductor internal (orchestration) | bdc-swarm-auto, bdc-wave-done |
| `bdw-` | Skill | Worker steps (execution pipeline) | bdw-verify-build, bdw-commit-changes |

Skills have `user-invocable: false` so they don't appear in the slash command menu, but can still be invoked via `/conductor:bdc-*` or `/conductor:bdw-*`.

---

## Entry Points

```
┌─────────────────────────────────────────────────────────────────────┐
│                        USER ENTRY POINTS (bd-*)                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  /conductor:bd-work [issue-id]                                      │
│       Single session - YOU do the work                              │
│       Full pipeline: build → test → commit → push                   │
│                                                                     │
│  /conductor:bd-plan                                                 │
│       Prepare backlog: refine, enhance prompts, match skills        │
│       Stores prepared.* in issue notes                              │
│                                                                     │
│  /conductor:bd-swarm                                                │
│       Multi-session: spawn parallel workers                         │
│       Interactive issue selection and worker count                  │
│                                                                     │
│  /conductor:bd-status                                               │
│       View issue state (open, blocked, ready, in-progress)          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### When to Use Each

| Entry Point | Use Case | Who Works? | Code Review By |
|-------------|----------|------------|----------------|
| `bd-work` | Single issue, you working | You | You (optional) |
| `bd-plan` | Prepare before execution | You (prep only) | N/A |
| `bd-swarm` | Parallel worker spawning | Spawned workers | Conductor (unified) |
| `bd-status` | Check project state | N/A | N/A |

---

## Single-Session Workflow (bd-work)

**Command**: `/conductor:bd-work`

```
┌─────────────────────────────────────────────────────────────────────┐
│                    /conductor:bd-work [issue-id]                    │
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
                    │ 4. bdw-verify-  │⛔
                    │    build        │
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ 5. bdw-run-     │⛔
                    │    tests        │
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ 6. bdw-commit-  │⛔
                    │    changes      │
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ 7. bdw-close-   │⛔
                    │    issue        │
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ 8. Push         │
                    │ bd sync &&      │
                    │ git push        │
                    └─────────────────┘
```

---

## Multi-Session Workflow (bdc-swarm-auto)

**Command**: `/conductor:bdc-swarm-auto`

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CONDUCTOR (bdc-swarm-auto)                       │
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
                              └─────────────────┘
                                        │
                                        ▼
                              ┌─────────────────┐
                              │ 5. Spawn        │
                              │    Workers      │◀──── TabzChrome /api/spawn
                              └─────────────────┘
                                        │
                                        ▼
                              ┌─────────────────┐
                              │ 6. Monitor      │◀──── bd list --type=agent
                              │  Agent States   │
                              └─────────────────┘
                                        │
                    Workers notify via tmux send-keys
                                        │
                                        ▼
                              ┌─────────────────┐
                              │ 7. bdc-wave-    │◀──── /conductor:bdc-wave-done
                              │    done         │
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
                    │       /conductor:bdw-worker-done        │
                    │  (auto-detects worker vs standalone)    │
                    └─────────────────────────────────────────┘
```

---

## bdw-worker-done Pipeline

**Command**: `/conductor:bdw-worker-done`

The pipeline **auto-detects execution mode**:

```
┌─────────────────────────────────────────────────────────────────────┐
│                 /conductor:bdw-worker-done <issue-id>               │
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
            ▼                                   ▼
   ┌─────────────────┐                ┌─────────────────┐
   │ bdw-verify-     │⛔              │ bdw-verify-     │⛔
   │ build           │                │ build           │
   └─────────────────┘                └─────────────────┘
            │                                  │
            ▼                                  ▼
   ┌─────────────────┐                ┌─────────────────┐
   │ bdw-run-tests   │⛔              │ bdw-run-tests   │⛔
   └─────────────────┘                └─────────────────┘
            │                                  │
            ▼                                  ▼
   ┌─────────────────┐                ┌─────────────────┐
   │ bdw-commit-     │⛔              │ bdw-commit-     │⛔
   │ changes         │                │ changes         │
   └─────────────────┘                └─────────────────┘
            │                                  │
            ▼                                  ▼
   ┌─────────────────┐                ┌─────────────────┐
   │ bdw-close-issue │⛔              │ bdw-close-issue │⛔
   └─────────────────┘                └─────────────────┘
            │                                  │
            ▼                                  ▼
   ┌─────────────────┐                ┌─────────────────┐
   │ NOTIFY          │                │ Show next steps │
   │ conductor       │                │ (push, etc.)    │
   └─────────────────┘                └─────────────────┘
```

---

## bdc-wave-done Pipeline

**Command**: `/conductor:bdc-wave-done`

```
┌─────────────────────────────────────────────────────────────────────┐
│              /conductor:bdc-wave-done <issue-ids>                   │
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
                    │ bdw-verify-     │◀──── Verify merged code
                    │ build           │
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

## Atomic Skills

### Worker Skills (bdw-*)

| Skill | Purpose | Blocking? |
|-------|---------|-----------|
| `/conductor:bdw-verify-build` | Run build, check errors | ⛔ Yes |
| `/conductor:bdw-run-tests` | Run test suite | ⛔ Yes |
| `/conductor:bdw-code-review` | Opus review (auto-fix) | ⛔ Yes |
| `/conductor:bdw-codex-review` | Cheaper Codex review | ⛔ Yes |
| `/conductor:bdw-commit-changes` | Stage + commit | ⛔ Yes |
| `/conductor:bdw-create-followups` | Create beads issues | No |
| `/conductor:bdw-update-docs` | Check/update docs | No |
| `/conductor:bdw-close-issue` | Close beads issue | ⛔ Yes |
| `/conductor:bdw-worker-done` | Full completion pipeline | ⛔ Yes |
| `/conductor:bdw-worker-init` | Initialize worker context | No |

### Conductor Skills (bdc-*)

| Skill | Purpose | Blocking? |
|-------|---------|-----------|
| `/conductor:bdc-swarm-auto` | Autonomous wave execution | ⛔ Yes |
| `/conductor:bdc-wave-done` | Merge + unified review | ⛔ Yes |
| `/conductor:bdc-run-wave` | Run wave from template | ⛔ Yes |
| `/conductor:bdc-orchestration` | Multi-session coordination | ⛔ Yes |
| `/conductor:bdc-analyze-transcripts` | Review worker sessions | No |

---

## Agents

| Agent | Purpose | Model |
|-------|---------|-------|
| `conductor:conductor` | Orchestrate workflows | opus |
| `conductor:code-reviewer` | Autonomous review | opus |
| `conductor:skill-picker` | Find skills | haiku |
| `conductor:docs-updater` | Update documentation | opus |
| `conductor:prompt-enhancer` | Optimize prompts | haiku |
| `conductor:tui-expert` | TUI tool control | opus |
| `conductor:tabz-artist` | Visual asset generation | opus |

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
/conductor:bd-work [issue-id]
# Does: select → claim → implement → verify → test → commit → close → push
```

### For Parallel Work (spawning workers)

```bash
/conductor:bd-swarm
# Interactive: select issues, worker count
# Then spawns workers in parallel
```

### For Autonomous Waves

```bash
/conductor:bdc-swarm-auto
# Loops waves until bd ready empty
# Each wave: worktrees → agents → spawn → monitor → wave-done
```

### For Worker Completion (spawned by conductor)

```bash
/conductor:bdw-worker-done <id>
# Auto-detects mode, adapts pipeline
# Worker mode: NO review, NO push, notifies conductor
```

### For Wave Completion (conductor runs this)

```bash
/conductor:bdc-wave-done <issue-ids>
# Does: verify done → kill → merge → build → review → cleanup → push
```

---

## File Locations

| Component | Location |
|-----------|----------|
| User commands (bd-*) | `plugins/conductor/commands/bd-*.md` |
| Conductor skills (bdc-*) | `plugins/conductor/skills/bdc-*/SKILL.md` |
| Worker skills (bdw-*) | `plugins/conductor/skills/bdw-*/SKILL.md` |
| Other skills | `plugins/conductor/skills/*/SKILL.md` |
| Agents | `plugins/conductor/agents/*.md` |
| Scripts | `plugins/conductor/scripts/*.sh` |

---

## Implementation Status

### Completed

| Feature | Status |
|---------|--------|
| Prefix taxonomy (bd-, bdc-, bdw-) | ✅ |
| `/conductor:bd-work` command | ✅ |
| `/conductor:bd-plan` command | ✅ |
| `/conductor:bd-swarm` command | ✅ |
| Auto-detect worker vs standalone | ✅ |
| `bd worktree` integration | ✅ |
| Agent bead tracking | ✅ |
| Prepared prompt storage | ✅ |
| Synced skills from TabzChrome | ✅ |

### Future (Proposed)

| Feature | Status |
|---------|--------|
| Molecules (workflow templates) | 🔮 TabzBeads-u7c |
| Complexity-aware worker pipeline | 🔮 TabzBeads-32q |
| Cross-project deps (bd ship) | 🔮 |
| Visual QA automation | 🔮 |
