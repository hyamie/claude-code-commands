---
name: duo-next
description: Advance to the next /duo phase — review Codex output, commit, regenerate
---

# /duo-next — Phase Handoff

Review Codex's work for the current phase, run verification, commit, and advance to the next phase.
Run this after Codex completes its tasks for a phase.

## Usage

```
/duo-next                    # Auto-finds active duo plan
```

## Process

### Step 1: Find Active Duo Plan

Find the plan file with `**Mode:** duo` metadata:

```bash
# Search for active duo plan
grep -rl "Mode.*duo" .claude/plans/*.md 2>/dev/null | grep -v '.codex.md'
```

If no plan found, display:
```
No active duo plan found. Run /duo first to create one.
```

If multiple found, use the most recently modified.

### Step 2: Find Current Phase

Parse the plan file to find the current phase — the first `### Phase N:` section that has unchecked tasks (`- [ ]`).

If all tasks are checked (`- [x]`), the plan is complete — go to Step 6.

### Step 3: Review Codex Output

Review what Codex changed for the current phase:

1. **Check git diff** for uncommitted changes:
   ```bash
   git diff --stat
   git diff
   ```

2. **Read modified files** — understand what Codex actually did

3. **Compare against plan** — check each Codex task in the current phase:
   - Was the task completed as specified?
   - Any deviations from the plan?
   - Any issues introduced?

4. **Run verification** (if the project has tests/lint):
   ```bash
   # Check for common verification commands
   if [ -f "package.json" ]; then
     npm test 2>/dev/null
     npm run lint 2>/dev/null
   elif [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
     python -m pytest 2>/dev/null
   fi
   ```

5. **Report findings:**
   - List what Codex completed correctly
   - List any issues found
   - For minor issues: fix them directly
   - For major issues: note them and instruct user to send back to Codex

### Step 4: Commit Phase Work

If verification passes (or issues were fixed):

1. **Stage changes:**
   ```bash
   git add -A
   ```

2. **Commit with dual co-author:**
   ```bash
   git commit -m "$(cat <<'COMMIT_EOF'
   feat(phase-N): [description of phase work]

   Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
   Co-Authored-By: Codex CLI 5.4 <noreply@openai.com>
   COMMIT_EOF
   )"
   ```

3. **Mark phase tasks complete** in plan.md — change `- [ ]` to `- [x]` for all tasks in the current phase.

### Step 5: Advance to Next Phase

Check for the next phase (next `### Phase N:` with `- [ ]` tasks):

**If next phase exists:**

1. Identify Codex-owned tasks in the next phase
2. Regenerate `plan.codex.md` with the next phase's Codex tasks using the V1 Step 4 template from duo.md:
   - Update `## Current Phase:` header
   - Populate with next phase's Codex tasks only
   - Keep project context and architecture decisions
   - Reset status table to `pending`
3. Execute any Claude-owned tasks for the next phase (config, deploy, MCP ops, etc.)
4. Present summary:

```markdown
## Phase N Complete → Phase N+1 Ready

### Phase N Summary
- Tasks completed: X/X
- Issues fixed: Y
- Commit: [hash]

### Phase N+1: [Name]
**Codex tasks:**
- [list Codex tasks for next phase]

**Claude tasks (done):**
- [list Claude tasks already executed]

### Next
Give Codex the updated `plan.codex.md`, then run `/duo-next` when done.
```

**If no next phase:** Go to Step 6.

### Step 6: Plan Complete

All phases done. Show final summary:

```markdown
## /duo Complete

### Plan: [plan name]
- Total phases: N
- Total tasks: X (Claude: Y, Codex: Z)
- Commits: [list]

### All Phases
| Phase | Status | Commit |
|-------|--------|--------|
| Phase 1 | Complete | [hash] |
| Phase 2 | Complete | [hash] |
| ... | ... | ... |

### Push when ready
git push
```
