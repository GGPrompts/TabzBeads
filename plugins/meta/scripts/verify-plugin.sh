#!/usr/bin/env bash
# Plugin Verifier - validates Claude Code plugin structure
# Usage: ./verify-plugin.sh [plugin-path]

set -e

PLUGIN_PATH="${1:-.}"
cd "$PLUGIN_PATH"

ERRORS=0
WARNINGS=0

echo "=== Plugin Verifier ==="
echo "Path: $(pwd)"
echo ""

# 1. Find manifest type
echo "=== Manifest Validation ==="
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
  echo "ERROR: No manifest found"
  exit 1
fi
echo "Found: $MANIFEST ($MANIFEST_TYPE)"

# Validate JSON
if ! jq empty "$MANIFEST" 2>/dev/null; then
  echo "ERROR: Invalid JSON in $MANIFEST"
  exit 1
fi
echo "✓ Valid JSON"

# Check required fields
if [ "$MANIFEST_TYPE" = "marketplace" ]; then
  for field in name plugins; do
    if ! jq -e ".$field" "$MANIFEST" >/dev/null 2>&1; then
      echo "ERROR: Missing required field: $field"
      ERRORS=$((ERRORS + 1))
    fi
  done
else
  if ! jq -e ".name" "$MANIFEST" >/dev/null 2>&1; then
    echo "ERROR: Missing required field: name"
    ERRORS=$((ERRORS + 1))
  fi
fi
echo "✓ Required fields present"

# 2. Get plugin directories
echo ""
echo "=== Structure Validation ==="
if [ "$MANIFEST_TYPE" = "marketplace" ]; then
  PLUGIN_DIRS=$(jq -r '.plugins[].source // empty' "$MANIFEST" | sed 's|^\./||')
else
  PLUGIN_DIRS="."
fi

for PLUGIN_DIR in $PLUGIN_DIRS; do
  [ ! -d "$PLUGIN_DIR" ] && continue
  echo "Checking: $PLUGIN_DIR"

  # Check for wrongly placed .claude-plugin/
  if [ "$MANIFEST_TYPE" = "marketplace" ] && [ -d "$PLUGIN_DIR/.claude-plugin" ]; then
    echo "  ERROR: $PLUGIN_DIR has .claude-plugin/ - use plugin.json at root"
    ERRORS=$((ERRORS + 1))
  fi

  # Check plugin.json for marketplace plugins
  if [ "$MANIFEST_TYPE" = "marketplace" ] && [ ! -f "$PLUGIN_DIR/plugin.json" ]; then
    echo "  WARNING: $PLUGIN_DIR missing plugin.json"
    WARNINGS=$((WARNINGS + 1))
  fi
done
echo "✓ Structure validated"

# 3. Commands
echo ""
echo "=== Commands Validation ==="
for PLUGIN_DIR in $PLUGIN_DIRS; do
  CMD_DIR="$PLUGIN_DIR/commands"
  [ ! -d "$CMD_DIR" ] && continue

  shopt -s nullglob
  for CMD_FILE in "$CMD_DIR"/*.md; do
    [ ! -f "$CMD_FILE" ] && continue
    CMD_NAME=$(basename "$CMD_FILE" .md)

    if ! head -1 "$CMD_FILE" | grep -q "^---"; then
      echo "  WARNING: $CMD_NAME missing frontmatter"
      WARNINGS=$((WARNINGS + 1))
    fi
    echo "  ✓ $CMD_NAME"
  done
done

# 4. Skills
echo ""
echo "=== Skills Validation ==="
for PLUGIN_DIR in $PLUGIN_DIRS; do
  SKILLS_DIR="$PLUGIN_DIR/skills"
  [ ! -d "$SKILLS_DIR" ] && continue

  for SKILL_DIR in "$SKILLS_DIR"/*/; do
    [ ! -d "$SKILL_DIR" ] && continue
    SKILL_NAME=$(basename "$SKILL_DIR")
    SKILL_MD="$SKILL_DIR/SKILL.md"

    if [ ! -f "$SKILL_MD" ]; then
      echo "  ERROR: $SKILL_NAME missing SKILL.md"
      ERRORS=$((ERRORS + 1))
      continue
    fi

    if [ -d "$SKILL_DIR/skills" ]; then
      echo "  ERROR: $SKILL_NAME has nested skills/ - flatten!"
      ERRORS=$((ERRORS + 1))
    fi

    echo "  ✓ $SKILL_NAME"
  done
