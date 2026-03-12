# JSON Output Reference

This document describes the machine-readable payloads currently emitted by the HomeLabManager CLI.

Successful payloads are written to `stdout`. Error payloads are written to `stderr` when `--json` is present.

## Success Payloads

### `inventory validate --json`

Type: `inventory-validation`

Fields:

- `type`: payload type string.
- `path`: inventory path used by the command.
- `valid`: always `true` for successful validation.
- `host_count`: number of parsed hosts.

Example:

```json
{
  "type": "inventory-validation",
  "path": "config/inventory.yml",
  "valid": true,
  "host_count": 2
}
```

### `inventory list --json`

Type: `inventory-list`

Top-level fields:

- `type`
- `path`
- `selection.tags`
- `selection.groups`
- `defaults.update`
- `hosts`

Each host object contains:

- `name`
- `address`
- `port`
- `ssh_user`
- `tags`
- `groups`
- `update`

Each `update` object contains:

- `refresh_package_index`
- `preview_upgrades`
- `require_manual_approval`
- `allow_reboot`

### `hosts check --json`

Type: `connectivity-check`

Top-level fields:

- `type`
- `path`
- `selection.tags`
- `selection.groups`
- `summary.succeeded`
- `summary.failed`
- `hosts`

Each host result contains:

- `host`
- `status`
- `exit_code`
- `summary`

### `updates plan --json`

Type: `update-plan`

Top-level fields:

- `type`
- `hosts`

Each host plan contains:

- `host`
- `resume_context`
- `approval_state`
- `approval_required`
- `steps`

Each step contains:

- `kind`
- `label`
- `command`
- `mutating`
- `enabled`
- `reason`

`kind` is emitted as an underscored step identifier, such as `refresh_package_index`.

`resume_context` is either `null` or an object with persisted recovery metadata.

### `updates dry-run --json`

Type: `update-dry-run`

Top-level fields:

- `type`
- `summary.succeeded`
- `summary.partial`
- `summary.failed`
- `hosts`

Each host run contains:

- `host`
- `resume_context`
- `overall_status`
- `approval_state`
- `reboot_required`
- `steps`

Each step result contains:

- `action`
- `status`
- `approval_state`
- `exit_code`
- `summary`

Even skipped mutating steps are present in the payload. In dry-run mode that makes the workflow shape explicit to automation.

### `updates run --json`

Type: `update-run`

This payload has the same shape as `update-dry-run`, but represents real execution rather than non-mutating execution.

## Resume Context Shape

When persisted recovery state exists for a selected host and the operator did not override it with `--resume-from`, `resume_context` is emitted as:

```json
{
  "source": "persisted",
  "resume_from": "update_apply_upgrades",
  "updated_at": "2026-03-12T12:34:56Z",
  "summary": "apt failed",
  "overall_status": "failed",
  "reboot_required": false
}
```

Otherwise the field is `null`.

## Error Payloads

When `--json` is present and a command fails, the CLI writes a JSON error object to `stderr`.

Shape:

- `type`: always `error`
- `category`: error category string
- `command`: command family when known
- `subcommand`: subcommand when known
- `errors`: array of human-readable error strings

Example:

```json
{
  "type": "error",
  "category": "execution-guard",
  "command": "updates",
  "subcommand": "run",
  "errors": [
    "Refusing to run mutating updates without --execute",
    "Use updates plan or updates dry-run first, then rerun with --execute when ready"
  ]
}
```

## Current Error Categories

The current code emits these categories:

- `usage`
- `inventory-validation`
- `selection`
- `execution-guard`

## Implementation Notes

The payload builders are split across these files:

- [src/homelab_manager/cli.cr](/workspaces/HomeLabManager/src/homelab_manager/cli.cr): inventory and connectivity success payloads.
- [src/homelab_manager/cli/update_output.cr](/workspaces/HomeLabManager/src/homelab_manager/cli/update_output.cr): update plan and run success payloads, including `resume_context`.
- [src/homelab_manager/cli/error_output.cr](/workspaces/HomeLabManager/src/homelab_manager/cli/error_output.cr): JSON error payloads.

If a payload shape changes, update this page and the matching CLI specs in the same change.