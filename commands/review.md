---
name: review
description: Multi-model code review pipeline (Claude + Codex)
---

# /review

Run a multi-model code review pipeline with parallel reviewers (Claude + Codex), verifier agents, and a synthesized report from verified findings only.

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

## Pipeline Contract

1. Parse arguments and resolve scope.
2. Build `REVIEW_ID` + `brief.md` under `.claude/reviews/{REVIEW_ID}/`.
3. Spawn Claude reviewer and Codex reviewer in parallel.
4. Spawn two verifiers in parallel after both reviewers complete.
5. Synthesize report from verified outputs only (never raw review files).
6. Present categorized report and offer `/plan` generation.

## 1) Argument Parsing

Parse tokens from `$ARGUMENTS` with this behavior:

```bash
FOCUS="all"
MODE="all"          # all | staged | diff
DIFF_BASE=""
SCOPE_INPUTS=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --focus)
      [ -n "${2:-}" ] || { echo "ERROR: --focus requires a value"; exit 1; }
      FOCUS="$2"
      shift 2
      ;;
    --staged)
      MODE="staged"
      shift
      ;;
    --diff)
      [ -n "${2:-}" ] || { echo "ERROR: --diff requires a branch"; exit 1; }
      MODE="diff"
      DIFF_BASE="$2"
      shift 2
      ;;
    --*)
      echo "ERROR: Unknown flag $1"
      exit 1
      ;;
    *)
      SCOPE_INPUTS+=("$1")
      shift
      ;;
  esac
done
```

Scope resolution rules:

- If `MODE=staged`: `git diff --name-only --cached`
- If `MODE=diff`: `git diff --name-only "${DIFF_BASE}..HEAD"`
- Else with no positional scope: `git ls-files`
- Else positional scope values:
  - Directory: `git ls-files -- "<dir>"`
  - File: include file directly
  - Pathspec fallback: `git ls-files -- "<pattern>"`
- Deduplicate and keep only existing files.

If resulting scope has `>100` files:

- Warn user that scope is large.
- Continue only after explicitly noting recommendation to narrow scope.

## 2) Focus Presets

Map `--focus` to review emphasis:

- `refactor`: code smells, duplication, complex functions, naming, dead code, extraction opportunities
- `security`: OWASP top 10, injection, auth issues, secrets, input validation, error exposure
- `performance`: N+1 queries, unnecessary allocations, missing indexes, caching opportunities, hot paths
- `architecture`: coupling, cohesion, dependency direction, layer violations, abstraction levels
- `smells`: long methods, god classes, feature envy, shotgun surgery, primitive obsession
- default (`all`): balanced across all categories

Reject unknown focus values with a clear error message listing valid presets.

## 3) Generate `REVIEW_ID` and `brief.md`

Create incrementing review ID format: `review-YYYY-MM-DD-NNN`.

```bash
TODAY="$(date +%F)"
mkdir -p .claude/reviews
LAST_NUM="$(ls -1 .claude/reviews 2>/dev/null | grep -E "^review-${TODAY}-[0-9]{3}$" | sed -E 's/.*-([0-9]{3})$/\1/' | sort | tail -1)"
NEXT_NUM="$((10#${LAST_NUM:-000} + 1))"
REVIEW_ID="$(printf "review-%s-%03d" "$TODAY" "$NEXT_NUM")"
REVIEW_DIR=".claude/reviews/${REVIEW_ID}"
mkdir -p "${REVIEW_DIR}/claude" "${REVIEW_DIR}/codex" "${REVIEW_DIR}/verified"
```

Write `${REVIEW_DIR}/brief.md` with:

- Scope mode (`all`, `staged`, `diff`) and explicit scope inputs
- Focus area and emphasis description
- File listing with line counts (`wc -l`) for every file in scope
- Project context from `CLAUDE.md` (tech stack, standards, conventions)
- Git context:
  - branch: `git rev-parse --abbrev-ref HEAD`
  - recent commits: `git log --oneline -n 8`

## 4) Spawn Review Workers (Parallel)

Launch both workers concurrently.

### Worker A: Claude Reviewer (Task tool)

Use Task tool with:

- `subagent_type: "reviewer"`
- Prompt requirements:
  - Read `${REVIEW_DIR}/brief.md`
  - Read all scoped files
  - Analyze according to selected focus emphasis
  - Write `${REVIEW_DIR}/claude/review.md` with structured findings
  - Each finding must include:
    - severity (`critical` | `major` | `minor`)
    - `file:line`
    - description
    - suggested fix
  - Write `${REVIEW_DIR}/claude/status.json`:
    - `{"pass": true, "finding_count": N, "agent": "claude-reviewer"}`
  - Return one summary line with counts by severity

