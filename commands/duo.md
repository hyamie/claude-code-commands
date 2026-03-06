---
name: duo
description: Dual-model workflow — Claude architects, Codex builds
argument-hint: "<requirements or path/to/plan.md>"
---

# /duo — Dual-Model Workflow

Claude Opus 4.6 architects and reviews. Codex CLI 5.4 builds.
Two plan files: `plan.md` (Claude) and `plan.codex.md` (Codex).

## Usage

```
/duo "add health check endpoint to the API"      # Requirements mode (V1)
/duo "refactor auth to use JWT tokens"            # Requirements mode (V1)
/duo .claude/plans/my-feature.md                  # Conversion mode (V2)
```

## Role Split

| Role | Model | Responsibilities |
|------|-------|------------------|
| Architect | Claude Opus 4.6 | Plan, review, deploy, MCP ops, decisions |
| Builder | Codex CLI 5.4 | Implement code, write tests, run verification |

**Claude does NOT:** Write implementation code (Codex does this)
**Codex does NOT:** Make architectural decisions, deploy, use MCPs (except GitHub)

## Process

### Step 1: Detect Mode

Check if `$ARGUMENTS` is an existing `.md` file path or free-text requirements:

```bash
# Mode detection
if [ -f "$ARGUMENTS" ] && [[ "$ARGUMENTS" == *.md ]]; then
  echo "CONVERSION MODE: Converting existing plan to duo format"
  # Go to Step 1b
else
  echo "REQUIREMENTS MODE: Generating new duo plans"
  # Continue to Step 2
fi
```

**Conversion mode** (`.md` file path): Go to Step 1b — convert existing plan to duo format.
**Requirements mode** (free text): Continue to Step 2 — standard V1 flow.

### Step 1a: Accept Requirements (Requirements Mode Only)

Read user requirements from `$ARGUMENTS`.

If requirements are vague, ask ONE round of clarifying questions, then proceed.

Continue to Step 2.

### Step 1b: Convert Existing Plan (Conversion Mode Only)

When `$ARGUMENTS` points to an existing `.md` plan file:

1. **Read the plan file** and parse its structure (phases, tasks, critical files)

2. **Scan tasks for owner labels** — look for `(Claude: ...)` or `(Codex: ...)` in each task line

3. **Auto-assign unlabeled tasks** using keyword heuristics:
   - **Claude** keywords: config, deploy, MCP, review, decision, architecture, credential, secret, env var, infrastructure
   - **Codex** keywords (default): implement, test, refactor, write, fix, add, create, update, build, migrate
   - If no keywords match, default to **Codex**
   - Explicit `(Claude: ...)` / `(Codex: ...)` labels always override heuristics

4. **Add duo metadata** to the plan if not present:
   ```markdown
   **Mode:** duo (Claude architects, Codex builds)
   ```
   Insert after the `**Summary:**` line. Save the updated plan file.

5. **Generate `plan.codex.md`** using the V1 Step 4 template below. Use the plan file's basename with `.codex.md` suffix in the same directory. Populate with:
   - Project context from `CLAUDE.md`
   - Architecture decisions from the plan
   - Only Codex-owned tasks for the current phase (first phase with `- [ ]` tasks)
   - Guardrails and verification commands

6. **Skip to Step 5** — present both plans to user.

### Step 2: Research Codebase

Before planning, understand the codebase:

1. Read `CLAUDE.md` for project conventions
2. Read `feature_list.json` for current state
3. Explore relevant source files (Glob/Grep/Read)
4. Identify patterns, dependencies, existing tests
5. Check git log for recent related work

### Step 3: Generate Claude Plan (`plan.md`)

Create the standard Claude plan in `.claude/plans/`:

```markdown
<!-- APPROVED: [timestamp] -->
<!-- EXECUTE WITH: /duo-exec .claude/plans/[name].md -->

## Plan: [Feature Name]

**Summary:** [What we're building]
**Confidence:** [0.0-1.0]
**Estimated Sessions:** [N]
**Mode:** duo (Claude architects, Codex builds)

---

### Phase N: [Name]

- [ ] Task 1 (Claude: [describe architect work])
- [ ] Task 2 (Codex: [describe implementation work])
- [ ] Task 3 (Codex: [describe implementation work])

📍 **SESSION CHECKPOINT** - Commit, sync plan.codex.md, restart

### Key Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| ... | ... | ... |

### Critical Files

| File | Action | Owner |
|------|--------|-------|
| ... | ... | Claude/Codex |

### Verification

**Per phase:** [verification commands]

### Risks

| Risk | Mitigation |
|------|------------|
| ... | ... |
```

