---
name: crystal-security-review
description: 'Review Crystal code for security vulnerabilities and secure coding risks. Use when auditing Crystal apps, CLI tools, services, authentication flows, file handling, command execution, deserialization, secrets management, and input validation. Produces prioritized findings, remediation guidance, and ongoing security best-practice recommendations.'
argument-hint: 'Describe the Crystal codebase, feature area, or files to review and any threat model or constraints'
user-invocable: true
disable-model-invocation: false
---

# Crystal Security Review

Use this skill to run a structured security review of Crystal code and return actionable findings, safer implementation guidance, and follow-up hardening work.

## When To Use

- Security-auditing a Crystal codebase, feature, or pull request
- Reviewing file handling, shell execution, configuration loading, or network-facing code
- Checking authentication, authorization, secrets handling, or audit logging
- Looking for injection, traversal, unsafe deserialization, data disclosure, or denial-of-service risks
- Turning an ad hoc security prompt into a repeatable review workflow
- Auditing HomeLabManager transport, inventory, update execution, recovery state, or audit logging with repo-specific checks

## Inputs To Collect

- Scope of review: full codebase, changed files, or a targeted module
- Runtime and trust boundaries: CLI-only, service, web app, job runner, integration worker, or mixed
- Sensitive assets: credentials, tokens, host inventory, audit logs, filesystem paths, remote commands, or persisted state
- Operational constraints: dry-run guarantees, approval gates, recovery behavior, and backward-compatibility requirements

If the request does not define scope, default to the most security-critical entry points and data-handling paths first.

For this repository, load and apply the HomeLabManager-specific checklist in [./references/homelabmanager-security-checklist.md](./references/homelabmanager-security-checklist.md).

## Review Priorities

Start with the highest-risk Crystal components before expanding:

1. Entry points that accept operator, user, network, file, or environment input
2. Command execution, SSH, subprocess, and shell-adjacent code
3. File access, path construction, config parsing, and state persistence
4. Authentication, authorization, secrets, and audit logging
5. Serialization and deserialization boundaries for JSON, YAML, or custom formats
6. Concurrency, shared mutable state, and long-running process behavior

## Vulnerability Patterns To Check

### Input Validation And Injection

- SQL, shell, LDAP, NoSQL, or template injection via interpolation or unsafe concatenation
- Path traversal and unsafe path expansion
- Missing allowlists, schema validation, or type checks on external input
- Remote command construction that mixes trusted and untrusted values

### Cryptography And Secret Management

- Hardcoded credentials, keys, tokens, or connection strings
- Weak random number generation or predictable tokens
- Insecure hashing or deprecated crypto primitives
- Sensitive values logged, persisted, or exposed through exceptions

### Deserialization And Parsing

- Blind `from_json`, YAML parsing, or object materialization from untrusted input
- Missing validation after parsing
- Trusting config files, environment variables, or recovery state without integrity checks

### Error Handling And Disclosure

- Raw stack traces or internal exception details exposed to operators or users
- Error output that leaks filesystem paths, schema details, credentials, or host metadata
- Missing exception handling around security-critical actions

### Availability, State, And Concurrency

- Race conditions on shared state or run-state files
- Unbounded input sizes, retries, or loops that can cause denial of service
- Unsafe recovery flows, partial-write handling, or inconsistent audit trails

## Crystal-Specific Review Heuristics

- Prefer argument arrays with `Process.run` over shell interpolation
- Treat `system`, backticks, and shell-style command strings as high risk
- Review `File`, `Dir`, `Path`, and `File.expand_path` usage for traversal and trust-boundary mistakes
- Validate `YAML::Serializable` and `JSON::Serializable` inputs against business rules after parsing
- Check exception formatting and CLI output helpers for leaked internal details
- Review module-level constants and config-loading code for embedded secrets
- Inspect long-lived objects and shared state for race conditions or stale security decisions

## Review Procedure

1. Build context.
Read the repository instructions, identify the app type, main entry points, and the modules that transform untrusted input into commands, files, state, or output.

2. Map trust boundaries.
Trace where input enters, where privilege changes happen, and where data crosses into subprocesses, filesystems, remote hosts, logs, or persisted state.

3. Inspect high-risk flows first.
Prioritize shell execution, transport code, config and inventory parsing, update workflows, auth logic, and any recovery or resume paths.

4. Apply structured threat analysis.
Use STRIDE as a forcing function:
- Spoofing: identity or source trust mistakes
- Tampering: unsafe mutation of config, state, or commands
- Repudiation: missing or incomplete auditability
- Information Disclosure: leaked secrets or sensitive state
- Denial of Service: unbounded or fragile operations
- Elevation of Privilege: unsafe approval bypasses or privilege jumps

5. Validate controls.
Check for input validation, allowlists, parameterization, path normalization, approval gates, redaction, least privilege, and safe defaults.

6. Rate and prioritize findings.
Assign `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`, or `INFO` based on exploitability, impact, and operator context. Include a CWE when it is reasonably clear.

7. Propose concrete remediation.
Give specific code-level fixes, safer Crystal alternatives, and any necessary test, logging, or architecture follow-up.

8. Close with prevention work.
Recommend review checklist items, automated tests, CI scanning, and monitoring improvements that would prevent recurrence.

## Output Requirements

Return results in this structure:

```md
## Security Analysis Summary
- Files reviewed: <count>
- Critical issues: <count>
- High priority issues: <count>
- Total findings: <count>

## Findings
### <title> - <file:line>
Severity: <CRITICAL|HIGH|MEDIUM|LOW|INFO>
CWE: <identifier or N/A>
Why it matters: <impact and exploitability>
Evidence: <brief explanation tied to code>
Recommended fix: <specific safe change>
Verification: <test or review step>

## Best Practices Recommendations
- <cross-cutting improvement>

## Automated Security Integration
- <tests, CI checks, scanners, or monitoring>
```

Use [./references/security-report-template.md](./references/security-report-template.md) when the review should follow a fixed report shape.

Keep the review focused on real risks and likely abuse paths. Avoid padding the report with stylistic nits that do not materially affect security.

## Secure Coding Guidance To Prefer

- Parameterize database queries instead of interpolating strings
- Pass subprocess arguments as arrays instead of building shell commands
- Normalize and validate file paths against explicit safe roots
- Load secrets from environment or a secure store, then validate presence and format
- Redact secrets and sensitive identifiers from logs and operator-facing errors
- Validate parsed JSON and YAML against business invariants, not just types
- Keep audit logs complete for sensitive operations without recording secrets

## Completion Checklist

- Entry points and trust boundaries were identified
- High-risk Crystal modules were reviewed first
- Findings were severity-ranked and tied to evidence
- Remediation guidance included concrete safer alternatives
- Testing, CI, and monitoring follow-up was proposed
- Residual risks and review gaps were stated explicitly

## Repository References

- HomeLabManager checklist: [./references/homelabmanager-security-checklist.md](./references/homelabmanager-security-checklist.md)
- Security report template: [./references/security-report-template.md](./references/security-report-template.md)
- Security remediation plan template: [./references/security-remediation-plan-template.md](./references/security-remediation-plan-template.md)
- Companion remediation prompt: [../../prompts/plan-security-remediation.prompt.md](../../prompts/plan-security-remediation.prompt.md)

## Invocation Examples

- `/crystal-security-review audit the update workflow for command injection, path traversal, and approval bypass risks`
- `/crystal-security-review review changed Crystal files for secrets handling, YAML parsing safety, and sensitive error leakage`
- `/crystal-security-review perform a full security review of this Crystal CLI with emphasis on transport, inventory, state, and audit logging`
