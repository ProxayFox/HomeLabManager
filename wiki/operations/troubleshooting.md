# Troubleshooting

This page collects the most common operator and contributor failure modes in the current HomeLabManager workflow.

## Inventory Problems

### Symptom

`inventory validate`, `hosts check`, or an update command fails before any remote work starts.

### Likely Causes

- `config/inventory.yml` does not exist.
- YAML indentation or syntax is invalid.
- A host is missing `name`, `address`, or `ssh_user`.
- Two hosts share the same name.
- A host port is outside the valid TCP range.

### What to Do

1. Start from [config/inventory.example.yml](/workspaces/HomeLabManager/config/inventory.example.yml) if the file shape is unclear.
2. Run:

```sh
shards run homelab_manager -- inventory validate
```

3. Fix the reported fields before attempting connectivity or update commands.
4. Use [Inventory Runbook](inventory-runbook.md) as the normal inventory preparation workflow.

Example validation failure:

```text
Inventory validation failed:
- hosts[0].name must not be blank
- hosts[0].ssh_user must not be blank
```

## Empty Host Selection

### Symptom

The CLI reports `no hosts matched the requested filters`.

### Likely Causes

- the chosen `--tag` value is wrong,
- the chosen `--group` value is wrong,
- tags and groups were combined in a way that excludes all hosts.

### What to Do

1. List the inventory without filters.
2. Re-run `inventory list` with just one filter type at a time.
3. Confirm that the targeted hosts actually contain the requested tags or groups.

Example:

```sh
shards run homelab_manager -- inventory list
shards run homelab_manager -- inventory list --tag updates
shards run homelab_manager -- inventory list --group lab
```

## SSH Connectivity Failures

### Symptom

`hosts check` reports failed hosts or returns a non-zero exit code.

### Likely Causes

- wrong host address, port, or user,
- SSH key or agent is unavailable,
- host key verification is blocking the connection,
- the remote host refuses or drops the connection,
- the host is offline or unreachable on the network.

### What to Do

1. Confirm the host data in `config/inventory.yml`.
2. Confirm your SSH key or agent is available in the current shell or devcontainer.
3. Test the host manually with `ssh` if needed.
4. Resolve host key trust issues explicitly instead of weakening SSH safety checks.
5. Re-run:

```sh
shards run homelab_manager -- hosts check
```

See [Connectivity Runbook](connectivity-runbook.md) for the normal connectivity workflow.

Example connectivity failure:

```text
Connectivity check: 1 host(s)
- atlas: failed
	summary: connection refused
	exit_code: 255
Summary: 0 succeeded, 1 failed
```

## `updates run` Refuses to Execute

### Symptom

The CLI reports that it is refusing to run mutating updates.

### Likely Cause

`--execute` was not provided.

### What to Do

Use the normal sequence:

```sh
shards run homelab_manager -- updates plan
shards run homelab_manager -- updates dry-run
shards run homelab_manager -- updates run --approve --execute
```

The command intentionally requires `--execute` so mutating behavior is never triggered by accident.

Example execution guard error:

```text
Refusing to run mutating updates without --execute
Use updates plan or updates dry-run first, then rerun with --execute when ready
```

## Update Step Is Blocked

### Symptom

The update plan shows `apply upgrades` as blocked.

### Likely Cause

The host requires manual approval and `--approve` was not provided.

### What to Do

Review the plan, then rerun with approval when appropriate:

```sh
shards run homelab_manager -- updates plan --approve
```

Approval and execution are separate guards. Approval enables the step. `--execute` allows mutating execution.

## Failed Update Run and Resume Confusion

### Symptom

An update failed, and a later command appears to skip earlier steps or shows resume context unexpectedly.

### Likely Cause

Persisted recovery state exists under `state/update-runs.json` for one or more selected hosts.

### What to Do

1. Inspect the update plan again.
2. If needed, inspect `state/update-runs.json` directly.
3. Decide whether to accept the persisted resume point or override it with `--resume-from`.

Example:

```sh
shards run homelab_manager -- updates plan --approve
shards run homelab_manager -- updates run --approve --resume-from update_apply_upgrades --execute
```

See [Update Recovery](../runtime/update-recovery.md) and [Update Runbook](update-runbook.md) for the full recovery flow.

Example persisted resume context in JSON:

```json
{
	"resume_context": {
		"source": "persisted",
		"resume_from": "update_apply_upgrades",
		"summary": "apt failed",
		"overall_status": "failed"
	}
}
```

## Audit Log Questions

### Symptom

You want to confirm what happened during dry-run or execution.

### What to Do

Inspect:

- `logs/audit.log` for the append-only audit trail,
- `state/update-runs.json` for current recovery state when failures occurred.

See [Audit Logging](../runtime/audit-logging.md) for the log format and sanitization rules.

## JSON Output Questions

### Symptom

You are integrating the CLI with tooling and need to know what a payload field means.

### What to Do

Use [JSON Output Reference](../reference/json-output-reference.md), which documents:

- success payload types,
- error payload shape,
- `resume_context`,
- update step result fields.

## Build or Test Failures

### Symptom

Local verification fails while you are changing docs or code.

### What to Do

Run the standard repository checks:

```sh
crystal spec
shards build
```

If `crystal spec` fails, remember it also includes:

- Ameba static analysis,
- the file-length guard.

That means a failure may be caused by formatting, linting, or repository conventions rather than a runtime bug.