#!/bin/sh

# Add a durable stop marker to a manual run. No OS process is killed.
set -eu

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
RUNS_DIR="$PROJECT_DIR/agents/runs"

usage() {
  cat <<'EOF'
Usage: ./scripts/agent-stop.sh RUN_ID [reason]

Creates STOPPED.md in the selected run. Agents and operators must check this
marker between steps. This script does not terminate OS processes.
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  "")
    usage >&2
    exit 2
    ;;
esac

RUN_ID=$1
shift
REASON=${*:-Stopped manually by the operator.}

case "$RUN_ID" in
  "."|".."|*[!a-zA-Z0-9._-]*)
    printf '%s\n' "Invalid run ID." >&2
    exit 2
    ;;
esac

RUN_DIR="$RUNS_DIR/$RUN_ID"
if [ ! -d "$RUN_DIR" ]; then
  printf 'Run not found: %s\n' "$RUN_ID" >&2
  exit 1
fi

STOPPED_AT=$(date '+%Y-%m-%d %H:%M:%S %Z')
cat > "$RUN_DIR/STOPPED.md" <<EOF
# Run Stopped

- **Run ID:** $RUN_ID
- **Stopped at:** $STOPPED_AT
- **Reason:** $REASON

Do not perform another workflow step until a human reviews the run and creates
a new explicit plan. Removing this marker is a human decision.
EOF

cat <<EOF
Stop marker created: agents/runs/$RUN_ID/STOPPED.md

This marker is a coordination and audit control. It did not kill an Ollama,
Aider, Docker, shell, or other operating-system process. Stop such a process
directly in the terminal where it is running if necessary.
EOF
