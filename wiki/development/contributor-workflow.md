# Contributor Workflow

This document explains how to change HomeLabManager without fighting the current structure or weakening the safety model.

The project is still intentionally small. The fastest way to create maintenance problems here is to introduce abstraction or sprawl that the current codebase does not need.

## Start with the Command Surface

Most changes begin from one of these questions:

- Is this a new CLI command?
- Is this a new option on an existing command?
- Is this a change to inventory parsing or selection?
- Is this a new update step or recovery behavior?
- Is this only an output or documentation change?

Start by identifying which module owns the behavior instead of adding logic to whichever file you touched first.

## Current Ownership Boundaries

- [src/homelab_manager/cli.cr](/workspaces/HomeLabManager/src/homelab_manager/cli.cr): command dispatch and top-level execution flow.
- [src/homelab_manager/cli/options.cr](/workspaces/HomeLabManager/src/homelab_manager/cli/options.cr): shared command option parsing.
- [src/homelab_manager/cli/inventory_output.cr](/workspaces/HomeLabManager/src/homelab_manager/cli/inventory_output.cr): inventory text and JSON rendering.
- [src/homelab_manager/cli/hosts_output.cr](/workspaces/HomeLabManager/src/homelab_manager/cli/hosts_output.cr): connectivity text and JSON rendering.
- [src/homelab_manager/cli/error_output.cr](/workspaces/HomeLabManager/src/homelab_manager/cli/error_output.cr): shared CLI error rendering.
- [src/homelab_manager/cli/update_output.cr](/workspaces/HomeLabManager/src/homelab_manager/cli/update_output.cr): JSON rendering for update plan and run payloads.
- [src/homelab_manager/inventory.cr](/workspaces/HomeLabManager/src/homelab_manager/inventory.cr): YAML parsing, validation, and host selection.
- [src/homelab_manager/transport.cr](/workspaces/HomeLabManager/src/homelab_manager/transport.cr): remote execution boundary.
- [src/homelab_manager/updates.cr](/workspaces/HomeLabManager/src/homelab_manager/updates.cr): shared update workflow types.
- [src/homelab_manager/updates/planner.cr](/workspaces/HomeLabManager/src/homelab_manager/updates/planner.cr): update plan construction and resume alias handling.
- [src/homelab_manager/updates/runner.cr](/workspaces/HomeLabManager/src/homelab_manager/updates/runner.cr): dry-run and execution semantics.
- [src/homelab_manager/updates/state.cr](/workspaces/HomeLabManager/src/homelab_manager/updates/state.cr): persisted recovery state.
- [src/homelab_manager/audit.cr](/workspaces/HomeLabManager/src/homelab_manager/audit.cr): audit persistence and sanitization.

If your change crosses more than one of those boundaries, keep each responsibility in its owning module rather than collapsing everything into the CLI.

If the work is large enough to span multiple phases, prepare a plan first and keep the implementation split into explicit phase and task boundaries so the resulting commits can stay staggered and reviewable.

## Adding a New CLI Feature

Use this sequence when adding or changing a command.

1. Decide the operator-facing behavior first: command name, arguments, exit codes, and whether `--json` is needed.
2. Add or update the CLI path in [src/homelab_manager/cli.cr](/workspaces/HomeLabManager/src/homelab_manager/cli.cr).
3. Keep parsing and top-level validation in the CLI.
4. Push domain behavior into the owning module rather than implementing it inline in the command handler.
5. Add or update the focused spec nearest to the behavior.
6. Update the relevant wiki page if the runtime contract changed.

## Adding an Update Step

Update workflow changes need extra discipline because this part of the project carries the main safety guarantees.

1. Add the step to `UpdateStepKind` in [src/homelab_manager/updates.cr](/workspaces/HomeLabManager/src/homelab_manager/updates.cr).
2. Add the step to the planner in [src/homelab_manager/updates/planner.cr](/workspaces/HomeLabManager/src/homelab_manager/updates/planner.cr) with the right mutating flag and enablement logic.
3. Update `Updates.parse_resume_from` if the step needs resume support.
4. Update `action_name` in [src/homelab_manager/updates/runner.cr](/workspaces/HomeLabManager/src/homelab_manager/updates/runner.cr) so step results and recovery state use a stable action identifier.
5. Extend the relevant specs in [spec/update_planner_spec.cr](/workspaces/HomeLabManager/spec/update_planner_spec.cr), [spec/update_runner_spec.cr](/workspaces/HomeLabManager/spec/update_runner_spec.cr), [spec/cli_updates_spec.cr](/workspaces/HomeLabManager/spec/cli_updates_spec.cr), or [spec/update_state_spec.cr](/workspaces/HomeLabManager/spec/update_state_spec.cr).
6. Recheck that dry-run remains non-mutating and that `updates run` still requires `--execute`.

