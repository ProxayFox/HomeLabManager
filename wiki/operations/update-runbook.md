# Update Runbook

This runbook covers the safe progression from update planning to dry-run execution to real update execution, including recovery after a failed run.

## Goal

Use this workflow when you need to:

- preview the intended update steps for a host set,
- execute only the non-mutating parts of the workflow,
- run approved package upgrades,
- recover cleanly after a failed host update.

## Safety Sequence

The intended command progression is:

1. validate inventory,
2. verify connectivity,
3. build an update plan,
4. execute a dry run,
5. execute the real run only with explicit approval and `--execute`.

Do not skip directly to `updates run` unless you are intentionally bypassing the normal review flow.

## Step 1: Plan the Update

Build the plan for all hosts:

```sh
shards run homelab_manager -- updates plan
```

Plan a subset:

```sh
shards run homelab_manager -- updates plan --tag updates
shards run homelab_manager -- updates plan --group lab
```

Mark approval in the plan output:

```sh
shards run homelab_manager -- updates plan --approve
```

This command does not execute remote steps. It exists to show:

- which hosts are targeted,
- whether approval is pending or approved,
- which steps are enabled,
- which steps are blocked and why,
- whether resume context exists from a prior failed run.

Example plan output:

```text
Update plan: 1 host(s)
- atlas
	approval_state: pending
	approval_required: true
	step: refresh package index [ready]
		command: sudo apt-get update
	step: preview upgrades [ready]
		command: sudo apt-get -s upgrade
	step: apply upgrades [blocked]
		command: sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
		reason: manual approval required; rerun with --approve to mark this step approved
	step: check reboot-required flag [ready]
		command: test -f /var/run/reboot-required
```

## Step 2: Run the Dry Run

Execute the non-mutating path:

```sh
shards run homelab_manager -- updates dry-run
```

Dry run for a subset:

```sh
shards run homelab_manager -- updates dry-run --tag updates
```

The dry run:

- executes refresh, preview, and reboot-check steps,
- skips the mutating apply step,
- writes audit entries,
- stops later steps for a host after a failure.

Use this to validate real command behavior before attempting a mutating run.

Example dry-run output:

```text
Update dry-run: 1 host(s)
- atlas
	overall_status: succeeded
	approval_state: pending
	reboot_required: false
	action: update_refresh_package_index [succeeded]
		summary: package lists refreshed
		exit_code: 0
	action: update_preview_upgrades [succeeded]
		summary: 2 packages can be upgraded
		exit_code: 0
	action: update_apply_upgrades [skipped]
		summary: skipped in dry-run mode; manual approval required; rerun with --approve to mark this step approved
	action: update_check_reboot_required [succeeded]
		summary: reboot not required
		exit_code: 1
Summary: 1 succeeded, 0 partial, 0 failed
```

## Step 3: Execute the Real Run

Only run this when you are ready for the mutating step:

```sh
shards run homelab_manager -- updates run --approve --execute
```

Target a subset when needed:

```sh
shards run homelab_manager -- updates run --group lab --approve --execute
```

Both flags matter:

- `--approve` enables approval-gated mutating steps,
- `--execute` allows the CLI to proceed with the mutating command path at all.

Without `--execute`, the CLI refuses to run mutating updates.

Example run output:

```text
Update run: 1 host(s)
- atlas
	overall_status: succeeded
	approval_state: approved
	reboot_required: false
	action: update_refresh_package_index [succeeded]
		summary: package lists refreshed
		exit_code: 0
	action: update_preview_upgrades [succeeded]
		summary: preview ok
		exit_code: 0
	action: update_apply_upgrades [succeeded]
		summary: packages upgraded
		exit_code: 0
	action: update_check_reboot_required [succeeded]
		summary: reboot not required
		exit_code: 1
Summary: 1 succeeded, 0 partial, 0 failed
```

## After a Failure

If a host fails during `updates run`:

- later steps for that host are marked skipped,
- audit logs still capture the results that did run,
- recovery metadata is written to `state/update-runs.json`.

Later `updates plan`, `updates dry-run`, and `updates run` commands automatically reuse that persisted recovery context unless you override it.

## Resume a Failed Host

Let the CLI reuse persisted recovery state automatically:

```sh
shards run homelab_manager -- updates plan --approve
shards run homelab_manager -- updates dry-run --approve
shards run homelab_manager -- updates run --approve --execute
```

Override the resume point explicitly when needed:

```sh
shards run homelab_manager -- updates run --approve --resume-from update_apply_upgrades --execute
```

Supported resume points are documented in [Update Recovery](../runtime/update-recovery.md).

## What to Review After a Run

Check these artifacts after any meaningful run:

- terminal output for per-host overall status,
- `logs/audit.log` for the persisted audit trail,
- `state/update-runs.json` if a host failed and resume behavior matters.

## JSON Mode

All update commands support `--json`.

Use this when the workflow is being driven by scripts or external tooling:

```sh
shards run homelab_manager -- updates plan --json
shards run homelab_manager -- updates dry-run --json
shards run homelab_manager -- updates run --approve --execute --json
```

The payload shapes are documented in [JSON Output Reference](../reference/json-output-reference.md).