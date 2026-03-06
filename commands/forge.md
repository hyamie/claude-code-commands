---
name: forge
description: Multi-model artifact-based execution pipeline — Codex builds, Claude reviews, artifacts keep context lean
argument-hint: "[--attended] [.claude/plans/plan.md]"
---

# /forge — Multi-Model Artifact-Based Execution

HMFIC orchestrates. Workers (Codex + Builder) implement via frozen task.md files. Reviewers verify per-step. Artifacts on disk keep main context lean.

**Key differences from /smoke and /turbo:**
- Per-step task.md → worker → verify loop (not phase-level)
- Codex for code implementation, Builder for config/MCP tasks
- Artifact-based contract (status.json, summary.md, raw.log)
- 2-3 end-of-run reviewers (Claude correctness + Codex implementation + conditional final)
- Objective gates (bash) before AI review

## Usage

```
/forge                              # Walk-away mode (auto-fallback to Builder on Codex failure)
/forge --attended                   # Attended mode (asks you on Codex failure — use when watching)
/forge .claude/plans/my-feature.md  # Specific plan (must be prepped with /forge-prep)
```

**Modes:**
- **Default (walk-away):** On Codex failure, auto-fallback to Builder agent. Logs the fallback in forge-status.json. Work never stops.
- **`--attended`:** On Codex failure, uses AskUserQuestion so you can pick Manual Codex split-pane, Builder, Skip, or Halt. Use when actively watching.

## Prerequisites

- Run `/forge-prep` first to create ACCEPTANCE.md, DECISIONS.md, forge-status.json
- Plan file exists with phases and `- [ ]` tasks

---

## Process

### Step 0: Check for Active Run

**FIRST ACTION — check for an active forge run:**

```bash
if [ -f forge-status.json ]; then
  ROOT_STATUS=$(cat forge-status.json)
  RUN_DIR_FIELD=$(jq -r '.run_dir // empty' <<< "$ROOT_STATUS")
  FULL_STATUS=""

  if [ -n "$RUN_DIR_FIELD" ]; then
    RUN_DIR="$RUN_DIR_FIELD"
    FULL_STATUS=$(cat "${RUN_DIR}/forge-status.json")
  else
    echo "ERROR: forge-status.json has no run_dir field. Run /forge-prep first."
    exit 1
  fi

  COMPLETED=$(jq -r '.completed // false' <<< "$FULL_STATUS")
  MODE=$(jq -r '.mode // empty' <<< "$FULL_STATUS")

  if [ "$MODE" = "forge" ] && [ "$COMPLETED" != "true" ]; then
    echo "=== RESUMING FORGE RUN ==="
    PLAN_FILE=$(jq -r '.plan_file' <<< "$FULL_STATUS")
    RUN_ID=$(jq -r '.run_id' <<< "$FULL_STATUS")
    CURRENT_PHASE=$(jq -r '.current_phase // 1' <<< "$FULL_STATUS")
    CURRENT_STEP=$(jq -r '.current_step // 1' <<< "$FULL_STATUS")
    ACCEPTANCE_FILE="${RUN_DIR}/ACCEPTANCE.md"
    DECISIONS_FILE="${RUN_DIR}/DECISIONS.md"
    echo "Plan: $PLAN_FILE | Run: $RUN_ID | Phase: $CURRENT_PHASE | Step: $CURRENT_STEP"
  elif [ "$COMPLETED" = "true" ]; then
    echo "Previous forge run completed. Run /forge-prep on a new plan to start fresh."
    exit 0
  fi
fi
```

**State machine:** `ready=true` means prepped. `completed=false` (or absent) means in-progress. `completed=true` means done. Resume fires when mode=forge and not completed.

**Pointer format:** Root `forge-status.json` has `active_run` and `run_dir` fields. Full state lives at `${RUN_DIR}/forge-status.json`. ACCEPTANCE.md and DECISIONS.md also live in `${RUN_DIR}/`.

**If resuming:** Skip to Phase 1 Step Execution with values from `${RUN_DIR}/forge-status.json`.

**If fresh start with plan argument:**

1. Check for forge-status.json — if missing, error: `Run /forge-prep first`
2. Resolve pointer: read `run_dir` from root forge-status.json, set `RUN_DIR`
3. Set `ACCEPTANCE_FILE="${RUN_DIR}/ACCEPTANCE.md"` and `DECISIONS_FILE="${RUN_DIR}/DECISIONS.md"`
4. Validate files exist: `$ACCEPTANCE_FILE`, `$DECISIONS_FILE`, `${RUN_DIR}/forge-status.json`
5. Read `${RUN_DIR}/forge-status.json` for run_id, worker_assignments, gates
6. If `--attended` was passed, set `"attended": true` in `${RUN_DIR}/forge-status.json` (persists across resume/clear)

### Step 1: Phase 0 — Prerequisites

Verify all required files exist:

