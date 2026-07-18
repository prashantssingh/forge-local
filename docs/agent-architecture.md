# Agent Architecture

## MVP objective

ForgeLocal AgentOS turns agentic coding into a visible sequence of role-specific prompts, Git operations, checks, and reports. The MVP is deliberately a scaffold: shell helpers prepare run artifacts, while a human moves information between roles and decides when the next stage may begin.

It does not run an autonomous control loop, provide an operating-system sandbox, or make model output trustworthy by itself.

## Why sequential agents

Sequential execution fits both the hardware and the risk model:

- One loaded model is realistic on a 16 GB M1 Pro; many concurrent sessions are not.
- One Builder at a time avoids overlapping writes and merge conflicts.
- Each role receives a smaller context and a clear permission boundary.
- Reports create checkpoints a human can inspect or stop.
- Failures are attributable to a stage rather than hidden inside a long autonomous run.

## Conceptual flow

```text
User goal
  -> Orchestrator creates run folder
  -> Planner creates plan
  -> Human approves plan
  -> Builder creates branch and implements
  -> Tester runs checks
  -> Reviewer reviews diff
  -> Builder fixes issues if needed
  -> Memory agent updates logs
  -> Human approves merge
```

The same local Ollama server can serve each turn. Multi-agent describes separation of responsibility, not many resident models.

## Roles and boundaries

| Role | Default access | May write | Commands | Primary output |
|---|---|---|---|---|
| Orchestrator | Read repository | Run reports and approved Markdown memory | Read-only coordination checks | Plan/status/final summary |
| Planner | Read repository | Nothing directly; returns plan text | Read-only inspection when allowed | Proposed run plan |
| Builder | Read and edit approved scope on agent branch | Approved code/docs and run status | Approved safe commands only | Focused branch diff |
| Tester | Read repository and execute checks | Test and status reports | Project-defined finite checks | Test report |
| Reviewer | Read repository and diff | Nothing directly; returns review text | Read-only inspection | Review recommendation |
| Memory | Read reports and memory | Core memory Markdown and memory report | Minimal read-only Git checks | Durable memory update |
| Researcher | Read approved local context | Nothing by default; Orchestrator records findings | Network only after explicit approval | Cited research result |

Planner and Reviewer are read-only even though their returned content eventually appears in reports. The human or Tier 2 Orchestrator records that content in the run folder. This prevents a review role from silently changing the material it reviews.

## Permission tiers

`agents/policies/permissions.yaml` defines:

- **Tier 0:** Read documentation only.
- **Tier 1:** Read the repository and inspect Git state.
- **Tier 2:** Write approved Markdown and run reports.
- **Tier 3:** Modify approved code on an isolated branch.
- **Tier 4:** Run explicit safe commands.
- **Tier 5:** Human approval only.

The YAML is a contract for prompts and future runtimes. V1 shell helpers do not intercept arbitrary commands or enforce macOS permissions. To obtain technical isolation later, run the coding runtime inside a constrained workspace or container with a narrow mount, allowlisted tools, resource limits, and no secrets.

## Read-only and write roles

- **Read-only:** Planner and Reviewer. Researcher is read-only unless a human approves a documentation destination and the Orchestrator records findings.
- **Documentation writers:** Orchestrator for run reports; Memory for the four project-memory files and its report; Tester for test/status reports.
- **Code writer:** Builder only, after plan approval and only on an agent branch.
- **Command runner:** Tester normally; Builder receives Tier 4 only for commands explicitly approved for the task. Other roles use read-only inspection when the operator permits it.

## Human-only actions

Human approval is mandatory for dependency changes, network access, file deletion, migrations, security/auth work, deployment changes, secrets, elevated commands, scope-limit exceptions, push, and merge. Approval must name the action, scope, risk, and rollback.

No agent approves its own work. A Reviewer recommendation of `approve` is evidence for the human, not merge authority.

## Run folders

Each run uses:

```text
agents/runs/YYYY-MM-DD-HHMMSS-short-slug/
  goal.md
  run-plan.md
  run-status.md
  test-report.md
  review-report.md
  memory-update.md
  STOPPED.md       # only when stopped
  run-summary.md   # generated near completion
```

Useful Markdown reports stay in Git. Large logs, temporary process files, and runtime artifacts are ignored. Never store credentials, raw private transcripts, model caches, or databases in a run folder.

## Branch lifecycle

1. The Orchestrator and Planner may prepare run artifacts while the operator is on `main`.
2. A human approves the plan in `run-plan.md`.
3. The human or Builder creates `agent/<run-id>`.
4. All implementation stays on that branch.
5. Tester and Reviewer inspect the branch and its diff from `main`.
6. The Memory role records verified outcomes on the same branch.
7. A human accepts, revises, rejects, or merges locally.
8. Remote push is a separate approval.

Branch isolation supplies a review and recovery boundary. It does not prevent a poorly permissioned command from changing files outside Git, which is why shell and secret restrictions still matter.

## Report lifecycle

- The plan defines authorized scope before edits.
- Status records the current phase, branch, files, commands, and next action.
- Test report includes failures and skipped checks, not just passing results.
- Review report compares the diff to the plan and recommends approve, revise, or reject.
- Memory update records durable knowledge only after evidence exists.
- Summary aggregates reports and unresolved work. It never substitutes for human acceptance.

## Stop and recovery model

`scripts/agent-stop.sh` creates `STOPPED.md`. Roles must check it between stages and return control to the operator. The operator separately interrupts any running terminal process, reviews `git status` and `git diff`, and decides whether to preserve, repair, or abandon the branch.

The repeated-failure limit is three attempts at the same blocking condition. Reaching it produces a report and stop, not a broader attempt with more permissions.

## Future runtime integration

A future OpenHands, LangGraph, AutoGen, or CrewAI adapter should consume the existing profiles, workflows, policies, and report schema rather than replacing them. It must add real enforcement for workspace mounts, command allowlists, network egress, time/resource limits, stop tokens, branch checks, and human approval callbacks before `autopilot.yaml` can be enabled.
