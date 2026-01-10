# Plugin Audit Report

Generated: 2026-01-09

## Executive Summary

| Directory | Grade | Summary |
|-----------|-------|---------|
| plugins/conductor/ | **B+** | Well-structured orchestration plugin with comprehensive skills/agents. Some inconsistencies in frontmatter and one skill missing proper YAML. |
| my-plugins/plugins/tools/code-review/ | **A** | Excellent structure, consistent frontmatter, good progressive disclosure with references. Model plugin. |
| my-plugins/plugins/frontend/frontend-development/ | **A-** | Strong patterns with agent orchestration. Minor issue: skill name in frontmatter doesn't match convention. |
| my-plugins/plugins/backend/backend-development/ | **B** | Good content but references lack YAML frontmatter. Agent/skill structure is sound. |

---

## Detailed Analysis

### 1. plugins/conductor/

**Skills (11 total)**

| Skill | Frontmatter | Name | Description Quality | Progressive Disclosure |
|-------|-------------|------|---------------------|------------------------|
| work/SKILL.md | Yes | `work` | Excellent - clear trigger | Good |
| wave-done/SKILL.md | Yes | `wave-done` | Excellent - includes invocation | Good |
| worker-done/SKILL.md | Yes | `worker-done` | Excellent - includes invocation | Good |
| bd-swarm-auto/SKILL.md | Yes | `bd-swarm-auto` | Excellent - clear use case | Good |
| code-review/SKILL.md | Yes | `code-review` | Excellent - modes explained | Excellent |
| new-project/SKILL.md | Yes | `new-project` | Good | Good |
| orchestration/SKILL.md | Yes | `orchestration` | Excellent - detailed triggers | Good |
| plan/SKILL.md | Yes | `bd-plan` | Good | Good |
| tabz-artist/SKILL.md | Yes | `TabzArtist` | Excellent - spawnable mention | Good |
| tabz-mcp/SKILL.md | Yes | `tabz-mcp` | Excellent - trigger phrases | Excellent |
| terminal-tools/SKILL.md | **NO** | N/A | N/A - Reference doc masquerading as skill | Poor |

**Agents (9 total)**

| Agent | Frontmatter Complete | Model | Tools Specified | Focused Role |
|-------|---------------------|-------|-----------------|--------------|
| conductor.md | Yes | opus | Yes (7 tools) | Yes |
| code-reviewer.md | Yes | opus | No (inherits all) | Yes |
| skill-picker.md | Yes | haiku | Yes (4 tools) | Yes |
| tabz-manager.md | Yes | opus | Yes (3 tools) | Yes |
| docs-updater.md | Yes | opus | Yes (6 tools) | Yes |
| prompt-enhancer.md | Yes | haiku | Yes (4 tools) | Yes |
| silent-failure-hunter.md | Yes | sonnet | No (inherits all) | Yes |
| tui-expert.md | Yes | opus | Yes (2 tools) | Yes |
| tabz-artist.md | Yes | opus | Yes (3 tools) | Yes |

**Issues Found:**

1. **terminal-tools/SKILL.md** - Missing YAML frontmatter entirely. This is a reference document, not a skill.
   - **Path:** `plugins/conductor/skills/terminal-tools/SKILL.md`
   - **Fix:** Move to `references/` or add proper frontmatter with `name` and `description`

2. **code-reviewer.md** - No `tools` restriction, inherits all tools
   - **Path:** `plugins/conductor/agents/code-reviewer.md`
   - **Fix:** Add `tools: [Read, Grep, Glob, Bash]` - reviewer shouldn't need Write/Edit

3. **silent-failure-hunter.md** - No `tools` restriction
   - **Path:** `plugins/conductor/agents/silent-failure-hunter.md`
   - **Fix:** Add `tools: [Read, Grep, Glob]` - auditor is read-only

4. **Naming inconsistency** - `plan/SKILL.md` uses `bd-plan` but skill invocation is `/conductor:plan`
   - **Path:** `plugins/conductor/skills/plan/SKILL.md`
   - **Fix:** Rename to `plan` for consistency

