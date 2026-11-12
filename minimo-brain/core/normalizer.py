"""
Minimo Brain Suite - Document Normalizer & Data Cleaning Pipeline
Standardizes heterogeneous knowledge sources (.org, .md, .pdf) into clean,
unified semantic text for FTS5 indexing, vector embeddings, and synthesis.
"""

import re
from typing import Optional

def normalize_org_content(text: str) -> str:
    """
    Standardize Emacs Org-mode and Org-Roam documents:
    - Strips property drawers (:PROPERTIES: ... :END:)
    - Extracts and cleans #+TITLE: and other directives
    - Unpacks Org-Roam internal links [[id:UUID][Label]] -> Label
    - Strips logbooks and drawer metadata
    """
    if not text:
        return ""
    
    # 1. Remove property drawers (:PROPERTIES: ... :END:)
    cleaned = re.sub(r':PROPERTIES:[\s\S]*?:END:', '', text, flags=re.I)
    
    # 2. Remove logbook drawers (:LOGBOOK: ... :END:)
    cleaned = re.sub(r':LOGBOOK:[\s\S]*?:END:', '', cleaned, flags=re.I)
    
    # 3. Unpack Org-roam links: [[id:UUID][Display Title]] -> Display Title
    cleaned = re.sub(r'\[\[(?:id:[a-f0-9\-]+|file:[^\]]+)\]\[([^\]]+)\]\]', r'\1', cleaned, flags=re.I)
    # Unpack simple bracket links: [[URL][Title]] -> Title
    cleaned = re.sub(r'\[\[[^\]]+\]\[([^\]]+)\]\]', r'\1', cleaned)
    # Remove naked link references [[id:UUID]]
    cleaned = re.sub(r'\[\[(?:id:[a-f0-9\-]+|file:[^\]]+)\]\]', '', cleaned, flags=re.I)
    
    # 4. Extract and clean #+TITLE: before stripping directives
    title_match = re.search(r'^\s*#\+TITLE:\s*(.+)$', cleaned, re.M | re.I)
    doc_title = title_match.group(1).strip() if title_match else ""
    
    # 5. Remove Org directive lines (#+DATE:, #+AUTHOR:, #+STARTUP:, #+HUGO_SECTION:, etc.)
    cleaned = re.sub(r'^\s*#\+[A-Za-z0-9_\-]+:.*$', '', cleaned, flags=re.M)
    
    # 6. Convert Org headings (* Heading, ** Subheading) to Markdown (# Heading, ## Subheading)
    cleaned = re.sub(r'^(\*+)\s+', lambda m: '#' * len(m.group(1)) + ' ', cleaned, flags=re.M)
    
    # 7. Prepend clean title if available and not already in text
    if doc_title and doc_title.lower() not in cleaned[:80].lower():
        cleaned = f"[{doc_title}]\n{cleaned}"
        
    return re.sub(r'\n{3,}', '\n\n', cleaned).strip()

def normalize_markdown_content(text: str) -> str:
    """
    Standardize Markdown and Obsidian documents:
    - Strips YAML front-matter (--- ... ---)
    - Unpacks Obsidian wikilinks [[Target|Alias]] -> Alias, [[Target]] -> Target
    """
    if not text:
        return ""
    
    # 1. Strip YAML frontmatter
    cleaned = re.sub(r'^---\s*\n[\s\S]*?\n---\s*\n', '', text, flags=re.M)
    
    # 2. Unpack Obsidian wikilinks: [[Target|Alias]] -> Alias
    cleaned = re.sub(r'\[\[[^\]\|]+\|([^\]]+)\]\]', r'\1', cleaned)
    # Unpack simple wikilinks: [[Target]] -> Target
    cleaned = re.sub(r'\[\[([^\]]+)\]\]', r'\1', cleaned)
    
    return re.sub(r'\n{3,}', '\n\n', cleaned).strip()

def normalize_pdf_content(text: str) -> str:
    """
    Standardize raw PDF text extracted from academic textbooks & papers:
    - Re-attaches hyphenated line breaks (e.g. 'ad- \n iabatic' -> 'adiabatic')
    - Removes isolated page numbers and running headers
    - Collapses abnormal whitespace and control characters
    """
    if not text:
        return ""
        
    # 1. Remove non-alphanumeric noise blocks (cover bars ||||||||)
    cleaned = re.sub(r'[\|_=\-]{6,}', ' ', text)
    
    # 2. Repair hyphenated word wrap: 'com- \n pressible' -> 'compressible'
    cleaned = re.sub(r'(\b[a-zA-Z]{2,})-\s*\n\s*([a-zA-Z]{2,}\b)', r'\1\2', cleaned)
    
    # 3. Remove isolated page numbers on their own lines (e.g. '  42  ')
    cleaned = re.sub(r'^\s*\d{1,4}\s*$', '', cleaned, flags=re.M)
    
    # 4. Standardize whitespace while preserving paragraph breaks
    lines = [re.sub(r'[ \t]+', ' ', l).strip() for l in cleaned.split('\n')]
    cleaned = '\n'.join(lines)
    
    return re.sub(r'\n{3,}', '\n\n', cleaned).strip()

def normalize_chunk_by_path(content: str, filepath: str) -> str:
    """
    Universal normalizer router based on file extension.
    Ensures embeddings and FTS match clean conceptual tokens.
    """
    fp_lower = filepath.lower()
    if fp_lower.endswith('.org'):
        return normalize_org_content(content)
    elif fp_lower.endswith(('.md', '.markdown')):
        return normalize_markdown_content(content)
    elif fp_lower.endswith('.pdf'):
        return normalize_pdf_content(content)
    return content.strip()
