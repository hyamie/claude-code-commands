---
name: forge-continue
description: Resume /forge after Codex failure — manual handoff or Builder fallback
argument-hint: "[--claude]"
---

# /forge-continue — Resume After Codex Failure

Resume the /forge pipeline after a Codex wrapper failure. Either Codex was run manually (default), or fall back to Builder agent with `--claude`.

## Usage

```
/forge-continue           # Codex completed manually, continue forge loop
/forge-continue --claude  # Fall back to Builder agent for this step
```

## Process

### Step 1: Load Forge State

```bash
if [ ! -f forge-status.json ]; then
  echo "ERROR: No forge-status.json found. Run /forge-prep first."
  exit 1
fi

cat forge-status.json

# Pointer resolution: root forge-status.json points to a run dir
RUN_DIR=$(jq -r '.run_dir // empty' forge-status.json)
if [ -n "$RUN_DIR" ]; then
  cat "${RUN_DIR}/forge-status.json"
else
  echo "ERROR: forge-status.json has no run_dir field. Run /forge-prep first."
  exit 1
fi

ACCEPTANCE_FILE="${RUN_DIR}/ACCEPTANCE.md"
DECISIONS_FILE="${RUN_DIR}/DECISIONS.md"
```

Parse:
- `run_id` — current run
- `current_step` — step that failed
- `plan_file` — the plan being executed
- `current_phase` — which phase we're in
- `parallel_groups` — group assignments (if present)
- `task_scopes` — file scope per step (if present)

**Parallel group detection:** Determine which group contains the current step:

```bash
CURRENT_STEP_NUM=$(jq -r '.current_step' "${RUN_DIR}/forge-status.json")
CURRENT_GROUP=$(jq -r --argjson step "$CURRENT_STEP_NUM" '
  .parallel_groups // [] | to_entries[] |
  select(.value | contains([$step])) | .key
' "${RUN_DIR}/forge-status.json" 2>/dev/null || echo "")
```

If `parallel_groups` is missing or the step isn't found in any group, treat as sequential (no special handling needed).

**Important:** When resuming a failed step from a parallel group, only resume the failed step — passing peers in the same group were already committed by /forge before the failure. Do NOT re-run the entire group.

### Step 2: Find Current Artifact Directory

```bash
RUN_ID=$(jq -r '.run_id' "${RUN_DIR}/forge-status.json")
STEP=$(printf "step-%02d" $(jq -r '.current_step' "${RUN_DIR}/forge-status.json"))
ARTIFACT_PATH="artifacts/${RUN_ID}/${STEP}"

if [ ! -d "$ARTIFACT_PATH" ]; then
  echo "ERROR: Artifact directory not found: $ARTIFACT_PATH"
  echo "Expected /forge to have created this before the failure."
  exit 1
fi

# Capture base SHA BEFORE recovery work — needed for accurate reviewer diffs later
STEP_BASE_SHA=$(git rev-parse HEAD)
```

### Step 3: Determine Resume Mode

Check if `--claude` flag was passed.

**Without `--claude` (default):** Codex completed manually.

1. Check for artifacts written by manual Codex session:
   ```bash
   ls -la ${ARTIFACT_PATH}/
   ```
2. If `status.json` exists in the artifact path, read it and parse the pass/fail
3. If NO `status.json`, run verification commands from task.md to determine pass/fail:
   ```bash
   # Extract verification commands from task.md "## Verification" section
   # Run each command sequentially
   ```
   - **All verification commands pass:** Create `status.json` with `pass: true` + warning `"auto-verified, no worker status"`
   - **Any verification command fails:** Create `status.json` with `pass: false` + `blocking_issues` listing the failed command and output
   - **No verification commands in task.md:** Create `status.json` with `pass: false` + `blocking_issues: ["no verification evidence — no status.json and no verification commands"]`
4. If `summary.md` doesn't exist, generate a brief one from git diff

**With `--claude`:** Builder agent implements instead.

1. Read the task.md from the artifact path:
   ```bash
   cat ${ARTIFACT_PATH}/task.md
   ```
2. Spawn a Builder agent via Task tool:
   ```
   subagent_type: "builder"
   prompt: [contents of task.md + standard builder instructions]

   Read: ${ACCEPTANCE_FILE}, ${DECISIONS_FILE}
   ```
3. After Builder completes:
   - Write `status.json` to artifact path (schema: `{pass, blocking_issues, warnings, metrics, agent:"builder"}`)
   - Write `summary.md` to artifact path
   - Capture any verification output to `raw.log`
4. Verify Builder wrote required files:
   ```bash
   for f in status.json summary.md; do
     if [ ! -f "${ARTIFACT_PATH}/$f" ]; then
       echo "ERROR: Builder did not write ${ARTIFACT_PATH}/$f. Cannot continue."
       exit 1
     fi
   done
   ```
   If `status.json` is missing `.pass` field, default to `pass: false`.

