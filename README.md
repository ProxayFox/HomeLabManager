# HomeLabManager

HomeLabManager is a Crystal-based homelab management project focused on safe, repeatable Ubuntu host operations. The first milestone is a CLI that removes the weekly manual SSH routine for package updates while keeping approval gates, auditability, and secrets hygiene in front of convenience.

## Current Scope

Phase 0 is complete: this repository now reflects the real project identity instead of the generic Crystal starter template.

The current MVP direction is:

- CLI first, web UI later
- Manage 4 to 10 Ubuntu hosts
- Use a single YAML inventory file initially
- Authenticate with the operator's SSH keys or SSH agent
- Require dry runs and manual approval before mutating actions
- Defer Docker Compose migration from the existing Python tool until after the host-update workflow is stable

## Planned MVP

The first real feature set is a host maintenance workflow that can:

- Validate inventory before any remote action starts
- Check connectivity to known hosts
- Preview available package updates safely
- Execute approved update actions host by host
- Detect whether a reboot is required after updates
- Record sanitized audit logs for each operation

## Development Environment

You can work in either the devcontainer or a local Crystal installation.

### Option 1: VS Code Devcontainer

1. Open the repository in VS Code.
2. Reopen it in the devcontainer when prompted.
3. Wait for the container to finish building.
4. The container runs `shards install` automatically after creation.

The devcontainer mounts your host SSH directory into the container so Git operations and future SSH-based host management workflows can use your existing keys.

### Option 2: Local Crystal Setup

Install Crystal 1.19.1 or newer, then run:

```sh
shards install
```

## Common Commands

Run the app through the target defined in [shard.yml](shard.yml):

```sh
shards run homelab_manager
```

Run the entrypoint directly with Crystal:

```sh
crystal run src/homelab_manager.cr
```

Build the binary into [bin/](bin):

```sh
shards build
./bin/homelab_manager
```

Run the test suite:

```sh
crystal spec
```

`crystal spec` also runs Ameba through [spec/ameba_spec.cr](spec/ameba_spec.cr), so the test pass now includes static analysis.

Validate an inventory file before any remote work begins:

```sh
cp config/inventory.example.yml config/inventory.yml
shards run homelab_manager -- inventory validate
```

List the hosts defined in an inventory file:

```sh
shards run homelab_manager -- inventory list
```

Limit inventory output to a specific tag or group:

```sh
shards run homelab_manager -- inventory list --tag core
shards run homelab_manager -- inventory list --group lab
```

Run a non-mutating SSH connectivity check across the inventory:

```sh
shards run homelab_manager -- hosts check
```

Limit connectivity checks to a selected subset of hosts:

```sh
shards run homelab_manager -- hosts check --tag core
shards run homelab_manager -- hosts check --group lab
```

Build an approval-aware update plan without executing any remote changes:

```sh
shards run homelab_manager -- updates plan
shards run homelab_manager -- updates plan --tag updates
shards run homelab_manager -- updates plan --approve
```

Execute only the non-mutating update steps and write audit logs:

```sh
shards run homelab_manager -- updates dry-run
shards run homelab_manager -- updates dry-run --tag updates
shards run homelab_manager -- updates dry-run --approve
```

Execute the full update workflow only when you explicitly opt in:

```sh
shards run homelab_manager -- updates run --approve --execute
shards run homelab_manager -- updates run --group lab --approve --execute
shards run homelab_manager -- updates run --group lab --approve --resume-from update_apply_upgrades --execute
```

Render update plans and runs as JSON:

```sh
shards run homelab_manager -- updates plan --json
shards run homelab_manager -- updates dry-run --json
shards run homelab_manager -- updates run --approve --execute --json
```

## Inventory Format

Phase 1 currently provides a validated YAML inventory baseline for host definitions.

Recommended location:

- Keep the operator-managed inventory at `config/inventory.yml`.
- Start from the tracked template at `config/inventory.example.yml`.
- `config/inventory.yml` is ignored by Git so real host details are not committed to the remote.
- Inventory commands default to `config/inventory.yml`, but you can still pass an explicit path when needed.

Example:

```yaml
defaults:
  update:
    refresh_package_index: true
    preview_upgrades: true
    require_manual_approval: true
    allow_reboot: false
hosts:
  - name: atlas
    address: 192.168.1.10
    ssh_user: ubuntu
    tags: [core]
    groups: [lab]
  - name: backup
    address: backup.internal
    ssh_user: admin
    port: 2222
    update:
      allow_reboot: true
```

