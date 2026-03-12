# Copilot Customizations

This page explains how HomeLabManager organizes repository-scoped Copilot customizations under `.github/`.

The goal is to keep agent guidance discoverable and maintainable without mixing different kinds of instructions into one file.

## Directory Roles

HomeLabManager currently uses these customization layers:

- `.github/copilot-instructions.md`: always-on repository guidance.
- `.github/instructions/`: scoped instruction files matched to file types or concerns.
- `.github/prompts/`: reusable task-oriented prompts a contributor can invoke deliberately.
- `.github/plans/`: local or private planning material that should not be treated like committed workflow guidance.

## What Belongs Where

### `.github/copilot-instructions.md`

Use this file for stable repository-wide defaults such as:

- project identity,
- primary architecture boundaries,
- build and test commands,
- naming or safety conventions that apply broadly.

Do not turn it into a duplicate of the wiki.

### `.github/instructions/`

Use scoped instruction files when guidance should apply only to certain file types or concerns.

Examples already present in this repository include guidance for:

- Crystal source files,
- Crystal spec files,
- documentation,
- update workflow changes,
- project plan files,
- agent customization files themselves.

Good scoped instructions are:

- narrow in responsibility,
- keyword-rich in their `description`,
- aligned with the real source and spec structure.

### `.github/prompts/`

Use prompts for repeatable workflows that a contributor may want to invoke intentionally, such as:

- preparing a commit series,
- drafting release notes,
- building a phased project plan,
- walking through a focused review or authoring flow.

Prompts should stay executable and task-oriented. They should not become private notes or broad static policy dumps.

### `.github/plans/`

Use plans for local or private planning notes only.

These are not the same as prompts:

- prompts are shareable workflows,
- plans are working notes.

If a plan becomes broadly useful and repeatable, it probably belongs in the wiki or a prompt, not in `.github/plans/`.

## Relationship to the Wiki

The wiki under [wiki/README.md](../README.md) is the source of truth for repository documentation.

The `.github/` customizations should:

- point contributors toward the right wiki pages,
- encode concise workflow guidance for the agent,
- avoid copying large blocks of wiki content.

This keeps the human docs and the agent docs from drifting apart unnecessarily.

## Updating Customizations Safely

When changing repository structure or workflow conventions:

1. update the nearest wiki page first if the change affects human-facing documentation,
2. update only the customization file that owns that concern,
3. avoid copying the same explanation into multiple `.github/` files,
4. keep prompt files task-shaped and instruction files policy-shaped.

## Current Practical Rules

- keep one concern per prompt or instruction file when possible,
- keep descriptions concrete so the right customization is discoverable,
- update customization paths when source or spec files move,
- preserve the distinction between committed prompts and ignored plans,
- keep implementation roadmaps out of prompt files.

## Where to Look Next

If you are working on the docs or customization system itself, also see:

- [Development Guide](development-guide.md)
- [Contributor Workflow](contributor-workflow.md)
- [Testing Strategy](testing-strategy.md)

Planning-specific files in this repository:

- `.github/prompts/build-project-plan.prompt.md`
- `.github/instructions/project-plans.instructions.md`