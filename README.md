# ForgeLocal AgentOS

ForgeLocal AgentOS is a local-first scaffold for project reasoning, coding assistance, durable project memory, and supervised multi-agent workflows on an Apple Silicon Mac. It combines native Ollama, Docker-hosted Open WebUI, Aider, Markdown memory, Git branches, and manual approval gates.

It is intentionally modest. The first version helps you run safe, observable workflows; it is not a fully autonomous coding platform.

## What it can do

- Serve local coding models through native Ollama.
- Provide a browser chat experience through Open WebUI in Docker.
- Start with Qwen2.5-Coder 14B and fall back to the lighter 7B model.
- Launch Aider with durable project context, decisions, tasks, and history.
- Separate planning, building, testing, reviewing, memory, and research roles.
- Create timestamped run folders with plans, status, test, review, and memory reports.
- Keep implementation work isolated on Git branches.
- Make risky actions and workflow limits explicit.
- Add optional local Qdrant storage later without making it an MVP dependency.

## What it cannot safely do yet

- Enforce an operating-system sandbox around arbitrary agent commands.
- Execute the YAML workflows or call models automatically.
- Guarantee that a model follows a Markdown permission policy.
- Kill a running model or shell process when a stop marker is created.
- Run several heavy agents or models concurrently on this hardware.
- Auto-merge, auto-push, manage secrets, or deploy changes.
- Replace human review of commands, diffs, tests, and reports.

The v1 runner scripts manage artifacts and manual gates only. They never pretend that a folder of prompts is technical isolation or full autonomy.

## Hardware target

This project is designed for:

- MacBook Pro 16-inch, 2021
- Apple M1 Pro
- 16 GB unified memory
- macOS Tahoe 26.5.2

That is a good fit for quantized 7B models and careful 14B use. It is not a large-model server. Keep context near 8K tokens to start, run one heavy model workload at a time, and use the 7B fallback when memory pressure rises.

See [local hardware guidance](docs/local-hardware.md) and [model notes](docs/model-notes.md).

## Why Ollama runs natively

Docker Desktop runs Linux containers inside a virtual machine on macOS. Native Ollama can use the Apple Silicon acceleration path directly; a Linux Ollama container is therefore not the default for this Mac. ForgeLocal expects Ollama at:

```text
http://127.0.0.1:11434
```

There is deliberately no Ollama service in `docker-compose.yml`.

## Why Open WebUI runs in Docker

Open WebUI is a light supporting application compared with the model server. Docker gives it a repeatable lifecycle and a named volume for accounts and settings. From the container, it reaches native Ollama through:

```text
http://host.docker.internal:11434
```

The UI is bound to loopback at `http://localhost:3000` by default. It is not exposed to the local network.

## Model strategy

### Primary: `qwen2.5-coder:14b`

The 14B model is the default for planning, focused implementation, and review. Its quantized Ollama artifact is large enough to use most of this machine's comfortable memory headroom, so keep Docker services light and context modest.

### Fallback: `qwen2.5-coder:7b`

The 7B model is installed during normal setup. Use it for quicker sessions, simpler tasks, memory updates, and any time the Mac begins swapping or feels unresponsive.

### Experimental: `qwen3-coder:30b`

The 30B model is never pulled by default. Its default Ollama artifact is roughly 19 GB before runtime overhead, making it unsuitable for normal use with 16 GB unified memory. The opt-in flag exists for deliberate experimentation, not as an upgrade recommendation.

## Project tree

