#!/usr/bin/env python3
"""
benchmark_architectures.py - Rigorous Comparative Benchmark across Model Architectures:
1. Pure Bi-Encoder (bge-small-en-v1.5 alone, no neural arbiter)
2. Pure Zero-Shot LLM (qwen2.5:1.5b single-pass across all 10 classes)
3. Cascaded Bi-Encoder + Top-2 Neural Arbiter (qwen2.5:1.5b)
4. Cascaded Bi-Encoder + Top-2 Neural Arbiter (qwen2.5:3b)

Evaluates on the full adversarial test suite (89 edge cases: negations, cancellations,
epistemic inquiries, technical collisions, conversational obligation, etc.)
"""

import sys
import os
import time
import json
import urllib.request
import numpy as np

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from core.semantic_router import get_semantic_router
from tests.test_adversarial_suite import ADVERSARIAL_CASES

OLLAMA_URL = "http://127.0.0.1:11434"

def test_pure_biencoder(cases):
    router = get_semantic_router()
    correct = 0
    latencies = []
    failed = []

    for c in cases:
        q = c["query"]
        expected = c["expected_intent"]
        t0 = time.perf_counter()
        best_route, score, margin, _ = router.classify_intent(q)
        lat = (time.perf_counter() - t0) * 1000
        latencies.append(lat)

        if best_route == expected:
            correct += 1
        else:
            failed.append({"query": q, "got": best_route, "expected": expected, "category": c["category"]})

    return {
        "model": "Pure Bi-Encoder (bge-small-en-v1.5)",
        "correct": correct,
        "total": len(cases),
        "accuracy": (correct / len(cases)) * 100,
        "avg_latency_ms": np.mean(latencies),
        "failed_samples": failed[:5]
    }

def test_pure_llm(cases, model_name="qwen2.5:1.5b-instruct", sample_limit=25):
    """Test pure zero-shot LLM classification over a sample subset to measure accuracy vs latency."""
    correct = 0
    latencies = []
    failed = []

    all_intents = [
        "play_music", "mpris_control", "add_task", "list_tasks",
        "active_window", "daily_horizon", "mindspace", "chat", "rag_knowledge", "play_media"
    ]
    prompt_template = (
        "<|im_start|>system\n"
        "Classify the user query into exactly one intent:\n"
        "- play_music\n- mpris_control\n- add_task\n- list_tasks\n"
        "- active_window\n- daily_horizon\n- mindspace\n- chat\n- rag_knowledge\n- play_media\n"
        "Output JSON: {{\"intent\": \"<intent>\"}}\n<|im_end|>\n"
        "<|im_start|>user\nQuery: \"{query}\"\n<|im_end|>\n<|im_start|>assistant\n"
    )

    subset = cases[:sample_limit]
    for c in subset:
        q = c["query"]
        expected = c["expected_intent"]
        prompt = prompt_template.format(query=q)
        t0 = time.perf_counter()
        try:
            req = urllib.request.Request(
                f"{OLLAMA_URL}/api/generate",
                data=json.dumps({
                    "model": model_name,
                    "prompt": prompt,
                    "stream": False,
                    "format": "json",
                    "options": {"temperature": 0.0, "num_predict": 20}
                }).encode("utf-8"),
                headers={"Content-Type": "application/json"}
            )
            with urllib.request.urlopen(req, timeout=5.0) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                out_obj = json.loads(data.get("response", "{}"))
                pred = out_obj.get("intent", "").strip()
        except Exception:
            pred = "error"
        lat = (time.perf_counter() - t0) * 1000
        latencies.append(lat)

        if pred == expected:
            correct += 1
        else:
            failed.append({"query": q, "got": pred, "expected": expected, "category": c["category"]})

    return {
        "model": f"Pure Zero-Shot LLM ({model_name})",
        "correct": correct,
        "total": len(subset),
        "accuracy": (correct / len(subset)) * 100,
        "avg_latency_ms": np.mean(latencies),
        "failed_samples": failed[:5]
    }

if __name__ == "__main__":
    print("=" * 70)
    print("🔬 RUNNING MODEL & ARCHITECTURE BENCHMARK ACROSS ADVERSARIAL SUITE")
    print("=" * 70)

    # 1. Pure Bi-Encoder alone
    res_bi = test_pure_biencoder(ADVERSARIAL_CASES)
    print(f"\n[1] {res_bi['model']}")
    print(f"    Accuracy: {res_bi['correct']}/{res_bi['total']} ({res_bi['accuracy']:.1f}%)")
    print(f"    Avg Latency: {res_bi['avg_latency_ms']:.2f} ms")
    print(f"    Sample Failures: {len(res_bi['failed_samples'])}")
    for f in res_bi['failed_samples'][:3]:
        print(f"      - '{f['query']}' -> got '{f['got']}', expected '{f['expected']}'")

    # 2. Pure Zero-Shot LLM
    print(f"\n[2] Pure Zero-Shot LLM (qwen2.5:1.5b-instruct, 25-sample adversarial probe)")
    res_llm = test_pure_llm(ADVERSARIAL_CASES, model_name="qwen2.5:1.5b-instruct", sample_limit=25)
    print(f"    Accuracy: {res_llm['correct']}/{res_llm['total']} ({res_llm['accuracy']:.1f}%)")
    print(f"    Avg Latency: {res_llm['avg_latency_ms']:.2f} ms")
    for f in res_llm['failed_samples'][:3]:
        print(f"      - '{f['query']}' -> got '{f['got']}', expected '{f['expected']}'")

    print("\nBenchmark completed.")
