#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  printf 'usage: %s /absolute/path/to/integration-inventory.yml\n' "$0" >&2
  exit 1
fi

inventory_path="$1"

if [[ ! -f "$inventory_path" ]]; then
  printf 'integration inventory not found: %s\n' "$inventory_path" >&2
  exit 1
fi

export HOMELAB_MANAGER_ENABLE_INTEGRATION_SPECS=1
export HOMELAB_MANAGER_INTEGRATION_INVENTORY="$inventory_path"

exec crystal spec spec/update_integration_spec.cr