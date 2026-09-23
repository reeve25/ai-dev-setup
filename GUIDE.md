# AI dev setup: how it works and how to use it

Written 2026-09-23 for Claude Code 2.1.281 and Codex CLI 0.155.1 on Windows 11.
Every command here was run on this machine or taken from current docs (Context7), not from memory.

---

## 1. How MCP actually works

**MCP (Model Context Protocol)** is a JSON-RPC 2.0 protocol between a *client* (Claude Code, Codex) and a *server*
(a small program that exposes tools, resources and prompts). The model never talks to the server; the client does.

```
you ─▶ Claude Code (MCP client) ─▶ model API
              │   ▲
    tools/list│   │ tool result (text/JSON goes into the context window)
              ▼   │
          MCP server (context7, supabase, playwright…)
```

Lifecycle of one session:
1. **initialize**: the client and server exchange versions and capabilities.
2. **tools/list**: the server returns each tool's `name`, `description` and a JSON Schema for its input.
3. The client **injects those definitions into the model's prompt**. This is the hidden cost.
4. When the model emits a tool call, the client sends **tools/call** to the server and pastes the result back into the context.

**Transports**
| | stdio | Streamable HTTP |
|---|---|---|
| Runs | a local child process (`npx …`, `uvx …`) | a remote URL |
| Auth | env vars in the config | OAuth (`/mcp` in Claude, `codex mcp login <name>`) or a bearer header |
| Cost | starts per session, uses your RAM | nothing local |
| Risk | runs code on your machine with your permissions | sees whatever you send it |

On Windows you no longer need the old `cmd /c npx` wrapper for stdio servers.

**Context cost is the real price.** Every tool definition is paid for on every request, even if the tool is never used.
A server with 25 tools can cost 5–15k tokens per turn. Two fixes:
- **Tool search (deferral):** the client sends only tool *names*, and the model loads a full schema when it needs one.
  Claude Code does this automatically against Anthropic's API, but **disables it for custom base URLs like 9router**.
  Your profile forces it back on with `ENABLE_TOOL_SEARCH=true`. Measured: 42.5k → 26.4k tokens per request.
- **Fewer servers.** If a CLI already does the job (`gh`, `supabase`, `psql`), the model can run the CLI through Bash
  at zero standing cost. That's why GitHub MCP is rejected below.

Check what you're paying: run `/context` inside Claude Code; it lists MCP tools and their token cost.

**Security model.** An MCP server's tool *descriptions* and *results* are text the model reads, so a malicious or
compromised server can inject instructions (a "tool poisoning" attack). Rules: install only first-party or high-reputation
servers, prefer read-only modes, scope database servers to a dev project, never give one production credentials.

---

## 2. How memory works

Neither tool "remembers" anything between sessions. Memory is **files that get loaded into the prompt at startup**.

**Claude Code**, loaded in this order (all are concatenated; more specific files win on conflicts):
| File | Scope | Notes |
|---|---|---|
| `~/.claude/CLAUDE.md` | you, every project | your global rules (36 lines) |
| `<repo>/CLAUDE.md` | project, committed | build/test commands, conventions |
| `<repo>/CLAUDE.local.md` | project, just you | gitignore it |
| `~/.claude/rules/*.md`, `.claude/rules/*.md` | modular rules | `paths:` frontmatter limits a rule to matching files |
| `~/.claude/projects/<proj>/memory/MEMORY.md` | **auto memory** | Claude writes it; the first 200 lines / 25KB load |

- `@path/to/file.md` inside a CLAUDE.md imports another file (max 4 hops). Imports load at launch, so they cost tokens every session.
- Claude reads `AGENTS.md` **only if there's no CLAUDE.md**. To share one file between both tools, put `@AGENTS.md` in CLAUDE.md.
- `/memory` opens these files; `#` at the start of a message saves a note.

**Codex**
| File | Notes |
|---|---|
| `~/.codex/AGENTS.md` | global (now the same text as your CLAUDE.md) |
| `<repo>/AGENTS.md`, nested `AGENTS.md` | concatenated from the repo root down to your cwd; `AGENTS.override.md` replaces instead |
| `~/.codex/memories/` | auto memories (on: `[features] memories = true` + `[memories]` in config.toml) |

- Codex caps project docs at `project_doc_max_bytes` (32 KiB).

**Rule of thumb:** memory files are a prompt you pay for on every turn. Put *commands and constraints* there, not essays.
If a line wouldn't change what the model does, delete it.

---

## 3. What's installed and why