When this worker completes, emit:

- `<<<CLAUDE_REVIEW_DONE>>>`

If Claude reviewer fails:

- Retry exactly once.
- If retry fails, continue with Codex-only results and note degradation in final report.

### Worker B: Codex Reviewer (Bash tool)

Run:

```bash
bash scripts/review-codex.sh \
  "$PWD" \
  "${REVIEW_DIR}/codex" \
  "${REVIEW_DIR}/brief.md" \
  600
```

HMFIC reads only the wrapper DONE line:

- `DONE review=codex pass=<bool> findings=<N> artifacts=<path>/`

When Codex worker completes, emit:

- `<<<CODEX_REVIEW_DONE>>>`

Codex degradations:

- If Codex times out/fails, continue with Claude-only results and record warning.
- If Codex is not installed (`command -v codex` fails), skip Codex worker and continue with Claude-only results with warning.

## 5) Spawn Verifiers (Parallel, after both workers)

After worker phase is finished (including any fallback), launch verifiers via Task tool.

- If both Claude and Codex produced reviews, launch two verifiers in parallel.
- If Codex was unavailable, failed, or skipped, launch only Verifier 1 (Claude findings). Do NOT spawn Verifier 2.

Verifier settings for both:

- `subagent_type: "general-purpose"`
- `model: "sonnet"`
- Each verifier gets only one raw review file + code access; verifiers do not read the other model review.

### Verifier 1 (Claude findings)

Input: `${REVIEW_DIR}/claude/review.md`

Tasks:

1. For each finding, open referenced `file:line` and inspect ~20 lines of context.
2. Confirm finding is real (not hallucinated, not already fixed, file/line exists).
3. Confirm severity is appropriate.
4. Write only confirmed findings to `${REVIEW_DIR}/verified/claude.md`.
5. Return: `VERIFIED: X of Y findings confirmed (Z rejected as false positives)`

### Verifier 2 (Codex findings) — only if Codex review exists

Input: `${REVIEW_DIR}/codex/review.md`

Skip this verifier entirely if Codex was unavailable, failed, or produced no review file.

Tasks and return format are identical; output file:

- `${REVIEW_DIR}/verified/codex.md`

After all verifiers complete, emit:

- `<<<VERIFICATION_DONE>>>`

If a verifier rejects more than 80% of a model's findings, flag in the report: `High false positive rate`.

## 6) HMFIC Synthesis (Verified Inputs Only)

HMFIC must read only:

- `${REVIEW_DIR}/verified/claude.md`
- `${REVIEW_DIR}/verified/codex.md`

HMFIC must not read:

- `${REVIEW_DIR}/claude/review.md`
- `${REVIEW_DIR}/codex/review.md`

Synthesis rules:

1. Deduplicate issues by same root issue at same `file:line`.
2. Merge provenance: `found by: Claude`, `found by: Codex`, or `found by: Claude + Codex`.
3. Categorize by severity in order: `Critical` -> `Major` -> `Minor`.
4. Group findings by file within each severity.
5. Write `${REVIEW_DIR}/report.md`.

No-findings rule:

- If neither verifier has confirmed findings, write report with `No issues found` and keep severity sections empty.

## 7) Present Report

Display summary in this format:

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

If degraded mode occurred (Codex unavailable/failed or Claude failed twice), note it directly under the summary line.

## 8) Offer Fix Plan

After presenting the report, ask exactly:

```text
Want me to generate a /plan to fix these issues? (Critical + Major only)
```

## 9) Context Discipline Rules

- Workers receive `${REVIEW_DIR}/brief.md`, not full conversation context.
- Verifiers each receive exactly one review file + code access.
- HMFIC reads only verified outputs, never raw reviews.

## 10) Required Signals

Emit these markers at key stages:

- `<<<CLAUDE_REVIEW_DONE>>>` — Claude reviewer finished
- `<<<CODEX_REVIEW_DONE>>>` — Codex reviewer finished
- `<<<VERIFICATION_DONE>>>` — Both verifiers finished
- `<<<REVIEW_COMPLETE>>>` — Full pipeline done

Emit `<<<REVIEW_COMPLETE>>>` only after report is written and displayed.