**Rules:**
- Max 3 tasks per phase
- Mark each task with owner: `(Claude: ...)` or `(Codex: ...)`
- Claude tasks: planning, config, deploy, MCP operations, reviews
- Codex tasks: code implementation, tests, refactoring

### Step 4: Generate Codex Plan (`plan.codex.md`)

Create the Codex-focused plan in the SAME `.claude/plans/` directory with `.codex` suffix.

This is the file Codex reads. It must be self-contained — Codex has NO access to Claude's context.

**Use the template at `.claude/templates/codex-plan.md`** — read it, substitute the `{{placeholders}}` with actual values from the codebase and plan, and write the result to `.claude/plans/[name].codex.md`.

Populate with:
- Project context from `CLAUDE.md`
- Architecture decisions from the plan (marked as final)
- Only Codex-owned tasks for the current phase
- Verification commands per task
- Guardrails and completion report template

### Step 5: Present Plans to User

Show both plans and ask for approval. Adapt the header based on mode:

**If conversion mode:**

```markdown
## /duo Plans Converted

Converted existing plan to duo format with Claude/Codex task assignments.

### Source Plan: `[original plan path]`
[summary — phases, total tasks, Claude vs Codex task counts]

### Generated Codex Plan: `.claude/plans/[name].codex.md`
[summary — current phase Codex tasks, guardrails]

### Task Assignment Summary

| Phase | Claude Tasks | Codex Tasks |
|-------|-------------|-------------|
| Phase 1 | N | N |
| Phase 2 | N | N |
| ... | ... | ... |

### Execution
Use `/duo-next` after each Codex phase to review, commit, and advance.
```

**If requirements mode:**

```markdown
## /duo Plans Generated

### Claude Plan: `.claude/plans/[name].md`
[summary — phases, task count, estimated sessions]

### Codex Plan: `.claude/plans/[name].codex.md`
[summary — current phase tasks, guardrails]
```

**Both modes show execution options:**

```markdown
### Execution Modes

**Interactive (recommended for first time):**
1. Press `Ctrl+Shift+D` in Wezterm to open duo split
2. In right pane (Codex): `codex` then paste the phase tasks
3. In left pane (Claude): Review Codex output, or run `/duo-next` to auto-advance

**Manual:**
1. Claude: Execute Claude-owned tasks from plan.md
2. Copy Codex tasks to Codex CLI (separate terminal)
3. Run `/duo-next` to review, commit, and advance to next phase

### Ready?
Approve to start execution, or request changes.
```

### Step 6: Execute (After Approval)

**CRITICAL RULE: Claude NEVER implements Codex-owned tasks.**
If a task is marked `(Codex: ...)`, Claude does NOT write that code. Period.
Claude's job is to hand off, wait, and review — not implement.

**Claude's execution loop per phase:**

1. Execute any Claude-owned tasks ONLY (config, MCP ops, deploy, etc.)
2. Check if there are Codex-owned tasks in this phase
3. **If Codex tasks exist — STOP and hand off:**
   - Confirm `plan.codex.md` is up to date with current phase details
   - Display this message to the user:

   ```
   ## Phase N — Ready for Codex

   Codex tasks for this phase:
   - [list Codex tasks]

   **Next steps:**
   1. Open Codex split: `Ctrl+Shift+D` (if not already open)
   2. In Codex pane, run: `cod` (alias for codex with auto-approve)
   3. Give Codex: `.claude/plans/[name].codex.md`
   4. When Codex finishes, come back here and run `/duo-next`

   Waiting for Codex to complete...
   ```

   - **DO NOT proceed. DO NOT implement Codex tasks. WAIT for the user to run `/duo-next`.**

4. If NO Codex tasks in this phase (Claude-only phase):
   - Execute all Claude tasks
   - Commit with conventional commit format
   - Mark tasks `[x]` in plan.md
   - Auto-advance to next phase (repeat from step 1)

**Between phases (handled by `/duo-next`):**
- Claude reviews Codex's changes
- Claude fixes minor issues, sends major issues back to Codex
- Claude commits with dual co-author
- Claude updates plan.codex.md with next phase tasks
- Claude reviews architecture decisions — any adjustments needed?

## When to Use /duo vs Other Commands

| Situation | Use |
|-----------|-----|
| New feature, want dual-model quality | `/duo "requirements"` |
| Convert existing plan to duo format | `/duo .claude/plans/plan.md` |
| Advance to next phase after Codex | `/duo-next` |
| Learning a codebase with Codex | `/duo` (interactive mode) |
| Quick fix, trust one model | `/cook` or `/smoke` |
| Maximum rigor | `/turbo` |

## Requirements

- Codex CLI installed (`codex` command available)
- Wezterm with duo keybind (`Ctrl+Shift+D`) for interactive mode
- Project trusted in `~/.codex/config.toml`
