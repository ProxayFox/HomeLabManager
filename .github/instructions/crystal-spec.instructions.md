---
description: "Use when writing or editing Crystal specs in spec/. Covers HomeLabManager test helpers, fake transport usage, file-length rules, and focused behavior specs."
name: "HomeLabManager Specs"
applyTo: "spec/**/*.cr"
---

# HomeLabManager Spec Guidelines

- Keep specs focused by concern, matching the production split where practical, instead of growing catch-all files.
- Use the shared helpers in [spec/spec_helper.cr](../spec/spec_helper.cr), especially `with_temp_inventory`, `with_temp_working_directory`, and `FakeTransport`, before introducing new one-off fixtures.
- Prefer `FakeTransport` over real SSH execution for orchestration tests so command behavior stays deterministic and safe.
- When a feature touches CLI behavior, cover both human-readable and JSON output paths if the command supports `--json`.
- Add regression coverage near the affected concern, such as [spec/cli_inventory_spec.cr](../spec/cli_inventory_spec.cr), [spec/cli_hosts_spec.cr](../spec/cli_hosts_spec.cr), [spec/cli_updates_spec.cr](../spec/cli_updates_spec.cr), [spec/updates_spec.cr](../spec/updates_spec.cr), or [spec/update_state_spec.cr](../spec/update_state_spec.cr).
- Keep Crystal files under the enforced 800-line limit; if a spec file starts to sprawl, split it before the file-length check fails.
- Avoid tests that depend on committed operator data or live runtime state under `config/`, `logs/`, or `state/`.
