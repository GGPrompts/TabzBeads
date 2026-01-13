---
name: bdc-visual-qa
description: "Visual QA check between waves - spawns tabz-manager to screenshot changes and check for browser errors. Use after completing a wave with UI changes."
user-invocable: false
agent: conductor:tabz-manager
context: fork
---

# Visual QA Check

Run visual QA after a wave with UI changes completes, before spawning the next wave.

## What This Does

1. **Spawns tabz-manager** in a forked context with browser isolation
2. **Screenshots changed pages** to catch glaring visual issues
3. **Checks browser console** for JavaScript errors
4. **Reports findings** back to the conductor

## Usage

The conductor invokes this skill between waves:

```
/conductor:bdc-visual-qa [urls-or-components]
```

## Workflow

When invoked, tabz-manager will:

### 1. Create Isolated Tab Group

```bash
SESSION_ID="QA-$(shuf -i 100-999 -n 1)"
mcp-cli call tabz/tabz_create_group "{\"title\": \"$SESSION_ID\", \"color\": \"green\"}"
```

### 2. For Each URL/Component

```bash
# Open the page
mcp-cli call tabz/tabz_open_url '{"url": "URL", "newTab": true, "groupId": <groupId>}'

# Wait for load, then screenshot
mcp-cli call tabz/tabz_screenshot '{"tabId": <tabId>}'

# Check console for errors
mcp-cli call tabz/tabz_get_console_logs '{}'
```

### 3. Report Findings

Return a summary:
- Screenshots taken (file paths)
- Console errors found (if any)
- Obvious visual issues spotted
- Recommendation: proceed or investigate

## Example Invocation

After a wave that modified the dashboard:

```
/conductor:bdc-visual-qa http://localhost:3000/dashboard http://localhost:3000/settings
```

tabz-manager will:
1. Create "QA-847" tab group
2. Screenshot both pages
3. Check console for errors
4. Report back with paths and any issues

## When to Use

- After waves that touch UI components
- Before spawning the next wave
- When you want quick visual sanity checks
- To catch obvious regressions before they compound

## What It Catches

- JavaScript console errors
- Missing images or broken layouts
- 404s and network failures
- Obvious visual regressions

## What It Doesn't Do

- Pixel-perfect comparison (use dedicated tools for that)
- Accessibility audits (see emulation tools for that)
- Performance profiling (tabz-manager has tools, but not in this skill)

## Integration with Wave Workflow

In bdc-wave-done or bdc-swarm-auto:

```markdown
## After Merge, Before Next Wave

If the wave included UI changes:

1. Run visual QA: `/conductor:bdc-visual-qa <changed-urls>`
2. Review screenshots and console output
3. If errors found, create follow-up issues before next wave
4. If clean, proceed to next wave
```
