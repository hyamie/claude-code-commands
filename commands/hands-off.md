---
name: hands-off
description: Remind Claude of autonomous capabilities - use when Claude asks you to do manual tasks
argument-hint: ""
---

# Hands-Off Mode

**You asked me to do something manually. Don't. Use your tools.**

## Your Available Tools

### CLI Commands (use via Bash)
| Tool | What it does |
|------|-------------|
| `railway` | Deploy, logs, vars, services - FULL control |
| `supabase` | Migrations, functions, secrets, db operations |
| `gh` | PRs, issues, releases, repo management |
| `op` | 1Password - get ANY credential from your vault |
| `docker` | Container management |
| `npm` / `npx` | Package management, run scripts |

### MCP Servers

**CHECK YOUR AVAILABLE MCPs NOW:**
```bash
# Read project MCPs
cat .mcp.json 2>/dev/null || cat .claude/.mcp.json 2>/dev/null

# Read global MCPs
cat ~/.claude.json 2>/dev/null | jq '.mcpServers | keys'
```

Common MCPs you might have:
- **github** - Create PRs, issues, manage repos
- **supabase** - Database operations
- **railway** - Deployment management
- **playwright** - Browser automation, testing
- **n8n** - Workflow automation
- **context7** - Library documentation lookup

**USE the MCPs listed in your config. They're there for a reason.**

### 1Password (op CLI)
All credentials are in 1Password. Never ask the user for secrets.
```bash
op item get "SERVICE_NAME" --vault YOUR_VAULT --fields "API Token" --reveal
```

## The Rule

**If a CLI or MCP can do it, YOU do it. Don't ask me.**

Wrong: "Can you update the Railway environment variable?"
Right: `railway variables set FOO=bar`

Wrong: "Can you run this Supabase migration?"
Right: `supabase db push` or `supabase migration up`

Wrong: "Can you check the deployment logs?"
Right: `railway logs` or check via MCP

## When to Actually Ask

Only ask if:
1. You genuinely don't have the tool/access
2. It requires a manual action (clicking UI buttons with no API)
3. It needs a human decision (delete production data, etc.)

## After Compaction

If context was compacted and you forgot this, the user will run `/hands-off` again. Re-read this and stop asking them to do manual tasks.