### Step 4: Run Per-Step Verification

Regardless of resume mode, spawn a Reviewer agent to verify the step (using `STEP_BASE_SHA` captured in Step 2):

```
subagent_type: "reviewer"
model: "sonnet"

You are verifying ONE step of a /forge run. Do NOT implement anything.

Read: {PLAN_FILE}, ${ACCEPTANCE_FILE}, ${DECISIONS_FILE}, {ARTIFACT_PATH}/task.md,
      {ARTIFACT_PATH}/summary.md, {ARTIFACT_PATH}/status.json
Then: git diff {STEP_BASE_SHA} --stat + read changed files

CHECKLIST:
1. PLAN COMPLIANCE: Change implements task.md and nothing extra?
2. SCOPE DRIFT: Touched files outside listed scope?
3. DECISIONS: Entries in DECISIONS.md reasonable?
4. VERIFICATION: Commands ran and passed?
5. OBVIOUS RISKS: Edge cases, missing error handling, security?

Write to {ARTIFACT_PATH}/review/:
- status.json (agent:"reviewer", task_type:"review")
- review.md (Gate: PASS/FAIL, findings, scope drift check)

Return: DONE step={STEP_ID} pass=<true|false> artifacts={ARTIFACT_PATH}/review/
```

### Step 4b: Code Simplification (if enabled)

If the reviewer passed (`pass=true`), check if simplification is enabled before committing:

```bash
SIMPLIFY=$(jq -r '.simplify // true' "${RUN_DIR}/forge-status.json")
SIMPLIFY_FAILURES=$(jq -r '.simplify_failures // 0' "${RUN_DIR}/forge-status.json")
SIMPLIFY_CB=$(jq -r '.simplify_circuit_breaker // 2' "${RUN_DIR}/forge-status.json")
```

If enabled and circuit breaker not tripped, run the same simplification pass described in forge.md step 2e-simplify:

1. Get changed code files: `git diff --name-only ${STEP_BASE_SHA} -- . ':!artifacts/' | grep -E '\.(ts|tsx|js|jsx|py|go|rs|java|rb|sh|css|scss)$'`
2. If code files exist, spawn `pr-review-toolkit:code-simplifier` agent (Opus) scoped to those files
3. Write artifacts to `{ARTIFACT_PATH}/simplify/`
4. If simplifier makes changes, run objective gates only (lint, typecheck, test, build) — no AI review
5. If gates fail after simplification, revert with `git checkout -- . ':!artifacts/'` and increment `simplify_failures`
6. If simplifier fails or no code files, skip and proceed to commit

Skip if simplification is disabled or circuit breaker has tripped (`simplify_failures >= simplify_circuit_breaker`).

### Step 5: Handle Verification Result

Read the reviewer's `status.json`:

- **pass=true:** Commit the step, update forge-status.json (advance current_step), mark task `[x]` in plan
- **pass=false:** Display findings from review.md, create a fix step

### Step 6: Resume Forge Loop

After successful step completion:

1. Update forge-status.json:
   ```bash
   # Write updated state to run-dir status
   FS_TMP=$(mktemp) && jq ".current_step = <next step number>" "${RUN_DIR}/forge-status.json" > "$FS_TMP" && mv "$FS_TMP" "${RUN_DIR}/forge-status.json"
   ```

2. Display status:
   ```markdown
   ## Step Recovered

   - Step: {STEP_ID}
   - Worker: {codex-manual or builder}
   - Verification: PASS
   - Commit: [hash]

   ### Continuing /forge...
   ```

3. **Automatically continue the forge loop** — proceed to the next step using group-aware logic.

   **If parallel groups exist:**
   - Check if any remaining steps in the current group still need to run (e.g., the failed step was
     part of a multi-step group and other steps in the group haven't been attempted yet).
   - If the current group is fully done (all steps committed or just recovered), advance to the next group.
   - Resume uses forge.md Step 2g logic: single-step groups run sequentially, multi-step groups
     spawn parallel workers.

   **If no parallel groups (sequential fallback):**
   - Proceed to the next step number sequentially.

   If this was the last step/group, proceed to objective gates (Phase 2 of forge).

   Do NOT tell the user to "run /forge to resume." Instead, continue executing the forge loop
   directly from this command. The forge-status.json is updated — just proceed to the next step
   using the same logic as forge.md Step 2 (generate task.md, spawn worker, verify, commit).

   **Exception:** If you detect the context is very large (approaching compaction), print:
   ```
   Context is large — run /forge to continue in a fresh context.
   ```
   and stop. Otherwise, keep going.
