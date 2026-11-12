#!/usr/bin/env python3
"""
tools/stress_test_negatives.py
Large-Scale Real Negative Stress Test for Minimo Brain.
Extracts 1,000 real natural language headings and sentences from the user's
actual indexed library (9,228 chunks across books, notes, and documents in library_rag.db).
Asserts that ZERO of them fire an action intent (add_task, play_music, play_media, mpris_control, run_cmd).
Reports:
1. False Positive Rate on real out-of-distribution traffic
2. 95% Wilson Score Confidence Interval
3. Pure Tier 1 Latency distribution (p50, p90, p99)
"""

import os
import sys
import time
import math
import sqlite3
import re
from typing import List, Dict, Any

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from core.semantic_router import route_intent_semantic, get_semantic_router

DB_PATH = os.path.expanduser("~/.local/share/quickshell/library_rag.db")
ACTION_INTENTS = {"add_task", "play_music", "play_media", "mpris_control", "run_cmd"}

def wilson_score_interval(k: int, n: int, confidence: float = 0.95):
    """Computes Wilson score interval for binomial proportion."""
    if n == 0:
        return (0.0, 0.0)
    z = 1.95996  # for 95% confidence
    p = k / n
    denominator = 1 + z**2 / n
    center = (p + z**2 / (2 * n)) / denominator
    spread = z * math.sqrt((p * (1 - p) + z**2 / (4 * n)) / n) / denominator
    return (max(0.0, center - spread), min(1.0, center + spread))

def extract_real_negative_queries(target_count: int = 1000) -> List[str]:
    if not os.path.exists(DB_PATH):
        print(f"Error: Database {DB_PATH} not found.")
        sys.exit(1)

    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("SELECT content FROM doc_chunks WHERE length(content) > 30")
    rows = c.fetchall()

    extracted = []
    seen = set()

    for (content,) in rows:
        lines = content.split("\n")
        for line in lines:
            # Strip markdown and bullet noise
            line = line.strip("#* -_=|/0123456789. \t")
            words = line.split()
            if 4 <= len(words) <= 16:
                clean = re.sub(r'[\r\n\t]+', ' ', line).strip()
                # Must start with letter and avoid raw code tokens
                if clean and clean[0].isalpha() and clean not in seen:
                    if not any(ch in clean for ch in "<>{}\\[]()$!#"):
                        extracted.append(clean)
                        seen.add(clean)
                        if len(extracted) >= target_count:
                            break
        if len(extracted) >= target_count:
            break

    return extracted

def run_stress_test(sample_count: int = 1000):
    print(f"\n================================================================================")
    print(f" 🛡️ REAL-WORLD NEGATIVE STRESS TEST: Mining {sample_count} Real Chunks from Library")
    print(f"================================================================================\n")

    queries = extract_real_negative_queries(sample_count)
    total = len(queries)
    print(f"Extracted {total} unique natural language queries from indexed textbooks & org notes.")

    # Warm-up ONNX model
    r = get_semantic_router()
    route_intent_semantic("warm up router query")

    spurious_actions = []
    latencies = []

    t_start = time.perf_counter()
    for i, q in enumerate(queries):
        t0 = time.perf_counter()
        res = route_intent_semantic(q)
        t_el = (time.perf_counter() - t0) * 1000.0
        latencies.append(t_el)

        intent = res.get("intent")
        if intent in ACTION_INTENTS:
            spurious_actions.append({
                "query": q,
                "triggered_intent": intent,
                "confidence": res.get("confidence", 0.0),
                "payload": res
            })

    total_time = time.perf_counter() - t_start

    # Latency percentiles
    latencies.sort()
    p50 = latencies[int(total * 0.50)]
    p90 = latencies[int(total * 0.90)]
    p95 = latencies[int(total * 0.95)]
    p99 = latencies[int(total * 0.99)]
    avg_latency = sum(latencies) / total if total else 0.0

    k = len(spurious_actions)
    fpr = (k / total) * 100.0
    ci_low, ci_high = wilson_score_interval(k, total)

    print("📊 NEGATIVE STRESS TEST RESULTS:")
    print("--------------------------------------------------------------------------------")
    print(f"  • Real Document Queries Evaluated : {total}")
    print(f"  • Spurious Actions Triggered      : {k} (Target: 0)")
    print(f"  • False Positive Action Rate (FPR): {fpr:.3f}%")
    print(f"  • 95% Confidence Interval for FPR : [{ci_low*100:.3f}%, {ci_high*100:.3f}%]")
    print(f"  • Fallthrough Safety Rate         : {((total - k) / total * 100):.2f}%")
    print("--------------------------------------------------------------------------------")
    print("⚡ ROUTING LATENCY PROFILE:")
    print(f"  • Average Latency : {avg_latency:.2f} ms")
    print(f"  • p50 (Median)    : {p50:.2f} ms")
    print(f"  • p90             : {p90:.2f} ms")
    print(f"  • p95             : {p95:.2f} ms")
    print(f"  • p99             : {p99:.2f} ms")
    print(f"  • Throughput      : {total / total_time:.1f} queries / sec")
    print("--------------------------------------------------------------------------------\n")

    if spurious_actions:
        print(f"❌ SPURIOUS ACTIONS DETECTED ({len(spurious_actions)}):")
        for sa in spurious_actions[:10]:
            print(f"  [TRIGGERED: {sa['triggered_intent']:15}] \"{sa['query']}\"")
        if len(spurious_actions) > 10:
            print(f"  ... and {len(spurious_actions) - 10} more.")
        print()
        sys.exit(1)
    else:
        print(f"🎉 ZERO FALSE POSITIVE ACTIONS ON {total} REAL LIBRARY HEADINGS! (100% Safe Fallthrough)\n")

if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    run_stress_test(n)
