#!/bin/sh

# Create durable project-memory files without overwriting existing history.
set -eu

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PROJECT_DIR"

FORCE=false
CREATED=0
SKIPPED=0

usage() {
  cat <<'EOF'
Usage: ./scripts/init-project-memory.sh [--force]

Creates the four core project-memory files when they are missing.
Use --force only when you intentionally want to replace their contents.
EOF
}

case "${1:-}" in
  --force) FORCE=true ;;
  -h|--help)
    usage
    exit 0
    ;;
  "") ;;
  *)
    usage >&2
    exit 2
    ;;
esac

mkdir -p docs

should_write() {
  TARGET=$1
  if [ "$FORCE" = true ] || [ ! -e "$TARGET" ]; then
    return 0
  fi
  printf 'Skipped existing file: %s\n' "$TARGET"
  SKIPPED=$((SKIPPED + 1))
  return 1
}

if should_write docs/ai-context.md; then
  cat > docs/ai-context.md <<'EOF'
# Project Context

## Project goal

Describe what this project exists to accomplish.

## Architecture

Record the current components, boundaries, and data flow.

## Local hardware constraints

- MacBook Pro 16-inch, 2021
- Apple M1 Pro
- 16 GB unified memory
- macOS Tahoe 26.5.2

## Current model choices

- Primary: `qwen2.5-coder:14b`
- Fallback: `qwen2.5-coder:7b`
- Experimental only: `qwen3-coder:30b`

## Coding standards

Add the repository's language, formatting, testing, and review conventions.

## Safety and privacy requirements

Keep private code local, work on branches, minimize changes, and stop for required approvals.

## Known limitations

List important technical, hardware, and workflow limitations.

## Current project state

Summarize what works now and what remains incomplete.

## Agent instructions

Read this file before planning. Treat it as durable context, verify it against the repository, and update it only when the project's lasting context changes.
EOF
  printf '%s\n' "Created: docs/ai-context.md"
  CREATED=$((CREATED + 1))
fi

if should_write docs/ai-decisions.md; then
  cat > docs/ai-decisions.md <<'EOF'
# Architecture Decisions

Use one section per durable decision. Do not record routine implementation details here.

## ADR-NNN: Decision title

- **Date:** YYYY-MM-DD
- **Status:** Proposed | Accepted | Superseded
- **Context:** Why a decision is needed.
- **Decision:** What was chosen.
- **Consequences:** Benefits, costs, and follow-up work.
EOF
  printf '%s\n' "Created: docs/ai-decisions.md"
  CREATED=$((CREATED + 1))
fi

if should_write docs/ai-todo.md; then
  cat > docs/ai-todo.md <<'EOF'
# Project TODO

## Next

- [ ] Add the next small, clearly testable task.

## Later

- [ ] Add deferred or exploratory work here.

## Completed

Move finished tasks here with a completion date and run reference.
EOF
  printf '%s\n' "Created: docs/ai-todo.md"
  CREATED=$((CREATED + 1))
fi

if should_write docs/ai-log.md; then
  cat > docs/ai-log.md <<'EOF'
# Project Work Log

Append concise, factual entries. Do not paste raw chat transcripts.

## YYYY-MM-DD — Session title

- **Goal:**
- **What changed:**
- **Commands run:**
- **Tests/checks:**
- **Decisions made:**
- **Problems encountered:**
- **Next steps:**
EOF
  printf '%s\n' "Created: docs/ai-log.md"
  CREATED=$((CREATED + 1))
fi

printf 'Memory initialization complete: %s created, %s skipped.\n' "$CREATED" "$SKIPPED"
