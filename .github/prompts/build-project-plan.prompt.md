---
description: "Inspect the current HomeLabManager state and produce a structured execution plan with phases, tasks, follow-up work, verification checkpoints, and staggered commit guidance."
name: "Build HomeLabManager Project Plan"
argument-hint: "Describe the feature, refactor, migration, or documentation effort to plan"
agent: "agent"
---

Build or update a HomeLabManager execution plan for the requested work.

Requirements:
- Inspect the current repository state, relevant source, specs, docs, and git status before proposing the plan.
- Structure the plan with explicit phases and tasks inside each phase.
- Keep phases outcome-oriented rather than file-oriented.
- For each phase, call out dependencies, verification steps, and likely follow-up work.
- Include commit guidance after each major task or phase using a staggered approach.
- Commits should be reviewable and coherent: not so small that they create noisy history, and not so large that debugging or blame becomes difficult later.
- Preserve the repository safety model when the work touches updates, inventory validation, SSH transport, or audit behavior.
- Do not describe future work as already implemented.

Plan structure:
1. Goal: short statement of the desired end state.
2. Constraints: repository rules, safety constraints, and known boundaries that matter.
3. Phase list: each phase should include:
   - phase objective,
   - tasks,
   - expected outputs or artifacts,
   - verification,
   - commit checkpoint guidance,
   - likely follow-up items required before the next phase.
4. Risks and open questions.
5. Suggested commit series: recommended commit groupings and messages.

Commit guidance rules:
- Prefer one commit per completed major task or tightly related task bundle.
- Use `git add -p` when a file mixes multiple concerns and the plan should land in separate commits.
- Call out when a phase is too large and should be split before implementation starts.
- Mention when follow-up cleanup should be its own later commit instead of being bundled into the main behavior change.

Output format:
1. Short overview.
2. Structured plan using `Phase 1`, `Phase 2`, and so on.
3. Per-phase task lists using `Task 1.1`, `Task 1.2`, and so on.
4. Commit checkpoints listed after the relevant phase.
5. Final section for follow-up work and deferred items.

User request:

"$ARGUMENTS"