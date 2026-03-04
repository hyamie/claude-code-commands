---
name: ready
description: Convert plan-mode plan to /turbo format, save state, end session
argument-hint: "[--smoke] [--cook]"
---

# Ready - Convert Plan to Turbo Format & End Session

You just exited plan mode. The user wants to execute the plan in a **fresh session**, not now.

Your job: take whatever plan was just created in this session, reformat it for `/turbo`, do `/done` teardown, and end the session.

**This is NOT optional. Do ALL steps. Do NOT ask questions. Do NOT offer alternatives.**

## Context

The user's workflow:
1. Enter plan mode (Shift+Tab shortcut)
2. Claude writes a plan, hits ExitPlanMode dialog
3. User exits plan mode (Shift+Tab again)
4. User types `/ready`
5. **You are here.** Convert the plan, save everything, end the session.

## Process

### Step 1: Find the Plan Content

The plan was just written during plan mode in THIS session. Find it:

1. **Check if a plan file was already saved** to `.claude/plans/`:
   ```bash
   ls -t .claude/plans/*.md 2>/dev/null | head -1
   ```
   If a file was modified in the last 10 minutes, use it.

2. **If no file was saved**, the plan only exists in the conversation context.
   Extract it from what was discussed and create a new file.

3. **Determine the plan name** from the content (the main heading or summary).
   Slugify it for the filename: `feature-name.md`

### Step 2: Reformat into /turbo Structure

The plan MUST match this exact structure for `/turbo` to consume it:

```markdown
## Plan: [Feature Name]

**Summary:** [1-2 sentence description]
**Confidence:** [0.0-1.0]
**Estimated Sessions:** [X]

### Phase 1: [Name] (Session 1)
- [ ] Task 1: [Specific, actionable description]
- [ ] Task 2: [Specific, actionable description]
- [ ] Task 3: [Specific, actionable description]
📍 **SESSION CHECKPOINT** - Commit, /done, restart

### Phase 2: [Name] (Session 2)
- [ ] Task 4: [Specific, actionable description]
- [ ] Task 5: [Specific, actionable description]
📍 **SESSION CHECKPOINT** - Commit, /done, restart

### Risks
- [Known risks or edge cases]
```

**Rules for conversion:**
- **Maximum 3 tasks per phase.** If the original plan has more, split into additional phases.
- **Every phase ends with a SESSION CHECKPOINT line.**
- **Tasks must be specific and actionable** — not vague like "implement the feature". Each task should be clear enough that a fresh Claude session can execute it without guessing.
- **Preserve all technical detail** from the original plan. Don't lose information during reformatting.
- **Add confidence score** based on how well-defined the tasks are.

### Step 3: Save the Plan File

```bash
# Save to .claude/plans/
PLAN_FILE=".claude/plans/[slugified-name].md"
```

Write the reformatted plan to this file.

### Step 4: Mark as Approved

Add approval header at the very top of the plan file:

```markdown
<!-- APPROVED: [ISO timestamp] -->
<!-- EXECUTE WITH: /turbo .claude/plans/[filename].md -->
```

Parse flags for execution command:
- Default: `/turbo`
- `--smoke` flag: use `/smoke`
- `--cook` flag: use `/cook`

### Step 5: Save Session State

Write `.claude/session-resume.json`:

```json
{
  "timestamp": "[ISO timestamp]",
  "session_date": "[YYYY-MM-DD]",
  "verification_status": "skipped",
  "completed": [
    "Created and approved plan: [plan name]"
  ],
  "in_progress": [],
  "next_steps": [
    "[EXEC_CMD] [PLAN_FILE]"
  ],
  "blockers": [],
  "notes": [
    "Plan approved and formatted for turbo execution",
    "Start fresh session, /continue, then run the command above"
  ],
  "last_commit": "[current HEAD SHA]",
  "branch": "[current branch]"
}
```

### Step 6: Update Progress Log

Append to `claude-progress.txt`:

```
## Session: [today's date]

### Verification
- Status: ⚠️ SKIPPED (planning session)

### Completed
- Created and approved plan: [plan name]

### Next Steps
1. [EXEC_CMD] [PLAN_FILE]

### Notes
- Plan formatted for /turbo execution in fresh session

---
```

### Step 7: Commit Everything

```bash
git add .claude/plans/[file] .claude/session-resume.json claude-progress.txt
git commit -m "chore: plan ready for turbo - [plan name]

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

### Step 8: Print Summary and STOP

```markdown
## Plan Ready

**Plan:** [plan file path]
**Phases:** [count] | **Tasks:** [total count]
**Execute:** `[EXEC_CMD] [PLAN_FILE]`

### Exit now. Next session:
1. `cld`
2. `/continue`
3. `[EXEC_CMD] [PLAN_FILE]`
```

**AFTER PRINTING THIS SUMMARY, YOU ARE DONE.**

DO NOT:
- Ask follow-up questions
- Suggest additional work
- Wait for confirmation
- Offer alternatives
- Say "anything else?"

The session is OVER. The user will Ctrl+C and start fresh.
