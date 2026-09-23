---
name: review-diff
description: Review the current uncommitted changes (or a branch vs its base) for bugs, security issues, and missing tests before committing. Use when asked to review my changes, check the diff, or before a commit/PR.
---

# Review diff

1. Get the diff. Default: `git diff HEAD` plus `git status --short` for untracked files.
   If the user names a base (e.g. `main`), use `git diff <base>...HEAD`.
2. For every changed function, read the whole function and grep its callers. A diff alone hides context.
3. Report findings, most severe first. For each: `file:line`, what breaks, and a concrete input that triggers it.
   Check in this order:
   - Correctness: off-by-one, None/null paths, error handling that swallows failures, wrong types.
   - Security: secrets or `.env` values in the diff, injection (SQL, shell, HTML), unvalidated input at trust boundaries, auth checks.
   - Tests: new logic with no test or self-check; tests that can't fail.
   - Scope creep: changes unrelated to the stated goal, dead code, debug prints.
4. If nothing is wrong, say "No issues found" and name what you checked. Don't invent nitpicks.
5. Do not edit files unless asked. Offer the fix as a snippet.
