#!/bin/sh

# Build a durable summary from the reports in a manual run folder.
set -eu

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
RUNS_DIR="$PROJECT_DIR/agents/runs"

usage() {
  cat <<'EOF'
Usage: ./scripts/summarize-run.sh RUN_ID

Creates or replaces run-summary.md using the run's goal, status, test, review,
and memory reports. Review the generated summary before accepting it.
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

[ "$#" -eq 1 ] || { usage >&2; exit 2; }
RUN_ID=$1

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

SUMMARY_FILE="$RUN_DIR/run-summary.md"
GENERATED_AT=$(date '+%Y-%m-%d %H:%M:%S %Z')

{
  printf '# Agent Run Summary\n\n'
  printf -- '- **Run ID:** %s\n' "$RUN_ID"
  printf -- '- **Generated:** %s\n' "$GENERATED_AT"
  if [ -f "$RUN_DIR/STOPPED.md" ]; then
    printf -- '- **Stop state:** Stopped; review `STOPPED.md`\n'
  else
    printf -- '- **Stop state:** No stop marker present\n'
  fi
  printf '\n> This file aggregates manual reports. Its presence is not merge approval.\n'

  for REPORT in goal.md run-status.md test-report.md review-report.md memory-update.md; do
    printf '\n---\n\n## Source: %s\n\n' "$REPORT"
    if [ -f "$RUN_DIR/$REPORT" ]; then
      cat "$RUN_DIR/$REPORT"
    else
      printf 'Missing report: `%s`\n' "$REPORT"
    fi
  done
} > "$SUMMARY_FILE"

printf 'Created summary: agents/runs/%s/run-summary.md\n' "$RUN_ID"
printf '%s\n' "Review it manually before accepting or merging any result."
