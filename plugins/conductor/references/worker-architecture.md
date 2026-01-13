# Worker Architecture

This document describes the unified worker architecture for parallel issue processing with bd-conduct.

## Overview

```
Worker (vanilla Claude via tmux/TabzChrome)
  ├─> Gets context from `bd show <issue-id>`
  ├─> Receives keyword-rich prompt (skill-eval hook activates skills automatically)
  ├─> Has SessionStart hooks inject PRIME.md and beads context
  └─> Completes with /conductor:bdw-worker-done
```

## What Workers ARE

- **Vanilla Claude sessions** spawned via TabzChrome API or direct tmux
- **Same plugin context** as the conductor (all skills available)
- **Keyword-activated** - domain keywords in prompts trigger skill-eval hook
- **Issue-focused** - each worker receives issue context and completes the task

## What Workers are NOT

- **NOT specialized agents** - no worker-frontend.md, worker-backend.md, etc.
- **NOT plugin-isolated** - no `--plugin-dir ./plugins/worker-minimal`
- **NOT explicit skill invokers** - keywords trigger skills via hook, not `/plugin:skill`

## Skill Activation

The **skill-eval hook** (UserPromptSubmit) automatically detects domain keywords and activates relevant skills. The conductor includes keywords in prompts:

| Issue Keywords | Keywords to Include | Skills Activated |
|----------------|---------------------|------------------|
| terminal, xterm, PTY, resize | xterm.js terminal, resize handling, FitAddon | xterm-js |
| UI, component, modal, dashboard | shadcn/ui components, Tailwind CSS styling | ui-styling |
| backend, API, server, database | backend development, REST API, Node.js | backend-development |
| browser, screenshot, click | browser automation, MCP tools | tabz-mcp |
| auth, login, oauth | Better Auth, OAuth, session management | better-auth |

## Why This Architecture?

1. **Simplicity** - Workers are just Claude sessions, no special configuration
2. **Hook-activated** - Skills activate automatically via keywords, no explicit invocations
3. **Flexible** - Same worker can handle any issue type with appropriate keywords
4. **Lean prompts** - File paths as text (not @file), keywords in Context section

## Worker Lifecycle

```
1. Spawn      → TabzChrome API or tmux creates session
2. Prompt     → Worker receives issue context + skill hint via tmux send-keys
3. Work       → Worker invokes skill when needed, reads files on-demand
4. Complete   → Worker runs /conductor:bdw-worker-done
5. Cleanup    → Session killed, worktree merged/removed
```

## Worker Prompt Guidelines

These guidelines ensure workers receive clear, effective prompts that Claude 4.x models follow precisely.

### Be Explicit

Claude 4.x models follow instructions **precisely**. If you say "suggest changes," Claude will suggest—not implement.

| Less Effective | More Effective |
|----------------|----------------|
| Fix the bug | Fix the null reference error on line 45 of Terminal.tsx when resize callback fires before terminal is initialized |
| Improve the UI | Add loading state to the button with disabled styling and spinner icon |
| Can you suggest improvements? | Make these improvements to the code |

### Add Context (Explain WHY)

Claude generalizes from explanations. Provide motivation:

```text
# Less effective
Add error handling

# More effective
Add try-catch around the WebSocket connection to gracefully handle
backend disconnections. Currently users see a cryptic error.
```

### Reference Existing Patterns

Point workers to existing code for consistency:

```text
Follow the same error handling pattern used in useTerminalSessions.ts
(lines 45-60) for consistency.
```

### Soften Aggressive Language

Avoid ALL CAPS and aggressive phrasing—Claude 4.x may overtrigger:

| Avoid | Use Instead |
|-------|-------------|
| CRITICAL: You MUST use this tool | Use this tool when... |
| NEVER do X | Prefer Y over X because... |
| ALWAYS do Y | Default to Y for... |

### Prompt Structure

Structure worker prompts in clear sections:

```markdown
## Task: ISSUE-ID - Title
[What to do - explicit, actionable]

## Context
[Background, WHY this matters]
This task involves [domain keywords: e.g., "FastAPI REST endpoint with PostgreSQL database"]

## Key Files
[File paths as text, not @file - workers read on-demand]

## Approach
[Implementation guidance - include domain keywords for skill activation]

## When Done
Run `/conductor:bdw-worker-done ISSUE-ID`
```

### Skill Activation via Keywords

The skill-eval hook (meta plugin) automatically activates relevant skills based on keywords in the prompt.
Include domain-specific keywords to help skill identification:

| Domain | Keywords to Include |
|--------|---------------------|
| UI/Frontend | shadcn/ui components, Tailwind CSS, Radix UI |
| Terminal | xterm.js, resize handling, FitAddon, WebSocket PTY |
| Backend | FastAPI, REST API, Node.js, database patterns |
| Plugin dev | Claude Code plugin, skill creation, agent patterns |
| Browser | MCP tools, screenshots, browser automation |

The hook handles activation - just include relevant keywords in the prompt context.

### Anti-Patterns

| Anti-Pattern | Why It Fails | Better Approach |
|--------------|--------------|-----------------|
| ALL CAPS INSTRUCTIONS | Reads as shouting, may overtrigger | Normal case with clear structure |
| "Don't do X" | Negative framing is harder to follow | "Do Y instead" (positive framing) |
| Vague adjectives ("good", "proper") | Undefined, varies by interpretation | Specific criteria or examples |
| Including full file contents | Bloats prompt, may be stale | File paths as text, read on-demand |

## Related Files

| File | Purpose |
|------|---------|
| `commands/bd-conduct.md` | Main orchestration workflow |
| `skills/bdc-swarm-auto/SKILL.md` | Autonomous backlog processing |
| `commands/bd-plan.md` | Sprint planning with skill matching |
| `scripts/completion-pipeline.sh` | Cleanup after workers complete |
