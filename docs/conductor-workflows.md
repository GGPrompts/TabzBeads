# Conductor Plugin - Complete Workflow Reference

This document maps all conductor plugin workflows, their components, and relationships. Use this to understand how the orchestration system works.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Entry Points](#entry-points)
3. [bd-swarm Pipeline](#bd-swarm-pipeline)
4. [Worker Pipeline](#worker-pipeline)
5. [worker-done Pipeline](#worker-done-pipeline)
6. [wave-done Pipeline](#wave-done-pipeline)
7. [Atomic Commands](#atomic-commands)
8. [Agents](#agents)
9. [Scripts](#scripts)
10. [Beads Context Integration](#beads-context-integration)
11. [Known Conflicts & Gaps](#known-conflicts--gaps)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CONDUCTOR                                    │
│            (orchestrates multi-session Claude work)                  │
└─────────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
   ┌─────────┐          ┌─────────┐          ┌─────────┐
   │ Worker  │          │ Worker  │          │ Worker  │
   │   1     │          │   2     │          │   3     │
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
| `[command]` | Slash command (`/conductor:X`) |
| `{agent}` | Subagent (`Task(subagent_type="...")`) |
| `(script)` | Shell script |
| `→` | Flow direction |
| `⛔` | Blocking (stops on failure) |

---

## Entry Points

Users invoke the conductor system through these commands:

```
┌─────────────────────────────────────────────────────────────────────┐
│                        USER ENTRY POINTS                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Single Issue:     /conductor:bd-work [issue-id]                    │
│                            ↓                                        │
│                    Spawns 1 worker (no worktree)                    │
│                                                                     │
│  Parallel Batch:   /conductor:bd-swarm                              │
│                            ↓                                        │
│                    Spawns N workers (with worktrees)                │
│                                                                     │
│  Full Auto:        /conductor:bd-swarm-auto                         │
│                            ↓                                        │
│                    Loops waves until bd ready empty                 │
│                                                                     │
│  Standalone:       /conductor:worker-done <id>                      │
│                            ↓                                        │
│                    Complete current work (no conductor)             │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### When to Use Each

| Entry Point | Use Case | Worktrees? | Code Review By |
|-------------|----------|------------|----------------|
| `bd-work` | Single issue, user watching | No | Optional (user decides) |
| `bd-swarm` | Batch parallel work | Yes | Conductor (wave-done) |
| `bd-swarm-auto` | Fully autonomous | Yes | Conductor (wave-done) |
| `worker-done` | Standalone completion | N/A | Skip (or manual) |

---

## bd-swarm Pipeline

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CONDUCTOR (bd-swarm)                             │
└─────────────────────────────────────────────────────────────────────┘
                              │
     ┌────────────────────────┼────────────────────────┐
     ▼                        ▼                        ▼
┌─────────────┐        ┌─────────────┐         ┌─────────────┐
│ 1. bd ready │        │ 2. VERIFY   │         │ 3. Setup    │
│   --json    │───────▶│   SKILLS    │────────▶│  Worktrees  │
│             │        │ (MANDATORY) │         │  (parallel) │
└─────────────┘        └─────────────┘         └─────────────┘
                              │                       │
                              ▼                       ▼
               scripts/match-skills.sh       scripts/setup-worktree.sh
               --available-full                    (per issue)
                                                      │
                              ┌────────────────────────┘
                              ▼
                    ┌─────────────────┐
                    │ 4. Spawn        │
                    │    Workers      │◀──── TabzChrome /api/spawn
                    │    (parallel)   │      or direct tmux
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ 5. Send Prompts │
                    │  (skill-aware)  │◀──── tmux send-keys
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ 6. POLL/WAIT    │◀──── scripts/monitor-workers.sh
                    │  for completion │      (every 2 min)
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ 7. wave-done    │◀──── /conductor:wave-done
                    │  (full cleanup) │
                    └─────────────────┘
                              │
            ┌─────────────────┴────────────────┐
            ▼ (auto mode)                      │
     ┌─────────────┐                           │
     │ LOOP: Check │                           │
     │  bd ready   │───▶ more issues? ─┐       │
     └─────────────┘                   │       │
            ▲                          ▼       │
            └──────────── START NEXT WAVE      │
                                               │
            bd ready empty? ───────────────────┘
                    ▼
              BACKLOG COMPLETE
```

### Key Points

- **Skill verification is MANDATORY** before crafting prompts
- Workers are spawned with `CONDUCTOR_SESSION` env var for notifications
- Workers run in isolated worktrees to prevent conflicts
- `BD_SOCKET` isolates beads daemon per worker

---

## Worker Pipeline

Each spawned worker follows this flow:

```
┌─────────────────────────────────────────────────────────────────────┐
│                    WORKER (spawned Claude session)                  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Receive Prompt  │
                    │ (from conductor)│
                    └─────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼ (optional)        ▼                   │
┌──────────────────┐ ┌─────────────────┐          │
│ /conductor:      │ │ Read Issue      │          │
│ worker-init      │ │ bd show <id>    │          │
│ (self-optimize)  │ └─────────────────┘          │
└──────────────────┘          │                   │
          │                   ▼                   │
          │          ┌─────────────────┐          │
          │          │ Invoke Skills   │          │
          │          │ /plugin:skill   │          │
          │          └─────────────────┘          │
          │                   │                   │
          └───────────────────┼───────────────────┘
                              ▼
                    ┌─────────────────┐
                    │   IMPLEMENT     │
                    │  (code changes) │
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────────────────────────────┐
                    │       /conductor:worker-done            │
                    └─────────────────────────────────────────┘
```

### Worker Prompt Template

All worker prompts should follow this structure:

```markdown
Fix beads issue ISSUE-ID: "Title"

## Skills to Load
**FIRST**, invoke these skills before starting work:
- /backend-development:backend-development
- /conductor:orchestration

These load patterns and context you'll need.

## Context
[WHY this matters - helps Claude generalize and make good decisions]

## Key Files
- path/to/file.ts (focus on lines X-Y)
- path/to/other.ts

## Approach
[Implementation guidance - what to do]

## Conductor Session
CONDUCTOR_SESSION=<conductor-tmux-session>
(Worker needs this to notify conductor on completion)

## When Done
Run `/conductor:worker-done ISSUE-ID`
```

**CRITICAL:** Use full `plugin:skill` format (e.g., `/backend-development:backend-development`), not shorthand.

---

## worker-done Pipeline

The `worker-done` skill orchestrates task completion through atomic commands:

```
┌─────────────────────────────────────────────────────────────────────┐
│                 /conductor:worker-done <issue-id>                   │
│                 (Task Completion Orchestrator)                      │
└─────────────────────────────────────────────────────────────────────┘
                              │
    ┌─────────────────────────┼─────────────────────────┐
    │ Step 0: Detect          │                         │
    │ Change Types            │                         │
    │ (DOCS_ONLY check)       │                         │
    └─────────────────────────┴─────────────────────────┘
                              │
            ┌─────────────────┴─────────────────┐
            ▼ (code changes)                   ▼ (DOCS_ONLY)
   ┌─────────────────┐                ┌─────────────────┐
   │ Step 1: ⛔      │                │ Step 1a: ⛔     │
   │ verify-build    │                │ plugin-validator│
   └─────────────────┘                │ agent           │
            │                         └─────────────────┘
            ▼                                  │
   ┌─────────────────┐                         │
   │ Step 2: ⛔      │                         │
   │ run-tests       │                         │
   └─────────────────┘                         │
            │                                  │
            └─────────────────┬────────────────┘
                              ▼
                    ┌─────────────────┐
                    │ Step 3: ⛔      │
                    │ commit-changes  │
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Step 4:         │  (non-blocking)
                    │ create-followups│
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Step 5:         │  (non-blocking)
                    │ update-docs     │
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Step 5.5:       │
                    │ Record to notes │  (audit trail)
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Step 6: ⛔      │
                    │ close-issue     │
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────────────────────────┐
                    │ Step 7: NOTIFY CONDUCTOR ⚠️ CRITICAL │
                    │ (tmux send-keys + API broadcast)    │
                    └─────────────────────────────────────┘
```

### Important: worker-done Does NOT Include Code Review

**Workers skip code review.** Code review happens at the conductor level (wave-done Step 5) after all workers complete. This prevents:
- Resource contention from parallel reviews
- Duplicate review effort
- Browser tab conflicts during visual QA

---

## wave-done Pipeline

The conductor runs `wave-done` after all workers complete:

```
┌─────────────────────────────────────────────────────────────────────┐
│              /conductor:wave-done <issue-ids>                       │
│              (Wave Completion Orchestrator)                         │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Step 1: ⛔      │
                    │ Verify all      │◀──── All issues must be closed
                    │ workers done    │
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Step 1.5:       │
                    │ Review worker   │◀──── Check discovered-from
                    │ discoveries     │      Check untracked TODOs
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Step 2:         │
                    │ Capture         │◀──── scripts/capture-session.sh
                    │ transcripts +   │      tmux kill-session
                    │ kill sessions   │
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Step 3: ⛔      │
                    │ Merge branches  │◀──── git merge (per branch)
                    │ to main         │
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Step 4: ⛔      │
                    │ verify-build    │◀──── Verify merged code builds
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Step 5: ⛔      │
                    │ code-review     │◀──── UNIFIED review (all changes)
                    │ (conductor-level)│      Workers do NOT review!
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Step 6:         │
                    │ Cleanup         │◀──── git worktree remove
                    │ worktrees +     │      git branch -d
                    │ branches        │
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Step 7:         │  (OPTIONAL - UI changes only)
                    │ Visual QA       │◀──── {conductor:tabz-manager}
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Step 8: ⛔      │
                    │ bd sync +       │◀──── git push origin main
                    │ git push        │
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Step 9:         │
                    │ Audio summary   │◀──── scripts/wave-summary.sh
                    └─────────────────┘
```

---

## Atomic Commands

Building blocks that can be composed into pipelines:

| Command | Purpose | Blocking? | Used By |
|---------|---------|-----------|---------|
| `/conductor:verify-build` | Run build, check for errors | ⛔ Yes | worker-done, wave-done |
| `/conductor:run-tests` | Run test suite | ⛔ Yes | worker-done |
| `/conductor:code-review` | Opus review (high-confidence auto-fix) | ⛔ Yes | wave-done ONLY |
| `/conductor:codex-review` | Cheaper OpenAI Codex review (read-only) | ⛔ Yes | Alternative to code-review |
| `/conductor:commit-changes` | Stage + commit with conventional format | ⛔ Yes | worker-done |
| `/conductor:create-followups` | Create follow-up beads issues | No | worker-done |
| `/conductor:update-docs` | Check/update documentation | No | worker-done |
| `/conductor:close-issue` | Close beads issue | ⛔ Yes | worker-done |

---

## Agents

Spawnable subagents for specialized tasks:

| Agent | Purpose | When Used |
|-------|---------|-----------|
| `conductor:conductor` | Orchestrate multi-session workflows | Main conductor |
| `conductor:tabz-manager` | Browser automation (screenshots, clicks) | Visual QA (wave-done Step 7) |
| `conductor:tui-expert` | TUI tools (btop, lazygit, lnav) | System inspection |
| `conductor:code-reviewer` | Autonomous code review | wave-done Step 5 |
| `conductor:skill-picker` | Find/install skills from skillsmp.com | Prompt enhancement |
| `conductor:prompt-enhancer` | Analyze issue, craft skill-aware prompt | worker-init |
| `conductor:docs-updater` | Update docs after feature wave | update-docs command |
| `conductor:silent-failure-hunter` | Find swallowed errors, empty catches | Thorough code review |
| `conductor:tabz-artist` | Generate images (DALL-E) and videos (Sora) | Visual asset creation |

---

## Scripts

Shell automation supporting the workflows:

| Script | Purpose | Called By |
|--------|---------|-----------|
| `setup-worktree.sh` | Create worktree + npm install + build | bd-swarm (parallel) |
| `monitor-workers.sh` | Poll worker status via tmuxplexer | bd-swarm polling loop |
| `match-skills.sh` | Map keywords → skill names | bd-swarm, bd-work, worker-init |
| `capture-session.sh` | Save tmux session output | wave-done Step 2 |
| `completion-pipeline.sh` | Quick cleanup (no review) | Alternative to wave-done |
| `wave-summary.sh` | Generate stats + audio notification | wave-done Step 9 |
| `discover-skills.sh` | List all available skills | Prompt crafting |

---

## Beads Context Integration

### How Context Gets Injected

1. Claude Code hooks call `bd prime` on `SessionStart` and `PreCompact`
2. `bd prime` outputs `.beads/PRIME.md` content
3. This appears as a `<system-reminder>` in the session

### PRIME.md Content Overview

The beads PRIME.md provides:
- Session close protocol (completion steps)
- Core beads rules
- Essential `bd` commands
- Common workflows

### Workflow Modes in PRIME.md

| Mode | Steps | Use Case |
|------|-------|----------|
| Standard Completion | verify → tests → review → commit → close → push | Standalone, thorough |
| Quick Completion | verify → commit → close → push | Trivial changes |
| Cost-Effective Review | verify → codex-review → commit → close → push | Budget-conscious |
| Full Pipeline | worker-done → push | Orchestrated workers |

---

## Known Conflicts & Gaps

### ⚠️ PRIME.md vs worker-done Conflict

| PRIME.md Says | worker-done Does | Issue |
|---------------|------------------|-------|
| Standard completion includes `code-review` | Workers skip code review | **Different contexts** |
| `bd sync && git push` after everything | Workers don't push | **Different responsibilities** |
| No mention of notify conductor | Step 7 is critical | **Missing for bd-swarm** |

**Root Cause:** PRIME.md is written for **standalone single-session work**, while worker-done is designed for **multi-session conductor-orchestrated work**.

### Resolution

PRIME.md should clarify:

```markdown
## Standalone Work (single session, no conductor)
Use full completion with review:
/conductor:verify-build
/conductor:run-tests
/conductor:code-review       # You do the review
/conductor:commit-changes
/conductor:close-issue <id>
bd sync && git push          # You push

## BD-Swarm Worker (spawned by conductor)
Use worker-done (conductor handles review + push):
/conductor:worker-done <id>  # Build → test → commit → close → NOTIFY
# DO NOT push - conductor handles merge + review + push
```

### ⚠️ Critical Steps Easy to Miss

| Step | Impact if Skipped | How to Prevent |
|------|-------------------|----------------|
| Skill verification (`--available-full`) | Workers fail on non-existent skills | Make it a blocking check |
| Step 7 (notify conductor) | Conductor has to poll, wastes resources | Enforce in worker-done |
| `CONDUCTOR_SESSION` env var | Notification fails silently | Validate on spawn |
| wave-done Step 1.5 (review discoveries) | Context lost when sessions killed | Add explicit prompt |

### ⚠️ Skill Invocation Format

**Wrong:** `/backend-development` or `"Use the X skill"`
**Right:** `/backend-development:backend-development`

Only project-level skills (in `.claude/skills/`) can use shorthand.

---

## Quick Reference Card

### For Standalone Work
```bash
# Complete task with review
/conductor:verify-build
/conductor:run-tests
/conductor:code-review
/conductor:commit-changes
/conductor:close-issue <id>
bd sync && git push
```

### For BD-Swarm Workers
```bash
# Let worker-done handle it (NO code review, NO push)
/conductor:worker-done <id>
# Worker is DONE - conductor takes over
```

### For Conductors After Wave
```bash
# Full wave cleanup with unified review
/conductor:wave-done <issue-ids>
# OR quick cleanup (skip review)
./plugins/conductor/scripts/completion-pipeline.sh "<issue-ids>"
```

---

## File Locations

| Component | Location |
|-----------|----------|
| Commands | `plugins/conductor/commands/*.md` |
| Skills | `plugins/conductor/skills/*/SKILL.md` |
| Agents | `plugins/conductor/agents/*.md` |
| Scripts | `plugins/conductor/scripts/*.sh` |
| Beads context | `~/.beads/PRIME.md` (global, symlinked to projects) |

---

# PROPOSED: Unified Interactive Architecture

> **Status**: Design proposal for simplifying the conductor workflow

## Problem Statement

The current system has too many entry points and flags:
- `bd-work`, `bd-swarm`, `bd-swarm-auto` (3 similar commands)
- Numerous `--flags` that users must memorize
- Prompt crafting happens at execution time (expensive, error-prone)
- No clear separation between research and implementation

## Proposed Solution

### Two Commands, Both Interactive

```
/conductor:refine   →  Prepare issues (research phase, cheap Haiku)
/conductor:work     →  Execute issues (implementation phase, Opus)
```

### Shift-Left Architecture

```
CURRENT (thinking during execution):
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ bd ready    │────▶│ Conductor   │────▶│ Worker      │
│ (raw issues)│     │ CRAFTS      │     │ executes    │
└─────────────┘     │ prompts     │     └─────────────┘
                    │ on-the-fly  │
                    └─────────────┘
                         ↑
                    BOTTLENECK
                    (slow, error-prone)

PROPOSED (pre-baked execution):
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ bd list     │────▶│ REFINEMENT  │────▶│ bd ready    │────▶│ Worker      │
│ (backlog)   │     │ (Haiku      │     │ (fully      │     │ (just       │
└─────────────┘     │  explorers) │     │  prepared)  │     │  executes)  │
                    └─────────────┘     └─────────────┘     └─────────────┘
                          │
                    Stores in issue:
                    • Full prompt
                    • Skills to load
                    • Completion steps
                    • Dependencies
```

### Interactive Issue Selection (No Flags)

Instead of:
```bash
/conductor:bd-swarm --auto --workers 3 --skip-review --issues abc,def
```

Use AskUserQuestion:
```
> /conductor:work

┌─────────────────────────────────────────────────────────────────┐
│ Which issues to work on?                           [multi-select]│
├─────────────────────────────────────────────────────────────────┤
│ ☑ TabzChrome-abc: Fix terminal resize corruption                │
│ ☑ TabzChrome-def: Add dark mode toggle                          │
│ ☐ TabzChrome-ghi: Update API documentation                      │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ How many workers?                                               │
├─────────────────────────────────────────────────────────────────┤
│ ○ 1 - Standalone (you watch, you review)                        │
│ ● 2-3 - Parallel (conductor merges & reviews)       (Recommended)│
│ ○ 4+ - Full swarm (max parallelism)                             │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ Completion steps?                                  [multi-select]│
├─────────────────────────────────────────────────────────────────┤
│ ☑ Build verification                                            │
│ ☑ Run tests                                                     │
│ ☐ Code review (Opus)                                            │
│ ☐ Visual QA                                                     │
└─────────────────────────────────────────────────────────────────┘
```

### Token-Efficient Refinement with Haiku

Use cheap Haiku models for exploration via pmux:

```
┌─────────────────────────────────────────────────────────────────────┐
│                    REFINEMENT PHASE                                  │
│                    (Haiku workers via pmux)                          │
└─────────────────────────────────────────────────────────────────────┘

  Issue 1              Issue 2              Issue 3
     │                    │                    │
     ▼                    ▼                    ▼
┌─────────┐         ┌─────────┐         ┌─────────┐
│ Haiku   │         │ Haiku   │         │ Haiku   │
│ Explorer│         │ Explorer│         │ Explorer│
│ (cheap) │         │ (cheap) │         │ (cheap) │
└─────────┘         └─────────┘         └─────────┘
     │                    │                    │
     │ Explores:          │                    │
     │ • Relevant files   │                    │
     │ • Patterns to use  │                    │
     │ • Skills to load   │                    │
     │ • Dependencies     │                    │
     ▼                    ▼                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                 BEADS (prepared prompts stored)                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Cost savings**: Haiku is ~20x cheaper than Opus. If each issue needs ~5k tokens of exploration:
- Current: 5k Opus tokens × N issues
- Proposed: 5k Haiku tokens × N issues

### Issue Structure After Refinement

```yaml
id: TabzChrome-abc
title: "Fix terminal resize corruption"
status: ready  # Only "ready" when fully prepared

prepared:
  prompt: |
    Fix beads issue TabzChrome-abc: "Fix terminal resize corruption"

    ## Skills to Load
    /xterm-js:xterm-js
    /ui-styling:ui-styling

    ## Context
    Rapidly narrowing sidebar during heavy output causes text wrapping
    corruption. Race condition between resize events and xterm.js buffer.

    ## Key Files
    - extension/components/Terminal.tsx (resize handling)
    - extension/hooks/useTerminalSessions.ts

    ## Approach
    Debounce resize events. Ensure FitAddon.fit() completes before
    new output arrives.

    ## When Done
    /conductor:complete

  skills: [xterm-js, ui-styling]
  mcp_tools: []
  completion:
    skip_tests: false
    skip_review: false
    docs_only: false
    needs_visual: true
  worker_count: 1
  estimated_complexity: medium
```

### Unified Completion (Adapts to Config)

```
Step                    │ When Included
────────────────────────┼─────────────────────────────────
verify-build            │ always (unless docs_only)
plugin-validator        │ only if docs_only
run-tests               │ unless skip_tests
commit-changes          │ always
code-review             │ workers=1 AND NOT skip_review
                        │ OR conductor after merge (workers>1)
visual-qa               │ only if needs_visual
close-issue             │ always
notify-conductor        │ only if workers > 1
push                    │ workers=1 OR conductor after merge
```

### Benefits Summary

| Aspect | Current | Proposed |
|--------|---------|----------|
| Entry points | 4+ commands | 2 commands |
| Configuration | Flags to memorize | Interactive prompts |
| Discoverability | Poor (`--help`) | Built-in (shows options) |
| Exploration cost | Opus (expensive) | Haiku (cheap) |
| Prompt quality | Variable (live crafting) | Consistent (pre-reviewed) |
| Debugging | Hard (context scattered) | Easy (everything in issue) |
| Parallelism | Bottlenecked | Unlimited (prompts pre-made) |

### Migration Path

1. Implement `/conductor:refine` with Haiku explorers via pmux
2. Add `prepared.*` fields to beads issue schema
3. Update `/conductor:work` to use AskUserQuestion
4. Deprecate `bd-work`, `bd-swarm`, `bd-swarm-auto`
5. Update PRIME.md with new two-command model

---

# PROPOSED: Beads-Native Architecture

> **Status**: Design proposal for leveraging beads' native agent, molecule, and worktree features

## Discovery

The [beads skill](https://github.com/steveyegge/beads/tree/main/skills/beads) documents features we're not using:

| Feature | Version | What It Does |
|---------|---------|--------------|
| Agent Beads | v0.40+ | First-class agent tracking with state machine |
| Molecules | v0.34+ | Reusable workflow templates (protos/mols/wisps) |
| `bd worktree` | v0.40+ | Beads-aware worktree management |
| Cross-project deps | v0.34+ | `bd ship` for capability publishing |

## Agent Beads for Workers

Instead of workers just tracking issues, **workers ARE agent beads**:

```bash
# Create agent bead for worker
bd create "Worker-TabzChrome-abc" --type agent

# State machine
bd agent spawn worker-id     # idle → spawning → running
bd agent working worker-id   # running → working (actively implementing)
bd agent done worker-id      # working → done
```

### Agent State Machine

```
                    ┌──────────┐
                    │   idle   │◀────────────────────┐
                    └────┬─────┘                     │
                         │ spawn                     │
                         ▼                           │
                    ┌──────────┐                     │
                    │ spawning │                     │
                    └────┬─────┘                     │
                         │ (auto)                    │
                         ▼                           │
                    ┌──────────┐                     │
            ┌──────▶│ running  │◀──────┐            │
            │       └────┬─────┘       │            │
            │            │ working     │            │
            │            ▼             │            │
            │       ┌──────────┐       │            │
            │       │ working  │───────┘            │
            │       └────┬─────┘  (pause)           │
            │            │                          │
            │            │ done                     │
     (unstuck)           ▼                          │
            │       ┌──────────┐                    │
            └───────│   done   │────────────────────┘
                    └──────────┘       (reset)
                         │
                    ┌────┴────┐
                    ▼         ▼
               ┌────────┐ ┌────────┐
               │ stuck  │ │  dead  │ (heartbeat timeout)
               └────────┘ └────────┘
```

### Benefits of Agent Beads

| Aspect | Current (Issue Tracking) | Proposed (Agent Beads) |
|--------|-------------------------|------------------------|
| Worker state | Implicit (check tmux) | Explicit state machine |
| Monitoring | Custom scripts | `bd agent list --state running` |
| Heartbeats | None | Built-in timeout detection |
| Role definition | In prompt | `bd create --type role` |
| Work attribution | Manual notes | Automatic via `hook` slot |

## Molecules for Workflow Templates

### The Chemistry Metaphor

| Phase | Name | Storage | Synced? | Use Case |
|-------|------|---------|---------|----------|
| **Solid** | Proto | `.beads/` | Yes | Reusable template |
| **Liquid** | Mol | `.beads/` | Yes | Persistent instance |
| **Vapor** | Wisp | `.beads-wisp/` | No | Ephemeral (no audit trail) |

### Conductor Wave as Proto

```bash
# Define once (solid template)
bd create "Conductor Wave" --type epic --label template
bd create "{{worker_count}} workers for {{issues}}" --type task
bd create "Setup worktrees" --type task
bd create "Spawn workers" --type task
bd create "Monitor completion" --type task
bd create "Merge branches" --type task
bd create "Unified code review" --type task
bd create "Cleanup worktrees" --type task
bd create "Push to main" --type task
# Link as parent-child dependencies...

# Each wave spawns from template (liquid instance)
bd mol run mol-conductor-wave --var issues="abc,def,ghi" --var worker_count=3
```

### When to Use Each Phase

| Scenario | Phase | Command |
|----------|-------|---------|
| Production wave (audit trail) | Mol (liquid) | `bd mol pour mol-conductor-wave` |
| Quick test run (no clutter) | Wisp (vapor) | `bd mol wisp mol-conductor-wave` |
| Define new workflow | Proto (solid) | Create epic with `template` label |
| Extract from ad-hoc work | Distill | `bd mol distill bd-xyz --as "My Workflow"` |

### Wisp for Ephemeral Operations

```bash
# Start ephemeral patrol
bd mol wisp mol-patrol

# Execute patrol work...

# End options:
bd mol squash wisp-abc --summary "3 issues found"  # Create digest, delete wisp
bd mol burn wisp-abc                                # Delete without trace
```

## `bd worktree` Instead of `git worktree`

### Why

The `bd worktree` command auto-configures:
- Beads database redirect files
- Proper gitignore entries
- Daemon bypass for worktree operations

### Current vs Proposed

```bash
# CURRENT (breaks beads)
git worktree add ../TabzChrome-abc feature/TabzChrome-abc
# Then manually configure beads...

# PROPOSED (beads-native)
bd worktree add TabzChrome-abc feature/TabzChrome-abc
# Beads automatically configured!
```

### Update setup-worktree.sh

```bash
# OLD
git worktree add "$WORKTREE_PATH" -b "feature/$ISSUE_ID"

# NEW
bd worktree add "$ISSUE_ID" "feature/$ISSUE_ID"
WORKTREE_PATH=$(bd worktree show "$ISSUE_ID" --path)
```

## Unified Beads-Native Workflow

```
┌─────────────────────────────────────────────────────────────────────┐
│                    /conductor:work                                   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ AskUserQuestion │
                    │ (issues, workers│
                    │  steps)         │
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ bd mol run      │  ← Spawn from Proto
                    │ mol-conductor   │
                    │ --var issues=.. │
                    └─────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
      ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
      │ bd worktree │ │ bd worktree │ │ bd worktree │  ← Beads-aware
      │ add abc ... │ │ add def ... │ │ add ghi ... │
      └─────────────┘ └─────────────┘ └─────────────┘
              │               │               │
              ▼               ▼               ▼
      ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
      │ bd create   │ │ bd create   │ │ bd create   │  ← Agent Beads
      │ --type agent│ │ --type agent│ │ --type agent│
      └─────────────┘ └─────────────┘ └─────────────┘
              │               │               │
              ▼               ▼               ▼
      ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
      │ bd agent    │ │ bd agent    │ │ bd agent    │
      │ spawn       │ │ spawn       │ │ spawn       │
      └─────────────┘ └─────────────┘ └─────────────┘
              │               │               │
              │    Workers execute...         │
              │               │               │
              ▼               ▼               ▼
      ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
      │ bd agent    │ │ bd agent    │ │ bd agent    │
      │ done        │ │ done        │ │ done        │
      └─────────────┘ └─────────────┘ └─────────────┘
              │               │               │
              └───────────────┼───────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Conductor       │
                    │ completes mol   │
                    │ (merge, review, │
                    │  cleanup, push) │
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ bd mol squash   │  ← Or keep for audit
                    │ (if wisp)       │
                    └─────────────────┘
```

## Monitoring with Agent Beads

```bash
# List all running workers
bd agent list --state running

# Check specific worker
bd agent show worker-abc

# Find stuck workers (heartbeat timeout)
bd agent list --state stuck

# Query by role
bd agent list --role conductor-worker
```

## Cross-Project Dependencies

For multi-repo work:

```bash
# Project A ships API capability
bd ship auth-api

# Project B depends on it
bd dep add bd-123 external:project-a:auth-api

# bd ready respects external deps
bd ready  # Won't show bd-123 until auth-api shipped
```

## Revised Migration Path

1. **Install beads skill** from official repo
2. **Create conductor protos** (mol-conductor-wave, mol-refine, etc.)
3. **Update scripts** to use `bd worktree` instead of `git worktree`
4. **Add agent bead creation** to worker spawn flow
5. **Replace custom monitoring** with `bd agent list`
6. **Update PRIME.md** with molecule/agent patterns
7. **Deprecate** custom state tracking in favor of beads-native

## Commands Summary

| Current | Beads-Native Replacement |
|---------|-------------------------|
| `git worktree add ...` | `bd worktree add ...` |
| Custom worker tracking | `bd create --type agent` |
| Custom state in notes | `bd agent spawn/working/done` |
| Ad-hoc wave setup | `bd mol run mol-conductor-wave` |
| Manual cleanup | `bd mol squash` or `bd mol burn` |
| Custom monitoring script | `bd agent list --state running` |

## Reference

- [Beads Skill](https://github.com/steveyegge/beads/tree/main/skills/beads)
- [AGENTS.md](https://github.com/steveyegge/beads/blob/main/skills/beads/resources/AGENTS.md)
- [MOLECULES.md](https://github.com/steveyegge/beads/blob/main/skills/beads/resources/MOLECULES.md)
- [WORKTREES.md](https://github.com/steveyegge/beads/blob/main/skills/beads/resources/WORKTREES.md)
