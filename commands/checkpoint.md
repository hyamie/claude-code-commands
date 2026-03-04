# /checkpoint - Emergency Context Save

Quickly capture session context before compaction hits.

## When to Use

- Context is getting long
- You're about to do something that might trigger compaction
- You want to save state before ending session

## Instructions

Save context using TWO mechanisms for redundancy:

### 1. Scratch Pad (ephemeral, fast recovery)

Call `brain_scratch_set` with a compact JSON payload:

```
brain_scratch_set(
  key="checkpoint",
  value='{
    "decisions": ["decision 1 (max 100 chars)", "decision 2"],
    "architecture": ["schema note", "api design"],
    "current_task": "what we are working on right now",
    "blockers": ["any issues blocking progress"],
    "next_steps": ["what to do next"]
  }',
  type="checkpoint",
  ttl_hours=48
)
```

### 2. Persistent Facts (important decisions survive forever)

For each KEY decision or architecture choice, also store as a permanent fact:

```
brain_remember(
  content="Decided to use JWT over sessions for stateless scaling",
  type="decision",
  summary="JWT for auth",
  project="<current project>",
  keywords="auth,jwt,session",
  importance=7
)
```

Only store 2-5 of the MOST important items as facts. The scratch pad handles the rest.

**Rules:**
- Keep each item under 100 characters
- Max 10 decisions, 10 architecture notes
- Max 5 blockers, 5 next_steps
- Be terse - this is emergency capture
- Only brain_remember things worth keeping across sessions

**Output only:** `Checkpoint saved: N scratch items, M facts stored`

## Token Budget

This command is designed to use ~300 tokens total:
- Command prompt: ~50 tokens
- Your JSON response: ~200 tokens
- Tool overhead: ~50 tokens

Compare to verbose summarization which could use 1000+ tokens.

## Example

User types `/checkpoint`, you respond:

1. Save scratch:
```
brain_scratch_set(
  key="checkpoint",
  value='{"decisions":["JWT for auth - stateless scaling","Supabase over Firebase - full SQL"],"architecture":["User table: id, email, role, created_at"],"current_task":"Implementing user registration endpoint","blockers":[],"next_steps":["Add email validation","Create tests"]}',
  type="checkpoint",
  ttl_hours=48
)
```

2. Store key decision as fact:
```
brain_remember(
  content="Chose JWT over sessions for auth - enables stateless horizontal scaling",
  type="decision",
  summary="JWT for auth (stateless)",
  project="hana-hub",
  keywords="auth,jwt,session,scaling",
  importance=7
)
```

Output: `Checkpoint saved: 4 scratch items, 1 fact stored`
