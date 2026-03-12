# Connectivity Runbook

This runbook covers the safe, read-only SSH probe workflow used to confirm that the inventory can actually reach the selected hosts.

## Goal

Use this workflow when you need to:

- confirm SSH access before planning updates,
- narrow down which hosts are currently reachable,
- validate tag or group targeting against live connectivity.

## Prerequisites

Before running connectivity checks:

- make sure [Inventory Runbook](inventory-runbook.md) is complete,
- ensure `config/inventory.yml` contains the intended hosts,
- ensure your SSH keys or SSH agent are available in the current environment,
- ensure host key verification prompts have been handled where necessary.

The current transport uses batch mode and does not fall back to interactive password prompts.

## Run the Check

Check every host in the inventory:

```sh
shards run homelab_manager -- hosts check
```

Limit the check to a tag:

```sh
shards run homelab_manager -- hosts check --tag core
```

Limit the check to a group:

```sh
shards run homelab_manager -- hosts check --group lab
```

Use JSON output for automation:

```sh
shards run homelab_manager -- hosts check --json
```

Example success output:

```text
Connectivity check: 2 host(s)
- atlas: succeeded
	summary: ssh connectivity ok
	exit_code: 0
- backup: succeeded
	summary: ssh connectivity ok
	exit_code: 0
Summary: 2 succeeded, 0 failed
```

Example failure output:

```text
Connectivity check: 2 host(s)
- atlas: succeeded
	summary: ssh connectivity ok
	exit_code: 0
- backup: failed
	summary: connection refused
	exit_code: 255
Summary: 1 succeeded, 1 failed
```

## What the Command Does

The connectivity command:

- loads and validates inventory,
- filters the selected hosts,
- probes each host through the SSH transport,
- reports per-host success or failure,
- exits non-zero if any probe fails.

It does not run package or configuration changes.

## Interpreting Results

Successful output means:

- the host is reachable over SSH,
- the configured user, port, and address work,
- the remote host can execute a trivial command.

Failure output usually means one of:

- the host is unreachable on the network,
- the SSH port is incorrect,
- the user is wrong,
- the key or agent setup is missing,
- host key verification is blocking the connection,
- the host refuses the connection.

## If a Host Fails

Work through these checks in order:

1. confirm the host address, port, and `ssh_user` in the inventory,
2. confirm your SSH key or agent is available in the current shell or devcontainer,
3. test the host manually with `ssh` if needed,
4. resolve host key trust issues explicitly rather than weakening SSH checks,
5. rerun `hosts check` before planning updates.

## Next Step

After connectivity is clean for the target hosts, move to [Update Runbook](update-runbook.md) to plan or execute updates safely.