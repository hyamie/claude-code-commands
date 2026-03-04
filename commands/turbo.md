---
name: turbo
description: Maximum autonomy - 5 parallel Claude review agents + Codex external review
argument-hint: "[PLAN_FILE] [--calls N] [--no-codex]"
---

# Turbo 2.0 - Maximum Autonomy Execution

The big guns. Execute all tasks, then run **5 parallel Claude review agents**,
then Codex external review, then final 2-agent review. Walk away and come back to a PR-ready branch.

## Usage

```
/turbo                              # Execute with full pipeline
/turbo .claude/plans/my-feature.md  # Specific plan
/turbo --calls 50                   # Rate limit
/turbo --no-codex                   # Skip Codex review
```

## The Pipeline

```
TASK EXECUTION → REVIEW PHASE 1 (5 agents) → CODEX REVIEW → FINAL CHECK (2 agents) → COMPLETE
```

Signals: `<<<ALL_TASKS_DONE>>>` → `<<<REVIEW_DONE>>>` → `<<<CODEX_DONE>>>` → `<<<FINAL_DONE>>>`

## Review Agent Definitions

Prompts live in `.claude/agents/reviewers/`. Each file has `{{BASE_BRANCH}}`, `{{CHANGED_FILES}}`, and `{{PLAN_FILE}}` placeholders.

| Agent | File | Focus |
|-------|------|-------|
| quality | `reviewers/quality.md` | Bugs, security, race conditions |
| implementation | `reviewers/implementation.md` | Does code achieve the goal? |
| testing | `reviewers/testing.md` | Test coverage, fake test detection |
| simplification | `reviewers/simplification.md` | Over-engineering detection |
| documentation | `reviewers/documentation.md` | Missing doc updates |
| final-quality | `reviewers/final-quality.md` | Critical/major bugs only |
| final-implementation | `reviewers/final-implementation.md` | Critical requirements met? |

## Process

### Step 0: Check for Active Run

```bash
if [ -f .claude/status.json ]; then
  MODE=$(jq -r '.mode // empty' .claude/status.json)
  RESUME=$(jq -r '.resume // false' .claude/status.json)

  if [ "$MODE" = "turbo" ] && [ "$RESUME" = "true" ]; then
    echo "=== RESUMING ACTIVE TURBO RUN ==="
    PLAN_FILE=$(jq -r '.plan_file' .claude/status.json)
    CURRENT_PHASE=$(jq -r '.current_phase' .claude/status.json)
    # Continue from appropriate step
  fi
fi
```

### Step 1: Load Plan (with cap)

```bash
PLAN_FILE="$ARGUMENTS"
# Parse --calls and --no-codex flags...

if [ -z "$PLAN_FILE" ]; then
  PLAN_FILE=$(ls -t .claude/plans/*.md 2>/dev/null | head -1)
fi

# CAP: If plan > 200 lines, extract current phase only
PLAN_LINES=$(wc -l < "$PLAN_FILE")
if [ "$PLAN_LINES" -gt 200 ]; then
  echo "Plan is $PLAN_LINES lines — loading current phase only"
  # Extract from first unchecked phase header to next phase header or EOF
  awk '/^## Phase|^## Session/{if(found)exit; if(/\[ \]/)found=1} found' "$PLAN_FILE"
else
  cat "$PLAN_FILE"
fi
```

### Step 2: Task Execution

Same as /smoke — execute tasks one at a time with signal-based iteration.

Signal `<<<ALL_TASKS_DONE>>>` when all tasks complete.

### Step 3: Comprehensive Review (5 Agents)

**Build the changed files list and detect base branch:**

```bash
# Detect base branch
BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo "main")

# Get changed files (scoped — no full diff)
CHANGED_FILES=$(git diff --name-only ${BASE_BRANCH}...HEAD | tr '\n' ' ')
echo "Reviewing files: $CHANGED_FILES"

# Cleanup previous reviews
rm -f .claude/reviews/claude-*.md
```

