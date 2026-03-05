#!/usr/bin/env bash
#
# review-codex.sh — Run Codex CLI as a code reviewer
#
# Usage: review-codex.sh REPO_PATH ARTIFACT_DIR BRIEF_FILE TIMEOUT
#
#   REPO_PATH      Absolute path to the repository
#   ARTIFACT_DIR   Directory for output artifacts
#   BRIEF_FILE     Path to brief.md (review scope + focus)
#   TIMEOUT        Max seconds before killing Codex
#
# Codex runs in read-only sandbox mode (approval_policy=never).
# Codex writes review.md; the wrapper generates status.json.
#
# Final stdout line:
#   DONE review=codex pass=<true|false> findings=<N> artifacts=<path>/

set -euo pipefail

REPO_PATH="${1:?Usage: review-codex.sh REPO_PATH ARTIFACT_DIR BRIEF_FILE TIMEOUT}"
ARTIFACT_DIR="${2:?Missing ARTIFACT_DIR}"
BRIEF_FILE="${3:?Missing BRIEF_FILE}"
TIMEOUT="${4:?Missing TIMEOUT}"

# ── Validate inputs ──────────────────────────────────────────────────

[[ -d "$REPO_PATH" ]] || { echo "ERROR: REPO_PATH not found: $REPO_PATH" >&2; exit 1; }
[[ -f "$BRIEF_FILE" ]] || { echo "ERROR: BRIEF_FILE not found: $BRIEF_FILE" >&2; exit 1; }
command -v codex >/dev/null 2>&1 || { echo "ERROR: codex CLI not found in PATH" >&2; exit 1; }
[[ "$TIMEOUT" =~ ^[0-9]+$ ]] || { echo "ERROR: TIMEOUT must be a positive integer" >&2; exit 1; }

mkdir -p "$ARTIFACT_DIR"

# ── Build review prompt ──────────────────────────────────────────────

BRIEF_CONTENT="$(cat "$BRIEF_FILE")"

PROMPT="You are a code reviewer. Analyze the code described in the brief below.
Do NOT modify any files. This is a read-only review.

${BRIEF_CONTENT}

INSTRUCTIONS:
1. Read all files listed in the brief.
2. Analyze according to the focus area specified.
3. For each finding include: severity (critical|major|minor), file:line,
   description, and suggested fix.
4. Write your findings to: ${ARTIFACT_DIR}/review.md
   Use this structure:
   # Code Review
   ## Critical
   ## Major
   ## Minor
   Each finding: **file:line** — description. Fix: suggestion.
5. If no issues found, write review.md with 'No issues found.'
6. Do NOT write status.json — the wrapper handles that."

# ── Run codex in read-only mode with timeout ─────────────────────────

codex exec -C "$REPO_PATH" -c 'approval_policy="never"' "$PROMPT" \
  > "${ARTIFACT_DIR}/raw.log" 2>&1 &
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

# Clean up the watcher
kill "$WATCHER_PID" 2>/dev/null || true
wait "$WATCHER_PID" 2>/dev/null || true

# Detect timeout (SIGTERM=143, SIGKILL=137)
TIMED_OUT=0
if (( EXIT_CODE == 143 || EXIT_CODE == 137 )); then
  TIMED_OUT=1
  EXIT_CODE=124
fi

# ── Ensure review.md exists ──────────────────────────────────────────

if [[ ! -f "${ARTIFACT_DIR}/review.md" ]]; then
  if (( TIMED_OUT )); then
    echo "# Review — Timed Out
Codex review timed out after ${TIMEOUT} seconds." > "${ARTIFACT_DIR}/review.md"
  elif (( EXIT_CODE != 0 )); then
    echo "# Review — Failed
Codex review exited with code ${EXIT_CODE}." > "${ARTIFACT_DIR}/review.md"
  else
    echo "# Review
No output produced by Codex." > "${ARTIFACT_DIR}/review.md"
  fi
fi

# ── Count findings from review.md ────────────────────────────────────

# Count severity markers as a proxy for finding count
FINDING_COUNT=$(grep -cE '^\*\*[^*]+:[0-9]+\*\*' "${ARTIFACT_DIR}/review.md" 2>/dev/null || echo 0)

# ── Determine pass/fail ──────────────────────────────────────────────

PASS=true
BLOCKING_ISSUES="[]"

if (( EXIT_CODE != 0 )); then
  PASS=false
  if (( TIMED_OUT )); then
    BLOCKING_ISSUES="[\"Codex review timed out after ${TIMEOUT}s\"]"
  else
    BLOCKING_ISSUES="[\"Codex review exited with code ${EXIT_CODE}\"]"
  fi
elif (( FINDING_COUNT > 0 )); then
  # Check if any critical findings exist
  CRITICAL_COUNT=$(grep -ci '## critical' "${ARTIFACT_DIR}/review.md" 2>/dev/null || echo 0)
  if (( CRITICAL_COUNT > 0 )); then
    PASS=false
    BLOCKING_ISSUES="[\"${FINDING_COUNT} findings including critical issues\"]"
  fi
fi

# ── Write status.json ────────────────────────────────────────────────

cat > "${ARTIFACT_DIR}/status.json" <<EOF
{
  "pass": ${PASS},
  "finding_count": ${FINDING_COUNT},
  "agent": "codex-reviewer",
  "task_type": "review",
  "blocking_issues": ${BLOCKING_ISSUES},
  "exit_code": ${EXIT_CODE},
  "timed_out": $( (( TIMED_OUT )) && echo true || echo false ),
  "generated_by": "wrapper"
}
EOF

# ── Final output ─────────────────────────────────────────────────────

echo "DONE review=codex pass=${PASS} findings=${FINDING_COUNT} artifacts=${ARTIFACT_DIR}/"
