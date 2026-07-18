# Example Aider Prompts

Use these prompts one at a time. Confirm that you are on an isolated branch before asking Aider to edit files.

## Prompt 1 — First TODO

> Read docs/ai-context.md and docs/ai-todo.md. Pick the first TODO. Make the smallest safe change. Update docs/ai-log.md when finished. Update docs/ai-decisions.md only if an architectural decision was made.

## Prompt 2 — Suggest only

> Review the current repository structure. Suggest a small next improvement. Do not make changes yet. Explain tradeoffs.

## Prompt 3 — Implement one item

> Implement the next TODO item. Keep the diff small. Run relevant checks if possible. Summarize what changed and update the project log.

## Prompt 4 — Plan before editing

> Before changing code, inspect the files involved and explain your plan. Wait for confirmation if the change is large.

## Prompt 5 — Read-only review

> Act as a reviewer. Review the current Git diff. Identify bugs, unnecessary changes, missing tests, and security concerns. Do not modify files.

## Prompt 6 — Memory update

> Act as the memory agent. Summarize this session into docs/ai-log.md. Update docs/ai-todo.md by marking completed tasks and adding clear next steps.
