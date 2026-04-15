#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-compare}"  # compare | sync
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REMOTE_USER="${REMOTE_USER:-eren.kacmaz}"
REMOTE_HOST="${REMOTE_HOST:-10.40.15.21}"
REMOTE_ROOT="${REMOTE_ROOT:-/home/eren.kacmaz/SOC_UVM}"
REMOTE="${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_ROOT}/"

if [[ "$MODE" == "compare" ]]; then DRY_FLAG=("-n"); else DRY_FLAG=(); fi

COMMON_EXCLUDES=(
  "--exclude=.git/" "--exclude=.bender/" "--exclude=**/__pycache__/" "--exclude=**/*.o"
  "--exclude=**/*.a" "--exclude=**/*.so" "--exclude=**/*.wlf" "--exclude=**/*.vcd"
  "--exclude=**/*.vpd" "--exclude=**/*.fsdb" "--exclude=**/*.ucdb"
  "--exclude=cheshire/.bender/"
)

rsync -azv "${DRY_FLAG[@]}" --itemize-changes "${COMMON_EXCLUDES[@]}" "$WORKSPACE_ROOT/" "$REMOTE"
