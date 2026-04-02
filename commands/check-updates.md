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

Note: There's no "check for updates" - you have to try `claude plugin update <name>` to see if newer version exists. Consider updating all plugins periodically.

### 3. Check CLIs

**CLI Registry** (add new CLIs here when installed):

| CLI | Version Command | Latest Source | Update Command |
|-----|-----------------|---------------|----------------|
| supabase | `supabase --version` | GitHub: supabase/cli | See below |
| gh | `gh --version` | GitHub: cli/cli | See below |
| railway | `railway --version` | npm: @railway/cli | `npm i -g @railway/cli` |
| vercel | `vercel --version` | npm: vercel | `npm i -g vercel` |
| openclaw | `openclaw --version` | npm: openclaw | `npm i -g openclaw` |
| skills | `skills --version` | npm: skills | `npm i -g skills` |
| playwright-cli | `playwright-cli --version` | npm: @playwright/cli | `npm i -g @playwright/cli` |
| skill-scanner | `skill-scanner --version` | PyPI: cisco-ai-skill-scanner | `pipx upgrade cisco-ai-skill-scanner` |
| bird | `bird --version` | npm: @steipete/bird | `npm i -g @steipete/bird` |
| go | `go version` | https://go.dev/dl/ | Download and extract to ~/go |
| github-mcp-server | `~/bin/github-mcp-server --help 2>&1 \| head -1` | GitHub: github/github-mcp-server | Build from source (Go) |
| notebooklm | `notebooklm --version` | PyPI: notebooklm-py | `pipx upgrade notebooklm-py` |
| quickbooks-mcp | `cd ~/.mcp-servers/quickbooks-online && git log --oneline -1` | GitHub: intuit/quickbooks-online-mcp-server | `cd ~/.mcp-servers/quickbooks-online && git pull && npm install && npm run build` |
| octofriend | `octofriend version` | npm: octofriend | `npm i -g octofriend` |
| qmd | `qmd --version` | npm: @tobilu/qmd | `npm i -g @tobilu/qmd` |
| mcp-searxng | `npm ls -g mcp-searxng --depth=0 2>/dev/null \| grep mcp-searxng` | npm: mcp-searxng | `npm i -g mcp-searxng` |
| ha-mcp | `uvx --python 3.13 ha-mcp --version 2>/dev/null \|\| echo "check PyPI"` | PyPI: ha-mcp | `uvx cache clean ha-mcp` (uvx auto-fetches latest) |
| resend | `resend --version` | npm: resend-cli | `npm i -g resend-cli` |
| gws | `gws --version` | npm: @googleworkspace/cli | `npm i -g @googleworkspace/cli` |
| autotask | `autotask --version` | PyPI: autotask-client | `pipx upgrade autotask-client` |
| codex (remote) | `ssh <remote-host> "codex --version"` | npm: @openai/codex | `ssh <remote-host> "npm i -g @openai/codex"` |
| steel-mcp-server | `npm ls -g @steel-dev/mcp-server --depth=0 2>/dev/null \| grep steel` | GitHub: steel-dev/steel-mcp-server | `cd /tmp && rm -rf steel-mcp-server && git clone https://github.com/steel-dev/steel-mcp-server.git && cd steel-mcp-server && npm install && npm run build && npm link` |
| ollama | `ollama --version` | GitHub: ollama/ollama | `curl -fsSL https://ollama.com/install.sh \| sh` |
| shadcn | `shadcn --version` | npm: shadcn | `npm i -g shadcn` |
| recon | `recon --version` | GitHub: gavraz/recon | Clone + `cargo build --release`, copy to ~/bin/ |
| php | `php -v \| head -1` | apt: php8.3-cli | `sudo apt-get update && sudo apt-get install -y php8.3-cli` |
| composer | `composer --version` | https://getcomposer.org | `curl -sS https://getcomposer.org/installer \| php -- --install-dir=~/.local/bin --filename=composer` |
| wp-cli | `wp --version` | GitHub: wp-cli/wp-cli | `curl -sS https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o ~/.local/bin/wp && chmod +x ~/.local/bin/wp` |
| phpcs | `phpcs --version` | Composer: squizlabs/php_codesniffer | `composer global update squizlabs/php_codesniffer` |

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

Use TodoWrite to create items for each update needed:

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

## Python MCP Servers (Manual Check)

These are local Python projects — check for dependency updates:

| MCP | Location | Check Command |
|-----|----------|---------------|
| wordpress | `~/projects/active/wp-site-intelligence/` | `cd ~/projects/active/wp-site-intelligence && .venv/bin/pip list --outdated` |

## MCP Packages (Info Only)

These auto-update via `npx @latest` - no action needed:
- @playwright/mcp
- @modelcontextprotocol/server-sequential-thinking
- @modelcontextprotocol/server-memory
- @cloudflare/mcp-server-cloudflare
- @supabase/mcp-server-supabase
- @mauricio.wolff/mcp-obsidian

**Note:** GitHub MCP moved from `@modelcontextprotocol/server-github` (npx) to official `github/github-mcp-server` (Go binary at `~/bin/github-mcp-server`). Update by rebuilding from source.

Force refresh if issues: `rm -rf ~/.npm/_npx`
