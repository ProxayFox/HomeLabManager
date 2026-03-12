---
description: "Update HomeLabManager documentation after code or behavior changes by syncing the README, wiki pages, and workspace instructions with the current implementation."
name: "Sync HomeLabManager Docs"
argument-hint: "Describe the behavior, architecture, or workflow change that docs should reflect"
agent: "agent"
---

Update the repository documentation to match the requested code or behavior change.

Scope:
- Update the top-level [README.md](../../README.md) only when operator-facing usage, setup, or command examples changed.
- Update the relevant wiki pages under [wiki/](../../wiki/README.md) when architecture, command flow, inventory rules, or testing guidance changed.
- Update [.github/copilot-instructions.md](../copilot-instructions.md) only when the always-on workspace guidance is now outdated.
- Keep scoped instruction files under [../instructions/](../instructions/crystal-src.instructions.md) focused; do not duplicate README or wiki content into them.

Requirements:
- Prefer targeted documentation edits over broad rewrites.
- Preserve the distinction between operator docs, implementation docs, and AI customization guidance.
- If behavior changed, update examples and verification commands so they remain runnable.
- Do not invent features or future behavior that is not implemented.
- If a requested change does not affect current documentation, say so clearly instead of forcing edits.

Expected workflow:
1. Inspect the affected code paths and the nearest existing docs before editing.
2. Update only the documents that are now stale.
3. Keep terminology consistent with the current CLI and module names.
4. Summarize which docs changed and whether any documentation gaps still remain.

User request:

"$ARGUMENTS"