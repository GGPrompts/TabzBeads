---
description: "Visual QA check between waves - runs as tabz-expert subagent to screenshot changes and check for browser errors."
agent: tabz-expert
---

# Visual QA Check

Run visual QA after a wave with UI changes completes. Runs as a **tabz-expert subagent** for browser automation.

## Execution Context

| Running As | How It Executes |
|------------|-----------------|
| `--agent conductor` | Fork context - inherits parent context, adds tabz-expert tools |
| Regular Claude | Task tool spawns tabz-expert subagent |

**Without `--agent` flag:** The conductor should invoke via Task tool:
```
Task(
  subagent_type="tabz:tabz-expert",
  description="Visual QA check",
  prompt="Run visual QA on [urls]. Create isolated tab group, check console errors, cleanup when done."
)
```

## Usage

```
/conductor:bdc-visual-qa [--mode=quick|full] [urls...]
```

### Modes

| Mode | Checks | Use Case |
|------|--------|----------|
| `quick` (default) | Console errors, DOM error patterns | Fast automated check |
| `full` | Quick + screenshots + interactive review | Thorough visual inspection |

## Workflow

When invoked, tabz-expert will:

### 1. Create Isolated Tab Group

```bash
SESSION_ID="QA-$(shuf -i 100-999 -n 1)"
mcp-cli call tabz/tabz_create_group "{\"title\": \"$SESSION_ID\", \"color\": \"green\"}"
# Save groupId for all subsequent operations
```

### 2. Quick Checks (Both Modes)

```bash
# Open dev server page into YOUR group
mcp-cli call tabz/tabz_open_url '{"url": "http://localhost:3000", "newTab": true, "groupId": <groupId>}'

# Check console for errors (explicit tabId)
mcp-cli call tabz/tabz_get_console_logs '{"tabId": <tabId>, "level": "error"}'

# Check DOM for error patterns
mcp-cli call tabz/tabz_execute_script '{
  "tabId": <tabId>,
  "script": "document.body.innerText.match(/error boundary|something went wrong|uncaught|failed to/gi)"
}'
```

### 3. Full Mode Additional Checks

```bash
# Screenshot at standard viewport
mcp-cli call tabz/tabz_screenshot '{"tabId": <tabId>, "width": 1920, "height": 1080}'

# For each additional URL provided:
mcp-cli call tabz/tabz_open_url '{"url": "URL", "newTab": true, "groupId": <groupId>}'
mcp-cli call tabz/tabz_screenshot '{"tabId": <new_tabId>}'
```

### 4. Cleanup and Report

```bash
# Close the QA tab group when done
mcp-cli call tabz/tabz_update_group '{"groupId": <groupId>, "collapsed": true}'
```

Return a summary:
- **Errors found**: List with severity (blocking vs warning)
- **Screenshots**: File paths (full mode only)
- **Recommendation**: PASS / INVESTIGATE / BLOCK

## Example Invocations

### Quick check (default)
```
/conductor:bdc-visual-qa http://localhost:3000
```

### Full check with multiple pages
```
/conductor:bdc-visual-qa --mode=full http://localhost:3000/dashboard http://localhost:3000/settings
```

## What It Catches

- JavaScript console errors
- React error boundaries / crash states
- Missing images or broken layouts
- 404s and network failures
- Obvious visual regressions (full mode)

## What It Doesn't Do

- Pixel-perfect comparison (use dedicated tools)
- Accessibility audits (see tabz emulation tools)
- Performance profiling (tabz-expert has tools, but not in this skill)

## Integration with bdc-wave-done

The `bdc-wave-done` skill invokes this automatically in Step 7:

```
# Auto-detects UI changes, then:
/conductor:bdc-visual-qa --mode=$VISUAL_QA_MODE [dev-server-urls]
```

Control via `--visual-qa` flag:
- `--visual-qa=quick` (default): Run quick checks
- `--visual-qa=full`: Run full visual inspection
- `--visual-qa=skip`: Skip entirely (backend-only waves)
