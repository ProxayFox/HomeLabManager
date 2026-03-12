# Crystal Lang Template

This repository is a starter template for building Crystal console applications with a ready-to-use devcontainer, Shards configuration, and a minimal project layout.

Use it when you want to start a new Crystal project without rebuilding the container setup, compiler installation, editor extensions, and basic file structure from scratch.

## What This Template Includes

- Crystal 1.19.1 in a VS Code devcontainer
- Shards configured with a starter target in [shard.yml](shard.yml)
- Crystal source layout under [src/](src)
- Spec setup under [spec/](spec)
- Build output kept in [bin/](bin) through `shards build`
- Workspace instructions for AI-assisted editing in [.github/copilot-instructions.md](.github/copilot-instructions.md)

## Create a New Repository From This Template

1. On GitHub, click `Use this template` on the template repository.
2. Create your new repository from it.
3. Clone your new repository locally.
4. Rename the shard, target, module, and metadata placeholders to match your project.

Example:

```sh
git clone https://github.com/your-user/your-new-repo.git
cd your-new-repo
```

## Set Up The Project

You can work in either the devcontainer or a local Crystal installation.

### Option 1: VS Code Devcontainer

1. Open the repository in VS Code.
2. Reopen it in the devcontainer when prompted.
3. Wait for the container to finish building.
4. The container runs `shards install` automatically after creation.

The devcontainer also mounts your host SSH directory into the container so Git operations can use your existing SSH keys.

### Option 2: Local Crystal Setup

Install Crystal 1.19.1 or newer, then run:

```sh
shards install
```

## Common Commands

Run the app through the target defined in [shard.yml](shard.yml):

```sh
shards run playground
```

Run the entrypoint directly with Crystal:

```sh
crystal run src/playground.cr
```

Build the binary into [bin/](bin):

```sh
shards build
./bin/playground
```

Run the test suite:

```sh
crystal spec
```

## Customize The Template After Creating A Repo

Before using the generated repository for real work, update these placeholders:

- Project name and target in [shard.yml](shard.yml)
- Author metadata in [shard.yml](shard.yml)
- Module name and documentation in [src/playground.cr](src/playground.cr)
- Starter spec in [spec/playground_spec.cr](spec/playground_spec.cr)
- Repository-specific text in this README

## Project Structure

```text
.
├── .devcontainer/        # Devcontainer configuration
├── .github/              # Workspace-specific Copilot instructions
├── spec/                 # Test files
├── src/                  # Application source
├── bin/                  # Build output from shards build
├── shard.yml             # Shards manifest
└── README.md
```

## Notes

- `shards run playground` is correct. `shard run playground` is not.
- `crystal run` expects a source file path, so use `crystal run src/playground.cr`.
- `crystal spec` passes in the starter template and gives you a clean baseline before you add your own tests.