```bash
REPO_PATH=$(pwd)
PLAN_FILE=$(jq -r '.plan_file' "${RUN_DIR}/forge-status.json")
RUN_ID=$(jq -r '.run_id' "${RUN_DIR}/forge-status.json")
BASE_BRANCH=$(jq -r '.base_branch' "${RUN_DIR}/forge-status.json")
ACCEPTANCE_FILE="${RUN_DIR}/ACCEPTANCE.md"
DECISIONS_FILE="${RUN_DIR}/DECISIONS.md"

for f in "$PLAN_FILE" "$ACCEPTANCE_FILE" "$DECISIONS_FILE" "${RUN_DIR}/forge-status.json"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: Missing $f — run /forge-prep first"
    exit 1
  fi
done

# Enforce clean working tree — uncommitted changes cause unreliable diffs
if [ -n "$(git status --porcelain)" ]; then
  echo "ERROR: Working tree is dirty. Commit or stash changes before running /forge."
  git status --short
  exit 1
fi

# Create artifact directory
mkdir -p "artifacts/${RUN_ID}"
echo "Forge run ${RUN_ID} initialized"

# Set started_at on first run (null means not yet started)
STARTED_AT=$(jq -r '.started_at // empty' "${RUN_DIR}/forge-status.json")
if [ -z "$STARTED_AT" ]; then
  FS_TMP=$(mktemp) && jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.started_at = $ts' "${RUN_DIR}/forge-status.json" > "$FS_TMP" && mv "$FS_TMP" "${RUN_DIR}/forge-status.json"
fi
```

Read the plan file. Parse phases and tasks:

**Phase boundary detection:**
1. Scan for `## Phase N` or `### Phase N` headers in the plan
2. Build a phase map: `{phase_num: {title, first_task, last_task}}`
3. If no phase headers found, treat all tasks as a single phase (backward compatible)
4. Track phase transitions during execution — when moving from one phase's tasks to the next, log:
   ```
   === Phase N Complete ===
   Moving to Phase N+1: {title}
   ```
5. Store `current_phase` in `${RUN_DIR}/forge-status.json` so resume starts in the right phase

Find the first phase with unchecked `- [ ]` tasks.

### Step 2: Phase 1 — Step Execution Loop

For each unchecked task in the current phase, execute this loop:

#### 2a. Generate task.md

Determine the step ID: `step-01`, `step-02`, etc. (zero-padded).

Create the artifact directory:
```bash
STEP_ID=$(printf "step-%02d" $STEP_NUM)
ARTIFACT_PATH="${REPO_PATH}/artifacts/${RUN_ID}/${STEP_ID}"
mkdir -p "$ARTIFACT_PATH"
```

Write `task.md` to the artifact path. Use this template — fill in from the plan task:

```markdown
# Step XX — <short title from plan task>

## Context
- Working directory: <REPO_PATH absolute, e.g. /home/user/projects/active/my-project>
- Plan file: <REPO_PATH>/<PLAN_FILE>
- PRD: <REPO_PATH>/<PRD_FILE or "None">
- Acceptance: <REPO_PATH>/${RUN_DIR}/ACCEPTANCE.md
- Decisions: <REPO_PATH>/${RUN_DIR}/DECISIONS.md
- Run: <RUN_ID>
- Step: <STEP_ID>

IMPORTANT: cd to <REPO_PATH> before any file operations.
NOTE: Do NOT read files from ~/.agents/skills/ or ~/.claude/skills/

## Objective
<one sentence derived from the plan task>

## Scope
IN SCOPE:
- <what this step should change>

OUT OF SCOPE:
- Everything else in the plan
- Architecture decisions (those are in DECISIONS.md)

## Required changes
- [ ] <broken down from plan task>

## Progress
- [ ] <each required change as a checkbox — Codex checks these off as it works>

## Decision Log
Reference: <REPO_PATH>/${RUN_DIR}/DECISIONS.md
If you make a non-obvious choice, append to DECISIONS.md.

## Surprises & Discoveries
<empty — Codex fills this in if anything unexpected is found>

## Note
The wrapper (forge-codex.sh) generates all artifacts (status.json, summary.md) automatically.
Codex does NOT write artifacts — it only implements code and runs verification.

## Validation
- [ ] Run: <verification commands from forge-status.json gates, if applicable>
- [ ] All required changes checked off above
```

**CRITICAL:** All paths in task.md MUST be absolute (Codex runs in a different directory). Use `${REPO_PATH}` prefix for every file reference.

#### 2b. Determine Worker

Read worker assignment from `${RUN_DIR}/forge-status.json`:
```bash
WORKER=$(jq -r ".worker_assignments.\"${STEP_ID}\"" "${RUN_DIR}/forge-status.json")
```

If not assigned, use keyword heuristics:
- Code keywords (create, implement, write, build, add, refactor, fix, test, function, class, module, endpoint, API, migration, schema) → `codex`
- Config keywords (configure, setup, config, MCP, deploy, environment, secret, credential, hook, skill, command, documentation) → `builder`
- Default → `codex`

#### 2c. Capture Base SHA and Spawn Worker

Capture the current HEAD before the worker runs — used for accurate diffs in review:
```bash
STEP_BASE_SHA=$(git rev-parse HEAD)
```

> **ATTENDED MODE CHECK**
>
> Before spawning any worker, check the `attended` field in `${RUN_DIR}/forge-status.json`:
> ```bash
> ATTENDED=$(jq -r '.attended // false' "${RUN_DIR}/forge-status.json")
> ```
> This controls failure handling for the entire step below. Walk-away mode is the default. Attended mode was set at run start if `--attended` was passed.

**If worker = codex:**

Run forge-codex.sh via Bash tool (background):

```bash
bash ~/claude-env/scripts/forge-codex.sh \
  "${REPO_PATH}" \
  "${ARTIFACT_PATH}" \
  "${ARTIFACT_PATH}/task.md" \
  900
```

