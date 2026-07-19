#!/bin/sh

# One-command setup and startup for the ForgeLocal AgentOS local stack.
set -eu

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PROJECT_DIR"

WITH_QDRANT=false
WITH_EXPERIMENTAL=false
DRY_RUN=false

usage() {
  cat <<'EOF'
Usage: ./scripts/bootstrap.sh [options]

Prepare and start the complete ForgeLocal AgentOS local stack:
  - create .env when missing
  - restore executable script permissions
  - ensure project-memory files exist
  - verify native Ollama and Docker Desktop
  - launch Ollama.app or a native `ollama serve` process when needed
  - launch Docker Desktop when it is not running
  - pull missing primary and fallback models
  - start Open WebUI
  - wait for services and run the complete health check

Options:
  --with-qdrant       Also start and verify optional Qdrant memory.
  --experimental      Also pull qwen3-coder:30b. Not recommended on 16 GB.
  --dry-run           Print the planned actions without changing anything.
  -h, --help          Show this help.

This script does not install missing host applications or launch Aider, which
is an interactive editing session. It prints exact guidance when a prerequisite
is missing.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --with-qdrant) WITH_QDRANT=true ;;
    --experimental) WITH_EXPERIMENTAL=true ;;
    --dry-run) DRY_RUN=true ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [ "$DRY_RUN" = true ]; then
  cat <<EOF
ForgeLocal AgentOS bootstrap dry run

Project root: $PROJECT_DIR
Optional Qdrant: $WITH_QDRANT
Experimental 30B model: $WITH_EXPERIMENTAL

Planned actions:
  1. Create .env from .env.example only if .env is missing.
  2. Restore executable permissions on shell entry points.
  3. Create only missing project-memory files.
  4. Verify Git, curl, native Ollama, and Docker Desktop.
  5. Launch Ollama.app or native ollama serve, plus Docker Desktop if needed.
  6. Pull only missing requested Ollama models.
  7. Start Open WebUI$(if [ "$WITH_QDRANT" = true ]; then printf ' and Qdrant'; fi).
  8. Wait for requested services and run the complete health check.

No files, applications, models, containers, or services were changed.
EOF
  exit 0
fi

printf '%s\n' "ForgeLocal AgentOS one-command bootstrap"
printf '%s\n' "Project root: $PROJECT_DIR"

if [ ! -f .env.example ]; then
  printf '%s\n' "Missing .env.example; restore the project scaffold before continuing." >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  cat >&2 <<'EOF'
Git is missing. Install the macOS command-line developer tools, then retry:
  xcode-select --install
EOF
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf '%s\n' "This project is not a Git repository. Initialize Git before continuing." >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  printf '%s\n' "curl is required and was not found on PATH." >&2
  exit 1
fi

if ! command -v ollama >/dev/null 2>&1; then
  cat >&2 <<'EOF'
Ollama is not installed or is not on PATH.
Install the native macOS app from https://ollama.com/download/mac and retry.
Do not install Ollama inside Docker on macOS.
EOF
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  cat >&2 <<'EOF'
Docker Desktop is not installed or its CLI is not on PATH.
Install it from https://docs.docker.com/desktop/setup/install/mac-install/
and then rerun this script.
EOF
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  printf '%s\n' "Docker Compose v2 is required but 'docker compose' is unavailable." >&2
  exit 1
fi

if [ -f .env ]; then
  printf '%s\n' "KEEP  Existing .env"
else
  cp .env.example .env
  printf '%s\n' "CREATE  .env from .env.example"
fi

