---
name: forge-prep
description: Prepare a plan for /forge — validate, create acceptance criteria, assign workers
argument-hint: "[.claude/plans/plan.md]"
---

# /forge-prep — Prepare Plan for Forge Execution

Validates a plan, generates a run ID, creates ACCEPTANCE.md and DECISIONS.md inside the per-run artifacts directory, assigns workers (Codex vs Builder) per task, detects verification commands, and creates forge-status.json (root pointer + full run-dir copy).

## Usage

```
/forge-prep                              # Prep latest plan
/forge-prep .claude/plans/my-feature.md  # Prep specific plan
/forge-prep --no-simplify                # Disable code simplification pass
```

## Process

### Step 1: Find Plan File

```bash
# Parse flags
NO_SIMPLIFY=false
for arg in "$@"; do
  case "$arg" in
    --no-simplify) NO_SIMPLIFY=true ;;
  esac
done

# Use argument or find latest plan (skip flags)
PLAN_FILE="${1:-}"
[[ "$PLAN_FILE" == --* ]] && PLAN_FILE=""

if [ -z "$PLAN_FILE" ]; then
  PLAN_FILE=$(ls -t .claude/plans/*.md 2>/dev/null | head -1)
fi

if [ -z "$PLAN_FILE" ] || [ ! -f "$PLAN_FILE" ]; then
  echo "No plan found. Create a plan first with /plan"
  exit 1
fi

echo "Preparing: $PLAN_FILE"
```

Read the plan file.

### Step 2: Validate Plan Structure

Check the plan has:
- At least one `## Phase` or `### Phase` header
- At least one `- [ ]` task checkbox

If missing either, display error:
```
ERROR: Plan missing phases or tasks.
Expected: ## Phase N headers with - [ ] task checkboxes.
```

**Codex AGENTS.md check:** If any tasks will be assigned to Codex (Step 6), verify `~/.codex/AGENTS.md` exists:
```bash
if [ ! -f ~/.codex/AGENTS.md ]; then
  echo "WARNING: ~/.codex/AGENTS.md not found. Codex workers may lack project guidelines."
  echo "Consider creating it from ~/claude-env/templates/AGENTS.md"
fi
```
This is a non-blocking warning only.

### Step 3: Generate Run ID and Create Run Directory

Generate a run ID: `run-YYYY-MM-DD-NNN` (increment NNN if prior runs exist in `artifacts/`).

```bash
TODAY=$(date +%Y-%m-%d)
# Find the highest existing NNN for today in artifacts/
LAST=$(ls -d artifacts/run-${TODAY}-* 2>/dev/null | sort | tail -1)
if [ -z "$LAST" ]; then
  NNN="001"
else
  PREV=$(basename "$LAST" | sed "s/run-${TODAY}-//")
  NNN=$(printf "%03d" $((10#$PREV + 1)))
fi
RUN_ID="run-${TODAY}-${NNN}"
RUN_DIR="artifacts/${RUN_ID}"
PRE_FORGE_SHA=$(git rev-parse HEAD)
mkdir -p "${RUN_DIR}"
echo "Run ID: ${RUN_ID}"
echo "Run dir: ${RUN_DIR}"
echo "Pre-forge SHA: ${PRE_FORGE_SHA}"
```

### Step 4: Create ACCEPTANCE.md

If a root-level `ACCEPTANCE.md` exists, print a legacy warning:

```bash
if [ -f "ACCEPTANCE.md" ]; then
  echo "⚠️ Legacy ACCEPTANCE.md at root detected. New criteria written to ${RUN_DIR}/ACCEPTANCE.md"
fi
```

Generate acceptance criteria — **prefer PRD over plan-derived criteria**:

**Check for PRD first:**
```bash
# Look for PRD referenced in plan header (PRD: .claude/plans/prd-*.md)
PRD_FILE=$(grep -oP '(?<=\*\*PRD:\*\* )\.claude/plans/prd-[^ ]+\.md' "$PLAN_FILE" 2>/dev/null || echo "")

# If not in plan, check for any recent PRD
if [ -z "$PRD_FILE" ] || [ ! -f "$PRD_FILE" ]; then
  PRD_FILE=$(ls -t .claude/plans/prd-*.md 2>/dev/null | head -1)
fi
```

**If PRD exists:** Read the PRD and copy its Acceptance Criteria section directly. The PRD is the canonical source — do not paraphrase or reinterpret. Copy Must Pass, Should Pass, and Smoke Test sections verbatim.

