#!/bin/sh

# Stop Compose services without deleting their persistent volumes.
set -eu

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PROJECT_DIR"

WITH_QDRANT=false

usage() {
  cat <<'EOF'
Usage: ./scripts/stop-webui.sh [--with-qdrant]

Stops Open WebUI. Pass --with-qdrant if the memory profile was started.
Named volumes are preserved.
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
  printf '%s\n' "Docker is not installed." >&2
  exit 1
fi

compose() {
  if [ -f .env ]; then
    docker compose --env-file .env "$@"
  else
    docker compose --env-file .env.example "$@"
  fi
}

if [ "$WITH_QDRANT" = true ]; then
  compose --profile memory down
else
  compose down
fi

printf '%s\n' "ForgeLocal Docker services stopped. Persistent volumes were kept."
