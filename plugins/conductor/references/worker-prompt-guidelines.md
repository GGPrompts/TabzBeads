# Worker Prompt Guidelines

Extracted from [Anthropic Claude 4.x Prompting Best Practices](../../references/anthropic-prompting-guide.md).

## Core Principles

### 1. Be Explicit

Claude 4.x follows instructions **precisely**. If you say "suggest changes," it will suggest—not implement.

| Less Effective | More Effective |
|----------------|----------------|
| Fix the bug | Fix the null reference error on line 45 of Terminal.tsx |
| Can you suggest improvements? | Make these improvements to the code |
| Improve the UI | Add loading state to the button with disabled styling |

### 2. Add Context (Explain WHY)

Claude generalizes from explanations. Provide motivation:

```text
# Less effective
Add error handling

# More effective
Add try-catch around the WebSocket connection to gracefully handle
backend disconnections. Currently users see a cryptic error.
```

### 3. Reference Existing Patterns

Point workers to existing code for consistency:

```text
Follow the same error handling pattern used in useTerminalSessions.ts
(lines 45-60) for consistency.
```

### 4. Soften Aggressive Language

Claude 4.x may overtrigger on aggressive phrasing:

| Avoid | Use Instead |
|-------|-------------|
| CRITICAL: You MUST use this tool | Use this tool when... |
| NEVER do X | Prefer Y over X because... |
| ALWAYS do Y | Default to Y for... |

### 5. Use Positive Framing

Tell Claude what TO DO, not what NOT to do:

- Instead of: "Do not use markdown"
- Try: "Write in smoothly flowing prose paragraphs"

## Worker Prompt Structure

```markdown
## Task: ISSUE-ID - Title
[What to do - explicit, actionable]

## Context
[Background, WHY this matters]
This task involves [domain keywords for skill activation]

## Key Files
[File paths as text - workers read on-demand]

## Approach
[Implementation guidance with domain keywords]

## When Done
Run `/conductor:bdw-worker-done ISSUE-ID`
```

## Anti-Patterns

| Anti-Pattern | Why It Fails | Better Approach |
|--------------|--------------|-----------------|
| ALL CAPS INSTRUCTIONS | Reads as shouting, overtriggers | Normal case with clear structure |
| "Don't do X" | Negative framing harder to follow | "Do Y instead" (positive framing) |
| Vague adjectives ("good", "proper") | Undefined, varies by interpretation | Specific criteria or examples |
| Full file contents in prompt | Bloats prompt, may be stale | File paths as text, read on-demand |

## Skill Activation via Keywords

Include domain-specific keywords to help skill identification:

| Domain | Keywords to Include |
|--------|---------------------|
| UI/Frontend | shadcn/ui components, Tailwind CSS, Radix UI |
| Terminal | xterm.js, resize handling, FitAddon, WebSocket PTY |
| Backend | FastAPI, REST API, Node.js, database patterns |
| Plugin dev | Claude Code plugin, skill creation, agent patterns |
| Browser | MCP tools, screenshots, browser automation |

The skill-eval hook handles activation automatically based on keywords.
