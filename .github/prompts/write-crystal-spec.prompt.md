---
description: "Write or refine focused HomeLabManager Crystal specs for a described behavior change, following the repo's split CLI spec layout and safety-focused test patterns."
name: "Write HomeLabManager Spec"
argument-hint: "Describe the behavior, regression, or command path that needs spec coverage"
agent: "agent"
---

Write or update focused Crystal specs for the requested HomeLabManager behavior.

Requirements:
- Use the shared helpers in [spec/spec_helper.cr](../../spec/spec_helper.cr), especially `with_temp_inventory`, `with_temp_working_directory`, and `FakeTransport`, before creating new fixtures.
- Put CLI coverage in the nearest split spec file: [spec/cli_inventory_spec.cr](../../spec/cli_inventory_spec.cr), [spec/cli_hosts_spec.cr](../../spec/cli_hosts_spec.cr), or [spec/cli_updates_spec.cr](../../spec/cli_updates_spec.cr).
- Put non-CLI update execution coverage in [spec/updates_spec.cr](../../spec/updates_spec.cr) and recovery-persistence coverage in [spec/update_state_spec.cr](../../spec/update_state_spec.cr).
- Cover JSON output paths when the command supports `--json`.
- Prefer examples that verify the safety contract directly, including approval gates, non-mutating dry runs, `--execute` guards, resume behavior, and sanitized logging where relevant.
- Keep specs focused and split by concern rather than growing a catch-all test file.
- Run `crystal spec` after editing the tests. If production behavior changed too, run `shards build` as well.

Expected workflow:
1. Inspect the nearest existing spec and the production code that owns the behavior.
2. Add the smallest focused spec change that captures the requested behavior or regression.
3. Cover both success and failure paths when the bug or feature warrants it.
4. Report which spec file changed and what behavior is now protected.

User request:

"$ARGUMENTS"