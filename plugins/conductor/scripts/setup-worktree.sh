#!/usr/bin/env bash
# Setup a worktree with dependencies for a beads issue
# Usage: setup-worktree.sh <ISSUE_ID> [PROJECT_DIR]
#
# Uses `bd worktree create` which automatically:
# - Creates the worktree with a feature branch
# - Sets up beads database redirect
# - Configures proper gitignore

set -e

ISSUE="$1"
PROJECT_DIR="${2:-$(pwd)}"

# Validate issue ID format (alphanumeric with dash only)
if [[ ! "$ISSUE" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "ERROR: Invalid issue ID format: $ISSUE" >&2
  exit 1
fi

# bd worktree creates worktrees at ../<name> relative to project
WORKTREE="$(dirname "$PROJECT_DIR")/${ISSUE}"

# Lockfile for worktree creation (prevents race conditions with parallel workers)
WORKTREE_LOCK="/tmp/bd-worktree-$(basename "$PROJECT_DIR").lock"

# Use flock to serialize worktree creation across parallel workers
# Lock is automatically released when subshell exits (success or error)
(
  flock -x 200 || { echo "ERROR: Failed to acquire worktree lock" >&2; exit 1; }

  # Check if worktree already exists (another worker may have created it)
  if [ -d "$WORKTREE" ]; then
    echo "Worktree already exists: $WORKTREE"
    exit 0
  fi

  # Use bd worktree create - handles beads redirect automatically
  cd "$PROJECT_DIR"
  bd worktree create "$ISSUE" --branch "feature/${ISSUE}" 2>/dev/null || \
  bd worktree create "$ISSUE"  # Fallback: create without new branch if it exists
) 200>"$WORKTREE_LOCK"

# Install deps based on lockfile type (outside lock - can run in parallel)
if [ -f "$WORKTREE/package.json" ] && [ ! -d "$WORKTREE/node_modules" ]; then
  echo "Installing dependencies..."
  cd "$WORKTREE"
  if [ -f "pnpm-lock.yaml" ]; then
    pnpm install --frozen-lockfile
  elif [ -f "yarn.lock" ]; then
    yarn install --frozen-lockfile
  else
    npm ci 2>/dev/null || npm install
  fi
fi

# Run initial build if package.json has a build script
if [ -f "$WORKTREE/package.json" ]; then
  cd "$WORKTREE"
  if grep -q '"build"' package.json; then
    echo "Running initial build..."
    npm run build 2>&1 | tail -5 || echo "Build had warnings (continuing)"
  fi
fi

echo "READY: $WORKTREE"
