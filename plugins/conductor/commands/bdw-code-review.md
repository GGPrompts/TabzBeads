---
description: "Code review with parallel specialized reviewers. Modes: quick (Codex), standard (Codex + Sonnet parallel), thorough (+ Opus auto-fix). Confidence-based filtering (80+)."
---

# Code Review - Parallel Reviewer Pattern

Automated code review using parallel specialized reviewers for broad coverage with minimal cost.

**Architecture:** Cheap parallel agents (Codex/Sonnet) for coverage, Opus only for auto-fixes.

## Invocation

```bash
/conductor:bdw-code-review                    # Standard: Codex + silent-failure-hunter
/conductor:bdw-code-review --quick            # Quick: Codex only (cheapest)
/conductor:bdw-code-review --thorough         # Thorough: + Opus for auto-fix
/conductor:bdw-code-review <issue-id>         # Review for specific issue
```

## Review Stack

| Mode | Reviewers | Cost | Auto-fix |
|------|-----------|------|----------|
| `--quick` | Codex (GPT) | $ | ❌ |
| Standard | Codex + silent-failure-hunter (Sonnet) | $$ | ❌ |
| `--thorough` | Codex + silent-failure-hunter + code-reviewer (Opus) | $$$ | ✅ |

## Core Capabilities

### 1. Confidence-Based Review

Reviews code with precision scoring to minimize false positives:

| Score | Meaning | Action |
|-------|---------|--------|
| 0 | False positive / pre-existing | Skip |
| 25 | Might be real, can't verify | Skip |
| 50 | Real but minor nitpick | Skip |
| 75 | Likely real but uncertain | Skip |
| **80-94** | Verified issue | **Flag** |
| **95-100** | Certain bug or rule violation | **Auto-fix** |

### 2. Test Coverage Assessment

**New:** Every review now includes a `needs_tests` assessment.

The reviewer evaluates whether changes warrant test coverage based on:

| Factor | Indicators |
|--------|------------|
| **Complexity** | Cyclomatic complexity, lines changed, branching logic |
| **Risk Areas** | Auth, payments, data mutations, API changes |
| **Missing Coverage** | New functions/classes without corresponding tests |
| **Regression Risk** | Bug fixes that could recur, edge cases discovered |

#### Test Assessment Output

```json
{
  "needs_tests": true,
  "test_assessment": {
    "recommendation": "required",
    "rationale": "New API endpoint with input validation and error handling",
    "suggested_tests": [
      {
        "type": "unit",
        "target": "validateUserInput()",
        "cases": ["valid input", "empty input", "malformed input"]
      },
      {
        "type": "integration",
        "target": "POST /api/users",
        "cases": ["success path", "validation errors", "auth failure"]
      }
    ],
    "priority": "high",
    "auto_writable": false
  }
}
```

#### Test Recommendation Levels

| Level | When | Action |
|-------|------|--------|
| `required` | New logic, complex branching, risk area | Block until tests added |
| `recommended` | Moderate changes, some complexity | Flag for consideration |
| `optional` | Simple changes, low risk | Note but don't block |
| `skip` | Docs, config, formatting, existing test coverage | No tests needed |

### 3. Auto-Fix Protocol

For issues with >=95% confidence:

1. Make minimal changes - only fix the issue
2. Preserve existing formatting
3. Run linter after fix
4. Verify build still works

**Safe to auto-fix:** Unused imports, console.log statements, formatting, typos

**Never auto-fix:** Logic changes, security issues, test coverage gaps

---

## Review Modes

### Quick Mode (`--quick`)

Codex only - cheapest, fastest:

```bash
echo "=== Quick Review (Codex) ==="

# Run Codex review via MCP
mcp-cli call codex/review '{
  "uncommitted": true,
  "prompt": "Check for bugs, security issues, and obvious problems. Be concise."
}'
```

Returns pass/fail with issues. No auto-fix.

### Standard Mode (default)

Parallel: Codex + silent-failure-hunter (Sonnet)