```text
forge-local/
├── README.md
├── docker-compose.yml
├── .env.example
├── .gitignore
├── scripts/
│   ├── setup-ollama.sh
│   ├── pull-models.sh
│   ├── start-webui.sh
│   ├── stop-webui.sh
│   ├── check-health.sh
│   ├── init-project-memory.sh
│   ├── create-agent-run.sh
│   ├── agent-run.sh
│   ├── agent-status.sh
│   ├── agent-stop.sh
│   └── summarize-run.sh
├── aider/
│   ├── aider-start.sh
│   └── example-aider-prompts.md
├── agents/
│   ├── README.md
│   ├── profiles/
│   │   ├── orchestrator.md
│   │   ├── planner.md
│   │   ├── builder.md
│   │   ├── tester.md
│   │   ├── reviewer.md
│   │   ├── memory.md
│   │   └── researcher.md
│   ├── workflows/
│   │   ├── single-task.yaml
│   │   ├── feature-build.yaml
│   │   ├── bugfix.yaml
│   │   ├── review-only.yaml
│   │   ├── research-only.yaml
│   │   └── autopilot.yaml
│   ├── policies/
│   │   ├── permissions.yaml
│   │   ├── safety-rules.md
│   │   └── human-approval.md
│   ├── templates/
│   │   ├── run-plan.md
│   │   ├── run-status.md
│   │   ├── test-report.md
│   │   ├── review-report.md
│   │   └── memory-update.md
│   └── runs/
│       └── .gitkeep
├── docs/
│   ├── ai-context.md
│   ├── ai-decisions.md
│   ├── ai-todo.md
│   ├── ai-log.md
│   ├── model-notes.md
│   ├── troubleshooting.md
│   ├── agent-architecture.md
│   ├── agent-operating-manual.md
│   └── local-hardware.md
└── examples/
    ├── curl-chat.sh
    ├── project-session-prompt.md
    ├── agent-run-prompt.md
    └── first-agent-task.md
```

## Prerequisites

Install these yourself. Dependency installation and downloads use the network and are not performed by the scaffold.

