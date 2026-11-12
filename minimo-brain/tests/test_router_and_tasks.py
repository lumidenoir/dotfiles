#!/usr/bin/env python3
"""
test_router_and_tasks.py - Comprehensive Regression Test Suite for Minimo Cognitive Router & Task Engine
Covers:
- Layer 1 Fast-paths (prefix commands, now-playing, media status)
- Layer 2 In-process ONNX Semantic Vector Router (sub-3ms embedding matching)
- Layer 3 Decoupled Entity Matchers (movies fuzzy lookup, music, MPRIS controls)
- Natural Language Task Creation (bug rephrasing, composite dates, priority parsing, description stamping)
- Conversational Vague Gating & False-Positive Immunity (knowledge questions vs task creation)
- Multi-domain RAG queries (Aero, Thermo, Systems, CS, Biology, Philosophy)
"""

import sys
import os
import time
import json
from typing import Dict, Any, List, Tuple

# Ensure minimo-brain is on python path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from core.semantic_router import route_intent_semantic, get_semantic_router

TEST_CASES: List[Dict[str, Any]] = [
    # ── 1. Media & Video Playback ──
    {
        "category": "Media Playback",
        "query": "play frieren ep 5",
        "expected_intent": "play_media",
        "check_media": True
    },
    {
        "category": "Media Playback (Fuzzy Typo)",
        "query": "play fieren ep 5",
        "expected_intent": "play_media",
        "check_media": True
    },
    {
        "category": "Media Playback",
        "query": "watch steins gate episode 1",
        "expected_intent": "play_media"
    },
    {
        "category": "Media Playback",
        "query": "stream movie interstellar",
        "expected_intent": "play_media"
    },

    # ── 2. Music Streaming & Library ──
    {
        "category": "Music",
        "query": "play aimer",
        "expected_intent": "play_music"
    },
    {
        "category": "Music",
        "query": "listen to radiohead",
        "expected_intent": "play_music"
    },
    {
        "category": "Music",
        "query": "stream lofi beats in background",
        "expected_intent": "play_music"
    },
    {
        "category": "Music",
        "query": "put on some jazz music",
        "expected_intent": "play_music"
    },
    {
        "category": "Music (Title by Artist)",
        "query": "play reaper by kelsey lu",
        "expected_intent": "play_music"
    },
    {
        "category": "Music (Mood)",
        "query": "play something chill",
        "expected_intent": "play_music"
    },
    {
        "category": "Music (Genre)",
        "query": "play jazz",
        "expected_intent": "play_music"
    },

    # ── 3. MPRIS Controls & Now Playing ──
    {
        "category": "MPRIS Now Playing",
        "query": "whats playing?",
        "expected_intent": "mpris_control",
        "expected_mpris_action": "status"
    },
    {
        "category": "MPRIS Now Playing",
        "query": "what song is playing right now",
        "expected_intent": "mpris_control",
        "expected_mpris_action": "status"
    },
    {
        "category": "MPRIS Now Playing",
        "query": "now playing",
        "expected_intent": "mpris_control",
        "expected_mpris_action": "status"
    },
    {
        "category": "MPRIS Now Playing",
        "query": "current track",
        "expected_intent": "mpris_control",
        "expected_mpris_action": "status"
    },
    {
        "category": "MPRIS Controls",
        "query": "pause music",
        "expected_intent": "mpris_control",
        "expected_mpris_action": "play-pause"
    },
    {
        "category": "MPRIS Controls (Conversational)",
        "query": "pause the music",
        "expected_intent": "mpris_control",
        "expected_mpris_action": "play-pause"
    },
    {
        "category": "MPRIS Controls",
        "query": "resume playback",
        "expected_intent": "mpris_control",
        "expected_mpris_action": "play-pause"
    },
    {
        "category": "MPRIS Controls",
        "query": "next track",
        "expected_intent": "mpris_control",
        "expected_mpris_action": "next"
    },
    {
        "category": "MPRIS Controls",
        "query": "skip song",
        "expected_intent": "mpris_control",
        "expected_mpris_action": "next"
    },
    {
        "category": "MPRIS Controls (Conversational Next)",
        "query": "play next song",
        "expected_intent": "mpris_control",
        "expected_mpris_action": "next"
    },
    {
        "category": "MPRIS Controls (Conversational Next)",
        "query": "play next track",
        "expected_intent": "mpris_control",
        "expected_mpris_action": "next"
    },
    {
        "category": "MPRIS Controls (Conversational Next)",
        "query": "play the next song",
        "expected_intent": "mpris_control",
        "expected_mpris_action": "next"
    },
    {
        "category": "MPRIS Controls (Conversational Next)",
        "query": "skip to next song",
        "expected_intent": "mpris_control",
        "expected_mpris_action": "next"
    },
    {
        "category": "MPRIS Controls",
        "query": "previous track",
        "expected_intent": "mpris_control",
        "expected_mpris_action": "previous"
    },
    {
        "category": "MPRIS Controls (Conversational Prev)",
        "query": "play previous song",
        "expected_intent": "mpris_control",
        "expected_mpris_action": "previous"
    },
    {
        "category": "MPRIS Controls (Conversational Prev)",
        "query": "play the previous track",
        "expected_intent": "mpris_control",
        "expected_mpris_action": "previous"
    },
    {
        "category": "MPRIS Controls",
        "query": "stop audio",
        "expected_intent": "mpris_control",
        "expected_mpris_action": "stop"
    },
    {
        "category": "MPRIS Controls (Conversational Stop)",
        "query": "stop playing",
        "expected_intent": "mpris_control",
        "expected_mpris_action": "stop"
    },

    # ── 4. Natural Language Task Creation (Clean Titles, Dates, Priorities, Descriptions) ──
    {
        "category": "Task Creation (Bug -> Actionable Title)",
        "query": "having difficulty in mpv subtitle rendering create a task due 23rd evening p1",
        "expected_intent": "add_task",
        "expected_title": "Fix MPV subtitle rendering",
        "expected_due": "23rd evening",
        "expected_priority": 1,
        "must_have_desc": True
    },
    {
        "category": "Task Creation (Crash Report + Tomorrow Morning)",
        "query": "facing issue with waybar audio widget crashing create a reminder for tomorrow morning",
        "expected_intent": "add_task",
        "expected_title": "Fix waybar audio widget crashing",
        "expected_due": "tomorrow morning",
        "must_have_desc": True
    },
    {
        "category": "Task Creation (Hardware Bug + Tonight P1)",
        "query": "got a problem with bluetooth headset disconnecting set a task due tonight p1",
        "expected_intent": "add_task",
        "expected_title": "Fix bluetooth headset disconnecting",
        "expected_due": "tonight",
        "expected_priority": 1,
        "must_have_desc": True
    },
    {
        "category": "Task Creation (Bug Report)",
        "query": "bug in opengl rendering please add a task to fix it tonight",
        "expected_intent": "add_task",
        "expected_title": "Fix opengl rendering",
        "expected_due": "tonight",
        "must_have_desc": True
    },
    {
        "category": "Task Creation (Word Priority)",
        "query": "urgent task to restart production nginx server tonight",
        "expected_intent": "add_task",
        "expected_title": "Restart production nginx server",
        "expected_due": "tonight",
        "expected_priority": 1,
        "must_have_desc": True
    },
    {
        "category": "Task Creation (High Priority Phrase)",
        "query": "set a high priority task to review pull request tomorrow morning",
        "expected_intent": "add_task",
        "expected_title": "Review pull request",
        "expected_due": "tomorrow morning",
        "expected_priority": 2,
        "must_have_desc": True
    },
    {
        "category": "Task Creation (Conversational Obligation)",
        "query": "need to re-read Anderson compressible flow chapter 4 set a p2 task due friday",
        "expected_intent": "add_task",
        "expected_title": "Re-read Anderson compressible flow chapter 4",
        "expected_due": "friday",
        "expected_priority": 2,
        "must_have_desc": True
    },
    {
        "category": "Task Creation (Time Trigger)",
        "query": "remind me to buy groceries tomorrow at 5pm p2",
        "expected_intent": "add_task",
        "expected_title": "Buy groceries",
        "expected_due": "tomorrow at 5pm",
        "expected_priority": 2,
        "must_have_desc": True
    },
    {
        "category": "Task Creation (Negative Reminder)",
        "query": "dont forget to push git commits before leaving tonight",
        "expected_intent": "add_task",
        "expected_title": "Push git commits before leaving",
        "expected_due": "tonight",
        "must_have_desc": True
    },
    {
        "category": "Task Creation (Self-Contained Followup)",
        "query": "media card and active pill in qs also not working add this task too",
        "expected_intent": "add_task",
        "expected_title": "Fix media card and active pill in QS",
        "must_have_desc": True
    },
    {
        "category": "Task Creation (Prefix)",
        "query": "todo: clean up unused docker images by sunday",
        "expected_intent": "add_task",
        "expected_title": "Clean up unused docker images",
        "expected_due": "sunday",
        "must_have_desc": True
    },
    {
        "category": "Task Creation (Prefix)",
        "query": "task: update arch linux system packages tomorrow p3",
        "expected_intent": "add_task",
        "expected_title": "Update arch linux system packages",
        "expected_due": "tomorrow",
        "expected_priority": 3,
        "must_have_desc": True
    },

    # ── 5. Vague Task Gating (Clarification Safeguards) ──
    {
        "category": "Task Gating (Vague)",
        "query": "add a task",
        "expected_intent": "add_task",
        "expected_clarification": True
    },
    {
        "category": "Task Gating (Vague)",
        "query": "create a new task please",
        "expected_intent": "add_task",
        "expected_clarification": True
    },
    {
        "category": "Task Gating (Vague)",
        "query": "remind me",
        "expected_intent": "add_task",
        "expected_clarification": True
    },

    # ── 6. Task Listing ──
    {
        "category": "Task Listing",
        "query": "show my tasks",
        "expected_intent": "list_tasks"
    },
    {
        "category": "Task Listing",
        "query": "what are my pending tasks?",
        "expected_intent": "list_tasks"
    },
    {
        "category": "Task Listing",
        "query": "what do i need to do today",
        "expected_intent": "list_tasks"
    },

    # ── 7. Daily Horizon & System Context ──
    {
        "category": "Daily Horizon",
        "query": "daily horizon",
        "expected_intent": "daily_horizon"
    },
    {
        "category": "Daily Horizon",
        "query": "morning briefing",
        "expected_intent": "daily_horizon"
    },
    {
        "category": "Active Window",
        "query": "what window is this",
        "expected_intent": "active_window"
    },
    {
        "category": "Active Window",
        "query": "which application is focused",
        "expected_intent": "active_window"
    },
    {
        "category": "MindSpace Clipboard",
        "query": "what did i copy to clipboard",
        "expected_intent": "mindspace"
    },
    {
        "category": "MindSpace Clipboard",
        "query": "search clipboard for token",
        "expected_intent": "mindspace"
    },

    # ── 8. False-Positive Immunity (Questions about tasks must route to RAG) ──
    {
        "category": "Knowledge False-Positive Guard",
        "query": "how does linux manage task scheduling?",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Knowledge False-Positive Guard",
        "query": "what is the difference between a task and a coroutine in asyncio?",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Knowledge False-Positive Guard",
        "query": "how to create a task in celery?",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Knowledge False-Positive Guard",
        "query": "explain cooperative multitasking in embedded systems",
        "expected_intent": "rag_knowledge"
    },

    # ── 9. Multi-Domain Technical Literature & Notes RAG ──
    {
        "category": "Literature RAG (Thermodynamics)",
        "query": "is fanno flow adiabatic?",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Literature RAG (Aerodynamics)",
        "query": "what is the BEMT equation for induced velocity",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Literature RAG (Distributed Systems)",
        "query": "explain the paxos consensus algorithm",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Literature RAG (Biology)",
        "query": "how does cellular respiration work in mitochondria",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Literature RAG (Philosophy)",
        "query": "what does marcus aurelius say about stoicism",
        "expected_intent": "rag_knowledge"
    },
    {
        "category": "Literature RAG (Programming)",
        "query": "explain rust ownership and borrow checker rules",
        "expected_intent": "rag_knowledge"
    },

    # ── 10. Casual Chat ──
    {
        "category": "Chat",
        "query": "hello",
        "expected_intent": "chat"
    },
    {
        "category": "Chat",
        "query": "who are you",
        "expected_intent": "chat"
    },
    {
        "category": "Chat",
        "query": "thanks for your help",
        "expected_intent": "chat"
    },

    # ── 12. Email Summaries & Inbox Inquiries ──
    {
        "category": "Email Summaries",
        "query": "what are the emails last hour",
        "expected_intent": "email_summary"
    },
    {
        "category": "Email Summaries",
        "query": "summarize my last 5 emails",
        "expected_intent": "email_summary"
    },
    {
        "category": "Email Summaries",
        "query": "any new emails in the last 2 hours",
        "expected_intent": "email_summary"
    },
    {
        "category": "Email Summaries",
        "query": "check my recent emails",
        "expected_intent": "email_summary"
    },
    {
        "category": "Email Summaries",
        "query": "give me a summary of my inbox",
        "expected_intent": "email_summary"
    }
]

