#!/bin/sh

# Call Ollama's local OpenAI-compatible chat endpoint.
set -eu

if ! command -v curl >/dev/null 2>&1; then
  printf '%s\n' "curl is required." >&2
  exit 1
fi

curl -fsS http://127.0.0.1:11434/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "qwen2.5-coder:14b",
    "messages": [
      {
        "role": "user",
        "content": "Explain the purpose of a README in three short bullets."
      }
    ],
    "stream": false
  }'

printf '\n'
