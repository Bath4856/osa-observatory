#!/usr/bin/env bash
# ============================================================
# OSA / ISA OBSERVATORY
# run_osa_nightly.sh — Wrapper cron production
# ============================================================

set -uo pipefail

PROJECT_DIR=$(cd "$(dirname "$0")/.." && pwd)
PYTHON_BIN=${PYTHON_BIN:-/usr/local/bin/python}
YEAR=${YEAR:-$(date +%Y)}
RUN_YEAR=${RUN_YEAR:-$((YEAR - 1))}
INCLUDE_PILOT=${INCLUDE_PILOT:-false}
AUTO_APPROVE=${AUTO_APPROVE:-false}
REQUIRE_VALIDATION=${REQUIRE_VALIDATION:-true}
EXPORT_AUDIT_CSV=${EXPORT_AUDIT_CSV:-true}
ALERT_WEBHOOK_URL=${ALERT_WEBHOOK_URL:-${OSA_ALERT_WEBHOOK_URL:-}}

LOG_DIR="$PROJECT_DIR/logs/nightly"
mkdir -p "$LOG_DIR"
TS=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/run_osa_nightly_${TS}.log"

cd "$PROJECT_DIR"

INCLUDE_PILOT_FLAG=""
AUTO_APPROVE_FLAG=""
NO_REQUIRE_VALIDATION_FLAG=""
EXPORT_AUDIT_FLAG=""
WEBHOOK_ARGS=()

if [[ "$INCLUDE_PILOT" == "true" ]]; then
  INCLUDE_PILOT_FLAG="--include-pilot"
fi

if [[ "$AUTO_APPROVE" == "true" ]]; then
  AUTO_APPROVE_FLAG="--auto-approve"
fi

if [[ "$REQUIRE_VALIDATION" != "true" ]]; then
  NO_REQUIRE_VALIDATION_FLAG="--no-require-validation"
fi

if [[ "$EXPORT_AUDIT_CSV" == "true" ]]; then
  EXPORT_AUDIT_FLAG="--export-audit-csv"
fi

if [[ -n "$ALERT_WEBHOOK_URL" ]]; then
  WEBHOOK_ARGS=(--webhook-url "$ALERT_WEBHOOK_URL")
fi

set +e
{
  echo "[OSA] start nightly run ts=$TS run_year=$RUN_YEAR"
  "$PYTHON_BIN" collectors/run_nightly_osa.py \
    --year "$RUN_YEAR" \
    --requested-by "CRON" \
    $INCLUDE_PILOT_FLAG \
    $AUTO_APPROVE_FLAG \
    $NO_REQUIRE_VALIDATION_FLAG \
    $EXPORT_AUDIT_FLAG
  echo "[OSA] done nightly run ts=$TS"
} >> "$LOG_FILE" 2>&1
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -ne 0 ]]; then
  {
    echo "[OSA] nightly failed ts=$TS exit_code=$EXIT_CODE"
    "$PYTHON_BIN" collectors/notify_pipeline_failure.py \
      --year "$RUN_YEAR" \
      --reason "run_osa_nightly.sh failed with exit code $EXIT_CODE" \
      --log-file "$LOG_FILE" \
      "${WEBHOOK_ARGS[@]}"
  } >> "$LOG_FILE" 2>&1 || true
fi

exit $EXIT_CODE
