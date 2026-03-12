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
- For each phase, call out dependencies, scope boundaries, verification steps, likely follow-up work, and risks when they matter.
- Include commit guidance after each major task or phase using a staggered approach.
- Commits should be reviewable and coherent: not so small that they create noisy history, and not so large that debugging or blame becomes difficult later.
- Preserve the repository safety model when the work touches updates, inventory validation, SSH transport, or audit behavior.
- When user-visible behavior changes, include the corresponding spec and documentation work in the same phase or as the immediate next step.
- Prefer measurable verification and acceptance criteria where practical, such as command output, JSON payload expectations, passing checks, or operator-visible behavior.
- Include rollback or fallback notes for high-risk changes when realistic. If rollback would be manual or operational, say that clearly.
- Include a short review checkpoint after major phases when the plan should be re-evaluated based on what was learned.
- Estimate effort or critical-path sequencing only when it materially improves the plan; avoid fake precision.
- When the work is substantial enough to deserve an implementation plan, make the output suitable for a committed or local plan file under `.github/plans/`.
- Do not describe future work as already implemented.

Plan structure:
1. Goal: short statement of the desired end state.
2. Constraints: repository rules, safety constraints, and known boundaries that matter.
3. Phase list: each phase should include:
   - phase objective,
   - intended outcome,
   - dependencies,
   - in-scope items,
   - out-of-scope items when useful,
   - risks or blockers,
   - tasks,
   - expected outputs or artifacts,
   - verification and acceptance criteria,
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
4. For each task, include acceptance criteria and the expected files or artifacts when they are clear.
5. Commit checkpoints listed after the relevant phase.
6. Final section for follow-up work, deferred items, and open questions.

Use this level of specificity for substantial work:

```md
Phase 1: [Clear Objective]

- Outcome: [measurable deliverable]
- Dependencies: [prerequisites]
- In scope: [what this phase covers]
- Out of scope: [what is intentionally deferred]
- Risks: [key blockers and mitigations]

Task 1.1: [Specific action]
- Description: [what will be done]
- Acceptance criteria: [how completion is verified]
- Expected artifacts: [source/spec/docs]

Phase 1 Verification:
- [ ] [testable criteria]

Commit checkpoint:
- [recommended commit grouping and message]
```

User request:

"$ARGUMENTS"