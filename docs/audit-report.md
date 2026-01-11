# Documentation Audit Report - TabzBeads

**Date**: 2026-01-10
**Auditor**: Claude Opus 4.5

---

## Executive Summary

The TabzBeads documentation has significant inconsistencies between documented and actual command names. The prefix taxonomy (bd-/bdc-/bdw-) was implemented but documentation was not fully updated to reflect the new naming convention. Several components are also missing from CLAUDE.md.

**Total Issues Found**: 28
- **High Priority**: 13 (command name inconsistencies)
- **Medium Priority**: 10 (missing documentation)
- **Low Priority**: 5 (minor inconsistencies)

---

## Issue 1: Command Name Inconsistencies (HIGH)

The actual commands use the prefix taxonomy (bdw-/bdc-) but most documentation still references old names without prefixes.

### 1.1 Worker Commands (bdw-*)

| Old Reference | Correct Name | Files Affected |
|--------------|--------------|----------------|
| `/conductor:worker-done` | `/conductor:bdw-worker-done` | 40+ files |
| `/conductor:verify-build` | `/conductor:bdw-verify-build` | 25+ files |
| `/conductor:run-tests` | `/conductor:bdw-run-tests` | 15+ files |
| `/conductor:commit-changes` | `/conductor:bdw-commit-changes` | 25+ files |
| `/conductor:close-issue` | `/conductor:bdw-close-issue` | 20+ files |
| `/conductor:code-review` | `/conductor:bdw-code-review` | 20+ files |
| `/conductor:codex-review` | `/conductor:bdw-codex-review` | 5+ files |
| `/conductor:create-followups` | `/conductor:bdw-create-followups` | 5+ files |
| `/conductor:update-docs` | `/conductor:bdw-update-docs` | 5+ files |

**Affected Files** (partial list):
- `docs/PRIME-template.md` (lines 14-18, 24-26, 32-35, 101-104, 140-146)
- `plugins/conductor/commands/bdw-worker-done.md` (description line, many internal refs)
- `plugins/conductor/commands/bdc-wave-done.md`
- `plugins/conductor/skills/worker-done/SKILL.md`
- `plugins/conductor/skills/wave-done/SKILL.md`
- `plugins/conductor/agents/conductor.md`

**Suggested Fix**: Batch rename all references. Use `sed` or similar:
```bash
find plugins docs -name "*.md" -exec sed -i \
  -e 's|/conductor:worker-done|/conductor:bdw-worker-done|g' \
  -e 's|/conductor:verify-build|/conductor:bdw-verify-build|g' \
  -e 's|/conductor:run-tests|/conductor:bdw-run-tests|g' \
  -e 's|/conductor:commit-changes|/conductor:bdw-commit-changes|g' \
  -e 's|/conductor:close-issue|/conductor:bdw-close-issue|g' \
  -e 's|/conductor:code-review|/conductor:bdw-code-review|g' \
  -e 's|/conductor:codex-review|/conductor:bdw-codex-review|g' \
  -e 's|/conductor:create-followups|/conductor:bdw-create-followups|g' \
  -e 's|/conductor:update-docs|/conductor:bdw-update-docs|g' \
  {} \;
```

### 1.2 Conductor Commands (bdc-*)

| Old Reference | Correct Name | Files Affected |
|--------------|--------------|----------------|
| `/conductor:wave-done` | `/conductor:bdc-wave-done` | 25+ files |
| `/conductor:analyze-transcripts` | `/conductor:bdc-analyze-transcripts` | 3 files |

**Suggested Fix**: Add to the batch rename above:
```bash
  -e 's|/conductor:wave-done|/conductor:bdc-wave-done|g' \
  -e 's|/conductor:analyze-transcripts|/conductor:bdc-analyze-transcripts|g' \
```

**Priority**: HIGH - These inconsistencies will cause commands to fail when invoked.

---

## Issue 2: CLAUDE.md Missing Components (MEDIUM)

### 2.1 Missing Scripts

CLAUDE.md only mentions `setup-worktree.sh` but 7 scripts exist:

| Script | Purpose | Status |
|--------|---------|--------|
| `setup-worktree.sh` | Create git worktrees | Documented |
| `match-skills.sh` | Skill matching for issues | **Missing** |
| `lookahead-enhancer.sh` | Parallel prompt preparation | **Missing** |
| `completion-pipeline.sh` | Worker completion automation | **Missing** |
| `wave-summary.sh` | Generate wave summaries | **Missing** |
| `capture-session.sh` | Capture tmux transcripts | **Missing** |
| `discover-skills.sh` | Skill discovery | **Missing** |

