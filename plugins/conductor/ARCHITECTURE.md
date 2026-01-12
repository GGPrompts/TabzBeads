# Conductor Architecture

Visual workflow diagrams with clickable skill references.

## Entry Points

```mermaid
flowchart LR
    subgraph "User Entry Points (bd-*)"
        plan["/bd-plan"]
        start["/bd-start"]
        status["/bd-status"]
        conduct["/bd-conduct"]
        newproj["/bd-new-project"]
    end

    plan --> |"prepare"| ready[(bd ready)]
    start --> |"you work"| worker_flow
    conduct --> |"spawn workers"| worker_spawn
    status --> |"read only"| ready
    newproj --> |"scaffold"| project[New Project]
```

---

## Standalone Workflow (bd-start)

When YOU work directly on an issue (no worker spawn).

```mermaid
flowchart TD
    subgraph "Phase 1: Setup"
        A1["bd ready"] --> A2["Select issue"]
        A2 --> A3["bd update --status=in_progress"]
    end

    subgraph "Phase 2: Work"
        B1["Explore codebase"] --> B2["Implement changes"]
    end

    subgraph "Phase 3: Complete"
        C1["bdw-verify-build"]
        C2["bdw-run-tests"]
        C3["bdw-commit-changes"]
        C4["bdw-close-issue"]
    end

    A3 --> B1
    B2 --> C1
    C1 --> C2
    C2 --> C3
    C3 --> C4
    C4 --> D1["bd sync && git push"]

    click C1 "skills/bdw-verify-build/SKILL.md"
    click C2 "skills/bdw-run-tests/SKILL.md"
    click C3 "skills/bdw-commit-changes/SKILL.md"
    click C4 "skills/bdw-close-issue/SKILL.md"
```

### Skills in this workflow

| Step | Skill | Purpose |
|------|-------|---------|
| Verify | [bdw-verify-build](skills/bdw-verify-build/SKILL.md) | Run build, report errors |
| Test | [bdw-run-tests](skills/bdw-run-tests/SKILL.md) | Run tests if available |
| Commit | [bdw-commit-changes](skills/bdw-commit-changes/SKILL.md) | Stage + conventional commit |
| Close | [bdw-close-issue](skills/bdw-close-issue/SKILL.md) | Close beads issue |

---

## Multi-Worker Workflow (bd-conduct)

Interactive orchestration spawning 1-4 workers.

```mermaid
flowchart TD
    subgraph "Conductor (Main Session)"
        A1["Select issues (multiSelect)"]
        A2["Choose terminals (1-4)"]
        A3["Choose mode (interactive/auto)"]
        A4["Setup worktrees"]
        A5["Spawn workers"]
        A6["Monitor progress"]
        A7["bdc-wave-done"]
    end

    subgraph "Worker 1"
        W1A["Receive prompt"]
        W1B["Work on issue"]
        W1C["bdw-worker-done"]
    end

    subgraph "Worker 2"
        W2A["Receive prompt"]
        W2B["Work on issue"]
        W2C["bdw-worker-done"]
    end

    A1 --> A2 --> A3 --> A4 --> A5
    A5 --> W1A & W2A
    W1A --> W1B --> W1C
    W2A --> W2B --> W2C
    W1C & W2C --> A6
    A6 --> A7
    A7 --> D1["Merge + Review + Push"]

    click A7 "skills/bdc-wave-done/SKILL.md"
    click W1C "skills/bdw-worker-done/SKILL.md"
    click W2C "skills/bdw-worker-done/SKILL.md"
```

### Conductor Skills (bdc-*)

| Skill | Purpose | When Used |
|-------|---------|-----------|
| [bdc-orchestration](skills/bdc-orchestration/SKILL.md) | Multi-session coordination patterns | During spawning |
| [bdc-swarm-auto](skills/bdc-swarm-auto/SKILL.md) | Autonomous waves until backlog empty | Auto mode |
| [bdc-wave-done](skills/bdc-wave-done/SKILL.md) | Merge branches, unified review, cleanup | After all workers complete |
| [bdc-run-wave](skills/bdc-run-wave/SKILL.md) | Run wave from molecule template | Template-based execution |
| [bdc-analyze-transcripts](skills/bdc-analyze-transcripts/SKILL.md) | Review worker session transcripts | Post-mortem |

---

## Worker Completion Pipeline (bdw-worker-done)

What happens when a worker finishes their task.

```mermaid
flowchart TD
    subgraph "bdw-worker-done Pipeline"
        S0["Detect change type"]
        S1["bdw-verify-build"]
        S2["bdw-run-tests"]
        S3["bdw-commit-changes"]
        S4["bdw-close-issue"]
        S5["Notify conductor"]
    end

    S0 --> S1
    S1 -->|"pass"| S2
    S1 -->|"fail"| F1["Fix & retry"]
    S2 -->|"pass"| S3
    S2 -->|"skip if none"| S3
    S3 --> S4
    S4 --> S5

    click S1 "skills/bdw-verify-build/SKILL.md"
    click S2 "skills/bdw-run-tests/SKILL.md"
    click S3 "skills/bdw-commit-changes/SKILL.md"
    click S4 "skills/bdw-close-issue/SKILL.md"
```

### Worker Skills (bdw-*)

