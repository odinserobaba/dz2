import os
import sys

from openai import OpenAI


def main() -> int:
    base_url = os.getenv("VLLM_BASE_URL", "http://localhost:8000/v1").rstrip("/")
    model = os.getenv("VLLM_MODEL", "facebook/opt-1.3b")
    api_key = os.getenv("VLLM_API_KEY", "local-dev-key")

    client = OpenAI(base_url=base_url, api_key=api_key)

    try:
        completion = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": "You are a helpful assistant."},
                {"role": "user", "content": "What is the capital of Germany?"},
            ],
            temperature=0.0,
            max_tokens=16,
        )
    except Exception as exc:  # noqa: BLE001
        print(f"[ERROR] Failed to call OpenAI-compatible endpoint: {exc}")
        print(f"[HINT] Check vLLM server URL: {base_url}")
        return 1

    answer = completion.choices[0].message.content

    print("=== openai SDK -> vLLM ===")
    print(f"Model: {model}")
    print(f"Question: What is the capital of Germany?")
    print(f"Answer: {answer}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
