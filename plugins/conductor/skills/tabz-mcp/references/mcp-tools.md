# TabzChrome MCP Tools Reference

Complete reference for all 71 MCP tools.

## Tab Management (5 tools)

### tabz_list_tabs
List all open tabs with tabIds, URLs, titles, active state.

```bash
mcp-cli call tabz/tabz_list_tabs '{}'
mcp-cli call tabz/tabz_list_tabs '{"response_format": "json"}'
```

### tabz_switch_tab
Switch to a specific tab by tabId.

```bash
mcp-cli call tabz/tabz_switch_tab '{"tabId": 1762561083}'
```

### tabz_rename_tab
Set custom display name for a tab.

```bash
mcp-cli call tabz/tabz_rename_tab '{"tabId": 123, "name": "My Tab"}'
```

### tabz_get_page_info
Get current page URL and title.

```bash
mcp-cli call tabz/tabz_get_page_info '{}'
mcp-cli call tabz/tabz_get_page_info '{"tabId": 123}'
```

### tabz_open_url
Open a URL in browser (new tab or current).

```bash
mcp-cli call tabz/tabz_open_url '{"url": "https://example.com"}'
mcp-cli call tabz/tabz_open_url '{"url": "https://example.com", "newTab": true}'
mcp-cli call tabz/tabz_open_url '{"url": "https://example.com", "groupId": 123}'
```

---

## Tab Groups (7 tools)

### tabz_list_groups
List all tab groups with their tabs.

```bash
mcp-cli call tabz/tabz_list_groups '{}'
```

### tabz_create_group
Create group with title and color.

```bash
mcp-cli call tabz/tabz_create_group '{"title": "Research", "color": "blue"}'
```

Colors: `grey`, `blue`, `red`, `yellow`, `green`, `pink`, `purple`, `cyan`, `orange`

### tabz_update_group
Update group title, color, collapsed state.

```bash
mcp-cli call tabz/tabz_update_group '{"groupId": 123, "title": "New Name", "collapsed": true}'
```

### tabz_add_to_group
Add tabs to existing group.

```bash
mcp-cli call tabz/tabz_add_to_group '{"groupId": 123, "tabIds": [456, 789]}'
```

### tabz_ungroup_tabs
Remove tabs from their groups.

```bash
mcp-cli call tabz/tabz_ungroup_tabs '{"tabIds": [456, 789]}'
```

### tabz_claude_group_add
Add tab to purple "Claude Active" group.

```bash
mcp-cli call tabz/tabz_claude_group_add '{"tabId": 123}'
```

### tabz_claude_group_remove
Remove tab from Claude group.

```bash
mcp-cli call tabz/tabz_claude_group_remove '{"tabId": 123}'
```

---

## Windows & Displays (7 tools)

### tabz_list_windows
List all browser windows.

```bash
mcp-cli call tabz/tabz_list_windows '{}'
```

### tabz_create_window
Create new browser window.

```bash
mcp-cli call tabz/tabz_create_window '{}'
mcp-cli call tabz/tabz_create_window '{"url": "https://example.com"}'
mcp-cli call tabz/tabz_create_window '{"width": 1200, "height": 800}'
```

### tabz_update_window
Update window state (size, position, focused).

```bash
mcp-cli call tabz/tabz_update_window '{"windowId": 123, "state": "maximized"}'
mcp-cli call tabz/tabz_update_window '{"windowId": 123, "left": 100, "top": 100}'
```

### tabz_close_window
Close a browser window.

```bash
mcp-cli call tabz/tabz_close_window '{"windowId": 123}'
```

### tabz_get_displays
Get info about connected displays.

```bash
mcp-cli call tabz/tabz_get_displays '{}'
```

### tabz_tile_windows
Tile windows across displays.

```bash
mcp-cli call tabz/tabz_tile_windows '{}'
```

### tabz_popout_terminal
Pop out terminal to separate window.

```bash
mcp-cli call tabz/tabz_popout_terminal '{"sessionName": "ctt-xxx"}'
```

---

## Screenshots (2 tools)

### tabz_screenshot
Capture visible viewport.

```bash
mcp-cli call tabz/tabz_screenshot '{}'
mcp-cli call tabz/tabz_screenshot '{"tabId": 123}'
```

### tabz_screenshot_full
Capture entire scrollable page.

```bash
mcp-cli call tabz/tabz_screenshot_full '{}'
mcp-cli call tabz/tabz_screenshot_full '{"tabId": 123}'
```

---

## Interaction (4 tools)

### tabz_click
Click element by CSS selector.

