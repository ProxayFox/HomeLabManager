# Project Security Requirements

This document defines the security requirements and best practices that must be followed when building or changing HomeLabManager.

HomeLabManager is a safety-first host management CLI. That means its security posture is not separate from normal feature work. Inventory parsing, transport execution, update planning, update execution, persisted recovery state, audit logging, and operator-facing output are all part of the security boundary.

## Security Model

The current project security model is built around a few non-negotiable rules:

- inventory must validate before any remote work starts,
- `updates plan` must remain non-mutating,
- `updates dry-run` must remain non-mutating,
- `updates run` must stay gated behind explicit approval and `--execute`,
- transport behavior must stay narrow and reviewable,
- recovery state must stay explicit and bounded,
- audit logs must remain sanitized,
- operator-facing error output must not leak secrets or unnecessary internals.

If a proposed change weakens one of those rules, treat it as a security-sensitive design change rather than a normal refactor.

## Trust Boundaries

The most important trust boundaries in the current codebase are:

- operator-supplied inventory data in [src/homelab_manager/inventory.cr](/workspaces/HomeLabManager/src/homelab_manager/inventory.cr),
- SSH transport execution in [src/homelab_manager/transport.cr](/workspaces/HomeLabManager/src/homelab_manager/transport.cr),
- CLI option parsing and command dispatch in [src/homelab_manager/cli.cr](/workspaces/HomeLabManager/src/homelab_manager/cli.cr) and [src/homelab_manager/cli/options.cr](/workspaces/HomeLabManager/src/homelab_manager/cli/options.cr),
- update planning, execution, and resume behavior in [src/homelab_manager/updates/planner.cr](/workspaces/HomeLabManager/src/homelab_manager/updates/planner.cr), [src/homelab_manager/updates/runner.cr](/workspaces/HomeLabManager/src/homelab_manager/updates/runner.cr), and [src/homelab_manager/updates/state.cr](/workspaces/HomeLabManager/src/homelab_manager/updates/state.cr),
- audit persistence and redaction in [src/homelab_manager/audit.cr](/workspaces/HomeLabManager/src/homelab_manager/audit.cr),
- CLI and JSON error rendering in [src/homelab_manager/cli/error_output.cr](/workspaces/HomeLabManager/src/homelab_manager/cli/error_output.cr).

Any change that crosses one of these boundaries should be treated as security-sensitive even if the feature request itself sounds small.

## Mandatory Requirements

### 1. Inventory And Input Validation

- Treat inventory values, CLI options, environment variables, persisted state, and remote host output as untrusted until validated.
- Reject malformed, ambiguous, or unsafe values before they reach transport or update execution.
- Do not rely on downstream command execution to be the first line of defense.
- When validation rules tighten, add focused specs for the new rejected cases.

### 2. Remote Execution Safety

- Prefer narrow argument-array execution over shell-interpolated command strings.
- Do not broaden the transport contract into a general remote command broker unless there is an explicit design decision and review.
- Keep SSH-target construction reviewable and bounded by validated input.
- Preserve explicit timeouts and predictable failure handling for remote actions.

### 3. Update Safety Model

- `updates plan` must not execute remote commands.
- `updates dry-run` must not execute mutating steps.
- `updates run` must continue to require explicit approval and `--execute`.
- Approval-gated steps must stay blocked without approval.
- Per-host execution must stop after a failed step unless the project intentionally changes that rule and updates specs and docs accordingly.
- Resume behavior must remain explicit enough that an operator can tell what will run and why.

### 4. Recovery State And Runtime Files

- Persisted recovery state must stay small, explicit, and bounded to the minimum control-plane data needed for resume behavior.
- Runtime-managed files such as `state/update-runs.json` and `logs/audit.log` must not become implicit sources of broad application truth.
- Reads and writes of runtime state should fail safely and produce clear operator-facing errors.
- When runtime state behavior changes, update both specs and the nearest runtime docs.

### 5. Audit Logging And Error Output

- Keep audit entries attributable and useful without logging secrets, raw credentials, or unnecessary internals.
- Sanitize command, summary, and related free-text fields before persistence.
- Keep JSON and human-readable error output aligned in meaning.
- Do not expose raw exception output to operators when a safer summary will do.

### 6. Documentation And Review Discipline

- When user-visible safeguards change, update the nearest docs in the same change or as the immediate next step.
- When a security-sensitive behavior changes, update focused specs instead of relying on broad regression coverage alone.
- Large security-sensitive changes should have a plan under [.github/plans/](/workspaces/HomeLabManager/.github/plans/plan-homeLabManager.md) before implementation starts.
- If a change affects trust boundaries, approval semantics, resume semantics, transport behavior, audit logging, or error disclosure, call that out explicitly in review.

## Best Practices By Area

### Inventory

- Keep schema and validation rules explicit.
- Prefer rejecting surprising values to silently normalizing them into something the operator did not intend.
- Verify host filtering still behaves predictably after validation changes.

### Transport

- Prefer minimal, explicit command construction.
- Keep command execution injectable so security-sensitive behavior can be tested with fakes instead of real hosts.
- Treat transport exceptions as operator-facing summaries, not raw diagnostic dumps.

### Updates

- Keep planning, execution, and recovery logic separated by concern.
- Review any new update step for mutating status, approval requirements, resume implications, audit implications, and JSON output implications.
- Treat changes to persisted resume behavior as control-flow changes, not just output changes.

### Audit And Output

- Prefer structured output over ad hoc strings when behavior needs to be audited or automated.
- Redaction rules should be backed by focused tests, not assumptions.
- Truncation should reduce disclosure risk without hiding whether the action itself succeeded or failed.

### Documentation

- Keep operator guidance in the relevant runbook or runtime page.
- Keep implementation and review guidance in the wiki and repository customization files.
- Do not document future security behavior as if it already exists.

## Required Verification For Security-Sensitive Changes

Use this checklist when a change touches inventory, transport, updates, recovery state, audit logging, or CLI and JSON error output.

- Add or update the nearest focused specs, such as [spec/cli_inventory_spec.cr](/workspaces/HomeLabManager/spec/cli_inventory_spec.cr), [spec/cli_updates_spec.cr](/workspaces/HomeLabManager/spec/cli_updates_spec.cr), [spec/update_runner_spec.cr](/workspaces/HomeLabManager/spec/update_runner_spec.cr), or [spec/update_state_spec.cr](/workspaces/HomeLabManager/spec/update_state_spec.cr).
- Run `crystal spec`.
- Run `shards build` when the change affects runtime behavior or command wiring.
- Validate the relevant operator command path when practical, such as `shards run homelab_manager -- inventory validate` or the affected `updates` path.
- Confirm the safety model still holds after the change.
- Update the nearest wiki page when the behavior or operator expectations changed.

## Review Questions

Before merging a security-sensitive change, answer these questions:

- What untrusted input reaches this code path?
- What trust boundary does the change cross?
- Could this change make a mutating action easier to trigger unintentionally?
- Could this change alter resume or recovery behavior without the operator noticing?
- Could this change leak secrets, host details, filesystem details, or raw exceptions?
- Which focused specs prove the intended safeguard now?
- Which docs need to change so the safer behavior is discoverable?

## Related Documents

- [Update Recovery](../runtime/update-recovery.md)
- [Transport and SSH](../runtime/transport-and-ssh.md)
- [Audit Logging](../runtime/audit-logging.md)
- [Contributor Workflow](../development/contributor-workflow.md)
- [Security Remediation Hardening Plan](../../.github/plans/plan-security-remediation.md)