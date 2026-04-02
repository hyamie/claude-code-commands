---
name: cook
description: Execute plan with signal-based iteration and verification gates
argument-hint: "[PLAN_FILE or leave empty for latest plan]"
---

# Cook - Signal-Based Plan Execution

Execute a pre-approved plan with signal-based iteration control.
Fresh context per task, signal-based iteration (no signal = run again).

## Usage

```
/cook                              # Execute latest plan in .claude/plans/
/cook .claude/plans/my-feature.md  # Execute specific plan
```

## Signal Protocol

The iteration loop is controlled by signals:

| Signal | Meaning | Action |
|--------|---------|--------|
| `<<<TASK_DONE>>>` | Task complete, more tasks remain | Loop continues |
| `<<<ALL_TASKS_DONE>>>` | All tasks complete | Proceed to review |
| `<<<TASK_FAILED>>>` | Unrecoverable error | Halt execution |
| (no signal after fix) | Fixed issues, verify again | Loop continues |

## Process

### Step 0: Initialize

Check for active run in `.claude/status.json`:

```bash
if [ -f .claude/status.json ]; then
  MODE=$(jq -r '.mode // empty' .claude/status.json)
  RESUME=$(jq -r '.resume // false' .claude/status.json)

  if [ "$MODE" = "cook" ] && [ "$RESUME" = "true" ]; then
    echo "=== RESUMING ACTIVE COOK2 RUN ==="
    PLAN_FILE=$(jq -r '.plan_file' .claude/status.json)
    CURRENT_TASK=$(jq -r '.current_task // 1' .claude/status.json)
    # Continue from Step 1 with these values
  fi
fi
```

If NOT resuming:
1. Parse arguments for plan file
2. Create status.json with `"mode": "cook"`, `"resume": false`

### Step 1: Load Plan and Find Current Task

```bash
PLAN_FILE="$ARGUMENTS"

if [ -z "$PLAN_FILE" ]; then
  PLAN_FILE=$(ls -t .claude/plans/*.md 2>/dev/null | head -1)
fi

if [ -z "$PLAN_FILE" ] || [ ! -f "$PLAN_FILE" ]; then
  echo "No plan found. Create a plan first with /plan"
  exit 1
fi

echo "Loading plan: $PLAN_FILE"

# CAP: If plan > 200 lines, extract current phase only
PLAN_LINES=$(wc -l < "$PLAN_FILE")
if [ "$PLAN_LINES" -gt 200 ]; then
  echo "Plan is $PLAN_LINES lines — loading current phase only"
  head -20 "$PLAN_FILE"
  echo "---"
  awk '/^## Phase|^## Session|^### Task/{if(found && /^## /)exit; if(/\[ \]/ && !found)found=1} found' "$PLAN_FILE"
else
  cat "$PLAN_FILE"
fi
```

Find the FIRST task section (`### Task N:` or `### Iteration N:`) with uncompleted checkboxes (`[ ]`).

### Step 2: Execute ONE Task

**CRITICAL CONSTRAINT:** Complete ONE task section per iteration.

1. **Announce** (up to 200 words):
   - Which task number and title
   - What it will accomplish
   - Key files/components involved

2. **Implement:**
   - Read plan's Overview/Context sections
   - Implement ALL items in current task section (all `[ ]` checkboxes)
   - Write tests for implementation

3. **De-Sloppify Pass:**
   Review all changes from this task and clean up before validating:
   - Remove tests that assert on language/framework behavior (not your code)
   - Remove redundant type checks that the type system already enforces
   - Remove over-defensive error handling that will never trigger
   - Remove console.log / print debug statements
   - Remove commented-out code
   - Remove unnecessary abstractions that add indirection without value

4. **Validate:**
   - Run test/lint commands from plan's Validation Commands section
   - Fix any failures, repeat until all pass
   - **Build/compilation error fallback:** If validation fails with a build or compilation error:
     1. Invoke the build-error-resolver agent on the failing files
     2. Re-run validation
     3. If still failing after build-error-resolver, proceed with the normal fix cycle