**If no PRD exists (fallback):**
1. Extract all acceptance criteria from the plan (look for "acceptance criteria", "must pass", "requirements" sections)
2. If the plan has no explicit criteria, generate them from the task descriptions — one "Must Pass" item per task
3. Add a "Smoke Test" section with placeholder commands

Write to `${RUN_DIR}/ACCEPTANCE.md`:

```markdown
# Acceptance Criteria: [Feature Name from Plan]

## Must Pass (blocking)
- [ ] [criterion derived from plan tasks]
- [ ] [criterion derived from plan tasks]

## Should Pass (warning)
- [ ] All verification commands pass (lint, test, build)

## Smoke Test
- [ ] [placeholder — user should fill in a curl/CLI command that proves it works]
```

### Step 5: Create DECISIONS.md

Create empty template at `${RUN_DIR}/DECISIONS.md`:

```markdown
# Decisions Log

Append-only. Workers add entries during /forge runs. Verifiers read but don't modify.
```

### Step 6: Assign Worker Types and Models

For each task in the plan, assign a worker type AND model using the tier+type matrix below. This replaces the old keyword heuristic approach.

**Step 6 sub-process:**
1. Determine the task type using keyword detection (see table below)
2. Read the tier from `tier_assignments` (assigned in Step 6c, which runs after this — use `medium` as provisional default, then re-run assignment after 6c assigns tiers)
3. Look up the worker + model from the matrix

**Worker+Model Assignment Matrix (tier × task type):**

| Task Type | Trivial | Small | Medium | Large |
|-----------|---------|-------|--------|-------|
| Implementation (default) | codex | codex | codex | builder (opus) |
| Test generation | codex | codex | codex | builder (sonnet) |
| API integration | codex | codex | codex | builder (opus) |
| Frontend/UI | codex | codex | codex | builder (sonnet) |
| DevOps/scripts | codex | codex | codex | builder (sonnet) |
| Architecture/refactor | — | builder (sonnet) | builder (opus) | builder (opus) |
| Security work | — | builder (opus) | builder (opus) | builder (opus) |
| Documentation | codex | codex | builder (sonnet) | builder (sonnet) |
| Database migration | — | builder (sonnet) | builder (sonnet) | builder (opus) |

**"—" means that tier/type combination shouldn't exist.** If encountered, assign builder (sonnet) as safe default.

**Task type detection keywords:**
- DevOps/scripts: shell, bash, script, dockerfile, CI, CD, pipeline, deploy, infra
- Frontend/UI: component, page, dashboard, UI, CSS, layout, React, Next
- Test generation: test, spec, fixture, mock, assert
- Architecture/refactor: refactor across, redesign, restructure, migrate pattern
- Security: auth, permission, RBAC, vulnerability, sanitize, encrypt
- Database migration: migration, schema, DDL, ALTER TABLE, index
- Documentation: docs, README, guide, CLAUDE.md, operations-guide
- API integration: API, endpoint, REST, GraphQL, webhook, fetch, request
- Implementation: (default — everything else)

**SCOPE LIMIT (unchanged):** Max 5 new files or ~150 lines of spec per Codex step. If exceeded, reassign codex→builder. Codex exhausts its reasoning budget on large tasks.

For each task, record the worker, model, and task type. Print a table:

```
Worker Assignments:
Step  Worker   Model    Type              Task
─────────────────────────────────────────────────────────
01    codex    —        devops/scripts    Write deploy script
02    codex    —        implementation    Create user model
03    builder  opus     security          Add auth middleware
04    codex    —        api-integration   Wire up payment endpoint
```

**Store model assignments and task types in forge-status.json** alongside worker assignments:
```json
"model_assignments": {
  "step-02": "sonnet",
  "step-03": "opus"
},
"task_types": {
  "step-01": "devops/scripts",
  "step-02": "implementation",
  "step-03": "security",
  "step-04": "implementation"
}
```
Codex steps have no model_assignment entry (Codex uses its own model internally).
Every step MUST have a task_types entry — forge.md reads this to set expect_changes.

**NOTE:** Tier assignments from Step 6c may change the matrix lookup. After Step 6c completes, re-validate worker+model assignments against final tiers. If any assignment changes, update both `worker_assignments` and `model_assignments` and print the correction.

### Step 6a: Reference File Analysis (Codex Budget Guard)

