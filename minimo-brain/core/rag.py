"""
Minimo Brain Suite - High Performance Hybrid RAG (FTS5 + Dense Nomic Vectors)
"""

import os
import re
import math
import struct
import sqlite3
import json
import urllib.request
from typing import List, Dict, Any, Optional
from .config import RAG_DB, MINDSPACE_DB, DOC_DIRS, OLLAMA_URL, EMBED_MODEL
from .normalizer import normalize_chunk_by_path

# Query expansion synonyms for technical concepts
SYNONYM_MAP = {
    'pid': ['pid controller', 'proportional integral derivative', 'control loop'],
    'controller': ['feedback controller', 'pid', 'lead lag compensator', 'transfer function'],
    'transfer function': ['laplace transform', 'frequency response', 'bode plot'],
    'stability': ['routh hurwitz', 'nyquist criterion', 'phase margin', 'gain margin'],
    'bode': ['frequency response', 'magnitude phase plot', 'gain margin'],
    'nyquist': ['nyquist plot', 'encirclement', 'cauchy argument principle'],
    'thermodynamics': ['enthalpy', 'entropy', 'first law', 'carnot cycle', 'heat engine'],
    'entropy': ['second law', 'irreversibility', 'clausius inequality', 't-s diagram'],
    'carnot': ['carnot efficiency', 'reversible engine', 'refrigeration cycle'],
    'rankine': ['rankine cycle', 'steam power plant', 'reheat cycle', 'superheat'],
    'otto': ['otto cycle', 'spark ignition', 'compression ratio', 'four stroke'],
    'diesel': ['diesel cycle', 'compression ignition', 'cutoff ratio'],
    'brayton': ['gas turbine cycle', 'isentropic compressor', 'combustor'],
    'fluid mechanics': ['navier stokes', 'reynolds number', 'bernoulli equation', 'viscosity'],
    'bernoulli': ['energy equation', 'streamline flow', 'pressure head', 'venturi'],
    'reynolds': ['laminar flow', 'turbulent flow', 'critical reynolds number'],
    'boundary layer': ['prandtl boundary layer', 'skin friction', 'boundary layer thickness'],
    'navier stokes': ['momentum equation', 'viscous flow', 'continuity equation'],
    'stress': ['strain', 'youngs modulus', 'mohrs circle', 'von mises'],
    'mohr': ['principal stress', 'maximum shear stress', 'stress transformation'],
    'heat transfer': ['conduction', 'convection', 'radiation', 'fourier law', 'nusselt'],
    'conduction': ['fourier law of heat conduction', 'thermal conductivity', 'steady state'],
    'convection': ['newtons law of cooling', 'nusselt number', 'heat transfer coefficient'],
    'radiation': ['stefan boltzmann', 'emissivity', 'blackbody radiation', 'planck law'],
}

def expand_query(query: str) -> List[str]:
    q_lower = query.lower()
    expanded = list(re.findall(r'\b[A-Za-z0-9_]{3,}\b', query))
    for key, synonyms in SYNONYM_MAP.items():
        if key in q_lower:
            expanded.extend(synonyms)
        else:
            for syn in synonyms:
                if syn.lower() in q_lower:
                    expanded.append(key)
                    break
    seen, out = set(), []
    stopwords = {'the', 'and', 'for', 'are', 'was', 'has', 'with', 'this', 'that', 'from', 'open', 'book', 'pdf', 'show', 'what', 'read', 'there', 'any', 'books'}
    for t in expanded:
        tl = t.lower()
        if tl not in seen and tl not in stopwords:
            seen.add(tl)
            out.append(t)
    return out[:12]

def get_embedding(text: str, prefix: str = "search_query: ") -> Optional[List[float]]:
    try:
        clean_text = text.strip()[:1000]
        if not clean_text:
            return None
        if prefix and not clean_text.startswith(("search_query:", "search_document:", "clustering:", "classification:")):
            clean_text = f"{prefix.strip()} {clean_text}"
        payload = {"model": EMBED_MODEL, "prompt": clean_text}
        req = urllib.request.Request(
            f"{OLLAMA_URL}/api/embeddings",
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"}
        )
        with urllib.request.urlopen(req, timeout=3.5) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            vec = data.get("embedding")
            if vec:
                norm = math.sqrt(sum(x * x for x in vec))
                if norm > 0:
                    return [x / norm for x in vec]
    except Exception:
        pass
    return None

def pack_vector(vec: List[float]) -> bytes:
    return struct.pack(f'{len(vec)}f', *vec)

def unpack_vector(blob: bytes) -> List[float]:
    count = len(blob) // 4
    return list(struct.unpack(f'{count}f', blob))

