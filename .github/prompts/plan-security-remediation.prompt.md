---
description: "Turn HomeLabManager security findings into a staged remediation plan with implementation phases, focused specs, documentation updates, verification checkpoints, and reviewable commit guidance."
name: "Plan Security Remediation"
argument-hint: "Paste the findings, report summary, or feature area that needs a security remediation plan"
agent: "agent"
---

Build a HomeLabManager remediation plan for the provided security findings, audit notes, or threat model.

Primary workflow:
- Start from the security findings the user provided. If the findings are incomplete or ambiguous, inspect the current code and confirm the affected flows before planning.
- Use the HomeLabManager security review workflow in [../skills/crystal-security-review/SKILL.md](../skills/crystal-security-review/SKILL.md) to preserve the same trust-boundary framing and severity model.
- Use the report structure in [../skills/crystal-security-review/references/security-report-template.md](../skills/crystal-security-review/references/security-report-template.md) when you need to normalize or restate the findings before planning.
- Shape the final output as an implementation plan suitable for a markdown plan file, using the template in [../skills/crystal-security-review/references/security-remediation-plan-template.md](../skills/crystal-security-review/references/security-remediation-plan-template.md).

Planning requirements:
- Prioritize work by severity, exploitability, and trust-boundary impact rather than by file order.
- Separate immediate containment, code remediation, regression coverage, and longer-term hardening into distinct phases when that improves sequencing.
- Include the exact source, spec, and documentation areas likely to change when they are clear.
- Preserve HomeLabManager safety guarantees around dry-run behavior, approval gates, `--execute`, persisted state, and audit logging.
- Include measurable verification for every major task, such as focused specs, `crystal spec`, `shards run homelab_manager -- inventory validate`, JSON output expectations, or operator-visible command behavior.
- Include documentation follow-up in the same phase or the immediate next phase whenever the security fix changes operator behavior, recovery flow, CLI output, or documented safeguards.
- Call out rollback or fallback notes for high-risk fixes. If rollback is manual or operational, say so explicitly.
- Recommend reviewable commit checkpoints, and split large security work into staged commits instead of one large change.
- Distinguish confirmed fixes from deferred hardening work so the plan stays implementable.

Output structure:
1. Short overview of the security problem set and the intended end state.
2. Constraints and safety boundaries that the remediation must preserve.
3. `Phase 1`, `Phase 2`, and so on, with `Task 1.1`, `Task 1.2`, and so on.
4. For each phase, include outcome, dependencies, in-scope items, out-of-scope items when useful, risks, tasks, expected artifacts, verification, and commit checkpoints.
5. Final section for deferred hardening, open questions, and suggested commit series.

If the user only provides a high-level issue and not a concrete finding list, infer a minimal safe remediation plan from the current codebase and say where deeper verification is still needed.

User request:

"$ARGUMENTS"