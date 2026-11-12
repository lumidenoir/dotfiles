#!/usr/bin/env python3
"""
test_adversarial_suite.py - Deep Adversarial & Edge-Case Benchmark for Minimo Cognitive Router
Tests complex, ambiguous, real-world natural language precedents completely independently from
internal implementation heuristics.

Categories:
1. Negations, Refusals & Cancellations (anti-patterns)
2. Keyword Collisions: Technical 'Task' Queries vs Task Creation
3. Epistemic Inquiries ('remind me what is X') vs Imperative Actions ('remind me to X')
4. Colloquial, Slang & Implicit Audio Controls
5. Music Streaming vs Ambient Study Moods
6. Video / Movie / Anime vs Music Ambiguity
7. Clipboard & Epistemic Memory Inquiries
8. Personal Notes & Document Vault Inquiries
9. Multi-Clause Complex Preambles & Noise
"""

import sys
import os
import time
from typing import Dict, Any, List

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from core.semantic_router import route_intent_semantic

ADVERSARIAL_CASES: List[Dict[str, Any]] = [
    # ── 1. Negations, Refusals & Cancellations ──
    {
        "category": "Negations & Cancellations",
        "query": "never mind cancel that task",
        "expected_intent": "chat"
    },
    {
        "category": "Negations & Cancellations",
        "query": "todo: do not add a task",
        "expected_intent": "chat"
    },
    {
        "category": "Negations & Cancellations",
        "query": "stop adding reminders please",
        "expected_intent": "chat"
    },
    {
        "category": "Negations & Cancellations",
        "query": "don't remind me about anything today",
        "expected_intent": "chat"
    },
    {
        "category": "Negations & Cancellations",
        "query": "forget what i just said about creating a todo",
        "expected_intent": "chat"
    },
    {
        "category": "Negations & Cancellations",
        "query": "cancel that reminder request",
        "expected_intent": "chat"
    },
    {
        "category": "Negations & Cancellations",
        "query": "do not create a todo for this bug",
        "expected_intent": "chat"
    },
    {
        "category": "Negations & Cancellations",
        "query": "nevermind forget about it",
        "expected_intent": "chat"
    },
    {
        "category": "Negations & Cancellations",
        "query": "abort task creation",
        "expected_intent": "chat"
    },
    {
        "category": "Negations & Cancellations",
        "query": "i changed my mind don't add that task",
        "expected_intent": "chat"
    },
    {
        "category": "Negations & Cancellations",
        "query": "stop creating tasks for me",
        "expected_intent": "chat"
    },

    # ── 2. Keyword Collisions: Technical 'Task' Queries vs Task Creation ──
    {
        "category": "Keyword Collision (Tech Task)",
        "query": "how to create a task in celery for background jobs",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Keyword Collision (Tech Task)",
        "query": "what is the linux kernel task scheduling algorithm",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Keyword Collision (Tech Task)",
        "query": "how does linux manage task scheduling",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Keyword Collision (Tech Task)",
        "query": "what is the difference between a task and a process in linux",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Keyword Collision (Tech Task)",
        "query": "explain cooperative multitasking in embedded systems",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Keyword Collision (Tech Task)",
        "query": "how does asyncio.create_task work in python",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Keyword Collision (Tech Task)",
        "query": "what causes task priority inversion in real time operating systems",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Keyword Collision (Tech Task)",
        "query": "celery worker task retry exponential backoff pattern",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Keyword Collision (Tech Task)",
        "query": "how to profile task memory allocation in go",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Keyword Collision (Tech Task)",
        "query": "implement a todo list data structure in rust",
        "expected_intent": "rag_knowledge"
    },

    # ── 3. Epistemic Inquiries vs Imperative Actions ──
    {
        "category": "Epistemic vs Imperative",
        "query": "remind me what is the formula for fanno flow",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Epistemic vs Imperative",
        "query": "remind me how the b-tree rebalancing algorithm works",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Epistemic vs Imperative",
        "query": "can you remind me who proved the poincare conjecture",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Epistemic vs Imperative",
        "query": "remind me what the speed of sound in air is at 20 celsius",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Epistemic vs Imperative",
        "query": "remind me to review the fanno flow formula tomorrow morning",
        "expected_intent": "add_task"
    },
    {
        "category": "Epistemic vs Imperative",
        "query": "remind me to call the professor on monday at 10am",
        "expected_intent": "add_task"
    },
    {
        "category": "Epistemic vs Imperative",
        "query": "make sure i dont forget to push git commits before leaving",
        "expected_intent": "add_task"
    },
    {
        "category": "Epistemic vs Imperative",
        "query": "dont let me forget to submit the conference paper by friday",
        "expected_intent": "add_task"
    },
    {
        "category": "Epistemic vs Imperative",
        "query": "remember to backup the postgres database tonight p1",
        "expected_intent": "add_task"
    },
    {
        "category": "Epistemic vs Imperative",
        "query": "need to re-read Anderson compressible flow chapter 4 set a p2 task due friday",
        "expected_intent": "add_task"
    },

    # ── 4. Colloquial, Slang & Implicit Audio Controls ──
    {
        "category": "Colloquial Audio Controls",
        "query": "can we turn this off please it is too loud",
        "expected_intent": "mpris_control"
    },
    {
        "category": "Colloquial Audio Controls",
        "query": "turn the music off",
        "expected_intent": "mpris_control"
    },
    {
        "category": "Colloquial Audio Controls",
        "query": "cut the sound",
        "expected_intent": "mpris_control"
    },
    {
        "category": "Colloquial Audio Controls",
        "query": "drop the volume a bit",
        "expected_intent": "mpris_control"
    },
    {
        "category": "Colloquial Audio Controls",
        "query": "shut off playback",
        "expected_intent": "mpris_control"
    },
    {
        "category": "Colloquial Audio Controls",
        "query": "what was that song playing in my browser earlier",
        "expected_intent": "mpris_control"
    },
    {
        "category": "Colloquial Audio Controls",
        "query": "what jam is this currently playing",
        "expected_intent": "mpris_control"
    },
    {
        "category": "Colloquial Audio Controls",
        "query": "pause playback for a second",
        "expected_intent": "mpris_control"
    },
    {
        "category": "Colloquial Audio Controls",
        "query": "skip to next song",
        "expected_intent": "mpris_control"
    },
    {
        "category": "Colloquial Audio Controls",
        "query": "go back to previous track",
        "expected_intent": "mpris_control"
    },

    # ── 5. Music Streaming vs Ambient Study Moods ──
    {
        "category": "Music Streaming & Mood",
        "query": "play something chill while i read",
        "expected_intent": "play_music"
    },
    {
        "category": "Music Streaming & Mood",
        "query": "put on some jazz music",
        "expected_intent": "play_music"
    },
    {
        "category": "Music Streaming & Mood",
        "query": "stream lofi beats in background",
        "expected_intent": "play_music"
    },
    {
        "category": "Music Streaming & Mood",
        "query": "play aimer",
        "expected_intent": "play_music"
    },
    {
        "category": "Music Streaming & Mood",
        "query": "listen to radiohead",
        "expected_intent": "play_music"
    },
    {
        "category": "Music Streaming & Mood",
        "query": "play reaper by kelsey lu",
        "expected_intent": "play_music"
    },
    {
        "category": "Music Streaming & Mood",
        "query": "queue up some acoustic guitar songs",
        "expected_intent": "play_music"
    },
    {
        "category": "Music Streaming & Mood",
        "query": "stream synthwave for coding",
        "expected_intent": "play_music"
    },
    {
        "category": "Music Streaming & Mood",
        "query": "play some piano music",
        "expected_intent": "play_music"
    },
    {
        "category": "Music Streaming & Mood",
        "query": "put on background study beats",
        "expected_intent": "play_music"
    },

    # ── 6. Video / Movie / Anime vs Music Ambiguity ──
    {
        "category": "Media vs Music",
        "query": "watch steins gate episode 1",
        "expected_intent": "play_media"
    },
    {
        "category": "Media vs Music",
        "query": "play frieren ep 5",
        "expected_intent": "play_media"
    },
    {
        "category": "Media vs Music",
        "query": "stream movie interstellar",
        "expected_intent": "play_media"
    },
    {
        "category": "Media vs Music",
        "query": "put on the latest episode of jujutsu kaisen",
        "expected_intent": "play_media"
    },
    {
        "category": "Media vs Music",
        "query": "watch anime",
        "expected_intent": "play_media"
    },
    {
        "category": "Media vs Music",
        "query": "stream season 2 episode 4 of vinland saga",
        "expected_intent": "play_media"
    },
    {
        "category": "Media vs Music",
        "query": "watch film blade runner 2049",
        "expected_intent": "play_media"
    },
    {
        "category": "Media vs Music",
        "query": "put on episode 3 of chainsaw man",
        "expected_intent": "play_media"
    },
    {
        "category": "Media vs Music",
        "query": "play video clip of the launch",
        "expected_intent": "play_media"
    },
    {
        "category": "Media vs Music",
        "query": "stream show the expanse",
        "expected_intent": "play_media"
    },

    # ── 7. Clipboard & Epistemic Memory Inquiries ──
    {
        "category": "Clipboard & Memory",
        "query": "did i copy that bearer token from postman earlier",
        "expected_intent": "mindspace"
    },
    {
        "category": "Clipboard & Memory",
        "query": "what did i copy to clipboard",
        "expected_intent": "mindspace"
    },
    {
        "category": "Clipboard & Memory",
        "query": "search clipboard stash for postgres connection string",
        "expected_intent": "mindspace"
    },
    {
        "category": "Clipboard & Memory",
        "query": "find in clipboard that curl command with authorization header",
        "expected_intent": "mindspace"
    },
    {
        "category": "Clipboard & Memory",
        "query": "what was the last thing i copied",
        "expected_intent": "mindspace"
    },
    {
        "category": "Clipboard & Memory",
        "query": "search clipboard for token",
        "expected_intent": "mindspace"
    },
    {
        "category": "Clipboard & Memory",
        "query": "show copied text from earlier",
        "expected_intent": "mindspace"
    },
    {
        "category": "Clipboard & Memory",
        "query": "clips from earlier today in stash",
        "expected_intent": "mindspace"
    },

    # ── 8. Personal Notes & Document Vault Inquiries ──
    {
        "category": "Notes Vault & RAG",
        "query": "is there any mention in my notes of how to configure cross compilation",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Notes Vault & RAG",
        "query": "i wrote a note about rust lifetimes last week find it",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Notes Vault & RAG",
        "query": "search my notes for python scripts",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Notes Vault & RAG",
        "query": "pull up my notes on aerodynamic flutter boundary",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Notes Vault & RAG",
        "query": "what does my org note say about compressible flow",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Notes Vault & RAG",
        "query": "find my notes on compiler architecture",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Notes Vault & RAG",
        "query": "search roam vault for paxos consensus notes",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Notes Vault & RAG",
        "query": "notes on rayleigh flow temperature ratio",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Notes Vault & RAG",
        "query": "where did i write down the ssh config snippet in my notes",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Notes Vault & RAG",
        "query": "check my notes for zathura keybindings",
        "expected_intent": "rag_knowledge"
    },

    # ── 9. Multi-Clause Complex Preambles & Noise ──
    {
        "category": "Multi-Clause Preambles",
        "query": "i've been working on this bug all day and it's driving me crazy. please add a task to debug the waybar audio crash tomorrow",
        "expected_intent": "add_task"
    },
    {
        "category": "Multi-Clause Preambles",
        "query": "the sound in my headphones is way too loud, pause it for a second",
        "expected_intent": "mpris_control"
    },
    {
        "category": "Multi-Clause Preambles",
        "query": "my professor said that fanno flow is adiabatic, is that true or did i misunderstand?",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Multi-Clause Preambles",
        "query": "i keep forgetting to push to origin main before heading out, remind me to push git commits tonight at 8pm",
        "expected_intent": "add_task"
    },
    {
        "category": "Multi-Clause Preambles",
        "query": "i can't focus with all this silence, play something chill while i study",
        "expected_intent": "play_music"
    },
    {
        "category": "Multi-Clause Preambles",
        "query": "i need to see what I have to do before leaving office, show my pending tasks",
        "expected_intent": "list_tasks"
    },
    {
        "category": "Multi-Clause Preambles",
        "query": "someone asked me about how b-tree handles node splits, can you explain b-tree split algorithm?",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Multi-Clause Preambles",
        "query": "i was reading an article on distributed locks earlier, did i copy that redis snippet?",
        "expected_intent": "mindspace"
    },
    {
        "category": "Multi-Clause Preambles",
        "query": "waybar audio widget is crashing repeatedly whenever pipewire restarts, create a task to fix it tonight p1",
        "expected_intent": "add_task"
    },
    {
        "category": "Multi-Clause Preambles",
        "query": "i'm exhausted of reading through these pull requests, never mind cancel that task",
        "expected_intent": "chat"
    }
]

