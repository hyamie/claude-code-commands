---
name: status
description: Show session and environment statistics
---

# Status - Quick Progress Check

Show current status of active /smoke runs, session state, and environment health.

## Usage

```
/status              # Show everything
/status smoke        # Show only /smoke progress
/status session      # Show only session info
```

## Process

### Step 1: Check for Active /smoke Run

```bash
if [ -f .claude/status.json ]; then
  echo "=== /smoke Status ==="
  cat .claude/status.json | jq -r '
    "Plan: \(.plan // "none")",
    "Phase: \(.current_phase // 0)/\(.total_phases // 0)",
    "Status: \(.status // "unknown")",
    "Mode: \(.mode // "none")",
    "Resume: \(.resume // false)",
    "Circuit Breaker: \(.circuit_breaker // "unknown")",
    "Commits: \(.commits | length // 0)",
    "Started: \(.started_at // "unknown")",
    "Elapsed: \(.elapsed_minutes // 0) minutes"
  '
  echo ""

  if [ "$(cat .claude/status.json | jq -r '.commits // []')" != "[]" ]; then
    echo "Recent Commits:"
    cat .claude/status.json | jq -r '.commits[-3:][] | "  \(.hash) \(.message)"'
  fi
else
  echo "No active /smoke run (no .claude/status.json)"
fi
```

### Step 2: Show Session Info

```bash
echo ""
echo "=== Session Info ==="

# Git status
echo "Branch: $(git branch --show-current 2>/dev/null || echo 'not a git repo')"
echo "Uncommitted changes: $(git status --porcelain 2>/dev/null | wc -l)"

# Recent session state
if [ -f .claude/session-state.json ]; then
  echo ""
  echo "Last Session State:"
  cat .claude/session-state.json | jq -r '
    "  Saved: \(.saved_at // "unknown")",
    "  In Progress: \(.in_progress | length // 0) items",
    "  Completed: \(.completed | length // 0) items"
  ' 2>/dev/null || echo "  (unable to parse)"
fi
```

### Step 3: Environment Health

```bash
echo ""
echo "=== Environment Health ==="

# Check critical tools
for tool in git jq; do
  if command -v $tool &>/dev/null; then
    echo "$tool: OK"
  else
    echo "$tool: MISSING"
  fi
done

# Check MCP status (if available)
if [ -f ~/.claude.json ]; then
  MCP_COUNT=$(cat ~/.claude.json | jq '.mcpServers | length' 2>/dev/null || echo "0")
  echo "Global MCPs: $MCP_COUNT configured"
fi

if [ -f .mcp.json ]; then
  PROJECT_MCP=$(cat .mcp.json | jq '.mcpServers | length' 2>/dev/null || echo "0")
  echo "Project MCPs: $PROJECT_MCP configured"
fi
```

## Output Example

```
=== /smoke Status ===
Plan: add-user-auth.md
Phase: 2/4
Status: executing
Mode: smoke
Resume: true
Circuit Breaker: CLOSED
Commits: 1
Started: 2026-01-21T10:00:00Z
Elapsed: 23 minutes

Recent Commits:
  a1b2c3d feat(phase-1): database schema

=== Session Info ===
Branch: feature/user-auth
Uncommitted changes: 3

Last Session State:
  Saved: 2026-01-21T09:45:00Z
  In Progress: 1 items
  Completed: 5 items

=== Environment Health ===
git: OK
jq: OK
Global MCPs: 10 configured
Project MCPs: 2 configured
```

## Quick Reference

| What | Command |
|------|---------|
| Full status | `/status` |
| Just /smoke progress | `/status smoke` |
| Just session info | `/status session` |
| Monitor continuously | `watch -n2 cat .claude/status.json` |
