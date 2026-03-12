# Development Guide

This project is intentionally small and explicit. Development work should preserve that shape unless the codebase genuinely outgrows it.

## Tooling

- Language: Crystal
- Build tool: Shards
- Linter: Ameba
- Primary entrypoint: [src/homelab_manager.cr](/workspaces/HomeLabManager/src/homelab_manager.cr)

The repository is set up to work well inside the devcontainer, which installs Crystal, Shards, and Ameba.

## Common Commands

```sh
shards install
shards run homelab_manager
shards build
crystal spec
```

`crystal spec` is the main verification command. In this repository it also covers static analysis through [spec/ameba_spec.cr](/workspaces/HomeLabManager/spec/ameba_spec.cr).

## Source Layout

- [src/homelab_manager/cli.cr](/workspaces/HomeLabManager/src/homelab_manager/cli.cr): command parsing and output orchestration.
- [src/homelab_manager/inventory.cr](/workspaces/HomeLabManager/src/homelab_manager/inventory.cr): YAML-backed inventory model and validation.
- [src/homelab_manager/transport.cr](/workspaces/HomeLabManager/src/homelab_manager/transport.cr): transport abstraction and SSH implementation.
- [src/homelab_manager/connectivity.cr](/workspaces/HomeLabManager/src/homelab_manager/connectivity.cr): read-only host probe behavior.
- [src/homelab_manager/updates.cr](/workspaces/HomeLabManager/src/homelab_manager/updates.cr): update planning and execution.
- [src/homelab_manager/updates/state.cr](/workspaces/HomeLabManager/src/homelab_manager/updates/state.cr): persisted recovery state.
- [src/homelab_manager/audit.cr](/workspaces/HomeLabManager/src/homelab_manager/audit.cr): audit log writing and sanitization.

## Test Layout

- [spec/cli_inventory_spec.cr](/workspaces/HomeLabManager/spec/cli_inventory_spec.cr): inventory command behavior and output.
- [spec/cli_hosts_spec.cr](/workspaces/HomeLabManager/spec/cli_hosts_spec.cr): connectivity command behavior and output.
- [spec/cli_updates_spec.cr](/workspaces/HomeLabManager/spec/cli_updates_spec.cr): update command behavior, JSON output, and execution guards.
- [spec/updates_spec.cr](/workspaces/HomeLabManager/spec/updates_spec.cr): update planning and execution semantics.
- [spec/update_state_spec.cr](/workspaces/HomeLabManager/spec/update_state_spec.cr): recovery persistence.
- [spec/homelab_manager_spec.cr](/workspaces/HomeLabManager/spec/homelab_manager_spec.cr): version and inventory behavior.
- [spec/spec_helper.cr](/workspaces/HomeLabManager/spec/spec_helper.cr): shared helpers and test doubles such as `FakeTransport`.

## Conventions That Matter

- Keep the CLI narrow and explicit while the host-update workflow is still evolving.
- Prefer stdlib serialization for YAML and JSON models when the file format maps cleanly to Crystal structs.
- Keep transport boundaries injectable so orchestration remains testable without live SSH hosts.
- Preserve the safety model: dry runs must stay non-mutating, and real updates must continue to require explicit approval and `--execute`.
- Keep Crystal source and spec files below the repository's 800-line limit.

## When Adding Features

1. Start with the operator behavior you want to expose from the CLI.
2. Decide whether the behavior belongs in inventory parsing, transport execution, update planning, or output formatting.
3. Add or update the focused spec nearest to that concern.
4. Keep runtime side effects explicit: inventory files, audit logs, and persisted update state should remain easy to locate.
5. Update the relevant page in this `wiki/` directory when the change affects architecture or command behavior.