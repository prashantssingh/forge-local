#!/bin/sh

# Start Open WebUI and, when requested, optional Qdrant memory.
set -eu

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PROJECT_DIR"

WITH_QDRANT=false

usage() {
  cat <<'EOF'
Usage: ./scripts/start-webui.sh [--with-qdrant]

Starts Open WebUI. Use --with-qdrant to also enable optional vector memory.
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

if ! command -v docker >/dev/null 2>&1; then
  printf '%s\n' "Docker is not installed. Install and start Docker Desktop first." >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  printf '%s\n' "Docker is installed but its daemon is not running." >&2
  exit 1
fi

compose() {
  if [ -f .env ]; then
    docker compose --env-file .env "$@"
  else
    docker compose --env-file .env.example "$@"
  fi
}

read_env_value() {
  ENV_NAME=$1
  ENV_SOURCE=.env
  [ -f "$ENV_SOURCE" ] || ENV_SOURCE=.env.example
  awk -v name="$ENV_NAME" 'index($0, name "=") == 1 { sub(/^[^=]*=/, ""); print; exit }' "$ENV_SOURCE"
}

FILE_WEBUI_PORT=$(read_env_value WEBUI_PORT)
WEBUI_PORT=${WEBUI_PORT:-${FILE_WEBUI_PORT:-3000}}

if [ "$WITH_QDRANT" = true ]; then
  compose --profile memory up -d
  printf '%s\n' "Open WebUI and optional Qdrant are starting."
else
  compose up -d open-webui
  printf '%s\n' "Open WebUI is starting. Qdrant remains disabled."
fi

cat <<EOF
Open WebUI: http://localhost:$WEBUI_PORT

Ollama must remain running natively on macOS at http://127.0.0.1:11434.
Run ./scripts/check-health.sh after the container finishes starting.
EOF
