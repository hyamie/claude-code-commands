---
name: scrap
description: Scrap current approach and implement the elegant solution with full context
argument-hint: "[optional: what to focus the redo on]"
---

# Scrap - Fresh Start with Full Context

"Knowing everything you know now, scrap this and implement the elegant solution."

Use when you've been circling, hit dead ends, or realized the approach is wrong. Claude has full context of what didn't work and can make a better decision.

**Use when you're 3+ iterations deep and it's getting messy.**

## Usage

```
/scrap                              # Scrap and redo recent work
/scrap "the caching implementation" # Scrap specific area
/scrap --keep-tests                 # Keep test files, redo implementation
```

## When to Use

✅ **Good times to scrap:**
- Third attempt at the same bug
- Code is getting more complex, not simpler
- "Let me try one more thing" has been said 3+ times
- You've learned the real problem is different than assumed
- Fighting the framework instead of working with it

❌ **Bad times to scrap:**
- First attempt that hit a snag (try fixing first)
- Working code that's just not pretty (refactor instead)
- User explicitly asked for the current approach

## Process

### Step 1: Assess What to Scrap

Identify the scope of the redo:

```bash
# Check uncommitted changes
git diff --stat

# Check recent commits that might be part of the failed approach
git log --oneline -5
```

Ask: What's the boundary of the failed attempt?
- Just uncommitted changes?
- Last N commits?
- Specific files?

### Step 2: Document What We Learned

Before scrapping, capture the lessons:

```markdown
## Lessons from Failed Attempt

### What didn't work
- [Approach 1]: Failed because [reason]
- [Approach 2]: Failed because [reason]

### What we learned
- The actual constraint is [X], not [Y] as assumed
- The framework doesn't support [Z], must work around
- The dependency has a bug in [scenario]

### Requirements we discovered
- Must handle [edge case]
- Performance matters for [specific case]
- Integration point requires [constraint]
```

### Step 3: Reset the Code

Based on scope:

```bash
# Option A: Just unstaged changes
git checkout -- .

# Option B: Including staged changes
git reset --hard HEAD

# Option C: Last N commits (CAREFUL)
git reset --hard HEAD~N

# Option D: Specific files only
git checkout HEAD -- path/to/file1 path/to/file2
```

If `--keep-tests` flag: Don't reset test files.

### Step 4: The Elegant Solution

With full context of:
- What the code needs to do
- What approaches failed and why
- What constraints were discovered
- What edge cases exist

Implement the RIGHT solution:

```markdown
## Fresh Implementation

### Approach
[Describe the new, informed approach]

### Why this is better
- Avoids [failed approach issue 1]
- Handles [discovered edge case]
- Works with [constraint] instead of fighting it

### Implementation
[Do the actual implementation]
```

### Step 5: Verify the Redo

Run verification to ensure the new approach works:

```bash
# Run tests
npm test  # or pytest, cargo test, etc.

# Run lint
npm run lint

# Build check
npm run build
```

### Step 6: Report

```markdown
## Scrap Complete

### What was scrapped
- [files/commits affected]

### Lessons captured
- [key learnings from failed attempt]

### New approach
- [summary of fresh implementation]

### Verification
- Tests: PASS
- Lint: PASS
- Build: PASS

### Next steps
- [continue with whatever comes next]
```

## Example

```
/scrap "the auth middleware"

## Assessing scope...

Uncommitted changes in:
- src/middleware/auth.ts (147 lines changed)
- src/utils/jwt.ts (89 lines changed)

Last 2 commits also related:
- abc123: "feat: add jwt verification"
- def456: "fix: handle expired tokens"

## Lessons from Failed Attempt

### What didn't work
- Custom JWT parsing: Too complex, edge cases in signature verification
- Storing tokens in localStorage: XSS vulnerability discovered
- Manual expiry checking: Race condition with refresh

### What we learned
- The jose library handles all JWT edge cases properly
- httpOnly cookies are the right storage for tokens
- Need to handle refresh atomically with validation

### Requirements discovered
- Must support both cookie and header auth (mobile clients)
- Refresh must happen server-side to avoid race
- Need to blacklist on logout (can't just expire)

## Resetting...

git reset --hard HEAD~2
git checkout -- src/middleware/auth.ts src/utils/jwt.ts

## Fresh Implementation

### Approach
Use jose library for JWT, httpOnly cookies as primary, Authorization
header as fallback. Server-side refresh with atomic check-and-refresh.
Redis blacklist for logout.

[Implementation proceeds with full context...]

## Scrap Complete

### What was scrapped
- 2 commits + uncommitted changes
- ~236 lines of custom JWT code

### New approach
- jose library for JWT (12 lines)
- Cookie + header dual support (18 lines)
- Atomic refresh middleware (24 lines)
- Redis blacklist (15 lines)

### Verification
- Tests: PASS (14 tests)
- Lint: PASS
- Build: PASS

Total: 69 lines vs 236 lines, handles all edge cases.
```

## Related Commands

| Command | Purpose |
|---------|---------|
| `/rollback` | Revert last /cook or /smoke phase |
| `/scrap` | Full redo with learned context (this) |
| `/prove` | Verify the new implementation works |
| `/grill` | Test your understanding of the redo |
