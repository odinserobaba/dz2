#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ ! -d ".venv" ]]; then
  echo "[ERROR] .venv not found. Create it first:"
  echo "  python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt vllm-cpu"
  exit 1
fi

source .venv/bin/activate

MODEL="${VLLM_MODEL:-distilgpt2}"
HOST="${VLLM_HOST:-0.0.0.0}"
PORT="${VLLM_PORT:-8000}"
MAX_MODEL_LEN="${VLLM_MAX_MODEL_LEN:-256}"
MAX_NUM_SEQS="${VLLM_MAX_NUM_SEQS:-1}"
DTYPE="${VLLM_DTYPE:-float32}"
START_TIMEOUT_SEC="${VLLM_START_TIMEOUT_SEC:-300}"
CPU_KV_CACHE_GB="${VLLM_CPU_KVCACHE_SPACE:-1}"
MAX_NUM_BATCHED_TOKENS="${VLLM_MAX_NUM_BATCHED_TOKENS:-128}"

LOG_DIR="${ROOT_DIR}/logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/vllm_cpu.log"
PID_FILE="${LOG_DIR}/vllm_cpu.pid"
CHAT_TEMPLATE_FILE="${ROOT_DIR}/scripts/chat_template.jinja"

if [[ -f "${PID_FILE}" ]]; then
  OLD_PID="$(cat "${PID_FILE}" || true)"
  if [[ -n "${OLD_PID}" ]] && kill -0 "${OLD_PID}" 2>/dev/null; then
    echo "[INFO] vLLM is already running with PID ${OLD_PID}"
    echo "[INFO] Log: ${LOG_FILE}"
    exit 0
  fi
  rm -f "${PID_FILE}"
fi

echo "[INFO] Starting vLLM CPU server..."
echo "[INFO] Model: ${MODEL}"
echo "[INFO] URL: http://localhost:${PORT}/v1"
echo "[INFO] Log: ${LOG_FILE}"
echo "[INFO] CPU KV cache (GiB): ${CPU_KV_CACHE_GB}"

nohup env VLLM_CPU_KVCACHE_SPACE="${CPU_KV_CACHE_GB}" python -m vllm.entrypoints.openai.api_server \
  --model "${MODEL}" \
  --runner generate \
  --convert none \
  --chat-template "${CHAT_TEMPLATE_FILE}" \
  --host "${HOST}" \
  --port "${PORT}" \
  --max-model-len "${MAX_MODEL_LEN}" \
  --max-num-seqs "${MAX_NUM_SEQS}" \
  --max-num-batched-tokens "${MAX_NUM_BATCHED_TOKENS}" \
  --dtype "${DTYPE}" \
  --no-enable-prefix-caching \
  --enforce-eager \
  > "${LOG_FILE}" 2>&1 &

VLLM_PID=$!
echo "${VLLM_PID}" > "${PID_FILE}"

echo "[INFO] PID: ${VLLM_PID}"
echo "[INFO] Waiting for readiness..."

START_TS="$(date +%s)"
READY=0
while true; do
  if ! kill -0 "${VLLM_PID}" 2>/dev/null; then
    echo "[ERROR] vLLM process exited during startup."
    echo "[ERROR] Last log lines:"
    tail -n 40 "${LOG_FILE}" || true
    rm -f "${PID_FILE}"
    exit 1
  fi

  if curl -fsS "http://localhost:${PORT}/v1/models" >/dev/null 2>&1; then
    READY=1
    break
  fi

  NOW_TS="$(date +%s)"
  ELAPSED=$((NOW_TS - START_TS))
  if (( ELAPSED >= START_TIMEOUT_SEC )); then
    echo "[ERROR] Timeout waiting for vLLM readiness (${START_TIMEOUT_SEC}s)."
    echo "[ERROR] Last log lines:"
    tail -n 60 "${LOG_FILE}" || true
    exit 1
  fi
  sleep 2
done

if (( READY == 1 )); then
  echo "[OK] vLLM is ready: http://localhost:${PORT}/v1/models"
fi
