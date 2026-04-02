---
name: review
description: Multi-model code review pipeline (Claude + Codex)
---

# /review

Run a multi-model code review pipeline: Claude reviewer agent + Codex CLI in parallel, verified findings, synthesized report.

## Usage

```bash
/review                          # All files in project (git ls-files)
/review src/api/                 # Scope to directory
/review src/api/users.ts         # Scope to file
/review --focus refactor         # Focus area
/review --focus security         # Focus area
/review --staged                 # Staged changes only
/review --diff main              # Changes vs branch
/review src/ --focus security    # Combined arguments
```

## Pipeline

```
Parse args → Create review dir + brief → Launch Claude + Codex in parallel → Verify findings → Synthesize report
```

## Step 1: Parse Arguments

Parse `$ARGUMENTS`:

- `--focus <area>`: refactor, security, performance, architecture, smells, or all (default: all)
- `--staged`: Review staged changes only
- `--diff <branch>`: Review changes vs branch
- Positional args: files/directories to scope

Resolve scope:
- `--staged` → `git diff --name-only --cached`
- `--diff <branch>` → `git diff --name-only "<branch>..HEAD"`
- Directory arg → `git ls-files -- "<dir>"`
- File arg → include directly
- No args → `git ls-files`

Warn if >100 files but continue.

## Step 2: Create Review Directory and Brief

```bash
TODAY="$(date +%F)"
mkdir -p .claude/reviews
LAST_NUM="$(ls -1 .claude/reviews 2>/dev/null | grep -E "^review-${TODAY}-[0-9]{3}$" | sed -E 's/.*-([0-9]{3})$/\1/' | sort | tail -1)"
NEXT_NUM="$((10#${LAST_NUM:-000} + 1))"
REVIEW_ID="$(printf "review-%s-%03d" "$TODAY" "$NEXT_NUM")"
REVIEW_DIR=".claude/reviews/${REVIEW_ID}"
mkdir -p "${REVIEW_DIR}/claude" "${REVIEW_DIR}/codex" "${REVIEW_DIR}/verified"
```

Write `${REVIEW_DIR}/brief.md` containing:
- Scope mode and inputs
- Focus area description
- File listing with line counts
- Project context from CLAUDE.md
- Branch name and recent commits (8)

## Step 3: Launch Reviewers in Parallel

Check if Codex is available: `command -v codex`. If not, skip Codex and note degradation.

Launch BOTH in parallel (same message, two tool calls):

### Worker A: Claude Reviewer (Agent tool)

```
subagent_type: "reviewer"
run_in_background: true
```

Prompt the reviewer agent to:
1. Read `${REVIEW_DIR}/brief.md`
2. Read all scoped files
3. Analyze according to focus emphasis
4. Write `${REVIEW_DIR}/claude/review.md` with structured findings:
   - Each finding: severity (critical|major|minor), file:line, description, suggested fix
5. Write `${REVIEW_DIR}/claude/status.json`: `{"pass": true/false, "finding_count": N, "agent": "claude-reviewer"}`
6. Return summary line with counts by severity

### Worker B: Codex Reviewer (Bash tool)

```
run_in_background: true
```

Run:
```bash
bash scripts/review-codex.sh "$PWD" "${REVIEW_DIR}/codex" "${REVIEW_DIR}/brief.md" 600
```

Wait for both to complete. If Codex fails/times out, continue Claude-only with degradation note.

## Step 4: Verify Findings

After BOTH workers complete, launch verifier agent(s) via Agent tool.

Only launch verifiers for models that produced review files:
- If Claude review exists → launch Verifier A
- If Codex review exists → launch Verifier B
- Launch available verifiers in parallel

Each verifier (subagent_type: "general-purpose"):
1. Read the single review file assigned to it
2. For each finding, open referenced file:line and check ~20 lines of context
3. Confirm finding is real (not hallucinated, file/line exists, issue present)
4. Write confirmed findings to `${REVIEW_DIR}/verified/claude.md` or `${REVIEW_DIR}/verified/codex.md`
5. Return: `VERIFIED: X of Y findings confirmed (Z rejected as false positives)`

If a verifier rejects >80% of findings, flag as "High false positive rate".

## Step 5: Synthesize Report

Read ONLY verified files (`${REVIEW_DIR}/verified/*.md`), NEVER raw review files.

Synthesis rules:
1. Deduplicate by same root issue at same file:line
2. Tag provenance: `found by: Claude`, `found by: Codex`, or `found by: Claude + Codex`
3. Order: Critical → Major → Minor
4. Group by file within each severity

Write `${REVIEW_DIR}/report.md`.

## Step 6: Present Report

Display:

```markdown
## Code Review Report — {scope} [{focus}]
Review ID: {REVIEW_ID} | Claude: X findings | Codex: Y findings | Verified: Z total

### Critical (must fix)
**src/api/users.ts**
- [C1] :47 — SQL injection in user query interpolation (Claude+Codex)
  Fix: Use parameterized query with $1 placeholder

### Major (should fix)
...

### Minor (nice to have)
...

---
Full report: .claude/reviews/{REVIEW_ID}/report.md
```

If degraded (Codex unavailable/failed), note it under the summary line.

Then ask: `Want me to generate a /plan to fix these issues? (Critical + Major only)`

## Context Rules

- Workers get `brief.md`, not conversation context
- Verifiers get exactly one review file + code access each
- Synthesis reads only verified outputs, never raw reviews
