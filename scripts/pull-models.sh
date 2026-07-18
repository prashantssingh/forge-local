#!/bin/sh

# Pull the default local models. The larger experimental model is opt-in.
set -eu

PRIMARY_MODEL=${PRIMARY_MODEL:-qwen2.5-coder:14b}
FALLBACK_MODEL=${FALLBACK_MODEL:-qwen2.5-coder:7b}
EXPERIMENTAL_MODEL=${EXPERIMENTAL_MODEL:-qwen3-coder:30b}
PULL_EXPERIMENTAL=false

usage() {
  cat <<'EOF'
Usage: ./scripts/pull-models.sh [--experimental]

Pulls qwen2.5-coder:14b and qwen2.5-coder:7b.
Use --experimental to also pull qwen3-coder:30b.
EOF
}

case "${1:-}" in
  --experimental) PULL_EXPERIMENTAL=true ;;
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

if ! command -v ollama >/dev/null 2>&1; then
  printf '%s\n' "Ollama is not installed. Run ./scripts/setup-ollama.sh first." >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1 || \
   ! curl -fsS --max-time 5 http://127.0.0.1:11434/api/tags >/dev/null; then
  printf '%s\n' "Ollama is not responding at http://127.0.0.1:11434." >&2
  printf '%s\n' "Start native Ollama, then retry." >&2
  exit 1
fi

printf '%s\n' "Pulling primary model: $PRIMARY_MODEL"
ollama pull "$PRIMARY_MODEL"

printf '%s\n' "Pulling fallback model: $FALLBACK_MODEL"
ollama pull "$FALLBACK_MODEL"

if [ "$PULL_EXPERIMENTAL" = true ]; then
  printf '%s\n' "Pulling experimental model: $EXPERIMENTAL_MODEL"
  printf '%s\n' "Warning: this model is about 19 GB before runtime overhead and is not a practical default on a 16 GB M1 Pro."
  ollama pull "$EXPERIMENTAL_MODEL"
else
  cat <<EOF

Skipped $EXPERIMENTAL_MODEL.
It is optional and may be too memory-heavy or slow on a 16 GB M1 Pro.
To try it deliberately, run:
  ./scripts/pull-models.sh --experimental
EOF
fi

printf '%s\n' "Model pull step complete."