done

# 5. Agents
echo ""
echo "=== Agents Validation ==="
for PLUGIN_DIR in $PLUGIN_DIRS; do
  AGENTS_DIR="$PLUGIN_DIR/agents"
  [ ! -d "$AGENTS_DIR" ] && continue

  shopt -s nullglob
  for AGENT_FILE in "$AGENTS_DIR"/*.md; do
    [ ! -f "$AGENT_FILE" ] && continue
    AGENT_NAME=$(basename "$AGENT_FILE" .md)
    echo "  ✓ $AGENT_NAME"
  done
done

# 6. Hooks
echo ""
echo "=== Hooks Validation ==="
for PLUGIN_DIR in $PLUGIN_DIRS; do
  HOOKS_JSON="$PLUGIN_DIR/hooks/hooks.json"
  [ ! -f "$HOOKS_JSON" ] && continue

  if ! jq empty "$HOOKS_JSON" 2>/dev/null; then
    echo "  ERROR: Invalid JSON in $HOOKS_JSON"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  # Check script references
  SCRIPTS=$(jq -r '.. | .command? // empty' "$HOOKS_JSON" 2>/dev/null | grep -v '^\$' || true)
  for SCRIPT in $SCRIPTS; do
    RESOLVED=$(echo "$SCRIPT" | sed "s|\${CLAUDE_PLUGIN_ROOT}|$PLUGIN_DIR|g")
    if [ -f "$RESOLVED" ]; then
      if [ ! -x "$RESOLVED" ]; then
        echo "  WARNING: $RESOLVED not executable"
        WARNINGS=$((WARNINGS + 1))
      else
        echo "  ✓ $RESOLVED"
      fi
    fi
  done
done

# 7. Enabled Plugins Validation
echo ""
echo "=== Enabled Plugins Validation ==="

if [ "$MANIFEST_TYPE" = "marketplace" ]; then
  MARKETPLACE_NAME=$(jq -r '.name // empty' "$MANIFEST")

  # Check both user and project settings
  for SETTINGS_FILE in ~/.claude/settings.json .claude/settings.json; do
    [ ! -f "$SETTINGS_FILE" ] && continue

    echo "Checking: $SETTINGS_FILE"

    # Get enabled plugins that reference this marketplace
    ENABLED=$(jq -r ".enabledPlugins // {} | keys[]" "$SETTINGS_FILE" 2>/dev/null | grep "@${MARKETPLACE_NAME}$" || true)

    for PLUGIN_REF in $ENABLED; do
      PLUGIN_NAME="${PLUGIN_REF%@*}"  # Strip @marketplace suffix

      # Check if plugin exists in marketplace
      EXISTS=$(jq -r --arg name "$PLUGIN_NAME" '.plugins[] | select(.name == $name) | .name' "$MANIFEST" 2>/dev/null)
      if [ -z "$EXISTS" ]; then
        echo "  WARNING: Stale reference '$PLUGIN_REF' - plugin not found in marketplace"
        WARNINGS=$((WARNINGS + 1))
      else
        echo "  ✓ $PLUGIN_REF"
      fi
    done
  done
else
  echo "  (skipped - only applies to marketplaces)"
fi

# Summary
echo ""
echo "=== Summary ==="
if [ $ERRORS -eq 0 ]; then
  echo "✅ Validation passed ($WARNINGS warnings)"
  echo "{\"valid\": true, \"errors\": 0, \"warnings\": $WARNINGS}"
  exit 0
else
  echo "❌ Validation failed: $ERRORS errors, $WARNINGS warnings"
  echo "{\"valid\": false, \"errors\": $ERRORS, \"warnings\": $WARNINGS}"
  exit 1
fi