def is_low_quality_or_toc(content: str, page_num: str, filepath: str) -> bool:
    """
    Detects Table of Contents, front-matter series, copyright, preface, and junk chunks.
    Prevents textbook TOC listings from burying actual conceptual explanations.
    """
    text = (content or "").strip()
    if len(text) < 35:
        return True
    if text.startswith("||||||") or text.startswith("Book Title:"):
        return True
    
    # Table of contents dot leaders (e.g. 'Chapter 3 ........... 84' or '. . . . 84')
    if len(re.findall(r'(?:\.\s*){3,}\d+', text)) >= 2:
        return True

    lower = text.lower()
    
    # Global TOC headers regardless of page number
    if any(h in lower for h in ('table of contents', 'brief contents', 'contents in detail')):
        return True

    # Book front-matter filter
    is_pdf = filepath.lower().endswith('.pdf')
    try:
        p = int(page_num)
    except Exception:
        p = 999

    # Most academic textbooks have 20-35 pages of front-matter (preface, TOC, acknowledgments)
    if is_pdf and p <= 35:
        front_matter_markers = (
            'table of contents', 'contents\n', 'contents \n', 'library of congress',
            'cataloging-in-publication', 'all rights reserved', 'praise for',
            'series of textbooks', 'isbn: 0-', 'isbn: 978', 'isbn 978', 'published by',
            'printed in the united states', 'brief contents', 'preface\n', 'preface \n',
            'to the instructor', 'acknowledgements', 'acknowledgments', 'about the authors',
            'financial support provided by', 'intended primarily as an introductory text',
            'order of coverage', 'end of each chapter', 'at the end of chapters',
            'the book is intended', 'in this text', 'this edition', 'coverage is gradual'
        )
        if any(marker in lower for marker in front_matter_markers):
            return True
        # Series listing pattern: e.g. '37. Potential Flows: ... 38. Computer-Aided Graphics'
        if len(re.findall(r'^\s*\d+\.\s+[A-Z]', text, re.M)) >= 3:
            return True
        # High density of lines ending with page numbers (typical of TOCs without dot leaders)
        lines = [l.strip() for l in text.splitlines() if l.strip()]
        if len(lines) >= 3:
            num_ending = sum(1 for l in lines if re.search(r'\b\d{1,4}$', l))
            if (num_ending / len(lines)) > 0.35:
                return True

    return False

_EMBEDDING_CACHE = {"mtime": 0.0, "ids": [], "mat": None}

def load_embedding_matrix(conn: sqlite3.Connection):
    """Cached in-memory normalized embedding matrix for sub-millisecond vector similarity."""
    global _EMBEDDING_CACHE
    if not os.path.isfile(RAG_DB):
        return [], None
    try:
        mtime = os.path.getmtime(RAG_DB)
        if _EMBEDDING_CACHE["mat"] is not None and _EMBEDDING_CACHE["mtime"] == mtime:
            return _EMBEDDING_CACHE["ids"], _EMBEDDING_CACHE["mat"]
        
        cur = conn.cursor()
        cur.execute("SELECT chunk_rowid, embedding FROM chunk_embeddings")
        rows = cur.fetchall()
        if not rows:
            return [], None
        
        ids = [r[0] for r in rows]
        blobs = [r[1] for r in rows]
        import numpy as np
        mat = np.frombuffer(b''.join(blobs), dtype=np.float32).copy().reshape(len(blobs), -1)
        norms = np.linalg.norm(mat, axis=1, keepdims=True)
        norms[norms == 0] = 1.0
        mat /= norms

        _EMBEDDING_CACHE = {"mtime": mtime, "ids": ids, "mat": mat}
        return ids, mat
    except Exception:
        return [], None

