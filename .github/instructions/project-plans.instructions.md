---
description: "Use when creating or editing HomeLabManager plan files under .github/plans/. Covers phase/task structure, verification checkpoints, follow-up tracking, and staggered commit guidance."
name: "HomeLabManager Project Plans"
applyTo:
  - ".github/plans/**/*.md"
---

# HomeLabManager Plan Guidelines

- Structure plans around phases and tasks. Each phase should have a clear objective, and each task should describe a concrete unit of work.
- Prefer `Phase 1`, `Phase 2`, and `Task 1.1`, `Task 1.2` style numbering so follow-up discussion can refer to exact work items.
- Every phase should include the intended outcome, dependencies, verification steps, likely follow-up work, and any important scope boundaries before the next phase can begin.
- Separate immediate implementation work from deferred work. If something is intentionally postponed, label it clearly instead of letting it blur into the active phase.
- Include commit checkpoints after each major task or phase. Commit guidance should aim for reviewable changesets that are neither too small nor too large.
- Prefer one commit per major task or tightly related task bundle. If a file mixes multiple concerns, note that `git add -p` or a follow-up cleanup commit may be required.
- Call out repository constraints that affect the plan, especially the safety model around `updates plan`, `updates dry-run`, `updates run`, `--approve`, and `--execute`.
- Include phase-level risks and mitigation notes when the work is non-trivial, especially for update workflow changes, CLI contract changes, or file moves that can break docs and specs.
- For high-risk or stateful changes, note rollback or fallback options when they are realistic. If rollback is operational rather than automated, say so explicitly.
- Verification should be measurable where practical. Prefer concrete checks such as command passes, expected JSON fields, spec coverage targets, or specific operator-visible behavior over vague statements like `verify it works`.
- When a phase changes user-visible behavior, call out the expected documentation artifacts in that same phase, such as README updates, wiki pages, runbooks, or JSON output references.
- Include a short review checkpoint after major phases where the plan may be adjusted based on what was learned, new constraints, or repo drift.
- Note what is intentionally out of scope for a phase when that omission prevents scope creep or keeps the phase reviewable.
- Estimate effort or critical-path dependencies only when they materially affect sequencing. Do not force timeline guesses when the repo state is too uncertain.
- When a phase changes user-visible behavior, include the docs and spec follow-up work in the same phase or as an immediate next step.
- Do not describe unimplemented work as if it already exists. Plans are execution guides, not release notes.
- Keep plans actionable. Avoid vague tasks such as `improve architecture` unless they are broken into explicit deliverables.

## Suggested Phase Shape

Use a structure close to this when the work is substantial:

### Phase X: Clear Objective

- Outcome: measurable end state for the phase.
- Dependencies: prior phases, repo assumptions, or external prerequisites.
- In scope: what this phase is meant to deliver.
- Out of scope: what is intentionally deferred.
- Risks: likely blockers or integration issues, plus mitigations when useful.

#### Task X.Y: Specific Action

- Description: what will be changed.
- Acceptance criteria: how completion will be recognized.
- Expected artifacts: source files, specs, docs, or plan updates.
- Commit checkpoint: what should be committed when this task lands.

### Phase Verification

- Include concrete functional checks.
- Include non-functional checks when they matter, such as CLI output shape, safety-guard preservation, or docs consistency.

## Examples

Good:

```md
Phase 1: Split CLI Output Helpers

- Outcome: inventory and host output rendering no longer expands `cli.cr`.
- Dependencies: current CLI behavior remains unchanged.
- In scope: extract helper files and update requires.
- Out of scope: changing command semantics.
- Risks: broken JSON payloads or missed helper wiring.

Task 1.1: Extract inventory output methods
- Acceptance criteria: `crystal spec && shards build` passes and inventory text/JSON output is unchanged.
- Commit checkpoint: commit source extraction once helper wiring and specs are green.
```

Bad:

```md
Phase 1: Make things better
- Fix stuff
- Improve performance
```