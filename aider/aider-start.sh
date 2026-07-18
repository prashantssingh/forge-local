#!/bin/sh

# Launch Aider against native Ollama with durable project memory in context.
set -eu

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PROJECT_DIR"

usage() {
  cat <<'EOF'
Usage: ./aider/aider-start.sh

Starts Aider with qwen2.5-coder:14b through native Ollama and adds the four
project-memory files to the editing session.
EOF
}

case "${1:-}" in
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

read_env_value() {
  ENV_NAME=$1
  ENV_SOURCE=.env
  [ -f "$ENV_SOURCE" ] || ENV_SOURCE=.env.example
  awk -v name="$ENV_NAME" 'index($0, name "=") == 1 { sub(/^[^=]*=/, ""); print; exit }' "$ENV_SOURCE"
}

FILE_PRIMARY_MODEL=$(read_env_value PRIMARY_MODEL)
PRIMARY_MODEL=${PRIMARY_MODEL:-${FILE_PRIMARY_MODEL:-qwen2.5-coder:14b}}

if ! command -v git >/dev/null 2>&1 || \
   ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf '%s\n' "Aider must be launched from inside the ForgeLocal Git repository." >&2
  exit 1
fi

CURRENT_BRANCH=$(git branch --show-current)
case "$CURRENT_BRANCH" in
  ""|main|master)
    cat >&2 <<EOF
Aider editing is blocked on the current branch: ${CURRENT_BRANCH:-detached HEAD}
Create an isolated branch first, for example:
  git switch -c agent/manual-YYYY-MM-DD-small-goal
EOF
    exit 1
    ;;
esac

if ! command -v aider >/dev/null 2>&1; then
  cat >&2 <<'EOF'
Aider is not installed or is not on PATH.
Follow the official installation instructions at https://aider.chat/docs/install.html
and then rerun this script.
EOF
  exit 1
fi

if ! command -v ollama >/dev/null 2>&1; then
  printf '%s\n' "Ollama is not installed. Run ./scripts/setup-ollama.sh." >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1 || \
   ! curl -fsS --max-time 5 http://127.0.0.1:11434/api/tags >/dev/null; then
  printf '%s\n' "Native Ollama is not responding at http://127.0.0.1:11434." >&2
  exit 1
fi

if ! ollama list 2>/dev/null | awk 'NR > 1 { print $1 }' | grep -Fx "$PRIMARY_MODEL" >/dev/null 2>&1; then
  printf 'Primary model is missing: %s\nRun ./scripts/pull-models.sh first.\n' "$PRIMARY_MODEL" >&2
  exit 1
fi

for MEMORY_FILE in docs/ai-context.md docs/ai-decisions.md docs/ai-todo.md docs/ai-log.md; do
  if [ ! -f "$MEMORY_FILE" ]; then
    printf 'Missing memory file: %s\nRun ./scripts/init-project-memory.sh.\n' "$MEMORY_FILE" >&2
    exit 1
  fi
done

export OLLAMA_API_BASE=http://127.0.0.1:11434

cat <<EOF
Starting Aider with ollama_chat/$PRIMARY_MODEL.
Keep work on a non-main branch and review every proposed shell command.
Use /ask for read-only discussion and keep coding tasks small.
EOF

exec aider \
  --model "ollama_chat/$PRIMARY_MODEL" \
  docs/ai-context.md \
  docs/ai-decisions.md \
  docs/ai-todo.md \
  docs/ai-log.md
