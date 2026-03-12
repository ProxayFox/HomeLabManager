# Inventory Runbook

This runbook covers the normal operator workflow for preparing and validating inventory before any remote command runs.

## Goal

Use this workflow when you need to:

- create a real inventory from the tracked example,
- validate changes before touching hosts,
- confirm which hosts are selected by tags or groups.

## Starting Point

The repository tracks [config/inventory.example.yml](/workspaces/HomeLabManager/config/inventory.example.yml) as the template.

The real working file should be:

- `config/inventory.yml`

That path is intentionally ignored by Git so real host details do not get committed accidentally.

## Create a Working Inventory

Start by copying the example file:

```sh
cp config/inventory.example.yml config/inventory.yml
```

Then edit `config/inventory.yml` with the real hosts, users, tags, groups, and any per-host update overrides.

## Validate Before Any Remote Action

Run:

```sh
shards run homelab_manager -- inventory validate
```

This validates:

- file presence,
- YAML syntax,
- required host fields,
- unique host names,
- valid port range.

If validation fails, stop there and fix the inventory before trying `hosts check` or any update command.

## Inspect the Selected Hosts

List all hosts:

```sh
shards run homelab_manager -- inventory list
```

Filter by tag:

```sh
shards run homelab_manager -- inventory list --tag core
```

Filter by group:

```sh
shards run homelab_manager -- inventory list --group lab
```

Combine filters:

```sh
shards run homelab_manager -- inventory list --tag updates --group lab
```

Use `--json` when you want machine-readable output for tooling.

Example text output:

```text
Hosts: 2
- atlas
	address: 192.168.1.10:22
	ssh_user: ubuntu
	tags: core,updates
	groups: lab
	update.refresh_package_index: true
	update.preview_upgrades: true
	update.require_manual_approval: true
	update.allow_reboot: false
```

Example JSON output:

```json
{
	"type": "inventory-list",
	"path": "config/inventory.yml",
	"selection": {"tags": [], "groups": []},
	"hosts": [
		{
			"name": "atlas",
			"address": "192.168.1.10",
			"port": 22,
			"ssh_user": "ubuntu",
			"tags": ["core", "updates"],
			"groups": ["lab"]
		}
	]
}
```

## What to Check in the Output

Before moving on to connectivity or updates, confirm that:

- the expected number of hosts is returned,
- each host has the correct address and SSH user,
- tags and groups match the intended targeting strategy,
- the effective update policy looks correct.

## Common Failure Cases

Typical inventory problems are:

- blank `name`, `address`, or `ssh_user`,
- duplicate host names,
- invalid YAML indentation or syntax,
- ports outside the valid TCP range,
- tag/group filters that match nothing.

If filters match nothing, the CLI returns a non-zero exit code and reports the filters that produced the empty selection.

## After Validation

Once the inventory validates and the host selection looks correct, the next safe step is the connectivity workflow in [Connectivity Runbook](connectivity-runbook.md).