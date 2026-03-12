# Audit Logging

HomeLabManager writes structured audit entries for update execution so operators can review what happened without depending on terminal scrollback.

The implementation lives in [src/homelab_manager/audit.cr](/workspaces/HomeLabManager/src/homelab_manager/audit.cr). Audit behavior is exercised by specs in [spec/updates_spec.cr](/workspaces/HomeLabManager/spec/updates_spec.cr).

## Logger Types

The audit module exposes a small logger interface:

- `Audit::Logger`: abstract base class for audit sinks.
- `Audit::NullLogger`: no-op implementation used when persistence is unnecessary, especially in tests.
- `Audit::FileLogger`: JSON-lines logger used by the normal runtime path.

This mirrors the same design choice used elsewhere in the codebase: keep the orchestration path independent from the concrete persistence implementation.

## Default Location

The file logger writes to `logs/audit.log` by default.

When writing an entry, it ensures the destination directory exists before appending a line. That keeps logging resilient even when the log path has not been created yet.

## Log Format

Each entry is written as one JSON object per line. The current fields are:

- `timestamp`
- `operator`
- `host`
- `address`
- `action`
- `step_label`
- `status`
- `approval_state`
- `exit_code`
- `command`
- `summary`

This format is compact enough for line-oriented tooling while still being readable in plain text.

Example log line:

```json
{
	"timestamp": "2026-03-12T12:34:56Z",
	"operator": "tester",
	"host": "atlas",
	"address": "192.168.1.10",
	"action": "update_preview_upgrades",
	"step_label": "preview upgrades",
	"status": "succeeded",
	"approval_state": "pending",
	"exit_code": 0,
	"command": "sudo apt-get -s upgrade",
	"summary": "2 packages can be upgraded"
}
```

## Operator Name

`FileLogger` resolves the operator name from the environment:

- `USER`, otherwise
- `USERNAME`, otherwise
- `unknown`

The operator value can also be provided explicitly when constructing the logger, which is useful in tests.

## Sanitization Rules

The logger sanitizes `step_label`, `command`, and `summary` before writing them.

The current sanitization pass:

- redacts values that look like `password=...`, `passwd=...`, `token=...`, or `secret=...`,
- normalizes whitespace down to single spaces,
- trims leading and trailing whitespace,
- truncates long values to `200` bytes and appends `...`.

The redaction pattern is intentionally simple and conservative. It is meant to reduce accidental leakage of obvious secret-like fields in command summaries, not to serve as a full data-loss-prevention system.

## When Logging Happens

Update execution is the current source of audit entries.

- `updates dry-run` writes audit entries for each step result, including skipped steps.
- `updates run` also writes audit entries for each step result.

The update runner calls the logger after each step result is produced. That means the log captures partial progress even when a later step fails.

## Separation from Recovery State

Audit logging and recovery state are different persistence paths.

- Audit logs are append-only operational history.
- Recovery state in `state/update-runs.json` is the small control-plane file used for resume behavior.

Keeping them separate avoids treating a human-auditable log as the system's source of truth for control flow.

## Test Coverage

The main audit logging behavior is covered in [spec/updates_spec.cr](/workspaces/HomeLabManager/spec/updates_spec.cr), which verifies that:

- dry-run execution writes log entries,
- secret-like values such as `token=abc123` are redacted,
- the configured operator name is written to the log.

## Current Limits

The logger is intentionally minimal.

- it writes only to a local file,
- it stores summarized command output instead of full remote streams,
- it uses a small fixed set of redaction patterns,
- it does not rotate logs or manage retention.

That is enough for the current MVP and leaves room for later expansion if audit requirements become stricter.