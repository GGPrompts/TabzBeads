# Conductor Plugin Comprehensive Audit

**Date:** 2026-01-13
**Scope:** TabzBeads conductor vs TabzChrome conductor (original)
**Status:** Conflicts identified, recommendations provided

---

## Executive Summary

The conductor plugin was migrated from TabzChrome to TabzBeads with significant restructuring. This audit found:

- **6 documentation conflicts** (1 critical)
- **Commands:** 18 → 23 (prefix taxonomy added)
- **Skills:** 9 → 2 (workflows moved to commands)
- **Agents:** 10 → 5 (consolidated)

**Critical Issue:** PRIME.md says `bdw-code-review` uses **Opus**, but all other documentation says **Sonnet**.

---

## 1. Command Inventory

### Current TabzBeads Commands (23 total)

#### User Entry Points (bd-*) - 6 commands
| Command | Purpose | Status |
|---------|---------|--------|
| `bd-plan` | Prepare backlog: analyze, match skills, estimate complexity | ✅ Documented |
| `bd-start` | YOU work directly on single issue (no spawn) | ✅ Documented |
| `bd-conduct` | Interactive orchestration (1-4 workers) | ✅ Documented |
| `bd-auto` | Fully autonomous (delegate to bdc-swarm-auto) | ⚠️ Missing from PRIME.md |
| `bd-status` | View issue state overview | ✅ Documented |
| `bd-new-project` | Multi-phase project scaffolding | ✅ Documented |

#### Conductor Internal (bdc-*) - 7 commands
| Command | Purpose |
|---------|---------|
| `bdc-swarm-auto` | Autonomous waves until backlog empty |
| `bdc-wave-done` | Merge branches, unified review, cleanup, push |
| `bdc-orchestration` | Multi-session coordination skill |
| `bdc-visual-qa` | Visual QA checks between waves (tabz-expert subagent) |
| `bdc-prompt-enhancer` | Enhance prompts with skills, key files |
| `bdc-run-wave` | Execute wave from molecule template |
| `bdc-analyze-transcripts` | Analyze worker session transcripts |

#### Worker Steps (bdw-*) - 10 commands
| Command | Purpose | Blocking |
|---------|---------|----------|
| `bdw-verify-build` | Run build, report errors | Yes |
| `bdw-run-tests` | Run tests if available | Yes |
| `bdw-code-review` | Code review (Sonnet, spawns subagent) | Yes |
| `bdw-codex-review` | Cheaper read-only review via OpenAI Codex | Yes |
| `bdw-commit-changes` | Stage + commit with conventional format | Yes |
| `bdw-close-issue` | Close beads issue with reason | Yes |
| `bdw-create-followups` | Create follow-up issues from TODOs | No |
| `bdw-update-docs` | Update README, CHANGELOG, CLAUDE.md | No |
| `bdw-worker-init` | Initialize worker context, match skills | No |
| `bdw-worker-done` | Full completion pipeline orchestrator | Yes |

---

## 2. Skills Inventory

### Current TabzBeads Skills (2 total)

| Skill | Purpose | Dependencies |
|-------|---------|--------------|
| `terminal-tools` | Reference for tmux mastery and TUI tool control | tmux, bash |
| `tabz-mcp` | Reference for 71 browser automation MCP tools | TabzChrome |

### Skills Removed (Converted to Commands)

| Former Skill | Now Command | Notes |
|--------------|-------------|-------|
| `bd-swarm-auto/` | `bd-auto` + `bdc-swarm-auto` | Split into user + internal |
| `code-review/` | `bdw-code-review` | Worker step |
| `new-project/` | `bd-new-project` | User entry point |
| `orchestration/` | `bdc-orchestration` | Conductor internal |
| `wave-done/` | `bdc-wave-done` | Conductor internal |
| `worker-done/` | `bdw-worker-done` | Worker step |

---

## 3. Agents Inventory

### Current TabzBeads Agents (5 total)

