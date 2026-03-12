# Release and Build

This page covers the current build and versioning surface for HomeLabManager.

The project is still early-stage, so this is a lightweight release/build guide rather than a formal release engineering playbook.

## Current Package Identity

The shard definition in [shard.yml](/workspaces/HomeLabManager/shard.yml) currently declares:

- shard name: `homelab_manager`
- version: `0.1.0`
- target name: `homelab_manager`
- main entrypoint: `src/homelab_manager.cr`

These values matter because they shape the build output and the commands contributors use during local development.

## Standard Build Commands

Run the app through the declared target:

```sh
shards run homelab_manager
```

Build the binary:

```sh
shards build
```

Run the entrypoint directly with Crystal:

```sh
crystal run src/homelab_manager.cr
```

## Build Output

`shards build` writes the binary to:

- `bin/homelab_manager`

That path matches the target name in [shard.yml](/workspaces/HomeLabManager/shard.yml).

## Standard Verification Flow

Before treating a change as ready, run:

```sh
crystal spec && shards build
```

In this repository, `crystal spec` covers more than behavior specs. It also includes:

- Ameba static analysis,
- the enforced file-length check.

That means the standard verification flow checks both code behavior and repository conventions.

For the current Phase 1 readiness flow, use [Phase 1 Verification Checklist](phase-1-verification-checklist.md) as the canonical sequence for local verification plus safe-host dry-run checks.

## When to Change the Version

The current project version is defined in two places:

- [shard.yml](/workspaces/HomeLabManager/shard.yml)
- [src/homelab_manager/app.cr](/workspaces/HomeLabManager/src/homelab_manager/app.cr)

If the project version changes, those values should stay aligned.

The test suite also checks the current application version exposure, so mismatches are likely to be caught quickly.

## Suggested Release Checklist

The repository does not yet define a formal tagged-release process, but the minimum sensible checklist is:

1. Confirm the working tree is clean.
2. Run `crystal spec && shards build`.
3. Confirm the version is correct in `shard.yml` and `src/homelab_manager/app.cr`.
4. Review documentation changes that affect operator-facing workflows.
5. Build the final binary and verify its expected location under `bin/`.
6. If Phase 1 update behavior changed, run the opt-in safe-host integration check from [Phase 1 Verification Checklist](phase-1-verification-checklist.md).

## Current Constraints

The project does not yet document:

- a binary distribution channel,
- package-manager publishing,
- automated release pipelines,
- semantic versioning policy beyond the current declared version.

Until those exist, the main release concern is keeping the local build and verification process predictable and repeatable.