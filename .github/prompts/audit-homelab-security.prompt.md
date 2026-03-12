---
description: "Run a HomeLabManager-focused Crystal security audit covering transport, inventory, update execution, state recovery, audit logging, and approval boundaries."
name: "Audit HomeLabManager Security"
argument-hint: "Describe the files, command path, feature area, or threat model to audit"
agent: "agent"
---

Run a security review of the requested HomeLabManager scope.

Primary workflow:
- Use the workspace skill at [../skills/crystal-security-review/SKILL.md](../skills/crystal-security-review/SKILL.md) as the main review procedure.
- Load the HomeLabManager checklist at [../skills/crystal-security-review/references/homelabmanager-security-checklist.md](../skills/crystal-security-review/references/homelabmanager-security-checklist.md) and apply the repo-specific focus areas.
- Inspect the current code, specs, and any nearby docs before drawing conclusions.

Review priorities:
- Check whether inventory parsing, host selection, config loading, and persisted state treat operator input as untrusted until validated.
- Review transport and update code for command injection, argument escaping, approval bypass, unsafe resume behavior, and partial-failure handling.
- Confirm dry-run, plan, and validation paths remain non-mutating and that execution still requires explicit approval and `--execute` where applicable.
- Review audit logging and CLI error output for sensitive-data leakage, missing attribution, or incomplete failure reporting.
- Check file and path handling around inventory, logs, scripts, and state for traversal, clobbering, or unsafe trust in runtime-managed files.
- Call out missing spec coverage or stale documentation when security-sensitive behavior changed.

Output requirements:
1. Findings first, ordered by severity.
2. For each finding, include the impacted file, the risk, and a concrete remediation path.
3. If there are no findings, say that explicitly and list residual risks or review gaps only if they matter.
4. End with targeted hardening follow-up for tests, CI, or operational safeguards when warranted.

User request:

"$ARGUMENTS"