```bash
mcp-cli call tabz/tabz_click '{"selector": "button.submit"}'
mcp-cli call tabz/tabz_click '{"selector": "#login-btn", "tabId": 123}'
```

### tabz_fill
Fill input field by CSS selector.

```bash
mcp-cli call tabz/tabz_fill '{"selector": "#email", "value": "user@example.com"}'
```

### tabz_get_element
Get element details (text, attributes, bounding box).

```bash
mcp-cli call tabz/tabz_get_element '{"selector": ".header"}'
```

### tabz_execute_script
Run JavaScript in page context.

```bash
mcp-cli call tabz/tabz_execute_script '{"script": "document.title"}'
mcp-cli call tabz/tabz_execute_script '{"script": "window.scrollTo(0, 500)"}'
```

---

## DOM & Debugging (4 tools)

### tabz_get_dom_tree
Full DOM tree via chrome.debugger.

```bash
mcp-cli call tabz/tabz_get_dom_tree '{}'
mcp-cli call tabz/tabz_get_dom_tree '{"depth": 3}'
```

### tabz_get_console_logs
View browser console output.

```bash
mcp-cli call tabz/tabz_get_console_logs '{}'
```

### tabz_profile_performance
Timing, memory, DOM metrics.

```bash
mcp-cli call tabz/tabz_profile_performance '{}'
```

### tabz_get_coverage
JS/CSS code coverage analysis.

```bash
mcp-cli call tabz/tabz_get_coverage '{}'
```

> **Note:** Debugger tools trigger Chrome's "debugging" banner while running.

---

## Network (3 tools)

### tabz_enable_network_capture
Start capturing network requests.

```bash
mcp-cli call tabz/tabz_enable_network_capture '{}'
```

### tabz_get_network_requests
Get captured requests (with optional filter).

```bash
mcp-cli call tabz/tabz_get_network_requests '{}'
mcp-cli call tabz/tabz_get_network_requests '{"filter": "/api/"}'
```

### tabz_clear_network_requests
Clear captured requests.

```bash
mcp-cli call tabz/tabz_clear_network_requests '{}'
```

---

## Downloads (5 tools)

### tabz_download_image
Download image from page by selector or URL.

```bash
mcp-cli call tabz/tabz_download_image '{"selector": "img.hero"}'
mcp-cli call tabz/tabz_download_image '{"url": "https://example.com/image.png"}'
```

### tabz_download_file
Download file from URL.

```bash
mcp-cli call tabz/tabz_download_file '{"url": "https://example.com/file.pdf"}'
```

### tabz_get_downloads
List recent downloads.

```bash
mcp-cli call tabz/tabz_get_downloads '{}'
```

### tabz_cancel_download
Cancel in-progress download.

```bash
mcp-cli call tabz/tabz_cancel_download '{"downloadId": 123}'
```

### tabz_save_page
Save page as HTML or MHTML.

```bash
mcp-cli call tabz/tabz_save_page '{}'
mcp-cli call tabz/tabz_save_page '{"format": "mhtml"}'
```

---

## Bookmarks (6 tools)

### tabz_get_bookmark_tree
Get full bookmark tree structure.

```bash
mcp-cli call tabz/tabz_get_bookmark_tree '{}'
```

### tabz_search_bookmarks
Search bookmarks by keyword.

```bash
mcp-cli call tabz/tabz_search_bookmarks '{"query": "github"}'
```

### tabz_save_bookmark
Create a new bookmark.

```bash
mcp-cli call tabz/tabz_save_bookmark '{"url": "https://example.com", "title": "Example"}'
```

### tabz_create_folder
Create bookmark folder.

```bash
mcp-cli call tabz/tabz_create_folder '{"title": "Work", "parentId": "1"}'
```

### tabz_move_bookmark
Move bookmark to different folder.

```bash
mcp-cli call tabz/tabz_move_bookmark '{"id": "123", "parentId": "456"}'
```

### tabz_delete_bookmark
Delete a bookmark.

```bash
mcp-cli call tabz/tabz_delete_bookmark '{"id": "123"}'
```

---

## Audio & TTS (3 tools)

### tabz_speak
Text-to-speech with voice selection.

```bash
mcp-cli call tabz/tabz_speak '{"text": "Hello world"}'
mcp-cli call tabz/tabz_speak '{"text": "Alert!", "priority": "high"}'
mcp-cli call tabz/tabz_speak '{"text": "Hello", "voice": "en-GB-SoniaNeural"}'
```

### tabz_list_voices
List available TTS voices.

```bash
mcp-cli call tabz/tabz_list_voices '{}'
```

