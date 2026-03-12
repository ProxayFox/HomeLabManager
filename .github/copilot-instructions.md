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

## Architecture

- Source code lives in `src/`
- Tests live in `spec/`
- Entry point and main target: `src/homelab_manager.cr`
- Project manifest: `shard.yml`
- There are no external dependencies yet

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

## Build and Test

- Run the app with `shards run homelab_manager` or `crystal run src/homelab_manager.cr`
- Build the app with `shards build`; this writes the binary to `bin/homelab_manager` based on the target declared in `shard.yml`
- Run tests with `crystal spec`
- The spec suite enforces the 800-line limit for Crystal files under `src/` and `spec/`
- Keep the baseline suite passing; extend `spec/homelab_manager_spec.cr` or replace it with real tests as the project evolves
