# ForgeLocal AgentOS TODO

Work from the top, one small item at a time. Do not mark operational checks complete until they have actually succeeded on this Mac.

## Initial onboarding

- [x] Add a one-command bootstrap for safe setup and startup. Completed on 2026-07-18.
- [x] Install Ollama natively on macOS. Homebrew CLI 0.12.8 confirmed at `/opt/homebrew/bin/ollama` on 2026-07-18.
- [ ] Pull the primary and fallback models.
- [ ] Start Open WebUI.
- [ ] Verify local chat works with `qwen2.5-coder:14b`.
- [ ] Install and configure Aider.
- [ ] Run the first project reasoning session.
- [x] Add the first agent profiles. Completed in the initial scaffold on 2026-07-17.
- [ ] Run the first sequential `single-task` workflow.
- [x] Add health checks. Completed in the initial scaffold on 2026-07-17; live results remain pending.

## Later, after the MVP is stable

- [ ] Add optional Qdrant-backed memory only after defining a retrieval use case and privacy boundary.
- [ ] Evaluate OpenHands integration in a disposable branch and constrained workspace.

## Operating rule

When a task is completed, move or mark it here only after its checks pass and add the run ID or log date as evidence.
