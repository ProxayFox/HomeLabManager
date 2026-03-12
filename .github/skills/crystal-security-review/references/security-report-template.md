# Security Report Template

Use this template when you want a consistent Crystal security review output.

```md
## Security Analysis Summary
- Files reviewed: <count>
- Critical issues: <count>
- High priority issues: <count>
- Total findings: <count>
- Review scope: <full codebase | changed files | targeted module>
- Review gaps: <none or concise note>

## Findings

### <Finding title> - <file:line>
Severity: <CRITICAL|HIGH|MEDIUM|LOW|INFO>
CWE: <identifier or N/A>
Affected flow: <entry point or trust boundary>
Why it matters: <impact and exploitability>
Evidence: <brief explanation tied to code>
Recommended fix: <specific safe change>
Verification: <spec, command, or review step>

## Best Practices Recommendations
- <cross-cutting improvement>

## Automated Security Integration
- <tests, CI checks, scanners, or monitoring>

## Residual Risks And Follow-Up
- <remaining uncertainty, operational mitigation, or next hardening step>
```

Guidance:

- Prefer concise evidence tied to a specific trust boundary or exploit path.
- Separate code fixes from operational mitigations when both matter.
- If no findings are present, keep the summary explicit and document any review gaps instead of inventing low-value issues.