**CONTEXT DISCIPLINE:** Ignore all stdout except the final `DONE step=... pass=...` line. Do NOT read raw.log, codex-output.md, or summary.md. The worker wrote everything to disk — you already know the path.

**ON CODEX FAILURE** (non-zero exit, timeout, missing DONE line):

Check `ATTENDED` (read above) FIRST — this is the branching condition:

**Walk-away mode (`ATTENDED=false`, default):**
1. Log the failure: add entry to `${RUN_DIR}/forge-status.json` under `codex_fallbacks` array: `{"step": "{STEP_ID}", "reason": "<exit code or timeout>", "fallback": "builder"}`
2. Print: `⚠️ Codex failed on {STEP_ID} — auto-falling back to Builder agent`
3. Re-run step 2c with worker=builder immediately. No blocking. No questions.
4. Continue the forge loop.

**Attended mode (`ATTENDED=true`):**
Use AskUserQuestion with:
- question: "Codex failed on {STEP_ID}. How do you want to proceed?"
- options:
  1. "Manual Codex (Ctrl+Shift+D)" — "Open Codex in split pane, paste task from {ARTIFACT_PATH}/task.md, then run /forge-continue when done"
  2. "Builder agent" — "Claude Builder implements this step instead of Codex"
  3. "Skip this step" — "Mark step as skipped and continue to next step"
  4. "Halt" — "Stop forge entirely, fix manually"

After user picks:
- **Manual Codex:** Update `${RUN_DIR}/forge-status.json` with current_step and STOP execution. User will run /forge-continue.
- **Builder agent:** Log to `codex_fallbacks` in `${RUN_DIR}/forge-status.json`, re-run step 2c with worker=builder, continue the forge loop.
- **Skip:** Mark step as skipped in `${RUN_DIR}/forge-status.json`, advance to next step, continue the forge loop.
- **Halt:** Update `${RUN_DIR}/forge-status.json` with current_step and STOP execution.

**If worker = builder:**

Spawn a Builder agent via Task tool:

```
subagent_type: "builder"
prompt: |
  You are implementing ONE step of a /forge run. Scope is ONLY what task.md describes.

  WORKING DIRECTORY: {REPO_PATH}
  RUN: {RUN_ID}, STEP: {STEP_ID}

  Read these files first:
  - {ARTIFACT_PATH}/task.md
  - {REPO_PATH}/${RUN_DIR}/ACCEPTANCE.md
  - {REPO_PATH}/${RUN_DIR}/DECISIONS.md

  STOP — do NOT read any file not listed above. If task.md is unclear, set pass=false
  with blocking_issues: ["task.md unclear — needs more context"] in status.json and return DONE.

  RULES:
  - Implement ONLY what task.md requires. Do not expand scope.
  - If you make a non-obvious choice, append to DECISIONS.md:
    ### {STEP_ID} (builder)
    - DECIDED: <what> (<why>)
  - Run all verification commands in task.md.
  - BUDGET: Complete within 25 tool calls. If you can't finish, write what you have,
    set pass=false in status.json with blocking_issues: ["exceeded tool call budget"],
    and return DONE.

  WRITE to {ARTIFACT_PATH}/:
  - status.json (schema: run_id, step, agent:"builder", task_type:"implement", pass, blocking_issues, warnings, metrics)
  - summary.md (changes, files touched, decisions, verification results)
  - raw.log (full stdout/stderr from verification)

  If verification fails: pass=false, list failing command in blocking_issues.

  YOUR FINAL MESSAGE must be ONLY this line, nothing else:
  DONE step={STEP_ID} pass=<true|false>
```

**CONTEXT DISCIPLINE:** The Builder agent's return message will be one line. Do NOT read raw.log or summary.md. Proceed to step 2d using only `{ARTIFACT_PATH}/status.json`.

#### 2d. Parse Worker Result

**Read ONLY `{ARTIFACT_PATH}/status.json` — nothing else.** Do NOT read summary.md, raw.log, or codex-output.md. Those are for the final Ship phase.

**Validate schema first:**
```bash
if ! jq -e '.pass != null and (.blocking_issues | type) == "array" and .agent != null' "${ARTIFACT_PATH}/status.json" >/dev/null 2>&1; then
  echo "WARNING: status.json missing required fields — treating as fail"
  # Missing schema fields = treat as pass=false
fi
```

If validation fails, treat as **pass=false** and create a fix step with `blocking_issues: ["status.json missing required fields (pass, blocking_issues, agent)"]`.

- **pass=true** → proceed to verification (Step 2e)
- **pass=false** → create fix step

**Creating a fix step:**
```
FIX_NUM increments (step-01-fix-01, step-01-fix-02, etc.)
Create new task.md with:
- Original task context
- Blocking issues from status.json
- "Fix the following issues: [list]"
Spawn worker again with fix task.md
```

**Circuit breaker:** After 3 fix attempts for the same step, HALT:
```
🛑 Circuit Breaker: Step {STEP_ID} failed 3 times.
Last error: [blocking_issues]

Options:
- Fix manually, then /forge-continue
- /forge-continue --claude (try Builder instead)
- Modify the plan and re-run /forge-prep
```

#### 2e. Spawn Per-Step Verifier

**MANDATORY — DO NOT SKIP. Every step MUST be verified before committing.**

After worker passes, spawn a Reviewer agent:

```
subagent_type: "reviewer"
model: "sonnet"
prompt: |
  You are verifying ONE step of a /forge run. Do NOT implement anything.

  Read these files (task-scoped — do NOT read the full plan file):
  - {ARTIFACT_PATH}/task.md
  - {ARTIFACT_PATH}/summary.md
  - {ARTIFACT_PATH}/status.json
  - {REPO_PATH}/${RUN_DIR}/ACCEPTANCE.md (first 80 lines)
  - {REPO_PATH}/${RUN_DIR}/DECISIONS.md

  Then run: git diff {STEP_BASE_SHA} --stat
  Read the changed files.

  BUDGET: Complete within 15 tool calls. Focus on the checklist, write findings, return.

  CHECKLIST:
  1. TASK COMPLIANCE: Does the change implement task.md and nothing extra?
  2. SCOPE DRIFT: Were files touched outside the listed scope?
  3. DECISIONS: Are entries in DECISIONS.md reasonable?
  4. VERIFICATION: Did verification commands run and pass?
  5. OBVIOUS RISKS: Edge cases, missing error handling, security issues?

  Write to {ARTIFACT_PATH}/review/:
  - status.json — MUST use this EXACT schema:
    {"agent":"reviewer", "task_type":"review", "pass": true, "blocking_issues": [], "warnings": []}
    The key MUST be "pass" (boolean). NOT "approved", NOT "reviewed", NOT "success". Just "pass".
  - review.md (Gate: PASS/FAIL, findings, scope drift check)

  YOUR FINAL MESSAGE must be ONLY this line, nothing else:
  DONE step={STEP_ID} pass=<true|false>
```

**CONTEXT DISCIPLINE:** The Reviewer's return message will be one line. Read ONLY `{ARTIFACT_PATH}/review/status.json` for pass/fail. Do NOT read review.md here — it's for the final Ship phase.

**DO NOT BATCH OR SKIP:** Each step gets its own reviewer invocation. Never combine multiple steps into one review. Never skip review because "it looks fine." The pre-commit guard in step 2f will block the commit if review artifacts are missing.

- **pass=true** → commit step, mark task `[x]` in plan, advance to next step
- **pass=false** → create fix step from review findings, re-execute (same circuit breaker)

#### 2e-simplify. Code Simplification Pass (Optional)

**Check if simplification is enabled:**

```bash
SIMPLIFY=$(jq -r '.simplify // true' "${RUN_DIR}/forge-status.json")
SIMPLIFY_FAILURES=$(jq -r '.simplify_failures // 0' "${RUN_DIR}/forge-status.json")
SIMPLIFY_CB=$(jq -r '.simplify_circuit_breaker // 2' "${RUN_DIR}/forge-status.json")

if [ "$SIMPLIFY" != "true" ] || [ "$SIMPLIFY_FAILURES" -ge "$SIMPLIFY_CB" ]; then
  echo "Simplification disabled (simplify=${SIMPLIFY}, failures=${SIMPLIFY_FAILURES}/${SIMPLIFY_CB}) — skipping to commit"
  # Skip to step 2f
fi
```

**Determine files to simplify:**

```bash
CHANGED_FILES=$(git diff --name-only ${STEP_BASE_SHA} -- . ':!artifacts/' | grep -E '\.(ts|tsx|js|jsx|py|go|rs|java|rb|sh|css|scss)$' || true)
if [ -z "$CHANGED_FILES" ]; then
  echo "No code files changed in ${STEP_ID} — skipping simplification"
  # Skip to step 2f
fi
```

If code files exist, create artifact directory and spawn the code-simplifier agent:

```bash
mkdir -p "${ARTIFACT_PATH}/simplify"
```

```
subagent_type: "pr-review-toolkit:code-simplifier"
model: "opus"
prompt: |
  You are simplifying code from ONE step of a /forge run.

  WORKING DIRECTORY: {REPO_PATH}
  RUN: {RUN_ID}, STEP: {STEP_ID}

  SCOPE — ONLY these files (changed in this step):
  {CHANGED_FILES — one per line}

  BUDGET: Complete within 15 tool calls. Read files, simplify, return.

  Read each file. Apply simplification:
  - Reduce unnecessary complexity and nesting
  - Eliminate redundant abstractions
  - Improve naming for clarity
  - Consolidate related logic
  - Remove comments that describe obvious code
  - Avoid nested ternaries — prefer switch/if-else
  - Choose clarity over brevity

  RULES:
  - PRESERVE ALL FUNCTIONALITY. Do not change behavior.
  - Do NOT add features or expand scope.
  - Do NOT touch files outside the list above.
  - Do NOT modify files in artifacts/.
  - If a file is already clean, leave it alone.

  After changes, run: git diff --stat

  Write to {ARTIFACT_PATH}/simplify/:
  - status.json: {"agent":"code-simplifier", "task_type":"simplify", "pass": true, "files_modified": [], "files_skipped": [], "changes_summary": ""}
  - summary.md: Changes per file, or "No changes needed"

  YOUR FINAL MESSAGE must be ONLY this line:
  DONE step={STEP_ID}-simplify pass=<true|false>
```

**CONTEXT DISCIPLINE:** Read ONLY `{ARTIFACT_PATH}/simplify/status.json`. Do NOT read summary.md here.

