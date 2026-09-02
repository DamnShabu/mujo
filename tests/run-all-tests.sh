#!/usr/bin/env bash
# Consolidated Mujo Security Test Runner
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

echo "================================================="
echo "       MUJO 2.0 SECURITY TEST HARNESS           "
echo "================================================="

FAILED_TESTS=0

run_test() {
  local test_script="$1"
  echo ""
  if bash "$test_script"; then
    echo ">>> STATUS: PASS ($test_script)"
  else
    echo ">>> STATUS: FAIL ($test_script)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
}

run_test "$SCRIPT_DIR/security/test-kernel-hardening.sh"
run_test "$SCRIPT_DIR/storage/test-vault-isolation.sh"
run_test "$SCRIPT_DIR/storage/test-swap-leakage.sh"
run_test "$SCRIPT_DIR/network/test-firewall-rules.sh"
run_test "$SCRIPT_DIR/sandbox/test-sandbox-isolation.sh"
run_test "$SCRIPT_DIR/microvm/test-quarantine-boundary.sh"
run_test "$SCRIPT_DIR/trust/test-trust-engine.sh"
run_test "$SCRIPT_DIR/physical/test-physical-extraction.sh"
run_test "$SCRIPT_DIR/recovery/test-recovery-bypass.sh"
run_test "$SCRIPT_DIR/redteam/test-boundary-violations.sh"
run_test "$SCRIPT_DIR/performance/test-performance-budget.sh"

echo ""
echo "================================================="
if [ "$FAILED_TESTS" -eq 0 ]; then
  echo "  ALL SECURITY ACCEPTANCE TESTS PASSED (0 failures) "
  echo "================================================="
  exit 0
else
  echo "  SECURITY TESTS COMPLETED WITH $FAILED_TESTS FAILURES "
  echo "================================================="
  exit 1
fi
