---
name: verify
description: Run project verification (tests, lint, typecheck, build). Supports modes: quick, full (default), pre-commit, pre-pr
---

# Verify Project

Run the project's verification commands and report results.

## Mode Parsing

Parse `$ARGUMENTS` to detect the requested mode. Valid modes:
- `quick` — build + typecheck only (fast feedback)
- `full` — all checks (default, current behavior)
- `pre-commit` — lint + typecheck + test (skip build)
- `pre-pr` — full + security scan (gitleaks detect) + coverage check (if available)

```bash
MODE="${ARGUMENTS:-full}"

case "$MODE" in
  quick|full|pre-commit|pre-pr)
    echo "=== Verify mode: $MODE ==="
    ;;
  "")
    MODE="full"
    echo "=== Verify mode: full (default) ==="
    ;;
  *)
    echo "Unknown mode: $MODE — valid modes: quick, full, pre-commit, pre-pr"
    exit 1
    ;;
esac
```

## Process

1. **Detect project type and find verification commands**

   Check in order:
   - `.claude/verify.sh` (custom verification script — bypasses mode logic)
   - `package.json` scripts: `test`, `lint`, `typecheck`, `check`, `build`
   - `Makefile` targets: `test`, `lint`, `check`
   - `pyproject.toml` or `setup.py`: pytest
   - `Cargo.toml`: cargo test, cargo clippy
   - `go.mod`: go test, go vet

2. **Run checks for the selected mode**

   ```bash
   # If .claude/verify.sh exists, delegate entirely (ignores mode)
   if [ -f .claude/verify.sh ]; then
     echo "Running custom verification (ignores mode)..."
     bash .claude/verify.sh
     exit $?
   fi

   FAILED=0

   # Helper flags derived from mode
   RUN_LINT=false
   RUN_TYPECHECK=false
   RUN_TEST=false
   RUN_BUILD=false
   RUN_SECURITY=false
   RUN_COVERAGE=false

   case "$MODE" in
     quick)
       RUN_BUILD=true
       RUN_TYPECHECK=true
       ;;
     full)
       RUN_LINT=true
       RUN_TYPECHECK=true
       RUN_TEST=true
       RUN_BUILD=true
       ;;
     pre-commit)
       RUN_LINT=true
       RUN_TYPECHECK=true
       RUN_TEST=true
       ;;
     pre-pr)
       RUN_LINT=true
       RUN_TYPECHECK=true
       RUN_TEST=true
       RUN_BUILD=true
       RUN_SECURITY=true
       RUN_COVERAGE=true
       ;;
   esac

   # Node.js projects
   if [ -f package.json ]; then
     if $RUN_LINT && grep -q '"lint"' package.json; then
       echo "=== Running lint ==="
       npm run lint || FAILED=1
     fi
     if $RUN_TYPECHECK && grep -q '"typecheck"' package.json; then
       echo "=== Running typecheck ==="
       npm run typecheck || FAILED=1
     fi
     if $RUN_TEST && grep -q '"test"' package.json; then
       echo "=== Running tests ==="
       npm test || FAILED=1
     fi
     if $RUN_BUILD && grep -q '"build"' package.json; then
       echo "=== Running build ==="
       npm run build || FAILED=1
     fi
     if $RUN_COVERAGE && grep -q '"coverage"' package.json; then
       echo "=== Running coverage ==="
       npm run coverage || true  # non-blocking if missing
     fi
   fi

   # Python projects
   if [ -f pyproject.toml ] || [ -f setup.py ] || [ -f pytest.ini ]; then
     if $RUN_LINT; then
       if command -v ruff &>/dev/null; then
         echo "=== Running ruff lint ==="
         ruff check . || FAILED=1
       fi
     fi
     if $RUN_TYPECHECK; then
       if command -v pyright &>/dev/null; then
         echo "=== Running pyright ==="
         pyright || FAILED=1
       fi
     fi
     if $RUN_TEST; then
       echo "=== Running pytest ==="
       pytest || FAILED=1
     fi
   fi

   # Rust projects
   if [ -f Cargo.toml ]; then
     if $RUN_LINT; then
       echo "=== Running cargo clippy ==="
       cargo clippy -- -D warnings || FAILED=1
     fi
     if $RUN_TEST; then
       echo "=== Running cargo test ==="
       cargo test || FAILED=1
     fi
     if $RUN_BUILD; then
       echo "=== Running cargo build ==="
       cargo build || FAILED=1
     fi
   fi

   # Go projects
   if [ -f go.mod ]; then
     if $RUN_LINT; then
       echo "=== Running go vet ==="
       go vet ./... || FAILED=1
     fi
     if $RUN_TEST; then
       echo "=== Running go test ==="
       go test ./... || FAILED=1
     fi
     if $RUN_BUILD; then
       echo "=== Running go build ==="
       go build ./... || FAILED=1
     fi
   fi

   # Security scan (pre-pr only)
   if $RUN_SECURITY; then
     if command -v gitleaks &>/dev/null; then
       echo "=== Running gitleaks detect ==="
       gitleaks detect --source . --no-git 2>/dev/null || FAILED=1
     else
       echo "WARNING: gitleaks not installed — skipping security scan"
     fi
   fi

   exit $FAILED
   ```

3. **Report results**

   If all verifications pass:
   ```
   ✅ VERIFICATION PASSED (mode: $MODE)
   - lint: ✓
   - typecheck: ✓
   - test: ✓
   - build: ✓
   ```

   If any fail:
   ```
   ❌ VERIFICATION FAILED (mode: $MODE)
   - lint: ✓
   - typecheck: ✓
   - test: ✗ (3 failures)
   - build: ✓

   Fix the failing checks before proceeding.
   ```

## Mode Summary

| Mode | lint | typecheck | test | build | security | coverage |
|------|------|-----------|------|-------|----------|----------|
| `quick` | | ✓ | | ✓ | | |
| `full` | ✓ | ✓ | ✓ | ✓ | | |
| `pre-commit` | ✓ | ✓ | ✓ | | | |
| `pre-pr` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

## Custom Verification

Projects can define `.claude/verify.sh` for custom verification (mode is ignored when this file exists):

```bash
#!/bin/bash
# .claude/verify.sh - Custom project verification
set -e  # Exit on first failure

echo "Running custom verification..."

# Add your verification commands here
npm run lint
npm run typecheck
npm test
npm run build

echo "✅ All checks passed"
```

## Notes

- Verification is REQUIRED before `/done` can complete
- For projects without tests, create a minimal `.claude/verify.sh` that at least checks build
- Empty verification (no commands found) counts as PASS with a warning
- `pre-pr` security scan requires `gitleaks` — install via `brew install gitleaks` or package manager
