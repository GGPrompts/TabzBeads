---
name: "bdw-update-docs"
user-invocable: false
description: "Verify beads metadata and update core documentation (README.md, CHANGELOG.md, CLAUDE.md). Creates missing docs, enforces line limits."
---

# Update Docs & Verify Beads

Verify issue metadata is correct and update core documentation. Anti-bloat: only touches README.md, CHANGELOG.md, CLAUDE.md, and existing docs/ files.

## Usage

```
/conductor:bdw-update-docs [issue-id]
```

## What This Does

1. **Verify beads metadata** - dependencies, discovered tasks, issue accuracy
2. **Update core docs** - README.md, CHANGELOG.md, CLAUDE.md
3. **Create if missing** - these 3 files only
4. **Enforce limits** - CHANGELOG.md capped at ~500 lines

## Documentation Philosophy

| File | Purpose | Style | Create? | Limit |
|------|---------|-------|---------|-------|
| `README.md` | Human intro, quick start, badges | Human-friendly | Yes | None |
| `CHANGELOG.md` | Version history | Human-friendly | Yes | ~500 lines |
| `CLAUDE.md` | LLM context (lean, no @imports) | For-LLMs style | Yes | Keep lean |
| `docs/*.md` | Detailed docs (progressive disclosure) | Detailed | Yes, when needed | None |

### For-LLMs Style (CLAUDE.md)

```markdown
## API Routes
- `POST /api/thing/action` - Description (app/api/thing/action/route.ts)

## Components
| Component | File | Purpose |
|-----------|------|---------|
| ThingCard | components/ThingCard.tsx | Display thing details |

## Key Files
- `src/lib/thing.ts` - Core thing logic
- `src/hooks/useThing.ts` - React hook for things
```

**Rules:**
- One-liner descriptions, not paragraphs
- File paths mandatory
- Tables for 3+ items
- No "why" - just "what" and "where"

---

## Execute

### Step 1: Verify Beads Metadata

```bash
echo "=== Step 1: Verify Beads Metadata ==="

ISSUE_ID="${1:-}"

if [ -n "$ISSUE_ID" ]; then
  # Get issue details
  bd show "$ISSUE_ID" --json
fi
```

**Check:**

1. **Dependencies accurate?**
   - Does the issue depend on things it actually needed?
   - Are there missing dependencies that should be added?

2. **Discovered work tracked?**
   - Any TODOs/FIXMEs in the code that need issues?
   - Should follow-up issues be created with `discovered-from` link?

3. **Issue description still accurate?**
   - Does the title match what was actually done?
   - Should notes be updated with implementation details?

```bash
# Check for TODOs in changed files
git diff HEAD~1 --name-only | xargs grep -l "TODO\|FIXME\|HACK" 2>/dev/null | head -5

# If TODOs found, suggest:
# bd create --title "TODO: ..." --type task
# bd dep add <new-id> discovered-from $ISSUE_ID
```

### Step 2: Check Core Docs Exist

```bash
echo "=== Step 2: Check Core Docs ==="

# Create README.md if missing
if [ ! -f "README.md" ]; then
  echo "Creating README.md..."
  # Create minimal README with project name from package.json or directory
  PROJECT_NAME=$(basename "$(pwd)")
  cat > README.md << 'HEREDOC'
# $PROJECT_NAME

## Quick Start

```bash
# Install
npm install

# Run
npm run dev
```

## Documentation

See [CLAUDE.md](./CLAUDE.md) for architecture and development guide.
HEREDOC
  sed -i "s/\$PROJECT_NAME/$PROJECT_NAME/g" README.md
fi

# Create CHANGELOG.md if missing
if [ ! -f "CHANGELOG.md" ]; then
  echo "Creating CHANGELOG.md..."
  cat > CHANGELOG.md << 'HEREDOC'
# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- Initial release
HEREDOC
fi

# Create CLAUDE.md if missing
if [ ! -f "CLAUDE.md" ]; then
  echo "Creating CLAUDE.md..."
  cat > CLAUDE.md << 'HEREDOC'
# CLAUDE.md

## Overview

[One-liner project description]

## Key Files

- `src/` - Source code
- `package.json` - Dependencies and scripts

## Commands

```bash
npm run dev      # Start development server
npm run build    # Build for production
npm test         # Run tests
```
HEREDOC
fi
```

### Step 3: Analyze Changes for Doc Updates

```bash
echo "=== Step 3: Analyze Changes ==="

# Get changed files
git diff HEAD~1 --name-only 2>/dev/null || git diff --cached --name-only
```

**Determine what needs documenting:**

