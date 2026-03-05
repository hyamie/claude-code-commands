#!/usr/bin/env bash
#
# forge-codex.sh — Run Codex CLI for a single /forge step
#
# Usage: forge-codex.sh REPO_PATH ARTIFACT_PATH TASK_FILE TIMEOUT [WRITABLE]
#
#   REPO_PATH      Absolute path to the repository
#   ARTIFACT_PATH  Directory for output artifacts
#   TASK_FILE      Path to the task.md prompt file
#   TIMEOUT        Max seconds before killing Codex
#   WRITABLE       "true" (default) = implement mode (--full-auto)
#                  "false" = review mode (read-only, approval_policy=never)
#
# Artifacts written by the wrapper (not Codex):
#   status.json    pass/fail + blocking_issues + metadata
#   summary.md     git diff --stat of changes
#   raw.log        full stdout/stderr from Codex
#
# Final stdout line:
#   DONE step=<id> pass=<true|false>

set -euo pipefail

REPO_PATH="${1:?Usage: forge-codex.sh REPO_PATH ARTIFACT_PATH TASK_FILE TIMEOUT [WRITABLE]}"
ARTIFACT_PATH="${2:?Missing ARTIFACT_PATH}"
TASK_FILE="${3:?Missing TASK_FILE}"
TIMEOUT="${4:?Missing TIMEOUT}"
WRITABLE="${5:-true}"

# Derive step ID from the artifact directory name
STEP_ID="$(basename "$ARTIFACT_PATH")"

# ── Validate inputs ──────────────────────────────────────────────────

[[ -d "$REPO_PATH" ]] || { echo "ERROR: REPO_PATH not found: $REPO_PATH" >&2; exit 1; }
[[ -f "$TASK_FILE" ]] || { echo "ERROR: TASK_FILE not found: $TASK_FILE" >&2; exit 1; }
command -v codex >/dev/null 2>&1 || { echo "ERROR: codex CLI not found in PATH" >&2; exit 1; }
[[ "$TIMEOUT" =~ ^[0-9]+$ ]] || { echo "ERROR: TIMEOUT must be a positive integer" >&2; exit 1; }

mkdir -p "$ARTIFACT_PATH"

# ── Capture pre-run state ────────────────────────────────────────────

PRE_SHA="$(git -C "$REPO_PATH" rev-parse HEAD 2>/dev/null || echo "none")"
PROMPT="$(cat "$TASK_FILE")"

# ── Build codex command ──────────────────────────────────────────────

CODEX_ARGS=(exec -C "$REPO_PATH")

if [[ "$WRITABLE" == "false" ]]; then
  # Review mode: no file writes allowed
  CODEX_ARGS+=(-c 'approval_policy="never"')
else
  # Implement mode: auto-approve all actions
  CODEX_ARGS+=(--full-auto)
fi

# ── Run codex with timeout ───────────────────────────────────────────

codex "${CODEX_ARGS[@]}" "$PROMPT" > "${ARTIFACT_PATH}/raw.log" 2>&1 &
CODEX_PID=$!

# Background watcher kills codex if it exceeds the timeout
(
  sleep "$TIMEOUT"
  kill -TERM "$CODEX_PID" 2>/dev/null || true
  sleep 5
  kill -9 "$CODEX_PID" 2>/dev/null || true
) &
WATCHER_PID=$!

set +e
wait "$CODEX_PID" 2>/dev/null
EXIT_CODE=$?
set -e

# Clean up the watcher (codex may have finished before timeout)
kill "$WATCHER_PID" 2>/dev/null || true
wait "$WATCHER_PID" 2>/dev/null || true

# Detect timeout (SIGTERM=143, SIGKILL=137)
TIMED_OUT=0
if (( EXIT_CODE == 143 || EXIT_CODE == 137 )); then
  TIMED_OUT=1
  EXIT_CODE=124
fi

# ── Determine pass/fail ──────────────────────────────────────────────

PASS=true
BLOCKING_ISSUES="[]"

if (( EXIT_CODE != 0 )); then
  PASS=false
  if (( TIMED_OUT )); then
    BLOCKING_ISSUES="[\"Codex timed out after ${TIMEOUT}s\"]"
  else
    BLOCKING_ISSUES="[\"Codex exited with code ${EXIT_CODE}\"]"
  fi
fi

# ── Write status.json ────────────────────────────────────────────────

cat > "${ARTIFACT_PATH}/status.json" <<EOF
{
  "pass": ${PASS},
  "blocking_issues": ${BLOCKING_ISSUES},
  "agent": "codex-implementer",
  "task_type": "implement",
  "step": "${STEP_ID}",
  "exit_code": ${EXIT_CODE},
  "timed_out": $( (( TIMED_OUT )) && echo true || echo false ),
  "generated_by": "wrapper"
}
EOF

# ── Write summary.md from git diff ───────────────────────────────────

{
  echo "# ${STEP_ID} — Summary"
  echo ""
  echo "- Agent: codex"
  echo "- Exit code: ${EXIT_CODE}"
  echo "- Timed out: $( (( TIMED_OUT )) && echo yes || echo no )"
  echo ""
  if [[ "$PRE_SHA" != "none" ]]; then
    echo "## Changes"
    echo '```'
    git -C "$REPO_PATH" diff --stat "$PRE_SHA" -- . ':!artifacts/' 2>/dev/null || echo "(no diff available)"
    echo '```'
  else
    echo "_Pre-run SHA unavailable — no diff generated._"
  fi
} > "${ARTIFACT_PATH}/summary.md"

# ── Final output ─────────────────────────────────────────────────────

echo "DONE step=${STEP_ID} pass=${PASS}"