```bash
echo "=== Standard Review (Parallel) ==="

# Run both reviewers in parallel using Task tool
# Reviewer 1: Codex for general issues
Task(
  subagent_type="general-purpose",
  prompt="Run: mcp-cli call codex/review '{\"uncommitted\": true}' and report findings"
)

# Reviewer 2: Silent failure hunter for error handling
Task(
  subagent_type="conductor:silent-failure-hunter",
  prompt="Audit error handling in uncommitted changes. Report issues with confidence >=80."
)

# Merge results - any blocker from either reviewer blocks
```

Broader coverage at low cost. No auto-fix.

### Thorough Mode (`--thorough`)

All three reviewers + Opus auto-fix:

```bash
echo "=== Thorough Review (Parallel + Auto-fix) ==="

# Run all three in parallel
# 1. Codex - general issues
Task(subagent_type="general-purpose", prompt="Run codex/review and report")

# 2. Silent failure hunter - error handling
Task(subagent_type="conductor:silent-failure-hunter", prompt="Audit error handling")

# 3. Opus code-reviewer - deep review + auto-fix
Task(
  subagent_type="conductor:code-reviewer",
  prompt="Thorough review with auto-fix for >=95% confidence issues"
)

# Merge results - Opus auto-fixes, others flag
```

Maximum coverage with auto-fix for high-confidence issues.

---

## Output Format

```json
{
  "passed": true,
  "mode": "standard",
  "summary": "Reviewed 5 files. Auto-fixed 2 issues. No blockers.",
  "claude_md_checked": ["CLAUDE.md"],
  "auto_fixed": [
    {"file": "src/utils.ts", "line": 45, "issue": "Unused import", "confidence": 98}
  ],
  "flagged": [
    {"severity": "important", "file": "src/api.ts", "line": 23, "issue": "Missing error handling", "confidence": 85}
  ],
  "blockers": [],
  "needs_tests": true,
  "test_assessment": {
    "recommendation": "recommended",
    "rationale": "New utility function with multiple code paths",
    "suggested_tests": [
      {"type": "unit", "target": "formatDate()", "cases": ["valid date", "invalid date", "null input"]}
    ],
    "priority": "medium",
    "auto_writable": true
  }
}
```

---

## Integration Points

### Worker Done Pipeline

The `/conductor:bdw-worker-done` pipeline uses test assessment:

1. **Code review** runs with test assessment
2. If `needs_tests: true` and `recommendation: required`:
   - Block until tests are added
   - Suggest specific test cases
3. If `auto_writable: true`:
   - Optionally generate tests automatically
4. Otherwise flag for manual review

### Test Generation

When `auto_writable: true`, can spawn test-writer:

```markdown
Task(
  subagent_type="general-purpose",
  prompt="Write tests for changes. Assessment: ${test_assessment}"
)
```

---

## Test Assessment Criteria

### Requires Tests (`recommendation: required`)

- New API endpoints
- Authentication/authorization changes
- Payment/billing logic
- Data mutation functions
- Functions with >3 branches
- Bug fixes without regression tests

### Recommended Tests

- New utility functions
- Significant refactors
- Error handling changes
- State management changes

### Optional/Skip

- Documentation changes
- Config file changes
- Formatting/style changes
- Changes to existing test files
- Pure type definitions

---

## Related

| Resource | Purpose |
|----------|---------|
| `plugins/conductor/agents/code-reviewer.md` | Opus agent - deep review + auto-fix |
| `plugins/conductor/agents/silent-failure-hunter.md` | Sonnet agent - error handling specialist |
| `/conductor:bdw-codex-review` | Standalone Codex review (cheapest) |
| `/conductor:bdw-worker-done` | Full completion pipeline |
| `/conductor:bdw-run-tests` | Test execution |

## Design Notes

**Why parallel reviewers?**
- Inspired by Anthropic's feature-dev plugin
- Cheap agents (Codex/Sonnet) for broad coverage
- Expensive agent (Opus) only for auto-fixes
- Specialized focus areas catch more issues than single reviewer

**Cost comparison:**
```
Quick:     1x Codex call           ~$0.01
Standard:  1x Codex + 1x Sonnet    ~$0.05
Thorough:  1x Codex + 2x Sonnet + 1x Opus  ~$0.30
```
