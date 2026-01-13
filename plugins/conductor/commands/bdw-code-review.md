---
description: "Code review with confidence-based filtering. Modes: quick (lint+types), standard (Sonnet), thorough (parallel agents). Worker applies fixes from review findings."
---

# Code Review Skill

Automated code review with confidence-based filtering and test coverage assessment.

> **Pattern:** Sonnet reviewers identify issues → Worker (Opus) applies fixes. This is cheaper than having Opus do both review and fix.

## Invocation

```bash
/conductor:bdw-code-review                    # Standard review (Sonnet)
/conductor:bdw-code-review --quick            # Fast: lint + types + secrets only
/conductor:bdw-code-review --thorough         # Deep: parallel specialized reviewers
/conductor:bdw-code-review <issue-id>         # Review for specific issue
```

## Core Capabilities

### 1. Confidence-Based Review

Reviews code with precision scoring to minimize false positives:

| Score | Meaning | Action |
|-------|---------|--------|
| 0 | False positive / pre-existing | Skip |
| 25 | Might be real, can't verify | Skip |
| 50 | Real but minor nitpick | Skip |
| 75 | Likely real but uncertain | Skip |
| **80-100** | Verified issue | **Report to worker** |

**Reviewers are read-only.** They report issues with suggestions. The calling worker (Opus) applies fixes.

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

### 3. Worker Applies Fixes

When the review returns issues, the worker (Opus) should:

1. Read the `issues` array from the review output
2. Apply suggested fixes for high-confidence issues (≥95%)
3. Consider fixes for medium-confidence issues (80-94%)
4. Re-run build/lint to verify fixes

**Safe to fix:** Unused imports, console.log statements, formatting, typos

**Require human review:** Logic changes, security issues, architectural decisions

---

## Review Modes

### Quick Mode (`--quick`)

Fast checks for trivial changes:
- Lint check
- Type check
- Secret scan
- Test assessment: `skip` (trivial changes)

### Standard Mode (default)

Spawns `conductor:code-reviewer` agent (Sonnet):
- Reads CLAUDE.md files
- Reviews against project conventions
- Confidence-based filtering
- **Full test assessment**
- Reports issues for worker to fix

### Thorough Mode (`--thorough`)

Parallel specialized reviewers:
1. CLAUDE.md compliance scan
2. Bug detection
3. Silent failure hunt
4. Security scan
5. **Test coverage analysis**

---

## Output Format

```json
{
  "passed": true,
  "mode": "standard",
  "summary": "Reviewed 5 files. Found 2 issues. No blockers.",
  "claude_md_checked": ["CLAUDE.md"],
  "issues": [
    {"severity": "high", "file": "src/utils.ts", "line": 45, "issue": "Unused import", "confidence": 98, "suggestion": "Remove unused import"},
    {"severity": "important", "file": "src/api.ts", "line": 23, "issue": "Missing error handling", "confidence": 85, "suggestion": "Add try-catch"}
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
| `plugins/conductor/agents/code-reviewer.md` | Agent implementation |
| `plugins/conductor/commands/code-review.md` | Command definition |
| `/conductor:bdw-worker-done` | Full completion pipeline |
| `/conductor:bdw-run-tests` | Test execution |