def search_library_rag(
    query: str,
    limit: int = 5,
    category_filter: Optional[str] = None,
    filepath_filter: Optional[str] = None
) -> List[Dict[str, Any]]:
    """
    Dual-Channel Hybrid Search:
      Channel 1: BM25 / SQLite FTS5 (Sparse Keyword Retrieval)
      Channel 2: Nomic Dense Vector Embeddings (Semantic Cosine Retrieval)
      Fusion: Reciprocal Rank Fusion (RRF) with Note Context Boost
      Reranking: ONNX Cross-Encoder (ms-marco-MiniLM-L-6-v2)
      Citations: Explicit File and Page/Line structured citations
    """
    if filepath_filter and os.path.isfile(filepath_filter):
        try:
            from .unified_indexer import index_file_incremental
            index_file_incremental(filepath_filter)
        except Exception:
            pass

    if not os.path.isfile(RAG_DB):
        return []

    conn = sqlite3.connect(RAG_DB)
    cur = conn.cursor()

    cur.execute("PRAGMA table_info(doc_chunks)")
    cols = [col[1] for col in cur.fetchall()]
    if not cols:
        conn.close()
        return []

    has_content = "content" in cols
    content_idx = cols.index("content") if has_content else 4

    candidates_map: Dict[int, Dict[str, Any]] = {}

    # ─────────────────────────────────────────────────────────────
    # Channel 1: BM25 Keyword Search (FTS5)
    # ─────────────────────────────────────────────────────────────
    tokens = expand_query(query)
    if not tokens:
        tokens = [t for t in re.findall(r'\b[A-Za-z0-9_]{3,}\b', query) if t.lower() not in ('open', 'book', 'pdf', 'the', 'what', 'read', 'show')]

    if tokens:
        fts_match = ' OR '.join([f'"{t}"*' for t in tokens[:8]])
        try:
            if filepath_filter:
                sql = f'''
                    SELECT rowid, filepath, filename, category, page_num,
                           snippet(doc_chunks, {content_idx}, '«', '»', '...', 22),
                           content, rank
                    FROM doc_chunks
                    WHERE doc_chunks MATCH ? AND filepath = ?
                    ORDER BY rank
                    LIMIT 40
                '''
                cur.execute(sql, (fts_match, filepath_filter))
            else:
                sql = f'''
                    SELECT rowid, filepath, filename, category, page_num,
                           snippet(doc_chunks, {content_idx}, '«', '»', '...', 22),
                           content, rank
                    FROM doc_chunks
                    WHERE doc_chunks MATCH ?
                    ORDER BY rank
                    LIMIT 40
                '''
                cur.execute(sql, (fts_match,))
            for bm_rank, row in enumerate(cur.fetchall(), 1):
                row_id = row[0]
                fp = row[1]
                fn = row[2]
                cat = row[3]
                p_num = str(row[4])
                raw_content = row[6] if len(row) > 6 and row[6] else ""
                norm_content = normalize_chunk_by_path(raw_content, fp)

                if len(norm_content) < 25 or is_low_quality_or_toc(norm_content, p_num, fp):
                    continue

                snip = row[5] or (norm_content[:200] if norm_content else "")
                candidates_map[row_id] = {
                    "rowid": row_id,
                    "filepath": fp,
                    "filename": fn,
                    "category": cat,
                    "page": p_num,
                    "snippet": snip,
                    "content": norm_content,
                    "bm25_rank": bm_rank,
                    "bm25_score": abs(row[7]) if len(row) > 7 and row[7] is not None else 1.0
                }
        except Exception:
            pass

    # ─────────────────────────────────────────────────────────────
    # Channel 2: Dense Semantic Vector Search (Nomic Embeddings)
    # ─────────────────────────────────────────────────────────────
    try:
        query_vec = get_embedding(query)
        if query_vec:
            ids, mat = load_embedding_matrix(conn)
            if mat is not None and len(ids) > 0:
                import numpy as np
                q_arr = np.array(query_vec, dtype=np.float32)
                q_norm = q_arr / (np.linalg.norm(q_arr) or 1.0)
                sims = np.dot(mat, q_norm)
                top_k_indices = np.argsort(sims)[::-1][:35]

                vector_missing_ids = []
                for v_rank, idx in enumerate(top_k_indices, 1):
                    cid = ids[idx]
                    sim = float(sims[idx])
                    if sim < 0.28:
                        break
                    if cid in candidates_map:
                        candidates_map[cid]["vector_rank"] = v_rank
                        candidates_map[cid]["cosine_sim"] = sim
                    else:
                        vector_missing_ids.append((cid, v_rank, sim))

                # Hydrate metadata for vector hits that weren't in BM25 results
                if vector_missing_ids:
                    id_to_vinfo = {cid: (vr, sm) for cid, vr, sm in vector_missing_ids}
                    placeholders = ','.join('?' * len(id_to_vinfo))
                    if filepath_filter:
                        cur.execute(f'''
                            SELECT rowid, filepath, filename, category, page_num, content
                            FROM doc_chunks
                            WHERE rowid IN ({placeholders}) AND filepath = ?
                        ''', list(id_to_vinfo.keys()) + [filepath_filter])
                    else:
                        cur.execute(f'''
                            SELECT rowid, filepath, filename, category, page_num, content
                            FROM doc_chunks
                            WHERE rowid IN ({placeholders})
                        ''', list(id_to_vinfo.keys()))
                    for row in cur.fetchall():
                        cid = row[0]
                        fp = row[1]
                        fn = row[2]
                        cat = row[3]
                        p_num = str(row[4])
                        raw_content = row[5] or ""
                        norm_content = normalize_chunk_by_path(raw_content, fp)

                        if len(norm_content) < 25 or is_low_quality_or_toc(norm_content, p_num, fp):
                            continue

                        vr, sm = id_to_vinfo.get(cid, (40, 0.3))
                        candidates_map[cid] = {
                            "rowid": cid,
                            "filepath": fp,
                            "filename": fn,
                            "category": cat,
                            "page": p_num,
                            "snippet": norm_content[:200],
                            "content": norm_content,
                            "vector_rank": vr,
                            "cosine_sim": sm
                        }
    except Exception:
        pass

    if not candidates_map:
        conn.close()
        return []

    # ─────────────────────────────────────────────────────────────
    # Fusion: Reciprocal Rank Fusion (RRF) & Filtering
    # ─────────────────────────────────────────────────────────────
    scored_candidates = []
    for cid, c in candidates_map.items():
        fp = c['filepath']
        if filepath_filter and fp != filepath_filter:
            continue
        is_note = fp.lower().endswith(('.org', '.md', '.txt')) or c.get('category') in ('notes', 'note')
        if category_filter == "notes" and not is_note:
            continue
        if category_filter == "books" and is_note:
            continue

        bm_rank = c.get('bm25_rank', 60)
        vec_rank = c.get('vector_rank', 60)
        cosine = c.get('cosine_sim', 0.0)

        # RRF formula blending sparse keyword rank + dense semantic rank + direct cosine similarity
        rrf_score = (1.0 / (40 + bm_rank)) + (1.0 / (40 + vec_rank)) + (0.22 * max(0.0, cosine))

        # Contextual boost for user's personal notes
        if is_note:
            rrf_score *= 1.15

        c['score'] = rrf_score
        scored_candidates.append(c)

    scored_candidates.sort(key=lambda x: x['score'], reverse=True)

    # Deduplication & Diversity: at most 2 chunks per file, no duplicate pages
    seen_file_pages = set()
    file_hit_counts = {}
    deduped_candidates = []

    for c in scored_candidates:
        fp = c['filepath']
        page = c['page']
        key = (fp, page)
        if key in seen_file_pages:
            continue
        if not filepath_filter and file_hit_counts.get(fp, 0) >= 2:
            continue
        seen_file_pages.add(key)
        file_hit_counts[fp] = file_hit_counts.get(fp, 0) + 1
        deduped_candidates.append(c)

    # ─────────────────────────────────────────────────────────────
    # Stage 2: ONNX Cross-Encoder Reranking
    # ─────────────────────────────────────────────────────────────
    from .reranker import get_reranker
    reranker = get_reranker()
    final_results = reranker.rerank(query, deduped_candidates[:16], top_k=limit, threshold=0.15)
    if not final_results:
        final_results = deduped_candidates[:limit]

    # Attach explicit citations with file and page/line
    for r in final_results:
        fp = r.get('filepath', '')
        is_note = fp.lower().endswith(('.org', '.md', '.txt')) or r.get('category') in ('notes', 'note')
        p_num = str(r.get('page', '1'))
        r['is_note'] = is_note
        r['page'] = p_num
        if is_note:
            r['citation'] = f"{r['filename']} (Line {p_num})"
            r['badge'] = f"NOTE · L{p_num}"
            r['action_type'] = "open_note"
        else:
            r['citation'] = f"{r['filename']} (Page {p_num})"
            r['badge'] = f"PDF · p. {p_num}"
            r['action_type'] = "open_book"
        r['action_payload'] = f"{fp}:::{p_num}"

    conn.close()
    return final_results

