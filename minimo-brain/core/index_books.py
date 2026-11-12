#!/usr/bin/env python3
"""
Minimo Brain Suite - Intelligent High-Performance PDF Book Indexer (PyMuPDF)
- Parses PDF outline bookmarks (TOC) to detect structure and section titles.
- Automatically cuts initial front-matter (TOC, preface, copyright) and back-matter (index, bibliography).
- Splits conceptual text into semantic ~350-word chunks with heading breadcrumbs.
- Populates library_rag.db (FTS5 + chunk metadata) safely with transaction batching.
"""

import os
import sys
import re
import sqlite3
import time
from typing import List, Dict, Any, Tuple, Optional

try:
    import fitz  # PyMuPDF
except ImportError:
    print("Error: PyMuPDF is required. Run 'pip install pymupdf' or 'paru -S python-pymupdf'")
    sys.exit(1)

DB_PATH = os.path.expanduser("~/.local/share/quickshell/library_rag.db")
BOOKS_DIR = os.path.expanduser("~/org/books")

def init_db(db_path: str = DB_PATH):
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
    conn.commit()
    conn.close()

def detect_body_page_range(doc: fitz.Document) -> Tuple[int, int]:
    """
    Analyzes document outline (bookmarks) and text heuristics to determine
    the first true body chapter page and the last content page (cutting TOC and Index).
    Returns (start_page, end_page) 1-indexed.
    """
    total_pages = len(doc)
    start_page = 1
    end_page = total_pages

    toc = doc.get_toc()
    if toc:
        # Search for first chapter / part
        first_chap_page = None
        last_chap_page = None
        for lvl, title, page in toc:
            t_lower = title.lower()
            if page <= 0:
                continue
            
            # Skip front-matter items in outline
            if any(fm in t_lower for fm in ('cover', 'title page', 'copyright', 'contents', 'preface', 'about the author', 'brief contents', 'prelims', 'preliminary', 'front matter')):
                continue
            
            if first_chap_page is None:
                # Look for Chapter 1, Part 1, or first substantive entry
                if re.search(r'\b(chapter|part|section)\s*1\b', t_lower) or lvl == 1:
                    first_chap_page = page
            
            # Detect back-matter index/bibliography
            if any(bm in t_lower for bm in ('index', 'subject index', 'author index', 'answers to selected', 'bibliography')):
                if last_chap_page is None or page < last_chap_page:
                    last_chap_page = max(1, page - 1)

        if first_chap_page and first_chap_page > 1:
            start_page = first_chap_page
        if last_chap_page and last_chap_page > start_page:
            end_page = last_chap_page

    # Fallback heuristic if no TOC outline exists:
    if start_page == 1 and total_pages > 40:
        # Check first 35 pages for TOC markers
        for pno in range(min(35, total_pages)):
            page_text = doc[pno].get_text("text").lower()
            if 'table of contents' in page_text or 'contents\n' in page_text:
                start_page = max(start_page, pno + 2)
            if re.search(r'\bchapter\s+1\b', page_text) or re.search(r'\bintroduction\b', page_text):
                start_page = pno + 1
                break

    return start_page, end_page

def extract_section_title_for_page(toc: List[List[Any]], page_num: int) -> str:
    """Find the most specific bookmark title covering page_num."""
    current_title = ""
    for lvl, title, p in toc:
        if p <= page_num:
            current_title = title.strip()
        else:
            break
    return current_title

def chunk_page_text(text: str, max_words: int = 350, overlap: int = 50) -> List[str]:
    """Sliding-window chunker with word overlap."""
    words = text.split()
    if not words or len(words) < 25:
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

def index_pdf_book(filepath: str, category: str = "books", force: bool = False) -> int:
    """Index a single PDF book with front-matter cutting and outline tagging."""
    if not os.path.isfile(filepath):
        print(f"File not found: {filepath}")
        return 0

    init_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    mtime = os.path.getmtime(filepath)
    cur.execute("SELECT mtime, indexed_chunks FROM doc_files WHERE filepath = ?", (filepath,))
    row = cur.fetchone()
    if row and not force and row[0] == mtime:
        print(f"Skipping already indexed file: {os.path.basename(filepath)} ({row[1]} chunks)")
        conn.close()
        return 0

    try:
        doc = fitz.open(filepath)
    except Exception as e:
        print(f"Failed to open PDF {filepath}: {e}")
        conn.close()
        return 0

    filename = os.path.basename(filepath)
    book_title = os.path.splitext(filename)[0].replace('_', ' ').strip()
    toc = doc.get_toc()

    start_page, end_page = detect_body_page_range(doc)
    print(f"Indexing '{book_title}' (Pages {start_page} to {end_page} of {len(doc)})...")

    # Clear previous chunks for this file
    cur.execute("DELETE FROM doc_chunks WHERE filepath = ?", (filepath,))
    cur.execute("DELETE FROM doc_files WHERE filepath = ?", (filepath,))

    total_chunks = 0
    batch_records = []

    for pno in range(start_page - 1, end_page):
        page_num = pno + 1
        page = doc[pno]
        raw_text = page.get_text("text").strip()
        if len(raw_text) < 40:
            continue

        sec_title = extract_section_title_for_page(toc, page_num)
        header_prefix = f"[{book_title}"
        if sec_title:
            header_prefix += f" • {sec_title}"
        header_prefix += f" (p. {page_num})]\n"

        page_chunks = chunk_page_text(raw_text, max_words=320, overlap=40)
        for chunk in page_chunks:
            full_content = header_prefix + chunk
            batch_records.append((filepath, filename, category, str(page_num), full_content))

        if len(batch_records) >= 500:
            cur.executemany('''
                INSERT INTO doc_chunks (filepath, filename, category, page_num, content)
                VALUES (?, ?, ?, ?, ?)
            ''', batch_records)
            total_chunks += len(batch_records)
            batch_records = []

    if batch_records:
        cur.executemany('''
            INSERT INTO doc_chunks (filepath, filename, category, page_num, content)
            VALUES (?, ?, ?, ?, ?)
        ''', batch_records)
        total_chunks += len(batch_records)

    cur.execute('''
        INSERT OR REPLACE INTO doc_files (filepath, mtime, category, indexed_chunks, title)
        VALUES (?, ?, ?, ?, ?)
    ''', (filepath, mtime, category, total_chunks, book_title))

    conn.commit()
    conn.close()
    print(f"Indexed '{filename}': {total_chunks} chunks.")
    return total_chunks

if __name__ == "__main__":
    if len(sys.argv) > 1:
        target = sys.argv[1]
        if os.path.isfile(target):
            index_pdf_book(target, force=True)
        else:
            print(f"Path not found: {target}")
    else:
        print("Usage: python3 index_books.py <path_to_pdf>")
