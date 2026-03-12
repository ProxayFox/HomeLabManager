# HomeLabManager Docs

This directory is the repository-local documentation space for HomeLabManager.

The main [README](../README.md) stays focused on project goals, operator usage, and day-one setup. The files here are intended to explain how the codebase is structured, how commands flow through the system, and where to extend behavior safely.

## Documents

### Architecture

- [Architecture Overview](architecture/overview.md): module responsibilities, data flow, and extension points.
- [Command Flow](architecture/command-flow.md): how CLI commands move from parsing to inventory loading, transport execution, audit logging, and recovery state.
- [Inventory Model](architecture/inventory-model.md): YAML schema, validation rules, and host selection behavior.
- [CLI Behavior](architecture/cli-behavior.md): command parsing, option support, output modes, and error rendering.

### Runtime Behavior

- [Update Recovery](runtime/update-recovery.md): persisted failure state, resume points, and recovery semantics.
- [Transport and SSH](runtime/transport-and-ssh.md): transport abstraction, SSH command behavior, and timeout semantics.
- [Audit Logging](runtime/audit-logging.md): audit logger types, log shape, and sanitization rules.

### Operations

- [Inventory Runbook](operations/inventory-runbook.md): how to create, validate, and inspect operator inventory safely.
- [Connectivity Runbook](operations/connectivity-runbook.md): how to confirm SSH reachability before update work.
- [Update Runbook](operations/update-runbook.md): how to move from plan to dry-run to execution and recovery.
- [Live Host Validation Plan](operations/live-host-validation-plan.md): how to prepare and validate a real non-critical test host.
- [Troubleshooting](operations/troubleshooting.md): common failure modes across inventory, connectivity, updates, and verification.

### Reference

- [JSON Output Reference](reference/json-output-reference.md): machine-readable payload shapes emitted by CLI commands.

### Development

- [Development Guide](development/development-guide.md): local workflow, testing expectations, and file layout conventions.
- [Testing Strategy](development/testing-strategy.md): how specs are organized and how transport-dependent behavior is tested safely.
- [Phase 1 Verification Checklist](development/phase-1-verification-checklist.md): the current readiness checklist for local verification and safe-host checks.
- [Contributor Workflow](development/contributor-workflow.md): how to add or change features without breaking the safety model or repo structure.
- [Release and Build](development/release-and-build.md): current versioning, build output, and release verification expectations.
- [Copilot Customizations](development/copilot-customizations.md): how repository instructions, prompts, plans, and customization files are organized.

## Intended Use

- Put design notes and codebase guides here instead of growing the top-level README indefinitely.
- Prefer focused documents by concern, such as CLI behavior, inventory rules, transport design, or update state handling.
- Keep docs close to the real implementation. When behavior changes, update the relevant page in this directory in the same change when practical.