# Security Remediation Plan Template

Use this template when converting security findings into staged implementation work.

```md
## Remediation Overview
- Goal: <desired secure end state>
- Source findings: <audit prompt, report, PR review, or manual notes>
- Priorities: <critical first, then high, then medium, etc.>
- Constraints: <safety model, compatibility, operational constraints>

## Phase 1: Immediate Containment Or Guardrail Fixes
- Outcome: <what urgent risk is removed>
- Dependencies: <prerequisites>
- In scope: <urgent code or config changes>
- Out of scope: <deferred work>
- Risks: <integration or regression risks>

### Task 1.1: <specific change>
- Description: <what will change>
- Acceptance criteria: <how the fix is verified>
- Expected artifacts: <source, specs, docs>

## Phase 1 Verification
- [ ] <focused spec or command>
- [ ] <operator-visible behavior or JSON contract check>

Commit checkpoint:
- <reviewable commit message or grouping>

## Phase 2: Full Remediation And Regression Coverage
- Outcome: <root cause fixed and covered>
- Dependencies: <what Phase 1 enables>
- In scope: <code fixes, focused specs, state handling, redaction, etc.>
- Out of scope: <later hardening>
- Risks: <behavior drift, rollout concerns>

### Task 2.1: <specific remediation>
- Description: <what will change>
- Acceptance criteria: <testable checks>
- Expected artifacts: <source, specs, docs>

## Phase 2 Verification
- [ ] <relevant commands or spec suite>
- [ ] <security-sensitive workflow check>

Commit checkpoint:
- <reviewable commit message or grouping>

## Phase 3: Documentation And Hardening Follow-Up
- Outcome: <operators and contributors understand the new guardrails>
- Dependencies: <implemented fixes>
- In scope: <docs, prompts, instructions, CI checks, follow-up safeguards>
- Out of scope: <future security roadmap>
- Risks: <stale docs, incomplete coverage>

### Task 3.1: <specific doc or hardening step>
- Description: <what will change>
- Acceptance criteria: <how the update is verified>
- Expected artifacts: <wiki, README, prompts, CI config>

## Phase 3 Verification
- [ ] <doc alignment check>
- [ ] <CI or monitoring follow-up check>

Commit checkpoint:
- <reviewable commit message or grouping>

## Deferred Hardening And Open Questions
- <clearly separated non-blocking improvements>

## Suggested Commit Series
- <commit 1>
- <commit 2>
- <commit 3>
```

Guidance:

- Prefer containment first only when the vulnerability warrants it; otherwise start at root-cause remediation.
- Keep spec and documentation updates adjacent to the behavior change they verify or explain.
- State explicitly when a risk cannot be fully closed in one pass and requires operational mitigation in the meantime.