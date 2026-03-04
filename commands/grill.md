---
name: grill
description: Have Codex interrogate you about the code - must pass before proceeding
argument-hint: "[topic or leave empty for recent changes]"
---

# Grill - Code Interrogation Mode

Codex asks probing questions about your implementation. You must demonstrate understanding before proceeding. Catches assumptions, gaps, and "it works but I don't know why" situations.

**Use before PR, after implementing something complex, or when onboarding.**

## Usage

```
/grill                              # Grill on recent changes
/grill "the authentication flow"    # Grill on specific topic
/grill --strict                     # Must pass ALL questions
```

## How It Works

1. Codex analyzes your code
2. Generates probing questions about critical areas
3. You answer each question
4. Codex evaluates your understanding
5. **PASS** = proceed, **FAIL** = more study needed

## Question Categories

| Category | Example Questions |
|----------|-------------------|
| **Why decisions** | "Why did you use a map instead of an array here?" |
| **Edge cases** | "What happens if the user submits an empty form?" |
| **Error handling** | "How does the system behave if the database is down?" |
| **Security** | "How do you prevent SQL injection in this query?" |
| **Concurrency** | "What happens if two users update this simultaneously?" |
| **Dependencies** | "What breaks if this external API is slow?" |

## Process

### Step 1: Identify Subject

If argument provided, use that as focus.
Otherwise, detect recent changes:

```bash
CHANGED=$(git diff --name-only HEAD~1 2>/dev/null || git diff --name-only)

if [ -z "$CHANGED" ]; then
  echo "No recent changes. Specify what to be grilled on:"
  echo "  /grill \"the payment processing logic\""
  exit 1
fi
```

### Step 2: Generate Questions via Codex

```
Call mcp__codex__codex with prompt:

"You are a senior engineer conducting a code review interview.

CODE TO REVIEW:
[relevant code sections]

CONTEXT:
[CLAUDE.md contents]

Generate 5-7 probing questions that test whether the developer truly understands this code. Focus on:

1. DESIGN DECISIONS - Why was this approach chosen over alternatives?
2. EDGE CASES - What happens at boundaries and with unexpected input?
3. ERROR HANDLING - How does the system fail? What's the recovery path?
4. SECURITY - What attack vectors exist? How are they mitigated?
5. SCALABILITY - What happens under load? What's the bottleneck?

For each question:
- The question itself
- What a GOOD answer should include
- Red flags that indicate poor understanding

Be tough but fair. The goal is learning, not gotchas."
```

### Step 3: Interactive Q&A

Present questions one at a time using AskUserQuestion tool:

```
Question 1 of 5:

"In your authentication middleware, you're checking the JWT signature
before checking if the token is expired. Why that order?"

Your answer:
[user types response]
```

### Step 4: Evaluate Answers via Codex

For each answer, send to Codex for evaluation:

```
Call mcp__codex__codex with prompt:

"Evaluate this answer to a code review question.

QUESTION: [question]
EXPECTED GOOD ANSWER SHOULD INCLUDE: [criteria from step 2]
USER'S ANSWER: [their response]

Rate the answer:
- PASS: Demonstrates solid understanding
- PARTIAL: Gets the idea but missing key details
- FAIL: Misses the point or shows misunderstanding

Provide brief feedback explaining the rating."
```

### Step 5: Track Score and Report

```markdown
## Grill Results

### Subject: [topic]

### Questions & Answers

#### Q1: Why check signature before expiry?
**Your answer:** "If the signature is invalid, the token is completely
untrustworthy so there's no point checking expiry..."
**Rating:** ✅ PASS
**Feedback:** Correct - signature validation is the trust anchor.

#### Q2: What happens if Redis is down?
**Your answer:** "Um, I think it falls back to... memory cache?"
**Rating:** ❌ FAIL
**Feedback:** There's no fallback configured. The auth middleware
will throw, returning 500 to users. You should add graceful degradation.

#### Q3: ...

### Final Score: 4/5 PASSED

### Verdict: ✅ PASS (80% threshold met)

You demonstrated solid understanding of the authentication flow.
One gap identified - add Redis failure handling before shipping.

### Action Items
- [ ] Add Redis connection error handling
- [ ] Consider fallback strategy for cache failures
```

### Step 6: Strict Mode

With `--strict` flag, ALL questions must pass:

```markdown
### Verdict: ❌ FAIL (strict mode - 4/5, need 5/5)

You must demonstrate understanding of ALL areas before proceeding.

Review these topics:
- Redis failure handling (Q2)

Run /grill again after studying.
```

## Why This Matters

- **Catches "copy-paste" code** - If you can't explain it, you don't own it
- **Surfaces hidden assumptions** - "I assumed X would never happen"
- **Prevents "works on my machine"** - Forces thinking about edge cases
- **Learning tool** - The questions teach as much as the answers

## Example Session

```
/grill "the caching layer"

Analyzing src/cache/...

Generating questions from Codex...

## Code Interrogation: Caching Layer

### Question 1 of 5

"Your cache uses an LRU eviction policy with a max size of 1000 entries.
How did you choose that number, and what happens if the working set
is larger than 1000?"

[User answers via interactive prompt]

Evaluating...

✅ PASS - Good awareness of memory tradeoffs and degradation behavior.

### Question 2 of 5

"The cache stores serialized JSON. What happens if someone stores
a value with a circular reference?"

[User answers]

Evaluating...

❌ FAIL - JSON.stringify throws on circular refs. You need to handle this.

...

## Grill Results

### Final Score: 3/5 PASSED

### Verdict: ⚠️ PARTIAL PASS

You understand the core caching logic but missed:
- Circular reference handling
- Cache stampede prevention

Study these before shipping to production.
```

## Related Commands

| Command | Purpose |
|---------|---------|
| `/plan-review` | Review plan before execution |
| `/prove` | Prove code works with evidence |
| `/grill` | Challenge your understanding (this) |
| `/turbo` | Maximum rigor execution |
