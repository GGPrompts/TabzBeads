---
description: "Validate plugin structure, manifests, and references. Use instead of full code review for plugin-only changes."
---

# Verify Plugin

Fast, automated validation of Claude Code plugin structure. Use this instead of full code review when changes are limited to plugin files.

## Usage

```bash
/meta:verify-plugin [path]
```

- No args: Validates all plugins in current marketplace
- With path: Validates specific plugin directory

## When to Use

- After modifying plugin.json or marketplace.json
- After adding/removing commands, agents, skills, or hooks
- Before committing plugin changes
- In worker-done pipeline (instead of full code-review for plugin changes)

## Validation Checks

### 1. Manifest Validation

```bash
echo "=== Manifest Validation ==="

# Find manifest type
if [ -f ".claude-plugin/marketplace.json" ]; then
  MANIFEST=".claude-plugin/marketplace.json"
  MANIFEST_TYPE="marketplace"
elif [ -f ".claude-plugin/plugin.json" ]; then
  MANIFEST=".claude-plugin/plugin.json"
  MANIFEST_TYPE="standalone"
elif [ -f "plugin.json" ]; then
  MANIFEST="plugin.json"
  MANIFEST_TYPE="plugin"
else
  echo "ERROR: No manifest found (plugin.json, .claude-plugin/plugin.json, or marketplace.json)"
  exit 1
fi

echo "Found: $MANIFEST ($MANIFEST_TYPE)"

# Validate JSON syntax
if ! jq empty "$MANIFEST" 2>/dev/null; then
  echo "ERROR: Invalid JSON in $MANIFEST"
  exit 1
fi
echo "✓ Valid JSON"

# Check required fields
if [ "$MANIFEST_TYPE" = "marketplace" ]; then
  REQUIRED_FIELDS=("name" "plugins")
else
  REQUIRED_FIELDS=("name")
fi

for field in "${REQUIRED_FIELDS[@]}"; do
  if ! jq -e ".$field" "$MANIFEST" >/dev/null 2>&1; then
    echo "ERROR: Missing required field: $field"
    exit 1
  fi
done
echo "✓ Required fields present"
```

### 2. Plugin Structure Validation

```bash
echo ""
echo "=== Structure Validation ==="

ERRORS=0

# Get plugin directories
if [ "$MANIFEST_TYPE" = "marketplace" ]; then
  PLUGIN_DIRS=$(jq -r '.plugins[].source // empty' "$MANIFEST" | sed 's|^\./||')
else
  PLUGIN_DIRS="."
fi

for PLUGIN_DIR in $PLUGIN_DIRS; do
  echo "Checking: $PLUGIN_DIR"

  # Check for wrongly placed .claude-plugin/ in marketplace plugins
  if [ "$MANIFEST_TYPE" = "marketplace" ] && [ -d "$PLUGIN_DIR/.claude-plugin" ]; then
    echo "  ERROR: $PLUGIN_DIR has .claude-plugin/ - use plugin.json at root instead"
    ERRORS=$((ERRORS + 1))
  fi

  # Check plugin.json exists for marketplace plugins
  if [ "$MANIFEST_TYPE" = "marketplace" ] && [ ! -f "$PLUGIN_DIR/plugin.json" ]; then
    echo "  WARNING: $PLUGIN_DIR missing plugin.json"
  fi
done

if [ $ERRORS -gt 0 ]; then
  echo "Structure validation failed with $ERRORS errors"
  exit 1
fi
echo "✓ Plugin structure valid"
```

### 3. Commands Validation

```bash
echo ""
echo "=== Commands Validation ==="

for PLUGIN_DIR in $PLUGIN_DIRS; do
  CMD_DIR="$PLUGIN_DIR/commands"
  [ ! -d "$CMD_DIR" ] && continue

  for CMD_FILE in "$CMD_DIR"/*.md; do
    [ ! -f "$CMD_FILE" ] && continue
    CMD_NAME=$(basename "$CMD_FILE" .md)

    # Check frontmatter exists
    if ! head -1 "$CMD_FILE" | grep -q "^---"; then
      echo "  WARNING: $CMD_FILE missing frontmatter"
    fi

    # Check description in frontmatter
    if ! grep -q "^description:" "$CMD_FILE"; then
      echo "  WARNING: $CMD_FILE missing description in frontmatter"
    fi

    echo "  ✓ $CMD_NAME"
  done
done
```

### 4. Skills Validation

```bash
echo ""
echo "=== Skills Validation ==="

for PLUGIN_DIR in $PLUGIN_DIRS; do
  SKILLS_DIR="$PLUGIN_DIR/skills"
  [ ! -d "$SKILLS_DIR" ] && continue

  for SKILL_DIR in "$SKILLS_DIR"/*/; do
    [ ! -d "$SKILL_DIR" ] && continue
    SKILL_NAME=$(basename "$SKILL_DIR")
    SKILL_MD="$SKILL_DIR/SKILL.md"

    # Check SKILL.md exists
    if [ ! -f "$SKILL_MD" ]; then
      echo "  ERROR: $SKILL_DIR missing SKILL.md"
      ERRORS=$((ERRORS + 1))
      continue
    fi

    # Check for nested skills (anti-pattern)
    if [ -d "$SKILL_DIR/skills" ]; then
      echo "  ERROR: $SKILL_DIR has nested skills/ - flatten to parent"
      ERRORS=$((ERRORS + 1))
    fi

    # Check frontmatter
    if ! head -1 "$SKILL_MD" | grep -q "^---"; then
      echo "  WARNING: $SKILL_MD missing frontmatter"
    fi

    # Check name and description
    if ! grep -q "^name:" "$SKILL_MD"; then
      echo "  WARNING: $SKILL_MD missing name in frontmatter"
    fi
    if ! grep -q "^description:" "$SKILL_MD"; then
      echo "  WARNING: $SKILL_MD missing description in frontmatter"
    fi

    echo "  ✓ $SKILL_NAME"
  done
done

if [ $ERRORS -gt 0 ]; then
  echo "Skills validation failed with $ERRORS errors"
  exit 1
fi
```