| Agent | Model | Purpose |
|-------|-------|---------|
| `conductor` | Opus | Main orchestrator - spawns workers, coordinates |
| `code-reviewer` | Sonnet | Read-only code review with confidence scoring |
| `skill-picker` | Haiku | Search/install skills from skillsmp.com |
| `silent-failure-hunter` | Sonnet | Find empty catches, swallowed errors |
| `docs-updater` | Haiku | **DEPRECATED** - use bdw-update-docs |

### Agents Removed

| Agent | Reason |
|-------|--------|
| `prompt-enhancer` | Converted to `bdc-prompt-enhancer` command |
| `tabz-artist` | Out of scope (visual assets elsewhere) |
| `tabz-manager` | Replaced by tabz MCP tools directly |
| `tui-expert` | Merged into `terminal-tools` skill |

---

## 4. TabzChrome vs TabzBeads Comparison

### Structure Changes

| Component | TabzChrome | TabzBeads | Change |
|-----------|------------|-----------|--------|
| Commands | 18 | 23 | +5 (split + new) |
| Skills | 9 | 2 | -7 (converted to commands) |
| Agents | 10 | 5 | -5 (consolidated) |
| Scripts | 7 | 7 | -1, +1 (replaced) |

### Naming Changes

| TabzChrome | TabzBeads | Type |
|------------|-----------|------|
| `plan-backlog` | `bd-plan` | Renamed |
| `bd-work` | `bd-start` | Renamed |
| `bd-swarm` | `bd-conduct` | Renamed |
| `bd-swarm-auto` | `bd-auto` + `bdc-swarm-auto` | Split |
| `verify-build` | `bdw-verify-build` | Prefixed |
| `run-tests` | `bdw-run-tests` | Prefixed |
| `commit-changes` | `bdw-commit-changes` | Prefixed |
| `close-issue` | `bdw-close-issue` | Prefixed |
| `worker-done` | `bdw-worker-done` | Prefixed |

### Key Architecture Changes

1. **Prefix Taxonomy (NEW):** bd-* (user), bdc-* (conductor), bdw-* (worker)
2. **Skills as Reference Only:** Workflows now commands, not skills
3. **Lean Agent Model:** 5 focused agents vs 10 specialized
4. **Commands as Orchestration:** Logic in commands, scripts support only

---

## 5. Documentation Conflicts

### CRITICAL: Code Review Model Mismatch

| File | Says |
|------|------|
| `.beads/PRIME.md` L41, L172 | "**Opus** review with auto-fix" |
| `CLAUDE.md` L276 | "**Sonnet** review, worker applies fixes" |
| `docs/PRIME-template.md` L16, L141 | "**Sonnet** review (you apply fixes)" |
| `docs/conductor-workflows.md` L406, L446 | "**Sonnet** review, worker applies fixes" |
| `plugins/conductor/commands/bdw-code-review.md` L14 | "Standard review (**Sonnet**)" |

**Consensus:** 5 of 6 sources say **Sonnet**. PRIME.md is wrong.

### Missing: bd-auto from PRIME Files

- **CLAUDE.md:** Listed at L163, L252
- **docs/conductor-workflows.md:** Fully documented L37, L106, L126
- **.beads/PRIME.md:** **MISSING**
- **docs/PRIME-template.md:** **MISSING**

### Unique Content in PRIME.md

These sections exist only in PRIME.md:
1. **MCP vs CLI Preference** (L6-29): Workspace context, `mcp-cli call beads/*`
2. **Terminal Communication** (L178-200): `load-buffer`/`paste-buffer` patterns

### Incomplete PRIME-template.md

Missing worker commands:
- `bdw-worker-init`
- `bdw-create-followups`

---

## 6. Recommendations

### Immediate Fixes

1. **Fix PRIME.md code review model** (Critical)
   - Change L41, L172 from "Opus" to "Sonnet"
   - Match CLAUDE.md and bdw-code-review.md

2. **Add bd-auto to PRIME files**
   - Add to `.beads/PRIME.md` user entry points
   - Add to `docs/PRIME-template.md`

