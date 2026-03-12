---
description: "Use when creating or editing HomeLabManager plan files under .github/plans/. Covers phase/task structure, verification checkpoints, follow-up tracking, and staggered commit guidance."
name: "HomeLabManager Project Plans"
applyTo:
  - ".github/plans/**/*.md"
---

# HomeLabManager Plan Guidelines

- Structure plans around phases and tasks. Each phase should have a clear objective, and each task should describe a concrete unit of work.
- Prefer `Phase 1`, `Phase 2`, and `Task 1.1`, `Task 1.2` style numbering so follow-up discussion can refer to exact work items.
- Every phase should include the intended outcome, dependencies, verification steps, and the likely follow-up work needed before the next phase can begin.
- Separate immediate implementation work from deferred work. If something is intentionally postponed, label it clearly instead of letting it blur into the active phase.
- Include commit checkpoints after each major task or phase. Commit guidance should aim for reviewable changesets that are neither too small nor too large.
- Prefer one commit per major task or tightly related task bundle. If a file mixes multiple concerns, note that `git add -p` or a follow-up cleanup commit may be required.
- Call out repository constraints that affect the plan, especially the safety model around `updates plan`, `updates dry-run`, `updates run`, `--approve`, and `--execute`.
- When a phase changes user-visible behavior, include the docs and spec follow-up work in the same phase or as an immediate next step.
- Do not describe unimplemented work as if it already exists. Plans are execution guides, not release notes.
- Keep plans actionable. Avoid vague tasks such as `improve architecture` unless they are broken into explicit deliverables.