---
name: plan-review
description: Get Gemini's second opinion on a plan before execution
argument-hint: "[PLAN_FILE or leave empty for latest plan]"
---

# Plan Review - Staff Engineer Second Opinion

Get Gemini to review your plan before `/cook` or `/smoke`. Different model family catches different blind spots.

**Use after `/plan`, before `/cook`.**

## Usage

```
/plan "Build user authentication"   # Create the plan
/plan-review                        # Gemini reviews it
/cook                               # Execute with confidence
```

Or review a specific plan:
```
/plan-review .claude/plans/my-feature.md
```

## What Gemini Reviews

| Category | Questions Asked |
|----------|-----------------|
| **Missing steps** | What's not covered? What will break? |
| **Wrong order** | Dependencies out of sequence? |
| **Over-engineering** | Factory pattern for 2 methods? |
| **Under-engineering** | Missing error handling? Security? |
| **Simpler alternatives** | Could use existing library/service? |
| **Security holes** | Auth, injection, secrets exposed? |
| **Dependency risks** | Unmaintained packages? Version conflicts? |

## Process

### Step 1: Find and Load Plan

```bash
PLAN_FILE="$ARGUMENTS"

# If no argument, find the most recent plan
if [ -z "$PLAN_FILE" ]; then
  PLAN_FILE=$(ls -t .claude/plans/*.md 2>/dev/null | head -1)
fi

if [ -z "$PLAN_FILE" ] || [ ! -f "$PLAN_FILE" ]; then
  echo "No plan found. Create a plan first with /plan"
  exit 1
fi

echo "Reviewing plan: $PLAN_FILE"
```

### Step 2: Gather Context

Collect:
1. The plan file contents
2. CLAUDE.md (project context)
3. Current codebase structure (key directories)
4. Any existing related code mentioned in the plan

### Step 3: Send to Gemini

Use the `/gemini` skill with `--plan` mode:

```
/gemini --plan
```

The gemini skill will:
1. Filter secrets from context
2. Send plan + project context to Gemini
3. Write full response to `.claude/gemini-response.md`
4. Return summary to Claude

### Step 4: Analyze Gemini's Feedback

Read the full response from `.claude/gemini-response.md`.

Categorize findings:
- **CRITICAL:** Must fix before execution (security, missing core steps)
- **IMPORTANT:** Should fix (better approaches, missing edge cases)
- **MINOR:** Nice to have (style, minor optimizations)

### Step 5: Report Results

```markdown
## Plan Review Complete

### Plan: [plan-name]

### Gemini's Assessment

**Overall:** APPROVE / APPROVE WITH CHANGES / RETHINK

### Critical Issues (fix before /cook)
- [issue 1]
- [issue 2]

### Important Suggestions
- [suggestion 1]
- [suggestion 2]

### Minor Notes
- [note 1]

### Recommended Changes to Plan
1. [specific change to make]
2. [specific change to make]

📄 Full analysis: `.claude/gemini-response.md`

### Next Steps
- Fix critical issues in the plan
- Run `/plan-review` again if major changes made
- Run `/cook` when ready
```

## Why Gemini?

Different model families have different blind spots. Claude might miss something that Gemini catches, and vice versa. Using both gives you:

- **Perspective diversity** - Different training, different assumptions
- **Architectural review** - Gemini is strong at system design critique
- **Second pair of eyes** - Catches assumptions you both might share

## Example

```
/plan-review

Reviewing plan: .claude/plans/add-user-auth.md

Sending to Gemini for review...

## Plan Review Complete

### Plan: add-user-auth.md

### Gemini's Assessment

**Overall:** APPROVE WITH CHANGES

### Critical Issues
- Phase 2 creates JWT tokens but Phase 1 doesn't set up the signing key
- No logout endpoint - tokens live forever

### Important Suggestions
- Consider using Supabase Auth instead of rolling your own
- Add rate limiting to login endpoint (brute force protection)
- Session table should have expires_at column

### Minor Notes
- Could use httpOnly cookies instead of localStorage for tokens

### Recommended Changes to Plan

1. Add to Phase 1: "Generate and store JWT signing key in env"
2. Add to Phase 2: "Implement logout endpoint (blacklist token)"
3. Add to Phase 2: "Add rate limiting middleware to auth routes"

📄 Full analysis: `.claude/gemini-response.md`

Ready to update the plan? Then run /cook.
```

## Related Commands

| Command | Purpose |
|---------|---------|
| `/plan` | Create the plan |
| `/plan-review` | Review before execution (this) |
| `/cook` | Execute one phase |
| `/smoke` | Execute all phases |
| `/turbo` | Maximum rigor execution |
