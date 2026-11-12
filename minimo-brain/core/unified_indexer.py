#!/usr/bin/env python3
"""
Minimo Brain Suite - Unified Knowledge Base Indexer
Indexes:
- PDF books & papers (PyMuPDF with TOC outline extraction & front-matter cutting)
- Emacs Org-mode, Markdown & text notes (Section heading chunking with line tracking)
Populates:
- doc_files (tracking mtimes)
- doc_chunks (SQLite FTS5 full-text index with Porter stemming)
- chunk_embeddings (Dense Nomic vector embeddings for semantic search)
"""

import os
import sys
import re
import math
import struct
import sqlite3
import time
import json
import urllib.request
from pathlib import Path
from typing import List, Dict, Any, Tuple, Optional
from concurrent.futures import ThreadPoolExecutor

try:
    import fitz  # PyMuPDF
except ImportError:
    fitz = None

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
try:
    from .config import RAG_DB, DOC_DIRS, OLLAMA_URL, EMBED_MODEL
    from .normalizer import normalize_org_content, normalize_markdown_content
except ImportError:
    from core.config import RAG_DB, DOC_DIRS, OLLAMA_URL, EMBED_MODEL
    from core.normalizer import normalize_org_content, normalize_markdown_content

def init_rag_schema(db_path: str = RAG_DB):
    os.makedirs(os.path.dirname(db_path), exist_ok=True)
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    cur.execute('''
        CREATE TABLE IF NOT EXISTS doc_files (
            filepath TEXT PRIMARY KEY,
            mtime REAL,
            category TEXT,
            indexed_chunks INTEGER,
            title TEXT
        )
    ''')
    cur.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS doc_chunks USING fts5(
            filepath,
            filename,
            category,
            page_num,
            content,
            tokenize='porter unicode61'
        )
    ''')
    cur.execute('''
        CREATE TABLE IF NOT EXISTS chunk_embeddings (
            chunk_rowid INTEGER PRIMARY KEY,
            embedding BLOB
        )
    ''')
    cur.execute("CREATE INDEX IF NOT EXISTS idx_chunk_embeddings_id ON chunk_embeddings(chunk_rowid)")
    conn.commit()
    conn.close()

def pack_vector(vec: List[float]) -> bytes:
    return struct.pack(f'{len(vec)}f', *vec)

def unpack_vector(blob: bytes) -> List[float]:
    count = len(blob) // 4
    return list(struct.unpack(f'{count}f', blob))

def get_doc_embedding(text: str) -> Optional[List[float]]:
    try:
        clean = text.strip()[:1000]
        if not clean:
            return None
        prompt = f"search_document: {clean}"
        payload = {"model": EMBED_MODEL, "prompt": prompt}
        req = urllib.request.Request(
            f"{OLLAMA_URL}/api/embeddings",
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"}
        )
        with urllib.request.urlopen(req, timeout=4.0) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            vec = data.get("embedding")
            if vec:
                norm = math.sqrt(sum(x * x for x in vec))
                if norm > 0:
                    return [x / norm for x in vec]
    except Exception:
        pass
    return None

# ─────────────────────────────────────────────────────────────────────────────
# PDF Indexing Pipeline
# ─────────────────────────────────────────────────────────────────────────────

def detect_body_page_range(doc: fitz.Document) -> Tuple[int, int]:
    total_pages = len(doc)
    start_page = 1
    end_page = total_pages
    toc = doc.get_toc()
    if toc:
        first_chap_page = None
        last_chap_page = None
        for lvl, title, page in toc:
            t_lower = title.lower()
            if page <= 0:
                continue
            if any(fm in t_lower for fm in ('cover', 'title page', 'copyright', 'contents', 'preface', 'about the author', 'brief contents', 'prelims', 'front matter')):
                continue
            if first_chap_page is None:
                if re.search(r'\b(chapter|part|section)\s*1\b', t_lower) or lvl == 1:
                    first_chap_page = page
            if any(bm in t_lower for bm in ('index', 'subject index', 'author index', 'answers to selected', 'bibliography')):
                if last_chap_page is None or page < last_chap_page:
                    last_chap_page = max(1, page - 1)
        if first_chap_page and first_chap_page > 1:
            start_page = first_chap_page
        if last_chap_page and last_chap_page > start_page:
            end_page = last_chap_page

    if start_page == 1 and total_pages > 40:
        for pno in range(min(35, total_pages)):
            page_text = doc[pno].get_text("text").lower()
            if 'table of contents' in page_text or 'contents\n' in page_text:
                start_page = max(start_page, pno + 2)
            if re.search(r'\bchapter\s+1\b', page_text) or re.search(r'\bintroduction\b', page_text):
                start_page = pno + 1
                break

    return start_page, end_page

def chunk_text_sliding(text: str, max_words: int = 320, overlap: int = 40) -> List[str]:
    words = text.split()
    if not words or len(words) < 20:
        return []
    chunks = []
    i = 0
    while i < len(words):
        chunk_words = words[i:i + max_words]
        chunks.append(" ".join(chunk_words))
        if i + max_words >= len(words):
            break
        i += max_words - overlap
    return chunks

def index_pdf_file(filepath: str, category: str, cur: sqlite3.Cursor) -> int:
    if not fitz:
        return 0
    doc = None
    try:
        doc = fitz.open(filepath)
        filename = os.path.basename(filepath)
        book_title = os.path.splitext(filename)[0].replace('_', ' ').strip()
        toc = doc.get_toc()
        start_page, end_page = detect_body_page_range(doc)

        batch_records = []
        total_chunks = 0

        for pno in range(start_page - 1, end_page):
            page_num = pno + 1
            page = doc[pno]
            raw_text = page.get_text("text").strip()
            if len(raw_text) < 40:
                continue

            # Extract bookmark title
            sec_title = ""
            for lvl, title, p in toc:
                if p <= page_num:
                    sec_title = title.strip()
                else:
                    break

            header_prefix = f"[{book_title}"
            if sec_title:
                header_prefix += f" • {sec_title}"
            header_prefix += f" (p. {page_num})]\n"

            chunks = chunk_text_sliding(raw_text, max_words=320, overlap=40)
            for chunk in chunks:
                full_content = header_prefix + chunk
                batch_records.append((filepath, filename, category, str(page_num), full_content))

        if batch_records:
            cur.executemany('''
                INSERT INTO doc_chunks (filepath, filename, category, page_num, content)
                VALUES (?, ?, ?, ?, ?)
            ''', batch_records)
            total_chunks = len(batch_records)

        return total_chunks
    except Exception:
        return 0
    finally:
        if doc is not None:
            try:
                doc.close()
            except Exception:
                pass

# ─────────────────────────────────────────────────────────────────────────────
# Org-Mode, Markdown & Note Indexing Pipeline
# ─────────────────────────────────────────────────────────────────────────────

def index_note_file(filepath: str, category: str, cur: sqlite3.Cursor) -> int:
    try:
        with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
            raw_text = f.read()
    except Exception:
        return 0

    if len(raw_text.strip()) < 30:
        return 0

    filename = os.path.basename(filepath)
    fp_lower = filepath.lower()

    if fp_lower.endswith('.org'):
        normalized = normalize_org_content(raw_text)
    elif fp_lower.endswith('.md'):
        normalized = normalize_markdown_content(raw_text)
    else:
        normalized = raw_text.strip()

    if len(normalized) < 25:
        return 0

    title = os.path.splitext(filename)[0].replace('_', ' ').replace('-', ' ').title()
    lines = raw_text.splitlines()
    batch_records = []

    # Section-based chunking using headers (# or * or empty line blocks)
    current_sec = title
    current_lines = []
    start_line_no = 1

    for line_idx, line in enumerate(lines, 1):
        # Header detection
        is_org_head = line.startswith('*') and re.match(r'^\*+\s+', line)
        is_md_head = line.startswith('#') and re.match(r'^#+\s+', line)

        if (is_org_head or is_md_head) and current_lines:
            content_str = "\n".join(current_lines).strip()
            if len(content_str.split()) >= 15:
                header_prefix = f"[{title} • {current_sec} (line {start_line_no})]\n"
                batch_records.append((filepath, filename, category, str(start_line_no), header_prefix + content_str))
            current_lines = [line]
            current_sec = line.lstrip('*# ').strip()
            start_line_no = line_idx
        else:
            current_lines.append(line)
            # Break large sections into ~300 word chunks
            if len(" ".join(current_lines).split()) >= 320:
                content_str = "\n".join(current_lines).strip()
                header_prefix = f"[{title} • {current_sec} (line {start_line_no})]\n"
                batch_records.append((filepath, filename, category, str(start_line_no), header_prefix + content_str))
                current_lines = current_lines[-15:]  # small line overlap
                start_line_no = line_idx

    if current_lines:
        content_str = "\n".join(current_lines).strip()
        if len(content_str.split()) >= 15:
            header_prefix = f"[{title} • {current_sec} (line {start_line_no})]\n"
            batch_records.append((filepath, filename, category, str(start_line_no), header_prefix + content_str))

    if batch_records:
        cur.executemany('''
            INSERT INTO doc_chunks (filepath, filename, category, page_num, content)
            VALUES (?, ?, ?, ?, ?)
        ''', batch_records)
        return len(batch_records)

    return 0

# ─────────────────────────────────────────────────────────────────────────────
# Incremental & Auto-Indexing API
# ─────────────────────────────────────────────────────────────────────────────

def get_category_for_path(filepath: str) -> str:
    """Infer document category from path or extension."""
    fp_lower = filepath.lower()
    for cat_name, base_dir in DOC_DIRS:
        try:
            if os.path.commonpath([filepath, base_dir]) == base_dir:
                return cat_name
        except ValueError:
            continue
    if fp_lower.endswith(".pdf"):
        return "books"
    if fp_lower.endswith((".org", ".md", ".txt")):
        return "notes"
    return "documents"

def index_file_incremental(filepath: str, force: bool = False, db_path: str = RAG_DB) -> Dict[str, Any]:
    """
    Incrementally indexes or updates a single file (.pdf, .org, .md, .txt) in SQLite FTS5
    and immediately computes & saves its dense vector embeddings.
    Safe for on-demand indexing when hovering or opening a new document.
    """
    if not os.path.isfile(filepath):
        return {"status": "error", "message": f"File not found: {filepath}"}

    ext = os.path.splitext(filepath)[1].lower()
    if ext not in ('.pdf', '.org', '.md', '.txt'):
        return {"status": "skipped", "message": f"Unsupported extension: {ext}"}

    init_rag_schema(db_path)
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    try:
        mtime = os.path.getmtime(filepath)
    except OSError as e:
        conn.close()
        return {"status": "error", "message": str(e)}

    # Check existing index status
    cur.execute("SELECT mtime, indexed_chunks FROM doc_files WHERE filepath = ?", (filepath,))
    row = cur.fetchone()
    if row and not force and row[0] == mtime and row[1] > 0:
        conn.close()
        return {"status": "unchanged", "chunks": row[1], "filepath": filepath}

    category = get_category_for_path(filepath)
    filename = os.path.basename(filepath)
    title = os.path.splitext(filename)[0].replace('_', ' ').strip()

    # Clean existing chunks and embeddings for this file
    cur.execute("SELECT rowid FROM doc_chunks WHERE filepath = ?", (filepath,))
    old_rowids = [r[0] for r in cur.fetchall()]
    if old_rowids:
        cur.executemany("DELETE FROM chunk_embeddings WHERE chunk_rowid = ?", [(rid,) for rid in old_rowids])
    cur.execute("DELETE FROM doc_chunks WHERE filepath = ?", (filepath,))
    cur.execute("DELETE FROM doc_files WHERE filepath = ?", (filepath,))

    # Parse and chunk document
    if ext == '.pdf':
        chunks_count = index_pdf_file(filepath, category, cur)
    else:
        chunks_count = index_note_file(filepath, category, cur)

    # ALWAYS record in doc_files (even if chunks_count == 0) to avoid infinite re-scanning loops
    cur.execute('''
        INSERT OR REPLACE INTO doc_files (filepath, mtime, category, indexed_chunks, title)
        VALUES (?, ?, ?, ?, ?)
    ''', (filepath, mtime, category, chunks_count, title))
    conn.commit()

    new_embeddings = 0
    if chunks_count > 0:
        # Compute embeddings for new chunks immediately
        cur.execute("SELECT rowid, content FROM doc_chunks WHERE filepath = ?", (filepath,))
        new_chunks = cur.fetchall()
        embed_records = []
        for rowid, content in new_chunks:
            vec = get_doc_embedding(content)
            if vec:
                embed_records.append((rowid, pack_vector(vec)))
                new_embeddings += 1

        if embed_records:
            cur.executemany("INSERT OR REPLACE INTO chunk_embeddings (chunk_rowid, embedding) VALUES (?, ?)", embed_records)
            conn.commit()

    conn.close()
    return {
        "status": "indexed",
        "filepath": filepath,
        "filename": filename,
        "category": category,
        "chunks": chunks_count,
        "embeddings": new_embeddings
    }

def scan_and_index_changes(force: bool = False, max_files_per_pass: int = 50) -> Dict[str, Any]:
    """
    Scans DOC_DIRS and auto-indexes any newly created or modified files.
    """
    init_rag_schema()
    conn = sqlite3.connect(RAG_DB)
    cur = conn.cursor()

    cur.execute("SELECT filepath, mtime FROM doc_files")
    indexed_map = {row[0]: row[1] for row in cur.fetchall()}
    conn.close()

    changed_files = []
    for cat_name, base_dir in DOC_DIRS:
        if not os.path.isdir(base_dir):
            continue
        for root, _, files in os.walk(base_dir):
            for fn in files:
                ext = os.path.splitext(fn)[1].lower()
                if ext in ('.pdf', '.org', '.md', '.txt'):
                    fp = os.path.join(root, fn)
                    try:
                        mtime = os.path.getmtime(fp)
                    except OSError:
                        continue
                    if force or fp not in indexed_map or indexed_map[fp] != mtime:
                        changed_files.append(fp)
                        if len(changed_files) >= max_files_per_pass:
                            break
            if len(changed_files) >= max_files_per_pass:
                break

    stats = {"files_checked": len(indexed_map), "files_updated": 0, "total_chunks": 0}
    for fp in changed_files:
        res = index_file_incremental(fp, force=force)
        if res.get("status") == "indexed":
            stats["files_updated"] += 1
            stats["total_chunks"] += res.get("chunks", 0)

    # Release any unused C/heap memory back to the Linux kernel immediately
    import gc
    gc.collect()
    try:
        import ctypes
        ctypes.CDLL('libc.so.6').malloc_trim(0)
    except Exception:
        pass

    return stats

_WATCHER_THREAD = None
_WATCHER_STOP_EVENT = None

def start_auto_indexer_background(interval_seconds: float = 180.0):
    """Start low-priority background daemon thread to monitor and auto-index changed files."""
    global _WATCHER_THREAD, _WATCHER_STOP_EVENT
    import threading

    if _WATCHER_THREAD and _WATCHER_THREAD.is_alive():
        return

    _WATCHER_STOP_EVENT = threading.Event()

    def _watcher_loop():
        # Initial delay on server start
        time.sleep(10.0)
        while not _WATCHER_STOP_EVENT.is_set():
            try:
                res = scan_and_index_changes(force=False, max_files_per_pass=20)
                if res.get("files_updated", 0) > 0 and res.get("total_chunks", 0) > 0:
                    print(f"🔄 [Minimo Auto-Indexer] Updated {res['files_updated']} file(s) ({res['total_chunks']} chunks).")
            except Exception:
                pass
            _WATCHER_STOP_EVENT.wait(interval_seconds)

    _WATCHER_THREAD = threading.Thread(target=_watcher_loop, daemon=True, name="MinimoAutoIndexer")
    _WATCHER_THREAD.start()
    print(f"✓ Minimo Auto-Indexer background service started (polling every {interval_seconds}s).")

# ─────────────────────────────────────────────────────────────────────────────
# Unified Indexer Orchestrator
# ─────────────────────────────────────────────────────────────────────────────

def run_unified_indexing(force: bool = False, max_embed_chunks: int = 2500) -> Dict[str, Any]:
    """
    Scans and indexes all PDFs, Org, Markdown, and text documents across DOC_DIRS.
    Ensures vector embeddings are generated and stored in chunk_embeddings.
    """
    init_rag_schema()
    conn = sqlite3.connect(RAG_DB)
    cur = conn.cursor()

    indexed_counts = {"pdfs": 0, "notes": 0, "new_chunks": 0, "new_embeddings": 0}
    seen_paths = set()

    print("🚀 Starting Minimo Unified Knowledge Indexer...")
    start_t = time.time()

    # Discover files
    files_to_process = []
    for cat_name, base_dir in DOC_DIRS:
        if not os.path.isdir(base_dir):
            continue
        for root, _, files in os.walk(base_dir):
            for fn in files:
                ext = os.path.splitext(fn)[1].lower()
                if ext in ('.pdf', '.org', '.md', '.txt'):
                    fp = os.path.join(root, fn)
                    if fp not in seen_paths:
                        seen_paths.add(fp)
                        files_to_process.append((fp, cat_name, ext))

    print(f"Found {len(files_to_process)} candidate documents across knowledge directories.")

    # Process files
    for fp, cat, ext in files_to_process:
        try:
            mtime = os.path.getmtime(fp)
        except OSError:
            continue

        cur.execute("SELECT mtime, indexed_chunks FROM doc_files WHERE filepath = ?", (fp,))
        row = cur.fetchone()
        if row and not force and row[0] == mtime:
            continue

        # Clear existing chunks for modified file
        cur.execute("DELETE FROM doc_chunks WHERE filepath = ?", (fp,))
        cur.execute("DELETE FROM doc_files WHERE filepath = ?", (fp,))

        filename = os.path.basename(fp)
        title = os.path.splitext(filename)[0].replace('_', ' ').strip()

        if ext == '.pdf':
            chunks = index_pdf_file(fp, cat, cur)
            indexed_counts["pdfs"] += 1
        else:
            chunks = index_note_file(fp, "notes" if "org" in fp else cat, cur)
            indexed_counts["notes"] += 1

        if chunks > 0:
            cur.execute('''
                INSERT OR REPLACE INTO doc_files (filepath, mtime, category, indexed_chunks, title)
                VALUES (?, ?, ?, ?, ?)
            ''', (fp, mtime, cat, chunks, title))
            indexed_counts["new_chunks"] += chunks

    conn.commit()
    print(f"Index stage complete: {indexed_counts['new_chunks']} chunks stored in FTS5.")

    # ─────────────────────────────────────────────────────────────────────────
    # Vector Embedding Generation Stage
    # ─────────────────────────────────────────────────────────────────────────
    cur.execute('''
        SELECT doc_chunks.rowid, doc_chunks.content
        FROM doc_chunks
        LEFT JOIN chunk_embeddings ON doc_chunks.rowid = chunk_embeddings.chunk_rowid
        WHERE chunk_embeddings.chunk_rowid IS NULL
        LIMIT ?
    ''', (max_embed_chunks,))
    missing_chunks = cur.fetchall()

    if missing_chunks:
        print(f"Generating dense Nomic embeddings for {len(missing_chunks)} chunks...")
        embed_records = []
        for rowid, content in missing_chunks:
            vec = get_doc_embedding(content)
            if vec:
                embed_records.append((rowid, pack_vector(vec)))
                indexed_counts["new_embeddings"] += 1

            if len(embed_records) >= 100:
                cur.executemany("INSERT OR REPLACE INTO chunk_embeddings (chunk_rowid, embedding) VALUES (?, ?)", embed_records)
                conn.commit()
                embed_records = []

        if embed_records:
            cur.executemany("INSERT OR REPLACE INTO chunk_embeddings (chunk_rowid, embedding) VALUES (?, ?)", embed_records)
            conn.commit()

    conn.close()
    elapsed = time.time() - start_t
    print(f"✓ Unified indexing completed in {elapsed:.1f}s: {indexed_counts}")
    return indexed_counts

if __name__ == "__main__":
    force_run = "--force" in sys.argv
    run_unified_indexing(force=force_run)
