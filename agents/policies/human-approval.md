# Human Approval Policy

Approval must be informed, specific, and recorded in the run plan or status. Silence, a prior approval for different work, or an agent's own recommendation is not approval.

## Approval is required for

- Installing, removing, or upgrading dependencies and packages
- Changing dependency or lock files beyond an already approved update
- Database or storage migrations and destructive data operations
- Deleting, renaming, or overwriting files
- Authentication, authorization, cryptography, privacy, or other security logic
- External network access, downloads, or sending repository content elsewhere
- Deployment, CI/CD, infrastructure, container security, or production configuration
- Reading, creating, or editing secrets and credential configuration
- Commands requiring elevated privileges
- Pushing to any remote or publishing a package or artifact
- Merging, rebasing shared branches, or modifying `main`
- Changes above `AGENT_MAX_FILES_CHANGED` or work beyond `AGENT_MAX_TASKS`
- Large rewrites, generated changes, or operations with unclear rollback

## Approval record

Before the action, record:

- Exact action and command, if applicable
- Why it is needed
- Files, services, data, and external destinations affected
- Expected result
- Risks and rollback method
- Approver and timestamp
- Scope and expiration of the approval

An approval applies only to the recorded action. Any material change requires new approval.

## Standard gates

1. **Plan gate:** Human approves task scope before code edits.
2. **Risk gate:** Human approves each risky action listed above.
3. **Result gate:** Human reviews diff, tests, and review report before acceptance.
4. **Remote gate:** Human separately approves push, merge, or publication.

## Reject or pause when

- The plan is incomplete or exceeds local hardware limits.
- The affected files or data cannot be identified.
- A rollback is missing for a destructive action.
- Tests cannot meaningfully verify the change.
- Private code would be sent to an unapproved service.
- The approval request combines unrelated actions.

## Emergency stop

Run `./scripts/agent-stop.sh RUN_ID "reason"` to create a durable stop marker. Then interrupt any active command in its own terminal and inspect Git status and the diff. The marker itself does not terminate processes or revert changes.
