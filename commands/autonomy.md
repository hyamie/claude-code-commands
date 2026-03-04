---
name: autonomy
description: Start unattended autonomous loop (Docker sandbox only)
argument-hint: "TASK_DESCRIPTION [--max-iterations N]"
---

# Autonomous Execution Mode

Start a long-running unattended loop using ralph-wiggum. **Docker sandbox only.**

## Safety Requirements

**CRITICAL: This command should ONLY be run inside a Docker container.**

If you're not in Docker:
1. Exit this session
2. Run `c` (Docker Claude alias) to start sandboxed session
3. Then run `/autonomy` from within Docker

## Usage

```
/autonomy "Build feature X with tests. All tests must pass."
/autonomy "Refactor module Y. Lint and typecheck must pass." --max-iterations 30
```

## What Happens

1. **Validates environment** - Warns if not in Docker
2. **Constructs ralph-loop prompt** with:
   - Your task description
   - Verification requirements (tests/lint/typecheck)
   - Clear completion criteria
   - Escape hatch instructions
3. **Starts ralph-loop** with safe defaults

## Default Settings

- `--max-iterations 25` (override with `--max-iterations N`)
- `--completion-promise "COMPLETE"`
- Verification required before completion

## Prompt Template

When you run `/autonomy "Your task"`, it expands to:

```
/ralph-loop "
TASK: Your task

REQUIREMENTS:
1. Complete the task as described
2. Run verification after each major change:
   - If .claude/verify.sh exists, run it
   - Otherwise: npm test, npm run lint, npm run typecheck (if available)
3. Fix any failures before proceeding

COMPLETION CRITERIA:
- Task is functionally complete
- All verification passes
- Code is committed to a new branch
- PR is created (if GitHub is available)

WHEN COMPLETE:
Output: <promise>COMPLETE</promise>

IF BLOCKED (after 15+ iterations):
- Document what's blocking progress
- List what was attempted
- Suggest alternative approaches
- Do NOT output false completion promise
" --max-iterations 25 --completion-promise "COMPLETE"
```

## Example Sessions

### Feature Development
```
/autonomy "Implement user authentication with JWT. Include login, logout, token refresh. All tests must pass."
```

### Refactoring
```
/autonomy "Migrate from CommonJS to ESM modules. No functionality changes. All existing tests must still pass."
```

### Bug Fix
```
/autonomy "Fix the race condition in the connection pool. Add regression test. Verify with load test."
```

## Monitoring

While the loop runs:
- Check terminal periodically for progress
- iTerm2 notifications will alert on completion (if configured)
- Use `/cancel-ralph` to stop if needed

## Stop Conditions

The loop will stop when:
1. **Success**: Claude outputs `<promise>COMPLETE</promise>`
2. **Iteration limit**: After `--max-iterations` attempts
3. **Manual cancel**: You run `/cancel-ralph`

## Post-Completion

After the loop completes:
1. Review the changes: `git diff main...HEAD`
2. Check the PR (if created)
3. Run `/verify` to confirm all checks pass
4. If satisfied, merge or request review

## Notes

- **Docker only**: Never run unattended outside sandbox
- **Cost awareness**: Long loops consume tokens. 25 iterations ≈ $25-50 typical
- **Clear tasks work best**: Vague tasks lead to loops
- **Include verification**: Tasks without verification criteria may never complete