Current validation rules:

- `hosts` must contain at least one host.
- Each host must define non-blank `name`, `address`, and `ssh_user` fields.
- `port` defaults to `22` and must remain within the valid TCP port range.
- Host names must be unique within the inventory file.
- Inventory validation must succeed before later SSH-based features are allowed to run.
- Copy `config/inventory.example.yml` to `config/inventory.yml` before adding real host data.

Inventory selection rules:

- `inventory list`, `hosts check`, and `updates plan` accept repeated `--tag` and `--group` filters.
- Tag filters match if a host contains any selected tag.
- Group filters match if a host contains any selected group.
- When both tags and groups are provided, a host must match at least one selected tag and at least one selected group.
- Commands return a non-zero exit code if no hosts match the requested filters.

## Connectivity Checks

Phase 1 now includes a read-only connectivity command that probes each host over SSH without performing package or configuration changes.

- `hosts check` uses the operator's existing SSH keys or SSH agent.
- Checks run sequentially and report per-host success or failure.
- The command exits non-zero if any host fails the connectivity probe.
- SSH probing is isolated behind a transport boundary so orchestration can be tested without real SSH targets.

## Update Plans

Phase 1 now includes a non-executing update planner that builds the intended host workflow before any mutating command runner exists.

- `updates plan` shows the refresh, preview, apply, and reboot-check steps for each selected host.
- Mutating upgrade steps remain blocked until approval is provided for hosts that require manual approval.
- `--approve` marks the plan as approved for preview purposes only; it does not execute the upgrade.
- The planner uses the host-specific or default update policy from the inventory file.

## Dry-Run Execution

Phase 1 now also includes a dry-run execution path that runs only the non-mutating update steps.

- `updates dry-run` executes refresh, preview, and reboot-check steps for each selected host.
- The mutating `apply upgrades` step is always skipped in dry-run mode, even when `--approve` is provided.
- Dry-run output reports per-host, per-step execution results and exit codes where available.
- The command exits non-zero if any executed dry-run step fails.

## Update Execution

Phase 1 now includes the first real mutating runner for approved host updates.

- `updates run` requires `--execute` so mutating actions are never triggered by accident.
- Hosts that still require approval will keep the upgrade step blocked unless `--approve` is also provided.
- `--resume-from` lets you skip earlier steps and resume from a specific update action after a partial failure or manual intervention.
- Per-host execution stops after the first failed step and clearly marks later steps as skipped.
- Execution output includes per-host overall status, per-step results, and reboot-required reporting when the host check completes.
- The command exits non-zero when any host run includes a failed step.

Supported `--resume-from` values:

- `update_refresh_package_index`
- `update_preview_upgrades`
- `update_apply_upgrades`
- `update_check_reboot_required`

## Audit Logging

Audit logging is file-based for the MVP.

- Dry-run execution writes JSON line entries to `logs/audit.log`.
- Dry-run and real update execution both write JSON line entries to `logs/audit.log`.
- Runtime logs are ignored by Git.
- Log entries include timestamp, operator, host, action, approval state, exit status, and sanitized command/result summaries.
- Sensitive-looking `password=`, `passwd=`, `token=`, and `secret=` values are redacted before being written.

## JSON Output

Update commands now support machine-readable JSON output.

- `updates plan --json` emits the selected hosts, approval state, and planned steps.
- `updates dry-run --json` and `updates run --json` emit per-host summaries, reboot-required state, and per-step results.
- Human-readable output remains the default when `--json` is not provided.

## Project Structure

```text
.
├── .devcontainer/        # Devcontainer configuration
├── .github/              # Workspace-specific Copilot instructions and prompts
├── config/               # Example inventory and local operator config location
├── spec/                 # Test files
├── src/                  # Application source
├── bin/                  # Build output from shards build
├── shard.yml             # Shards manifest
└── README.md
```

## Next Milestones

1. Expand retry and resume behavior beyond step-based restarts into safer host-level recovery workflows.
2. Extend machine-readable output and summaries to more command areas as the CLI surface grows.
3. Expand audit logging and sanitization rules as more commands and outputs are introduced.
4. Keep the transport boundary testable while evolving toward broader host-management operations.

## Notes

- `shards run homelab_manager` is correct. `shard run homelab_manager` is not.
- `crystal run` expects a source file path, so use `crystal run src/homelab_manager.cr`.
- `crystal spec` should remain green while Phase 1 is developed.