def run_adversarial_suite():
    print("=" * 80)
    print(" 🚀 RUNNING ADVERSARIAL & NATURAL LANGUAGE EDGE-CASE ROUTER BENCHMARK")
    print(f" Total Adversarial Test Cases: {len(ADVERSARIAL_CASES)}")
    print("=" * 80)

    passed = 0
    failed = 0
    latencies = []
    category_stats = {}

    for i, test in enumerate(ADVERSARIAL_CASES):
        cat = test["category"]
        q = test["query"]
        expected = test["expected_intent"]

        if cat not in category_stats:
            category_stats[cat] = {"passed": 0, "total": 0}
        category_stats[cat]["total"] += 1

        t0 = time.perf_counter()
        res = route_intent_semantic(q)
        t1 = time.perf_counter()
        elapsed_ms = (t1 - t0) * 1000.0
        latencies.append(elapsed_ms)

        got = res.get("intent")
        conf = res.get("confidence", 0.0)

        is_pass = (got == expected)
        if is_pass:
            passed += 1
            category_stats[cat]["passed"] += 1
            status = "✅ PASS"
        else:
            failed += 1
            status = "❌ FAIL"

        short_q = q if len(q) <= 52 else q[:49] + "..."
        print(f"[{status}] #{i+1:02d} ({cat[:26]:26}) \"{short_q:52}\" -> got [{got:13}] exp [{expected:13}] ({elapsed_ms:6.2f}ms)")

    avg_latency = sum(latencies) / len(latencies) if latencies else 0.0

    print("\n" + "=" * 80)
    print(" 📊 CATEGORY BREAKDOWN")
    print("=" * 80)
    for cat, stats in category_stats.items():
        pct = (stats["passed"] / stats["total"]) * 100.0
        icon = "✅" if stats["passed"] == stats["total"] else "⚠️"
        print(f" {icon} {cat:32}: {stats['passed']:2d}/{stats['total']:2d} ({pct:5.1f}%)")

    print("\n" + "=" * 80)
    print(f" OVERALL ADVERSARIAL BENCHMARK: {passed}/{len(ADVERSARIAL_CASES)} Passed ({failed} Failed)")
    print(f" Pass Rate: {(passed / len(ADVERSARIAL_CASES)) * 100:.1f}%")
    print(f" Average Latency: {avg_latency:.2f} ms")
    print("=" * 80)

    if failed > 0:
        sys.exit(1)

if __name__ == "__main__":
    run_adversarial_suite()
