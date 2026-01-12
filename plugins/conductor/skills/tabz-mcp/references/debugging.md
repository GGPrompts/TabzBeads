# TabzChrome Debugging Guide

## Quick Diagnostics

```bash
# Check backend status
ps aux | grep "node server.js" | grep -v grep

# Check health
curl http://localhost:8129/api/health

# List active terminals
tmux ls | grep "^ctt-"

# List via API
curl -s http://localhost:8129/api/agents | jq '.data[] | {id, name, state}'
```

---

## Common Issues

### Backend won't start

```bash
lsof -i :8129                      # Check if port in use
pkill -f "node.*server.js"         # Kill orphaned processes
cd ~/projects/TabzChrome/backend && npm start
```

### Terminal won't connect

```bash
curl http://localhost:8129/api/health   # Check backend
tmux ls | grep "^ctt-"                  # List extension terminals
```

### Sidebar doesn't open

- Reload extension at `chrome://extensions`
- Check service worker console for errors

### Sessions not persisting

```bash
tmux ls                           # Verify tmux running
tmux kill-server                  # Reset if corrupted (loses all sessions!)
```

### Terminal display corrupted

- Click refresh button in header
- Forces tmux to redraw all terminals

### Text has gaps/spacing

- Font not installed or misconfigured
- Change font to "Monospace (Default)" in settings

---

## Capture Terminal Output

```bash
# Capture last 50 lines from terminal
tmux capture-pane -t ctt-Worker-abc123 -p -S -50

# Capture via API
curl http://localhost:8129/api/tmux/sessions/ctt-Worker-abc123/capture
```

---

## MCP Tool Debugging

### Check tool schema first

```bash
mcp-cli info tabz/tabz_screenshot
```

### Common MCP issues

| Issue | Solution |
|-------|----------|
| "Tool not found" | Check MCP server running, verify `.mcp.json` |
| Wrong tab targeted | Always use explicit `tabId` from `tabz_list_tabs` |
| Screenshot fails | Can't capture Chrome sidebar (limitation) |
| Network capture empty | Must enable before requests occur |

---

## Key Constraints

| Constraint | Details |
|------------|---------|
| Screenshot limitation | `tabz_screenshot` cannot capture Chrome sidebar |
| Tab IDs | Real Chrome IDs (large integers), not sequential |
| Debugger banner | DOM tree, coverage tools show Chrome's debug banner |
| Terminal ID prefix | All IDs start with `ctt-` (Chrome Terminal Tab) |

---

## Worker Debugging

### Check worker status

```bash
# List Claude terminals
curl -s http://localhost:8129/api/agents | jq '.data[] | select(.name | contains("Claude"))'

# Capture worker output
tmux capture-pane -t ctt-Claude-Worker-xxx -p -S -30
```

### Stuck worker

```bash
# Send nudge
tmux send-keys -t ctt-Claude-Worker-xxx 'Are you stuck? Please continue.' C-m

# Kill if unresponsive
curl -X DELETE http://localhost:8129/api/agents/ctt-Claude-Worker-xxx
```

---

## Backend Logs

```bash
# If running in tmux
tmux capture-pane -t tabzchrome:logs -p -S -100

# Or check directly
journalctl -u tabzchrome --since "1 hour ago"
```

---

## Reset Everything

```bash
# Kill all extension terminals
tmux ls | grep "^ctt-" | cut -d: -f1 | xargs -I {} tmux kill-session -t {}

# Restart backend
pkill -f "node.*server.js"
cd ~/projects/TabzChrome && ./scripts/dev.sh

# Reload extension
# Go to chrome://extensions → TabzChrome → Reload
```