def run_suite():
    print("=" * 78)
    print(" 🚀 MINIMO COGNITIVE ROUTER & TASK ENGINE REGRESSION SUITE")
    print("=" * 78)
    print(f"Total Test Cases: {len(TEST_CASES)}\n")

    router = get_semantic_router()
    passed_count = 0
    failed_count = 0
    latencies: List[float] = []

    for idx, tc in enumerate(TEST_CASES, start=1):
        q = tc["query"]
        cat = tc["category"]
        exp_intent = tc.get("expected_intent")

        t0 = time.perf_counter()
        res = route_intent_semantic(q)
        dt = (time.perf_counter() - t0) * 1000.0
        latencies.append(dt)

        intent = res.get("intent")
        title = res.get("task_title")
        prio = res.get("task_priority")
        due = res.get("task_due")
        desc = res.get("task_description")
        clar = res.get("needs_clarification", False)
        m_act = res.get("mpris_action")

        passed = True
        fail_reasons = []

        if exp_intent and intent != exp_intent:
            passed = False
            fail_reasons.append(f"Intent mismatch: got '{intent}', expected '{exp_intent}'")

        if tc.get("expected_title"):
            exp_t = tc["expected_title"].strip().lower()
            got_t = (title or "").strip().lower()
            import difflib, re
            sim = difflib.SequenceMatcher(None, exp_t, got_t).ratio()
            exp_words = set(re.findall(r'\w{3,}', exp_t))
            got_words = set(re.findall(r'\w{3,}', got_t))
            overlap = len(exp_words & got_words) / max(1, len(exp_words))
            if got_t != exp_t and exp_t not in got_t and got_t not in exp_t and sim < 0.60 and overlap < 0.50:
                passed = False
                fail_reasons.append(f"Title mismatch: got '{title}', expected '{tc['expected_title']}' (sim={sim:.2f}, overlap={overlap:.2f})")

        if tc.get("expected_mpris_action") and m_act != tc["expected_mpris_action"]:
            passed = False
            fail_reasons.append(f"MPRIS action mismatch: got '{m_act}', expected '{tc['expected_mpris_action']}'")

        if tc.get("expected_clarification") is not None and clar != tc["expected_clarification"]:
            passed = False
            fail_reasons.append(f"Clarification mismatch: got {clar}, expected {tc['expected_clarification']}")

        if tc.get("expected_priority") is not None and prio != tc["expected_priority"]:
            passed = False
            fail_reasons.append(f"Priority mismatch: got P{prio}, expected P{tc['expected_priority']}")

        if tc.get("expected_due") is not None and due != tc["expected_due"]:
            passed = False
            fail_reasons.append(f"Due date mismatch: got '{due}', expected '{tc['expected_due']}'")

        if tc.get("must_have_desc"):
            if not desc or ("Kafka" not in desc and "Minimo" not in desc):
                passed = False
                fail_reasons.append(f"Description missing attribution (expected Kafka/Minimo): got '{desc}'")

        if passed:
            passed_count += 1
            status = "✅ PASS"
            extra = f"[{intent}]"
            if title:
                extra += f" -> \"{title}\""
            if m_act:
                extra += f" (action={m_act})"
            print(f"[{status}] #{idx:02d} ({cat:<28}) \"{q[:42]:<42}\" {extra} ({dt:.2f}ms)")
        else:
            failed_count += 1
            status = "❌ FAIL"
            print(f"[{status}] #{idx:02d} ({cat:<28}) \"{q}\"")
            for r in fail_reasons:
                print(f"        └─ {r}")
            print(f"        └─ Raw Output: {json.dumps(res)}")

    avg_lat = sum(latencies) / len(latencies) if latencies else 0.0
    print("\n" + "=" * 78)
    print(f" ROUTER SUITE: {passed_count}/{len(TEST_CASES)} Passed ({failed_count} Failed)")
    print(f" Average Latency: {avg_lat:.2f} ms")
    print("=" * 78)

    # ── Stage 1 & Stage 4 Cognitive Suite ──
    print("\n" + "=" * 78)
    print(" 🧠 STAGE 1 (DECOMPOSER) & STAGE 4 (ZERO-HALLUCINATION RAG) SUITE")
    print("=" * 78)

    from core.decomposer import decompose_query
    from core.rag import search_library_rag

    decomp_cases = [
        {
            "query": "pause music and search notes for BEMT",
            "is_compound": True,
            "expected_steps": [("mpris_control", "immediate"), ("rag_knowledge", "deferred")]
        },
        {
            "query": "add a task to fix waybar and show my tasks",
            "is_compound": True,
            "expected_steps": [("add_task", "deferred"), ("list_tasks", "deferred")]
        },
        {
            "query": "skip song then what is playing",
            "is_compound": True,
            "expected_steps": [("mpris_control", "immediate"), ("mpris_control", "immediate")]
        },
        {
            "query": "what is the difference between TCP and UDP",
            "is_compound": False,
            "expected_steps": [("rag_knowledge", "deferred")]
        },
        {
            "query": "fanno flow and is it adiabatic",
            "is_compound": False,
            "expected_steps": [("rag_knowledge", "deferred")]
        },
        {
            "query": "notes on flutter and buffet boundary",
            "is_compound": False,
            "expected_steps": [("rag_knowledge", "deferred")]
        }
    ]

    decomp_passed = 0
    for idx, dc in enumerate(decomp_cases, start=1):
        q = dc["query"]
        t0 = time.perf_counter()
        res = decompose_query(q)
        dt = (time.perf_counter() - t0) * 1000.0
        is_comp = res.get("is_compound")
        steps = res.get("steps", [])

        ok = (is_comp == dc["is_compound"]) and (len(steps) == len(dc["expected_steps"]))
        if ok:
            for s, (exp_i, exp_t) in zip(steps, dc["expected_steps"]):
                if s["route"].get("intent") != exp_i or s["step_type"] != exp_t:
                    ok = False
                    break

        if ok:
            decomp_passed += 1
            step_summary = " -> ".join([f"[{s['route'].get('intent')}:{s['step_type']}]" for s in steps])
            print(f"[✅ PASS] Decomp #{idx:02d} \"{q[:42]:<42}\" {step_summary} ({dt:.2f}ms)")
        else:
            print(f"[❌ FAIL] Decomp #{idx:02d} \"{q}\"")
            print(f"        └─ Got: is_compound={is_comp}, steps={[s['route'].get('intent') for s in steps]}")
            failed_count += 1

    # Stage 4: Zero-Hallucination Gate & Reranker Precision
    print("\n--- Stage 4: Two-Key RAG Lock & Zero-Hallucination Abort ---")
    
    # 1. In-index query must return high-confidence chunks
    t0 = time.perf_counter()
    in_index_hits = search_library_rag("fanno flow", limit=4)
    dt_in = (time.perf_counter() - t0) * 1000.0
    if in_index_hits and in_index_hits[0].get("rerank_score", 0.0) > 0.80:
        print(f"[✅ PASS] In-Index Corpus Match: Retrieved {len(in_index_hits)} chunks with top score={in_index_hits[0].get('rerank_score', 0.0):.4f} ({dt_in:.2f}ms)")
    else:
        print(f"[❌ FAIL] In-Index Corpus Match failed: {in_index_hits}")
        failed_count += 1

    # 2. Out-of-index query must abort with 0 chunks (Zero-Hallucination Lock)
    t0 = time.perf_counter()
    out_index_hits = search_library_rag("who won the 1994 FIFA world cup final penalty shootout", limit=4)
    dt_out = (time.perf_counter() - t0) * 1000.0
    if len(out_index_hits) == 0:
        print(f"[✅ PASS] Zero-Hallucination Lock: Successfully aborted unindexed query (0 chunks returned) ({dt_out:.2f}ms)")
    else:
        print(f"[❌ FAIL] Zero-Hallucination Lock failed: returned {len(out_index_hits)} chunks")
        failed_count += 1

    total_all = len(TEST_CASES) + len(decomp_cases) + 2
    passed_all = passed_count + decomp_passed + (1 if in_index_hits else 0) + (1 if len(out_index_hits) == 0 else 0)

    print("\n" + "=" * 78)
    print(f" OVERALL SUITE: {passed_all}/{total_all} Passed ({failed_count} Failed)")
    print("=" * 78)

    if failed_count > 0:
        sys.exit(1)

if __name__ == "__main__":
    run_suite()
