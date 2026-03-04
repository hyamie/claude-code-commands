# /env:sync - Sync Reports to Obsidian Vault

Copy reports from WSL staging directory to Windows Obsidian vault.

## Paths

| Location | Path |
|----------|------|
| WSL Staging | `~/obsidian-staging/claude-code/` |
| Windows Vault | `/mnt/c/Users/YOUR_USERNAME/Documents/ObsidianVault/claude-code/` |

## Process

### 1. Verify Source Exists
```bash
if [ ! -d ~/obsidian-staging/claude-code/ ]; then
    echo "No staging directory found. Run /env:report first."
    exit 1
fi
```

### 2. Create Destination if Needed
```bash
VAULT_PATH="/mnt/c/Users/YOUR_USERNAME/Documents/ObsidianVault/claude-code/"
mkdir -p "$VAULT_PATH"
```

### 3. Sync Files
```bash
cp -r ~/obsidian-staging/claude-code/* "$VAULT_PATH"
```

Or use rsync for more control:
```bash
rsync -av --update ~/obsidian-staging/claude-code/ "$VAULT_PATH"
```

### 4. Verify Sync
```bash
ls -la "$VAULT_PATH"
```

## Output Format

```
Obsidian Sync
=============

Source: ~/obsidian-staging/claude-code/
Destination: $VAULT_PATH

Synced Files:
- health-report-YYYY-MM-DD.md (new)
- health-report-YYYY-MM-DD.md (unchanged)

Status: SUCCESS
```

## Cron Setup

For automatic syncing:
```bash
# Syncs every 30 minutes
*/30 * * * * ~/.claude/scripts/sync-to-obsidian.sh
```
