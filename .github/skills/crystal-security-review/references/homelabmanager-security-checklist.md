# HomeLabManager Security Checklist

Use this checklist when applying the crystal-security-review skill to this repository.

## Repo Focus Areas

1. Inventory and config loading
- Review [src/homelab_manager/inventory.cr](../../../../src/homelab_manager/inventory.cr) and runtime inventory files for path handling, schema validation, and trust in operator-supplied host data.
- Check whether YAML deserialization is followed by explicit validation of required fields, enumerations, and operational invariants.

2. SSH transport and remote execution
- Review [src/homelab_manager/transport.cr](../../../../src/homelab_manager/transport.cr) for shell interpolation, unsafe argument quoting, host-key handling assumptions, and leakage of remote command details.
- Check whether transport errors expose sensitive host or command data beyond what operators need.

3. Connectivity and host targeting
- Review [src/homelab_manager/connectivity.cr](../../../../src/homelab_manager/connectivity.cr) and CLI host-selection paths for unsafe trust in user-selected targets, unexpected fan-out, or denial-of-service patterns.

4. Update planning and execution
- Review [src/homelab_manager/updates.cr](../../../../src/homelab_manager/updates.cr), [src/homelab_manager/updates/planner.cr](../../../../src/homelab_manager/updates/planner.cr), [src/homelab_manager/updates/runner.cr](../../../../src/homelab_manager/updates/runner.cr), and [src/homelab_manager/updates/state.cr](../../../../src/homelab_manager/updates/state.cr).
- Check approval enforcement, `--execute` gating, dry-run non-mutation, resume integrity, per-host failure handling, and any possibility of running a different plan than the operator reviewed.

5. Audit logging and error output
- Review [src/homelab_manager/audit.cr](../../../../src/homelab_manager/audit.cr) and [src/homelab_manager/cli/error_output.cr](../../../../src/homelab_manager/cli/error_output.cr) for secret leakage, missing attribution, weak redaction, and inconsistencies between human-readable and JSON output.

6. CLI boundaries
- Review [src/homelab_manager/cli.cr](../../../../src/homelab_manager/cli.cr) and helpers under [src/homelab_manager/cli/](../../../../src/homelab_manager/cli/) for unvalidated arguments, ambiguous option interactions, or behavior that bypasses intended safety gates.

## Spec Expectations

- Check nearby behavior specs in [spec/cli_inventory_spec.cr](../../../../spec/cli_inventory_spec.cr), [spec/cli_hosts_spec.cr](../../../../spec/cli_hosts_spec.cr), [spec/cli_updates_spec.cr](../../../../spec/cli_updates_spec.cr), [spec/update_planner_spec.cr](../../../../spec/update_planner_spec.cr), [spec/update_runner_spec.cr](../../../../spec/update_runner_spec.cr), [spec/update_integration_spec.cr](../../../../spec/update_integration_spec.cr), and [spec/update_state_spec.cr](../../../../spec/update_state_spec.cr).
- When fixing a security issue, prefer a focused regression spec that proves the unsafe path is blocked or redacted.

## Verification Commands

- `crystal spec`
- `shards run homelab_manager -- inventory validate`
- Run only the most relevant command path when the audit concerns a specific workflow, and verify that dry-run and approval semantics did not drift.

## Reporting Notes

- Prioritize real exploit paths over theoretical style issues.
- Mention review gaps explicitly when runtime behavior, external systems, or operator environment assumptions could not be verified.
- Call out operational mitigations separately from code fixes when the safest immediate response is procedural.