**Launch ALL 5 agents IN PARALLEL using Task tool:**

For each agent, read the prompt from `.claude/agents/reviewers/{name}.md` and substitute:
- `{{BASE_BRANCH}}` → detected base branch
- `{{CHANGED_FILES}}` → the file list from above
- `{{PLAN_FILE}}` → the plan file path

```
All 5 agents use:
  subagent_type: "reviewer"
  model: "sonnet"

Agent 1: quality     → .claude/agents/reviewers/quality.md
Agent 2: implementation → .claude/agents/reviewers/implementation.md
Agent 3: testing     → .claude/agents/reviewers/testing.md
Agent 4: simplification → .claude/agents/reviewers/simplification.md
Agent 5: documentation → .claude/agents/reviewers/documentation.md
```

**After agents complete:**

1. **Collect findings** — summaries in parent context, details in `.claude/reviews/claude-*.md`
2. **Deduplicate** (same file:line + same issue = merge)
3. **Verify EACH finding:**
   - Read actual code at file:line (20-30 lines context)
   - Classify: CONFIRMED or FALSE POSITIVE
4. **Fix all CONFIRMED issues**
5. **Run tests and linter** — ALL must pass
6. **If issues were fixed:** Do NOT signal — loop runs again
7. **If no issues found:** `<<<REVIEW_DONE>>>`

### Step 4: Codex External Review

**Skip if --no-codex flag was used.**

```bash
codex review --base $BASE_BRANCH
```

**Claude evaluates Codex findings:**

For each finding:
1. Read code at location, trace the flow
2. Check plan — intentional design decision?
3. Assess actual impact
4. Valid → Fix it. Invalid → Document why.

**Iteration:**
- Fixed issues → No signal → Codex runs again
- No issues → Commit fixes → `<<<CODEX_DONE>>>`

### Step 5: Final Review (2 Agents)

Launch quality + implementation final reviewers in parallel:

```
Both agents use:
  subagent_type: "reviewer"
  model: "sonnet"

Agent 1: .claude/agents/reviewers/final-quality.md
Agent 2: .claude/agents/reviewers/final-implementation.md
```

Substitute `{{BASE_BRANCH}}`, `{{CHANGED_FILES}}`, `{{PLAN_FILE}}` same as Step 3.

Same iteration logic:
- Issues found + fixed → No signal → Run again
- No issues → `<<<FINAL_DONE>>>`

### Step 6: Complete

```markdown
## /turbo Complete

### Summary
- Plan: [name]
- Tasks: X/X completed
- Review iterations:
  - Comprehensive (5 agents): Y iterations, Z issues fixed
  - Codex: Y iterations, Z issues fixed
  - Final (2 agents): Y iterations, Z issues fixed

### Commits
[list of commits]

### Quality Metrics
- All tests: PASS
- Lint: PASS
- 5-agent review: PASS
- Codex review: PASS
- Final review: PASS

### Push when ready
git push
```

## status.json Schema

```json
{
  "mode": "turbo",
  "resume": true,
  "plan_file": ".claude/plans/feature.md",
  "current_phase": "comprehensive_review",
  "current_task": 5,
  "total_tasks": 5,
  "rate_limit": 100,
  "use_codex": true,
  "review_state": {
    "comprehensive": { "iteration": 2, "issues_fixed": 5 },
    "codex": { "iteration": 0, "issues_fixed": 0 },
    "final": { "iteration": 0, "issues_fixed": 0 }
  },
  "commits": [],
  "started_at": "2026-01-30T10:00:00Z"
}
```

## Safety Features

- **Circuit breaker:** 3 failures → halt
- **Rate limiting:** Default 100 calls/hour
- **Scoped review:** Reviewers see changed files only, not full diff
- **External review:** Codex provides independent analysis
- **Iterative verification:** Fixes are always re-checked

## Monitoring

```bash
watch -n2 'jq . .claude/status.json'
watch -n10 'git log --oneline -10'
```
