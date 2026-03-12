# Quick Start Workflow

This page is the shortest safe path through the current HomeLabManager operator workflow.

Use it when you need a compact checklist rather than the more detailed runbooks.

## 1. Prepare the Inventory

Create the working inventory file:

```sh
cp config/inventory.example.yml config/inventory.yml
```

Edit `config/inventory.yml` with the real hosts, SSH users, tags, groups, and any per-host update overrides.

Validate it:

```sh
shards run homelab_manager -- inventory validate
```

If you need to inspect the selected hosts before going further:

```sh
shards run homelab_manager -- inventory list
```

## 2. Verify SSH Connectivity

Probe every configured host:

```sh
shards run homelab_manager -- hosts check
```

Or limit the scope:

```sh
shards run homelab_manager -- hosts check --tag updates
```

Do not move on to update planning until the connectivity check is clean for the intended target hosts.

## 3. Build the Update Plan

Preview the intended workflow:

```sh
shards run homelab_manager -- updates plan
```

If you want to see the approved path without executing it:

```sh
shards run homelab_manager -- updates plan --approve
```

## 4. Run the Dry Run

Execute the non-mutating workflow:

```sh
shards run homelab_manager -- updates dry-run
```

This runs the safe steps, skips `apply upgrades`, and writes audit entries.

## 5. Execute the Real Run

Only run this when you are ready for the mutating step:

```sh
shards run homelab_manager -- updates run --approve --execute
```

The two flags have separate meanings:

- `--approve` enables approval-gated mutating steps.
- `--execute` allows the mutating path to run at all.

## 6. Review the Results

After dry-run or execution, inspect:

- terminal output for host and step status,
- `logs/audit.log` for the audit trail,
- `state/update-runs.json` if a host failed and resume behavior matters.

## 7. Recover from a Failed Run

If a host fails during `updates run`, the later update commands can automatically reuse persisted recovery state.

Start by reviewing the plan again:

```sh
shards run homelab_manager -- updates plan --approve
```

If needed, override the resume point explicitly:

```sh
shards run homelab_manager -- updates run --approve --resume-from update_apply_upgrades --execute
```

## Related Pages

- [Inventory Runbook](inventory-runbook.md)
- [Connectivity Runbook](connectivity-runbook.md)
- [Update Runbook](update-runbook.md)
- [Troubleshooting](troubleshooting.md)