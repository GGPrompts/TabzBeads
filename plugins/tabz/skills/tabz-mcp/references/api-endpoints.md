# TabzChrome REST API Reference

REST API at `localhost:8129` for terminal management and browser automation.

## Authentication

Most endpoints require auth token from `/tmp/tabz-auth-token`.

```bash
TOKEN=$(cat /tmp/tabz-auth-token)
curl -H "X-Auth-Token: $TOKEN" http://localhost:8129/api/endpoint
```

---

## Terminal Endpoints

### POST /api/spawn

Create a terminal programmatically.

```bash
TOKEN=$(cat /tmp/tabz-auth-token)
curl -X POST http://localhost:8129/api/spawn \
  -H "Content-Type: application/json" \
  -H "X-Auth-Token: $TOKEN" \
  -d '{"name": "Worker", "workingDir": "~/projects", "command": "claude"}'
```

**Parameters:**

| Param | Default | Description |
|-------|---------|-------------|
| name | "Claude Terminal" | Display name |
| workingDir | $HOME | Starting directory |
| command | - | Command to auto-execute |

**Response:**
```json
{
  "terminal": {
    "id": "ctt-Worker-abc123",
    "ptyInfo": {
      "tmuxSession": "ctt-Worker-abc123"
    }
  }
}
```

### GET /api/agents

List all active terminals.

```bash
curl http://localhost:8129/api/agents
```

Returns array of terminals with id, name, state, sessionName.

### DELETE /api/agents/:id

Kill a terminal by ID.

```bash
curl -X DELETE http://localhost:8129/api/agents/ctt-Worker-abc123
```

---

## Health & Status

### GET /api/health

Health check (no auth required).

```bash
curl http://localhost:8129/api/health
```

Returns: uptime, memory, version, Node.js version, platform.

### GET /api/claude-status

Get Claude Code status for a terminal.

```bash
curl "http://localhost:8129/api/claude-status?dir=/home/user/project&sessionName=ctt-xxx"
```

Returns: status, tool, file, subagentCount, contextPercentage.

---

## Terminal Capture

### GET /api/tmux/sessions/:name/capture

Capture full terminal scrollback as text.

```bash
curl http://localhost:8129/api/tmux/sessions/ctt-Claude-abc123/capture
```

Returns:
```json
{
  "content": "terminal output...",
  "metadata": {
    "workingDir": "/home/user/project",
    "gitBranch": "main",
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

---

## Audio Endpoints

### POST /api/audio/speak

Generate TTS and broadcast for playback.

```bash
curl -X POST http://localhost:8129/api/audio/speak \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello", "voice": "en-US-AndrewNeural"}'
```

### POST /api/audio/generate

Generate TTS audio and return URL.

```bash
curl -X POST http://localhost:8129/api/audio/generate \
  -H "Content-Type: application/json" \
  -d '{"text": "Test"}'
```

---

## Settings

### GET/POST /api/settings/working-dir

Sync working directory settings.

```bash
# GET
curl http://localhost:8129/api/settings/working-dir

# POST
curl -X POST http://localhost:8129/api/settings/working-dir \
  -H "Content-Type: application/json" \
  -d '{"globalWorkingDir": "~/projects", "recentDirs": ["~", "~/projects"]}'
```

---

## Browser Profiles

### GET /api/browser/profiles

List all profiles.

```bash
curl http://localhost:8129/api/browser/profiles
```

### POST /api/browser/profiles

Create a new profile.

```bash
TOKEN=$(cat /tmp/tabz-auth-token)
curl -X POST http://localhost:8129/api/browser/profiles \
  -H "Content-Type: application/json" \
  -H "X-Auth-Token: $TOKEN" \
  -d '{"profile": {"name": "Dev", "command": "claude"}}'
```

### PUT /api/browser/profiles/:id

Update a profile.

```bash
TOKEN=$(cat /tmp/tabz-auth-token)
curl -X PUT http://localhost:8129/api/browser/profiles/dev \
  -H "Content-Type: application/json" \
  -H "X-Auth-Token: $TOKEN" \
  -d '{"name": "Development", "category": "Work"}'
```

### DELETE /api/browser/profiles/:id

Delete a profile.

```bash
TOKEN=$(cat /tmp/tabz-auth-token)
curl -X DELETE http://localhost:8129/api/browser/profiles/dev \
  -H "X-Auth-Token: $TOKEN"
```

### POST /api/browser/profiles/import

Bulk import profiles.

```bash
TOKEN=$(cat /tmp/tabz-auth-token)
curl -X POST http://localhost:8129/api/browser/profiles/import \
  -H "Content-Type: application/json" \
  -H "X-Auth-Token: $TOKEN" \
  -d '{"profiles": [{"name": "P1"}, {"name": "P2"}], "mode": "merge"}'
```

Modes: `merge` (add new) | `replace` (overwrite all)

---

## WebSocket Messages

Real-time terminal I/O via `ws://localhost:8129`:

| Message | Purpose |
|---------|---------|
| `TERMINAL_SPAWN` | Create terminal |
| `TERMINAL_INPUT` | Send keystrokes |
| `TERMINAL_OUTPUT` | Receive output |
| `TERMINAL_RESIZE` | Update dimensions |
| `TERMINAL_KILL` | Close terminal |
| `RECONNECT` | Reattach to session |

---

## Notifications

### POST /api/notify

Send notification to connected clients.

```bash
TOKEN=$(cat /tmp/tabz-auth-token)
curl -X POST http://localhost:8129/api/notify \
  -H "Content-Type: application/json" \
  -H "X-Auth-Token: $TOKEN" \
  -d '{"type": "worker-complete", "issueId": "xxx", "summary": "Done"}'
```

Used by conductor workers to notify completion.
