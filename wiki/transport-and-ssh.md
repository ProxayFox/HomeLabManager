# Transport and SSH

HomeLabManager keeps remote execution behind a small transport abstraction so command orchestration can be tested without talking to real hosts.

The implementation lives in [src/homelab_manager/transport.cr](/workspaces/HomeLabManager/src/homelab_manager/transport.cr).

## Transport Contract

The abstract `Transport` class defines two operations:

- `probe(host, timeout_seconds)`: used for read-only connectivity checks.
- `run_command(host, action, command, timeout_seconds)`: used for arbitrary remote command execution.

Both return the shared `ExecutionResult` type from [src/homelab_manager/domain.cr](/workspaces/HomeLabManager/src/homelab_manager/domain.cr), which means connectivity checks and update steps report results in a consistent shape.

## Default Timeouts

The transport layer currently defines two defaults:

- connect timeout: `5` seconds
- command timeout value passed through the interface: `30` seconds

The connect timeout is applied directly to the SSH invocation through `ConnectTimeout`. The command timeout is modeled in the transport API and passed through the caller chain, even though the current SSH implementation does not yet enforce a separate remote execution timeout beyond what `ssh` itself provides.

## `SshTransport`

`SshTransport` is the production implementation. It shells out to the system `ssh` binary via Crystal's `Process.run`.

### Probe Behavior

`probe` is intentionally minimal. It calls `run_command` with:

- action: `connectivity_check`
- command: `true`

That means connectivity checks validate SSH reachability and command execution ability without mutating the remote host.

### SSH Arguments

The current SSH invocation uses these options:

- `BatchMode=yes`
- `NumberOfPasswordPrompts=0`
- `StrictHostKeyChecking=ask`
- `ConnectTimeout=<seconds>`
- `-p <host.port>`
- `<ssh_user>@<address>`
- the remote command string

The intent behind those settings is:

- avoid interactive password prompting,
- rely on the operator's existing SSH keys or agent,
- keep host key verification explicit rather than silently accepting unknown hosts,
- fail reasonably quickly on unreachable targets.

## Result Mapping

The transport collects both `stdout` and `stderr` into memory and then builds a summary string.

Summary selection follows this order:

1. first non-empty line from `stderr`, otherwise
2. first non-empty line from `stdout`, otherwise
3. `ssh connectivity ok` for successful commands, otherwise
4. `ssh connectivity failed` for unsuccessful commands without output.

The returned `ExecutionResult` includes:

- the host name,
- the action name supplied by the caller,
- `Succeeded` or `Failed` based on the process exit status,
- the exit code when available,
- the chosen summary message.

If the SSH process itself raises an exception, the transport returns a failed result with a summary like `ssh command failed: ...`.

## Why the Boundary Exists

The rest of the application does not need to know how remote commands are executed. That gives the codebase a clean split:

- the CLI decides what should happen,
- the updates module decides which step to run,
- the transport decides how a command reaches the remote host.

This separation also makes alternative transport implementations possible later if the project grows beyond direct SSH command execution.

## Testability

Specs do not depend on `SshTransport`. Instead they inject `FakeTransport` from [spec/spec_helper.cr](/workspaces/HomeLabManager/spec/spec_helper.cr).

That keeps transport-dependent tests:

- deterministic,
- fast,
- independent of network state,
- safe inside CI and the devcontainer.

## Current Constraints

The current transport layer is intentionally small and has some known limits:

- commands run sequentially,
- there is no connection reuse or pooling,
- SSH output is reduced to a short summary instead of preserving full streams,
- the API exposes a command timeout value, but the default implementation does not yet enforce a stronger timeout wrapper around the SSH process.

Those constraints are acceptable for the current MVP, where correctness and explicit behavior matter more than throughput.