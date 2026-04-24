#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ ! -d ".venv" ]]; then
  echo "[ERROR] .venv not found."
  echo "Create it first:"
  echo "  python3 -m venv .venv"
  echo "  source .venv/bin/activate"
  echo "  pip install -r requirements.txt vllm-cpu"
  exit 1
fi

source .venv/bin/activate

export VLLM_MODEL="${VLLM_MODEL:-distilgpt2}"
export VLLM_BASE_URL="${VLLM_BASE_URL:-http://localhost:8000/v1}"
export MLFLOW_TRACKING_URI="${MLFLOW_TRACKING_URI:-file:./mlruns}"
export MLFLOW_EXPERIMENT_NAME="${MLFLOW_EXPERIMENT_NAME:-vllm_llm_judge_homework}"

LOG_DIR="${ROOT_DIR}/logs"
mkdir -p "${LOG_DIR}"
MLFLOW_UI_LOG="${LOG_DIR}/mlflow_ui.log"
MLFLOW_UI_PID_FILE="${LOG_DIR}/mlflow_ui.pid"

echo "[STEP 1/5] Start vLLM CPU server"
"${ROOT_DIR}/scripts/start_vllm_cpu.sh"

echo "[STEP 2/5] Smoke test via requests"
python "${ROOT_DIR}/scripts/check_vllm_requests.py"

echo "[STEP 3/5] Smoke test via openai SDK"
python "${ROOT_DIR}/scripts/check_vllm_openai.py"

echo "[STEP 4/5] Run MLflow experiment with custom judge metric"
python "${ROOT_DIR}/scripts/run_mlflow_judge_experiment.py"

if [[ "${START_MLFLOW_UI:-1}" == "1" ]]; then
  echo "[STEP 5/5] Start MLflow UI in background"
  if [[ -f "${MLFLOW_UI_PID_FILE}" ]]; then
    OLD_PID="$(cat "${MLFLOW_UI_PID_FILE}" || true)"
    if [[ -n "${OLD_PID}" ]] && kill -0 "${OLD_PID}" 2>/dev/null; then
      echo "[INFO] MLflow UI already running with PID ${OLD_PID}"
      echo "[INFO] Open: http://localhost:5000"
      echo "[DONE] Pipeline completed."
      exit 0
    fi
    rm -f "${MLFLOW_UI_PID_FILE}"
  fi

  nohup mlflow ui --host 0.0.0.0 --port 5000 > "${MLFLOW_UI_LOG}" 2>&1 &
  MLFLOW_UI_PID=$!
  echo "${MLFLOW_UI_PID}" > "${MLFLOW_UI_PID_FILE}"
  echo "[OK] MLflow UI started (PID ${MLFLOW_UI_PID})"
  echo "[INFO] Open: http://localhost:5000"
  echo "[INFO] UI log: ${MLFLOW_UI_LOG}"
else
  echo "[STEP 5/5] Skip MLflow UI (START_MLFLOW_UI=0)"
fi

echo "[DONE] All homework steps finished."
echo "[INFO] When done, stop vLLM: ./scripts/stop_vllm_cpu.sh"
