---
name: resume
description: Resume work from last session
---

# Resume Previous Session

Continue where the last session left off using project-specific session state.

## Process

1. **Read session resume file (primary source)**
   ```bash
   cat .claude/session-resume.json 2>/dev/null || echo "No session-resume.json found"
   ```

   If `.claude/session-resume.json` exists, use it. This contains:
   - `completed`: What was done last session
   - `in_progress`: What's currently being worked on
   - `next_steps`: What to do next
   - `blockers`: Any issues
   - `notes`: Important context
   - `last_commit`: Where we left off
   - `branch`: Current branch

2. **Fallback: Read progress file**
   Only if session-resume.json doesn't exist:
   ```bash
   cat claude-progress.txt 2>/dev/null | tail -50
   ```

3. **Read feature list for context**
   ```bash
   cat feature_list.json 2>/dev/null | jq '.features[] | select(.status != "complete")' 2>/dev/null
   ```

4. **Summarize for user**
   ```markdown
   ## Resuming Session

   ### Last Session ([date from session-resume.json])
   - Completed: [from session-resume.json]
   - In progress: [from session-resume.json]
   - Blockers: [from session-resume.json]

   ### Next Steps
   [from session-resume.json next_steps]

   ### Context
   [from session-resume.json notes]

   Ready to continue? Or would you like to work on something different?
   ```

5. **Wait for confirmation** before starting work

## Important

- **DO NOT use episodic memory search** - session state is in `.claude/session-resume.json`
- This file is project-specific, created by `/done` command
- If no session-resume.json exists, this is likely a new session
