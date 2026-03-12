# Live Host Validation Plan

This document defines how to validate HomeLabManager against a real non-critical machine before Phase 1 is considered fully complete.

## Goal

Use a real host to validate that the production `SshTransport`, the dry-run update flow, audit logging, and persisted recovery behavior work as expected outside of test doubles.

The target must be a disposable or low-risk asset, not a production system.

## Success Criteria

The live-host validation is successful when all of these are true:

- the host is reachable through the same SSH path the operator will use normally,
- `inventory validate` succeeds for the live-host inventory,
- `hosts check` succeeds for the selected host,
- `updates plan` produces the expected approval-aware plan,
- `updates dry-run` succeeds without mutating the host,
- audit logging and any recovery-state artifacts are sensible,
- if a controlled failure is introduced, resume behavior is understandable and host-scoped,
- any later approved mutating run is performed only by explicit operator choice.

## Candidate Host Requirements

Choose a host that meets these constraints:

- Ubuntu-based and representative of the intended fleet,
- reachable from the current operator environment with SSH keys or agent,
- safe to probe repeatedly,
- safe to snapshot, rebuild, or recover if testing goes wrong,
- not hosting critical workloads that would make reboot or package drift unacceptable.

Good candidates include a staging VM, a lab spare, or a short-lived cloud VM created specifically for validation.

## Setup Steps

1. Provision or identify a non-critical Ubuntu host.
2. Confirm the operator can connect with normal SSH credentials.
3. Copy [config/integration.inventory.example.yml](/workspaces/HomeLabManager/config/integration.inventory.example.yml) to an operator-managed path outside Git, such as `config/integration.inventory.yml`.
4. Replace the placeholder host fields with the real staging host values.
5. Validate the file:

```sh
shards run homelab_manager -- inventory validate /absolute/path/to/integration.inventory.yml
```

## Validation Sequence

Use this sequence in order.

### 1. Connectivity

```sh
shards run homelab_manager -- hosts check /absolute/path/to/integration.inventory.yml
```

### 2. Plan

```sh
shards run homelab_manager -- updates plan /absolute/path/to/integration.inventory.yml --approve
```

### 3. Dry Run via CLI

```sh
shards run homelab_manager -- updates dry-run /absolute/path/to/integration.inventory.yml --approve
```

### 4. Dry Run via Integration Spec Harness

```sh
scripts/run_update_integration_spec.sh /absolute/path/to/integration.inventory.yml
```

This is the repository's formal safe-host gate for the current Phase 1 plan.

It should fail against placeholder or unreachable hosts. A passing result means the dry-run path completed cleanly on the selected real host.

### 5. Optional Approved Mutating Run

Only if the operator explicitly decides the host is safe for a real package update:

```sh
shards run homelab_manager -- updates run /absolute/path/to/integration.inventory.yml --approve --execute
```

This step is not required to wire up the integration harness. Treat it as a separate operational decision.

## What to Record

Capture at least:

- the host identity and why it was considered safe,
- command outputs or summaries for `hosts check`, `updates plan`, and `updates dry-run`,
- audit log behavior under `logs/audit.log`,
- recovery-state behavior under `state/update-runs.json` if a failure was exercised,
- any SSH or timeout problems that differed from the fake-transport test path.

## Failure Handling

If live-host validation fails:

- stop before any mutating run,
- keep the inventory file for investigation but do not commit it,
- review [troubleshooting.md](troubleshooting.md),
- inspect `logs/audit.log` and `state/update-runs.json`,
- record whether the issue was transport, inventory, timeout, approval handling, or host-specific behavior.

## Out of Scope

This plan does not define:

- production rollout,
- unattended scheduled execution,
- multi-host concurrency,
- rollback automation.

Those remain later-phase concerns.