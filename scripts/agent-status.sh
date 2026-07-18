#!/bin/sh

# Display the latest or named manual run status.
set -eu

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
RUNS_DIR="$PROJECT_DIR/agents/runs"

usage() {
  cat <<'EOF'
Usage: ./scripts/agent-status.sh [RUN_ID]

Shows run metadata and status. With no RUN_ID, shows the newest run folder.
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

if [ "$#" -gt 1 ]; then
  usage >&2
  exit 2
fi

if [ "$#" -eq 1 ]; then
  RUN_ID=$1
  case "$RUN_ID" in
    "."|".."|*[!a-zA-Z0-9._-]*)
      printf '%s\n' "Invalid run ID." >&2
      exit 2
      ;;
  esac
  RUN_DIR="$RUNS_DIR/$RUN_ID"
else
  RUN_DIR=$(ls -1dt "$RUNS_DIR"/20* 2>/dev/null | sed -n '1p')
  if [ -z "$RUN_DIR" ]; then
    printf '%s\n' "No agent runs exist yet." >&2
    exit 1
  fi
  RUN_ID=$(basename "$RUN_DIR")
fi

if [ ! -d "$RUN_DIR" ]; then
  printf 'Run not found: %s\n' "$RUN_ID" >&2
  exit 1
fi

printf 'Agent run: %s\n\n' "$RUN_ID"

if [ -f "$RUN_DIR/goal.md" ]; then
  cat "$RUN_DIR/goal.md"
fi

if [ -f "$RUN_DIR/run-status.md" ]; then
  printf '\n'
  cat "$RUN_DIR/run-status.md"
fi

if [ -f "$RUN_DIR/STOPPED.md" ]; then
  printf '\nSTOP MARKER PRESENT\n\n'
  cat "$RUN_DIR/STOPPED.md"
else
  printf '\nNo stop marker is present. This does not imply automatic approval.\n'
fi