For each task assigned to `codex`, analyze the reference files it would need to read:

1. **Extract reference files** from the plan task. Look for:
   - "Files to Read" sections listing file paths
   - "Read these files" instructions
   - Explicit file paths in the task description that the worker must read before implementing
   - Do NOT count files the worker will CREATE (those are output, not input)

2. **Measure reference burden** for each Codex task:
   ```bash
   REF_COUNT=<number of reference files>
   REF_BYTES=0
   for f in <reference_files>; do
     if [ -f "$f" ]; then
       REF_BYTES=$((REF_BYTES + $(wc -c < "$f")))
     fi
   done
   ```

3. **Apply thresholds:**
   - **>4 reference files OR >10KB total reference size** → auto-reassign to `builder`
   - Print warning: `⚠️ step-XX reassigned codex→builder (N ref files, NKB total — exceeds Codex reasoning budget)`

   These thresholds are based on observed Codex no-op failures: tasks requiring 7 large preset files (the ai-answering-factory case) exhausted Codex's reasoning budget on file reads alone, producing zero output.

4. **Print reference analysis table** (only for Codex tasks that were reassigned):
   ```
   Reference File Analysis (Codex budget guard):
   Step  Refs  Size    Action
   ──────────────────────────────────────────────
   01    7     28KB    reassigned → builder
   02    8     32KB    reassigned → builder
   03    2     3KB     OK (stays codex)
   ```

   If no reassignments occurred, print: `Reference analysis: all Codex tasks within budget.`

### Step 6b: File Scope Analysis and Parallel Groups

For each task in the plan, extract file scope from the task text. Look for:
- `IN SCOPE:` sections listing files/directories
- `Required changes:` sections with file paths
- Explicit file paths mentioned in the task description (e.g., `src/models/user.ts`)
- Directory patterns (e.g., `src/api/`, `tests/`)

Build a scope map per step:
```json
"task_scopes": {
  "step-01": ["src/models/"],
  "step-02": ["src/api/"],
  "step-03": [".claude/commands/"],
  "step-04": ["src/models/", "tests/"]
}
```

**Build parallel groups** via greedy overlap detection:

```
groups = [[]]
for each task in order:
  placed = false
  for each existing group:
    if task.files don't overlap with any task already in group:
      add task to group
      placed = true
      break
  if not placed:
    create new group with this task
```

**Overlap rules:**
- Two tasks overlap if any of their file paths share a common prefix
- Directory paths match if one is a prefix of the other (`src/` overlaps `src/models/`)
- Tasks with unknown/empty scope get their own sequential group (safe default)

Store in `${RUN_DIR}/forge-status.json`:
```json
"parallel_groups": [[1, 2], [3], [4, 5]],
"task_scopes": {"step-01": ["src/models/"], "step-02": ["src/api/"]}
```

Print parallel groups in the readiness report (Step 9).

### Step 6c: Assign Complexity Tiers

For each step in the plan, assign a complexity tier based on the task description. Read from the plan file for explicit `- **Tier:** <tier>` overrides first; fall back to heuristics.

**Tier definitions:**
| Tier | Criteria | Pipeline Effect |
|------|----------|----------------|
| `trivial` | Single-file change, <20 lines, no new logic | Skip de-sloppify + skip AI review |
| `small` | 1-3 files, straightforward logic | Skip AI review |
| `medium` | 3-6 files or new patterns (default) | Full pipeline |
| `large` | 7+ files or architectural change | Full pipeline + extra architecture review pass |

**Tier assignment heuristics (when no explicit override):**

```
for each step:
  # Check for explicit override in plan
  TIER=$(grep -A5 "^### Step <N>" plan | grep -oP '(?<=\*\*Tier:\*\* )(trivial|small|medium|large)' || "")

  if [ -n "$TIER" ]; then
    # Use explicit override
  else
    FILE_COUNT=$(count distinct files mentioned in task IN SCOPE list)
    if [ "$FILE_COUNT" -le 1 ] && (task has <20 lines change indication or single-function scope); then
      TIER="trivial"
    elif [ "$FILE_COUNT" -le 3 ]; then
      TIER="small"
    elif [ "$FILE_COUNT" -le 6 ]; then
      TIER="medium"
    else
      TIER="large"
    fi
    # Also force large if: "architectural", "refactor across", "schema change", "migrate", "7+ files"
  fi
  TIER_ASSIGNMENTS["step-XX"]=$TIER
```

