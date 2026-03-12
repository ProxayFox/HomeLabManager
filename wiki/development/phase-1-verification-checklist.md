# Phase 1 Verification Checklist

Use this checklist when deciding whether the current Phase 1 host-update workflow is ready to treat as stable.

It intentionally separates local repository verification from safe-host verification so routine development stays fast while real transport checks remain explicit.

## 1. Local Repository Checks

Run these on every substantive Phase 1 change:

```sh
crystal spec
shards build
```

These checks currently verify:

- unit and CLI behavior specs,
- update planner and runner behavior,
- persisted recovery-state behavior,
- Ameba linting,
- the Crystal file-length guard,
- successful binary compilation.

## 2. Update Workflow Spot Checks

Before a Phase 1 slice is considered ready, confirm at least these workflows still behave as expected:

1. `inventory validate` succeeds for a valid inventory and fails early for invalid input.
2. `hosts check` still behaves read-only and exits non-zero on probe failures.
3. `updates plan` stays non-executing and shows approval and resume context clearly.
4. `updates dry-run` skips the mutating step and still writes sanitized audit entries.
5. `updates run` still refuses to proceed without `--execute`.
6. A failed update run still persists host-scoped recovery metadata.
7. A successful rerun clears stale recovery state for the recovered host.

## 3. Safe-Host Integration Check

Run this only against a non-critical environment that is explicitly meant for validation.

Set:

- `HOMELAB_MANAGER_ENABLE_INTEGRATION_SPECS=1`
- `HOMELAB_MANAGER_INTEGRATION_INVENTORY=/absolute/path/to/integration-inventory.yml`

Then run:

```sh
crystal spec spec/update_integration_spec.cr
```

The integration harness currently verifies that:

- the real `SshTransport` can load the supplied inventory,
- update plans can be built for the selected hosts,
- the non-mutating update path can execute without mutating the host,
- each targeted host produces step results.

Do not point this at production or other critical hosts.

## 4. Operator-Facing Artifacts

After any meaningful update-path change, review:

- `logs/audit.log` behavior in a temporary or safe environment,
- `state/update-runs.json` behavior after a forced failure and successful rerun,
- JSON output changes against [../reference/json-output-reference.md](../reference/json-output-reference.md),
- any affected runbooks under [../operations/](../operations/).

## 5. Readiness Decision

Phase 1 is ready to declare complete only when all of these are true:

- local verification passes consistently,
- the safe-host integration check passes in a controlled environment,
- the update workflow safety invariants still hold,
- documentation matches the actual command and file layout,
- no known reliability gap remains in resume handling, audit logging, or execution guards.

Until then, treat Phase 1 as functionally complete but still under readiness hardening.