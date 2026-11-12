"""
Unit & Integration Tests for:
1. Coding Intent Routing (ensuring MATLAB/script requests generate answers/code rather than tasks).
2. Active Window & Hover PDF Detection (/proc/<pid>/fd & Hyprland).
3. Incremental Auto-Indexing of added/modified files.
4. Scoped PDF Question Answering with present vs absent feedback.
"""

import os
import sys
import tempfile
import sqlite3
import unittest
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from core.desktop_agent import call_direct_cognitive_agent, check_reflex_fast_path
from core.pdf_context import (
    extract_pdf_from_pid, find_pdf_by_filename, get_active_or_hovered_pdf
)
from core.unified_indexer import (
    init_rag_schema, index_file_incremental, scan_and_index_changes, get_category_for_path
)
from core.rag import search_library_rag


class TestPdfAutoIndexAndCoding(unittest.TestCase):

    def test_coding_queries_do_not_route_to_add_task(self):
        """Verify that requests to write code/MATLAB scripts route to rag_knowledge, never add_task."""
        coding_queries = [
            "write a code for matlab polyfit and graphs plotting",
            "write a python script to monitor disk usage",
            "implement quicksort algorithm in C++",
            "plot a damped sine wave in matlab"
        ]

        for q in coding_queries:
            # Reflex path should not treat these as task actions
            reflex = check_reflex_fast_path(q)
            if reflex:
                self.assertNotEqual(reflex.get("intent"), "add_task", f"Query '{q}' was reflex-routed to add_task")

            # Mock LLM response simulating an edge model that might emit 'add_task'
            with patch("urllib.request.urlopen") as mock_urlopen:
                mock_resp = MagicMock()
                mock_resp.read.return_value = b'{"response": "{\\"thought\\": \\"write code\\", \\"action\\": \\"add_task\\", \\"params\\": {\\"title\\": \\"write code for matlab\\"}}"}'
                mock_resp.__enter__.return_value = mock_resp
                mock_urlopen.return_value = mock_resp

                routed = call_direct_cognitive_agent(q)
                self.assertEqual(
                    routed["intent"], "rag_knowledge",
                    f"Defensive guard failed: '{q}' was permitted to route as {routed['intent']}"
                )

    def test_task_queries_still_route_to_add_task(self):
        """Verify that legitimate tasks still route properly."""
        task_query = "remind me to submit the lab report tomorrow at 5pm p1"
        with patch("urllib.request.urlopen") as mock_urlopen:
            mock_resp = MagicMock()
            mock_resp.read.return_value = b'{"response": "{\\"thought\\": \\"reminder\\", \\"action\\": \\"add_task\\", \\"params\\": {\\"title\\": \\"submit lab report\\", \\"due\\": \\"tomorrow 5pm\\", \\"priority\\": 1}}"}'
            mock_resp.__enter__.return_value = mock_resp
            mock_urlopen.return_value = mock_resp

            routed = call_direct_cognitive_agent(task_query)
            self.assertEqual(routed["intent"], "add_task")
            self.assertEqual(routed.get("task_title"), "submit lab report")

    def test_extract_pdf_from_pid(self):
        """Test PDF resolution from process file descriptors."""
        with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as tmp_pdf:
            tmp_pdf.write(b"%PDF-1.4 dummy content")
            pdf_path = tmp_pdf.name

        try:
            # Test with current process PID and an open file
            with open(pdf_path, "rb") as f:
                detected = extract_pdf_from_pid(os.getpid())
                self.assertIsNotNone(detected)
                self.assertTrue(detected.endswith(".pdf"))
                self.assertTrue(os.path.isfile(detected))
        finally:
            if os.path.exists(pdf_path):
                os.unlink(pdf_path)

    def test_incremental_indexing_and_scoped_search(self):
        """Test creating, indexing, and querying a document with scoped RAG search."""
        with tempfile.TemporaryDirectory() as tmp_dir:
            test_db = os.path.join(tmp_dir, "test_rag.db")
            init_rag_schema(test_db)

            # Create a sample markdown notes file
            doc_path = os.path.join(tmp_dir, "aerodynamics_notes.md")
            with open(doc_path, "w", encoding="utf-8") as f:
                f.write("""# Aerodynamic Theory and Wing Flutter
Flutter is a dynamic aeroelastic instability occurring when structural damping
is overwhelmed by aerodynamic forces, leading to self-sustained oscillations.
The classical Wagner function governs indicial lift buildup.
""")

            # Index the file incrementally
            res = index_file_incremental(doc_path, force=True, db_path=test_db)
            self.assertEqual(res["status"], "indexed")
            self.assertGreater(res["chunks"], 0)

            # Query the test DB directly with filepath scoping
            conn = sqlite3.connect(test_db)
            cur = conn.cursor()
            cur.execute("SELECT count(*) FROM doc_chunks WHERE filepath = ?", (doc_path,))
            count = cur.fetchone()[0]
            self.assertGreater(count, 0)

            # Test BM25 match for term present in document
            cur.execute("SELECT rowid, content FROM doc_chunks WHERE doc_chunks MATCH 'flutter' AND filepath = ?", (doc_path,))
            hit = cur.fetchone()
            self.assertIsNotNone(hit)
            self.assertIn("aeroelastic", hit[1])

            # Test BM25 match for term NOT in document
            cur.execute("SELECT rowid, content FROM doc_chunks WHERE doc_chunks MATCH 'polyfit' AND filepath = ?", (doc_path,))
            miss = cur.fetchone()
            self.assertIsNone(miss)

            conn.close()


if __name__ == "__main__":
    unittest.main()
