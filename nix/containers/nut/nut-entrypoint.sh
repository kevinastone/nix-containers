#!/usr/bin/env bash
set -euo pipefail

NUT_USER="${NUT_USER:-root}"

cleanup() {
  echo "Stopping NUT server and drivers..."
  upsd -c stop 2>/dev/null || true
  upsdrvctl stop 2>/dev/null || true
}
trap cleanup TERM INT

echo "Starting NUT drivers (user=$NUT_USER)..."
upsdrvctl -u "$NUT_USER" start

echo "Starting upsd (user=$NUT_USER)..."
upsd -u "$NUT_USER" -F &
UPSD_PID=$!
wait "$UPSD_PID"
