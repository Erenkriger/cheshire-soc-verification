#!/usr/bin/env bash
set -euo pipefail

# Extract an explainable "who talks to whom" story from a UVM GUI transcript log.
#
# Usage:
#   bash verif/sim/extract_sw_story.sh verif/sim/logs/test_lvl_easy_uart_hello.gui.log
#   bash verif/sim/extract_sw_story.sh <input.log> <output.story.txt>

IN_LOG="${1:-}"
OUT_TXT="${2:-}"

if [[ -z "$IN_LOG" ]]; then
  echo "Usage: $0 <input_log> [output_story_file]"
  exit 1
fi

if [[ ! -f "$IN_LOG" ]]; then
  echo "[ERROR] Input log not found: $IN_LOG"
  exit 1
fi

if [[ -z "$OUT_TXT" ]]; then
  OUT_TXT="${IN_LOG%.log}.story.txt"
fi

{
  echo "============================================================"
  echo "SW TEST STORY REPORT"
  echo "============================================================"
  echo "Input log: $IN_LOG"
  echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
  echo

  echo "[1] RESULT"
  grep -E "SW TEST PASSED|SW TEST FAILED|SW TEST TIMEOUT|EOC detected" "$IN_LOG" || echo "(No explicit result line found)"
  echo

  echo "[2] JTAG/DEBUG CONTROL FLOW"
  grep -E "IDCODE|DMSTATUS|ABSTRACTCS|SBA|JTAG TR" "$IN_LOG" | head -n 120 || echo "(No JTAG/DEBUG lines found)"
  echo

  echo "[3] AXI FABRIC ACTIVITY"
  grep -E "\[AXI_MON\]|AXI LLC Monitor Statistics|AW handshakes|W  handshakes|B  handshakes|AR handshakes|R  handshakes|AXI WRITE|AXI READ" "$IN_LOG" || echo "(No AXI monitor lines found)"
  echo

  echo "[4] UART / PERIPHERAL ACTIVITY"
  grep -E "SCB_UART_LINE|SCB_UART_FINAL|UART Monitor Summary|SPI Monitor Summary|I2C|GPIO" "$IN_LOG" | head -n 120 || echo "(No peripheral summary lines found)"
  echo

  echo "[5] SCOREBOARD SUMMARY"
  awk '
    /Cheshire SoC Scoreboard Summary/ {cap=1; cnt=0}
    cap {print; cnt++}
    cap && cnt>24 {cap=0}
  ' "$IN_LOG" || true
  echo

  echo "[6] COVERAGE SNAPSHOT"
  awk '
    /Functional Coverage Report/ {cap=1; cnt=0}
    cap {print; cnt++}
    cap && cnt>24 {cap=0}
  ' "$IN_LOG" || true
  echo

  echo "[7] QUICK INTERPRETATION"
  if grep -q "SW TEST PASSED" "$IN_LOG"; then
    echo "- Test verdict: PASS"
  elif grep -q "SW TEST FAILED" "$IN_LOG"; then
    echo "- Test verdict: FAIL"
  elif grep -q "SW TEST TIMEOUT" "$IN_LOG"; then
    echo "- Test verdict: TIMEOUT"
  else
    echo "- Test verdict: UNKNOWN (check raw log)"
  fi

  if grep -q "Cheshire SoC Scoreboard Summary          (no checks)" "$IN_LOG"; then
    echo "- Scoreboard mode: Traffic monitor only (no expected-vs-actual data queue consumed)."
  fi

  if grep -q "AXI LLC Monitor Statistics" "$IN_LOG"; then
    echo "- AXI activity present; use handshake counts to explain read/write balance."
  fi

  echo "- For full evidence, keep this report together with the original transcript log."
} > "$OUT_TXT"

echo "[DONE] Story report generated: $OUT_TXT"