**Large tier indicator keywords:** architectural, refactor across, schema change, database migration, cross-cutting concern, 7+ files, redesign, overhaul.

Store tier assignments in `${RUN_DIR}/forge-status.json` as:
```json
"tier_assignments": {
  "step-01": "medium",
  "step-02": "small",
  "step-03": "trivial"
}
```

### Step 6d: Environment Constraint Check

For each Codex-assigned task, scan the task description (from the plan) for host-access ACTION markers — verbs/phrases that require resources Codex's sandbox cannot access.

**Host-access markers (action verbs, not nouns):**
- Docker runtime: `docker cp`, `docker exec`, `docker run`, `docker compose up`, `docker restart`, `docker build` (NOT "Dockerfile" or "docker image" as nouns — those are file edits Codex can handle)
- Network APIs: `curl`, `httpGet`, `fetch(`, `wget`, API endpoint URL patterns (`http://`, `https://`), `grafana`, `prometheus`
- SSH/Remote: `ssh `, `scp `, `rsync`, `remote host`, IP addresses (`192.168.`, `10.0.`)
- Secrets management: `op item`, `op read`, `op run`, `op inject` (NOT `op://` URI strings — those are references Codex can write as literals)
- System: `systemctl`, `journalctl`, `crontab`, `mount`
- Interactive verification: `heartbeat`, `smoke test`, `manual verification`, `e2e test`, `run the service`

**Logic:**

```
for each Codex-assigned step:
  scan task text (from plan) for host-access markers (case-insensitive)
  if ANY marker found:
    reassign worker: codex → builder
    set model: sonnet (safe default for formerly-codex tasks)
    print: "⚠️ step-XX reassigned codex→builder (requires host access: <matched marker>)"
    update worker_assignments and model_assignments in forge-status.json
```

**Print reassignment table** (only if any reassignments occurred):

```
Environment Constraint Check:
Step  Marker Found           Action
──────────────────────────────────────────────
02    docker cp               reassigned → builder (sonnet)
04    op item, service account reassigned → builder (sonnet)
06    heartbeat, smoke test   reassigned → builder (sonnet)
```

If no reassignments: `Environment check: all Codex tasks compatible with sandbox.`

### Step 7: Detect Verification Commands

Auto-detect available verification commands by checking project files:

```bash
# Node.js
if [ -f package.json ]; then
  # Check for lint, typecheck, test, build scripts
  jq -r '.scripts | keys[]' package.json 2>/dev/null | grep -E '^(lint|typecheck|test|build)$'
fi

# Check for pnpm vs npm vs yarn
if [ -f pnpm-lock.yaml ]; then PKG_MGR="pnpm"
elif [ -f yarn.lock ]; then PKG_MGR="yarn"
else PKG_MGR="npm"; fi

# Python
if [ -f pyproject.toml ]; then
  # Check for ruff, mypy, pytest
  grep -q '\[tool.ruff\]' pyproject.toml 2>/dev/null && echo "lint: ruff check ."
  grep -q '\[tool.mypy\]' pyproject.toml 2>/dev/null && echo "typecheck: mypy ."
  grep -q '\[tool.pytest\]' pyproject.toml 2>/dev/null && echo "test: pytest"
fi

# Go
if [ -f go.mod ]; then
  echo "lint: golangci-lint run"
  echo "test: go test ./..."
  echo "build: go build ./..."
fi

# Secret scanning (validate command exists — forge gates will also re-check at runtime)
if command -v gitleaks >/dev/null 2>&1; then
  echo "secrets: gitleaks detect --source ."
else
  echo "⚠️ gitleaks not found — secrets gate will be null. Install: brew install gitleaks"
fi
```

Build a gates object from detected commands.

#### Custom Gates

Check the plan file for a `## Gates` or `## Custom Gates` section. If found, parse custom gate commands:

```markdown
## Gates
- lint: pnpm lint
- typecheck: pnpm typecheck
- integration: docker compose -f docker-compose.test.yml up --abort-on-container-exit
- e2e: playwright test
```

Parse each `- name: command` line into custom gates. These override auto-detected gates (by name) and add new ones. Store as:

```json
"custom": [{"name": "integration", "command": "docker compose -f docker-compose.test.yml up --abort-on-container-exit"}, {"name": "e2e", "command": "playwright test"}]
```