def search_mindspace(query: str, limit: int = 5) -> List[Dict[str, Any]]:
    if not os.path.exists(MINDSPACE_DB):
        return []
    results = []
    try:
        conn = sqlite3.connect(MINDSPACE_DB)
        cur = conn.cursor()
        q_tokens = [t for t in re.split(r'[^a-z0-9_]+', query.lower()) if len(t) >= 2]
        is_recency = any(w in query.lower() for w in ('last', 'latest', 'recent', 'recently', 'newest', 'yesterday', 'today'))
        
        if not q_tokens:
            cur.execute('SELECT id, title, content, source_app, tags, created_at FROM stash_items ORDER BY id DESC LIMIT ?', (limit,))
            rows = cur.fetchall()
        else:
            fts_query = ' OR '.join([f'"{t}"' for t in q_tokens[:5]])
            order = 's.id DESC' if is_recency else 'rank'
            try:
                cur.execute(f'''
                    SELECT s.id, s.title, s.content, s.source_app, s.tags, s.created_at
                    FROM stash_fts f
                    JOIN stash_items s ON f.rowid = s.id
                    WHERE stash_fts MATCH ?
                    ORDER BY {order} LIMIT ?
                ''', (fts_query, limit))
                rows = cur.fetchall()
            except Exception:
                rows = []

        for row in rows:
            results.append({
                "id": row[0],
                "title": row[1] or "Stash Note",
                "content": (row[2] or "").strip(),
                "app": row[3] or "Desktop",
                "tags": row[4] or "",
                "date": str(row[5])[:16] if row[5] else ""
            })
        conn.close()
    except Exception:
        pass
    return results
