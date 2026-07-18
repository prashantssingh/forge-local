#!/bin/sh

# Verify that the native macOS Ollama installation is ready.
set -eu

usage() {
  cat <<'EOF'
Usage: ./scripts/setup-ollama.sh

Checks for a native Ollama installation and verifies the local API.
This script does not install Ollama or run it in Docker.
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

printf '%s\n' "ForgeLocal AgentOS: checking native Ollama..."

if ! command -v ollama >/dev/null 2>&1; then
  cat >&2 <<'EOF'
Ollama is not installed or is not on PATH.

Install Ollama for macOS from:
  https://ollama.com/download/mac

Keep Ollama native on macOS so Apple Metal acceleration is available.
After installation, open the Ollama app or run `ollama serve`, then retry.
EOF
  exit 1
fi

printf 'Found Ollama: '
ollama --version 2>/dev/null || printf '%s\n' "version unavailable"

if ! command -v curl >/dev/null 2>&1; then
  printf '%s\n' "curl is required for the API health check." >&2
  exit 1
fi

if curl -fsS --max-time 5 http://127.0.0.1:11434/api/tags >/dev/null; then
  cat <<'EOF'
Ollama is responding at http://127.0.0.1:11434.

Next steps:
  ./scripts/pull-models.sh
  ./scripts/start-webui.sh
  ./scripts/check-health.sh
EOF
else
  cat >&2 <<'EOF'
Ollama is installed but its API is not responding.

Open the Ollama macOS app, or start it in another terminal with:
  OLLAMA_CONTEXT_LENGTH=8192 ollama serve

Then rerun this check. Do not move Ollama into Docker on macOS.
EOF
  exit 1
fi
