---
name: continue
description: Pick up where last session left off
---

# Continue Previous Session

Pick up where the last session left off using project-specific session state.

## Process

1. **Ground yourself in project reality** (DO THIS FIRST)

   **You MUST read these files before anything else.** Session-resume.json may be stale. These files are ground truth.

   ```bash
   # Project identity and rules
   cat CLAUDE.md 2>/dev/null | head -100

   # What features exist and their status
   cat feature_list.json 2>/dev/null

   # Project spec if exists
   cat .claude/project-spec.json 2>/dev/null

   # Recent work (last 15 commits)
   git log --oneline -15

   # Current branch and working tree status
   git branch --show-current
   git status --short
   ```

   **Understand the project from these files.** Form your own understanding of:
   - What this project is
   - What features are complete vs incomplete
   - What recent work has been done (from git log)
   - Current branch and any uncommitted changes

2. **Read session state file**
   ```bash
   cat .claude/session-resume.json 2>/dev/null || echo '{"error": "No session state found"}'
   ```

3. **Check for state drift** (IMPORTANT)
   ```bash
   # Get last_commit from session-resume.json
   LAST_SAVED=$(jq -r '.last_commit // "none"' .claude/session-resume.json 2>/dev/null)

   # Get current HEAD
   CURRENT_HEAD=$(git rev-parse HEAD 2>/dev/null)

   # Check for commits since last /done
   if [ "$LAST_SAVED" != "none" ] && [ "$LAST_SAVED" != "$CURRENT_HEAD" ]; then
     echo "⚠️ DRIFT DETECTED: Work done since last /done"
     git log --oneline ${LAST_SAVED}..HEAD

     # Show FULL commit messages for context
     echo ""
     echo "=== Full commit details (use this to understand what was done) ==="
     git log --format="commit: %h%ndate: %ci%nmessage: %s%n%b%n---" ${LAST_SAVED}..HEAD
   fi

   # Check for uncommitted changes
   git status --short
   ```

   **If drift detected:**
   - Read the full commit messages above
   - Incorporate that work into your understanding of current state
   - Update the "completed" list mentally to include drift commits
   - Tell user: "Session state is from [date], but I see [N] additional commits. Based on commit messages, it looks like [summarize work done]."

4. **If session-resume.json exists**, parse and display:
   - `completed`: What was done last session
   - `in_progress`: What's currently being worked on
   - `next_steps`: What to do next
   - `blockers`: Any issues
   - `notes`: Important context
   - `last_commit`: Where we left off
   - `branch`: Current branch

5. **If no session state exists**, check for fallbacks:
   ```bash
   cat claude-progress.txt 2>/dev/null | tail -30
   ```

6. **Read incomplete features for context**
   ```bash
   cat feature_list.json 2>/dev/null | jq '.features[] | select(.status != "complete")' 2>/dev/null
   ```

7. **Synthesize and present summary**:

   Combine what you learned from exploration (step 1) with session-resume.json (step 2).
   If they conflict, trust the exploration (files/git) over session-resume.json.

   ```markdown
   ## Project State

   ### Project Overview
   [1-2 sentences from CLAUDE.md about what this project is]

   ### Current Status (from exploration)
   - Branch: [current branch]
   - Uncommitted changes: [yes/no, count]
   - Recent commits: [summarize last 3-5 commits]

   ### Feature Progress (from feature_list.json)
   - Complete: [count] features
   - In Progress: [list incomplete features]
   - Blocked: [any blockers]

   ### Last Saved Session ([date from session-resume.json])
   - Completed: [list]
   - In progress: [list]
   - Next steps: [list]
   [Note any conflicts with current state]

   ### Recommended Next Action
   Based on feature_list.json and recent commits, I recommend:
   [Specific next action]

   Ready to proceed, or do you want to work on something else?
   ```

8. **Wait for user confirmation** before starting work

## Source

Session state is stored in `.claude/session-resume.json`, created by `/done` command.
This is project-specific - each project has its own session state.
