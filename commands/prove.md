---
name: prove
description: Have Codex prove the code works with concrete evidence
argument-hint: "[description of what to prove]"
---

# Prove - Evidence-Based Verification

Have Codex (GPT-5.4 debugging specialist) generate concrete evidence that code works.
Not "tests pass" - actual proof of behavior.

**Use after implementing, before claiming "done".**

## Usage

```
/prove                              # Prove recent changes work
/prove "authentication flow"        # Prove specific functionality
/prove --diff main                  # Prove changes from main branch
```

## What Codex Does

| Evidence Type | How It's Generated |
|---------------|-------------------|
| **Behavioral diff** | Show before/after behavior with same inputs |
| **Edge case proof** | Test boundaries, nulls, empties, limits |
| **Error path proof** | Trigger each error condition, verify handling |
| **Integration proof** | Trace data flow through connected components |
| **Regression proof** | Verify old behavior still works |

## Process

### Step 1: Identify What to Prove

If argument provided, use that as focus.
Otherwise, detect recent changes:

```bash
# Get files changed in last commit or uncommitted
CHANGED=$(git diff --name-only HEAD~1 2>/dev/null || git diff --name-only)

if [ -z "$CHANGED" ]; then
  echo "No recent changes to prove. Specify what to prove:"
  echo "  /prove \"the login endpoint handles invalid passwords\""
  exit 1
fi

echo "Changes to prove:"
echo "$CHANGED"
```

### Step 2: Send to Codex

Use Codex MCP to analyze the code:

```
Call mcp__codex__codex with prompt:

"You are a verification specialist. Your job is to PROVE code works, not just say it does.

TASK: Generate concrete evidence that this code works correctly.

CHANGES:
[git diff output]

FOCUS AREA: [argument if provided]

For each significant change, provide:

1. BEHAVIORAL EVIDENCE
   - Input: [specific test input]
   - Expected: [what should happen]
   - How to verify: [command or test to run]

2. EDGE CASE EVIDENCE
   - Edge case: [description]
   - Input: [edge case input]
   - Expected: [handling behavior]
   - How to verify: [command or test]

3. ERROR PATH EVIDENCE
   - Error condition: [what triggers it]
   - Input: [trigger input]
   - Expected: [error handling behavior]
   - How to verify: [command or test]

Generate RUNNABLE verification commands. Not theory - proof."
```

### Step 3: Execute Verification Commands

For each verification command Codex provides:

1. Run the command
2. Capture output
3. Compare to expected
4. Record: PROVED or FAILED

```bash
# Example verification execution
echo "=== Testing login with invalid password ==="
curl -X POST localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"wrong"}' \
  -w "\nStatus: %{http_code}\n"

# Expected: 401 status, error message
```

### Step 4: Generate Proof Report

```markdown
## Proof Report

### Subject: [what was proved]

### Evidence Summary

| Claim | Evidence | Status |
|-------|----------|--------|
| Login rejects bad password | 401 + error message | ✅ PROVED |
| Token expires after 1 hour | JWT exp claim verified | ✅ PROVED |
| Rate limiting kicks in at 5 attempts | 429 after 5 requests | ✅ PROVED |
| Empty email returns 400 | Validation error returned | ✅ PROVED |

### Detailed Evidence

#### 1. Login rejects bad password

**Input:**
```json
{"email": "test@test.com", "password": "wrongpassword"}
```

**Output:**
```json
{"error": "Invalid credentials", "code": "AUTH_FAILED"}
```
Status: 401

**Verdict:** ✅ PROVED - Returns 401 with appropriate error

#### 2. Token expires after 1 hour
...

### Failed Proofs

[Any claims that couldn't be proved]

### Confidence Level

HIGH / MEDIUM / LOW

Based on: [X evidence points collected, Y% coverage of changes]
```

### Step 5: Handle Failures

If any proof fails:

1. Report the failure clearly
2. Show expected vs actual
3. DO NOT claim the code works
4. Suggest investigation steps

```markdown
### ❌ PROOF FAILED: Rate limiting

**Claim:** Rate limiting kicks in at 5 attempts
**Expected:** 429 status after 5 rapid requests
**Actual:** 200 status on all requests

**Investigation needed:**
- Is rate limiting middleware attached to route?
- Is the limit configured correctly?
- Is Redis running (if using distributed rate limiting)?
```

## Why Codex?

Codex (GPT-5.4) is specifically tuned for:
- Debugging and verification
- Generating test cases
- Understanding code behavior
- Finding edge cases

It's the right tool for "prove this works" tasks.

## Example

```
/prove "the new caching layer"

Analyzing changes to src/cache/...

Sending to Codex for verification strategy...

## Proof Report

### Subject: Caching layer (src/cache/)

### Evidence Summary

| Claim | Evidence | Status |
|-------|----------|--------|
| Cache stores values | GET after SET returns value | ✅ PROVED |
| Cache respects TTL | Value gone after TTL expires | ✅ PROVED |
| Cache miss returns null | GET unknown key = null | ✅ PROVED |
| Cache handles concurrent writes | 100 parallel writes succeed | ✅ PROVED |
| Cache evicts LRU when full | Oldest evicted at capacity | ✅ PROVED |

### Confidence Level: HIGH

5/5 claims proved with concrete evidence.

The caching layer is verified working.
```

## Related Commands

| Command | Purpose |
|---------|---------|
| `/plan-review` | Review plan before execution |
| `/prove` | Prove code works (this) |
| `/grill` | Challenge your understanding |
| `/cook` | Execute with verification gates |