1. **Git and curl:** included with or available through standard macOS developer tools.
2. **Ollama for macOS:** download from [ollama.com/download/mac](https://ollama.com/download/mac) and run it natively.
3. **Docker Desktop for Mac:** install from [Docker's macOS guide](https://docs.docker.com/desktop/setup/install/mac-install/), then start Docker Desktop.
4. **Aider:** follow [Aider's installation guide](https://aider.chat/docs/install.html). A common official path is:

   ```sh
   python -m pip install aider-install
   aider-install
   ```

Do not give an agent approval to install these on your behalf during the first setup.

## Initial setup

From this project root:

```sh
cp .env.example .env
chmod +x scripts/*.sh aider/*.sh examples/*.sh
./scripts/setup-ollama.sh
./scripts/pull-models.sh
./scripts/start-webui.sh
./scripts/check-health.sh
```

What each step does:

- `.env` holds local overrides and remains ignored by Git.
- `setup-ollama.sh` checks native Ollama; it does not install or start it for you.
- `pull-models.sh` pulls only the 14B primary and 7B fallback.
- `start-webui.sh` starts only Open WebUI and preserves its named volume.
- `check-health.sh` checks Docker, Ollama, both models, and the UI.

If native Ollama is installed but not serving, open the macOS app. To start it manually with an 8K target in a dedicated terminal:

```sh
OLLAMA_CONTEXT_LENGTH=8192 ollama serve
```

Then open [http://localhost:3000](http://localhost:3000). The first local account becomes the Open WebUI administrator; use a strong local password even though the port is loopback-only.

## Optional Qdrant

Qdrant is not required for chat, Aider, Markdown memory, or manual workflows. Start it only when evaluating a specific vector-memory use case:

```sh
./scripts/start-webui.sh --with-qdrant
./scripts/check-health.sh --with-qdrant
```

It is available only at `http://localhost:6333` and stores data in a named volume. The MVP does not configure authentication because it is loopback-only; do not expose this service to a network.

Stop both profile services without deleting volumes:

```sh
./scripts/stop-webui.sh --with-qdrant
```

## Use Ollama directly

Terminal chat:

```sh
ollama run qwen2.5-coder:14b
```

OpenAI-compatible API example:

```sh
./examples/curl-chat.sh
```

Use the fallback when needed:

```sh
ollama run qwen2.5-coder:7b
```

The experimental model requires explicit intent:

```sh
./scripts/pull-models.sh --experimental
```

Read the warning in `docs/model-notes.md` before doing this.

## Use Aider

Check that Git has no unexplained changes, create an isolated branch, and launch:

```sh
git status --short
git switch -c agent/manual-YYYY-MM-DD-small-goal
./aider/aider-start.sh
```

The helper uses:

```sh
aider --model ollama_chat/qwen2.5-coder:14b \
  docs/ai-context.md \
  docs/ai-decisions.md \
  docs/ai-todo.md \
  docs/ai-log.md
```

The helper refuses to start on `main`, `master`, or a detached HEAD. It also verifies Aider, native Ollama, the primary model, and project-memory files.

Those memory files are editable in the Aider session so verified work can update them. Use `/ask` for read-only discussion, inspect all proposed commands, and start with `aider/example-aider-prompts.md`.

To use the fallback for one launch:

```sh
PRIMARY_MODEL=qwen2.5-coder:7b ./aider/aider-start.sh
```

## Project memory

The four core files have separate purposes:

- `docs/ai-context.md`: durable goals, architecture, constraints, and current state.
- `docs/ai-decisions.md`: lasting architecture decisions in ADR form.
- `docs/ai-todo.md`: ordered, verifiable work items.
- `docs/ai-log.md`: concise session history and next steps.

Git history is the audit trail. Agents should summarize verified outcomes instead of copying raw conversations. Recreate missing templates without overwriting existing memory:

```sh
./scripts/init-project-memory.sh
```

`--force` intentionally replaces the four files with starter templates; use it only after reviewing and backing up current memory.

## How agent runs work

A run is a folder of human-readable artifacts. Create one with:

```sh
./scripts/agent-run.sh --workflow single-task "Add one small, testable improvement"
```

The helper:

- Validates the workflow name.
- Creates `agents/runs/YYYY-MM-DD-HHMMSS-short-slug/`.
- Copies the five report templates.
- Records the goal and selected workflow.
- Prints the next Orchestrator prompt and branch command.

It does **not** call Ollama, execute a workflow, create a branch, run tests, approve actions, or merge code.

Check the latest or a named run:

```sh
./scripts/agent-status.sh
./scripts/agent-status.sh RUN_ID
```

Stop coordination for a run:

```sh
./scripts/agent-stop.sh RUN_ID "Reason for stopping"
```

Generate the final aggregate report:

```sh
./scripts/summarize-run.sh RUN_ID
```

Every meaningful run should preserve its completed plan, status, test report, review report, memory update, and summary. A report is evidence, not permission.

## Single-task workflow

The safest first workflow is:

1. Orchestrator reads the goal, memory, policy, and workflow.
2. Planner inspects relevant files and returns a small plan.
3. Human records approval in `run-plan.md`.
4. Builder works on `agent/<run-id>` and implements one task.
5. Tester records exact checks and all failures.
6. Reviewer returns `approve`, `revise`, or `reject` without editing files.
7. Memory agent records only verified outcomes.
8. Human reviews the diff and decides whether to accept locally.
9. Merge and remote push remain separate human approvals.

See `docs/agent-operating-manual.md` for exact instructions.

## Evolve into multi-agent workflows

Use several roles as controlled sequential turns through one model server. Do not start multiple heavy models or let multiple Builders edit concurrently.

Available workflows:

- `single-task`: one small implementation.
- `feature-build`: at most three independently reviewed tasks by default.
- `bugfix`: reproduce, diagnose, fix, regression-test, review.
- `review-only`: read a diff and return findings without source edits.
- `research-only`: answer one question; network access requires approval.
- `autopilot`: future policy scaffold, disabled and not executable in v1.

## Git branch isolation

Git is the source of truth. Agent implementation never happens on `main`.

After the plan is approved:

```sh
git status --short
git switch -c agent/RUN_ID
```

Before acceptance:

```sh
git status --short
git diff --stat main...HEAD
git diff --check main...HEAD
git diff main...HEAD
```

If the result is unsafe or wrong, stop the run and switch back to `main` without merging. Keep the branch until you have decided whether any work must be recovered.

## Safety gates

Human approval is required before:

- Dependency installation, removal, or upgrades
- External network access or downloads
- File deletion, rename, truncation, or overwrite
- Database and storage migrations
- Authentication, authorization, cryptography, or security changes
- Deployment, CI/CD, infrastructure, or production configuration changes
- Secret or credential access
- Elevated commands
- Exceeding task or file limits
- Remote push, publication, merge, or protected-branch changes

Blocked commands and actions are listed in `agents/policies/permissions.yaml`. V1 relies on the operator to enforce them. Do not give a local model unrestricted shell or home-directory access.

## Daily usage

Typical start:

```sh
ollama run qwen2.5-coder:14b
./scripts/start-webui.sh
./aider/aider-start.sh
```

Before agent implementation:

```sh
git status --short
git switch -c agent/short-task-name
```

At the end of every meaningful session:

```sh
git status --short
git diff
```

Then update `docs/ai-log.md` with the goal, changes, commands, checks, decisions, problems, and next steps. Stop the UI when finished:

```sh
./scripts/stop-webui.sh
```

## First successful run checklist

- [ ] Ollama is installed natively, not in Docker.
- [ ] `./scripts/setup-ollama.sh` reports the API is responding.
- [ ] `ollama list` contains `qwen2.5-coder:14b` and `qwen2.5-coder:7b`.
- [ ] `./scripts/start-webui.sh` starts the container.
- [ ] `./scripts/check-health.sh` passes every required check.
- [ ] Open WebUI opens at `http://localhost:3000`.
- [ ] Open WebUI lists both local models.
- [ ] A short prompt to the 14B model returns a useful response.
- [ ] `./examples/curl-chat.sh` returns JSON from the local model.
- [ ] Aider is installed and `./aider/aider-start.sh` reaches Ollama.
- [ ] Activity Monitor shows acceptable memory pressure during a short session.
- [ ] `docs/ai-log.md` records the successful setup and any deviations.

## First agent run checklist

- [ ] Read `agents/policies/safety-rules.md` and `agents/policies/human-approval.md`.
- [ ] Run `./scripts/agent-run.sh --workflow single-task "Verify the scaffold documentation"`.
- [ ] Copy the returned run ID.
- [ ] Use `examples/first-agent-task.md` as the bounded goal.
- [ ] Have the Planner return a plan without editing files.
- [ ] Review and record human plan approval.
- [ ] Create `agent/<run-id>`; confirm the branch is not `main`.
- [ ] Give the Builder one documentation-only task.
- [ ] Have Tester record safe checks in `test-report.md`.
- [ ] Have Reviewer inspect the diff without modifying it.
- [ ] Accept, revise, or reject the result yourself.
- [ ] Have Memory update `docs/ai-log.md` and `docs/ai-todo.md` truthfully.
- [ ] Generate and inspect `run-summary.md`.
- [ ] Review the full Git diff before any merge.

## Troubleshooting quick start

```sh
./scripts/check-health.sh
docker compose ps
docker compose logs --tail=100 open-webui
ollama list
ollama ps
```

Common problems—including Docker-to-Ollama connectivity, swapping, model fallback, Aider connection errors, stuck workflows, excessive changes, and branch recovery—are covered in [troubleshooting](docs/troubleshooting.md).

## Future evolution

Evolve only after the manual workflow is boring, repeatable, and well tested.

### Qdrant

Define what needs semantic retrieval, an embedding model, collection lifecycle, deletion policy, and privacy boundary. Keep Markdown and Git as the canonical memory; use Qdrant as a rebuildable index rather than the sole source of truth.

### OpenHands

Run it later in a disposable, narrowly mounted workspace with no secrets, network disabled by default, resource limits, an allowlisted command set, and mandatory branch checks. Map its events into the existing run reports and approval gates.

### LangGraph

LangGraph is a natural fit when you want a state machine that implements the existing sequential YAML stages. Persist explicit state, stop before every human gate, and make the `STOPPED.md` state terminal until human recovery.

### AutoGen or CrewAI

Use them as role-message coordinators, not as permission systems. Keep a single active local model call, one Builder, finite turns, and external enforcement around tools and paths.

### Runtime hardening

Before enabling any automated loop, add:

- Workspace-level filesystem isolation
- Command and path allowlists enforced outside prompts
- Default-deny network egress
- CPU, memory, time, task, and file limits
- Programmatic protected-branch checks
- Durable event and approval logs
- Disposable-repository tests for failure and recovery

`agents/workflows/autopilot.yaml` remains disabled until those controls exist.

## Safety reminder

Local does not automatically mean safe. A local model can still delete files, expose secrets, consume all memory, or make plausible but incorrect changes. Keep agents on branches, show every command, review every diff, preserve reports, and stop whenever scope or behavior becomes surprising.

The goal of ForgeLocal AgentOS is controlled progress—not maximum autonomy.
