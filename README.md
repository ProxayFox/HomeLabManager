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

## Project Structure

```text
.
├── .devcontainer/        # Devcontainer configuration
├── .github/              # Workspace-specific Copilot instructions and prompts
├── spec/                 # Test files
├── src/                  # Application source
├── bin/                  # Build output from shards build
├── shard.yml             # Shards manifest
└── README.md
```

## Next Milestones

1. Define the Phase 1 domain model for hosts, approvals, execution results, and audit events.
2. Introduce YAML inventory parsing and strict validation.
3. Build the dry-run-first update workflow for Ubuntu hosts.
4. Add safe remote execution boundaries and file-based audit logging.

## Notes

- `shards run homelab_manager` is correct. `shard run homelab_manager` is not.
- `crystal run` expects a source file path, so use `crystal run src/homelab_manager.cr`.
- `crystal spec` should remain green while Phase 1 is developed.
