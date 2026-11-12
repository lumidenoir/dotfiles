#!/usr/bin/env python3
"""
Minimo Brain Suite - Rigorous Router Evaluation Harness
Evaluates frozen held-out test sets with:
1. Action Precision + 95% Wilson Score CI
2. Action Recall + 95% Wilson Score CI
3. Safe Fallthrough Rate on Hard Negatives / OOD
4. Top-1 Raw Accuracy across all classes
5. Full Per-Intent Confusion Matrix
6. Latency Percentiles (p50, p90, p95)
"""

import os
import sys
import json
import time
import math
from typing import Dict, Any, List

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from core.semantic_router import route_intent_semantic, get_semantic_router

DEFAULT_BENCHMARK_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "../data/intent_test_frozen.jsonl"))
ACTION_INTENTS = {"add_task", "play_music", "play_media", "mpris_control", "run_cmd"}

def wilson_score_interval(k: int, n: int, confidence: float = 0.95):
    if n == 0:
        return (0.0, 0.0)
    z = 1.95996
    p = k / n
    denom = 1 + z**2 / n
    center = (p + z**2 / (2 * n)) / denom
    spread = z * math.sqrt((p * (1 - p) + z**2 / (4 * n)) / n) / denom
    return (max(0.0, center - spread), min(1.0, center + spread))

def run_evaluation(benchmark_file: str = None):
    bench_path = benchmark_file or (sys.argv[1] if len(sys.argv) > 1 else DEFAULT_BENCHMARK_PATH)
    if not os.path.exists(bench_path):
        print(f"Error: Benchmark file not found at {bench_path}")
        sys.exit(1)

    with open(bench_path, "r", encoding="utf-8") as f:
        samples = [json.loads(line.strip()) for line in f if line.strip()]

    print(f"\n================================================================================")
    print(f" 🚀 MINIMO RIGOROUS EVALUATION: {len(samples)} Frozen Held-Out Test Queries")
    print(f" Source: {os.path.basename(bench_path)}")
    print(f"================================================================================\n")

    # Warm-up
    get_semantic_router()
    route_intent_semantic("warm up router query")

    total = len(samples)
    correct_top1 = 0

    action_triggered = 0
    action_true_positives = 0
    action_false_positives = 0
    expected_actions_total = 0

    safe_fallthroughs = 0
    non_action_total = 0

    latencies = []
    failures = []
    confusion_matrix: Dict[str, Dict[str, int]] = {}

    for i, s in enumerate(samples):
        query = s["query"]
        expected = s["expected_intent"]
        is_action_expected = s.get("is_action", False)
        if is_action_expected:
            expected_actions_total += 1
        else:
            non_action_total += 1

        t0 = time.perf_counter()
        res = route_intent_semantic(query)
        elapsed_ms = (time.perf_counter() - t0) * 1000.0
        latencies.append(elapsed_ms)

        predicted = res.get("intent")
        confidence = res.get("confidence", 0.0)

        # Track confusion matrix
        confusion_matrix.setdefault(expected, {}).setdefault(predicted, 0)
        confusion_matrix[expected][predicted] += 1

        is_action_predicted = predicted in ACTION_INTENTS
        if is_action_predicted:
            action_triggered += 1
            if predicted == expected and is_action_expected:
                action_true_positives += 1
            else:
                action_false_positives += 1

        if not is_action_expected and not is_action_predicted:
            safe_fallthroughs += 1

        # Correctness
        is_correct = (predicted == expected)
        # For non-action general inquiries, rag_knowledge or chat is acceptable
        if not is_correct and expected in ("rag_knowledge", "chat") and predicted in ("rag_knowledge", "chat"):
            is_correct = True

        if is_correct:
            correct_top1 += 1
        else:
            failures.append({
                "query": query,
                "expected": expected,
                "predicted": predicted,
                "confidence": confidence,
                "latency_ms": elapsed_ms
            })

    top1_accuracy = (correct_top1 / total) * 100.0

    # Action metrics
    prec = (action_true_positives / action_triggered * 100.0) if action_triggered > 0 else 100.0
    prec_low, prec_high = wilson_score_interval(action_true_positives, action_triggered) if action_triggered > 0 else (1.0, 1.0)

    recall = (action_true_positives / expected_actions_total * 100.0) if expected_actions_total > 0 else 100.0
    rec_low, rec_high = wilson_score_interval(action_true_positives, expected_actions_total) if expected_actions_total > 0 else (1.0, 1.0)

    safe_rate = (safe_fallthroughs / non_action_total * 100.0) if non_action_total > 0 else 100.0

    # Latencies
    latencies.sort()
    p50 = latencies[int(total * 0.50)]
    p90 = latencies[int(total * 0.90)]
    p95 = latencies[int(total * 0.95)]
    avg_latency = sum(latencies) / total if total else 0.0

    print("📊 BENCHMARK METRICS BREAKDOWN:")
    print("--------------------------------------------------------------------------------")
    print(f"  • Total Test Samples Evaluated : {total}")
    print(f"  • Top-1 Raw Accuracy           : {top1_accuracy:.2f}% ({correct_top1}/{total})")
    print(f"  • Action Precision             : {prec:.2f}% ({action_true_positives}/{action_triggered})")
    print(f"    └─ 95% Confidence Interval   : [{prec_low*100:.1f}%, {prec_high*100:.1f}%]")
    print(f"  • Action Recall                : {recall:.2f}% ({action_true_positives}/{expected_actions_total})")
    print(f"    └─ 95% Confidence Interval   : [{rec_low*100:.1f}%, {rec_high*100:.1f}%]")
    print(f"  • Safe Fallthrough Rate (OOD)  : {safe_rate:.2f}% ({safe_fallthroughs}/{non_action_total})")
    print(f"  • Action False Positives       : {action_false_positives}")
    print("--------------------------------------------------------------------------------")
    print("⚡ LATENCY PROFILE:")
    print(f"  • p50 (Median) : {p50:.2f} ms")
    print(f"  • p90          : {p90:.2f} ms")
    print(f"  • p95          : {p95:.2f} ms")
    print(f"  • Average      : {avg_latency:.2f} ms")
    print("--------------------------------------------------------------------------------\n")

    print("🔲 CONFUSION MATRIX (Expected Rows -> Predicted Columns):")
    all_intents = sorted(list(set(list(confusion_matrix.keys()) + [c for r in confusion_matrix.values() for c in r.keys()])))
    hdr = f"{'Expected':<16} | " + " ".join([f"{i[:4]:>4}" for i in all_intents])
    print(hdr)
    print("-" * len(hdr))
    for exp in all_intents:
        if exp not in confusion_matrix:
            continue
        row = confusion_matrix[exp]
        vals = [f"{row.get(pred, 0):4d}" for pred in all_intents]
        print(f"{exp:<16} | " + " ".join(vals))
    print()

    if failures:
        print(f"❌ MISROUTES / EDGE CASES ({len(failures)}):")
        for f in failures:
            print(f"  [Q]: \"{f['query']}\"")
            print(f"       Expected: {f['expected']:15} | Predicted: {f['predicted']:15} (conf: {f['confidence']:.2f})")
            print()
    else:
        print("🎉 ZERO MISROUTES ON FROZEN TEST SET!\n")

if __name__ == "__main__":
    run_evaluation()