**On simplifier failure** (non-zero exit, missing DONE line, pass=false):
1. Revert any uncommitted changes: `git checkout -- . ':!artifacts/'`
2. Log warning: `"⚠️ Simplifier failed on {STEP_ID} — continuing with original code"`
3. Increment `simplify_failures` in `${RUN_DIR}/forge-status.json`:
   ```bash
   FS_TMP=$(mktemp) && jq '.simplify_failures = ((.simplify_failures // 0) + 1)' "${RUN_DIR}/forge-status.json" > "$FS_TMP" && mv "$FS_TMP" "${RUN_DIR}/forge-status.json"
   ```
4. Skip to step 2f (commit original code)

**On simplifier pass=true:**

Check if files actually changed:
```bash
SIMPLIFY_DIFF=$(git diff --name-only -- . ':!artifacts/')
if [ -z "$SIMPLIFY_DIFF" ]; then
  echo "Simplifier made no changes — proceeding to commit"
  # Skip re-verification, proceed to step 2f
fi
```

**If simplifier made changes — run objective gates only (no AI review):**

```bash
echo "=== Re-verifying after simplification ==="
GATE_PASS=true

for GATE_NAME in lint typecheck test build; do
  GATE_CMD=$(jq -r ".gates.${GATE_NAME} // empty" "${RUN_DIR}/forge-status.json")
  if [ -n "$GATE_CMD" ]; then
    echo "Running gate: ${GATE_NAME}"
    if ! eval "$GATE_CMD" > "${ARTIFACT_PATH}/simplify/gate-${GATE_NAME}.log" 2>&1; then
      echo "GATE ${GATE_NAME}: FAIL after simplification"
      GATE_PASS=false
      break
    fi
    echo "GATE ${GATE_NAME}: PASS"
  fi
done

# Also run custom gates if any
if [ "$GATE_PASS" = "true" ]; then
  CUSTOM_GATES=$(jq -r '.gates.custom // [] | .[] | "\(.name)|\(.command)"' "${RUN_DIR}/forge-status.json")
  for ENTRY in $CUSTOM_GATES; do
    GATE_NAME=$(echo "$ENTRY" | cut -d'|' -f1)
    GATE_CMD=$(echo "$ENTRY" | cut -d'|' -f2-)
    echo "Running custom gate: ${GATE_NAME}"
    if ! eval "$GATE_CMD" > "${ARTIFACT_PATH}/simplify/gate-${GATE_NAME}.log" 2>&1; then
      echo "GATE ${GATE_NAME}: FAIL after simplification"
      GATE_PASS=false
      break
    fi
    echo "GATE ${GATE_NAME}: PASS"
  done
fi

if [ "$GATE_PASS" = "false" ]; then
  echo "⚠️ Simplification broke ${GATE_NAME} gate — reverting simplification changes"
  git checkout -- . ':!artifacts/'
  FS_TMP=$(mktemp) && jq '.simplify_failures = ((.simplify_failures // 0) + 1)' "${RUN_DIR}/forge-status.json" > "$FS_TMP" && mv "$FS_TMP" "${RUN_DIR}/forge-status.json"
  echo '{"reverted": true, "reason": "gate_failure", "gate": "'${GATE_NAME}'"}' > "${ARTIFACT_PATH}/simplify/revert.json"
fi
```

**DO NOT run AI review after simplification.** Gates-only re-verification prevents infinite review loops.

---

#### 2f. Commit Step

**Pre-commit guard — verify review artifacts exist:**

```bash
if [ ! -f "{ARTIFACT_PATH}/review/status.json" ]; then
  echo "STOP: review/status.json missing for {STEP_ID}. You skipped verification. Go back to step 2e."
  exit 1
fi
```

If the file does not exist, STOP — you skipped verification. Go back to step 2e and run the Reviewer agent.

```bash
# Log whether simplification ran (informational, non-blocking)
if [ -f "${ARTIFACT_PATH}/simplify/status.json" ]; then
  SIMPLIFY_PASS=$(jq -r '.pass' "${ARTIFACT_PATH}/simplify/status.json")
  SIMPLIFY_FILES=$(jq -r '.files_modified | length' "${ARTIFACT_PATH}/simplify/status.json" 2>/dev/null || echo "0")
  echo "Simplification: pass=${SIMPLIFY_PASS}, files=${SIMPLIFY_FILES}"
fi

git add -- . ':!artifacts/'
git commit -m "$(cat <<'EOF'
feat(forge): {STEP_ID} — {short task title}

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

Update `${RUN_DIR}/forge-status.json`: increment current_step. Mark task `[x]` in plan file.

#### 2g. Loop (Group-Aware)

Check `parallel_groups` in `${RUN_DIR}/forge-status.json`:

```bash
PARALLEL_GROUPS=$(jq -r '.parallel_groups // empty' "${RUN_DIR}/forge-status.json")
```

**If `parallel_groups` is missing or empty:** Fall back to sequential execution — repeat from 2a for the next unchecked task. This is backward compatible with plans that weren't prepped with parallel detection.

**If `parallel_groups` exists:** Execute groups in order. For each group:

1. **Single-step group** (e.g., `[3]`): Execute identically to the sequential path — steps 2a through 2f. No overhead.

2. **Multi-step group** (e.g., `[1, 2]`): Execute steps in parallel:
   a. Capture `GROUP_BASE_SHA=$(git rev-parse HEAD)` once — all workers share it
   b. Generate all `task.md` files for the group (step 2a for each)
   c. Spawn all workers simultaneously using `run_in_background: true` (step 2c for each)
   d. Wait for all workers to complete
   e. Parse each worker's result (step 2d for each)
   f. Run per-step verification **sequentially** — each reviewer diffs against `GROUP_BASE_SHA` (step 2e for each)
   g. Commit each step separately using targeted `git add` with the step's file scope from `task_scopes` (step 2f for each)

3. **If any step in a group fails:** Do NOT start the next group. Handle the failure normally (fix step, circuit breaker, etc.). Passing peers in the same group are already committed.

When all groups in the current phase are complete, run the post-loop verification check before proceeding.

#### 2h. Post-Loop Verification Check

**Before proceeding to gates, verify every step has review artifacts:**

```bash
for STEP_DIR in artifacts/${RUN_ID}/step-*/; do
  if [ ! -f "${STEP_DIR}review/status.json" ]; then
    echo "STOP: Missing review artifacts for $(basename $STEP_DIR). Go back and run step 2e for this step."
    exit 1
  fi
