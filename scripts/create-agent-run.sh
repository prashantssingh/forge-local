#!/bin/sh

# Create a manual agent-run workspace from the tracked report templates.
set -eu

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
RUNS_DIR="$PROJECT_DIR/agents/runs"
TEMPLATES_DIR="$PROJECT_DIR/agents/templates"
WORKFLOWS_DIR="$PROJECT_DIR/agents/workflows"
WORKFLOW=single-task

usage() {
  cat <<'EOF'
Usage: ./scripts/create-agent-run.sh [--workflow NAME] "goal"

Creates agents/runs/YYYY-MM-DD-HHMMSS-short-slug/, copies the report
templates, and records the goal. It does not invoke a model or modify code.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --workflow)
      [ "$#" -ge 2 ] || { printf '%s\n' "--workflow requires a name." >&2; exit 2; }
      WORKFLOW=${2%.yaml}
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
    *) break ;;
  esac
done

[ "$#" -gt 0 ] || { usage >&2; exit 2; }
GOAL=$*

case "$WORKFLOW" in
  *[!a-zA-Z0-9_-]*|"")
    printf '%s\n' "Workflow names may contain only letters, numbers, underscores, and hyphens." >&2
    exit 2
    ;;
esac

WORKFLOW_FILE="$WORKFLOWS_DIR/$WORKFLOW.yaml"
if [ ! -f "$WORKFLOW_FILE" ]; then
  printf 'Unknown workflow: %s\nAvailable workflows:\n' "$WORKFLOW" >&2
  for WORKFLOW_PATH in "$WORKFLOWS_DIR"/*.yaml; do
    [ -f "$WORKFLOW_PATH" ] || continue
    basename "$WORKFLOW_PATH" .yaml
  done | sort >&2
  exit 1
fi

for TEMPLATE in run-plan.md run-status.md test-report.md review-report.md memory-update.md; do
  if [ ! -f "$TEMPLATES_DIR/$TEMPLATE" ]; then
    printf 'Missing run template: %s\n' "$TEMPLATES_DIR/$TEMPLATE" >&2
    exit 1
  fi
done

SLUG=$(printf '%s' "$GOAL" | tr '[:upper:]' '[:lower:]' | \
  sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//' | cut -c1-40)
[ -n "$SLUG" ] || SLUG=run

TIMESTAMP=$(date '+%Y-%m-%d-%H%M%S')
RUN_ID="$TIMESTAMP-$SLUG"
RUN_DIR="$RUNS_DIR/$RUN_ID"

if [ -e "$RUN_DIR" ]; then
  printf 'Run directory already exists: %s\nRetry in one second or use a more specific goal.\n' "$RUN_DIR" >&2
  exit 1
fi

mkdir -p "$RUN_DIR"
cp "$TEMPLATES_DIR/run-plan.md" "$RUN_DIR/run-plan.md"
cp "$TEMPLATES_DIR/run-status.md" "$RUN_DIR/run-status.md"
cp "$TEMPLATES_DIR/test-report.md" "$RUN_DIR/test-report.md"
cp "$TEMPLATES_DIR/review-report.md" "$RUN_DIR/review-report.md"
cp "$TEMPLATES_DIR/memory-update.md" "$RUN_DIR/memory-update.md"

CREATED_AT=$(date '+%Y-%m-%d %H:%M:%S %Z')
cat > "$RUN_DIR/goal.md" <<EOF
# Agent Run Goal

- **Run ID:** $RUN_ID
- **Created:** $CREATED_AT
- **Selected workflow:** $WORKFLOW
- **Workflow definition:** agents/workflows/$WORKFLOW.yaml

## User goal

$GOAL
EOF

cat >> "$RUN_DIR/run-plan.md" <<EOF

## Recorded run metadata

- **Run ID:** $RUN_ID
- **Selected workflow:** $WORKFLOW
- **User goal:** $GOAL
EOF

cat >> "$RUN_DIR/run-status.md" <<EOF

## Initial status

- **Run ID:** $RUN_ID
- **Current phase:** Planning
- **Current branch:** Not created; wait for plan approval
- **Next action:** Complete and approve run-plan.md
EOF

printf 'Created manual agent run: %s\n' "$RUN_ID"
printf 'RUN_ID=%s\n' "$RUN_ID"
printf 'RUN_PATH=%s\n' "$RUN_DIR"
