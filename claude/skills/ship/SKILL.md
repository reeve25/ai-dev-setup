---
name: ship
description: Commit the current work with a clean conventional message and open a GitHub pull request with gh, after a secret scan and test run. Use only when explicitly asked to ship, commit and PR, or open a PR.
disable-model-invocation: true
---

# Ship: commit + PR

Stop and report at the first failed step. Never force-push, never push to `main`/`master` directly, never add co-author or "Generated with" lines.

1. `git status --short` and `git branch --show-current`. On `main`/`master`: create a branch `git switch -c <type>/<short-slug>`.
2. Secret scan the changes: check `git diff HEAD` and untracked files for `.env*`, `*.pem`, `*.key`, `credentials*`, and strings that look like keys (`sk-`, `ghp_`, `eyJ` JWTs, `AKIA`, `*_API_KEY=`, `SUPABASE_*KEY`). Any hit: stop and show it (mask the value).
3. Run the project's tests/build (see CLAUDE.md/AGENTS.md or the manifest). Failing: stop and report.
4. Stage explicit paths only (`git add <paths>`), not `-A`. Show `git diff --cached --stat`.
5. Commit: `<type>: <imperative summary>` (≤ 72 chars; type is one of feat, fix, refactor, test, docs, chore). The body says why, not what.
6. `git push -u origin HEAD`.
7. `gh pr create --fill` or `--title/--body`. The body has: what changed, why, how it was tested (the actual command + result). Print the PR URL.
