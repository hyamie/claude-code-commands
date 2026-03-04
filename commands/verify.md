---
name: verify
description: Run project verification (tests, lint, typecheck, build)
---

# Verify Project

Run the project's verification commands and report results.

## Process

1. **Detect project type and find verification commands**

   Check in order:
   - `.claude/verify.sh` (custom verification script)
   - `package.json` scripts: `test`, `lint`, `typecheck`, `check`, `build`
   - `Makefile` targets: `test`, `lint`, `check`
   - `pyproject.toml` or `setup.py`: pytest
   - `Cargo.toml`: cargo test, cargo clippy
   - `go.mod`: go test, go vet

2. **Run available verification commands**

   ```bash
   # If .claude/verify.sh exists, use it
   if [ -f .claude/verify.sh ]; then
     echo "Running custom verification..."
     bash .claude/verify.sh
     exit $?
   fi

   # Otherwise, detect and run standard commands
   FAILED=0

   # Node.js projects
   if [ -f package.json ]; then
     if grep -q '"lint"' package.json; then
       echo "=== Running lint ==="
       npm run lint || FAILED=1
     fi
     if grep -q '"typecheck"' package.json; then
       echo "=== Running typecheck ==="
       npm run typecheck || FAILED=1
     fi
     if grep -q '"test"' package.json; then
       echo "=== Running tests ==="
       npm test || FAILED=1
     fi
     if grep -q '"build"' package.json; then
       echo "=== Running build ==="
       npm run build || FAILED=1
     fi
   fi

   # Python projects
   if [ -f pyproject.toml ] || [ -f setup.py ] || [ -f pytest.ini ]; then
     echo "=== Running pytest ==="
     pytest || FAILED=1
   fi

   # Rust projects
   if [ -f Cargo.toml ]; then
     echo "=== Running cargo test ==="
     cargo test || FAILED=1
     echo "=== Running cargo clippy ==="
     cargo clippy -- -D warnings || FAILED=1
   fi

   # Go projects
   if [ -f go.mod ]; then
     echo "=== Running go test ==="
     go test ./... || FAILED=1
     echo "=== Running go vet ==="
     go vet ./... || FAILED=1
   fi

   exit $FAILED
   ```

3. **Report results**

   If all verifications pass:
   ```
   ✅ VERIFICATION PASSED
   - lint: ✓
   - typecheck: ✓
   - test: ✓
   - build: ✓
   ```

   If any fail:
   ```
   ❌ VERIFICATION FAILED
   - lint: ✓
   - typecheck: ✓
   - test: ✗ (3 failures)
   - build: ✓

   Fix the failing checks before proceeding.
   ```

## Custom Verification

Projects can define `.claude/verify.sh` for custom verification:

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