| Piece | Where | Why it stays |
|---|---|---|
| **9router** (127.0.0.1:20128) | `%APPDATA%\9router` | One endpoint and a fallback chain (Opus 5.5 → Opus 5 → GPT-5.6 → Antigravity → Kiro → Flash). It falls back only on quota errors, not on 400s. |
| `claude` / `cc` / `claude9` | PowerShell profile | routed Claude with tool search on |
| `claude-direct` | PowerShell profile | Claude Pro subscription directly; use when the router misbehaves |
| `codex` / `codex9` | PowerShell profile | ChatGPT Plus directly, or via 9router (`~/.codex/9router.config.toml`) |
| **context7 MCP** | Claude + Codex, HTTP | Current library docs. 2 tools, deferred. It stops the model from hallucinating APIs. |
| Plugins: `feature-dev`, `commit-commands`, `code-review`, `ponytail` | `~/.claude/settings.json` | Guided feature workflow, `/commit`, `/code-review`, and the anti-over-engineering style |
| Skills: `review-diff`, `write-tests`, `explain-codebase`, `ship` | `~/.claude/skills`, `~/.agents/skills` | Your repeatable workflows (section 5) |
| `attribution: {commit:"", pr:""}` | Claude settings | no "Co-Authored-By: Claude" lines |
| Global + project CLAUDE.md / AGENTS.md | see section 2 | stack, Windows quirks, verify-before-done, secret rules |

**Codex attribution:** Codex's `Co-authored-by: Codex` trailer is an account setting, not a config key.
Turn it off in ChatGPT → Settings → Codex (commit attribution). AGENTS.md can't override it.

### Available but not installed (turn on when needed)
- **Supabase MCP**, for pinpoint. It needs your project ref and an OAuth login, so it can't be set up unattended:
  ```powershell
  cd C:\Users\reeve\dev\pinpoint-revamped
  claude mcp add --transport http --scope project supabase "https://mcp.supabase.com/mcp?project_ref=<REF>&read_only=true&features=database,debugging,development,docs"
  # then inside claude: /mcp → supabase → Authenticate
  codex mcp add supabase --url "https://mcp.supabase.com/mcp?project_ref=<REF>&read_only=true"; codex mcp login supabase
  ```
  `read_only=true` plus a project ref means the model can inspect the schema and run SELECTs but can't drop tables. Use a dev project.
- **Playwright MCP**: per project only (`--scope project`), for UI debugging. It costs ~20 tools of context, so keep it out of global config.
- **Chrome DevTools MCP**: `npx chrome-devtools-mcp@latest --slim --isolated` for performance/network debugging.
- **Semgrep** (`semgrep mcp`): static analysis, relevant to vulnerability-management work. Windows support is uncertain; try it in WSL first.
- **Cloudflare MCP**: its "Code Mode" server has 2 tools; only if you deploy on Cloudflare.

---

## 4. What was rejected and why

| Candidate | Verdict | Reason |
|---|---|---|
| **Headroom** | removed earlier, stays out | 0 prompt-cache hits in 825 requests; its compression rewrote prompts and broke caching. Cache reads are ~10× cheaper than fresh tokens, so it cost more than it saved. |
| **Serena** | removed earlier, stays out | Its LSP-backed tools add big standing tool-definition overhead. At your repo sizes (<200 files), grep + read is as good. Reconsider only for a 5k+ file codebase. |
| **OpenCode** | removed | a third agent CLI adds maintenance, not capability |
| **GitHub MCP** | skip | `gh` does everything (PRs, issues, Actions, API) through Bash at zero context cost. |
| **Postgres MCP** | skip | the official reference server is archived; Supabase MCP covers your DB |
| **Filesystem MCP** | skip | both CLIs already have native file tools |
| **Memory MCPs** (official memory, basic-memory, claude-mem, mem0) | skip | Built-in CLAUDE.md, auto memory and Codex memories cover it. If you ever want one memory store shared by Claude and Codex, **basic-memory** (plain Markdown files) is the pick. |
| **Sentry, AWS MCPs** | skip | you don't use those services yet |

The test for anything new: *does it do something the CLI + Bash can't, and is it worth its tokens on every single turn?*

---

## 5. Using it like a pro

### Plan before code (every non-trivial task)
- Claude: **Shift+Tab** twice (plan mode), or `claude --permission-mode plan`. It reads and proposes and can't edit until you approve.
- Codex: `/plan`, or just say "plan first, don't edit".
- The habit: *explore → plan → you edit the plan → implement → verify.* Most bad AI code comes from skipping the plan.

### Test-first
```
/write-tests test first: arb.py should reject a trade with an empty --give list
```
The skill writes the test and shows it failing, then implements the change and shows it passing. You review the test, not 200 lines of code.

### Review before every commit
```
/review-diff              # Claude: uncommitted changes
/review-diff main         # a branch vs main
codex review --uncommitted          # a second opinion from a different model family
codex review --base main
```
Two different models catch different bugs. For anything touching auth, money or SQL, run both.

### Ship
```
/ship
```
Secret scan → tests → explicit `git add` → conventional commit → push → `gh pr create`. It never force-pushes and never pushes to main.

