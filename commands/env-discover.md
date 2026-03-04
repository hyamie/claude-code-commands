# /env:discover - Discover New MCPs and Tools

Find new MCP servers and tools that could enhance the Claude Code environment.

## Process

### 1. Reference MCP Directories

Check these sources for new MCPs:

**Official Anthropic MCPs:**
- https://github.com/anthropics/anthropic-tools

**Community Collections:**
- https://github.com/punkpeye/awesome-mcp-servers
- https://github.com/wong2/awesome-mcp-servers

### 2. Compare Against Installed MCPs

Read your current MCPs:
```bash
cat ~/.claude.json 2>/dev/null | jq '.mcpServers | keys'
cat .mcp.json 2>/dev/null | jq 'keys'
```

### 3. Stack-Based Recommendations

Based on detected stack, suggest relevant MCPs:

| If Using | Consider |
|----------|----------|
| PostgreSQL | postgres-mcp |
| MongoDB | mongodb-mcp |
| Redis | redis-mcp |
| AWS | aws-mcp |
| Google Cloud | gcp-mcp |
| Docker | docker-mcp |
| Kubernetes | k8s-mcp |
| Slack | slack-mcp |
| Linear | linear-mcp |
| Notion | notion-mcp |

### 4. Check for MCP Updates

For each installed MCP, check if newer versions exist:
```bash
npm show <mcp-package> version
```

## Installation Guide

To install a new MCP:

1. Add to `~/.claude.json`:
   ```json
   "mcp-name": {
     "command": "npx",
     "args": ["-y", "@mcp/package-name"]
   }
   ```

2. If credentials needed, use a 1Password wrapper:
   ```json
   "mcp-name": {
     "command": "~/.claude/scripts/1password-mcp-wrapper.sh",
     "args": ["npx", "-y", "@mcp/package-name"],
     "env": {
       "API_KEY_REF": "op://YOUR_VAULT/mcp-name/api-key"
     }
   }
   ```

3. Restart Claude Code to load the new MCP.

## Web Search

Use WebSearch to find:
1. "awesome mcp servers 2026"
2. "[detected-stack] mcp server"
3. "anthropic mcp new releases"

## Safety Notes

- Only recommend MCPs from trusted sources
- Prefer official Anthropic or well-starred community MCPs
- Check GitHub stars/activity before recommending
- Note any security considerations