### tabz_play_audio
Play audio file or URL.

```bash
mcp-cli call tabz/tabz_play_audio '{"url": "http://localhost:8129/sounds/ding.mp3"}'
```

---

## History (5 tools)

### tabz_history_search
Search browsing history.

```bash
mcp-cli call tabz/tabz_history_search '{"text": "github"}'
```

### tabz_history_visits
Get visit details for a URL.

```bash
mcp-cli call tabz/tabz_history_visits '{"url": "https://github.com"}'
```

### tabz_history_recent
Get recent browsing history.

```bash
mcp-cli call tabz/tabz_history_recent '{}'
mcp-cli call tabz/tabz_history_recent '{"maxResults": 50}'
```

### tabz_history_delete_url
Delete a URL from history.

```bash
mcp-cli call tabz/tabz_history_delete_url '{"url": "https://example.com"}'
```

### tabz_history_delete_range
Delete history within time range.

```bash
mcp-cli call tabz/tabz_history_delete_range '{"startTime": 0, "endTime": 1704067200000}'
```

---

## Sessions (3 tools)

### tabz_sessions_recently_closed
Get recently closed tabs/windows.

```bash
mcp-cli call tabz/tabz_sessions_recently_closed '{}'
```

### tabz_sessions_restore
Restore a closed session.

```bash
mcp-cli call tabz/tabz_sessions_restore '{"sessionId": "xxx"}'
```

### tabz_sessions_devices
Get synced devices and their tabs.

```bash
mcp-cli call tabz/tabz_sessions_devices '{}'
```

---

## Cookies (5 tools)

### tabz_cookies_get
Get a specific cookie.

```bash
mcp-cli call tabz/tabz_cookies_get '{"url": "https://example.com", "name": "session"}'
```

### tabz_cookies_list
List all cookies for a URL.

```bash
mcp-cli call tabz/tabz_cookies_list '{"url": "https://example.com"}'
```

### tabz_cookies_set
Set a cookie.

```bash
mcp-cli call tabz/tabz_cookies_set '{"url": "https://example.com", "name": "test", "value": "123"}'
```

### tabz_cookies_delete
Delete a cookie.

```bash
mcp-cli call tabz/tabz_cookies_delete '{"url": "https://example.com", "name": "session"}'
```

### tabz_cookies_audit
Audit cookies for trackers.

```bash
mcp-cli call tabz/tabz_cookies_audit '{}'
```

---

## Emulation (6 tools)

### tabz_emulate_device
Emulate mobile/tablet device.

```bash
mcp-cli call tabz/tabz_emulate_device '{"device": "iPhone 14"}'
mcp-cli call tabz/tabz_emulate_device '{"width": 375, "height": 812, "deviceScaleFactor": 3}'
```

### tabz_emulate_clear
Clear all emulation settings.

```bash
mcp-cli call tabz/tabz_emulate_clear '{}'
```

### tabz_emulate_geolocation
Emulate GPS location.

```bash
mcp-cli call tabz/tabz_emulate_geolocation '{"latitude": 40.7128, "longitude": -74.0060}'
```

### tabz_emulate_network
Emulate network conditions.

```bash
mcp-cli call tabz/tabz_emulate_network '{"offline": true}'
mcp-cli call tabz/tabz_emulate_network '{"latency": 200, "downloadThroughput": 500000}'
```

### tabz_emulate_media
Emulate media features.

```bash
mcp-cli call tabz/tabz_emulate_media '{"colorScheme": "dark"}'
mcp-cli call tabz/tabz_emulate_media '{"reducedMotion": "reduce"}'
```

### tabz_emulate_vision
Emulate vision deficiencies.

```bash
mcp-cli call tabz/tabz_emulate_vision '{"type": "deuteranopia"}'
```

Types: `none`, `blurredVision`, `protanopia`, `deuteranopia`, `tritanopia`, `achromatopsia`

---

## Notifications (4 tools)

### tabz_notification_show
Show desktop notification.

```bash
mcp-cli call tabz/tabz_notification_show '{"title": "Build Complete", "message": "All tests passed"}'
```

### tabz_notification_update
Update notification (e.g., progress).

```bash
mcp-cli call tabz/tabz_notification_update '{"notificationId": "xxx", "progress": 75}'
```

### tabz_notification_clear
Clear a notification.

```bash
mcp-cli call tabz/tabz_notification_clear '{"notificationId": "xxx"}'
```

### tabz_notification_list
List active notifications.

```bash
mcp-cli call tabz/tabz_notification_list '{}'
```