done
echo "All steps verified."
```

If any step is missing `review/status.json`, STOP and go back to run the Reviewer for that step. Do NOT proceed to gates with unverified steps.

---

### Step 3: Phase 2 — Objective Gates (Bash, No AI)

Run verification commands from forge-status.json gates. Sequential, stop on first failure.

```bash
GATES=$(jq -r '.gates' "${RUN_DIR}/forge-status.json")
```

For each built-in gate (lint, typecheck, test, build, secrets):

1. Skip if gate value is null
2. Create gate artifact directory: `artifacts/${RUN_ID}/gates/${GATE_NAME}/`
3. **Validate the gate command exists** before running:
   ```bash
   GATE_BIN=$(echo "$GATE_CMD" | awk '{print $1}')
   if ! command -v "$GATE_BIN" >/dev/null 2>&1; then
     echo "GATE ${GATE_NAME}: FAIL (command not found: ${GATE_BIN})"
     echo '{"gate":"'${GATE_NAME}'","command":"'${GATE_CMD}'","pass":false,"exit_code":-1,"raw_log_bytes":0,"blocking_issues":["'${GATE_BIN}' not found — install it before running forge"]}' > "artifacts/${RUN_ID}/gates/${GATE_NAME}/status.json"
     echo "${GATE_BIN}: command not found" > "artifacts/${RUN_ID}/gates/${GATE_NAME}/raw.log"
     # Treat as gate failure — triggers fix step
     break
   fi
   ```
4. Run the command, capture output to `raw.log`
5. Write `status.json` with `raw_log_bytes` for auditability:
   ```json
   {"gate": "<name>", "command": "<cmd>", "pass": true/false, "exit_code": N, "raw_log_bytes": <byte size of raw.log>}
   ```
   ```bash
   RAW_LOG_BYTES=$(wc -c < "artifacts/${RUN_ID}/gates/${GATE_NAME}/raw.log" 2>/dev/null || echo 0)
   ```
6. Print result: `GATE <name>: PASS/FAIL`

Then run custom gates (if any):

```bash
CUSTOM_GATES=$(jq -r '.gates.custom // [] | .[] | "\(.name)|\(.command)"' "${RUN_DIR}/forge-status.json")
for ENTRY in $CUSTOM_GATES; do
  GATE_NAME=$(echo "$ENTRY" | cut -d'|' -f1)
  GATE_CMD=$(echo "$ENTRY" | cut -d'|' -f2-)
  # Same flow: create dir, run command, capture output, write status.json
done
```

Custom gates follow the same pass/fail/fix logic as built-in gates (including command existence validation and `raw_log_bytes` in status.json).

**On gate failure:**
- Display failing gate and output
- Create a fix step targeting the failure
- Loop back to Step 2 (execute fix, re-verify, then re-run gates)
- Circuit breaker: max 3 gate-fix cycles → HALT

**On all gates pass:**
```
=== Objective Gates ===
PASS lint
PASS typecheck
PASS test
PASS build
PASS secrets
```

Proceed to Step 4 (AI Review).

---

### Step 4: Phase 3 — AI Review (2 Agents, Parallel)

Launch two reviewers in parallel via Task tool:

**Reviewer 1: Correctness (Claude Reviewer agent)**

```
subagent_type: "reviewer"
model: "sonnet"
prompt: |
  Review ALL changes from forge run {RUN_ID}.

  Read: {PLAN_FILE}, {REPO_PATH}/${RUN_DIR}/ACCEPTANCE.md, {REPO_PATH}/${RUN_DIR}/DECISIONS.md
  Run: git diff {BASE_BRANCH}...HEAD

  FOCUS: Logic errors, edge cases, error handling, security, test quality.
  DO NOT flag: style, naming, minor refactors.

  Write to artifacts/{RUN_ID}/final-review/correctness/:
  - status.json (agent:"reviewer", task_type:"review", pass, blocking_issues top 5 max)
  - review.md (top 5 issues max, categorized by severity)

  Return: DONE step=final-correctness pass=<true|false> artifacts=artifacts/{RUN_ID}/final-review/correctness/
```

**Reviewer 2: Implementation (Codex via wrapper)**

Create a review task.md at `artifacts/{RUN_ID}/final-review/implementation/task.md`:

```markdown
# Final Review — Implementation Coverage

## Context
- Repo: {REPO_PATH}
- Run: {RUN_ID}
- Step: final-implementation

## Objective
Review ONLY. Do NOT modify code.

## Instructions
Read: {PLAN_FILE}, {REPO_PATH}/${RUN_DIR}/ACCEPTANCE.md, {REPO_PATH}/${RUN_DIR}/DECISIONS.md
Run: git diff {BASE_BRANCH}...HEAD