| Change Type | Update Target |
|-------------|---------------|
| New API route | CLAUDE.md (API section) |
| New component | CLAUDE.md (Components table) |
| New CLI command | README.md (Usage section) |
| New feature | CHANGELOG.md (under ## [Unreleased]) |
| Breaking change | CHANGELOG.md + README.md migration note |
| New env var | CLAUDE.md + README.md setup section |

### Step 4: Update CHANGELOG.md

Add entry under `## [Unreleased]`:

```markdown
## [Unreleased]

### Added
- Feature description (#issue-id)

### Fixed
- Bug fix description

### Changed
- Notable change
```

**Style:**
- One line per change
- User-facing language
- Link to issue if available

### Step 5: Update CLAUDE.md (For-LLMs Style)

If new APIs, components, or architecture changes:

```markdown
## New in This Wave

### API Routes
- `POST /api/new/endpoint` - Description (path/to/route.ts)

### Components
| Component | File | Purpose |
|-----------|------|---------|
| NewThing | components/NewThing.tsx | Does the thing |

### Key Files Changed
- `src/lib/core.ts` - Added X functionality
```

### Step 6: Enforce CHANGELOG Limit

```bash
echo "=== Step 6: Check CHANGELOG Size ==="

if [ -f "CHANGELOG.md" ]; then
  LINES=$(wc -l < CHANGELOG.md)
  if [ "$LINES" -gt 500 ]; then
    echo "CHANGELOG.md is $LINES lines (limit: 500)"
    echo "Archiving older entries..."

    # Find the 3rd version header (keep ~2 versions in main file)
    SPLIT_LINE=$(grep -n "^## \[" CHANGELOG.md | sed -n '3p' | cut -d: -f1)

    if [ -n "$SPLIT_LINE" ]; then
      # Archive older entries
      mkdir -p docs
      tail -n +$SPLIT_LINE CHANGELOG.md >> docs/CHANGELOG-archive.md
      head -n $((SPLIT_LINE - 1)) CHANGELOG.md > CHANGELOG.tmp
      mv CHANGELOG.tmp CHANGELOG.md

      # Add link to archive
      echo "" >> CHANGELOG.md
      echo "---" >> CHANGELOG.md
      echo "See [docs/CHANGELOG-archive.md](docs/CHANGELOG-archive.md) for older versions." >> CHANGELOG.md

      echo "Archived entries to docs/CHANGELOG-archive.md"
    fi
  else
    echo "CHANGELOG.md is $LINES lines (under 500 limit)"
  fi
fi
```

### Step 7: Stage and Report

```bash
echo "=== Step 7: Stage Doc Changes ==="

UPDATED_FILES=""

for FILE in README.md CHANGELOG.md CLAUDE.md docs/CHANGELOG-archive.md; do
  if [ -f "$FILE" ] && ! git diff --quiet "$FILE" 2>/dev/null; then
    git add "$FILE"
    UPDATED_FILES="$UPDATED_FILES $FILE"
  fi
done

if [ -n "$UPDATED_FILES" ]; then
  echo '{"updated": true, "files": ["'"${UPDATED_FILES# }"'"]}'
else
  echo '{"updated": false}'
fi
```

---

## Progressive Disclosure Rules

**CLAUDE.md stays lean** - it's loaded into every LLM context window, so:

| In CLAUDE.md | In separate docs/ files |
|--------------|------------------------|
| One-liner descriptions | Detailed explanations |
| File paths | Full API documentation |
| Command examples | Tutorials and guides |
| Architecture overview | Implementation details |

**Key rule:** The `@` symbol auto-loads files into context. Use `-` for references instead.

```markdown
## Good - Progressive Disclosure
- `docs/api/thing.md` - Detailed API documentation
- `docs/architecture.md` - System design details

## Bad - Bloats Context
@docs/api/thing.md
@docs/architecture.md
```

**When to use `@` (sparingly):**
- Core architecture files needed in every session
- Key config files (maybe 2-3 max)

**When to use `-` references:**
- Detailed API docs
- Tutorials and guides
- Implementation details
- Anything Claude can look up on demand

**Creating new .md files is OK** when:
- A topic needs more than 2-3 lines of explanation
- You're documenting complex workflows
- API endpoints need request/response examples

**ALWAYS in CLAUDE.md:**
- One-liner descriptions
- File paths with every reference
- Tables for lists of 3+ items
- Use `-` for doc references, not `@`

---

## Output Format

```json
{"updated": true, "files": ["CHANGELOG.md", "CLAUDE.md"], "beads_verified": true}
{"updated": false, "beads_verified": true}
{"updated": false, "beads_issues": ["Missing dependency on TabzBeads-xyz"]}
```

---

## Composable With

| Command | Relationship |
|---------|--------------|
| `/conductor:bdw-commit-changes` | Doc updates included in commit |
| `/conductor:bdw-create-followups` | Run before (creates issues this verifies) |
| `/conductor:bdw-close-issue` | Run before closing |
| `/conductor:bdw-worker-done` | Full pipeline includes this as Step 5 |
