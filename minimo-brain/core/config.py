"""
Minimo Brain Suite - Configuration & System Context
"""

import os
import time
import subprocess
import urllib.request
import json
from typing import List, Tuple

USER = os.environ.get('USER', 'krishna')
HOST = "0.0.0.0"
PORT = 8088

OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://127.0.0.1:11434")
SYNTHESIS_MODEL = "qwen2.5:3b"
ROUTER_MODEL = "qwen2.5:1.5b-instruct"
# Primary text retrieval embedding model (8192 token context, 274MB RAM, English MTEB ~62.3).
# Future multimodal upgrade path: "embeddinggemma-2" (768d, 1.3GB) if indexing screenshots, diagrams, and audio.
EMBED_MODEL = "nomic-embed-text"

MINDSPACE_DB = os.path.expanduser("~/.local/share/quickshell/mindspace.db")
RAG_DB = os.path.expanduser("~/.local/share/quickshell/library_rag.db")
TASKS_SCRIPT = os.path.expanduser("~/dotfiles/scripts/tasks_manager.py")

MOVIE_DIRS = [
    "/mnt/shared/Movies",
    f"/run/media/{USER}/7958-E812/movie",
    os.path.expanduser("~/Videos/Movies"),
    os.path.expanduser("~/Movies"),
    os.path.expanduser("~/Videos"),
]
VIDEO_EXTS = ('.mkv', '.mp4', '.avi', '.webm', '.mov', '.m4v')

DOC_DIRS: List[Tuple[str, str]] = [
    ("notes", os.path.expanduser("~/org")),
    ("obsidian", os.path.expanduser("~/org/obsidian")),
    ("books", os.path.expanduser("~/org/books")),
    ("college", os.path.expanduser("~/org/college")),
    ("documents", os.path.expanduser("~/Documents")),
    ("shared_notes", "/mnt/shared/org"),
    ("shared_obsidian", "/mnt/shared/org/obsidian"),
    ("shared_books", "/mnt/shared/org/books"),
    ("shared_college", "/mnt/shared/org/college"),
]

def get_tailscale_ip() -> str:
    """Returns Tailscale IPv4 address if active, else localhost."""
    try:
        out = subprocess.check_output(["tailscale", "ip", "-4"], text=True, timeout=1.5).strip()
        if out:
            return out
    except Exception:
        pass
    return "127.0.0.1"

_MODEL_CACHE = {"models": [], "ts": 0}

def get_available_models(ttl_seconds: float = 60.0) -> List[str]:
    """Fetch available Ollama models with in-memory TTL caching."""
    now = time.time()
    if _MODEL_CACHE["models"] and (now - _MODEL_CACHE["ts"]) < ttl_seconds:
        return _MODEL_CACHE["models"]
    try:
        req = urllib.request.Request(f"{OLLAMA_URL}/api/tags")
        with urllib.request.urlopen(req, timeout=1.0) as r:
            data = json.loads(r.read().decode('utf-8'))
            models = [m.get("name", "") for m in data.get("models", [])]
            _MODEL_CACHE["models"] = models
            _MODEL_CACHE["ts"] = now
            return models
    except Exception:
        pass
    return _MODEL_CACHE["models"]

def get_router_model() -> str:
    models = get_available_models()
    if any("qwen2.5:1.5b" in m for m in models):
        return "qwen2.5:1.5b-instruct"
    return ROUTER_MODEL

def get_synthesis_model() -> str:
    models = get_available_models()
    if any("qwen2.5:3b" in m for m in models):
        return "qwen2.5:3b"
    if any("qwen2.5:1.5b" in m for m in models):
        return "qwen2.5:1.5b-instruct"
    return SYNTHESIS_MODEL