CHECK:
- Does the diff satisfy ACCEPTANCE.md?
- Are all plan tasks implemented?
- Missing integration between steps?
- Requirement gaps?

## Output contract
Write to artifacts/{RUN_ID}/final-review/implementation/:
- status.json (agent:"codex-reviewer", task_type:"review", pass, blocking_issues)
- review.md (findings, coverage assessment)

Then print: DONE step=final-implementation pass=<true|false> artifacts=artifacts/{RUN_ID}/final-review/implementation/
```

Run via forge-codex.sh:
```bash
bash ~/claude-env/scripts/forge-codex.sh \
  "${REPO_PATH}" \
  "artifacts/${RUN_ID}/final-review/implementation" \
  "artifacts/${RUN_ID}/final-review/implementation/task.md" \
  300 \
  false
```

**If Codex wrapper fails for review:** Skip Codex review, continue with Claude review only. Print warning.

#### Parse Review Results

Read `status.json` from each reviewer:

- **Both pass** → skip final check → proceed to Step 5 (Ship)
- **Issues found** → create fix steps from blocking_issues, execute fixes, re-run gates, re-run reviewers
- **Circuit breaker:** max 3 review-fix cycles → HALT with summary of unresolved issues

#### Conditional Final Check

**Only if fixes were made during Phase 3**, spawn one more Reviewer:

```
subagent_type: "reviewer"
model: "sonnet"
prompt: |
  Only runs because prior reviewers found issues that were fixed.
  Verify the fixes are correct. Only flag CRITICAL or MAJOR new issues found while verifying.

  Read: {PLAN_FILE}, {REPO_PATH}/${RUN_DIR}/ACCEPTANCE.md, {REPO_PATH}/${RUN_DIR}/DECISIONS.md
  Run: git diff {BASE_BRANCH}...HEAD

  Write to artifacts/{RUN_ID}/final-review/final-check/:
  - status.json, review.md

  Return: DONE step=final-check pass=<true|false> artifacts=artifacts/{RUN_ID}/final-review/final-check/
