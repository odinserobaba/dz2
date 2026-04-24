#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_FILE="${ROOT_DIR}/logs/vllm_cpu.pid"

if [[ ! -f "${PID_FILE}" ]]; then
  echo "[INFO] PID file not found: ${PID_FILE}"
  echo "[INFO] Nothing to stop."
  exit 0
fi

PID="$(cat "${PID_FILE}" || true)"
if [[ -z "${PID}" ]]; then
  echo "[WARN] PID file is empty. Removing it."
  rm -f "${PID_FILE}"
  exit 0
fi

if kill -0 "${PID}" 2>/dev/null; then
  echo "[INFO] Stopping vLLM PID ${PID}..."
  kill "${PID}"
  sleep 1
  if kill -0 "${PID}" 2>/dev/null; then
    echo "[WARN] Process still alive, sending SIGKILL..."
    kill -9 "${PID}"
  fi
  echo "[OK] Stopped."
else
  echo "[INFO] Process ${PID} is not running."
fi

rm -f "${PID_FILE}"