5. **TabzArtist naming** - Uses PascalCase (`TabzArtist`) instead of kebab-case
   - **Path:** `plugins/conductor/skills/tabz-artist/SKILL.md`
   - **Fix:** Change name to `tabz-artist` for consistency

---

### 2. my-plugins/plugins/tools/code-review/

**Skills (4 total)**

| Skill | Frontmatter | Name | Description Quality | Progressive Disclosure |
|-------|-------------|------|---------------------|------------------------|
| review/SKILL.md | Yes | `review` | Excellent - modes explained | Excellent |
| security/SKILL.md | Yes | `security` | Excellent - OWASP mentioned | Good |
| silent-failures/SKILL.md | Yes | `silent-failures` | Excellent - clear patterns | Good |
| review-practices/SKILL.md | Yes | `review-practices` | Excellent - three practices | Excellent with refs |

**Agents (1 total)**

| Agent | Frontmatter Complete | Model | Tools Specified | Focused Role |
|-------|---------------------|-------|-----------------|--------------|
| reviewer.md | Yes | opus | No (inherits all) | Yes |

**References (3 total)**
All have proper YAML frontmatter with `name` and `description` - excellent pattern.

**Issues Found:**

1. **reviewer.md** - No `tools` restriction
   - **Path:** `my-plugins/plugins/tools/code-review/agents/reviewer.md`
   - **Fix:** Add `tools: [Read, Grep, Glob, Edit]` - reviewer needs Edit for auto-fix only

**Best Practices Observed:**
- References have YAML frontmatter (model to follow)
- Progressive skill loading (`review-practices` invokes child references)
- JSON output format specified for machine consumption
- Confidence-based filtering is consistent across all skills/agents

---

### 3. my-plugins/plugins/frontend/frontend-development/

**Skills (1 total)**

| Skill | Frontmatter | Name | Description Quality | Progressive Disclosure |
|-------|-------------|------|---------------------|------------------------|
| frontend-development/SKILL.md | Yes | `frontend-dev-guidelines` | Excellent - very detailed | Excellent with resources |

**Agents (1 total)**

| Agent | Frontmatter Complete | Model | Tools Specified | Focused Role |
|-------|---------------------|-------|-----------------|--------------|
| frontend-expert.md | Partial | N/A | No | Yes |

**Resources (10 total)**
Well-organized topic guides in `resources/` directory.

**Issues Found:**

1. **Skill name mismatch** - Folder is `frontend-development/` but name is `frontend-dev-guidelines`
   - **Path:** `my-plugins/plugins/frontend/frontend-development/skills/frontend-development/SKILL.md`
   - **Fix:** Change name to `frontend-development` for consistency

2. **Agent missing fields** - No `name`, `model`, or `tools` in frontmatter
   - **Path:** `my-plugins/plugins/frontend/frontend-development/agents/frontend-expert.md`
   - **Fix:** Add:
     ```yaml
     name: frontend-expert
     model: sonnet
     tools: [Read, Grep, Glob, Write, Edit]
     ```

3. **Resources lack frontmatter** - Unlike code-review references, these have no YAML
   - **Path:** `my-plugins/plugins/frontend/frontend-development/skills/frontend-development/resources/*.md`
   - **Fix:** Add `name` and `description` to each for discoverability

**Best Practices Observed:**
- Progressive skill loading pattern in agent
- Clear checklists for new component/feature creation
- Excellent separation of concerns (10 resource files)

---

### 4. my-plugins/plugins/backend/backend-development/

**Skills (1 total)**

| Skill | Frontmatter | Name | Description Quality | Progressive Disclosure |
|-------|-------------|------|---------------------|------------------------|
| backend-development/SKILL.md | Yes | `backend-development` | Excellent - comprehensive | Excellent with references |

**Agents (1 total)**

| Agent | Frontmatter Complete | Model | Tools Specified | Focused Role |
|-------|---------------------|-------|-----------------|--------------|
| backend-expert.md | Yes | sonnet | No | Yes |

**References (11 total)**
None have YAML frontmatter.

**Issues Found:**

