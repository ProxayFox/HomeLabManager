# Crystal Lang Playground

## Project Overview

- Language: Crystal
- Build tool: Shards (Crystal's dependency manager)
- Project type: Console application
- This repository is still close to the Crystal starter template

## Development Environment

- Uses devcontainer with Crystal language image
- Crystal 1.19.1 and Shards are available in the container
- Devcontainer `postCreateCommand` runs `shards install`

## Architecture

- Source code lives in `src/`
- Tests live in `spec/`
- Entry point and main target: `src/playground.cr`
- Project manifest: `shard.yml`
- There are no external dependencies yet

## Conventions

- Keep shard and target names lowercase in `shard.yml`; the current shard name is `playground`
- Keep Crystal module names CamelCase; the current top-level module is `Playground`
- Prefer minimal, direct Crystal code over framework-style abstractions unless the repo grows beyond a single console app
- Update template placeholders when touching them: `README.md`, `shard.yml` author metadata, and module documentation in `src/playground.cr`

## Build and Test

- Run the app with `shards run playground` or `crystal run src/playground.cr`
- Build the app with `shards build`; this writes the binary to `bin/playground` based on the target declared in `shard.yml`
- Run tests with `crystal spec`
- Keep the starter test suite passing; extend `spec/playground_spec.cr` or replace it with real tests as the template is customized
