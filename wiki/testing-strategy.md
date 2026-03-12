# Testing Strategy

HomeLabManager keeps tests close to the concerns they verify. The goal is to validate command behavior and safety rules without relying on live SSH hosts or mutating a real machine.

## Core Principles

- Prefer focused spec files by concern.
- Keep transport-dependent behavior behind test doubles.
- Verify safety behavior explicitly, especially dry-run, approval, and execution guards.
- Treat specs as part of the codebase documentation, not just regression coverage.

## Test Layout

The current spec files are organized around the major source modules.

- [spec/homelab_manager_spec.cr](/workspaces/HomeLabManager/spec/homelab_manager_spec.cr): version exposure, inventory parsing, and selection basics.
- [spec/cli_inventory_spec.cr](/workspaces/HomeLabManager/spec/cli_inventory_spec.cr): inventory command parsing, output modes, and exit codes.
- [spec/cli_hosts_spec.cr](/workspaces/HomeLabManager/spec/cli_hosts_spec.cr): connectivity command parsing, host-selection failures, and output modes.
- [spec/cli_updates_spec.cr](/workspaces/HomeLabManager/spec/cli_updates_spec.cr): update command parsing, output modes, resume context, and execution guards.
- [spec/updates_spec.cr](/workspaces/HomeLabManager/spec/updates_spec.cr): plan construction, dry-run semantics, approval state, failure handling, and audit logging.
- [spec/update_state_spec.cr](/workspaces/HomeLabManager/spec/update_state_spec.cr): persisted resume data and recovery behavior.
- [spec/ameba_spec.cr](/workspaces/HomeLabManager/spec/ameba_spec.cr): lint enforcement through Ameba.
- [spec/file_length_spec.cr](/workspaces/HomeLabManager/spec/file_length_spec.cr): repository rule that source and spec files stay within the file-length limit.

## Shared Helpers

[spec/spec_helper.cr](/workspaces/HomeLabManager/spec/spec_helper.cr) provides the common test setup.

Important helpers include:

- `with_temp_inventory`: writes a temporary YAML inventory file for CLI-oriented tests.
- `with_temp_working_directory`: creates an isolated directory so tests can exercise default paths like `config/inventory.yml` or `logs/audit.log` safely.
- `FakeTransport`: replaces the real SSH transport with deterministic in-memory results.

## Why `FakeTransport` Matters

The real implementation in [src/homelab_manager/transport.cr](/workspaces/HomeLabManager/src/homelab_manager/transport.cr) shells out to `ssh`. That is correct for production behavior but inappropriate for unit and command-level specs.

`FakeTransport` keeps tests:

- fast,
- deterministic,
- independent of network state,
- safe to run inside CI or a devcontainer.

Because the CLI and update modules accept a `Transport` instance, tests can inject `FakeTransport` directly without special hooks or monkey patching.

## What the Specs Protect

The current suite is especially valuable around the project's safety model.

- Inventory must validate before remote work begins.
- Host selection must behave predictably when tags and groups are combined.
- `updates plan` must show approval state without executing anything.
- `updates dry-run` must skip mutating steps even when approval exists.
- `updates run` must require `--execute` before mutating commands are allowed.
- Per-host execution must halt later steps after a failure.
- Audit log entries must sanitize secret-like values.
- Failed runs must persist enough state to support resume behavior.
- Split CLI specs should keep inventory, hosts, and updates coverage separate so command-family behavior stays easy to extend.

## Running the Standard Checks

The main verification command is:

```sh
crystal spec
```

In this repository, that command also runs the lint gate through [spec/ameba_spec.cr](/workspaces/HomeLabManager/spec/ameba_spec.cr). A successful test run therefore covers both functional specs and the configured static-analysis pass.

The build can be verified separately with:

```sh
shards build
```

## When Adding Tests

1. Add coverage to the nearest focused spec file instead of growing a catch-all test file.
2. Use `FakeTransport` whenever the behavior under test depends on SSH command outcomes.
3. Use temporary directories for anything that reads or writes default runtime paths.
4. Assert exit codes and output shape for CLI behavior, not just internal method results.
5. Prefer examples that capture the safety contract of the feature, especially around approval and mutating actions.