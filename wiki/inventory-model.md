# Inventory Model

The inventory file is the operator-controlled input to nearly every command in HomeLabManager. It defines which hosts exist, how they are reached over SSH, and which update policy applies to each host.

The implementation lives in [src/homelab_manager/inventory.cr](/workspaces/HomeLabManager/src/homelab_manager/inventory.cr).

## Primary Types

- `UpdatePolicy`: defines whether package index refresh, upgrade preview, manual approval, and reboot allowance are enabled.
- `InventoryDefaults`: holds the default `UpdatePolicy` applied when a host does not override it.
- `Host`: represents one host entry with address, SSH user, port, tags, groups, and optional per-host update policy.
- `InventoryFile`: the fully parsed inventory document with defaults and a host list.

## File Shape

The expected YAML structure is:

```yaml
defaults:
  update:
    refresh_package_index: true
    preview_upgrades: true
    require_manual_approval: true
    allow_reboot: false
hosts:
  - name: atlas
    address: 192.168.1.10
    ssh_user: ubuntu
    port: 22
    tags: [core, updates]
    groups: [lab]
    update:
      allow_reboot: true
```

All fields under `defaults` are optional because the Crystal structs provide defaults. The `hosts` array is required in practice because validation rejects an empty inventory.

## Validation Rules

`InventoryFile.validate!` enforces the safety checks that must pass before any connectivity or update command proceeds.

- `hosts` must contain at least one host.
- `hosts[i].name` must not be blank.
- `hosts[i].address` must not be blank.
- `hosts[i].ssh_user` must not be blank.
- `hosts[i].port` must be between 1 and 65535.
- Host names must be unique after trimming surrounding whitespace.

Validation failures are collected and raised as `InventoryError`, which lets the CLI render either readable terminal output or structured JSON errors.

## Effective Update Policy

Each host can override the inventory defaults partially or completely.

`Host#effective_update(defaults)` returns:

- the host-specific `update` block when present, otherwise
- the inventory default policy.

The rest of the system relies on this resolved policy rather than inspecting raw YAML fields repeatedly.

## Host Selection

Tag and group filtering is modeled by `HostSelection` in [src/homelab_manager/domain.cr](/workspaces/HomeLabManager/src/homelab_manager/domain.cr) and applied by `Inventory.select_hosts`.

The matching rules are:

- If no tags or groups are requested, all hosts are selected.
- If only tags are provided, a host matches when it contains any requested tag.
- If only groups are provided, a host matches when it contains any requested group.
- If both are provided, a host must match at least one requested tag and at least one requested group.

That gives the CLI a predictable filter model without adding a more complex query language yet.

## Error Boundaries

Inventory loading has two important responsibilities:

- normalize YAML parsing failures into `InventoryError`, and
- stop execution before any remote operation is attempted.

This makes inventory parsing the first hard safety boundary in the application.

## Why This Matters

The current architecture keeps a lot of complexity out of the rest of the system by resolving inventory concerns early.

- Connectivity checks receive a validated host list.
- Update planning receives hosts with known-good fields and an effective update policy.
- The CLI can keep command handlers small because inventory loading and selection are already centralized.