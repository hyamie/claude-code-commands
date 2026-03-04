---
name: rollback
description: Revert the last phase commit from /cook or /smoke
argument-hint: "[--hard] [COMMIT_HASH]"
---

# Rollback - Revert Last Phase Commit

Safely revert the last commit made by /cook or /smoke when verification passed but functionality is broken.

## Usage

```
/rollback                 # Revert last commit, keep changes staged
/rollback --hard          # Revert last commit, discard changes
/rollback abc1234         # Revert specific commit
/rollback --hard abc1234  # Revert specific commit, discard changes
```

## When to Use

- /smoke completed a phase but broke existing functionality
- /cook committed but you realized the approach is wrong
- Tests passed but integration is broken
- Need to undo and try a different approach

## Process

### Step 1: Identify Target Commit

```bash
# Check if specific commit provided
TARGET_COMMIT="$ARGUMENTS"
HARD_MODE=false

if [[ "$ARGUMENTS" == *"--hard"* ]]; then
  HARD_MODE=true
  TARGET_COMMIT=$(echo "$ARGUMENTS" | sed 's/--hard//g' | xargs)
fi

# If no commit specified, find the last /cook or /smoke commit
if [ -z "$TARGET_COMMIT" ]; then
  # Check status.json for last commit
  if [ -f .claude/status.json ]; then
    TARGET_COMMIT=$(cat .claude/status.json | jq -r '.last_commit // empty')
  fi

  # Fallback: find last commit with Claude co-author
  if [ -z "$TARGET_COMMIT" ]; then
    TARGET_COMMIT=$(git log --oneline --grep="Co-Authored-By: Claude" -1 --format="%h")
  fi
fi

if [ -z "$TARGET_COMMIT" ]; then
  echo "ERROR: Could not identify commit to rollback"
  echo "Specify a commit hash: /rollback abc1234"
  exit 1
fi

echo "Target commit: $TARGET_COMMIT"
git log -1 --oneline $TARGET_COMMIT
```

### Step 2: Verify Commit is Safe to Rollback

```bash
echo ""
echo "=== Commit Details ==="
git show --stat $TARGET_COMMIT

echo ""
echo "=== Safety Checks ==="

# Check if commit is on current branch
if git merge-base --is-ancestor $TARGET_COMMIT HEAD; then
  echo "Commit is on current branch: OK"
else
  echo "WARNING: Commit is not on current branch"
  exit 1
fi

# Check if commit was pushed
REMOTE_BRANCH=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
if [ -n "$REMOTE_BRANCH" ]; then
  if git merge-base --is-ancestor $TARGET_COMMIT $REMOTE_BRANCH 2>/dev/null; then
    echo "WARNING: Commit has been pushed to remote"
    echo "Rolling back will require force push"
  else
    echo "Commit not pushed: OK"
  fi
fi
```

### Step 3: Perform Rollback

**Soft rollback (default):** Reverts commit but keeps changes staged so you can modify and recommit.

```bash
if [ "$HARD_MODE" = true ]; then
  echo ""
  echo "=== Hard Rollback ==="
  echo "Reverting and discarding all changes..."
  git reset --hard HEAD~1
else
  echo ""
  echo "=== Soft Rollback ==="
  echo "Reverting commit, keeping changes staged..."
  git reset --soft HEAD~1
fi
```

### Step 4: Update Status

```bash
# Update status.json if it exists
if [ -f .claude/status.json ]; then
  # Decrement phase counter
  CURRENT_PHASE=$(cat .claude/status.json | jq '.current_phase')
  NEW_PHASE=$((CURRENT_PHASE - 1))

  # Remove last commit from commits array
  cat .claude/status.json | jq --arg phase "$NEW_PHASE" '
    .current_phase = ($phase | tonumber) |
    .commits = .commits[:-1] |
    .last_commit = (.commits[-1].hash // null) |
    .status = "rolled_back"
  ' > .claude/status.json.tmp && mv .claude/status.json.tmp .claude/status.json

  echo ""
  echo "Updated status.json"
fi

# Update plan file - unmark last completed tasks
# (This requires manual review - show what was in the commit)
echo ""
echo "=== Manual Step Required ==="
echo "Review the plan file and unmark tasks that were in this commit:"
echo ""
git show --name-only $TARGET_COMMIT -- "*.md" 2>/dev/null | grep -E "plans/.*\.md" | head -1
```

### Step 5: Report Results

```markdown
## Rollback Complete

### What Happened
- Reverted commit: [hash]
- Mode: [soft/hard]
- Changes: [staged/discarded]

### Current State
- Branch: [branch name]
- HEAD: [new commit hash]
- Staged changes: [count]

### Next Steps
- Review the staged changes (if soft rollback)
- Fix the issue that caused the rollback
- Run /cook or /smoke again to retry

### If Commit Was Pushed
If you pushed before rolling back:
```bash
git push --force-with-lease
```
(Use with caution - this rewrites history)
```

## Safety Features

| Feature | Description |
|---------|-------------|
| **Soft by default** | Keeps changes so you can fix and retry |
| **Remote check** | Warns if commit was pushed |
| **Status update** | Updates status.json to reflect rollback |
| **Audit trail** | Shows exactly what's being reverted |

## Examples

### Rollback Last Phase (Soft)
```
/rollback

Target commit: a1b2c3d
a1b2c3d feat(phase-2): api endpoints

Commit is on current branch: OK
Commit not pushed: OK

=== Soft Rollback ===
Reverting commit, keeping changes staged...

Rollback complete. Changes are staged for review.
```

### Rollback Specific Commit (Hard)
```
/rollback --hard a1b2c3d

Target commit: a1b2c3d

WARNING: This will discard all changes from this commit.

=== Hard Rollback ===
Reverting and discarding all changes...

Rollback complete. Changes discarded.
```
