# /env:audit - Full Environment Audit

Perform a comprehensive audit of the Claude Code environment (2-5 minutes).

## Process

### 1. MCP Server Audit
Run `~/.claude/scripts/mcp-health.sh` or manually check:

**Global MCPs** (from `~/.claude.json`):
- github
- playwright
- sequential-thinking
- n8n
- unifi
- memory
- cloudflare

**Project MCPs** (from `.mcp.json`):
- task_orchestrator_mcp
- observability

For each MCP, report:
- Status: Running/Stopped/Error
- Version if available
- Last successful connection

### 2. Agent Configuration Audit
Run `~/.claude/scripts/validate-agents.py` or manually check:

Validate all agents in `~/claude-env/.claude/agents/`:
- YAML frontmatter valid
- Required fields present (name, description, tools)
- Tool permissions align with architecture

### 3. CLI Tool Versions
Check and report versions:

```bash
claude --version          # Claude CLI
gh --version              # GitHub CLI
railway --version         # Railway CLI
supabase --version        # Supabase CLI
op --version              # 1Password CLI
node --version            # Node.js
python3 --version         # Python
```

### 4. Package Inventory

**npm globals:**
```bash
npm list -g --depth=0
```

**pip packages:**
```bash
pip list --format=freeze | head -20
```

### 5. Skill Inventory
```bash
ls ~/claude-env/.claude/skills/ | wc -l
```
List skill categories and counts.

### 6. Hook Status
List all hooks from `~/.claude/settings.json`:
- SessionStart hooks
- UserPromptSubmit hooks
- PreToolUse hooks
- PostToolUse hooks
- Stop hooks

### 7. Session Health
Check for stale sessions:
```bash
find ~/.claude/projects/ -name "*.jsonl" -mtime +7 | wc -l
```

## Output Format

```
Full Environment Audit
======================
Generated: YYYY-MM-DD HH:MM

## MCP Servers
| Server | Status | Notes |
|--------|--------|-------|
| github | OK | via 1Password |
| ... | ... | ... |

## CLI Tools
| Tool | Version | Status |
|------|---------|--------|
| claude | X.Y.Z | current |
| ... | ... | ... |

## Agents
Found: X agents
Valid: Y/X
Issues: [list any problems]

## Skills
Total: X skills
Categories: [list]

## Hooks
Active: X hooks
- SessionStart: Y
- PreToolUse: Z
- ...

## Sessions
Active projects: X
Stale sessions (>7d): Y

## Recommendations
- [ ] Upgrade claude CLI (current: X, latest: Y)
- [ ] Remove stale sessions
- ...
```

## Timing

Target: 2-5 minutes
- MCP checks: 30s (parallel with timeouts)
- CLI versions: 10s
- Package inventory: 30s
- File scans: 30s