Custom gates that share a name with a built-in gate (lint, typecheck, test, build, secrets) replace the auto-detected command. Custom gates with new names are appended and run after built-in gates.

### Step 8: Create forge-status.json

Write TWO files using the `RUN_ID` and `RUN_DIR` established in Step 3:

**1. Root pointer** — minimal, written to `forge-status.json` at project root:

```json
{
  "active_run": "run-YYYY-MM-DD-NNN",
  "run_dir": "artifacts/run-YYYY-MM-DD-NNN",
  "attended": false,
  "completed": false
}
```

**2. Full status** — written to `${RUN_DIR}/forge-status.json`:

```json
{
  "mode": "forge",
  "plan_file": "<relative path to plan>",
  "prd_file": "<relative path to PRD or null>",
  "acceptance_file": "artifacts/run-YYYY-MM-DD-NNN/ACCEPTANCE.md",
  "decisions_file": "artifacts/run-YYYY-MM-DD-NNN/DECISIONS.md",
  "base_branch": "<current git branch>",
  "pre_forge_sha": "<PRE_FORGE_SHA captured in Step 3>",
  "run_id": "run-YYYY-MM-DD-NNN",
  "run_dir": "artifacts/run-YYYY-MM-DD-NNN",
  "attended": false,
  "current_phase": 1,
  "current_step": 1,
  "total_steps": "<count of all tasks>",
  "worker_assignments": {
    "step-01": "codex|builder",
    "step-02": "codex|builder"
  },
  "model_assignments": {
    "step-02": "sonnet|opus"
  },
  "task_types": {
    "step-01": "devops/scripts",
    "step-02": "implementation"
  },
  "tier_assignments": {
    "step-01": "medium",
    "step-02": "small"
  },
  "parallel_groups": [[1], [2], [3]],
  "task_scopes": {},
  "gates": {
    "lint": "<detected command or null>",
    "typecheck": "<detected command or null>",
    "test": "<detected command or null>",
    "build": "<detected command or null>",
    "secrets": "<detected command or null>",
    "custom": []
  },
  "simplify": true,
  "simplify_failures": 0,
  "simplify_circuit_breaker": 2,
  "started_at": null,
  "ready": true,
  "completed": false
}
```

### Step 8b: Handle --no-simplify Flag

If `--no-simplify` was passed as an argument, set `"simplify": false` in the generated `${RUN_DIR}/forge-status.json`. Otherwise leave the default `true`.

### Step 9: Print Readiness Report

```markdown
## Forge Readiness Report

### Plan
- File: [plan path]
- Phases: [count]
- Tasks: [count]

### Run
- Run ID: [RUN_ID]
- Run dir: [RUN_DIR]

### Files Created
- [x] [RUN_DIR]/ACCEPTANCE.md (N criteria)
- [x] [RUN_DIR]/DECISIONS.md (empty template)
- [x] forge-status.json (root pointer → [RUN_DIR])
- [x] [RUN_DIR]/forge-status.json (full status)

### Worker Assignments
[table from Step 6, with Tier, Model, and Type columns]

```
Worker Assignments:
Step  Worker   Model    Tier      Type              Task
────────────────────────────────────────────────────────────────
01    codex    —        small     devops/scripts    Write deploy script
02    codex    —        medium    implementation    Create user model
03    builder  opus     large     security          Add auth middleware
04    codex    —        small     api-integration   Wire up payment endpoint
```

### Verification Gates
| Gate | Command | Status |
|------|---------|--------|
| Lint | pnpm lint | Detected |
| Typecheck | pnpm typecheck | Detected |
| Test | pnpm test | Detected |
| Build | pnpm build | Detected |
| Secrets | gitleaks detect | Available |

### Parallel Groups
| Group | Steps | Mode |
|-------|-------|------|
| 1 | step-01, step-02 | parallel |
| 2 | step-03 | sequential |
| 3 | step-04, step-05 | parallel |
(Show actual groups from Step 6b. If all groups are single-step, note "No parallelism detected.")

### Custom Gates
| Name | Command | Source |
|------|---------|--------|
(Only shown if custom gates were parsed from plan. Otherwise: "None detected.")

### Code Simplification
| Setting | Value |
|---------|-------|
| Enabled | Yes/No (default: Yes) |
| Agent | code-simplifier (Opus) |
| Circuit Breaker | 2 consecutive gate failures → disable |
| Timing | After verification, before commit |

### Next Step
Run `/forge` to start execution.
```
