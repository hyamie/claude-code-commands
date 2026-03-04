---
name: smoke
description: Full autonomy with signal-based iteration and Codex review
argument-hint: "[PLAN_FILE] [--calls N]"
---

# Smoke - Full Autonomy with Codex Integration

Execute ALL phases autonomously with signal-based iteration, fresh context per task,
and integrated Codex external review.

## Usage

```
/smoke                              # Execute all phases
/smoke .claude/plans/my-feature.md  # Specific plan
/smoke --calls 50                   # Set rate limit
/smoke --no-codex                   # Skip Codex review
```

## Execution Flow

```
┌─────────────────────────────────────────────────────┐
│                    TASK LOOP                        │
│  ┌──────────────────────────────────────────────┐  │
│  │ Task 1 → Validate → Commit → <<<TASK_DONE>>> │  │
│  │ Task 2 → Validate → Commit → <<<TASK_DONE>>> │  │
│  │ Task N → Validate → Commit → <<<ALL_DONE>>>  │  │
│  └──────────────────────────────────────────────┘  │
│                        ↓                            │
│                  REVIEW PHASE 1                     │
│           (Claude code-reviewer agent)              │
│        Issues found? Fix → No signal → Repeat       │
│        No issues? → <<<REVIEW_DONE>>>               │
│                        ↓                            │
│                  REVIEW PHASE 2                     │
│             (Codex GPT-5.2 external)                │
│        Claude evaluates findings → Fix valid ones   │
│        No issues? → <<<CODEX_DONE>>>                │
│                        ↓                            │
│                  REVIEW PHASE 3                     │
│           (Final Claude review - critical only)     │
│        No issues? → <<<FINAL_REVIEW_DONE>>>         │
│                        ↓                            │
│                    COMPLETE                         │
└─────────────────────────────────────────────────────┘
```

## Signal Protocol

| Signal | Meaning | Next Action |
|--------|---------|-------------|
| `<<<TASK_DONE>>>` | Task complete, more remain | Continue task loop |
| `<<<ALL_TASKS_DONE>>>` | All tasks complete | Start review phase 1 |
| `<<<TASK_FAILED>>>` | Unrecoverable error | Halt |
| `<<<REVIEW_DONE>>>` | Claude review clean | Start Codex review |
| `<<<CODEX_DONE>>>` | Codex review clean | Start final review |
| `<<<FINAL_REVIEW_DONE>>>` | Final review clean | Complete |
| (no signal after fix) | Fixed issues | Re-run current phase |

## Process

### Step 0: Check for Active Run

```bash
if [ -f .claude/status.json ]; then
  MODE=$(jq -r '.mode // empty' .claude/status.json)
  RESUME=$(jq -r '.resume // false' .claude/status.json)

  if [ "$MODE" = "smoke" ] && [ "$RESUME" = "true" ]; then
    echo "=== RESUMING ACTIVE SMOKE2 RUN ==="
    PLAN_FILE=$(jq -r '.plan_file' .claude/status.json)
    CURRENT_PHASE=$(jq -r '.current_phase' .claude/status.json)
    CURRENT_TASK=$(jq -r '.current_task // 1' .claude/status.json)
    # Continue from appropriate step
  fi
fi
```

### Step 1: Initialize

```bash
PLAN_FILE="$ARGUMENTS"
RATE_LIMIT=100
USE_CODEX=true

# Parse flags
if [[ "$ARGUMENTS" == *"--calls"* ]]; then
  RATE_LIMIT=$(echo "$ARGUMENTS" | grep -oP '(?<=--calls )\d+')
fi
if [[ "$ARGUMENTS" == *"--no-codex"* ]]; then
  USE_CODEX=false
fi

# Find plan if not specified
if [ -z "$PLAN_FILE" ]; then
  PLAN_FILE=$(ls -t .claude/plans/*.md 2>/dev/null | head -1)
fi

# Load plan with cap
echo "Loading plan: $PLAN_FILE"
PLAN_LINES=$(wc -l < "$PLAN_FILE")
if [ "$PLAN_LINES" -gt 200 ]; then
  echo "Plan is $PLAN_LINES lines — loading current phase only"
  head -20 "$PLAN_FILE"
  echo "---"
  awk '/^## Phase|^## Session|^### Task/{if(found && /^## /)exit; if(/\[ \]/ && !found)found=1} found' "$PLAN_FILE"
else
  cat "$PLAN_FILE"
fi

# Initialize status.json
cat > .claude/status.json << EOF
{
  "mode": "smoke",
  "resume": false,
  "plan_file": "$PLAN_FILE",
  "current_phase": "tasks",
  "current_task": 1,
  "rate_limit": $RATE_LIMIT,
  "use_codex": $USE_CODEX,
  "status": "starting"
}
EOF
```