1. **Agent missing tools** - No tool restriction specified
   - **Path:** `my-plugins/plugins/backend/backend-development/agents/backend-expert.md`
   - **Fix:** Add `tools: [Read, Grep, Glob, Write, Edit, Bash]`

2. **References lack frontmatter** - All 11 reference files have no YAML
   - **Path:** `my-plugins/plugins/backend/backend-development/skills/backend-development/references/*.md`
   - **Fix:** Add `name` and `description` to each (see code-review as model)

**Best Practices Observed:**
- Tiered knowledge architecture (agent → skill → references)
- Progressive disclosure agent design
- Decision matrices for technology selection

---

## Quick Wins

These are easy fixes with high impact:

### High Priority

1. **Add YAML frontmatter to terminal-tools/SKILL.md**
   ```yaml
   ---
   name: terminal-tools
   description: "Reference for tmux, TUI tools (btop, lazygit, lnav), and CLI utilities. Use when working with terminal-based interfaces."
   ---
   ```

2. **Add tools restriction to read-only agents**
   - `code-reviewer.md`: `tools: [Read, Grep, Glob, Edit]`
   - `silent-failure-hunter.md`: `tools: [Read, Grep, Glob]`
   - `reviewer.md`: `tools: [Read, Grep, Glob, Edit]`

3. **Fix naming inconsistencies**
   - `plan/SKILL.md`: Change `bd-plan` → `plan`
   - `tabz-artist/SKILL.md`: Change `TabzArtist` → `tabz-artist`
   - `frontend-development/SKILL.md`: Change `frontend-dev-guidelines` → `frontend-development`

### Medium Priority

4. **Add frontmatter to frontend resources** (10 files)
5. **Add frontmatter to backend references** (11 files)
6. **Add missing agent fields** for `frontend-expert.md`

---

## Best Examples to Follow

### Model Skill: `code-review/skills/review/SKILL.md`
- Clear description with modes explained
- Progressive disclosure (quick/standard/thorough)
- JSON output format specified
- Links to related skills

### Model Agent: `conductor/agents/skill-picker.md`
- Complete frontmatter (name, description, model, tools)
- Haiku for cost optimization
- Focused responsibility (marketplace only)
- Clear workflow described

### Model Reference: `code-review/skills/review-practices/references/verification-before-completion.md`
- Has YAML frontmatter with name/description
- Detailed trigger conditions in description
- Actionable patterns with examples
- Tables for quick scanning

### Model Architecture: `my-plugins/plugins/tools/code-review/`
- Skills invoke references progressively
- References have frontmatter for discoverability
- Agent is focused and restricted
- JSON output for machine consumption

---

## Checklist for New Skills

Based on this audit, use this checklist for new skills:

```markdown
## Skill Checklist

- [ ] YAML frontmatter present
- [ ] `name` matches folder name (kebab-case)
- [ ] `description` explains WHEN to use (trigger phrases)
- [ ] Core content comes first (not buried in references)
- [ ] References have their own frontmatter
- [ ] Progressive disclosure (link to references, don't embed)
- [ ] Output format specified if structured (JSON schema)
- [ ] Examples are correct and testable
```

## Checklist for New Agents

```markdown
## Agent Checklist

- [ ] YAML frontmatter present
- [ ] `name` is lowercase with hyphens
- [ ] `description` explains when to invoke
- [ ] `model` specified (haiku/sonnet/opus)
- [ ] `tools` restricted to minimum needed
- [ ] System prompt uses imperative form
- [ ] Invokes skills rather than embedding knowledge
- [ ] One clear specialty (not swiss army knife)
- [ ] No "CRITICAL/MUST" aggressive language
```

---

## Summary

| Category | Count | With Issues |
|----------|-------|-------------|
| Skills | 17 | 5 |
| Agents | 12 | 5 |
| References | 24 | 21 (missing frontmatter) |
| Commands | 17 | 0 (lighter structure expected) |

**Overall Grade: B+**

The plugins are well-architected with good separation of concerns. The main issues are:
1. Missing tool restrictions on agents (security concern)
2. Missing frontmatter on references (discoverability)
3. Minor naming inconsistencies

The code-review plugin is the gold standard to follow for new development.
