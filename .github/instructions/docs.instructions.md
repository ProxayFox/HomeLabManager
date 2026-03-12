---
description: "Use when editing HomeLabManager documentation in README.md, wiki/, or Copilot instruction markdown. Covers doc boundaries, terminology, and keeping implementation docs aligned with the current code."
name: "HomeLabManager Docs"
applyTo:
  - "README.md"
  - "wiki/**/*.md"
  - ".github/copilot-instructions.md"
---

# HomeLabManager Documentation Guidelines

- Keep the top-level `README.md` operator-facing: setup, usage, commands, and high-level project framing belong there.
- Keep implementation detail in `wiki/` rather than growing the README into an internal architecture document.
- Keep AI-agent guidance in `.github/copilot-instructions.md` and `.github/instructions/*.instructions.md`; do not duplicate large wiki sections into those files.
- Prefer updating the nearest focused wiki page, such as CLI behavior, transport, audit logging, update recovery, or JSON output, instead of sprinkling the same detail across multiple docs.
- Do not document future features as if they already exist. Planned work belongs in `.github/plans/`, not in committed operator or implementation docs unless clearly labeled as future work.
- When behavior changes, update examples and file references so they point at the current command names, spec layout, and source paths.
- Preserve the repo's terminology: `HomeLabManager`, `homelab_manager`, `updates plan`, `updates dry-run`, `updates run`, `--approve`, and `--execute`.
- Keep docs concise and navigable. Prefer index pages that link to focused documents over long all-in-one reference pages.
