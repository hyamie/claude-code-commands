---
name: prd
description: Generate a Product Requirements Document before planning
argument-hint: "<feature description>"
---

# /prd — Generate Product Requirements Document

Creates a structured PRD at `.claude/plans/prd-{name}.md` that anchors the entire pipeline. The PRD captures **what** and **why** — the plan captures **how**.

## Usage

```
/prd "user authentication for the API"
/prd "dashboard real-time notifications"
```

## Input

$ARGUMENTS - Feature description (required)

## Process

### Step 1: Read Project Context

Read the project's CLAUDE.md and any existing PRDs to understand the current state:

```bash
cat CLAUDE.md 2>/dev/null | head -100
ls .claude/plans/prd-*.md 2>/dev/null
```

Also check for a project spec:
```bash
cat .claude/project-spec.json 2>/dev/null
```

### Step 2: Explore Relevant Codebase

Based on the feature description, do a quick targeted search of the codebase to understand:
- What already exists that's related
- What patterns/conventions the project uses
- What dependencies or integrations are relevant

Use Glob and Grep — keep it focused, max 3-5 searches. This is reconnaissance, not deep research.

### Step 3: Ask Clarifying Questions

Use AskUserQuestion to ask **3-5 targeted questions** about the feature. Ask them in sequence (one at a time) to keep answers focused.

**Required questions (adapt phrasing to context):**

1. **Core flow:** "What's the primary user flow for this feature?" (open-ended or with options if obvious patterns exist)
2. **Scope boundaries:** "What should this feature explicitly NOT do?" (open-ended — this catches non-goals)
3. **Success criteria:** "How will you know this works? What's the smoke test?" (open-ended)

**Conditional questions (ask if relevant):**

4. **Users/roles:** "Who uses this? Any role-based differences?" (skip for infra/tooling work)
5. **Technical constraints:** "Any specific tech requirements, integrations, or limitations?" (skip if obvious from codebase)

**DO NOT ask more than 5 questions.** If you need more context, make reasonable assumptions and list them in the PRD's Open Questions section.

### Step 4: Generate PRD

Read the template:
```bash
cat ~/claude-env/templates/prd-template.md
```

Generate the PRD by filling in the template with:
- Feature description from $ARGUMENTS
- Answers from clarifying questions
- Codebase context from Step 2
- Reasonable assumptions (clearly marked)

**Naming convention:** `prd-{kebab-case-name}.md`
- Derive the name from the feature description
- Examples: `prd-user-auth.md`, `prd-dashboard-notifications.md`, `prd-forge-pipeline-prd.md`

**Key rules for generation:**
- Acceptance criteria must be **concrete and testable** — no vague "should work well"
- Non-goals must be **explicit** — things someone might reasonably assume are in scope but aren't
- Smoke test must be a **specific command or action** — `curl`, click path, CLI command
- Keep it concise — a PRD should be 1-2 pages, not a novel

### Step 5: Write PRD File

Write to `.claude/plans/prd-{name}.md` in the current project directory.

```bash
# Ensure directory exists
mkdir -p .claude/plans
```

### Step 6: Present Summary

After writing the PRD, display:

```markdown
## PRD Created

**File:** .claude/plans/prd-{name}.md
**Feature:** {feature name}

### Goals
{numbered list}

### Acceptance Criteria
- Must Pass: {count} criteria
- Should Pass: {count} criteria
- Smoke Test: {description}

### Non-Goals
{bullet list}

### Next Steps
- Review and edit the PRD if needed
- Run `/plan "feature"` to create an implementation plan (will auto-detect this PRD)
- Or run `/plan-review` after `/plan` for a second opinion
```

## PRD Quality Checklist

Before writing the file, verify:
- [ ] Problem statement is one clear sentence
- [ ] Goals are measurable (not vague)
- [ ] Non-goals exist and are meaningful
- [ ] Acceptance criteria are testable with specific commands/checks
- [ ] Smoke test is a concrete action, not a description
- [ ] No implementation details leaked into requirements (that's the plan's job)
- [ ] Open questions are listed if any assumptions were made

## Integration Points

This PRD is consumed by:
- **`/plan`** — Reads PRD to derive phases and tasks
- **`/forge-prep`** — Pulls acceptance criteria from PRD instead of inventing them
- **`/forge` task.md** — References PRD in Context section for Codex workers
- **`/plan-review`** — Gemini evaluates plan against PRD requirements

The PRD is **optional** — the pipeline still works without one. But when present, it becomes the source of truth for requirements.
