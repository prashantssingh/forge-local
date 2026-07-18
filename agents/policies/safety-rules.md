# Agent Safety Rules

These rules apply to every ForgeLocal run. V1 enforcement is primarily procedural: prompts, scripts, Git, reports, and human review. They do not replace an operating-system sandbox.

## Mandatory rules

1. **Work on branches.** Planning may be recorded before branch creation, but all implementation must occur on an approved non-`main` branch.
2. **Keep changes small.** Perform one approved task at a time and stay within `AGENT_MAX_FILES_CHANGED`.
3. **Check the stop marker.** Stop before each phase when the run contains `STOPPED.md`.
4. **Ask before dependency changes.** Installation, upgrades, lockfile churn, and new services require human approval.
5. **Ask before deletion.** Do not delete, rename, truncate, or overwrite files without approval and a rollback plan.
6. **Ask before network access.** State the destination, purpose, data sent, and expected result first.
7. **Ask before migrations.** Schema and persistent-data changes require backups, rollback, and approval.
8. **Never access secrets.** Do not inspect environment secrets, keychains, credential stores, SSH files, tokens, or unrelated private data.
9. **Never push or merge by default.** A human approves remote pushes and merges after reviewing the diff and reports.
10. **Use finite commands.** Prefer repository scripts; avoid destructive, recursive, privileged, hidden, or unbounded commands.
11. **Stop after repeated failure.** After three attempts with the same blocking condition, record the failure and return control to the human.
12. **Report honestly.** Every run records scope, files, commands, failures, tests, review, memory updates, and unresolved work.

## Before any edit

- Read the user goal, approved plan, project memory, and relevant policy.
- Confirm the current branch is not `main`.
- Confirm no stop marker exists.
- Confirm the exact task, file scope, and approval state.
- Inspect relevant files before proposing a patch.

## Before any command

- Show the exact command and explain why it is needed.
- Confirm it is allowed by the role and workflow.
- Check that it cannot expose secrets or mutate unrelated state.
- Prefer a dry run or read-only check when available.
- Set a reasonable scope and timeout.

## Stop immediately when

- A requested action conflicts with policy.
- The current branch is protected.
- A secret or unexpected private file appears.
- The diff touches unapproved files or exceeds limits.
- Tests reveal data-loss, security, or migration risk.
- The machine begins heavy swapping or becomes unstable.
- The human asks to stop or a stop marker appears.

Stopping is a successful safety outcome. Record what happened and the exact decision needed next.
