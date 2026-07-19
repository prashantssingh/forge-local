# Agent Operating Manual

## Operating principle

ForgeLocal AgentOS is a supervised workflow. You remain the operator, approver, and merge authority. The model proposes; Git, tests, reports, and your review determine what is accepted.

## Start a normal local AI session

For the normal full-stack path, run:

```sh
./scripts/bootstrap.sh
```

It verifies or starts installed local services, pulls missing default models, starts Open WebUI, waits for readiness, and runs health checks. It does not launch an interactive Aider session.

To operate each layer manually instead:

1. Open the native Ollama macOS app, or start the server in a terminal:

   ```sh
   OLLAMA_CONTEXT_LENGTH=8192 ollama serve
   ```

2. Check the stack:

   ```sh
   ./scripts/check-health.sh
   ```

3. Use a direct terminal chat:

   ```sh
   ollama run qwen2.5-coder:14b
   ```

4. Or start the local browser UI:

   ```sh
   ./scripts/start-webui.sh
   ```

5. Begin with `examples/project-session-prompt.md`. Keep the request to one small task and ask for a plan before edits.

## Run Aider

Before an editing session, create a branch:

```sh
git status --short
git switch -c agent/manual-YYYY-MM-DD-short-goal
./aider/aider-start.sh
```

The helper verifies the Git branch, Aider, native Ollama, the primary model, and project-memory files. It refuses to start on `main`, `master`, or a detached HEAD, then adds the four memory files to the session. Aider starts in its normal editing mode, so use `/ask` for read-only questions and inspect every proposed shell command.

Inside Aider:

- Use one prompt from `aider/example-aider-prompts.md`.
- Add only files needed for the current task.
- Keep the diff below the configured file limit.
- Run checks before finishing.
- Update `docs/ai-log.md` after verified work.

## Start a manual single-task workflow

```sh
./scripts/agent-run.sh --workflow single-task "Describe one small outcome"
```

The script creates a run folder and prints the Orchestrator prompt. It does not call a model, create a branch, approve a plan, or execute commands.

If creating artifacts separately:

```sh
./scripts/create-agent-run.sh --workflow single-task "Describe one small outcome"
```

Copy the returned run ID for the rest of the session.

## Complete and approve a plan

1. Give the Orchestrator prompt to the local model.
2. Have the read-only Planner inspect relevant files and return a decision-complete plan.
3. Record the proposal in `agents/runs/RUN_ID/run-plan.md`.
4. Verify success criteria, file scope, checks, rollback, limits, and risky actions.
5. Set the approval record to `Approved`, with your name, timestamp, and exact approved scope.
6. If the plan is too large, reject it and create a smaller run.

Approval of a plan is not approval for network access, dependency changes, deletion, migration, push, or merge. Record those separately when needed.

## Create the Builder branch

Only after plan approval:

```sh
git status --short
git switch -c agent/RUN_ID
git branch --show-current
```

Do not start building if there are unexplained changes or if the current branch is `main`.

Give the Builder exactly one approved task, its file boundary, and the permitted checks. Update `run-status.md` as the task progresses.

## Test the result

Give the Tester the plan, diff, and project-defined check commands. It should run the narrowest check first and fill `test-report.md` with:

- Exact commands
- Exit statuses
- Passes and failures
- Skipped checks and reasons
- Environment limitations
- Recommended next step

A check that could not run is not a pass.

## Inspect the diff

Use read-only Git commands:

```sh
git status --short
git diff --stat main...HEAD
git diff --check main...HEAD
git diff main...HEAD
```

Confirm that:

- Every changed file belongs to the approved task.
- The file count is within the limit.
- No secrets, generated junk, or unrelated formatting appeared.
- Tests cover the changed behavior.
- Documentation and memory are accurate.

Give the same evidence to the read-only Reviewer. The human or Orchestrator records its recommendation in `review-report.md`.

## Accept, revise, or reject

### Accept locally

Accept only when the diff matches the plan, checks are adequate, the Reviewer has no blocking finding, and memory is accurate. A local commit is still not permission to push or merge.

### Revise

Record each approved finding as a small Builder task. After fixes, rerun the relevant Tester checks and Reviewer pass. Do not silently broaden the original plan.

### Reject

Record why the result was rejected. Preserve the run reports. Switch back to `main` without merging. Keep the branch until you are certain no work needs recovery.

## Update project memory

After verified work, give the Memory role the reports and final disposition. It may update only:

- `docs/ai-context.md` for durable project context
- `docs/ai-decisions.md` for meaningful architecture/workflow choices
- `docs/ai-todo.md` for verified task status and next steps
- `docs/ai-log.md` for the concise session record
- The run's `memory-update.md`

Do not mark rejected, untested, or incomplete work as complete. Then generate the aggregate report:

```sh
./scripts/summarize-run.sh RUN_ID
```

Review the generated summary; its existence is not approval.

## Stop an unsafe run

1. Interrupt the active command in its terminal, normally with `Control-C`.
2. Create the coordination marker:

   ```sh
   ./scripts/agent-stop.sh RUN_ID "Unexpected file scope"
   ```

3. Inspect status and diff:

   ```sh
   ./scripts/agent-status.sh RUN_ID
   git status --short
   git diff
   ```

4. Do not delete the stop marker or resume until you have a new explicit plan.

The helper does not kill processes. Stop Ollama, Aider, or Docker through the terminal or lifecycle command that started it.

## Recover from a bad branch

First preserve evidence:

```sh
git status --short
git diff --stat
git diff
```

If useful changes exist, commit them on the agent branch or copy only the approved patch to a safe location. To abandon the branch without modifying `main`:

```sh
git switch main
git branch --list 'agent/*'
```

Leave the rejected branch in place until you have verified `main` and the run reports. Deleting a branch is destructive and requires a deliberate human decision. See `docs/troubleshooting.md` for recovery options.

## Normal end-of-day routine

```sh
git status --short
./scripts/agent-status.sh
./scripts/stop-webui.sh
```

If Qdrant was started, stop the matching profile:

```sh
./scripts/stop-webui.sh --with-qdrant
```

Update `docs/ai-log.md` with verified work and next steps before ending the session.

## Use autopilot safely later

`agents/workflows/autopilot.yaml` is disabled and no v1 script executes it. Do not enable it merely by changing `enabled: false`.

Before any automated loop, add:

- A constrained runtime workspace with no home-directory or secret mounts
- Command and path allowlists enforced outside the model
- Network egress disabled by default
- Resource, time, task, and file limits
- Programmatic branch protection and stop checks
- Durable event logs and approval callbacks
- A disposable-repository test suite with failure injection

Start with one pre-approved documentation task. Keep continuation between tasks behind a human gate.
