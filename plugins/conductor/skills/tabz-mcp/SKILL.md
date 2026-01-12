---
name: tabz-mcp
description: "Control Chrome browser via 71 MCP tools - screenshots, clicks, forms, downloads, network capture, TTS, history, cookies, emulation. Use when working with browser automation."
---

# TabzChrome MCP Tools

TabzChrome provides 71 MCP tools for browser automation via Chrome Extension APIs.

## Quick Start

```bash
# Always check schema first (MANDATORY)
mcp-cli info tabz/tabz_screenshot

# Then call the tool
mcp-cli call tabz/tabz_screenshot '{}'
```

## Tool Categories (71 Tools)

| Category | Tools | Purpose |
|----------|-------|---------|
| **Tab Management** | `tabz_list_tabs`, `tabz_switch_tab`, `tabz_rename_tab` | Navigate tabs, accurate active detection |
| **Tab Groups** | `tabz_list_groups`, `tabz_create_group`, `tabz_update_group`, `tabz_add_to_group`, `tabz_ungroup_tabs` | Organize tabs into groups |
| **Claude Group** | `tabz_claude_group_add`, `tabz_claude_group_remove`, `tabz_claude_group_status` | Highlight tabs Claude is working with |
| **Windows** | `tabz_list_windows`, `tabz_create_window`, `tabz_update_window`, `tabz_close_window` | Manage browser windows |
| **Displays** | `tabz_get_displays`, `tabz_tile_windows`, `tabz_popout_terminal` | Multi-monitor layouts, tiling |
| **Screenshots** | `tabz_screenshot`, `tabz_screenshot_full` | Capture viewport or full page |
| **Interaction** | `tabz_click`, `tabz_fill`, `tabz_get_element`, `tabz_execute_script` | Click, fill forms, run JS |
| **Downloads** | `tabz_download_image`, `tabz_download_file`, `tabz_get_downloads`, `tabz_cancel_download`, `tabz_save_page` | Download files, save pages |
| **Bookmarks** | `tabz_get_bookmark_tree`, `tabz_search_bookmarks`, `tabz_save_bookmark`, `tabz_create_folder`, `tabz_move_bookmark`, `tabz_delete_bookmark` | Organize bookmarks |
| **Network** | `tabz_enable_network_capture`, `tabz_get_network_requests`, `tabz_clear_network_requests` | Monitor API calls |
| **Inspection** | `tabz_get_page_info`, `tabz_get_console_logs` | Debug, inspect pages |
| **Debugger** | `tabz_get_dom_tree`, `tabz_profile_performance`, `tabz_get_coverage` | DOM tree, metrics, coverage |
| **Audio/TTS** | `tabz_speak`, `tabz_list_voices`, `tabz_play_audio` | Text-to-speech, audio playback |
| **History** | `tabz_history_search`, `tabz_history_visits`, `tabz_history_recent`, `tabz_history_delete_url`, `tabz_history_delete_range` | Search and manage history |
| **Sessions** | `tabz_sessions_recently_closed`, `tabz_sessions_restore`, `tabz_sessions_devices` | Recover tabs, synced devices |
| **Cookies** | `tabz_cookies_get`, `tabz_cookies_list`, `tabz_cookies_set`, `tabz_cookies_delete`, `tabz_cookies_audit` | Debug auth, audit trackers |
| **Emulation** | `tabz_emulate_device`, `tabz_emulate_clear`, `tabz_emulate_geolocation`, `tabz_emulate_network`, `tabz_emulate_media`, `tabz_emulate_vision` | Responsive testing, accessibility |
| **Notifications** | `tabz_notification_show`, `tabz_notification_update`, `tabz_notification_clear`, `tabz_notification_list` | Desktop alerts with progress |

## Visual Feedback

Interaction tools show visual feedback when targeting elements:

| Tool | Glow Color |
|------|------------|
| `tabz_click` | Green (action completed) |
| `tabz_fill` | Blue (input focused) |
| `tabz_get_element` | Purple (inspecting) |

Elements pulse twice and auto-scroll into view.

## Getting CSS Selectors

Right-click any element on a webpage **"Send Element to Chat"** to capture:
- Unique CSS selector (with `:nth-of-type()` for siblings)
- Tag, ID, classes, text content
- Useful attributes (`data-testid`, `aria-label`, `role`)

## Common Workflows

### Screenshot a Page

