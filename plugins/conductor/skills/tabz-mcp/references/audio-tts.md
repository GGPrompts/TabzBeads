# Audio/TTS System

TabzChrome includes a neural text-to-speech system for audio notifications.

## MCP Tools

### tabz_speak

Speak text aloud using neural TTS.

```bash
mcp-cli call tabz/tabz_speak '{"text": "Build complete"}'
mcp-cli call tabz/tabz_speak '{"text": "Error!", "priority": "high"}'
mcp-cli call tabz/tabz_speak '{"text": "Hello", "voice": "en-GB-SoniaNeural"}'
```

**Parameters:**

| Param | Required | Default | Description |
|-------|----------|---------|-------------|
| text | Yes | - | Text to speak |
| voice | No | `en-US-AndrewNeural` | Voice code |
| rate | No | `+0%` | Speed: `-50%` to `+100%` |
| pitch | No | `+0Hz` | Pitch: `-200Hz` to `+300Hz` |
| volume | No | 0.7 | Volume: 0.0-1.0 |
| priority | No | `low` | `high` interrupts, `low` skipped if high playing |

### tabz_list_voices

List available TTS voices.

```bash
mcp-cli call tabz/tabz_list_voices '{}'
```

### tabz_play_audio

Play audio files by URL.

```bash
mcp-cli call tabz/tabz_play_audio '{"url": "http://localhost:8129/sounds/ding.mp3"}'
mcp-cli call tabz/tabz_play_audio '{"url": "...", "volume": 0.5, "priority": "high"}'
```

---

## Available Voices

| Voice | Code |
|-------|------|
| Andrew (US Male) | `en-US-AndrewNeural` |
| Emma (US Female) | `en-US-EmmaNeural` |
| Brian (US Male) | `en-US-BrianNeural` |
| Aria (US Female) | `en-US-AriaNeural` |
| Guy (US Male) | `en-US-GuyNeural` |
| Jenny (US Female) | `en-US-JennyNeural` |
| Sonia (UK Female) | `en-GB-SoniaNeural` |
| Ryan (UK Male) | `en-GB-RyanNeural` |
| Natasha (AU Female) | `en-AU-NatashaNeural` |
| William (AU Male) | `en-AU-WilliamNeural` |

---

## Rate & Pitch

### Rate (Speech Speed)

| Value | Effect |
|-------|--------|
| `-50%` | Half speed (slower) |
| `+0%` | Normal speed |
| `+50%` | 1.5x speed |
| `+100%` | Double speed |

### Pitch

| Value | Effect |
|-------|--------|
| `-200Hz` | Much lower, calmer tone |
| `+0Hz` | Normal pitch |
| `+100Hz` | Higher, noticeable urgency |
| `+300Hz` | Maximum pitch |

---

## Priority System

- **high**: Interrupts any playing audio, blocks low-priority until complete
- **low**: Skipped if high-priority audio is playing

Use `high` for:
- Error alerts
- Task completion summaries
- Important notifications

Use `low` for:
- Status updates
- Tool announcements
- Background info

---

## REST API

### POST /api/audio/speak

Generate TTS and broadcast for playback.

```bash
curl -X POST http://localhost:8129/api/audio/speak \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Hello world",
    "voice": "en-US-EmmaNeural",
    "rate": "+10%",
    "pitch": "+20Hz",
    "volume": 0.8,
    "priority": "high"
  }'
```

### POST /api/audio/generate

Generate TTS audio and return URL (for manual playback).

```bash
curl -X POST http://localhost:8129/api/audio/generate \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Test",
    "voice": "en-US-AndrewNeural"
  }'
```

Returns:
```json
{
  "success": true,
  "url": "http://localhost:8129/audio/<hash>.mp3",
  "cached": false
}
```

---

## Caching

Audio is cached in `/tmp/claude-audio-cache/` with MD5 hash keys.

- First playback: brief delay (network + generation)
- Subsequent plays: instant from cache

---

## Custom Audio Files

Place files in TabzChrome's `backend/public/sounds/` to serve at:
```
http://localhost:8129/sounds/<filename>
```

Example:
```bash
mcp-cli call tabz/tabz_play_audio '{"url": "http://localhost:8129/sounds/success.mp3"}'
```