| Skill | Purpose | Atomic? |
|-------|---------|---------|
| [bdw-worker-init](skills/bdw-worker-init/SKILL.md) | Initialize worker context | No |
| [bdw-worker-done](skills/bdw-worker-done/SKILL.md) | Full completion pipeline | No (orchestrator) |
| [bdw-verify-build](skills/bdw-verify-build/SKILL.md) | Run build, report errors | Yes |
| [bdw-run-tests](skills/bdw-run-tests/SKILL.md) | Run tests if available | Yes |
| [bdw-code-review](skills/bdw-code-review/SKILL.md) | Opus review with auto-fix | Yes |
| [bdw-codex-review](skills/bdw-codex-review/SKILL.md) | Cost-effective GPT review | Yes |
| [bdw-commit-changes](skills/bdw-commit-changes/SKILL.md) | Stage + commit | Yes |
| [bdw-close-issue](skills/bdw-close-issue/SKILL.md) | Close beads issue | Yes |
| [bdw-create-followups](skills/bdw-create-followups/SKILL.md) | Create follow-up issues | Yes |
| [bdw-update-docs](skills/bdw-update-docs/SKILL.md) | Update documentation | Yes |

---

## Wave Completion (bdc-wave-done)

After all workers finish, conductor runs unified completion.

```mermaid
flowchart TD
    subgraph "bdc-wave-done Pipeline"
        V1["Verify all workers done"]
        V2["Kill worker sessions"]
        V3["Merge branches to main"]
        V4["bdw-verify-build"]
        V5["Unified code review"]
        V6["Cleanup worktrees"]
        V7["bd sync && git push"]
        V8["Summary + notification"]
    end

    V1 --> V2 --> V3 --> V4 --> V5 --> V6 --> V7 --> V8

    click V5 "agents/code-reviewer.md"
```

---

## Agents (Spawnable Subagents)

Agents are spawned via Task tool for isolated work.

```mermaid
flowchart LR
    subgraph "Spawned by Conductor"
        AG1["code-reviewer"]
        AG2["docs-updater"]
        AG3["prompt-enhancer"]
        AG4["skill-picker"]
        AG5["tabz-artist"]
    end

    conductor["Conductor"] --> AG1 & AG2 & AG3 & AG4 & AG5

    click AG1 "agents/code-reviewer.md"
    click AG2 "agents/docs-updater.md"
    click AG3 "agents/prompt-enhancer.md"
    click AG4 "agents/skill-picker.md"
    click AG5 "agents/tabz-artist.md"
```

| Agent | Model | Purpose |
|-------|-------|---------|
| [conductor](agents/conductor.md) | Opus | Main orchestration |
| [code-reviewer](agents/code-reviewer.md) | Sonnet | Autonomous code review |
| [docs-updater](agents/docs-updater.md) | Opus | Update documentation |
| [prompt-enhancer](agents/prompt-enhancer.md) | Haiku | Optimize worker prompts |
| [skill-picker](agents/skill-picker.md) | Haiku | Find/install skills |
| [tabz-artist](agents/tabz-artist.md) | Sonnet | Visual asset generation |
| [silent-failure-hunter](agents/silent-failure-hunter.md) | Sonnet | Error handling audit |

---

## File Structure Map

```
plugins/conductor/
├── ARCHITECTURE.md          ← You are here
├── plugin.json
│
├── commands/                ← User entry points (visible in / menu)
│   ├── bd-plan.md
│   ├── bd-start.md
│   ├── bd-status.md
│   ├── bd-conduct.md
│   └── bd-new-project.md
│
├── skills/                  ← Workflow steps (hidden: user-invocable: false)
│   ├── bdc-orchestration/   ┐
│   ├── bdc-swarm-auto/      │ Conductor internal
│   ├── bdc-wave-done/       │
│   ├── bdc-run-wave/        │
│   ├── bdc-analyze-transcripts/ ┘
│   │
│   ├── bdw-worker-init/     ┐
│   ├── bdw-worker-done/     │
│   ├── bdw-verify-build/    │
│   ├── bdw-run-tests/       │ Worker steps
│   ├── bdw-code-review/     │
│   ├── bdw-codex-review/    │
│   ├── bdw-commit-changes/  │
│   ├── bdw-close-issue/     │
│   ├── bdw-create-followups/│
│   ├── bdw-update-docs/     ┘
│   │
│   ├── tabz-mcp/            ┐
│   ├── tabz-artist/         │ Special capabilities
│   └── terminal-tools/      ┘
│
├── agents/                  ← Spawnable subagents
│   ├── conductor.md
│   ├── code-reviewer.md
│   ├── docs-updater.md
│   ├── prompt-enhancer.md
│   ├── skill-picker.md
│   ├── tabz-artist.md
│   └── silent-failure-hunter.md
│
└── scripts/                 ← Shell automation
    ├── setup-worktree.sh
    ├── match-skills.sh
    ├── discover-skills.sh
    ├── completion-pipeline.sh
    ├── wave-summary.sh
    ├── capture-session.sh
    └── lookahead-enhancer.sh
```

---

## Quick Reference

### Prefix Taxonomy

| Prefix | Meaning | Visible in Menu |
|--------|---------|-----------------|
| `bd-*` | User entry points | Yes |
| `bdc-*` | Conductor internal | No |
| `bdw-*` | Worker steps | No |

### Workflow Selection

| Scenario | Use |
|----------|-----|
| Work on 1 issue yourself | `/conductor:bd-start` |
| Spawn workers for issues | `/conductor:bd-conduct` |
| Prepare backlog first | `/conductor:bd-plan` |
| Check project status | `/conductor:bd-status` |
| Fully autonomous | `/conductor:bdc-swarm-auto` |
