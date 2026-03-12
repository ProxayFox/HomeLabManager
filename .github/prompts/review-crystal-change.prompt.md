---
description: "Review a HomeLabManager Crystal change for bugs, safety regressions, JSON output drift, and missing spec or documentation updates."
name: "Review HomeLabManager Change"
argument-hint: "Describe the change, file set, or behavior to review"
agent: "agent"
---

Review the requested HomeLabManager change.

Review priorities:
- Look for behavioral bugs, safety regressions, or broken approval and execution guards first.
- Check whether non-mutating commands stayed non-mutating and whether mutating paths still require explicit approval and `--execute` where applicable.
- Verify JSON output behavior stayed aligned with the corresponding human-readable command path.
- Check whether update-workflow changes preserved resume behavior, per-host failure handling, reboot-required normalization, and audit logging expectations.
- Check for missing or weak spec coverage, especially in [spec/cli_inventory_spec.cr](../../spec/cli_inventory_spec.cr), [spec/cli_hosts_spec.cr](../../spec/cli_hosts_spec.cr), [spec/cli_updates_spec.cr](../../spec/cli_updates_spec.cr), [spec/update_planner_spec.cr](../../spec/update_planner_spec.cr), [spec/update_runner_spec.cr](../../spec/update_runner_spec.cr), [spec/update_integration_spec.cr](../../spec/update_integration_spec.cr), and [spec/update_state_spec.cr](../../spec/update_state_spec.cr).
- Check whether operator-facing or implementation docs should have been updated in [README.md](../../README.md), [wiki/README.md](../../wiki/README.md), [wiki/architecture/cli-behavior.md](../../wiki/architecture/cli-behavior.md), [wiki/runtime/update-recovery.md](../../wiki/runtime/update-recovery.md), [wiki/reference/json-output-reference.md](../../wiki/reference/json-output-reference.md), or [.github/copilot-instructions.md](../copilot-instructions.md).

Output format:
1. Findings first, ordered by severity.
2. For each finding, include the impacted file and a concise explanation of the risk or regression.
3. If there are no findings, say that explicitly.
4. After findings, list open questions or residual risks only if they matter.
5. Keep summaries brief and keep the primary focus on actionable findings.

User request:

"$ARGUMENTS"