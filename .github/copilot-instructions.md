# HomeLabManager

## Project Overview

- Language: Crystal
- Build tool: Shards (Crystal's dependency manager)
- Project type: Console application
- Purpose: safety-first homelab host management CLI

## Development Environment

- Uses devcontainer with Crystal language image
- Crystal 1.19.1 and Shards are available in the container
- Devcontainer `postCreateCommand` runs `shards install`
- The devcontainer mounts the operator's SSH directory so Git and SSH-based host workflows can use existing keys
- Ameba is installed globally in the devcontainer; `crystal spec` shells out to `ameba --config .ameba.yml` through `spec/ameba_spec.cr`

## Architecture

- Entry point and main target: `src/homelab_manager.cr`, which dispatches to `HomeLabManager::CLI.run(ARGV)`
- Core domain types live in `src/homelab_manager/domain.cr`
- Inventory parsing and validation live in `src/homelab_manager/inventory.cr`
- SSH transport abstractions live in `src/homelab_manager/transport.cr`
- Connectivity checks live in `src/homelab_manager/connectivity.cr`
- Update planning and execution live in `src/homelab_manager/updates.cr` and `src/homelab_manager/updates/state.cr`
- Audit logging lives in `src/homelab_manager/audit.cr`
- CLI parsing, dispatch, and error formatting live in `src/homelab_manager/cli.cr` and `src/homelab_manager/cli/error_output.cr`
- Command-family output helpers can be split under `src/homelab_manager/cli/`, such as inventory, hosts, and update output renderers
- Tests live in `spec/`, with shared helpers in `spec/spec_helper.cr`

## Conventions

- Keep shard and target names lowercase in `shard.yml`; the current shard name is `homelab_manager`
- Keep Crystal module names CamelCase; the current top-level module is `HomeLabManager`
- Prefer minimal, direct Crystal code over framework-style abstractions unless the repo grows beyond a single console app
- Keep the early CLI narrow and explicit while the Phase 1 host-update workflow is being built out
- Keep Crystal files in `src/` and `spec/` at or below 800 lines; split large files by concern before they exceed that limit
- When a module starts to sprawl, keep the public entrypoints in the main module file and extract supporting concerns into adjacent files under a matching directory
- Prefer module-local shared helpers such as `src/homelab_manager/<module>/utils.cr` for reusable private logic instead of growing a single top-level grab bag
- Split mixed-responsibility files along clear boundaries such as parsing, option handling, output rendering, domain models, execution flow, and shared helper methods
- Mirror major source splits in `spec/` with focused spec files so tests stay close to the concern they cover
- Favor names that describe the concern directly, such as `cli/options.cr`, `cli/output.cr`, `updates/planner.cr`, `updates/runner.cr`, or `inventory/validation.cr`, over generic suffixes unless the file truly holds shared utilities for that module
- When CLI output starts to sprawl for one command family, extract it into a dedicated helper under `src/homelab_manager/cli/` instead of growing `cli.cr` indefinitely
- Prefer Crystal stdlib serialization (`YAML::Serializable`, `JSON::Serializable`) over custom parsing when the model fits the file format
- Keep transport boundaries injectable so command orchestration can be tested with `FakeTransport` instead of real SSH hosts
- Treat `config/inventory.yml`, `logs/audit.log`, and `state/update-runs.json` as operator/runtime data, not source-controlled fixtures
- Preserve the safety model: dry-run and plan commands remain non-mutating, and real update execution should continue to require explicit approval and `--execute`

## Build and Test

- Run the app with `shards run homelab_manager` or `crystal run src/homelab_manager.cr`
- Build the app with `shards build`; this writes the binary to `bin/homelab_manager` based on the target declared in `shard.yml`
- Run tests with `crystal spec`
- `crystal spec` also runs Ameba and the 800-line file-length check
- Use `shards run homelab_manager -- inventory validate` to validate inventory changes before touching connectivity or update flows
- Prefer focused specs near the affected concern, such as `spec/cli_inventory_spec.cr`, `spec/cli_hosts_spec.cr`, `spec/cli_updates_spec.cr`, `spec/update_planner_spec.cr`, `spec/update_runner_spec.cr`, `spec/update_integration_spec.cr`, and `spec/update_state_spec.cr`, instead of growing a single catch-all spec file
