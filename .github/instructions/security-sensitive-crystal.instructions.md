---
description: "Use when editing or reviewing HomeLabManager Crystal code that crosses trust boundaries, executes commands, parses config, persists state, writes logs, or handles approvals. Adds security and safety checks for transport, inventory, update workflows, and audit behavior."
name: "HomeLabManager Security-Sensitive Crystal"
applyTo:
  - "src/**/*.cr"
  - "spec/**/*.cr"
---

# HomeLabManager Security-Sensitive Crystal Guidelines

- Treat operator input, inventory data, persisted state, environment variables, and remote host output as untrusted until validated.
- Preserve the safety model: non-mutating commands stay non-mutating, and mutating update execution remains gated behind explicit approval and `--execute`.
- Prefer argument-array subprocess execution and transport abstractions over shell-interpolated command strings.
- Validate and normalize filesystem paths before reading or writing runtime-managed files such as inventory, audit logs, and update state.
- Do not leak secrets, host metadata, filesystem internals, or raw exceptions through CLI output, JSON output, or audit logs.
- Keep audit trails complete for security-relevant actions without logging credentials, tokens, or full sensitive payloads.
- Treat YAML and JSON parsing as only the first validation step; enforce business invariants after deserialization.
- When changing approval, resume, recovery, or failure-handling behavior, verify that partial runs remain attributable and safe to retry.
- Add or update focused specs for security-sensitive behavior changes rather than relying on broad regression coverage.
- When a change affects operator trust or threat boundaries, update the nearest prompt, instruction, or wiki page so the documented workflow stays accurate.
