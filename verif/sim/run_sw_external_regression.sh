#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SW_BUILD_DIR="$ROOT_DIR/sw/build"
LOG_DIR="$ROOT_DIR/sim/logs"
mkdir -p "$LOG_DIR"

if ! command -v vsim >/dev/null 2>&1; then
  echo "[WARN] vsim not found in PATH. Run this script on your QuestaSim server."
fi

mapfile -t words_files < <(ls -1 "$SW_BUILD_DIR"/*.words 2>/dev/null | sort)
if [[ ${#words_files[@]} -eq 0 ]]; then
  echo "[ERROR] No .words files found under $SW_BUILD_DIR"
  echo "        Run: cd $ROOT_DIR/sw && make all"
  exit 1
fi

echo "[INFO] Found ${#words_files[@]} SW images"

pushd "$ROOT_DIR" >/dev/null
for wf in "${words_files[@]}"; do
  test_name="$(basename "$wf" .words)"
  echo "============================================================"
  echo "[RUN] $test_name"
  echo "============================================================"

  make sim TEST=chs_sw_external_test \
    VERBOSITY=UVM_MEDIUM \
    PLUSARGS="+SW_WORDS_FILE=../sw/build/${test_name}.words +SW_TEST_NAME=${test_name} +SW_TIMEOUT_CYCLES=500000" \
    | tee "$LOG_DIR/${test_name}.sw_external.log"
done
popd >/dev/null

echo "[DONE] SW external regression complete. Logs: $LOG_DIR"
