# /recall - Restore Context After Compaction

Restore session context after compaction or when context feels lost.

## When to Use

- After compaction happened (you notice context is suddenly shorter)
- When you're uncertain about prior decisions
- At the start of a resumed session
- When user says "what were we working on?"

## Instructions

1. Query `brain_context` for the current project's facts + scratch entries
2. Query `brain_recall` with relevant search terms (current task, project name)
3. Check session state file for tracked failures
4. Report what you found in a structured summary

## Process

### Step 1: Get Brain Context (Hot Tier)

```
brain_context(project="<current project name>")
```

This returns:
- All hot_facts for the project (decisions, architecture, errors, etc.)
- Last 10 non-expired scratch entries (from /checkpoint saves)

### Step 2: Search Brain for Relevant Facts

```
brain_recall(query="<what we were working on>", project="<project>", limit=10)
```

This does hybrid search (vector + FTS) over hot_facts. Use keywords from:
- The project name
- Any task context you still have
- Recent file paths or feature names

### Step 3: Check Scratch Pad (Checkpoint Data)

```
brain_scratch_get(key="checkpoint")
```

This retrieves the last /checkpoint save if one exists and hasn't expired.

### Step 4: Check Session State for Failures

Read `~/.claude/session-state.json` to retrieve tracked failures:

```bash
cat ~/.claude/session-state.json | jq '.failures[:5]'
```

This shows recent failures captured across sessions by session-analyze.py. Include these in your "Failed Attempts" section to avoid retry loops.

### Step 5: Report Summary

After gathering context, provide a brief summary:

```
## Session Context Restored

**Current Task:** [from brain facts/scratch]

**Key Decisions:**
- [decision 1]
- [decision 2]

**Architecture:**
- [schema/api notes]

**Failed Attempts:**
- [from session-state.json failures]

**Blockers:** [any issues]

**Next Steps:** [what to do next]
```

## Example Flow

User: `/recall`

You:
1. Call `brain_context(project="hana-hub")` → get all facts + scratch
2. Call `brain_recall(query="authentication endpoint", project="hana-hub")` → search for specific context
3. Call `brain_scratch_get(key="checkpoint")` → get checkpoint data
4. Output:

```
## Session Context Restored

**Current Task:** Building user authentication system

**Key Decisions:**
- JWT over sessions for stateless scaling
- Supabase for backend (full SQL access)

**Architecture:**
- User table: id, email, role, created_at
- Auth endpoint: POST /api/auth/login

**Failed Attempts:**
- Redis sessions didn't work (WSL networking issues)

**Next Steps:**
1. Add refresh token logic
2. Create protected route middleware
```
