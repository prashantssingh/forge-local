# Local Hardware Profile

## Machine

- **Computer:** MacBook Pro 16-inch, 2021
- **Chip:** Apple M1 Pro
- **Memory:** 16 GB unified memory
- **Operating system:** macOS Tahoe 26.5.2

## What this machine is good at

- Interactive use of quantized 7B coding models
- Careful use of a quantized 14B model with modest context
- One local inference workload at a time
- A light Docker Desktop stack such as Open WebUI and optional single-node Qdrant
- Sequential planning, building, testing, reviewing, and memory turns
- Private repository work that stays on the laptop

## What this machine is not good at

- Giant models intended for server GPUs
- A 19 GB model plus comfortable runtime headroom
- Several heavy local agents or models in parallel
- Huge context windows with many repository files
- Kubernetes or a large container platform
- Running Ollama in a Docker Linux VM and expecting Apple Metal acceleration

## Runtime choices

Run Ollama natively so it can use the Apple Silicon execution path. Run Open WebUI in Docker because it is a supporting application with modest resource needs. Keep Qdrant disabled until a real vector-memory use case exists.

Recommended role assignment:

| Role | Normal model | Lighter option |
|---|---|---|
| Orchestrator | 7B | 7B |
| Planner | 14B | 7B for simple tasks |
| Builder | 14B | 7B for tiny edits |
| Tester | 7B | 7B |
| Reviewer | 14B | 7B for small diffs |
| Memory | 7B | 7B |
| Researcher | 7B or 14B | Based on question complexity |

These are guidance, not simultaneous allocations. Give roles sequential turns through the same Ollama server.

## Resource habits

- Start around an 8K context target.
- Add only relevant files to Aider.
- Close unused model sessions and heavy applications.
- Watch Activity Monitor memory pressure and swap.
- Use `ollama ps` to see loaded models.
- Switch to `qwen2.5-coder:7b` at the first sign of sustained swapping.
- Stop Qdrant when it is not being evaluated.
- Keep Docker Desktop's memory allocation conservative while still allowing Open WebUI to run.

## Privacy boundary

Native Ollama, Open WebUI, Aider, Git, Markdown memory, and optional Qdrant can all operate locally. Internet access is still needed initially to download applications, container images, Python packages, and models. After setup, do not assume a tool is offline merely because the model is local; inspect its configuration and approve external access deliberately.
