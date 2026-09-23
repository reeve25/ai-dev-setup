---
name: explain-codebase
description: Produce a concise map of an unfamiliar repository: what it does, how to run it, entry points, data flow, and where to start reading. Use when onboarding to a repo or asked to explain this codebase/project.
---

# Explain codebase

Read before summarizing. Prefer `git ls-files` over directory walks (skips node_modules/venvs).

1. Identify: README, manifest (`package.json`, `pyproject.toml`, `requirements.txt`, `Makefile`, `CMakeLists.txt`), CI config, existing CLAUDE.md/AGENTS.md.
2. Find the entry points (main scripts, `app/` routes, CLI commands) and trace one real request or command end to end.
3. Output, in this shape and under ~60 lines:
   - **What it is**: one or two sentences.
   - **Run it**: exact install / dev / test / build commands, verified against the manifest (say which ones you actually ran).
   - **Layout**: the 5–10 files or dirs that matter, one line each.
   - **Flow**: the traced path as `a.py:func -> b.py:func -> ...`.
   - **Gotchas**: env vars needed (names only, never values), external services, anything surprising.
   - **Read first**: three files, in order, and why.
4. If asked, offer to save the Run/Gotchas parts as the project's CLAUDE.md (keep it under 60 lines).
