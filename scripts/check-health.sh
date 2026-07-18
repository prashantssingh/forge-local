#!/bin/sh

# Check local dependencies, model availability, and service reachability.
set -u

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PROJECT_DIR"

WITH_QDRANT=false
FAILURES=0

usage() {
  cat <<'EOF'
Usage: ./scripts/check-health.sh [--with-qdrant]

Checks Docker, native Ollama, required models, and Open WebUI.
Use --with-qdrant to also require Qdrant to be reachable.
EOF
}

case "${1:-}" in
  --with-qdrant) WITH_QDRANT=true ;;
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

pass() {
  printf 'PASS  %s\n' "$1"
}

fail() {
  printf 'FAIL  %s\n' "$1" >&2
  FAILURES=$((FAILURES + 1))
}

FILE_PRIMARY_MODEL=$(read_env_value PRIMARY_MODEL)
FILE_FALLBACK_MODEL=$(read_env_value FALLBACK_MODEL)
FILE_WEBUI_PORT=$(read_env_value WEBUI_PORT)
FILE_QDRANT_PORT=$(read_env_value QDRANT_PORT)

PRIMARY_MODEL=${PRIMARY_MODEL:-${FILE_PRIMARY_MODEL:-qwen2.5-coder:14b}}
FALLBACK_MODEL=${FALLBACK_MODEL:-${FILE_FALLBACK_MODEL:-qwen2.5-coder:7b}}
WEBUI_PORT=${WEBUI_PORT:-${FILE_WEBUI_PORT:-3000}}
QDRANT_PORT=${QDRANT_PORT:-${FILE_QDRANT_PORT:-6333}}

printf '%s\n' "ForgeLocal AgentOS health check"

if command -v docker >/dev/null 2>&1; then
  pass "Docker CLI is installed"
  if docker info >/dev/null 2>&1; then
    pass "Docker daemon is running"
  else
    fail "Docker daemon is not running"
  fi
else
  fail "Docker CLI is not installed"
fi

if command -v curl >/dev/null 2>&1; then
  pass "curl is installed"
else
  fail "curl is not installed"
fi

OLLAMA_READY=false
if command -v ollama >/dev/null 2>&1; then
  pass "Ollama CLI is installed"
else
  fail "Ollama CLI is not installed"
fi

if command -v curl >/dev/null 2>&1 && \
   curl -fsS --max-time 5 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
  pass "Native Ollama API is responding"
  OLLAMA_READY=true
else
  fail "Native Ollama API is not responding at 127.0.0.1:11434"
fi

if [ "$OLLAMA_READY" = true ] && command -v ollama >/dev/null 2>&1; then
  MODEL_LIST=$(ollama list 2>/dev/null || true)
  if printf '%s\n' "$MODEL_LIST" | awk 'NR > 1 { print $1 }' | grep -Fx "$PRIMARY_MODEL" >/dev/null 2>&1; then
    pass "Primary model is available: $PRIMARY_MODEL"
  else
    fail "Primary model is missing: $PRIMARY_MODEL"
  fi

  if printf '%s\n' "$MODEL_LIST" | awk 'NR > 1 { print $1 }' | grep -Fx "$FALLBACK_MODEL" >/dev/null 2>&1; then
    pass "Fallback model is available: $FALLBACK_MODEL"
  else
    fail "Fallback model is missing: $FALLBACK_MODEL"
  fi
else
  fail "Model availability could not be checked"
fi

if command -v curl >/dev/null 2>&1 && \
   curl -fsS --max-time 5 "http://127.0.0.1:$WEBUI_PORT/" >/dev/null 2>&1; then
  pass "Open WebUI is reachable at http://localhost:$WEBUI_PORT"
else
  fail "Open WebUI is not reachable at http://localhost:$WEBUI_PORT"
fi

if [ "$WITH_QDRANT" = true ]; then
  if command -v curl >/dev/null 2>&1 && \
     curl -fsS --max-time 5 "http://127.0.0.1:$QDRANT_PORT/" >/dev/null 2>&1; then
    pass "Qdrant is reachable at http://localhost:$QDRANT_PORT"
  else
    fail "Qdrant is not reachable at http://localhost:$QDRANT_PORT"
  fi
else
  printf '%s\n' "SKIP  Qdrant is optional; use --with-qdrant to check it"
fi

if [ "$FAILURES" -gt 0 ]; then
  printf '%s\n' "$FAILURES health check(s) failed. See docs/troubleshooting.md." >&2
  exit 1
fi

printf '%s\n' "All requested health checks passed."