### 5. Agents Validation

```bash
echo ""
echo "=== Agents Validation ==="

for PLUGIN_DIR in $PLUGIN_DIRS; do
  AGENTS_DIR="$PLUGIN_DIR/agents"
  [ ! -d "$AGENTS_DIR" ] && continue

  for AGENT_FILE in "$AGENTS_DIR"/*.md; do
    [ ! -f "$AGENT_FILE" ] && continue
    AGENT_NAME=$(basename "$AGENT_FILE" .md)

    # Check frontmatter
    if ! head -1 "$AGENT_FILE" | grep -q "^---"; then
      echo "  WARNING: $AGENT_FILE missing frontmatter"
    fi

    # Check required fields
    if ! grep -q "^name:\|^description:" "$AGENT_FILE"; then
      echo "  WARNING: $AGENT_FILE missing name or description"
    fi

    echo "  ✓ $AGENT_NAME"
  done
done
```

### 6. Hooks Validation

```bash
echo ""
echo "=== Hooks Validation ==="

for PLUGIN_DIR in $PLUGIN_DIRS; do
  HOOKS_JSON="$PLUGIN_DIR/hooks/hooks.json"
  [ ! -f "$HOOKS_JSON" ] && continue

  # Validate JSON
  if ! jq empty "$HOOKS_JSON" 2>/dev/null; then
    echo "  ERROR: Invalid JSON in $HOOKS_JSON"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  # Check referenced scripts exist and are executable
  SCRIPTS=$(jq -r '.. | .command? // empty' "$HOOKS_JSON" 2>/dev/null | grep -v '^\$' || true)
  for SCRIPT in $SCRIPTS; do
    # Resolve ${CLAUDE_PLUGIN_ROOT}
    RESOLVED=$(echo "$SCRIPT" | sed "s|\${CLAUDE_PLUGIN_ROOT}|$PLUGIN_DIR|g")

    if [ ! -f "$RESOLVED" ]; then
      echo "  ERROR: Hook script not found: $RESOLVED"
      ERRORS=$((ERRORS + 1))
    elif [ ! -x "$RESOLVED" ]; then
      echo "  WARNING: Hook script not executable: $RESOLVED (run chmod +x)"
    else
      echo "  ✓ $RESOLVED"
    fi
  done
done

if [ $ERRORS -gt 0 ]; then
  echo "Hooks validation failed with $ERRORS errors"
  exit 1
fi
```

### 7. Marketplace Skills Array

```bash
echo ""
echo "=== Marketplace Skills Validation ==="

if [ "$MANIFEST_TYPE" = "marketplace" ]; then
  # Check if plugins have explicit skills arrays
  PLUGINS_WITH_SKILLS=$(jq -r '.plugins[] | select(.skills) | .name' "$MANIFEST" 2>/dev/null)

  if [ -z "$PLUGINS_WITH_SKILLS" ]; then
    echo "  INFO: No explicit skills arrays in marketplace.json (auto-discovery used)"
  else
    # Validate each explicit skill path exists
    jq -r '.plugins[] | select(.skills) | "\(.source)|\(.skills[])"' "$MANIFEST" 2>/dev/null | while IFS='|' read -r SRC SKILL_PATH; do
      FULL_PATH="${SRC#./}/${SKILL_PATH#./}"
      if [ ! -d "$FULL_PATH" ] && [ ! -f "$FULL_PATH/SKILL.md" ]; then
        echo "  ERROR: Skill path not found: $FULL_PATH"
        ERRORS=$((ERRORS + 1))
      else
        echo "  ✓ $FULL_PATH"
      fi
    done
  fi
fi
```

### 8. Summary

```bash
echo ""
echo "=== Validation Summary ==="

if [ $ERRORS -eq 0 ]; then
  echo "✅ All validations passed"
  echo '{"valid": true, "errors": 0}'
else
  echo "❌ Validation failed with $ERRORS errors"
  echo "{\"valid\": false, \"errors\": $ERRORS}"
  exit 1
fi
```

## Output Format

```json
{"valid": true, "errors": 0}
{"valid": false, "errors": 3}
```

## Integration with Worker Pipeline

In `bdw-worker-done` or code review step:

```bash
# Check if changes are plugin-only
CHANGED_FILES=$(git diff --name-only HEAD~1)
PLUGIN_ONLY=$(echo "$CHANGED_FILES" | grep -v "^plugins/\|^\.claude-plugin/" | wc -l)

if [ "$PLUGIN_ONLY" -eq 0 ]; then
  echo "Plugin-only changes detected, running verify-plugin"
  /meta:verify-plugin
else
  echo "Non-plugin changes, running full code review"
  /conductor:bdw-code-review
fi
```

## Composable With

- `/conductor:bdw-commit-changes` - Run verify before commit
- `/conductor:bdw-worker-done` - Alternative to full code-review
- `/meta:plugin-development` - Reference for fixing issues
