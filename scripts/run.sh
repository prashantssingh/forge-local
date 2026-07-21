#!/bin/sh

# Start native Ollama when needed, ensure the model exists, then run Brain API.
set -eu

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PROJECT_DIR"

if [ ! -f .env ]; then
  cp .env.example .env
  printf '%s\n' "Created .env from .env.example"
fi

# Load only the known keys; do not execute .env as shell code.
while IFS='=' read -r KEY VALUE; do
  case "$KEY" in
    BRAIN_ADDRESS|OLLAMA_URL|BRAIN_MODEL|BRAIN_CONTEXT_SIZE|BRAIN_REASONING|BRAIN_DATA_DIR|BRAIN_MEMORY_ITEMS|BRAIN_MAX_AGENTS|BRAIN_API_KEY)
      VALUE=$(printf '%s' "$VALUE" | tr -d '\r')
      export "$KEY=$VALUE"
      ;;
  esac
done < .env

OLLAMA_URL=${OLLAMA_URL:-http://127.0.0.1:11434}
BRAIN_MODEL=${BRAIN_MODEL:-gpt-oss:20b}
BRAIN_ADDRESS=${BRAIN_ADDRESS:-127.0.0.1:8080}
RUNTIME_DIR="$PROJECT_DIR/.runtime"

for COMMAND in go curl ollama nohup; do
  if ! command -v "$COMMAND" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$COMMAND" >&2
    exit 1
  fi
done

wait_for_ollama() {
  ATTEMPT=0
  while [ "$ATTEMPT" -lt 30 ]; do
    if curl -fsS --max-time 3 "$OLLAMA_URL/api/tags" >/dev/null 2>&1; then
      return 0
    fi
    ATTEMPT=$((ATTEMPT + 1))
    sleep 2
  done
  return 1
}

if ! curl -fsS --max-time 3 "$OLLAMA_URL/api/tags" >/dev/null 2>&1; then
  if [ "$OLLAMA_URL" != "http://127.0.0.1:11434" ] && [ "$OLLAMA_URL" != "http://localhost:11434" ]; then
    printf 'Configured Ollama is unavailable: %s\n' "$OLLAMA_URL" >&2
    exit 1
  fi
  mkdir -p "$RUNTIME_DIR"
  printf '%s\n' "Starting native Ollama..."
  nohup ollama serve >"$RUNTIME_DIR/ollama.log" 2>&1 &
  printf '%s\n' "$!" > "$RUNTIME_DIR/ollama.pid"
  if ! wait_for_ollama; then
    printf 'Ollama did not become ready. Inspect %s\n' "$RUNTIME_DIR/ollama.log" >&2
    exit 1
  fi
fi

MODEL_LIST=$(ollama list 2>/dev/null || true)
if ! printf '%s\n' "$MODEL_LIST" | awk 'NR > 1 { print $1 }' | grep -Fx "$BRAIN_MODEL" >/dev/null 2>&1; then
  printf '%s\n' "Pulling $BRAIN_MODEL (about 14 GB; this can take a while)..."
  ollama pull "$BRAIN_MODEL"
fi

cat <<EOF
ForgeLocal Brain is starting.
API:    http://$BRAIN_ADDRESS
Model:  $BRAIN_MODEL
Memory: ${BRAIN_DATA_DIR:-./data}

Press Control-C to stop the Brain API. Native Ollama may remain available for
the next run.
EOF

exec go run .