**Suggested Fix**: Update CLAUDE.md conductor architecture section:
```markdown
└── scripts/                     # Shell automation
    ├── setup-worktree.sh        # Git worktree creation
    ├── match-skills.sh          # Issue-to-skill matching
    ├── lookahead-enhancer.sh    # Parallel prompt preparation
    ├── completion-pipeline.sh   # Automated wave completion
    ├── wave-summary.sh          # Generate wave summaries
    ├── capture-session.sh       # Capture session transcripts
    └── discover-skills.sh       # Runtime skill discovery
```

### 2.2 Missing Skills

CLAUDE.md only mentions `bd-conduct` but 10 skills exist:

| Skill | Purpose | Status |
|-------|---------|--------|
| `bd-conduct` | Interactive orchestration | Documented |
| `code-review` | Code review skill | **Missing** |
| `new-project` | New project setup | **Missing** |
| `tabz-artist` | Visual asset generation | **Missing** |
| `tabz-mcp` | Browser automation | **Missing** |
| `terminal-tools` | TUI tool control | **Missing** |
| `orchestration` | Multi-session coordination | **Missing** |
| `wave-done` | Wave completion skill | **Missing** |
| `bd-swarm-auto` | Autonomous swarm | **Missing** |
| `worker-done` | Worker completion skill | **Missing** |

**Suggested Fix**: Update skills section in CLAUDE.md.

### 2.3 Missing Agents

CLAUDE.md mentions `conductor.md` and `code-reviewer.md` but 5 agents exist:

| Agent | Purpose | Status |
|-------|---------|--------|
| `conductor.md` | Main orchestrator | Documented |
| `code-reviewer.md` | Code review | Documented |
| `docs-updater.md` | Update documentation | **Missing** |
| `skill-picker.md` | Find skills for issues | **Missing** |
| `prompt-enhancer.md` | Optimize prompts | **Missing** |

**Suggested Fix**: Update agents section.

### 2.4 Missing Commands in CLAUDE.md

The Commands Reference table is missing several commands:

**bdw-* (Worker Internal) missing:**
- `bdw-codex-review` - Cost-effective Codex review
- `bdw-create-followups` - Create follow-up issues
- `bdw-update-docs` - Update documentation
- `bdw-worker-init` - Initialize worker context

**bdc-* (Conductor Internal) missing:**
- `bdc-analyze-transcripts` - Review worker sessions
- `bdc-run-wave` - Run wave from formula

**Non-prefixed commands (not following taxonomy):**
- `new-project` - Project scaffolding
- `tabz-artist` - Visual asset generation
- `tabz-mcp` - Browser automation
- `terminal-tools` - TUI tool reference

**Priority**: MEDIUM - Missing documentation but commands still work.

---

## Issue 3: Non-Prefixed Commands (LOW)

Several commands don't follow the prefix taxonomy:

| Command | Current Name | Should Be |
|---------|--------------|-----------|
| `new-project.md` | `/conductor:new-project` | Keep as-is (user entry point) |
| `tabz-artist.md` | `/conductor:tabz-artist` | Keep as-is (user entry point) |
| `tabz-mcp.md` | `/conductor:tabz-mcp` | Keep as-is (user entry point) |
| `terminal-tools.md` | `/conductor:terminal-tools` | Keep as-is (reference) |

**Analysis**: These are user-facing commands and don't need the prefix taxonomy. They should be documented in CLAUDE.md under a separate "Additional Commands" section.

**Priority**: LOW - Not a bug, just missing documentation.

---

## Issue 4: Skill Invocation Format Inconsistency (MEDIUM)

`match-skills.sh` uses different invocation formats:

```bash
# Conductor skills (correct)
"browser|screenshot|click|mcp|tabz_|automation|/conductor:tabz-mcp"

# User-level plugins (using plugin:skill format)
"ui|component|modal|dashboard|styling|tailwind|shadcn|form|button|/ui-styling:ui-styling"
"react|next|vue|svelte|frontend|/frontend-development:frontend-development"
```

The `get_issue_skills()` function converts shorthand to full format:
- `ui-styling` -> `/ui-styling:ui-styling`
- `conductor:tabz-mcp` -> `/conductor:tabz-mcp`

This is inconsistent with how skills are documented in CLAUDE.md.

**Suggested Fix**: Document the skill invocation format clearly in CLAUDE.md:
```markdown
## Skill Invocation Formats

- Conductor skills: `/conductor:skill-name` (e.g., `/conductor:tabz-mcp`)
- Plugin skills: `/plugin-name:skill-name` (e.g., `/frontend:ui-styling`)
- Project skills: `/skill-name` (shorthand, e.g., `/tabz-guide`)
```