4a. **Security Review:**
   Invoke the security-reviewer agent on all files changed in this task:
   ```
   Use Task tool with subagent_type: "security-reviewer"
   Prompt: "Review changed files for security issues. Files: [list changed files via git diff --name-only HEAD]. Flag CRITICAL findings that must be fixed before committing."
   ```
   - If CRITICAL findings are reported, fix them before committing
   - WARNING-level findings: note in commit message and continue
   - Skip if no code files changed (config-only or doc-only tasks)

5. **Complete:**
   - Edit plan file: change `[ ]` to `[x]` for completed items
   - Commit: `git commit -m "feat: <brief task description>"`

### Step 3: Signal and Loop Control

After completing the task:

**If NO more `[ ]` checkboxes in entire plan:**
```
Output exactly: <<<ALL_TASKS_DONE>>>
```
→ Proceed to Step 4 (Review)

**If more tasks remain:**
```
Output exactly: <<<TASK_DONE>>>
```
→ Update status.json (resume: true, current_task: N+1)
→ **STOP HERE** - Do not continue to next task
→ The external loop or user runs /cook again

**If task fails after reasonable attempts:**
```
Output exactly: <<<TASK_FAILED>>>
```
→ Halt with error report

### Step 4: Review Phase

After `<<<ALL_TASKS_DONE>>>`:

1. **Run verification:**
   ```bash
   if [ -f .claude/verify.sh ]; then
     bash .claude/verify.sh
   else
     # Auto-detect (npm test, pytest, cargo test, go test, etc.)
   fi
   ```

2. **Run code review:**
   ```
   Use Task tool with subagent_type: "pr-review-toolkit:code-reviewer", model: "sonnet"
   Prompt: "Review all changes from this plan execution for quality and security."
   ```

3. **Fix any issues found**

4. **After fixes, DO NOT output <<<REVIEW_DONE>>>**
   - The external loop runs review again to verify fixes
   - Only when review finds ZERO issues: output `<<<REVIEW_DONE>>>`

### Step 5: Final Summary

```markdown
## /cook Complete

### Tasks Completed
- Task 1: [description]
- Task 2: [description]
...

### Commits
- [hash] feat: task 1 description
- [hash] feat: task 2 description
...

### Verification
- All tests: PASS
- Lint: PASS
- Review: PASS

### Next Steps
- Run `/cook` for next plan
- Or `/smoke` for full autonomy
```

## status.json Schema

```json
{
  "mode": "cook",
  "resume": true,
  "plan_file": ".claude/plans/feature.md",
  "current_task": 2,
  "total_tasks": 5,
  "status": "executing",
  "last_signal": "TASK_DONE",
  "commits": [
    {"task": 1, "hash": "abc1234", "message": "feat: task 1"}
  ],
  "started_at": "2026-01-30T10:00:00Z"
}
```

## Example Run

```
/cook

Loading plan: .claude/plans/add-auth.md

Task 1/3: Create user model
- What: Define User schema with email, password hash, timestamps
- Files: src/models/user.ts, src/types/user.ts

Implementing...
- [x] Create User interface
- [x] Create Prisma schema
- [x] Add validation
- [x] Write tests

Validation: PASS
Committing: feat: create user model
Committed: a1b2c3d

<<<TASK_DONE>>>

---
[User or loop runs /cook again]
---

=== RESUMING ACTIVE COOK2 RUN ===
Plan: .claude/plans/add-auth.md
Continuing from task: 2

Task 2/3: Add authentication endpoints
...
```

## Why Signal-Based?

The "no signal = run again" pattern prevents premature completion:

1. **Issue found + fixed** → No signal → Loop runs again to verify fix
2. **Fix introduces new issue** → Caught in next iteration
3. **Clean verification** → Signal emitted → Move to next stage

This ensures fixes are verified before proceeding.
