---
name: plan
description: Create implementation plan
---

# Create Plan

Have Donnie create an implementation plan with session checkpoints.

## Input
$ARGUMENTS - The requirements or feature to plan

## Process

Donnie will:
1. **Check for PRD** — look for a matching PRD in `.claude/plans/prd-*.md`
2. Read requirements (from PRD if available, otherwise from $ARGUMENTS)
3. Research codebase if needed
4. Create structured plan **with session checkpoints**
5. Identify uncertainties
6. Ask clarifying questions
7. Wait for approval

## PRD Integration

Before starting the plan, check for an existing PRD:

```bash
ls -t .claude/plans/prd-*.md 2>/dev/null | head -5
```

If a PRD exists that matches the feature being planned:
- Read it and use its goals, acceptance criteria, and constraints as inputs
- Reference it in the plan header: `**PRD:** .claude/plans/prd-{name}.md`
- Derive plan tasks from PRD goals — every goal should map to at least one task
- Copy acceptance criteria into the plan's verification section
- Respect non-goals — do NOT plan work that the PRD explicitly excludes

If no PRD exists, proceed normally from $ARGUMENTS. The PRD is optional.

## Context Management Rule

**Maximum 3 tasks per phase.** This prevents context degradation.

- Each task runs in a fresh subagent with clean 200k context
- More than 3 tasks = context pollution = quality drops
- If you need more tasks, split into additional phases
- Each phase ends with a session checkpoint anyway

## Required Output Format

Plans MUST include:

```markdown
## Plan: [Feature Name]

**Summary:** [What we're building]
**PRD:** [.claude/plans/prd-{name}.md or "None"]
**Confidence:** [0.0-1.0]
**Estimated Sessions:** [X sessions expected]

### Phase 1: [Name] (Session 1)
- [ ] Task 1
- [ ] Task 2
- [ ] Task 3
📍 **SESSION CHECKPOINT** - Commit, /done, restart

### Phase 2: [Name] (Session 2)
- [ ] Task 4
- [ ] Task 5
📍 **SESSION CHECKPOINT** - Commit, /done, restart

[Continue phases as needed...]

### Questions
- [Clarifications needed]

### Risks
- [Potential issues]
```

## Checkpoint Rules

1. **Maximum 2-3 hours of work per phase**
2. **Checkpoints go after natural boundaries:**
   - Feature complete with tests passing
   - Major context shift (backend → frontend)
   - Commit-worthy state
3. **Never more than 3 checkpoints ahead** - reassess after each session

## JSON Format (Alternative)

```json
{
  "summary": "...",
  "confidence": 0.X,
  "estimated_sessions": 3,
  "phases": [
    {
      "name": "Phase 1",
      "session": 1,
      "tasks": [...],
      "checkpoint": true
    }
  ],
  "questions": [...],
  "risks": [...]
}
```
