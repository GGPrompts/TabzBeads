#!/usr/bin/env bash
# Install TabzBeads plugins to Claude Code
# Usage: ./install.sh [--link /path/to/project]
#
# Options:
#   --link <path>  Symlink PRIME.md template to target project

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS_SRC="$SCRIPT_DIR/plugins"
PLUGINS_DEST="$HOME/.claude/plugins"
PRIME_TEMPLATE="$SCRIPT_DIR/docs/PRIME-template.md"

# Parse arguments
LINK_TARGET=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --link)
      LINK_TARGET="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [--link /path/to/project]"
      echo ""
      echo "Install TabzBeads plugins to ~/.claude/plugins/"
      echo ""
      echo "Options:"
      echo "  --link <path>  Symlink PRIME.md template to target project"
      echo "  -h, --help     Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Use --help for usage information" >&2
      exit 1
      ;;
  esac
done

# Ensure plugins source exists
if [ ! -d "$PLUGINS_SRC" ]; then
  echo "ERROR: Plugins directory not found: $PLUGINS_SRC" >&2
  exit 1
fi

# Create destination directory if needed
mkdir -p "$PLUGINS_DEST"

echo "Installing TabzBeads plugins..."
echo ""

# Install each plugin
installed=0
for plugin_dir in "$PLUGINS_SRC"/*/; do
  if [ -d "$plugin_dir" ]; then
    plugin_name=$(basename "$plugin_dir")
    dest_dir="$PLUGINS_DEST/$plugin_name"

    # Remove existing plugin (idempotent)
    if [ -d "$dest_dir" ] || [ -L "$dest_dir" ]; then
      rm -rf "$dest_dir"
    fi

    # Copy plugin
    cp -r "$plugin_dir" "$dest_dir"
    echo "  Installed: $plugin_name"
    installed=$((installed + 1))
  fi
done

echo ""
echo "Installed $installed plugin(s) to $PLUGINS_DEST"

# Handle --link option
if [ -n "$LINK_TARGET" ]; then
  echo ""

  # Validate link target
  if [ ! -d "$LINK_TARGET" ]; then
    echo "ERROR: Target directory does not exist: $LINK_TARGET" >&2
    exit 1
  fi

  # Check if PRIME template exists
  if [ ! -f "$PRIME_TEMPLATE" ]; then
    echo "ERROR: PRIME template not found: $PRIME_TEMPLATE" >&2
    exit 1
  fi

  prime_dest="$LINK_TARGET/PRIME.md"

  # Remove existing PRIME.md (idempotent)
  if [ -f "$prime_dest" ] || [ -L "$prime_dest" ]; then
    rm -f "$prime_dest"
  fi

  # Create symlink
  ln -s "$PRIME_TEMPLATE" "$prime_dest"
  echo "Linked PRIME.md template to: $prime_dest"
fi

echo ""
echo "Done!"
