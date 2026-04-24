import os
import sys

import requests


def main() -> int:
    base_url = os.getenv("VLLM_BASE_URL", "http://localhost:8000/v1").rstrip("/")
    model = os.getenv("VLLM_MODEL", "facebook/opt-1.3b")
    api_key = os.getenv("VLLM_API_KEY", "local-dev-key")

    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": "What is the capital of Germany?"},
        ],
        "temperature": 0.0,
        "max_tokens": 16,
    }

    url = f"{base_url}/chat/completions"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    try:
        response = requests.post(url, json=payload, headers=headers, timeout=120)
        response.raise_for_status()
    except requests.RequestException as exc:
        print(f"[ERROR] Failed to call vLLM endpoint: {exc}")
        print(f"[HINT] Check server availability: {base_url}")
        return 1

    data = response.json()
    answer = data["choices"][0]["message"]["content"]

    print("=== requests -> vLLM chat/completions ===")
    print(f"Model: {model}")
    print(f"Question: What is the capital of Germany?")
    print(f"Answer: {answer}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
