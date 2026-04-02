---
name: done
description: Commit work, save session state, and end session
---

# End Session

Commit work, save state, clean up. Fast and focused.

## Process

### 1. Kill Orphan Processes

Kill any zombie processes from this session (forge runs, codex spawns, background agents).
Do NOT kill processes attached to the current Claude Code session (pts/3, pts/4 etc with Sl+ state).

```bash
# Kill orphaned codex exec processes
pkill -f "codex exec" 2>/dev/null

# Kill orphaned gemini CLI processes
pkill -f "gemini.*--prompt" 2>/dev/null

# Kill orphaned forge worker processes (background Task agents leave these)
# Only kill detached ones (those running without a terminal or in background state)
ps aux | grep -E "node.*(task_orchestrator|observability)" | grep -v grep | grep -v "Sl+" | awk '{print $2}' | xargs -r kill 2>/dev/null

# Check for stale MCP processes from previous sessions (running >12 hours)
ps aux | grep "node.*mcp" | grep -v grep | awk -v threshold=720 '{
  split($10, t, ":")
  minutes = t[1]*60 + t[2]
  if (minutes > threshold) print $2, $11
}' 2>/dev/null
```

Report what was killed. If stale MCP processes are found, report them but don't kill (they may belong to another active session).

### 2. Verify (if applicable)

Only run verification if the project HAS checks. Don't waste time scanning for nonexistent test infrastructure.

```bash
if [ -f .claude/verify.sh ]; then
  bash .claude/verify.sh
elif [ -f package.json ] && grep -qE '"(test|lint|typecheck|build)"' package.json; then
  # Run only what exists
  grep -q '"lint"' package.json && npm run lint
  grep -q '"typecheck"' package.json && npm run typecheck
  grep -q '"test"' package.json && npm test
elif [ -f pytest.ini ] || [ -f setup.py ] || [ -f pyproject.toml ]; then
  pytest
elif [ -f Cargo.toml ]; then
  cargo test && cargo clippy -- -D warnings
elif [ -f go.mod ]; then
  go test ./... && go vet ./...
fi
```

If no checks found, skip silently. Don't warn — infra projects don't need tests.
If verification FAILS, stop and fix before proceeding.

### 3. Commit Work

Stage and commit changes. **Decide the commit message yourself** (conventional commit format).
Stage specific files, not `git add .` — review what's changed first.

```bash
git status --short
git diff --stat
# Stage relevant files (NOT git add .)
git add [specific files]
git commit -m "[conventional commit message]

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

If no changes to commit, skip this step.

### 4. Save Session State

Create/update `.claude/session-resume.json`:

```json
{
  "timestamp": "ISO-8601",
  "session_date": "YYYY-MM-DD",
  "verification_status": "passed|skipped",
  "completed": ["what was done"],
  "in_progress": ["what's still going"],
  "next_steps": ["what to do next"],
  "blockers": ["any issues"],
  "notes": ["important context"],
  "last_commit": "SHA",
  "branch": "branch-name"
}
```

### 5. Sync Command Reference (if commands changed)

Check if any commands were added/removed this session:

```bash
# Get list of current commands
CURRENT=$(ls .claude/commands/*.md 2>/dev/null | xargs -I{} basename {} .md | sort)

# Compare against last known list (stored in session state or by diffing git)
git diff --name-only HEAD~3 -- .claude/commands/ 2>/dev/null
```

If new commands were added or removed, update the Obsidian slash command reference:
- Read `WSL/claude-env/.claude/docs/boris-tips-commands.md` via Obsidian MCP
- Add entries for new commands (name, one-line description, usage example)
- Remove entries for deleted commands
- Write back via Obsidian MCP

This adds ~5 seconds. Skip if no command changes detected.

### 6. Commit Session State

```bash
git add .claude/session-resume.json
git commit -m "chore: save session state — [brief summary]

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

### 7. Summary

Display:
- Verification: passed/skipped
- Commits: count and SHAs
- Orphan cleanup: what was killed
- Command sync: any updates pushed to Obsidian
- Resume: `run /continue next session`

## What Was Removed (vs old /done)

- `claude-progress.txt` — redundant with session-resume.json
- "Ask user for commit message" — rules say decide it yourself
- Scanning for test infrastructure on infra projects — waste of time
- `git add .` — risky, now uses specific files
- "Claude Opus 4.5" — updated to 4.6