3. **Complete PRIME-template.md**
   - Add `bdw-worker-init`, `bdw-create-followups`

### Documentation Sync

4. **Decide on MCP guidance location**
   - If universal: Add to CLAUDE.md
   - If PRIME-specific: Document in CLAUDE.md that PRIME has extended guidance

5. **Terminal patterns**
   - Add terminal communication section to CLAUDE.md
   - Or reference PRIME.md explicitly

### Complexity Reduction

6. **Archive deprecated agent**
   - Move `agents/docs-updater.md` to `plugins/archive/`
   - Or remove entirely (command exists)

7. **Consolidate reference docs**
   - 12 reference files could be reduced
   - `references/plan-backlog/` still uses old naming

---

## 7. Workflow Patterns Summary

### Critical Rules (Consistent Across All Docs)

1. **Workers NEVER run code review** - Conductor runs unified review after merge
2. **Max 4 workers** - Prevents statusline chaos
3. **Isolated worktrees** - Per-worker to prevent conflicts
4. **Worktrees cleaned before build** - Not after
5. **BD_SOCKET per worker** - Isolates beads daemon

### Completion Pipelines

**Standalone (you're the only session):**
```
bdw-verify-build → bdw-run-tests → bdw-code-review → bdw-commit-changes → bdw-close-issue → git push
```

**Worker (spawned by bd-conduct):**
```
bdw-worker-done → notify conductor → STOP
(Conductor handles merge + review + push)
```

### Skill Invocation (3 Methods)

1. **Keyword activation (automatic):** Hooks detect keywords, inject skills
2. **Natural trigger phrases (recommended):** "Use the ui-styling skill to..."
3. **Explicit invocation (deprecated):** `/conductor:skill-name`

---

## 8. File Structure Reference

```
plugins/conductor/
├── plugin.json                 # Plugin manifest
├── commands/                   # 23 commands
│   ├── bd-*.md                 # 6 user entry points
│   ├── bdc-*.md                # 7 conductor internal
│   └── bdw-*.md                # 10 worker steps
├── agents/                     # 5 agents
│   ├── conductor.md            # Main orchestrator (Opus)
│   ├── code-reviewer.md        # Code review (Sonnet)
│   ├── skill-picker.md         # Skill discovery (Haiku)
│   ├── silent-failure-hunter.md # Error audit (Sonnet)
│   └── docs-updater.md         # DEPRECATED
├── skills/                     # 2 reference skills
│   ├── tabz-mcp/SKILL.md       # Browser automation
│   └── terminal-tools/SKILL.md # Terminal patterns
├── references/                 # 12 supporting docs
│   ├── bdc-orchestration/
│   ├── bdc-swarm-auto/
│   ├── bdw-worker-done/
│   └── plan-backlog/
└── scripts/                    # 7 shell scripts
    ├── setup-worktree.sh
    ├── match-skills.sh
    ├── lookahead-enhancer.sh
    ├── completion-pipeline.sh
    ├── wave-summary.sh
    ├── capture-session.sh
    └── discover-skills.sh
```

---

## Appendix: Complete Command Reference

### Invocation Format

```bash
# User commands
/conductor:bd-plan
/conductor:bd-start <issue-id>
/conductor:bd-conduct
/conductor:bd-auto
/conductor:bd-status
/conductor:bd-new-project

# Conductor internal
/conductor:bdc-swarm-auto
/conductor:bdc-wave-done <issue-ids>
/conductor:bdc-orchestration
/conductor:bdc-visual-qa
/conductor:bdc-prompt-enhancer
/conductor:bdc-run-wave <issue-ids>
/conductor:bdc-analyze-transcripts

# Worker steps
/conductor:bdw-verify-build
/conductor:bdw-run-tests
/conductor:bdw-code-review
/conductor:bdw-codex-review
/conductor:bdw-commit-changes
/conductor:bdw-close-issue <issue-id>
/conductor:bdw-create-followups
/conductor:bdw-update-docs
/conductor:bdw-worker-init
/conductor:bdw-worker-done <issue-id>
```
