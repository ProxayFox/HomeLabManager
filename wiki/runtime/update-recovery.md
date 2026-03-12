# Update Recovery

HomeLabManager persists failure context for update runs so later commands can resume from the last failed step instead of always restarting from the beginning.

The implementation lives in [src/homelab_manager/updates/state.cr](/workspaces/HomeLabManager/src/homelab_manager/updates/state.cr), with CLI integration in [src/homelab_manager/cli.cr](/workspaces/HomeLabManager/src/homelab_manager/cli.cr).

## State File

Recovery data is stored in `state/update-runs.json` by default.

The state file contains:

- a file version,
- a per-host list of failed recovery entries,
- the failed action name,
- an update timestamp,
- an optional summary,
- the host's overall status,
- whether a reboot was known to be required.

The data model is represented by:

- `RecoveryStateEntry`
- `RecoveryStateFile`
- `Updates::StateStore`

Example state file fragment:

```json
{
	"version": 1,
	"hosts": [
		{
			"host_name": "atlas",
			"failed_action": "update_apply_upgrades",
			"updated_at": "2026-03-12T12:34:56Z",
			"summary": "apt failed",
			"overall_status": "failed",
			"reboot_required": false
		}
	]
}
```

## When State Is Written

Persisted recovery state is only updated during `updates run`.

- If a host run contains a failed step, that host gets a recovery entry.
- If a host later reruns successfully, its recovery entry is removed.
- Hosts are stored in sorted order by name when the state file is written.

`updates dry-run` does not write recovery state, even though it does produce audit logs.

## Resume Points

The resume mechanism is step-based. The current supported step names are:

- `update_refresh_package_index`
- `update_preview_upgrades`
- `update_apply_upgrades`
- `update_check_reboot_required`

`Updates.parse_resume_from` converts those action strings into `UpdateStepKind` values used by the planner.

## How Automatic Resume Works

When the operator does not pass `--resume-from`, the CLI asks `StateStore` for stored recovery entries for the selected hosts.

The CLI then:

1. loads the selected hosts,
2. reads any matching persisted recovery entries,
3. converts failed actions into resume points,
4. passes those points into `Updates.build_plans`.

That means later `updates plan`, `updates dry-run`, and `updates run` commands can automatically reflect where a failed host should restart.

## How Explicit Resume Works

If the operator passes `--resume-from`, the CLI uses that explicit step instead of persisted state.

This has two important consequences:

- the chosen resume point applies directly to the generated plans,
- persisted recovery entries are omitted from the JSON `resume_context` path because the source is no longer the saved state file.

This makes the operator override explicit and avoids blending automatic and manual recovery sources together.

Example `resume_context` fragment in command JSON output:

```json
{
	"resume_context": {
		"source": "persisted",
		"resume_from": "update_apply_upgrades",
		"updated_at": "2026-03-12T12:34:56Z",
		"summary": "apt failed",
		"overall_status": "failed",
		"reboot_required": false
	}
}
```

## Planner Behavior During Resume

Resume is implemented by disabling all steps before the chosen resume point.

- earlier steps become disabled,
- earlier steps carry the reason `skipped before resume point`,
- the resume step itself remains enabled,
- later steps remain enabled according to the normal approval and execution rules.

This logic lives in `Updates.apply_resume_from` inside [src/homelab_manager/updates.cr](/workspaces/HomeLabManager/src/homelab_manager/updates.cr).

## Relationship to Audit Logging

Recovery state and audit logging are separate concerns.

- Audit logs record executed step outcomes over time.
- Recovery state stores only the minimal data needed to continue from a failure.

Keeping them separate avoids overloading the audit log as a control-plane state store.

## Test Coverage

The main persistence behavior is covered by [spec/update_state_spec.cr](/workspaces/HomeLabManager/spec/update_state_spec.cr).

Current specs verify that:

- failed host runs are stored as resume points,
- successful reruns clear stored recovery entries.

Related CLI coverage in [spec/cli_updates_spec.cr](/workspaces/HomeLabManager/spec/cli_updates_spec.cr) verifies that persisted recovery context is surfaced in JSON plan output.
