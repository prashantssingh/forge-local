# ForgeLocal Agents

ForgeLocal agents are reusable role prompts, not independent background processes. In the MVP, one human operator gives each role a controlled turn through one local Ollama server. The run folder and Git branch carry state between turns.

## Why role-based agents

A single unrestricted prompt tends to mix planning, implementation, testing, and approval. Separate roles make intent and permissions visible:

- The **Orchestrator** manages the run but does not edit application code.
- The **Planner**, **Reviewer**, and usually the **Researcher** are read-only.
- The **Builder** may modify approved code on an agent branch.
- The **Tester** runs approved safe checks and normally does not edit source.
- The **Memory** agent writes only durable Markdown memory.

Profiles describe expected behavior; `policies/permissions.yaml` maps roles to permission tiers. These are declarative controls in v1. They do not create an operating-system sandbox, so the human must still inspect prompts, commands, diffs, and branch state.

## Why workflows are sequential

An M1 Pro with 16 GB unified memory should not run several heavy model sessions simultaneously. Sequential turns also avoid concurrent edits and make review easier:

1. Orchestrator creates a run.
2. Planner writes a small plan.
3. Human approves or rejects the plan.
4. Builder creates an isolated branch and implements one task.
5. Tester checks the result.
6. Reviewer inspects the diff.
7. Builder fixes approved findings if needed.
8. Memory agent records the outcome.
9. Human decides whether to merge.

## Create a run

```sh
./scripts/agent-run.sh --workflow single-task "Describe one small goal"
```

The command creates a directory such as:

```text
agents/runs/2026-07-17-193000-describe-one-small-goal/
```

Each run receives the goal, plan, status, test, review, and memory templates. Complete reports in place; do not store raw private transcripts or secrets. Run summaries are created with:

```sh
./scripts/summarize-run.sh RUN_ID
```

## Manual approval and branch flow

Planning can happen before a branch is created. Once the plan is approved, create a branch named for the run:

```sh
git switch -c agent/RUN_ID
```

Before accepting the result, inspect:

```sh
git status --short
git diff --stat main...HEAD
git diff main...HEAD
```

Agents never merge or push by default. A human decides whether the reports and diff justify a merge.

## Stop a run

```sh
./scripts/agent-stop.sh RUN_ID "Reason for stopping"
```

This creates `STOPPED.md`. It is an audit and coordination marker, not a process killer. Stop an active terminal process separately with its normal interrupt mechanism.

## Add an agent profile

1. Copy the closest profile in `profiles/`.
2. Give the role one clear purpose.
3. Declare its permission tier, readable inputs, allowed writes, commands, reports, and stop conditions.
4. Add the role mapping to `policies/permissions.yaml`.
5. Reference it only from workflows that need it.
6. Test it first in a documentation-only run.

Avoid combining approval authority with code-writing authority.

## Add a workflow

1. Copy the closest YAML file in `workflows/`.
2. Keep `mode: sequential` for this hardware.
3. Define ordered stages with role, permission tier, allowed writes, approval, report, and stop conditions.
4. Put a human gate before the first code change and before merge or push.
5. Set finite task and file limits.
6. Run it manually and review every artifact before considering automation.

## Read run reports

- `goal.md` is the original request and selected workflow.
- `run-plan.md` contains the proposed tasks, risks, and approvals.
- `run-status.md` is the current checkpoint and branch state.
- `test-report.md` records commands exactly as run and all failures.
- `review-report.md` records plan alignment and a recommendation.
- `memory-update.md` proposes durable memory changes.
- `run-summary.md` aggregates those artifacts but is not approval.

## Safety basics

- Read `policies/safety-rules.md` and `policies/human-approval.md` before every run.
- Never give a role more permission than its current step needs.
- Never provide secrets to a model or save them in a run folder.
- Keep Ollama local, commands visible, and changes on a branch.
- Stop after repeated failure, unexpected file scope, a missing test, or a policy conflict.
- Treat all model output as an untrusted proposal until a human verifies it.