```bash
mcp-cli info tabz/tabz_screenshot
mcp-cli call tabz/tabz_screenshot '{}'            # Viewport
mcp-cli call tabz/tabz_screenshot_full '{}'       # Full scrollable page
```

### Fill and Submit Form

```bash
mcp-cli call tabz/tabz_fill '{"selector": "#username", "value": "user@example.com"}'
mcp-cli call tabz/tabz_fill '{"selector": "#password", "value": "secret"}'
mcp-cli call tabz/tabz_click '{"selector": "button[type=submit]"}'
```

### Debug API Issues

```bash
mcp-cli call tabz/tabz_enable_network_capture '{}'
# Trigger the action
mcp-cli call tabz/tabz_get_network_requests '{}'
mcp-cli call tabz/tabz_get_network_requests '{"filter": "/api/users"}'
```

### Organize Tabs into Groups

```bash
mcp-cli call tabz/tabz_create_group '{"title": "Research", "color": "blue"}'
mcp-cli call tabz/tabz_add_to_group '{"groupId": 123, "tabIds": [456, 789]}'
```

### Text-to-Speech

```bash
mcp-cli call tabz/tabz_list_voices '{}'
mcp-cli call tabz/tabz_speak '{"text": "Build complete"}'
mcp-cli call tabz/tabz_speak '{"text": "Alert!", "priority": "high"}'
```

### Download Images

```bash
mcp-cli call tabz/tabz_download_image '{"selector": "img.hero-image"}'
mcp-cli call tabz/tabz_download_image '{"url": "https://example.com/image.png"}'
```

## Tab Targeting (Critical)

**Chrome tab IDs are large integers** (e.g., `1762561083`), NOT sequential like 1, 2, 3.

### Always List Tabs First

```bash
mcp-cli call tabz/tabz_list_tabs '{}'
```

Returns:
```json
{
  "claudeCurrentTabId": 1762561083,
  "tabs": [
    {"tabId": 1762561065, "url": "...", "active": false},
    {"tabId": 1762561083, "url": "...", "active": true}
  ]
}
```

### Use Explicit tabId

```bash
# DON'T rely on implicit current tab
mcp-cli call tabz/tabz_screenshot '{}'  # May target wrong tab!

# DO use explicit tabId
mcp-cli call tabz/tabz_screenshot '{"tabId": 1762561083}'
```

## Parallel Worker Isolation

When multiple Claude workers use tabz tools simultaneously, they MUST isolate tabs.

### Required Pattern: Own Tab Group

```bash
# 1. Create unique group for this worker
SESSION_ID=$(tmux display-message -p '#{session_name}' 2>/dev/null || echo "worker-$$")
mcp-cli call tabz/tabz_create_group "{\"title\": \"$SESSION_ID\", \"color\": \"blue\"}"

# 2. Open tabs IN that group
mcp-cli call tabz/tabz_open_url '{"url": "https://example.com", "groupId": <group_id>}'

# 3. Always use explicit tabIds from YOUR group
```

### Do's and Don'ts

| Do | Don't |
|----|-------|
| Create own tab group at start | Use shared "Claude" group |
| Store your tabIds after opening | Rely on `active: true` tab |
| Target tabs by explicit ID | Assume current tab is yours |
| Clean up group when done | Leave orphaned tabs/groups |

## MCP Server Configuration

Add to `.mcp.json`:

```json
{
  "mcpServers": {
    "tabz": {
      "command": "/path/to/TabzChrome/tabz-mcp-server/run-auto.sh",
      "args": [],
      "env": { "BACKEND_URL": "http://localhost:8129" }
    }
  }
}
```

## Limitations

- `tabz_screenshot` cannot capture Chrome sidebar (Chrome limitation)
- Always call `mcp-cli info tabz/<tool>` before `mcp-cli call`
- Tab IDs are real Chrome tab IDs (large integers)
- Debugger tools (DOM tree, coverage) show Chrome's debug banner

## Reference Documentation

For detailed information:
- `references/mcp-tools.md` - Complete tool reference
- `references/audio-tts.md` - TTS voices, settings, API
- `references/api-endpoints.md` - REST API reference
- `references/debugging.md` - Troubleshooting guide

## Related

| Resource | Purpose |
|----------|---------|
| `tabz:tabz-manager` agent | Spawn as specialist for complex browser work |
| `/conductor:tabz-artist` | Generate images (DALL-E) and videos (Sora) |
