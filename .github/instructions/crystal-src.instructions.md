---
description: "Use when editing Crystal source files in src/, especially CLI commands, inventory parsing, transport code, update workflows, or audit logging. Covers HomeLabManager source layout, safety constraints, and Crystal-specific patterns."
name: "HomeLabManager Source"
applyTo: "src/**/*.cr"
---

# HomeLabManager Source Guidelines

- Keep public entrypoints in the top-level module file for that concern and extract supporting logic into adjacent files before a file approaches the 800-line limit.
- Preserve the current module boundaries: domain types in `domain.cr`, inventory parsing in `inventory.cr`, transport abstractions in `transport.cr`, connectivity checks in `connectivity.cr`, update flow in `updates.cr` and `updates/state.cr`, audit logging in `audit.cr`, and CLI dispatch in `cli.cr` plus `cli/error_output.cr`.
- If one command family's text or JSON rendering grows beyond a small helper, extract it under `src/homelab_manager/cli/` rather than leaving `cli.cr` as a mixed dispatch-and-rendering file.
- Prefer Crystal stdlib features such as `YAML::Serializable` and `JSON::Serializable` when they fit the model instead of custom parsing code.
- Keep command orchestration injectable through `Transport`, `Audit::Logger`, and `Updates::StateStore` so behavior can be tested without real SSH or filesystem state.
- Treat `config/inventory.yml`, `logs/audit.log`, and `state/update-runs.json` as operator-managed runtime data; do not add fixtures that depend on committing those files.
- Preserve the safety model: `inventory validate`, `hosts check`, `updates plan`, and `updates dry-run` must remain non-mutating, and mutating update execution must stay explicitly gated behind `--execute`.
- When extending CLI behavior, follow the existing command pattern in [src/homelab_manager/cli.cr](../src/homelab_manager/cli.cr): parse options centrally, support `--json` where the surrounding command family already does, and route failures through the structured error helpers.
- Prefer narrow, explicit command surfaces over abstractions aimed at a future web layer.
