---
description: "Use when editing the HomeLabManager update workflow, including update planning, dry-run behavior, approval gates, resume handling, persisted recovery state, or update-related specs."
name: "HomeLabManager Updates"
applyTo:
  - "src/homelab_manager/updates.cr"
  - "src/homelab_manager/updates/**/*.cr"
  - "spec/update_planner_spec.cr"
  - "spec/update_runner_spec.cr"
  - "spec/update_integration_spec.cr"
  - "spec/update_state_spec.cr"
---

# HomeLabManager Update Workflow Guidelines

- Preserve the current step model: refresh package index, preview upgrades, apply upgrades, then check reboot-required state.
- Keep `updates plan` non-executing, `updates dry-run` non-mutating, and `updates run` explicitly gated behind `--execute`.
- Treat approval and execution as separate guards: approval controls whether the mutating step is enabled, while `--execute` controls whether mutating steps may run at all.
- Keep per-host failure handling predictable: once one step fails for a host, later steps for that host should become skipped rather than continuing opportunistically.
- When changing resume behavior, preserve both explicit `--resume-from` support and persisted recovery-state support through `Updates::StateStore`.
- Recovery state under `state/update-runs.json` should stay machine-readable and host-scoped. Successful reruns should clear stale failed state for that host.
- Reboot-required detection is normalized from the reboot-check command exit code. Preserve that mapping unless the command contract itself changes.
- Audit logging is part of the workflow contract. Update-related execution changes should continue to emit sanitized audit entries for each step.
- Extend or update [spec/update_planner_spec.cr](../spec/update_planner_spec.cr), [spec/update_runner_spec.cr](../spec/update_runner_spec.cr), [spec/update_integration_spec.cr](../spec/update_integration_spec.cr), and [spec/update_state_spec.cr](../spec/update_state_spec.cr) alongside behavior changes, especially for approval gates, skipped steps, partial failures, resume points, and persisted state cleanup.
