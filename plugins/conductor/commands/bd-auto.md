---
description: "Fully autonomous backlog completion. Runs waves until backlog empty with zero user prompts. Use when you want hands-off parallel issue processing."
---

# BD Auto - Hands-Off Autonomous Mode

Process the entire ready backlog autonomously. No prompts, no configuration - just execute.

## Usage

```bash
/conductor:bd-auto
```

## What Happens

1. Gets all ready issues (`bd ready`)
2. Checks for prepared prompts in issue notes
3. For unprepared issues: spawns Explore agents (haiku) to gather context
4. Crafts skill-aware prompts from exploration or uses prepared prompts
5. Spawns 3-4 workers (auto-calculated)
6. Runs waves until backlog empty
7. Merges, reviews, pushes after each wave
8. Continues until `bd ready` returns empty

## When to Use

- **End of day**: "Process overnight while I sleep"
- **Batch execution**: "Run everything that's ready"
- **Trusted backlog**: Issues are well-prepared via `bd-plan`

## Prerequisites

**Optional but recommended:** Run `/conductor:bd-plan` first for best results:
- Prepared prompts are richer (more context, better skill hints)
- Complexity estimation enables smart batching
- Dependencies are resolved upfront

**Without bd-plan:** Issues are still processed - Explore agents gather context on-the-fly before spawning workers. This works well for well-described issues but prepared prompts produce better results.

## Comparison

| Command | Selection | Prompts | Use Case |
|---------|-----------|---------|----------|
| `bd-start` | 1 issue | None | YOU work directly |
| `bd-conduct` | User picks | 3 prompts | Controlled parallel work |
| `bd-auto` | All ready | None | Hands-off batch processing |

---

## Execute

This command delegates to `/conductor:bdc-swarm-auto`. Run that workflow now with zero user prompts.

**IMPORTANT:** Do NOT ask the user any questions. Execute autonomously.

```
/conductor:bdc-swarm-auto
```