### Step 2: Task Execution Loop

For each task in the plan:

1. **Announce task** (brief overview)
2. **Implement all checkboxes** in current task section
3. **Run validation** (test/lint commands from plan)
4. **Fix failures** until validation passes
5. **Commit:** `git commit -m "feat: <task description>"`
6. **Update plan:** `[ ]` → `[x]`
7. **Signal:**
   - More tasks? → `<<<TASK_DONE>>>` → Update status → Continue
   - No more? → `<<<ALL_TASKS_DONE>>>` → Proceed to review

### Step 3: Review Phase 1 (Claude)

Use code-reviewer agent to review all changes:

```
Use Task tool with subagent_type: "pr-review-toolkit:code-reviewer", model: "sonnet"
Prompt: "Review changes since default branch for bugs, security, quality."
```

**For each issue found:**
1. Read actual code at file:line
2. Verify issue is real (not false positive)
3. If valid: fix it
4. After fixing: **DO NOT signal** - loop runs again

**Only when review finds ZERO issues:**
```
Output: <<<REVIEW_DONE>>>
```

### Step 4: Review Phase 2 (Codex External)

**Skip if --no-codex flag was used.**

Run Codex for independent external review:

```bash
# Uses config.toml model setting, computes diff against base automatically
codex review --base master
```

**Claude evaluates Codex findings:**

For each Codex finding:
1. Read code at reported location
2. Trace the flow, understand context
3. Check if intentional design decision (in plan)
4. Assess actual impact

Categorize:
- **Valid issues:** Fix them
- **Invalid/irrelevant:** Document why (will be passed back to Codex)

**After fixing valid issues:** No signal - Codex runs again
**When Codex reports no issues:**
```
git commit -m "fix: address codex review findings"
Output: <<<CODEX_DONE>>>
```

### Step 5: Review Phase 3 (Final Claude)

Final review focusing on critical/major issues only:

```
Use Task tool with subagent_type: "pr-review-toolkit:code-reviewer", model: "sonnet"
Prompt: "Final review - critical and major issues only. Skip style/minor issues."
```

Same iteration logic:
- Issues found + fixed → No signal → Run again
- No issues → `<<<FINAL_REVIEW_DONE>>>`

### Step 6: Complete

Clear resume flag and report:

```markdown
## /smoke Complete

### Summary
- Plan: [name]
- Tasks completed: X/X
- Review iterations: Y (Claude) + Z (Codex) + W (Final)
- Total commits: N

### Commits
1. [hash] feat: task 1
2. [hash] feat: task 2
3. [hash] fix: address review findings
4. [hash] fix: address codex findings
...

### Review Summary
- Claude review: X iterations, Y issues fixed
- Codex review: X iterations, Y issues fixed
- Final review: X iterations, Y issues fixed

### Push when ready
git push
```

## status.json Schema

```json
{
  "mode": "smoke",
  "resume": true,
  "plan_file": ".claude/plans/feature.md",
  "current_phase": "codex_review",
  "current_task": 5,
  "total_tasks": 5,
  "rate_limit": 100,
  "use_codex": true,
  "status": "reviewing",
  "review_iterations": {
    "claude": 2,
    "codex": 1,
    "final": 0
  },
  "commits": [...],
  "started_at": "2026-01-30T10:00:00Z"
}
```

## Circuit Breaker

Same as /smoke:
- 3 consecutive failures → OPEN → Halt
- Same error 3 times → OPEN → Halt
- Resets on fresh /smoke run

## Rate Limiting

- Default: 100 calls/hour
- Override: `--calls N`
- Pauses with countdown at 90% of limit
- Resets each hour

## Monitoring

```bash
# Watch status
watch -n2 'jq . .claude/status.json'

# Watch commits
watch -n10 'git log --oneline -10'

# Watch current phase
watch -n5 'jq -r ".current_phase, .status" .claude/status.json'
```
