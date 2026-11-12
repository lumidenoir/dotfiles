"""
Minimo Brain Suite - Test Suite for Steps 1, 2, and 4
Verifies:
- Step 1: Model lock-in (qwen2.5:1.5b-instruct and qwen2.5:3b / qwen2.5:3b-instruct).
- Step 2: End-to-end structured action payloads (action_dispatched packets).
- Step 4: Multi-turn conversational context rewriter.
"""

import sys
import os
import asyncio
import json
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from core.config import get_router_model, get_synthesis_model, ROUTER_MODEL, SYNTHESIS_MODEL
from core.context_rewriter import should_rewrite, rewrite_conversational_context
from core.desktop_agent import execute_desktop_agent_stream

class TestStep124(unittest.TestCase):
    def test_step1_model_lockin(self):
        r_model = get_router_model()
        s_model = get_synthesis_model()
        self.assertIn("qwen2.5:1.5b", r_model)
        self.assertIn("qwen2.5:3b", s_model)
        self.assertNotIn("3.5", r_model)
        self.assertNotIn("3.5", s_model)
        print(f"✓ Step 1 verified: Router={r_model}, Synthesis={s_model}")

    def test_step4_should_rewrite_filter(self):
        # Empty history -> False
        self.assertFalse(should_rewrite("what is rayleigh flow", []))
        self.assertFalse(should_rewrite("what is rayleigh flow", None))

        # Explicit atomic command -> False
        hist = [{"q": "what is fanno flow", "a": "Fanno flow is adiabatic."}]
        self.assertFalse(should_rewrite("pause", hist))
        self.assertFalse(should_rewrite("$uname -r", hist))
        self.assertFalse(should_rewrite("todo: buy milk", hist))

        # Anaphoric references -> True
        self.assertTrue(should_rewrite("and what about rayleigh flow?", hist))
        self.assertTrue(should_rewrite("is it adiabatic?", hist))
        self.assertTrue(should_rewrite("make that p1", hist))
        self.assertTrue(should_rewrite("play it", hist))
        self.assertTrue(should_rewrite("how does that work?", hist))
        print("✓ Step 4 filter (should_rewrite) verified with zero-cost fast paths")

    def test_step4_rewrite_execution(self):
        hist = [{"q": "what is fanno flow", "a": "Fanno flow is adiabatic frictional duct flow."}]
        res = rewrite_conversational_context("and what about rayleigh flow?", hist)
        self.assertIn("rayleigh", res.lower())
        self.assertNotIn("<|im_start|>", res)
        print(f"✓ Step 4 rewriter: 'and what about rayleigh flow?' -> '{res}'")

        hist_task = [{"q": "add task finish problem set", "a": "Added task to Todoist."}]
        res_task = rewrite_conversational_context("make that p1", hist_task)
        self.assertIn("p1", res_task.lower())
        print(f"✓ Step 4 rewriter: 'make that p1' -> '{res_task}'")

    def test_step2_structured_action_packets(self):
        async def run_queries():
            # Test 1: Task list fetch
            packets_tasks = []
            async for pkt in execute_desktop_agent_stream("tasks"):
                packets_tasks.append(pkt)
            
            dispatched = [p for p in packets_tasks if p.get("type") == "action_dispatched"]
            self.assertTrue(len(dispatched) > 0, "Expected action_dispatched packet for list_tasks")
            self.assertEqual(dispatched[0]["intent"], "list_tasks")
            self.assertEqual(dispatched[0]["risk_policy"], "safe")
            self.assertIn("tasks", dispatched[0]["payload"])

            # Test 2: Shell command
            packets_cmd = []
            async for pkt in execute_desktop_agent_stream("$echo hello_minimo"):
                packets_cmd.append(pkt)
            dispatched_cmd = [p for p in packets_cmd if p.get("type") == "action_dispatched"]
            self.assertTrue(len(dispatched_cmd) > 0, "Expected action_dispatched packet for run_cmd")
            self.assertEqual(dispatched_cmd[0]["intent"], "run_cmd")
            self.assertIn("hello_minimo", dispatched_cmd[0]["payload"]["stdout"])

            # Test 3: RAG knowledge search
            packets_rag = []
            async for pkt in execute_desktop_agent_stream("what is shock wave"):
                packets_rag.append(pkt)
            dispatched_rag = [p for p in packets_rag if p.get("type") == "action_dispatched"]
            self.assertTrue(len(dispatched_rag) > 0, "Expected action_dispatched packet for rag_knowledge")
            self.assertEqual(dispatched_rag[0]["intent"], "rag_knowledge")
            self.assertIn("sources", dispatched_rag[0]["payload"])

            print("✓ Step 2 verified: structured action_dispatched packets emitted across intents")

        asyncio.run(run_queries())

    def test_hybrid_rag_with_reranker_and_citations(self):
        from core.rag import search_library_rag
        hits = search_library_rag("supersonic oblique shock", limit=3)
        self.assertTrue(len(hits) > 0, "Expected hybrid RAG hits for supersonic oblique shock")
        for h in hits:
            self.assertIn("citation", h)
            self.assertIn("page", h)
            self.assertIn("badge", h)
            self.assertIn("action_type", h)
            self.assertIn("action_payload", h)
            self.assertIn(h["action_type"], ("open_book", "open_note"))
            self.assertIn(":::", h["action_payload"])
        print(f"✓ Hybrid RAG verified: {len(hits)} hits with reranker and explicit citations (e.g. '{hits[0]['citation']}')")

if __name__ == "__main__":
    unittest.main()
