# HomeLabManager Docs

This directory is the repository-local documentation space for HomeLabManager.

The main [README](../README.md) stays focused on project goals, operator usage, and day-one setup. The files here are intended to explain how the codebase is structured, how commands flow through the system, and where to extend behavior safely.

## Documents

### Architecture

- [Architecture Overview](architecture.md): module responsibilities, data flow, and extension points.
- [Command Flow](command-flow.md): how CLI commands move from parsing to inventory loading, transport execution, audit logging, and recovery state.
- [Inventory Model](inventory-model.md): YAML schema, validation rules, and host selection behavior.
- [CLI Behavior](cli-behavior.md): command parsing, option support, output modes, and error rendering.

### Runtime Behavior

- [Update Recovery](update-recovery.md): persisted failure state, resume points, and recovery semantics.
- [Transport and SSH](transport-and-ssh.md): transport abstraction, SSH command behavior, and timeout semantics.
- [Audit Logging](audit-logging.md): audit logger types, log shape, and sanitization rules.
- [JSON Output Reference](json-output-reference.md): machine-readable payload shapes emitted by CLI commands.

### Development

- [Development Guide](development-guide.md): local workflow, testing expectations, and file layout conventions.
- [Testing Strategy](testing-strategy.md): how specs are organized and how transport-dependent behavior is tested safely.
- [Contributor Workflow](contributor-workflow.md): how to add or change features without breaking the safety model or repo structure.

## Intended Use

- Put design notes and codebase guides here instead of growing the top-level README indefinitely.
- Prefer focused documents by concern, such as CLI behavior, inventory rules, transport design, or update state handling.
- Keep docs close to the real implementation. When behavior changes, update the relevant page in this directory in the same change when practical.