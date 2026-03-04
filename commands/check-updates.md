# Check for Tool Updates

Weekly check for all updateable components. Creates a todo list for updates needed.

## What Gets Checked

| Category | Discovery | Update Method |
|----------|-----------|---------------|
| Claude Code | Automatic | `claude update` |
| Plugins | Automatic | `claude plugin update <name>` |
| CLIs | From list below | Per-tool commands |
| MCPs | N/A | Auto via @latest |

## Execution Steps

### 1. Check Claude Code

```bash
claude update 2>&1 | head -10
```

If update available, add to todo list.

### 2. Check Plugins

For each enabled plugin, try updating and see if there's a newer version:

```bash
claude plugin list 2>/dev/null | grep -E "^  ❯|Version:" | paste - - | grep "enabled"
```

### 3. Check CLIs

**CLI Registry** (add new CLIs here when installed):

| CLI | Version Command | Latest Source | Update Command |
|-----|-----------------|---------------|----------------|
| supabase | `supabase --version` | GitHub: supabase/cli | See below |
| gh | `gh --version` | GitHub: cli/cli | See below |
| railway | `railway --version` | npm: @railway/cli | `npm i -g @railway/cli` |
| vercel | `vercel --version` | npm: vercel | `npm i -g vercel` |

Run in parallel:
```bash
# Current versions
echo "supabase:$(supabase --version 2>/dev/null || echo 'not installed')"
echo "railway:$(railway --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || echo 'not installed')"
echo "gh:$(gh --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+' || echo 'not installed')"
echo "vercel:$(vercel --version 2>/dev/null || echo 'not installed')"
```

```bash
# Latest versions
echo "supabase:$(curl -s https://api.github.com/repos/supabase/cli/releases/latest | jq -r .tag_name | tr -d 'v')"
echo "gh:$(curl -s https://api.github.com/repos/cli/cli/releases/latest | jq -r .tag_name | tr -d 'v')"
echo "railway:$(npm view @railway/cli version 2>/dev/null)"
echo "vercel:$(npm view vercel version 2>/dev/null)"
```

### 4. Create Todo List

Create items for each update needed:

**Categories:**
- "Update Claude Code to vX.X.X" (if available)
- "Update plugin: <name>" (for each outdated plugin)
- "Update <cli> from vX to vY" (for each CLI)

### 5. Offer to Apply Updates

Ask: "Found X updates. Apply them now?"

If yes, work through the todo list.

## Update Commands Reference

### Claude Code
```bash
claude update
```

### Plugins
```bash
# Update specific plugin
claude plugin update <plugin-name>

# Update all plugins (run for each)
claude plugin list | grep "❯" | awk '{print $2}' | cut -d@ -f1 | xargs -I {} claude plugin update {}
```

### CLIs

**Supabase** (direct binary):
```bash
VERSION="X.X.X"
curl -fsSL "https://github.com/supabase/cli/releases/download/v${VERSION}/supabase_linux_amd64.tar.gz" -o /tmp/supabase.tar.gz
tar -xzf /tmp/supabase.tar.gz -C /tmp
mv /tmp/supabase ~/.local/bin/supabase
rm /tmp/supabase.tar.gz
```

**GitHub CLI** (download .deb or binary from releases):
```bash
# Check https://github.com/cli/cli/releases for latest .deb
# Or use: gh extension upgrade --all (for extensions only)
```

**Railway & Vercel** (npm):
```bash
npm install -g @railway/cli
npm install -g vercel
```

## Adding New CLIs

When you install a new CLI, add it to the "CLI Registry" table above with:
1. Version command
2. Where to check latest version (GitHub releases or npm)
3. Update command

## MCP Packages (Info Only)

These auto-update via `npx @latest` - no action needed. Common ones:
- @playwright/mcp
- @modelcontextprotocol/server-sequential-thinking
- @cloudflare/mcp-server-cloudflare
- @supabase/mcp-server-supabase

Force refresh if issues: `rm -rf ~/.npm/_npx`
