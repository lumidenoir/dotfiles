"""
Minimo Brain Suite - Todoist & Local Tasks Client with Offline SQLite Outbox
"""

import os
import time
import json
import sqlite3
import subprocess
from typing import List, Dict, Any, Optional
from .config import TASKS_SCRIPT

CACHE_FILE = os.path.expanduser("~/.cache/quickshell/tasks_cache.json")
OFFLINE_DB_PATH = os.path.expanduser("~/.cache/quickshell/offline_tasks.db")

def _init_offline_db():
    os.makedirs(os.path.dirname(OFFLINE_DB_PATH), exist_ok=True)
    with sqlite3.connect(OFFLINE_DB_PATH) as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS offline_tasks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                due TEXT,
                priority INTEGER,
                description TEXT,
                created_at REAL,
                synced INTEGER DEFAULT 0
            )
        """)
        conn.commit()

def queue_offline_task(title: str, due: Optional[str] = None, priority: Optional[int] = None, description: Optional[str] = None) -> Dict[str, Any]:
    """Store task in local SQLite outbox when offline."""
    _init_offline_db()
    now = time.time()
    with sqlite3.connect(OFFLINE_DB_PATH) as conn:
        cur = conn.execute(
            "INSERT INTO offline_tasks (title, due, priority, description, created_at, synced) VALUES (?, ?, ?, ?, ?, 0)",
            (title, due or "", priority or 4, description or "", now)
        )
        task_id = f"offline_{cur.lastrowid}"
        conn.commit()
    return {
        "id": task_id,
        "content": title,
        "due": due or "",
        "priority": priority or 4,
        "description": description or "",
        "offline_queued": True
    }

def get_offline_tasks() -> List[Dict[str, Any]]:
    """Retrieve unsynced offline tasks."""
    if not os.path.isfile(OFFLINE_DB_PATH):
        return []
    try:
        with sqlite3.connect(OFFLINE_DB_PATH) as conn:
            conn.row_factory = sqlite3.Row
            rows = conn.execute("SELECT * FROM offline_tasks WHERE synced = 0 ORDER BY created_at ASC").fetchall()
            return [
                {
                    "id": f"offline_{r['id']}",
                    "content": f"[Offline] {r['title']}",
                    "due": r["due"] or "",
                    "priority": r["priority"] or 4,
                    "description": r["description"] or "",
                    "offline_queued": True
                }
                for r in rows
            ]
    except Exception:
        return []

def sync_offline_tasks() -> int:
    """Attempt to push queued offline tasks to Todoist."""
    if not os.path.isfile(OFFLINE_DB_PATH) or not os.path.isfile(TASKS_SCRIPT):
        return 0
    synced_count = 0
    try:
        with sqlite3.connect(OFFLINE_DB_PATH) as conn:
            conn.row_factory = sqlite3.Row
            rows = conn.execute("SELECT * FROM offline_tasks WHERE synced = 0").fetchall()
            for r in rows:
                payload = json.dumps({
                    "title": r["title"],
                    "due": r["due"] or None,
                    "priority": r["priority"] or None,
                    "description": r["description"] or None
                })
                try:
                    res = subprocess.check_output(
                        ["python3", TASKS_SCRIPT, "--add-json", payload],
                        timeout=6
                    ).decode("utf-8")
                    data = json.loads(res)
                    if data.get("tasks"):
                        conn.execute("UPDATE offline_tasks SET synced = 1 WHERE id = ?", (r["id"],))
                        synced_count += 1
                except Exception:
                    # Still offline or error; stop attempting for now
                    break
            conn.commit()
    except Exception:
        pass
    return synced_count

def get_tasks() -> List[Dict[str, Any]]:
    # 1. Attempt non-blocking drain of offline tasks if any exist
    try:
        sync_offline_tasks()
    except Exception:
        pass

    # 2. Fast path: Read cache file directly if fresh (< 45s)
    tasks = []
    try:
        if os.path.isfile(CACHE_FILE):
            mtime = os.path.getmtime(CACHE_FILE)
            if (time.time() - mtime) < 45.0:
                with open(CACHE_FILE, "r") as f:
                    data = json.load(f)
                    tasks = data.get("tasks", [])
    except Exception:
        pass

    if not tasks and os.path.isfile(TASKS_SCRIPT):
        try:
            res = subprocess.check_output(["python3", TASKS_SCRIPT, "--get"], timeout=8).decode('utf-8')
            data = json.loads(res)
            tasks = data.get("tasks", [])
        except Exception:
            pass

    # 3. Prepend any remaining unsynced offline tasks so the user sees them
    offline = get_offline_tasks()
    return offline + tasks

def add_task(title: str, due: Optional[str] = None, priority: Optional[int] = None, description: Optional[str] = None) -> Optional[Dict[str, Any]]:
    # If tasks script is missing or Todoist call fails, cleanly queue offline
    if not os.path.isfile(TASKS_SCRIPT):
        return queue_offline_task(title, due, priority, description)

    try:
        if due or priority or description:
            payload = json.dumps({"title": title, "due": due, "priority": priority, "description": description})
            res = subprocess.check_output(["python3", TASKS_SCRIPT, "--add-json", payload], timeout=8).decode('utf-8')
        else:
            res = subprocess.check_output(["python3", TASKS_SCRIPT, "--add", title], timeout=8).decode('utf-8')
        data = json.loads(res)
        tasks = data.get("tasks", [])
        norm = title.strip().lower()
        if norm:
            for t in reversed(tasks):
                t_cnt = (t.get("content") or "").strip().lower()
                if t_cnt and (t_cnt == norm or (len(norm) >= 3 and norm in t_cnt) or (len(t_cnt) >= 3 and t_cnt in norm)):
                    return t
        return tasks[-1] if tasks else {"content": title, "priority": priority or 4, "due": due or "", "description": description or ""}
    except Exception:
        # Fallback to local SQLite outbox queue
        return queue_offline_task(title, due, priority, description)

def toggle_task(task_id: str) -> bool:
    if not os.path.isfile(TASKS_SCRIPT):
        return False
    try:
        subprocess.check_call(["python3", TASKS_SCRIPT, "--toggle", task_id], timeout=8)
        return True
    except Exception:
        return False

def delete_task(task_id: str) -> bool:
    if not os.path.isfile(TASKS_SCRIPT):
        return False
    try:
        subprocess.check_call(["python3", TASKS_SCRIPT, "--delete", task_id], timeout=8)
        return True
    except Exception:
        return False
