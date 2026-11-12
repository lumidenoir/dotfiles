"""
Minimo Brain Suite - High-Speed Prompt Table Storage (Tier 0 Fast Path)
Provides sub-millisecond (< 0.05ms) SQLite-backed intent and shortcut resolution.
Bypasses LLM compute entirely for common commands, system controls, greetings, and user macros.
"""

import os
import re
import sqlite3
import threading
from typing import Dict, Any, Optional, List

DB_PATH = os.environ.get("MINIMO_PROMPT_DB", os.path.expanduser("~/.config/minimo/prompt_table.sqlite3"))
_LOCAL = threading.local()

def _get_connection() -> sqlite3.Connection:
    """Thread-local SQLite connection with WAL mode and memory pragmas for microsecond lookups."""
    if not hasattr(_LOCAL, "conn") or _LOCAL.conn is None:
        conn = None
        try:
            os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
            c = sqlite3.connect(DB_PATH, timeout=5.0)
            c.row_factory = sqlite3.Row
            c.execute("PRAGMA journal_mode=WAL")
            # Verify database is writable
            c.execute("CREATE TABLE IF NOT EXISTS _test_write_perm (id INTEGER PRIMARY KEY)")
            conn = c
        except Exception:
            fallback_path = "/tmp/minimo_prompt_table.sqlite3"
            conn = sqlite3.connect(fallback_path, timeout=5.0)
            conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA synchronous=NORMAL")
        conn.execute("PRAGMA temp_store=MEMORY")
        conn.execute("PRAGMA cache_size=-2000")
        _LOCAL.conn = conn
    return _LOCAL.conn

def init_prompt_table():
    """Create schema and seed system default fast-path triggers."""
    conn = _get_connection()
    try:
        _setup_schema(conn)
    except sqlite3.OperationalError:
        # Fallback to /tmp if main db is read-only in sandbox/test environments
        fallback_path = "/tmp/minimo_prompt_table.sqlite3"
        conn = sqlite3.connect(fallback_path, timeout=5.0)
        conn.row_factory = sqlite3.Row
        _LOCAL.conn = conn
        _setup_schema(conn)