**Priority**: MEDIUM - Affects skill matching but not critically broken.

---

## Issue 5: Formula Documentation Complete (OK)

The `conductor-wave.formula.toml` exists and is documented in CLAUDE.md correctly:
- Located at `.beads/formulas/conductor-wave.formula.toml`
- Documented in CLAUDE.md under "Molecule Templates"
- `bdc-run-wave.md` correctly references it

**Status**: No issues found.

---

## Issue 6: docs/conductor-workflows.md Inconsistencies (MEDIUM)

### 6.1 Atomic Commands Table

The "Atomic Commands" section uses old command names (lines 420-440):
- Should use `bdw-*` prefixes

### 6.2 Implementation Status

References to molecule features show issue IDs that may be outdated:
- `TabzBeads-u7c` - Molecules
- `TabzBeads-32q` - Complexity-aware pipeline

**Suggested Fix**: Verify these issue IDs still exist and are accurate.

---

## Issue 7: Duplicate Content (LOW)

The following files appear to have duplicate/similar content:

| File | Duplicate Of |
|------|--------------|
| `plugins/conductor/skills/worker-done/SKILL.md` | `plugins/conductor/commands/bdw-worker-done.md` |
| `plugins/conductor/skills/wave-done/SKILL.md` | `plugins/conductor/commands/bdc-wave-done.md` |

**Analysis**: This may be intentional (skill vs command), but the content should be kept in sync or one should reference the other.

**Priority**: LOW - Not breaking, but maintenance burden.

---

## Summary of Suggested Fixes

### Immediate (HIGH priority)

1. **Batch rename command references** - Run sed script to update all old command names to new prefix format

### Soon (MEDIUM priority)

2. **Update CLAUDE.md** - Add missing scripts, skills, agents, and commands
3. **Update docs/conductor-workflows.md** - Fix command names in Atomic Commands table
4. **Document skill invocation format** - Add clear section on skill invocation syntax

### Later (LOW priority)

5. **Document non-prefixed commands** - Add section for tabz-artist, tabz-mcp, etc.
6. **Consider deduplicating skills/commands** - Either sync content or reference

---

## Files Requiring Updates

| File | Priority | Issues |
|------|----------|--------|
| `CLAUDE.md` | MEDIUM | Missing scripts, skills, agents, commands |
| `docs/PRIME-template.md` | HIGH | Old command names |
| `docs/conductor-workflows.md` | MEDIUM | Old command names |
| `plugins/conductor/commands/bdw-worker-done.md` | HIGH | Self-referencing old name |
| `plugins/conductor/commands/bdc-wave-done.md` | HIGH | Old command names |
| `plugins/conductor/skills/worker-done/SKILL.md` | HIGH | Old command names |
| `plugins/conductor/skills/wave-done/SKILL.md` | HIGH | Old command names |
| `plugins/conductor/agents/conductor.md` | HIGH | Old command names |
| `plugins/conductor/references/*.md` | MEDIUM | Old command names |

---

## Appendix: Full Script for Batch Rename

```bash
#!/bin/bash
# fix-command-names.sh - Update all command references to use new prefix taxonomy

find plugins docs -name "*.md" -exec sed -i \
  -e 's|/conductor:worker-done|/conductor:bdw-worker-done|g' \
  -e 's|/conductor:verify-build|/conductor:bdw-verify-build|g' \
  -e 's|/conductor:run-tests|/conductor:bdw-run-tests|g' \
  -e 's|/conductor:commit-changes|/conductor:bdw-commit-changes|g' \
  -e 's|/conductor:close-issue|/conductor:bdw-close-issue|g' \
  -e 's|/conductor:code-review|/conductor:bdw-code-review|g' \
  -e 's|/conductor:codex-review|/conductor:bdw-codex-review|g' \
  -e 's|/conductor:create-followups|/conductor:bdw-create-followups|g' \
  -e 's|/conductor:update-docs|/conductor:bdw-update-docs|g' \
  -e 's|/conductor:wave-done|/conductor:bdc-wave-done|g' \
  -e 's|/conductor:analyze-transcripts|/conductor:bdc-analyze-transcripts|g' \
  -e 's|/conductor:swarm-auto|/conductor:bdc-swarm-auto|g' \
  {} \;

echo "Command names updated. Review changes with: git diff"
```

**Note**: Run with caution and review changes before committing.
