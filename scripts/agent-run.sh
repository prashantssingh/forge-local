#!/bin/sh

# Prepare a run and print the next manual approval-gated prompt.
set -eu

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
WORKFLOW=single-task

usage() {
  cat <<'EOF'
Usage: ./scripts/agent-run.sh [--workflow NAME] "goal"

Creates a run folder and prints manual orchestration instructions.
This command does not invoke an AI model or execute workflow steps.
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

CREATE_OUTPUT=$("$SCRIPT_DIR/create-agent-run.sh" --workflow "$WORKFLOW" "$GOAL")
printf '%s\n' "$CREATE_OUTPUT"
RUN_ID=$(printf '%s\n' "$CREATE_OUTPUT" | sed -n 's/^RUN_ID=//p')

if [ -z "$RUN_ID" ]; then
  printf '%s\n' "The run was created but its ID could not be read." >&2
  exit 1
fi

cat <<EOF

Manual next steps
-----------------
1. Open agents/runs/$RUN_ID/run-plan.md.
2. Give the prompt below to your local model or Aider in read-only/ask mode.
3. Review and approve the completed plan yourself.
4. Only after approval, create the isolated branch:
     git switch -c agent/$RUN_ID
5. Let the Builder implement one approved task, then run Tester and Reviewer.
6. Stop immediately if agents/runs/$RUN_ID/STOPPED.md exists.

Orchestrator prompt
-------------------
You are the Orchestrator Agent for ForgeLocal AgentOS. Read the project memory,
agent policies, agents/profiles/orchestrator.md, agents/workflows/$WORKFLOW.yaml,
and agents/runs/$RUN_ID/goal.md. Complete only the run plan and status files.
Do not modify application code. Stop for human approval after planning.

This helper prepared artifacts only. It did not invoke a model, create a branch,
run commands on your behalf, or approve any work.
EOF