def _setup_schema(conn: sqlite3.Connection):
    with conn:
        conn.execute("""
        CREATE TABLE IF NOT EXISTS prompt_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            trigger_phrase TEXT UNIQUE NOT NULL,
            match_type TEXT NOT NULL DEFAULT 'exact', -- 'exact', 'prefix', 'regex'
            intent TEXT NOT NULL,
            action_type TEXT,
            action_payload TEXT,
            direct_response TEXT,
            is_system BOOLEAN DEFAULT 0,
            hit_count INTEGER DEFAULT 0,
            last_used_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """)
        conn.execute("CREATE INDEX IF NOT EXISTS idx_prompt_trigger ON prompt_table(trigger_phrase)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_prompt_match_type ON prompt_table(match_type)")

    # System built-in prompts
    defaults = [
        # 1. Greetings & Instant Persona Dialogue (0ms response)
        ("hi", "exact", "chat", "direct_dialogue", "", "Hey Krishna! How can I help you today?", 1),
        ("hello", "exact", "chat", "direct_dialogue", "", "Hello Krishna. What shall we arrange today?", 1),
        ("hey", "exact", "chat", "direct_dialogue", "", "Hey there. Ready when you are.", 1),
        ("who are you", "exact", "chat", "direct_dialogue", "", "I'm Kafka, your personal desktop pilot on Hyprland.", 1),
        

        # 3. Tasks & Todoist Immediate Fetch
        ("tasks", "exact", "list_tasks", "fetch_tasks", "", None, 1),
        ("my tasks", "exact", "list_tasks", "fetch_tasks", "", None, 1),
        ("show tasks", "exact", "list_tasks", "fetch_tasks", "", None, 1),
        ("show my tasks", "exact", "list_tasks", "fetch_tasks", "", None, 1),
        ("list tasks", "exact", "list_tasks", "fetch_tasks", "", None, 1),
        ("todo", "exact", "list_tasks", "fetch_tasks", "", None, 1),
        ("todos", "exact", "list_tasks", "fetch_tasks", "", None, 1),
        ("pending tasks", "exact", "list_tasks", "fetch_tasks", "", None, 1),

        # 4. Email Inquiries
        ("emails", "exact", "email_summary", "fetch_emails", "", None, 1),
        ("my emails", "exact", "email_summary", "fetch_emails", "", None, 1),
        ("inbox", "exact", "email_summary", "fetch_emails", "", None, 1),
        ("check mail", "exact", "email_summary", "fetch_emails", "", None, 1),
        ("check emails", "exact", "email_summary", "fetch_emails", "", None, 1),

        # 5. Horizon & Weather
        ("weather", "exact", "daily_horizon", "horizon", "", None, 1),
        ("forecast", "exact", "daily_horizon", "horizon", "", None, 1),
        ("daily horizon", "exact", "daily_horizon", "horizon", "", None, 1),
        ("morning briefing", "exact", "daily_horizon", "horizon", "", None, 1)
    ]

    with conn:
        for trig, m_type, intent, a_type, a_payload, d_resp, is_sys in defaults:
            conn.execute("""
            INSERT OR IGNORE INTO prompt_table 
            (trigger_phrase, match_type, intent, action_type, action_payload, direct_response, is_system)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (trig, m_type, intent, a_type, a_payload, d_resp, is_sys))

def lookup_prompt(query: str) -> Optional[Dict[str, Any]]:
    """
    Sub-millisecond prompt lookup.
    Returns structured intent payload if hit, else None.
    """
    q_clean = (query or "").strip().lower()
    if not q_clean:
        return None

    conn = _get_connection()
    cur = conn.cursor()

    # Step 1: Exact match lookup (fastest, O(1) B-Tree index lookup, ~0.005ms)
    cur.execute("""
    SELECT trigger_phrase, match_type, intent, action_type, action_payload, direct_response
    FROM prompt_table
    WHERE trigger_phrase = ?
    LIMIT 1
    """, (q_clean,))
    row = cur.fetchone()

    # Step 2: Prefix / Regex matching fallback
    if not row:
        cur.execute("""
        SELECT trigger_phrase, match_type, intent, action_type, action_payload, direct_response
        FROM prompt_table
        WHERE match_type IN ('prefix', 'regex')
        """)
        for candidate in cur.fetchall():
            m_type = candidate["match_type"]
            trig = candidate["trigger_phrase"]
            if m_type == "prefix" and q_clean.startswith(trig):
                row = candidate
                break
            elif m_type == "regex":
                try:
                    if re.search(trig, q_clean):
                        row = candidate
                        break
                except re.error:
                    continue

    if row:
        # Asynchronously or quickly bump hit count
        try:
            with conn:
                conn.execute("""
                UPDATE prompt_table 
                SET hit_count = hit_count + 1, last_used_at = CURRENT_TIMESTAMP
                WHERE trigger_phrase = ?
                """, (row["trigger_phrase"],))
        except Exception:
            pass

        return {
            "hit": True,
            "trigger": row["trigger_phrase"],
            "intent": row["intent"],
            "action_type": row["action_type"],
            "action_payload": row["action_payload"],
            "direct_response": row["direct_response"],
            "confidence": 1.0,
            "source": "prompt_table"
        }

    return None

def upsert_custom_prompt(
    trigger: str,
    intent: str,
    action_type: Optional[str] = None,
    action_payload: Optional[str] = None,
    direct_response: Optional[str] = None,
    match_type: str = "exact"
) -> bool:
    """Allow user or agent to record new custom macros and shortcuts into the prompt table."""
    conn = _get_connection()
    try:
        with conn:
            conn.execute("""
            INSERT INTO prompt_table (trigger_phrase, match_type, intent, action_type, action_payload, direct_response, is_system)
            VALUES (?, ?, ?, ?, ?, ?, 0)
            ON CONFLICT(trigger_phrase) DO UPDATE SET
                match_type = excluded.match_type,
                intent = excluded.intent,
                action_type = excluded.action_type,
                action_payload = excluded.action_payload,
                direct_response = excluded.direct_response
            """, (trigger.strip().lower(), match_type, intent, action_type, action_payload, direct_response))
        return True
    except Exception:
        return False

def list_all_prompts() -> List[Dict[str, Any]]:
    """Retrieve all prompt table entries for settings UI or CLI management."""
    conn = _get_connection()
    cur = conn.cursor()
    cur.execute("""
    SELECT trigger_phrase, match_type, intent, action_type, action_payload, direct_response, is_system, hit_count, last_used_at
    FROM prompt_table
    ORDER BY hit_count DESC, trigger_phrase ASC
    """)
    return [dict(r) for r in cur.fetchall()]

# Ensure initialization on import
init_prompt_table()
