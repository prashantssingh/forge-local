# ForgeLocal Brain

One strong local reasoning service for every project.

ForgeLocal Brain does four things:

1. Runs the strongest model that is genuinely feasible on this 16 GB M1 Pro.
2. Stores and retrieves per-project progress, decisions, context, and analysis.
3. Exposes a local HTTP API for ad hoc analysis from other applications.
4. Uses bounded sequential sub-agents when a problem benefits from multiple perspectives.

That is the entire product. There is no coding assistant, Docker stack, web UI, vector database, workflow library, or prompt-template hierarchy.

## Architecture

```text
Other local apps
      |
      v
ForgeLocal Brain API :8080
      |-- retrieve relevant + recent project memory
      |-- direct reasoning, or sequential sub-agent team
      |-- persist the final analysis automatically
      v
Native Ollama :11434 -> gpt-oss:20b

Durable memory -> data/projects/<project_id>/memory.jsonl
```

Every model call is serialized. Team mode means several focused reasoning turns through the same loaded model—not several 14 GB models competing for memory.

## Why `gpt-oss:20b`

This repository standardizes on one model: `gpt-oss:20b`.

- OpenAI describes it as a strong open-weight reasoning and agentic model designed to run with 16 GB of memory.
- Ollama's official artifact is about 14 GB and supports configurable low, medium, or high reasoning effort.
- The 120B model needs roughly 65–80 GB and is not a local option for this Mac.

ForgeLocal uses high reasoning effort and an 8K working context by default. The model advertises a much larger context, but using it would be irresponsible on a 16 GB machine. If memory pressure is high, set `BRAIN_CONTEXT_SIZE=4096`.

Sources: [OpenAI gpt-oss announcement](https://openai.com/index/introducing-gpt-oss/), [Ollama gpt-oss model](https://ollama.com/library/gpt-oss), [Ollama thinking API](https://docs.ollama.com/capabilities/thinking).

## Requirements

- macOS with native Ollama available as the `ollama` command
- Go 1.22 or newer
- `curl`
- About 14 GB of free disk space for the model

Ollama runs natively, never in Docker.

## Run it

```sh
./scripts/run.sh
```

On the first run, the script:

- Creates `.env` from `.env.example` if needed.
- Starts native `ollama serve` if the API is stopped.
- Pulls `gpt-oss:20b` if missing.
- Starts ForgeLocal Brain at `http://127.0.0.1:8080`.

Keep that terminal open. Press `Control-C` to stop the Brain API. Ollama may remain running so the next start is faster.

Check it:

```sh
curl -s http://127.0.0.1:8080/health
```

## Analyze something

Direct mode uses the central model once, with relevant project memory:

```sh
curl -s http://127.0.0.1:8080/v1/analyze \
  -H 'Content-Type: application/json' \
  -d '{
    "project_id": "my-project",
    "prompt": "Evaluate the main architectural risk and recommend the next decision."
  }'
```

You may supply transient context without saving it separately:

```json
{
  "project_id": "my-project",
  "prompt": "Analyze these results and recommend the next experiment.",
  "context": "Paste the relevant metrics or project facts here."
}
```

Every successful analysis is automatically appended to that project's memory.

## Use sub-agents

Team mode asks the central brain to choose distinct expert perspectives, runs those sub-agents sequentially, then synthesizes their findings:

```sh
curl -s http://127.0.0.1:8080/v1/analyze \
  -H 'Content-Type: application/json' \
  -d '{
    "project_id": "my-project",
    "mode": "team",
    "max_agents": 3,
    "prompt": "Stress-test this business plan from technical, market, and execution perspectives."
  }'
```

The response includes each sub-agent's name, focus, finding, and the synthesized answer. The configured maximum is five; the default is three.

Sub-agents reason only. They do not receive shell, filesystem, network, or code-editing tools.

## Record progress and decisions

Add durable memory explicitly:

```sh
curl -s http://127.0.0.1:8080/v1/memory \
  -H 'Content-Type: application/json' \
  -d '{
    "project_id": "my-project",
    "kind": "progress",
    "content": "Validated the pricing assumption; retention remains untested.",
    "tags": ["validation", "next-step"]
  }'
```

Memory kinds are:

- `context`: durable facts and constraints
- `progress`: work completed and current state
- `decision`: choices and rationale
- `analysis`: automatically stored Brain results

## Retrieve continuity

Get the latest memory:

```sh
curl -s 'http://127.0.0.1:8080/v1/memory?project_id=my-project&limit=10'
```

Search memory lexically:

```sh
curl -s 'http://127.0.0.1:8080/v1/memory?project_id=my-project&q=pricing+retention&limit=10'
```

List projects with memory:

```sh
curl -s http://127.0.0.1:8080/v1/projects
```

For every analysis, ForgeLocal retrieves relevant matches plus recent entries. This gives continuity even when the caller provides only a project ID and a new question.

## API

| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `/health` | Ollama and Brain configuration status |
| `POST` | `/v1/analyze` | Direct or team reasoning with automatic memory |
| `POST` | `/v1/memory` | Save context, progress, or decisions |
| `GET` | `/v1/memory` | Retrieve recent or matching project memory |
| `GET` | `/v1/projects` | List known project IDs |

Requests and responses are JSON. Analysis requests are serialized because one loaded model is the correct concurrency model for this hardware.

## Configuration

Copy and edit `.env.example`, or let `scripts/run.sh` create `.env` automatically.

| Variable | Default | Meaning |
|---|---|---|
| `BRAIN_ADDRESS` | `127.0.0.1:8080` | Brain API bind address |
| `OLLAMA_URL` | `http://127.0.0.1:11434` | Native Ollama API |
| `BRAIN_MODEL` | `gpt-oss:20b` | The single local model |
| `BRAIN_CONTEXT_SIZE` | `8192` | Working context; use `4096` under pressure |
| `BRAIN_REASONING` | `high` | `low`, `medium`, or `high` |
| `BRAIN_DATA_DIR` | `./data` | Durable memory root |
| `BRAIN_MEMORY_ITEMS` | `8` | Memory records supplied per analysis |
| `BRAIN_MAX_AGENTS` | `3` | Maximum sequential sub-agents, up to five |
| `BRAIN_API_KEY` | empty | Optional local API authentication |

The API refuses to bind off loopback unless `BRAIN_API_KEY` is set. When set, callers must send either:

```text
Authorization: Bearer <key>
```

or:

```text
X-API-Key: <key>
```

## Memory ownership

Memory is append-only JSON Lines under `data/projects/`. It is deliberately simple, inspectable, and local. The directory is ignored by Git because it may contain private project information.

Back it up like any other local data:

```sh
cp -R data ../forge-local-data-backup
```

If a JSONL file is corrupted, ForgeLocal fails loudly rather than silently discarding continuity.

## Test

Tests use a fake Ollama server; they do not load the real model:

```sh
go test ./...
```

The test suite covers persistent retrieval, unsafe project IDs, direct analysis, automatic memory, team orchestration, and API authentication.

## Files

```text
forge-local/
├── README.md
├── .env.example
├── .gitignore
├── go.mod
├── main.go
├── config.go
├── memory.go
├── ollama.go
├── brain.go
├── server.go
├── memory_test.go
├── server_test.go
├── scripts/
│   └── run.sh
└── data/
    └── .gitkeep
```
