---
description: "Add or extend a HomeLabManager CLI command while following the repository's command parsing, safety, JSON output, and test patterns."
name: "Add HomeLabManager CLI Command"
argument-hint: "Describe the command or subcommand to add"
agent: "agent"
---

Implement the requested HomeLabManager CLI command or subcommand.

Requirements:
- Follow the existing dispatch and option-parsing patterns in [src/homelab_manager/cli.cr](../src/homelab_manager/cli.cr).
- Reuse the structured error behavior in [src/homelab_manager/cli/error_output.cr](../src/homelab_manager/cli/error_output.cr) when the new command can fail.
- Keep the safety model intact: do not introduce mutating behavior without explicit approval and `--execute` style guards when applicable.
- Prefer extending the existing domain, inventory, transport, connectivity, updates, or audit modules instead of adding a generic utility layer.
- Add or update focused specs under [spec/](../spec/) using the helpers in [spec/spec_helper.cr](../spec/spec_helper.cr).
- Run `crystal spec` after the change. If the command surface or build wiring changed, also run `shards build`.

Expected workflow:
1. Inspect the existing command family and nearby specs before editing.
2. Implement the smallest cohesive source change that fits the current module boundaries.
3. Add or update specs for success, failure, and JSON output where relevant.
4. Run verification commands and report the results clearly.

User request:

"$ARGUMENTS"