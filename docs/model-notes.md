# Local Model Notes

## Default: Qwen2.5-Coder 14B

`qwen2.5-coder:14b` is the primary model because it offers a useful quality step above smaller coding models while remaining barely practical as a quantized model on a 16 GB Apple Silicon machine. Ollama currently lists its default artifact at roughly 9 GB, leaving limited shared memory for context, macOS, Aider, and Docker.

Use it for:

- Planning changes that require repository understanding
- Focused implementation tasks
- Reviewing non-trivial diffs
- Project reasoning where quality matters more than latency

Do not treat 14B as lightweight. Close unnecessary applications, keep context modest, and avoid concurrent heavy sessions.

## Fallback: Qwen2.5-Coder 7B

`qwen2.5-coder:7b` is pulled during normal setup and is the first response to memory pressure or slow iteration. Ollama currently lists its default artifact at roughly 4.7 GB.

Use it for:

- Short documentation or summarization turns
- Simple code questions and small edits
- Fast Planner, Tester, Memory, or Orchestrator passes
- Sessions where Docker and development tools need more headroom
- Troubleshooting when 14B causes swapping

Expect weaker performance on subtle architecture, large diffs, and long-horizon tasks. Smaller scope usually helps more than a longer prompt.

## Experimental: Qwen3-Coder 30B

`qwen3-coder:30b` is not a normal option for this machine. Ollama's default Q4 artifact is roughly 19 GB, already larger than 16 GB unified memory before context cache and runtime overhead. Although it is a mixture-of-experts model with fewer active parameters per token, the weights still need storage and memory management.

The pull script requires:

```sh
./scripts/pull-models.sh --experimental
```

Trying it may cause heavy swapping, long load times, poor responsiveness, or failure. Stop the experiment if memory pressure becomes yellow/red or swap grows quickly.

## Why giant models are unrealistic here

Models such as Kimi K3 and other hundreds-of-billions or trillion-parameter systems are designed for multi-GPU servers, specialized inference clusters, or hosted APIs. Quantization reduces weight memory but does not make models of that class practical on a 16 GB laptop. Offloading enough data to CPU or disk would not create a useful interactive coding system.

Use a smaller local model with tighter tasks instead of chasing server-scale parameter counts.

## Apple Silicon memory guidance

Unified memory is shared by:

- macOS and desktop applications
- Model weights
- Key/value context cache
- Ollama runtime buffers
- Aider, terminals, editors, and Git
- Docker Desktop's Linux VM and containers

The model download size is not the complete runtime requirement. Context length, prompt size, batch behavior, and concurrent processes add memory use.

Useful checks:

```sh
ollama ps
ollama list
```

Also watch Activity Monitor's Memory Pressure and Swap Used fields. Prefer a restart or the 7B fallback over sustained heavy swapping.

## Context-window policy

Large advertised context windows are capacity claims, not recommendations for this laptop. Start around 8K tokens for coding sessions. Reduce file scope or context if the machine swaps. Summarize completed work into project memory rather than carrying an ever-growing conversation.

If starting the server from a terminal, an 8K target can be set with:

```sh
OLLAMA_CONTEXT_LENGTH=8192 ollama serve
```

The Ollama macOS app and clients may apply their own per-request context settings. Confirm actual behavior with current Ollama and client documentation.

## Sequential roles, one model server

Multi-agent means several responsibilities taking turns; it does not require several models resident at once. Reuse one Ollama server and unload or switch models deliberately. Planner, Builder, Tester, Reviewer, and Memory roles should exchange concise run artifacts rather than simultaneous chat sessions.

## References

- [Ollama Qwen2.5-Coder library](https://ollama.com/library/qwen2.5-coder)
- [Ollama Qwen3-Coder library](https://ollama.com/library/qwen3-coder)
- [Aider with Ollama](https://aider.chat/docs/llms/ollama.html)
