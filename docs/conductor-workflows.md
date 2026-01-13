# Conductor Plugin - Complete Workflow Reference

This document maps all conductor plugin workflows, their components, and relationships. Use this to understand how the orchestration system works.

**Last Updated**: 2026-01-12 (code-reviewer → Sonnet, CHANGE_TYPE detection, visual QA)

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
│    /conductor:bd-plan      - Prepare backlog                        │
│    /conductor:bd-start     - YOU work directly (no spawn)           │
│    /conductor:bd-status    - View issue state                       │
│    /conductor:bd-conduct   - Interactive orchestration (1-4 workers)│
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
│  /conductor:bd-plan                                                 │
│       Prepare backlog: refine, enhance prompts, match skills        │
│       Stores prepared.* in issue notes                              │
│                                                                     │
│  /conductor:bd-start [issue-id]                                     │
│       Single session - YOU do the work directly (no spawn)          │
│       Full pipeline: build → test → commit → push                   │
│                                                                     │
│  /conductor:bd-status                                               │
│       View issue state (open, blocked, ready, in-progress)          │
│                                                                     │
│  /conductor:bd-conduct                                              │
│       Interactive multi-session orchestration                       │
│       Select issues, terminal count (1-4), execution mode           │
│                                                                     │
│  /conductor:bd-new-project                                          │
│       Template-based project scaffolding                            │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### When to Use Each

| Entry Point | Use Case | Who Works? | Code Review By |
|-------------|----------|------------|----------------|
| `bd-plan` | Prepare before execution | You (prep only) | N/A |
| `bd-start` | Single issue, you working | You | You (optional) |
| `bd-status` | Check project state | N/A | N/A |
| `bd-conduct` | Spawn 1-4 workers | Spawned workers | Conductor (unified) |
| `bd-new-project` | Create new project | You | N/A |

---

## Single-Session Workflow (bd-start)

**Command**: `/conductor:bd-start`

```
┌─────────────────────────────────────────────────────────────────────┐
│                    /conductor:bd-start [issue-id]                   │
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
                    │ UNIFIED review  │◀──── Sonnet review, worker applies fixes
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
                    │ Step 6:         │⛔
                    │ bdc-visual-qa   │◀──── Forked tabz-manager (if UI changes)
                    │ --mode=quick    │      Console errors, DOM check
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Step 7: Push    │⛔
                    │ bd sync &&      │
                    │ git push        │
                    └─────────────────┘
```

**Visual QA modes:**
- `--visual-qa=quick` (default): Console + DOM error checks
- `--visual-qa=full`: Screenshots + interactive review
- `--visual-qa=skip`: Skip entirely (backend-only waves)

---

## Atomic Skills

### Worker Skills (bdw-*)

| Skill | Purpose | Blocking? |
|-------|---------|-----------|
| `/conductor:bdw-verify-build` | Run build (CHANGE_TYPE=code) | ⛔ Yes |
| `/conductor:bdw-run-tests` | Run tests (CHANGE_TYPE=code) | ⛔ Yes |
| `/conductor:bdw-code-review` | Sonnet review (worker applies fixes) | ⛔ Yes |
| `/conductor:bdw-codex-review` | Cheaper Codex review | ⛔ Yes |
| `/conductor:bdw-commit-changes` | Stage + commit | ⛔ Yes |
| `/conductor:bdw-create-followups` | Create beads issues | No |
| `/conductor:bdw-update-docs` | Verify beads + update docs | No |
| `/conductor:bdw-close-issue` | Close beads issue | ⛔ Yes |
| `/conductor:bdw-worker-done` | Full pipeline (detects CHANGE_TYPE) | ⛔ Yes |
| `/conductor:bdw-worker-init` | Initialize worker context | No |

**CHANGE_TYPE detection:** `bdw-worker-done` detects change types:
- `code` → Run build + tests
- `plugin` → Run plugin-validator (markdown, plugin.json, etc.)
- `none` → Skip to commit

### Conductor Skills (bdc-*)

| Skill | Purpose | Blocking? |
|-------|---------|-----------|
| `/conductor:bdc-swarm-auto` | Autonomous wave execution | ⛔ Yes |
| `/conductor:bdc-wave-done` | Merge + unified review + visual QA | ⛔ Yes |
| `/conductor:bdc-visual-qa` | Visual QA (forked tabz-manager subagent) | ⛔ Yes |
| `/conductor:bdc-run-wave` | Run wave from template | ⛔ Yes |
| `/conductor:bdc-orchestration` | Multi-session coordination | ⛔ Yes |
| `/conductor:bdc-analyze-transcripts` | Review worker sessions | No |

---

## Agents

| Agent | Purpose | Model |
|-------|---------|-------|
| `conductor:conductor` | Orchestrate workflows | opus |
| `conductor:code-reviewer` | Read-only review (worker applies fixes) | sonnet |
| `conductor:skill-picker` | Find skills | haiku |
| `conductor:docs-updater` | DEPRECATED - use bdw-update-docs | haiku |
| `conductor:silent-failure-hunter` | Error handling audit | sonnet |
| `conductor:tabz-manager` | Browser automation (70 MCP tools) | opus |

**Note:** `tabz-artist` is now a skill that runs in tabz-manager context, not a standalone agent.

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
/conductor:bd-start [issue-id]
# Does: select → claim → implement → verify → test → commit → close → push
```

### For Interactive Orchestration (spawning workers)

```bash
/conductor:bd-conduct
# Interactive: select issues, terminal count (1-4), mode
# Then spawns workers
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

### Current Commands

| Command | Purpose |
|---------|---------|
| `bd-plan.md` | Prepare backlog |
| `bd-start.md` | YOU work directly |
| `bd-status.md` | View issue state |
| `bd-conduct.md` | Interactive orchestration (1-4 workers) |
| `bd-new-project.md` | Project scaffolding |

---

## Implementation Status

### Completed

| Feature | Status |
|---------|--------|
| Prefix taxonomy (bd-, bdc-, bdw-) | ✅ |
| `/conductor:bd-start` command | ✅ |
| `/conductor:bd-plan` command | ✅ |
| `/conductor:bd-conduct` command | ✅ |
| `/conductor:bd-status` command | ✅ |
| `/conductor:bd-new-project` command | ✅ |
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
