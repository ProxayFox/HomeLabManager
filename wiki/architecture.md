# Architecture Overview

HomeLabManager is a Crystal console application built around a narrow CLI and a small set of explicit domain modules. The current design favors direct code paths over abstraction-heavy layers because the MVP is still centered on safe host update workflows.

## Runtime Entry

- [src/homelab_manager.cr](/workspaces/HomeLabManager/src/homelab_manager.cr) is the executable entrypoint.
- [src/homelab_manager/app.cr](/workspaces/HomeLabManager/src/homelab_manager/app.cr) loads the application modules and defines `HomeLabManager::VERSION`.
- [src/homelab_manager/cli.cr](/workspaces/HomeLabManager/src/homelab_manager/cli.cr) is the main orchestration layer for command parsing, validation, output formatting, and dispatch.

## Core Modules

### Domain and Shared Types

[src/homelab_manager/domain.cr](/workspaces/HomeLabManager/src/homelab_manager/domain.cr) defines the low-level types reused across the app:

- `HostSelection` for tag and group filters.
- `ApprovalState` for manual approval tracking.
- `OperationStatus` for success, failure, and skipped execution states.
- `ExecutionResult` as the common result envelope returned by transport-backed operations.

These types keep the CLI, connectivity checks, update execution, and audit logging speaking the same language.

### Inventory

[src/homelab_manager/inventory.cr](/workspaces/HomeLabManager/src/homelab_manager/inventory.cr) handles operator-supplied inventory data.

- `UpdatePolicy` defines per-host update behavior such as previewing upgrades, requiring approval, and allowing reboot.
- `InventoryDefaults` holds fallback policy values.
- `Host` models a single managed host and computes its effective update policy.
- `InventoryFile` validates the parsed YAML and rejects malformed or duplicate host definitions before any remote action occurs.
- `Inventory.load` and `Inventory.parse` provide the main file-loading and parsing entrypoints.
- `Inventory.select_hosts` applies `--tag` and `--group` filters.

This module is the first safety gate in the system. If inventory parsing or validation fails, later transport and update code is never reached.

### Transport

[src/homelab_manager/transport.cr](/workspaces/HomeLabManager/src/homelab_manager/transport.cr) isolates remote execution behind an abstract transport boundary.

- `Transport` defines the contract for connectivity probes and command execution.
- `SshTransport` is the real implementation that shells out to `ssh` with batch mode, strict host key checking, and command/connect timeout controls.

The main reason this boundary exists is testability. Specs can use `FakeTransport` from the shared spec helpers rather than depending on real SSH hosts.

### Connectivity

[src/homelab_manager/connectivity.cr](/workspaces/HomeLabManager/src/homelab_manager/connectivity.cr) is intentionally small. It maps selected hosts through the transport probe method and determines whether every result succeeded.

This keeps the read-only connectivity command narrow and makes its behavior easy to reason about.

### Updates

[src/homelab_manager/updates.cr](/workspaces/HomeLabManager/src/homelab_manager/updates.cr) contains the update planning and execution model.

- `UpdateStepKind` names the supported workflow stages.
- `UpdateStep` describes one remote action, whether it mutates state, and whether it is currently enabled.
- `UpdatePlan` captures the steps and approval state for a host before execution.
- `UpdateRun` records the actual step results for a host and exposes derived overall status helpers.
- `Updates.build_plans` produces plans from inventory defaults, host-specific policy, approval state, and optional resume points.
- `Updates.dry_run` executes only non-mutating steps.
- `Updates.execute` runs the full workflow when the CLI has already enforced `--execute`.

The update module is where the project's safety-first rules are encoded:

- approval gates can disable mutating steps,
- dry-run mode skips mutating commands even when a host is approved,
- execution halts remaining steps for a host after the first failure,
- reboot-required detection is normalized into a boolean result,
- resume points can disable earlier steps when recovering from a prior failure.

### Update State

[src/homelab_manager/updates/state.cr](/workspaces/HomeLabManager/src/homelab_manager/updates/state.cr) persists failed update context to `state/update-runs.json`.

- `RecoveryStateEntry` stores the failed action, timestamp, summary, and reboot-required status for one host.
- `StateStore` loads and writes the state file, provides selected-host recovery entries, and converts failed actions into resume points.

This file gives later `updates plan`, `updates dry-run`, and `updates run` commands enough context to resume intelligently without forcing the operator to restate the last failed step manually.

### Audit Logging

[src/homelab_manager/audit.cr](/workspaces/HomeLabManager/src/homelab_manager/audit.cr) provides the audit sink used by update execution.

- `Audit::Logger` is the abstraction.
- `Audit::NullLogger` is the no-op implementation used in tests or when persistence is not needed.
- `Audit::FileLogger` writes JSON lines to `logs/audit.log` and redacts simple secret-like fields before persisting summaries or commands.

Audit logging is deliberately separate from transport execution so the app can evolve logging behavior without tangling it into SSH code.

### CLI Error Rendering

[src/homelab_manager/cli/error_output.cr](/workspaces/HomeLabManager/src/homelab_manager/cli/error_output.cr) holds shared error formatting used by the CLI, including structured JSON error output when `--json` is requested.

## Design Characteristics

- Thin CLI, explicit modules: commands are dispatched centrally, then handed to focused modules.
- Validation before action: inventory errors stop execution early.
- Injectable boundaries: transport, audit logger, and update state store can all be replaced in specs.
- Safety over convenience: dry runs, explicit approval, and `--execute` guards are built into the command model.
- Minimal persistence: runtime data is intentionally limited to audit logs and update recovery state.

## Tests as Supporting Documentation

The test suite under [spec/](/workspaces/HomeLabManager/spec) mirrors the major concerns of the source tree.

- [spec/cli_inventory_spec.cr](/workspaces/HomeLabManager/spec/cli_inventory_spec.cr), [spec/cli_hosts_spec.cr](/workspaces/HomeLabManager/spec/cli_hosts_spec.cr), and [spec/cli_updates_spec.cr](/workspaces/HomeLabManager/spec/cli_updates_spec.cr) cover the split CLI command families, output paths, and execution guards.
- [spec/updates_spec.cr](/workspaces/HomeLabManager/spec/updates_spec.cr) covers planning, dry-run behavior, approval, failure handling, and audit logging.
- [spec/update_state_spec.cr](/workspaces/HomeLabManager/spec/update_state_spec.cr) covers persisted recovery behavior.
- [spec/homelab_manager_spec.cr](/workspaces/HomeLabManager/spec/homelab_manager_spec.cr) covers core inventory and version behavior.

If you are changing behavior, the nearest focused spec file is usually the correct place to extend first.