### Subagents: keep the main context clean
A subagent runs in its own context and returns only its conclusion. Use one when an answer needs reading 20 files.
- Ad hoc: "use a subagent to find every caller of `get_deeplink` and summarize."
- Reusable: create `.claude/agents/security-reviewer.md`:
  ```markdown
  ---
  name: security-reviewer
  description: Reviews a diff for OWASP Top 10 issues and leaked secrets. Use before merging auth/DB changes.
  tools: Read, Grep, Glob, Bash
  ---
  You are an application security reviewer. For the given diff, report injection, broken auth, secrets,
  SSRF, insecure deserialization. Give file:line, exploit scenario, fix. No style nits.
  ```
  `/agents` manages them.

### Worktrees: parallel work without branch juggling
```powershell
claude -w fix-report-types      # new git worktree + branch; Claude works there
codex --worktree                # the same for Codex
git worktree list; git worktree remove <path>   # clean up after merging
```
Run one agent on a bug fix and another on a feature in separate worktrees at the same time. Put untracked files the worktree
needs (like `.env.local`) in `.worktreeinclude`.

### Hooks: rules that can't be ignored
CLAUDE.md is advice; a hook is enforcement. Example: block the agent from reading any `.env` file.
Save as `~/.claude/hooks/block-env.py`:
```python
import json, sys, re
p = json.load(sys.stdin).get("tool_input", {}).get("file_path", "")
if re.search(r"(^|[\\/])\.env(\.|$)", p):
    print("Blocked: .env files hold secrets", file=sys.stderr); sys.exit(2)   # exit 2 = block, stderr goes to the model
```
Add to `~/.claude/settings.json`:
```json
"hooks": { "PreToolUse": [ { "matcher": "Read|Edit|Write",
  "hooks": [ { "type": "command", "command": "python C:/Users/reeve/.claude/hooks/block-env.py" } ] } ] }
```
Check with `/hooks`. Codex hooks live in `~/.codex/hooks.json` and must be trusted via `/hooks` before they run.

### Headless: AI in scripts and CI
```powershell
claude -p "summarize what changed in the last 5 commits" --output-format json --permission-mode plan --max-budget-usd 0.50
claude -p "fix the type errors from: npx tsc --noEmit" --allowedTools "Read,Edit,Bash(npx tsc:*)" --max-budget-usd 1
codex exec "add a --json flag to arb.py scan and run selfcheck"
git diff | claude -p "review this diff for security issues"     # pipes work
```
For GitHub: `claude setup-token`, add it as the repo secret `CLAUDE_CODE_OAUTH_TOKEN`, then use `anthropics/claude-code-action@v1`
in a workflow, and `@claude` in a PR comment triggers a review.

### Daily loop
1. `cd` into the repo → `claude` (or `ffc` for fantasy).
2. New repo? `/explain-codebase`.
3. Plan mode → approve → implement with `/write-tests` for the logic.
4. `/review-diff`, plus `codex review --uncommitted` for risky changes.
5. `/ship`.
6. Anything you corrected twice goes into the project CLAUDE.md, so you never correct it a third time.

### Career angle
- **Cybersecurity / vuln management:** the security-reviewer subagent, Semgrep, and `codex review` on real diffs.
  Learn to read SARIF output and triage false positives; that's the job.
- **SWE:** test-first plus worktrees plus PR review is exactly the workflow modern teams expect you to have.
- **SRE/infra:** headless `claude -p` in GitHub Actions, and hooks as policy-as-code.

---

## 6. Exercises for this week (~20 min each)

1. **See the cost.** In `ff-arbitrage` run `claude`, then `/context`. Find the MCP tools line. Run `claude-direct` and compare.
2. **Test-first.** `/write-tests test first` for one pure function in `arb.py`. Watch it fail, then pass. Commit with `/ship` on a branch.
3. **Two reviewers.** Make a deliberate bug (an off-by-one) in pinpoint's `report2.tsx`. Run `/review-diff` and `codex review --uncommitted`.
   Did both catch it? Revert with `git restore`.
4. **Fix a real thing.** In pinpoint, plan mode: "fix the 2 real tsc errors (see CLAUDE.md)". Approve the plan, verify with `npx tsc --noEmit`.
5. **Worktree.** `claude -w readme-rewrite` in pinpoint and have it replace the Supabase starter README. Meanwhile work on something else in the main checkout.
6. **Write a hook.** Install the `.env` blocker from section 5, then ask Claude to "read .env". It should be blocked.
7. **Headless.** `git log -20 --oneline | claude -p "group these commits by theme"`. Then script it into a PowerShell function.
8. **Supabase MCP.** Add it read-only to pinpoint (section 3) and ask "which tables have RLS disabled?" That's a real security question.
