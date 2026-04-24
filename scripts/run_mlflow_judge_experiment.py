import os
import sys

import mlflow
import pandas as pd
from openai import OpenAI

from mlflow.metrics.genai import EvaluationExample, make_genai_metric


def generate_predictions(
    client: OpenAI, model: str, questions: list[str], max_tokens: int = 96
) -> list[str]:
    predictions: list[str] = []
    for question in questions:
        completion = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": "Answer briefly and factually."},
                {"role": "user", "content": question},
            ],
            temperature=0.0,
            max_tokens=max_tokens,
        )
        predictions.append((completion.choices[0].message.content or "").strip())
    return predictions


def main() -> int:
    base_url = os.getenv("VLLM_BASE_URL", "http://localhost:8000/v1").rstrip("/")
    api_key = os.getenv("VLLM_API_KEY", "local-dev-key")
    model_name = os.getenv("VLLM_MODEL", "facebook/opt-1.3b")
    tracking_uri = os.getenv("MLFLOW_TRACKING_URI", "file:./mlruns")
    experiment_name = os.getenv("MLFLOW_EXPERIMENT_NAME", "vllm_llm_judge_homework")

    # MLflow GenAI metrics use OpenAI provider-style model URI.
    # For local vLLM OpenAI-compatible endpoint, expose matching env vars.
    os.environ.setdefault("OPENAI_API_KEY", api_key)
    os.environ["OPENAI_API_BASE"] = base_url
    os.environ["OPENAI_BASE_URL"] = base_url

    client = OpenAI(base_url=base_url, api_key=api_key)

    questions = [
        "What is the capital of Germany?",
        "What is 2 + 2?",
        "Name the largest planet in our solar system.",
    ]
    targets = [
        "Berlin.",
        "4.",
        "Jupiter.",
    ]

    try:
        predictions = generate_predictions(client=client, model=model_name, questions=questions)
    except Exception as exc:  # noqa: BLE001
        print(f"[ERROR] Failed to generate predictions from vLLM: {exc}")
        return 1

    df = pd.DataFrame(
        {
            "inputs": questions,
            "predictions": predictions,
            "targets": targets,
        }
    )

    example = EvaluationExample(
        input="What is 2 + 2?",
        output="The answer is 4.",
        score=5,
        justification="Output exactly matches the target and is factually correct.",
        grading_context={"targets": "4."},
    )

    correctness_metric = make_genai_metric(
        name="local_answer_correctness",
        definition=(
            "Measures factual correctness of the model output compared to provided target."
        ),
        grading_prompt=(
            "Score the answer correctness from 1 to 5.\n"
            "- Score 1: Completely wrong or contradictory to target.\n"
            "- Score 2: Mostly wrong with a small relevant fragment.\n"
            "- Score 3: Partially correct but has major issues.\n"
            "- Score 4: Mostly correct with minor issues.\n"
            "- Score 5: Fully correct and aligned with target."
        ),
        examples=[example],
        model=f"openai:/{model_name}",
        grading_context_columns=["targets"],
        parameters={"temperature": 0.0, "max_tokens": 256},
        aggregations=["mean", "variance", "p90"],
        greater_is_better=True,
    )

    mlflow.set_tracking_uri(tracking_uri)
    mlflow.set_experiment(experiment_name)

    with mlflow.start_run(run_name="vllm_custom_judge_metric") as run:
        mlflow.log_param("vllm_base_url", base_url)
        mlflow.log_param("vllm_model", model_name)
        mlflow.log_table(df, "predictions.json")

        try:
            result = mlflow.evaluate(
                data=df,
                model_type="question-answering",
                predictions="predictions",
                targets="targets",
                extra_metrics=[correctness_metric],
            )
        except Exception as exc:  # noqa: BLE001
            print(f"[ERROR] mlflow.evaluate failed: {exc}")
            print(
                "[HINT] Ensure MLflow can reach vLLM and that VLLM_BASE_URL includes /v1."
            )
            return 1

        print("=== MLflow evaluation completed ===")
        print(f"Run ID: {run.info.run_id}")
        print("Metrics:")
        for key, value in sorted(result.metrics.items()):
            print(f"  {key}: {value}")
        print(f"Tracking URI: {tracking_uri}")
        return 0


if __name__ == "__main__":
    sys.exit(main())
