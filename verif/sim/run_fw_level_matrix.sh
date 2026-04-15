#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SW_BUILD_DIR="$ROOT_DIR/sw/build"
LOG_DIR="$ROOT_DIR/sim/logs"
mkdir -p "$LOG_DIR"

LEVEL="${1:-all}"     # easy | medium | hard | all
MODE="${2:-batch}"    # batch | gui
SIM_TIME_PS="${SIM_TIME_PS:-10000000000000}"

if [[ "$MODE" != "batch" && "$MODE" != "gui" ]]; then
  echo "[ERROR] MODE must be: batch | gui"
  exit 1
fi

easy_tests=(
  test_lvl_easy_uart_hello
  test_lvl_easy_gpio_basic
  test_lvl_easy_mem_smoke
)

medium_tests=(
  test_lvl_medium_memmap_probe
  test_lvl_medium_uart_pattern
  test_lvl_medium_gpio_irq_cfg
  test_lvl_medium_spi_i2c_cfg
  test_lvl_medium_interleave_rw
)

hard_tests=(
  test_lvl_hard_idma_multi_copy
  test_lvl_hard_spm_dram_march_mix
  test_lvl_hard_longrun_protocol_mix
  test_lvl_hard_periph_stress_matrix
  test_lvl_hard_recovery_resilience
)

select_tests() {
  case "$LEVEL" in
    easy) selected=("${easy_tests[@]}") ;;
    medium) selected=("${medium_tests[@]}") ;;
    hard) selected=("${hard_tests[@]}") ;;
    all) selected=("${easy_tests[@]}" "${medium_tests[@]}" "${hard_tests[@]}") ;;
    *)
      echo "[ERROR] LEVEL must be: easy | medium | hard | all"
      exit 1
      ;;
  esac
}

ensure_words_files() {
  local missing=0
  for t in "${selected[@]}"; do
    if [[ ! -f "$SW_BUILD_DIR/${t}.words" ]]; then
      missing=1
      break
    fi
  done

  if [[ "$missing" -eq 1 ]]; then
    echo "[INFO] Missing .words artifacts, building all firmware tests"
    make -C "$ROOT_DIR/sw" all
  fi
}

run_one() {
  local t="$1"
  local cmd="sim"
  if [[ "$MODE" == "gui" ]]; then
    cmd="sim_gui"
  fi

  echo "============================================================"
  echo "[RUN] $t (level=$LEVEL mode=$MODE)"
  echo "============================================================"

  make -C "$ROOT_DIR" "$cmd" TEST=chs_sw_external_test \
    SIM_TIME="$SIM_TIME_PS" \
    VERBOSITY=UVM_MEDIUM \
    PLUSARGS="+SW_WORDS_FILE=../sw/build/${t}.words +SW_TEST_NAME=${t} +SW_TIMEOUT_CYCLES=700000" \
    | tee "$LOG_DIR/${t}.level_${LEVEL}.${MODE}.log"
}

select_tests
ensure_words_files

for t in "${selected[@]}"; do
  run_one "$t"
done

echo "[DONE] Level matrix run finished. Logs: $LOG_DIR"
