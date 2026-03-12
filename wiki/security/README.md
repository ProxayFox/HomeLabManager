# Security

This section documents the security requirements and best practices that must be followed when changing HomeLabManager.

Use these pages when work crosses a trust boundary, changes remote execution behavior, handles inventory or persisted state, writes audit logs, or changes approval and recovery flow.

## Documents

- [Project Security Requirements](project-security-requirements.md): the security model, mandatory requirements, trust boundaries, and verification expectations for the current codebase.

## How To Use This Section

- Read this section before changing inventory validation, transport behavior, update execution, recovery state, audit logging, or JSON and CLI error output.
- Treat the requirements here as project rules, not optional guidance, when a change affects operator trust or execution safety.
- Update the nearest security page in the same change when the implemented behavior or required safeguards change.