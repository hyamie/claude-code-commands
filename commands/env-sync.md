# /env:sync - Sync Reports to Obsidian Vault

Copy reports from WSL staging directory to Windows Obsidian vault.

## Paths

| Location | Path |
|----------|------|
| WSL Staging | `~/obsidian-staging/claude-code/` |
| Windows Vault | `/mnt/c/Users/hyami/Documents/ObsidianVault/claude-code/` |

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
mkdir -p "/mnt/c/Users/hyami/Documents/ObsidianVault/claude-code/"
```

### 3. Sync Files
```bash
# Copy all files from staging to vault
cp -r ~/obsidian-staging/claude-code/* "/mnt/c/Users/hyami/Documents/ObsidianVault/claude-code/"
```

Or use rsync for more control:
```bash
rsync -av --update ~/obsidian-staging/claude-code/ "/mnt/c/Users/hyami/Documents/ObsidianVault/claude-code/"
```

### 4. Verify Sync
```bash
# List synced files
ls -la "/mnt/c/Users/hyami/Documents/ObsidianVault/claude-code/"
```

## Output Format

```
Obsidian Sync
=============

Source: ~/obsidian-staging/claude-code/
Destination: /mnt/c/Users/hyami/Documents/ObsidianVault/claude-code/

Synced Files:
- health-report-2026-01-21.md (new)
- health-report-2026-01-20.md (unchanged)

Status: SUCCESS
```

## Error Handling

### Windows Path Not Accessible
```
ERROR: Windows vault path not accessible.

This can happen if:
1. WSL is not properly configured
2. The path doesn't exist in Windows
3. Permission issues

Try:
- Verify path exists: ls /mnt/c/Users/hyami/Documents/
- Create vault directory manually in Windows
- Check WSL mount: mount | grep /mnt/c
```

### Staging Directory Empty
```
WARNING: Staging directory is empty.

Run /env:report to generate a report first.
```

## Cron Setup

For automatic syncing, run `~/.claude/scripts/setup-cron.sh` to install:
```bash
# Syncs every 30 minutes
*/30 * * * * ~/.claude/scripts/sync-to-obsidian.sh
```

## Manual Script

Can also run directly:
```bash
~/.claude/scripts/sync-to-obsidian.sh
```
