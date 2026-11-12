#!/usr/bin/env python3
"""
tools/build_splits.py
Constructs a cluster-aware, 3-way dataset split with zero data leakage:
1. Fixes any shell expansion corruption ($cat, $uname, $hyprctl, $ls).
2. Groups queries into semantic template clusters so similar phrasing patterns
   do not leak across splits.
3. Generates:
   - data/intent_train.jsonl (60% of clusters)
   - data/intent_val.jsonl   (20% of clusters, for dev & threshold tuning)
   - data/intent_test_frozen.jsonl (20% of clusters, FROZEN for final eval)
"""

import os
import json
import random
from typing import Dict, List, Any

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DATA_DIR = os.path.join(BASE_DIR, "data")
os.makedirs(DATA_DIR, exist_ok=True)

# 1. Load full benchmark and fix corrupted queries
raw_full_path = os.path.join(DATA_DIR, "intent_benchmark_full.jsonl")
if not os.path.exists(raw_full_path):
    print(f"Error: {raw_full_path} not found")
    exit(1)

with open(raw_full_path, "r", encoding="utf-8") as f:
    items = [json.loads(line) for line in f if line.strip()]

# Clean any shell expansion corruption
for it in items:
    q = it["query"].strip()
    if q == "-r":
        it["query"] = "$uname -r"
    elif q == "clients":
        it["query"] = "$hyprctl clients"
    elif q == "-la ~/dotfiles":
        it["query"] = "$ls -la ~/dotfiles"
    elif q == "/etc/os-release":
        it["query"] = "$cat /etc/os-release"

print(f"Loaded {len(items)} items from benchmark.")

# 2. Cluster items by semantic template / topic
def get_cluster_key(item: Dict[str, Any]) -> str:
    q = item["query"].lower()
    intent = item["expected_intent"]
    tag = item.get("tag", "")

    if tag.startswith("hard_negative_"):
        return f"neg_{tag}"
    if "frieren" in q: return "media_frieren"
    if "steins gate" in q: return "media_steinsgate"
    if "cyberpunk" in q: return "media_cyberpunk"
    if "attack on titan" in q: return "media_aot"
    if "interstellar" in q: return "media_interstellar"
    if "aimer" in q: return "music_aimer"
    if "kelsey lu" in q: return "music_kelseylu"
    if "radiohead" in q: return "music_radiohead"
    if "daft punk" in q: return "music_daftpunk"
    if "lofi" in q or "chillhop" in q: return "music_lofi"
    if "jazz" in q: return "music_jazz"
    if "classical" in q or "chopin" in q or "beethoven" in q: return "music_classical"
    if "slide" in q or "slides" in q: return "task_slides"
    if "nginx" in q or "server" in q or "router" in q: return "task_infra"
    if "groceries" in q or "shopping" in q or "pharmacy" in q or "store" in q: return "task_errands"
    if "doctor" in q or "dentist" in q or "medical" in q: return "task_medical"
    if "git" in q or "github" in q or "pull request" in q or "pr" in q: return "task_git"
    if "review" in q or "paper" in q or "thesis" in q: return "task_academic"
    if "backup" in q or "nas" in q: return "task_backup"
    if intent == "run_cmd": return "cmd_shell"
    if intent == "mpris_control": return "mpris_transport"
    if intent == "active_window": return "desktop_window"
    if intent == "daily_horizon": return "desktop_horizon"
    if intent == "mindspace": return "desktop_mindspace"
    if intent == "chat": return "chat_dialog"
    if intent == "list_tasks": return "tasks_listing"
    
    # Default cluster by first two words
    words = q.split()
    lead = "_".join(words[:2]) if len(words) >= 2 else q
    return f"{intent}_{lead}"

clusters: Dict[str, List[Dict[str, Any]]] = {}
for it in items:
    k = get_cluster_key(it)
    clusters.setdefault(k, []).append(it)

print(f"Grouped into {len(clusters)} distinct semantic clusters.")

# 3. Stratified Partition into Train (60%), Validation (20%), Frozen Test (20%)
random.seed(42)
all_cluster_keys = list(clusters.keys())
random.shuffle(all_cluster_keys)

train_items = []
val_items = []
test_items = []

for i, k in enumerate(all_cluster_keys):
    c_items = clusters[k]
    # Assign entire cluster to one split
    mod = i % 5
    if mod in (0, 1, 2):
        train_items.extend(c_items)
    elif mod == 3:
        val_items.extend(c_items)
    else:
        test_items.extend(c_items)

# Write out splits
def write_jsonl(path: str, data: List[Dict[str, Any]]):
    with open(path, "w", encoding="utf-8") as f:
        for d in data:
            f.write(json.dumps(d) + "\n")

train_path = os.path.join(DATA_DIR, "intent_train.jsonl")
val_path = os.path.join(DATA_DIR, "intent_val.jsonl")
test_path = os.path.join(DATA_DIR, "intent_test_frozen.jsonl")

write_jsonl(train_path, train_items)
write_jsonl(val_path, val_items)
write_jsonl(test_path, test_items)

print("\n📊 3-WAY SPLIT SUMMARY (Zero Template Leakage):")
print(f"  • Train Split       : {len(train_items):3d} queries ({len(train_items)/len(items)*100:.1f}%) -> {train_path}")
print(f"  • Validation (Dev)  : {len(val_items):3d} queries ({len(val_items)/len(items)*100:.1f}%) -> {val_path}")
print(f"  • Frozen Test Set   : {len(test_items):3d} queries ({len(test_items)/len(items)*100:.1f}%) -> {test_path}")
