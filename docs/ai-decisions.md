# ForgeLocal AgentOS Architecture Decisions

This file uses lightweight Architecture Decision Records (ADRs). Append new accepted decisions; do not rewrite history. Mark superseded decisions and link their replacements.

## ADR-001: Run Ollama natively on macOS

- **Date:** 2026-07-17
- **Status:** Accepted
- **Context:** Docker Desktop runs Linux virtual machines on macOS and does not expose Apple Metal acceleration to a Linux Ollama container in the way native Ollama can use it.
- **Decision:** Install and run Ollama directly on macOS at `127.0.0.1:11434`.
- **Consequences:** Local inference can use Apple Silicon acceleration. Docker services connect through `host.docker.internal`; Ollama lifecycle remains separate from Compose.

## ADR-002: Run Open WebUI in Docker

- **Date:** 2026-07-17
- **Status:** Accepted
- **Context:** The chat UI benefits from an isolated, repeatable service with persistent application data.
- **Decision:** Run `ghcr.io/open-webui/open-webui:main` under Docker Compose with a named volume and loopback-only host port.
- **Consequences:** Open WebUI is easy to start and stop without moving model inference into Docker. Updates to the moving `main` tag must be reviewed deliberately.

## ADR-003: Use Qwen2.5-Coder 14B as the primary model

- **Date:** 2026-07-17
- **Status:** Accepted
- **Context:** The system needs useful code reasoning while remaining plausible on 16 GB unified memory.
- **Decision:** Use `qwen2.5-coder:14b` for normal planning, building, and review.
- **Consequences:** It offers better capability than the 7B fallback but leaves limited headroom. Keep context modest and supporting services light.

## ADR-004: Keep Qwen2.5-Coder 7B as the fallback

- **Date:** 2026-07-17
- **Status:** Accepted
- **Context:** Some sessions prioritize responsiveness or need more memory headroom.
- **Decision:** Pull `qwen2.5-coder:7b` during normal setup and use it for lighter roles or degraded conditions.
- **Consequences:** Responses are faster and memory use is lower, with a possible quality tradeoff on complex tasks.

## ADR-005: Treat Qwen3-Coder 30B as experimental

- **Date:** 2026-07-17
- **Status:** Accepted
- **Context:** The Ollama Q4 artifact is about 19 GB before context and runtime overhead, which exceeds the machine's 16 GB unified memory.
- **Decision:** Never pull `qwen3-coder:30b` by default. Require the explicit `--experimental` flag and warn about swapping and poor performance.
- **Consequences:** The default setup stays realistic. Experimentation remains possible but unsupported for normal use on this machine.

## ADR-006: Use Markdown and Git as durable project memory

- **Date:** 2026-07-17
- **Status:** Accepted
- **Context:** The MVP needs transparent, portable memory without requiring a database or cloud service.
- **Decision:** Store context, decisions, tasks, and session summaries in `docs/ai-*.md`, with Git history as the audit trail.
- **Consequences:** Memory is human-readable and reviewable. Agents must summarize carefully, and semantic retrieval remains a later option.

## ADR-007: Use sequential multi-agent workflows first

- **Date:** 2026-07-17
- **Status:** Accepted
- **Context:** Concurrent model sessions and simultaneous code edits create memory pressure, conflicts, and weak observability on local hardware.
- **Decision:** Give Orchestrator, Planner, Builder, Tester, Reviewer, Memory, and Researcher controlled turns through one local model server.
- **Consequences:** Runs are slower than parallel execution but easier to inspect, stop, and recover.

## ADR-008: Require human approval for risky actions

- **Date:** 2026-07-17
- **Status:** Accepted
- **Context:** Local agents can still damage files, leak data, or make costly changes when given broad permissions.
- **Decision:** Require recorded approval before dependency changes, network access, deletion, migrations, security work, deployment changes, secrets, push, merge, or scope-limit exceptions.
- **Consequences:** V1 is semi-manual by design. Safety and accountability take priority over speed.

## ADR-009: Isolate agent modifications on Git branches

- **Date:** 2026-07-17
- **Status:** Accepted
- **Context:** Implementation needs a simple rollback and review boundary.
- **Decision:** Builders work on `agent/<run-id>` or another approved non-`main` branch. Agents do not modify, merge into, or push `main` directly.
- **Consequences:** Every code change has a reviewable diff and can be abandoned safely. Humans remain responsible for final merge and remote operations.