chmod +x scripts/*.sh aider/*.sh examples/*.sh
printf '%s\n' "READY  Script permissions"

"$SCRIPT_DIR/init-project-memory.sh"

wait_for_ollama() {
  ATTEMPT=0
  while [ "$ATTEMPT" -lt 30 ]; do
    if curl -fsS --max-time 3 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
      return 0
    fi
    ATTEMPT=$((ATTEMPT + 1))
    sleep 2
  done
  return 1
}

start_ollama_cli() {
  RUNTIME_DIR="$PROJECT_DIR/.forge-local-runtime"
  OLLAMA_LOG="$RUNTIME_DIR/ollama.log"
  OLLAMA_PID_FILE="$RUNTIME_DIR/ollama.pid"

  if ! command -v nohup >/dev/null 2>&1; then
    printf '%s\n' "Ollama.app is unavailable and the nohup command required for a background server was not found." >&2
    return 1
  fi

  mkdir -p "$RUNTIME_DIR"
  printf '%s\n' "START  Launching native Ollama CLI server..."
  OLLAMA_CONTEXT_LENGTH="${OLLAMA_CONTEXT_LENGTH:-8192}" \
    nohup ollama serve >"$OLLAMA_LOG" 2>&1 &
  OLLAMA_PID=$!
  printf '%s\n' "$OLLAMA_PID" > "$OLLAMA_PID_FILE"

  if wait_for_ollama; then
    printf 'READY  Native Ollama CLI server (PID %s)\n' "$OLLAMA_PID"
    printf 'LOG    %s\n' "$OLLAMA_LOG"
    return 0
  fi

  printf 'Ollama CLI server did not become ready. Inspect: %s\n' "$OLLAMA_LOG" >&2
  return 1
}

if curl -fsS --max-time 3 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
  printf '%s\n' "READY  Native Ollama is running"
else
  if [ "$(uname -s)" = Darwin ] && command -v open >/dev/null 2>&1; then
    printf '%s\n' "START  Looking for the native Ollama app..."
    if open -a Ollama >/dev/null 2>&1; then
      if ! wait_for_ollama; then
        cat >&2 <<'EOF'
Ollama did not become ready within 60 seconds.
Open the Ollama app manually, or run this in another terminal:
  OLLAMA_CONTEXT_LENGTH=8192 ollama serve
Then rerun ./scripts/bootstrap.sh.
EOF
        exit 1
      fi
    elif ! start_ollama_cli; then
      exit 1
    fi
  elif ! start_ollama_cli; then
    exit 1
  fi
fi

"$SCRIPT_DIR/setup-ollama.sh" >/dev/null
printf '%s\n' "READY  Native Ollama API"

wait_for_docker() {
  ATTEMPT=0
  while [ "$ATTEMPT" -lt 30 ]; do
    if docker info >/dev/null 2>&1; then
      return 0
    fi
    ATTEMPT=$((ATTEMPT + 1))
    sleep 2
  done
  return 1
}

if docker info >/dev/null 2>&1; then
  printf '%s\n' "READY  Docker Desktop is running"
else
  if [ "$(uname -s)" = Darwin ] && command -v open >/dev/null 2>&1; then
    printf '%s\n' "START  Opening Docker Desktop..."
    open -a Docker
    if ! wait_for_docker; then
      printf '%s\n' "Docker Desktop did not become ready within 60 seconds. Start it manually and retry." >&2
      exit 1
    fi
  else
    printf '%s\n' "Docker is installed but its daemon is not running. Start it and retry." >&2
    exit 1
  fi
fi

read_env_value() {
  ENV_NAME=$1
  awk -v name="$ENV_NAME" 'index($0, name "=") == 1 { sub(/^[^=]*=/, ""); print; exit }' .env
}

FILE_PRIMARY_MODEL=$(read_env_value PRIMARY_MODEL)
FILE_FALLBACK_MODEL=$(read_env_value FALLBACK_MODEL)
FILE_EXPERIMENTAL_MODEL=$(read_env_value EXPERIMENTAL_MODEL)
FILE_WEBUI_PORT=$(read_env_value WEBUI_PORT)
FILE_QDRANT_PORT=$(read_env_value QDRANT_PORT)

PRIMARY_MODEL=${PRIMARY_MODEL:-${FILE_PRIMARY_MODEL:-qwen2.5-coder:14b}}
FALLBACK_MODEL=${FALLBACK_MODEL:-${FILE_FALLBACK_MODEL:-qwen2.5-coder:7b}}
EXPERIMENTAL_MODEL=${EXPERIMENTAL_MODEL:-${FILE_EXPERIMENTAL_MODEL:-qwen3-coder:30b}}
WEBUI_PORT=${WEBUI_PORT:-${FILE_WEBUI_PORT:-3000}}
QDRANT_PORT=${QDRANT_PORT:-${FILE_QDRANT_PORT:-6333}}
export PRIMARY_MODEL FALLBACK_MODEL EXPERIMENTAL_MODEL

MODEL_LIST=$(ollama list 2>/dev/null || true)
NEED_MODEL_PULL=false

for REQUIRED_MODEL in "$PRIMARY_MODEL" "$FALLBACK_MODEL"; do
  if ! printf '%s\n' "$MODEL_LIST" | awk 'NR > 1 { print $1 }' | grep -Fx "$REQUIRED_MODEL" >/dev/null 2>&1; then
    NEED_MODEL_PULL=true
  fi
done

if [ "$WITH_EXPERIMENTAL" = true ] && \
   ! printf '%s\n' "$MODEL_LIST" | awk 'NR > 1 { print $1 }' | grep -Fx "$EXPERIMENTAL_MODEL" >/dev/null 2>&1; then
  NEED_MODEL_PULL=true
fi

if [ "$NEED_MODEL_PULL" = true ]; then
  if [ "$WITH_EXPERIMENTAL" = true ]; then
    "$SCRIPT_DIR/pull-models.sh" --experimental
  else
    "$SCRIPT_DIR/pull-models.sh"
  fi
else
  printf '%s\n' "READY  All requested Ollama models are already available"
fi

if [ "$WITH_QDRANT" = true ]; then
  "$SCRIPT_DIR/start-webui.sh" --with-qdrant
else
  "$SCRIPT_DIR/start-webui.sh"
fi

wait_for_url() {
  SERVICE_NAME=$1
  SERVICE_URL=$2
  ATTEMPT=0
  printf 'WAIT   %s' "$SERVICE_NAME"
  while [ "$ATTEMPT" -lt 30 ]; do
    if curl -fsS --max-time 3 "$SERVICE_URL" >/dev/null 2>&1; then
      printf '%s\n' " ready"
      return 0
    fi
    printf '.'
    ATTEMPT=$((ATTEMPT + 1))
    sleep 2
  done
  printf '%s\n' " timed out" >&2
  return 1
}

if ! wait_for_url "Open WebUI" "http://127.0.0.1:$WEBUI_PORT/"; then
  printf '%s\n' "Inspect logs with: docker compose logs --tail=100 open-webui" >&2
  exit 1
fi

if [ "$WITH_QDRANT" = true ] && \
   ! wait_for_url "Qdrant" "http://127.0.0.1:$QDRANT_PORT/"; then
  printf '%s\n' "Inspect logs with: docker compose --profile memory logs --tail=100 qdrant" >&2
  exit 1
fi

if [ "$WITH_QDRANT" = true ]; then
  "$SCRIPT_DIR/check-health.sh" --with-qdrant
else
  "$SCRIPT_DIR/check-health.sh"
fi

cat <<EOF

ForgeLocal AgentOS is ready.

Open WebUI:  http://localhost:$WEBUI_PORT
Ollama API:  http://127.0.0.1:11434
EOF

if [ "$WITH_QDRANT" = true ]; then
  printf 'Qdrant:     http://localhost:%s\n' "$QDRANT_PORT"
fi

if command -v aider >/dev/null 2>&1; then
  cat <<'EOF'

For an editing session, create an agent branch and launch Aider:
  git switch -c agent/short-task-name
  ./aider/aider-start.sh
EOF
else
  cat <<'EOF'

Open WebUI and Ollama are ready. Aider is not installed, so its interactive
coding launcher is unavailable. Install it later using the README instructions.
EOF
fi