## Working with Output

The repository now has an explicit split between text output and some JSON output concerns.

- General command flow and most text output still live in [src/homelab_manager/cli.cr](/workspaces/HomeLabManager/src/homelab_manager/cli.cr).
- Shared command option parsing lives in [src/homelab_manager/cli/options.cr](/workspaces/HomeLabManager/src/homelab_manager/cli/options.cr).
- Inventory and connectivity rendering live in [src/homelab_manager/cli/inventory_output.cr](/workspaces/HomeLabManager/src/homelab_manager/cli/inventory_output.cr) and [src/homelab_manager/cli/hosts_output.cr](/workspaces/HomeLabManager/src/homelab_manager/cli/hosts_output.cr).
- Error JSON output lives in [src/homelab_manager/cli/error_output.cr](/workspaces/HomeLabManager/src/homelab_manager/cli/error_output.cr).
- Update JSON payloads live in [src/homelab_manager/cli/update_output.cr](/workspaces/HomeLabManager/src/homelab_manager/cli/update_output.cr).

If output logic starts to sprawl for another command family, follow that same pattern and split it into a dedicated helper file under `src/homelab_manager/cli/`.

## Testing Expectations

This repo expects focused specs, not a single oversized catch-all file.

- [spec/cli_inventory_spec.cr](/workspaces/HomeLabManager/spec/cli_inventory_spec.cr): inventory command behavior.
- [spec/cli_hosts_spec.cr](/workspaces/HomeLabManager/spec/cli_hosts_spec.cr): host connectivity command behavior.
- [spec/cli_updates_spec.cr](/workspaces/HomeLabManager/spec/cli_updates_spec.cr): update command behavior and output.
- [spec/update_planner_spec.cr](/workspaces/HomeLabManager/spec/update_planner_spec.cr): planner semantics and resume alias handling.
- [spec/update_runner_spec.cr](/workspaces/HomeLabManager/spec/update_runner_spec.cr): runner semantics, timeout propagation, and audit coverage.
- [spec/update_integration_spec.cr](/workspaces/HomeLabManager/spec/update_integration_spec.cr): opt-in real-transport verification in a safe environment.
- [spec/update_state_spec.cr](/workspaces/HomeLabManager/spec/update_state_spec.cr): persisted recovery state.

Use `FakeTransport` from [spec/spec_helper.cr](/workspaces/HomeLabManager/spec/spec_helper.cr) whenever SSH outcomes matter.

## Keep the Safety Model Intact

Any change touching update behavior should preserve these invariants unless the project explicitly decides to change them.

- inventory must validate before remote work starts,
- `updates plan` must not execute remote commands,
- `updates dry-run` must not execute mutating steps,
- `updates run` must require `--execute`,
- approval-gated steps must remain blocked without approval,
- per-host execution must stop after a failed step,
- recovery state must be small and explicit,
- audit logs must remain sanitized.

## Verification Loop

The normal repository verification flow is:

```sh
crystal spec && shards build
```

That covers:

- behavior specs,
- Ameba static analysis,
- the repository file-length guard,
- a build of the `homelab_manager` binary.

If you touch docs only, it is still useful to run the same flow because the repo’s spec gate also catches unrelated drift in the working tree.

## When to Split Files

The repo rule is to keep Crystal source and spec files under the file-length limit and split by concern before they sprawl.

Good reasons to split a file:

- a module is mixing parsing, execution, and rendering logic,
- a command family has enough specialized output to justify its own helper,
- a spec file is growing into multiple unrelated behaviors.

Poor reasons to split a file:

- creating generic abstraction layers with no second use,
- moving tiny helpers out just to increase indirection,
- separating code in a way that hides the main execution flow.

The project favors clarity over clever structure.