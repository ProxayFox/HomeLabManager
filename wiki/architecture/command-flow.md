# Command Flow

This document describes how a command moves through the codebase today.

## High-Level Flow

1. The executable starts in [src/homelab_manager.cr](/workspaces/HomeLabManager/src/homelab_manager.cr).
2. `HomeLabManager::CLI.run` in [src/homelab_manager/cli.cr](/workspaces/HomeLabManager/src/homelab_manager/cli.cr) parses the top-level command and options.
3. Shared option parsing and command-family renderers under [src/homelab_manager/cli/](/workspaces/HomeLabManager/src/homelab_manager/cli) handle common parsing and output responsibilities.
4. The CLI loads and validates inventory where needed.
5. Selected hosts are filtered by tags and groups.
6. The command-specific module runs through the injected transport, audit logger, and update state store.
7. The CLI renders human-readable or JSON output and returns a process exit code.

## Inventory Commands

`inventory validate` and `inventory list` both use the inventory module only.

### `inventory validate`

1. Parse optional inventory path and `--json`.
2. Call `Inventory.load`.
3. YAML parsing and structural validation happen in [src/homelab_manager/inventory.cr](/workspaces/HomeLabManager/src/homelab_manager/inventory.cr).
4. On success, the CLI prints either a text summary or JSON payload.
5. On failure, the CLI routes the collected validation errors through the shared error renderer.

### `inventory list`

1. Load the inventory.
2. Apply `HostSelection` filters.
3. Fail early if no hosts match the requested tags or groups.
4. Render the selected hosts with their effective update policy.

## Connectivity Command

`hosts check` adds the transport layer to the same inventory-loading path.

1. Load and validate the inventory.
2. Filter hosts by `--tag` and `--group`.
3. Build a trimmed `InventoryFile` containing only the selected hosts.
4. Call `Connectivity.check`, which delegates each probe to the configured transport.
5. Aggregate success or failure and render output.

The current implementation runs connectivity checks sequentially. There is no concurrency layer yet.

## Update Planning and Execution

The update commands share the same basic setup and then diverge by how they treat mutating steps.

### Shared Setup

1. The CLI parses `--approve`, `--execute`, `--resume-from`, `--tag`, `--group`, and `--json`.
2. Inventory is loaded and filtered.
3. Recovery metadata is read from [state/update-runs.json](/workspaces/HomeLabManager/state/update-runs.json) through `Updates::StateStore`.
4. Resume points are derived either from the explicit `--resume-from` value or from persisted recovery state.
5. `Updates.build_plans` constructs one `UpdatePlan` per selected host.

Plan construction and resume alias parsing now live in [src/homelab_manager/updates/planner.cr](/workspaces/HomeLabManager/src/homelab_manager/updates/planner.cr).

### `updates plan`

This command stops after plan construction.

- It never runs remote commands.
- It exposes approval state and which steps are enabled or blocked.
- It can show resumed plans when a prior failed run exists.

### `updates dry-run`

This command executes the plan but keeps the safety model intact.

- Non-mutating steps run through the transport.
- `apply upgrades` is always marked skipped in dry-run mode.
- Every step result is written through the configured audit logger.
- A host stops executing later steps after the first failure.

Dry-run and mutating execution behavior now live in [src/homelab_manager/updates/runner.cr](/workspaces/HomeLabManager/src/homelab_manager/updates/runner.cr).

### `updates run`

This is the mutating command path.

- The CLI refuses to proceed unless `--execute` is present.
- Approval still controls whether the mutating apply step is enabled.
- Executed results are written to the audit log.
- Failed per-host runs are persisted through `StateStore.record_runs` for future resume behavior.

## Approval and Execution Guards

There are two separate protection layers in the current design.

- Approval: the update plan can mark the mutating step disabled unless the operator supplies `--approve` or the host policy does not require manual approval.
- Execution mode: `updates run` also requires `--execute`, even if approval is already present.

This separation makes the command intent explicit:

- `updates plan` explains what would happen.
- `updates dry-run` performs only safe read-only steps.
- `updates run --approve --execute` is the only path that can apply package upgrades.

## Failure Handling

The update runner treats each host independently.

- If a step fails for one host, later steps for that host become skipped.
- Other hosts continue to run in their own plan sequence.
- A partially completed host can later resume from the recorded failed action.

This model keeps failure behavior predictable and preserves operator control during recovery.