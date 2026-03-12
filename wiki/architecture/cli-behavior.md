# CLI Behavior

The CLI is the narrow orchestration layer for HomeLabManager. It owns command parsing, command-specific option validation, output rendering, and process exit codes. Most business behavior is delegated to focused modules after the CLI has validated the request.

The implementation lives primarily in [src/homelab_manager/cli.cr](/workspaces/HomeLabManager/src/homelab_manager/cli.cr), with shared error rendering in [src/homelab_manager/cli/error_output.cr](/workspaces/HomeLabManager/src/homelab_manager/cli/error_output.cr).

## Entry and Dispatch

The executable entrypoint in [src/homelab_manager.cr](/workspaces/HomeLabManager/src/homelab_manager.cr) calls `HomeLabManager::CLI.run(ARGV)`.

`CLI.run` then:

1. checks for empty args and prints help,
2. inspects the top-level command,
3. dispatches to `run_inventory`, `run_hosts`, or `run_updates`,
4. returns an integer exit code instead of raising for normal command failures.

This keeps the CLI predictable for shell usage and automation.

## Supported Command Families

The current command groups are:

- `inventory`: validate and list inventory content.
- `hosts`: run connectivity checks.
- `updates`: plan, dry-run, or execute update workflows.

Each family has its own subcommand gate, and unknown subcommands are converted into user-facing errors rather than crashing.

## Option Parsing Model

The CLI uses a single shared parser, `parse_command_options`, for the common option set. The parser supports:

- an optional inventory path,
- repeated `--tag` filters,
- repeated `--group` filters,
- `--approve` for update-related approval state,
- `--execute` for mutating update runs,
- `--resume-from` for explicit update resume points,
- `--json` for machine-readable output.

Command handlers decide which of those options are allowed by passing flags into `parse_command_options`. Unsupported options are rejected as user errors.

## Selection Semantics

Inventory, connectivity, and update commands all share the same host-selection behavior.

- If no filters are supplied, all hosts are selected.
- `--tag` and `--group` can each be repeated.
- When both kinds of filters are present, a host must satisfy both the tag side and the group side.
- If no hosts match, the CLI returns exit code `1` and renders a selection error.

## Output Modes

The CLI supports two output styles.

### Human-Readable Output

Human-readable output is the default. It is optimized for terminal use and includes concise summaries such as:

- host counts,
- approval state,
- per-step status,
- exit codes where relevant,
- summary lines for success and failure totals.

### JSON Output

When `--json` is present on a command that allows it, the CLI emits structured payloads to `stdout` for successful execution.

Examples include:

- `inventory-validation`
- `inventory-list`
- `connectivity-check`
- `update-plan`
- `update-run`

The JSON path is intended for tooling and automation, so command handlers include metadata such as selected filters, host results, approval state, and persisted resume context when available.

## Error Rendering

Errors use a separate rendering path in [src/homelab_manager/cli/error_output.cr](/workspaces/HomeLabManager/src/homelab_manager/cli/error_output.cr).

### Text Errors

In human-readable mode, the CLI prints plain text errors to `stderr`. Some commands use a heading, such as inventory validation failures, followed by individual error lines.

### JSON Errors

In JSON mode, the CLI writes an `error` payload to `stderr` with:

- `category`
- `command`
- `subcommand`
- `errors`

Current error categories include:

- `usage`
- `inventory-validation`
- `selection`
- `execution-guard`

Example JSON error payload:

```json
{
	"type": "error",
	"category": "selection",
	"command": "hosts",
	"subcommand": "check",
	"errors": [
		"no hosts matched the requested filters",
		"groups: missing"
	]
}
```

That separation keeps successful machine-readable output on `stdout` and error payloads on `stderr`, which is the right behavior for shell pipelines and automation.

## Execution Guards

The CLI is responsible for several safety checks before update execution reaches the lower-level modules.

- Missing subcommands are rejected early.
- Unsupported options are rejected early.
- Inventory parsing errors stop execution before remote work.
- Empty host selections stop execution before remote work.
- `updates run` refuses to proceed without `--execute`.

Approval state is also surfaced by the CLI, but the step-level gating itself is implemented in the update planner.

## Why the CLI Stays Thin

The current design deliberately avoids burying command behavior inside deeply nested abstractions.

- The CLI owns request validation and presentation.
- The inventory module owns YAML parsing and host filtering.
- The transport layer owns SSH behavior.
- The updates module owns plan and run semantics.
- The state store owns recovery persistence.

This split makes the command surface easier to extend without making the runtime behavior harder to trace.