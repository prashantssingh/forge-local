# ForgeLocal AgentOS Project Context

## Project goal

ForgeLocal AgentOS provides a beginner-friendly way to use local/open-source models for project reasoning, coding help, incremental progress, durable memory, and controlled agent workflows on one MacBook Pro. It favors privacy, small diffs, visible commands, Git history, and human decisions over unattended autonomy.

## Architecture

- **Native model server:** Ollama runs directly on macOS and exposes its API at `http://127.0.0.1:11434`.
- **Chat interface:** Open WebUI runs in Docker and reaches host Ollama through `http://host.docker.internal:11434`.
- **Optional vector memory:** Qdrant runs in the Compose `memory` profile and is not required for the MVP.
- **Coding assistant:** Aider uses `ollama_chat/qwen2.5-coder:14b` and includes the four project-memory files in its session.
- **Agent system:** Markdown role profiles and declarative YAML workflows coordinate sequential turns. V1 runner scripts create and manage artifacts but do not invoke agents.
- **Durable state:** Git is the source of truth; Markdown memory records context, decisions, tasks, and work history.
- **Isolation:** Implementation happens on `agent/<run-id>` branches. Humans approve plans, risky actions, acceptance, merge, and push.

## Local hardware constraints

- MacBook Pro 16-inch, 2021
- Apple M1 Pro
- 16 GB unified memory
- macOS Tahoe 26.5.2
- Docker Desktop is suitable for light supporting services, not Metal-accelerated Ollama inference.
- Only one heavy local model workload should run at a time.
- Start with an 8K context target and reduce it when memory pressure or swapping appears.

## Current model choices

- **Primary:** `qwen2.5-coder:14b` for planning, building, and review when quality matters.
- **Fallback:** `qwen2.5-coder:7b` for faster, lighter roles and when the Mac is under pressure.
- **Experimental:** `qwen3-coder:30b` only after explicit opt-in. Its default Ollama artifact is larger than available unified memory before runtime overhead, so it is not part of normal operation.

## Coding and workflow standards

- Work on one small task at a time.
- Inspect before editing and keep diffs narrowly scoped.
- Use repository-defined checks and report failures honestly.
- Do not rewrite unrelated code or change dependencies without approval.
- Record meaningful work in `docs/ai-log.md`.
- Record lasting architecture choices in `docs/ai-decisions.md`, not routine details.
- Keep `docs/ai-todo.md` ordered and actionable.
- Use concise Markdown and portable shell where possible.

## Safety and privacy requirements

- Keep private code, prompts, and model traffic local unless a human approves a named external destination.
- Never give agents secrets, unrestricted shell access, or permission to modify `main`.
- Require human approval for network access, dependency changes, deletion, migrations, security changes, deployment changes, push, and merge.
- Check for a run's `STOPPED.md` marker before each phase.
- Treat model output as an untrusted proposal until a human verifies the files, commands, tests, and diff.

## Known limitations

- V1 policies are declarative and depend on the operator and agent prompts; they are not an OS sandbox.
- The runner helpers do not call Ollama, Aider, OpenHands, or another orchestration framework.
- A stop marker coordinates agents but does not kill operating-system processes.
- Markdown memory has no semantic search or automatic retrieval beyond what is placed in the prompt.
- Open WebUI and Qdrant image tags are intentionally easy to start but not pinned for production reproducibility.
- No Kubernetes, parallel heavy agents, remote execution, auto-merge, or auto-push is included.

## Current project state

The initial scaffold contains Docker Compose configuration, local health and lifecycle scripts, Aider integration, role profiles, policies, workflow definitions, run templates, and operating documentation. Native Ollama CLI 0.12.8 is installed at `/opt/homebrew/bin/ollama`. Its API was not running at the last check, so the bootstrap now falls back to a background native `ollama serve` process when `Ollama.app` is unavailable. Default model downloads, Docker/Open WebUI startup, and live health verification remain pending.

## How agents should use this file

1. Read it before planning or editing.
2. Verify time-sensitive or repository-specific claims against the current files.
3. Treat hardware, privacy, branch, and approval constraints as mandatory.
4. Update it only when durable project context changes.
5. Do not turn session notes into permanent context; put them in `docs/ai-log.md`.
