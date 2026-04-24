# Домашнее задание: трекинг LLM-инференса с vLLM

Этот репозиторий покрывает полный цикл из задания:
- поднимает локальную LLM через vLLM (OpenAI-compatible API),
- отправляет запросы к модели через `requests` и `openai`,
- запускает эксперимент в MLflow с кастомной LLM-as-a-Judge метрикой (`make_genai_metric`).

## 1) Структура проекта

- `docker-compose.yml` — запуск vLLM API сервера
- `requirements.txt` — зависимости для скриптов
- `scripts/check_vllm_requests.py` — запрос к модели через HTTP (`requests`)
- `scripts/check_vllm_openai.py` — запрос к модели через `openai` SDK
- `scripts/run_mlflow_judge_experiment.py` — MLflow эксперимент с кастомной GenAI метрикой

## 2) Быстрый старт

### Шаг 0. Требования

- Docker + Docker Compose
- Python 3.10+
- Желательно GPU (для большинства моделей). Для слабого железа выберите более лёгкую модель.

### Шаг 1. Поднимите vLLM сервер

По умолчанию используется модель `facebook/opt-1.3b` и порт `8000`.

```bash
docker compose up -d
docker compose logs -f vllm
```

Дождитесь, пока сервер станет готов принимать запросы.

### Шаг 2. Установите зависимости

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Шаг 3. Проверка запроса через requests

```bash
python scripts/check_vllm_requests.py
```

### Шаг 4. Проверка запроса через openai SDK

```bash
python scripts/check_vllm_openai.py
```

### Шаг 5. Запуск MLflow эксперимента с кастомной метрикой

```bash
python scripts/run_mlflow_judge_experiment.py
```

После запуска откройте UI:

```bash
mlflow ui --host 0.0.0.0 --port 5000
```

И перейдите на [http://localhost:5000](http://localhost:5000).

## 3) Переменные окружения

Скрипты используют следующие переменные (все опциональны):

- `VLLM_BASE_URL` (default: `http://localhost:8000/v1`)
- `VLLM_API_KEY` (default: `local-dev-key`)
- `VLLM_MODEL` (default: `facebook/opt-1.3b`)
- `MLFLOW_TRACKING_URI` (default: `file:./mlruns`)
- `MLFLOW_EXPERIMENT_NAME` (default: `vllm_llm_judge_homework`)

Пример:

```bash
export VLLM_BASE_URL="http://localhost:8000/v1"
export VLLM_MODEL="facebook/opt-1.3b"
```

## 4) Что показать в сдаче на GitHub

1. Код из этого репозитория (или аналогичный, но рабочий).
2. Скриншот/лог запуска vLLM (видно, что сервер поднят на `0.0.0.0:8000` или `localhost:8000`).
3. Скриншот ответа скрипта `check_vllm_requests.py`.
4. Скриншот ответа скрипта `check_vllm_openai.py`.
5. Скриншоты MLflow:
   - вкладка Experiments,
   - конкретный run с метриками (включая кастомную judge-метрику).

## 5) Примечания

- Если модель слишком тяжёлая для вашего железа, замените `VLLM_MODEL` на более лёгкую.
- Для некоторых моделей Hugging Face нужен токен (`HUGGING_FACE_HUB_TOKEN`).
- vLLM работает через OpenAI-compatible endpoint, поэтому URL должен включать `/v1`.
