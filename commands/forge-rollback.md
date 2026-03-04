---
name: forge-rollback
description: Rollback an entire /forge run to the pre-forge SHA
argument-hint: "[--hard]"
---

# /forge-rollback — Revert Entire Forge Run

Reverts all commits made during a /forge run back to the pre-forge state. Default mode squashes changes into staged files for review. Hard mode discards everything.

## Usage

```
/forge-rollback          # Squash all forge commits into staged changes (soft reset)
/forge-rollback --hard   # Fully revert to pre-forge state (discard all changes)
```

## Process

### Step 1: Load Forge State

```bash
if [ ! -f forge-status.json ]; then
  echo "ERROR: No forge-status.json found. Nothing to rollback."
  exit 1
fi

RUN_DIR=$(jq -r '.run_dir // empty' forge-status.json)
if [ -z "$RUN_DIR" ]; then
  echo "ERROR: forge-status.json missing run_dir field."
  exit 1
fi

PRE_FORGE_SHA=$(jq -r '.pre_forge_sha // empty' "${RUN_DIR}/forge-status.json")
if [ -z "$PRE_FORGE_SHA" ]; then
  echo "ERROR: pre_forge_sha not stored in ${RUN_DIR}/forge-status.json."
  echo "This forge run predates rollback support. Manual git reset required."
  exit 1
fi

RUN_ID=$(jq -r '.run_id' "${RUN_DIR}/forge-status.json")
echo "Forge run: ${RUN_ID}"
echo "Pre-forge SHA: ${PRE_FORGE_SHA}"
echo "Current HEAD: $(git rev-parse HEAD)"
```

### Step 2: Show What Will Be Reverted

```bash
COMMIT_COUNT=$(git rev-list --count ${PRE_FORGE_SHA}..HEAD)
echo ""
echo "=== ${COMMIT_COUNT} commits to revert ==="
git log --oneline ${PRE_FORGE_SHA}..HEAD
echo ""
echo "=== File changes ==="
git diff --stat ${PRE_FORGE_SHA} HEAD
```

If `COMMIT_COUNT` is 0, there's nothing to revert:
```
No forge commits found since pre-forge SHA. Nothing to rollback.
```

### Step 3: Confirm and Perform Rollback

**This is a destructive operation. Use AskUserQuestion to confirm:**

- question: "Rollback {COMMIT_COUNT} forge commits from run {RUN_ID}?"
- options:
  1. "Soft reset (keep changes staged)" — default
  2. "Hard reset (discard all changes)"
  3. "Cancel"

**Soft reset (default or explicit `--soft`):**
```bash
git reset --soft ${PRE_FORGE_SHA}
echo "Soft reset complete. All forge changes are now staged."
echo "Review with: git diff --cached --stat"
echo "Recommit with: git commit"
echo "Or discard with: git reset HEAD"
```

**Hard reset (`--hard` flag):**
```bash
git reset --hard ${PRE_FORGE_SHA}
echo "Hard reset complete. All forge changes discarded."
```

### Step 4: Update Forge State

```bash
FS_TMP=$(mktemp)
jq '. + {completed: true, rolled_back: true, rolled_back_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))}' \
  "${RUN_DIR}/forge-status.json" > "$FS_TMP" && mv "$FS_TMP" "${RUN_DIR}/forge-status.json"

# Update root pointer
FS_TMP=$(mktemp)
jq '. + {active_run: null, completed: true, rolled_back: true}' \
  forge-status.json > "$FS_TMP" && mv "$FS_TMP" forge-status.json
```

### Step 5: Report

```markdown
## Forge Rollback Complete

- Run: {RUN_ID}
- Mode: soft/hard
- Commits reverted: {COMMIT_COUNT}
- Rolled back to: {PRE_FORGE_SHA}

### Next Steps
- **Soft reset:** Review staged changes with `git diff --cached`, recommit selectively, or discard with `git reset HEAD`
- **Hard reset:** Start fresh with `/plan` or modify the existing plan and re-run `/forge-prep`
```