```

- **pass=true** → proceed to Ship
- **pass=false** with only warnings → proceed to Ship with warnings noted
- **pass=false** with critical issues → HALT

---

### Step 5: Phase 4 — Ship

NOW read everything:
- All `artifacts/{RUN_ID}/step-XX/summary.md` files
- All `artifacts/{RUN_ID}/final-review/*/review.md` files
- ACCEPTANCE.md — verify all "Must Pass" items are satisfied

#### 5a. Run Smoke Test

Execute smoke test commands from ACCEPTANCE.md `## Smoke Test` section:

```bash
# Parse and run each smoke test command
# If any fail, report but don't block (user decides)
```

#### 5b. Final Commit

```bash
git add -- . ':!artifacts/'
git commit -m "$(cat <<'EOF'
feat: [feature name from plan] — forge complete

Forge run: {RUN_ID}
Steps: {total_steps} completed
Reviews: correctness (Claude) + implementation (Codex)
Gates: lint, typecheck, test, build, secrets — all pass

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
Co-Authored-By: Codex CLI 5.4 <noreply@openai.com>
EOF
)"
```

#### 5c. Deploy (Optional)

If the project has a Deployer configuration:

```
subagent_type: "deployer"
prompt: "Deploy the current build to production. Run: {deploy_command}"
```

If no deploy config, skip and note: "No deploy configuration found. Push manually when ready."

#### 5d. Summary Report

```markdown
## /forge Complete

### Run: {RUN_ID}
- Plan: {PLAN_FILE}
- Steps completed: {N}/{total}
- Fix cycles: {N}
- Duration: {elapsed} (calculate from `started_at` in forge-status.json to current time)

### Objective Gates
| Gate | Status |
|------|--------|
| Lint | PASS |
| Typecheck | PASS |
| Test | PASS |
| Build | PASS |
| Secrets | PASS |

### AI Reviews
| Reviewer | Model | Status | Issues |
|----------|-------|--------|--------|
| Correctness | Claude | PASS | 0 |
| Implementation | Codex | PASS | 0 |
| Final Check | Claude | SKIPPED | — |

### Parallel Execution
| Group | Steps | Mode | Status |
|-------|-------|------|--------|
(Populate from parallel_groups in forge-status.json. Show "No parallelism" if all groups are single-step.)

### Codex Fallbacks
| Step | Reason | Fallback |
|------|--------|----------|
| step-04 | timeout | builder |
| step-08 | exit code 1 | builder |
(Only shown if codex_fallbacks array is non-empty in forge-status.json)

### Code Simplification
| Step | Simplified | Files Modified | Reverted |
|------|-----------|----------------|----------|
(Populate from {ARTIFACT_PATH}/simplify/status.json per step. Show "Skipped" if no code files or disabled.)

### Acceptance Criteria
- Must Pass: X/X satisfied
- Should Pass: Y/Y satisfied
- Smoke Test: PASS/FAIL

### Artifacts
All artifacts in: artifacts/{RUN_ID}/

### Next
- `git push` to publish
- Or `/ship` to deploy
```

#### 5e. Clean Up

Update `${RUN_DIR}/forge-status.json` (full run state):
```json
{
  "ready": false,
  "completed": true,
  "completed_at": "<timestamp>"
}
```

Also update root `forge-status.json` (pointer file) to mark completed:
```json
{
  "active_run": null,
  "run_dir": "<RUN_DIR>",
  "completed": true,
  "completed_at": "<timestamp>"
}
```

Note: Any background Codex processes spawned via forge-codex.sh should have exited by now (they timeout at 900s). No manual cleanup needed unless `ps aux | grep codex` shows orphaned processes from failed steps — in that case, kill them by PID.

---

## Self-Continuation After /clear

If context gets large during a forge run, the system may auto-compact or you may need to `/clear`.

After clearing, run `/forge` again — it reads forge-status.json and resumes from the current step.

forge-status.json is updated after every step, so no progress is lost.

---

## Safety Features

| Feature | Description |
|---------|-------------|
| **Clean tree enforcement** | Dirty working tree blocked at forge start |
| **Per-step verification** | Every step gets a fresh Reviewer before advancing |
| **Circuit breaker** | Max 3 retries per step, max 3 gate-fix cycles, max 3 review-fix cycles |
| **Artifact contract** | Workers write to disk, HMFIC reads only status lines |
| **Codex fallback** | Walk-away: auto-Builder + log. Attended: AskUserQuestion with 4 options |
| **Gate command validation** | Validates command exists before running (prevents silent-pass on missing tools) |
| **Objective gates** | Bash-only verification (free, no tokens) before AI review |
| **Custom gates** | Plan-defined verification commands extend/override built-in gates |
| **Code simplification** | Optional Opus-powered cleanup after verification, gate-only re-verify, auto-revert on failure |
| **Per-step commits** | Each step committed separately for easy rollback |
| **Rollback** | `/forge-rollback` resets to pre-forge SHA (soft or hard) |
| **Parallel execution** | Non-overlapping steps run concurrently within groups |
| **Duration tracking** | `started_at` timestamp enables elapsed time reporting |
| **forge-status.json** | Machine-readable state for resume after /clear or crash |

---

## Artifact Schema

Canonical `status.json` schema for all workers and reviewers:

```json
{
  "pass": true,               // REQUIRED: boolean — did the step succeed?
  "blocking_issues": [],      // REQUIRED: array of strings — empty if pass=true
  "agent": "codex-implementer", // REQUIRED: string — who wrote this artifact
  "task_type": "implement",   // Optional: "implement" | "review" | "fix"
  "run_id": "run-2026-...",   // Optional: forge run identifier
  "step": "step-01",          // Optional: step identifier
  "warnings": [],             // Optional: non-blocking observations
  "metrics": {}               // Optional: timing, token usage, etc.
}
```

**Rules:**
- The key MUST be `pass` (boolean). NOT `approved`, `reviewed`, `success`, or any variant.
- `blocking_issues` MUST be non-empty when `pass` is `false`. Empty issues with `pass: false` is a bug.
- Codex wrappers (forge-codex.sh, review-codex.sh) generate all artifacts — Codex only writes code (implement) or review.md (review). The `generated_by: "wrapper"` field identifies wrapper-generated artifacts.
- Builder agents still write their own artifacts directly per the contract above.

---

## Error Recovery

| Situation | Recovery |
|-----------|----------|
| Codex wrapper fails | Walk-away: auto-Builder fallback + log. Attended: AskUserQuestion → `/forge-continue` or `--claude` |
| Step fails 3 times | Circuit breaker HALT → fix manually or modify plan |
| Gate fails | Auto-creates fix step → re-runs gates |
| Review finds issues | Auto-creates fix step → re-runs gates → re-runs review |
| Context too large | `/clear` then `/forge` — resumes from forge-status.json |
| Crash/disconnect | Run `/forge` — picks up from last committed step |
| Bad forge run | `/forge-rollback` — soft reset (staged) or `--hard` (full revert) |

---

## Test Plan

### Codex Path Validation
- [ ] Run `/forge` on a plan with codex-assigned steps
- [ ] Verify forge-codex.sh generates status.json, summary.md, raw.log
- [ ] Verify review-codex.sh runs with `approval_policy=never`
- [ ] Trigger a Codex failure → verify auto-Builder fallback (walk-away mode)
- [ ] Trigger a Codex failure → verify AskUserQuestion prompt (attended mode)

### Simplification Validation
- [ ] Run a forge with `simplify: true` → verify code-simplifier agent runs after verification
- [ ] Trigger simplification gate failure → verify auto-revert and `simplify_failures` increment
- [ ] Trigger 2 consecutive failures → verify circuit breaker disables simplification
- [ ] Run with `--no-simplify` → verify simplification is skipped

### Parallel Execution Validation
- [ ] Create a plan with non-overlapping file scopes → verify parallel groups detected
- [ ] Create a plan with overlapping scopes → verify tasks placed in separate groups
- [ ] Run `/forge` with parallel groups → verify multi-step groups spawn concurrent workers
- [ ] Fail one step in a parallel group → verify only that step retries, peers committed

### Custom Gates Validation
- [ ] Add `## Gates` section to a plan → verify forge-prep parses custom gates
- [ ] Custom gate with same name as built-in → verify it overrides the built-in command
- [ ] Custom gate with new name → verify it runs after built-in gates

### Rollback Validation
- [ ] Run `/forge-rollback` → verify soft reset to pre-forge SHA (changes staged)
- [ ] Run `/forge-rollback --hard` → verify hard reset (all changes gone)
- [ ] Verify forge-status.json updated with `rolled_back: true`
