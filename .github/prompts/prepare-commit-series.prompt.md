---
description: "Review the current HomeLabManager worktree and propose a clean series of git add and git commit steps with messages that match the actual change groups."
name: "Prepare HomeLabManager Commits"
argument-hint: "Describe the scope or constraints for the commit split"
agent: "agent"
---

Prepare a commit plan for the current HomeLabManager worktree.

Requirements:
- Inspect the current git status and relevant diffs before proposing commit groups.
- Group files by coherent change intent rather than by directory alone.
- Prefer small, reviewable commits with clear messages.
- Call out any files that should stay unstaged because they are ignored, generated, or unrelated.
- If a file mixes multiple concerns, suggest whether `git add -p` is warranted.
- Do not actually run `git commit` unless the user explicitly asks for execution.

Output format:
1. Short overview of the recommended commit series.
2. For each commit: purpose, files to stage, and a proposed commit message.
3. Mention any risks or cleanup items that should be resolved before committing.

User request:

"$ARGUMENTS"