"""
Minimo Brain Suite - Unified Desktop Agent Engine (Kafka Persona)
Powers the Quickshell dynamic island, desktop synthesis, and situational tool calling.
Features server-side session memory persistence across popup toggles,
offline-aware task management, and rich bidirectional action feedback.
"""

import os
import re
import time
import json
import random
import asyncio
import logging
import urllib.request
from typing import Dict, Any, List, Optional, AsyncGenerator

logger = logging.getLogger("desktop_agent")

from .config import OLLAMA_URL, get_router_model
from .decomposer import decompose_query
from .context_rewriter import rewrite_conversational_context
from .router import route_intent
from .prompt_table import lookup_prompt
from .tasks import get_tasks, add_task, toggle_task, delete_task
from .media import (
    search_local_movies, resolve_music_intent, play_mpd_playlist,
    play_mpd_song, optimize_youtube_query, play_youtube_audio,
    mpris_control, stop_all_audio
)
from .emails import fetch_recent_emails, build_email_digest_prompt, get_maildir_sync_status
from .system_context import get_daily_horizon_data, get_active_window_info
from .pdf_context import get_active_or_hovered_pdf
from .rag import search_library_rag, search_mindspace
from .synthesis import (
    stream_synthesis_async, stream_chat_async, stream_email_synthesis_async,
    clean_math_notation
)
from .executor import execute_desktop_action, run_command_safe

# =====================================================================
# Kafka Dynamic Voice Lines & Multi-Phrase Pools (Honkai: Star Rail)
# =====================================================================
KAFKA_ROUTING_PHRASES = [
    "⚡ Listen... I'm reading where your thoughts are heading.",
    "⚡ Patience. Let's see what the script has laid out for us.",
    "⚡ A curious query. Allow me to weave the threads.",
    "⚡ Don't fret. I know exactly where this belongs.",
    "⚡ Tracing the pattern of your question...",
]

KAFKA_TODOIST_SYNC_PHRASES = [
    "󰄬 Aligning your agenda with the script...",
    "󰄬 Reviewing your commitments. Shall we check what's due?",
    "󰄬 Let's see what threads are still untangled in your tasks.",
    "󰄬 Syncing Todoist... Every deadline has its place.",
]

KAFKA_MAILBOX_PHRASES = [
    "📬 Sifting through your correspondence...",
    "📬 Let's see what demands your attention today.",
    "📬 Scanning your mail... I'll highlight what truly matters.",
    "📬 Reading between the lines of your inbox...",
]

KAFKA_NOTES_SEARCH_PHRASES = [
    "🔍 Consulting the script... I see all your threads.",
    "🔍 Scanning through the records. Every secret leaves a trace.",
    "🔍 Tracing your archives... Nothing stays hidden from me.",
    "🔍 Flipping through your volumes... Let's find what you need.",
]

KAFKA_TASK_ADDED_TITLES = [
    "Boom. Written into the script.",
    "Consider it arranged.",
    "Tied to your strings now.",
    "I've noted that down for you.",
    "Another thread woven in.",
]

# =====================================================================
# Server-Side Ephemeral Session Store (30-Minute Inactivity TTL)
# =====================================================================
SESSION_TTL_SECONDS = 1800.0  # 30 minutes
_SESSION_STORE: Dict[str, Dict[str, Any]] = {}

def get_session_history(session_id: str = "hyprland_desktop") -> List[Dict[str, str]]:
    """Retrieve warm session history, auto-expiring after 30 minutes of inactivity."""
    entry = _SESSION_STORE.get(session_id)
    if not entry:
        return []
    if (time.time() - entry.get("last_seen", 0.0)) > SESSION_TTL_SECONDS:
        _SESSION_STORE.pop(session_id, None)
        return []
    return entry.get("history", [])

def update_session_history(session_id: str, query: str, answer: str):
    """Store conversational turn in the warm session cache."""
    now = time.time()
    entry = _SESSION_STORE.setdefault(session_id, {"history": [], "last_seen": now})
    entry["last_seen"] = now
    hist = entry["history"]
    hist.append({"q": query, "a": answer})
    if len(hist) > 20:
        entry["history"] = hist[-20:]

def clear_session(session_id: str = "hyprland_desktop"):
    """Reset session conversation state."""
    _SESSION_STORE.pop(session_id, None)


# =====================================================================
# Dual-Process Routing: System 1 (Reflex) & System 2 (Direct Cognitive Agent)
# =====================================================================
DIRECT_AGENT_PROMPT = (
    "You are Minimo MindPilot (Kafka persona), an intelligent desktop AI co-pilot on Hyprland.\n"
    "Your role: directly select the single best action, extract clean parameters, and output valid JSON.\n\n"
    "Available Actions:\n"
    "- 'rag_knowledge': General knowledge, code generation, writing code or scripts (MATLAB, Python, C++, Bash, Rust, etc.), graph plotting, formulas, math, physics, technical concepts, notes/books search. params: {\"search_query\": \"...\"}\n"
    "- 'add_task': Creating a personal todo, task, reminder, or scheduling errands (e.g. 'remind me to...', 'buy milk', 'schedule dentist'). NEVER route requests to write code, solve problems, plot graphs, or explain concepts to add_task! params: {\"title\": \"...\", \"due\": \"...\"|null, \"priority\": 1|2|3|4, \"description\": \"...\"}\n"
    "- 'play_media': Watching local anime, movies, series. params: {\"media_title\": \"...\"}\n"
    "- 'email_summary': Checking unread inbox or summarizing recent emails. params: {\"limit\": 5, \"query_desc\": \"recent emails\"}\n"
    "- 'run_cmd': Executing shell commands. Synthesize the exact, syntactically correct, idiomatic Linux/bash command (e.g. colloquial 'git porcelain command' -> 'git status --porcelain', 'disk space' -> 'df -h'). params: {\"command\": \"...\", \"description\": \"...\", \"risk\": \"safe\"|\"mutating\"|\"dangerous\"}\n"
    "- 'daily_horizon': Morning briefing, weather and agenda. params: {}\n"
    "- 'chat': Casual greetings and conversational banter. params: {}\n"
    "- 'clarify': ONLY when a query is genuinely ambiguous, contradictory, or missing critical targets. params: {\"question\": \"...\", \"options\": [...]}\n\n"
    "Few-Shot Examples:\n"
    "Q: 'write a code for matlab polyfit and graphs plotting'\n"
    "JSON: {\"thought\": \"User wants MATLAB code written for polynomial curve fitting and graph plotting.\", \"action\": \"rag_knowledge\", \"confidence\": 0.99, \"params\": {\"search_query\": \"matlab polyfit and plotting code\"}, \"needs_clarification\": false}\n\n"
    "Q: 'write a python function to parse json logs'\n"
    "JSON: {\"thought\": \"User wants a Python function written.\", \"action\": \"rag_knowledge\", \"confidence\": 0.99, \"params\": {\"search_query\": \"python function to parse json logs\"}, \"needs_clarification\": false}\n\n"
    "Q: 'what is supersonic oblique shock'\n"
    "JSON: {\"thought\": \"Direct conceptual physics inquiry.\", \"action\": \"rag_knowledge\", \"confidence\": 0.98, \"params\": {\"search_query\": \"what is supersonic oblique shock\"}, \"needs_clarification\": false}\n\n"
    "Q: 'remind me to fix the waybar battery widget crash tomorrow at 5pm p1'\n"
    "JSON: {\"thought\": \"Task creation with title, deadline, priority.\", \"action\": \"add_task\", \"confidence\": 0.98, \"params\": {\"title\": \"Fix waybar battery widget crash\", \"due\": \"tomorrow at 5pm\", \"priority\": 1, \"description\": \"Waybar battery widget crashing.\"}, \"needs_clarification\": false}\n\n"
    "Q: 'run git porcelain command'\n"
    "JSON: {\"thought\": \"User wants git status in machine-readable porcelain format.\", \"action\": \"run_cmd\", \"confidence\": 0.98, \"params\": {\"command\": \"git status --porcelain\", \"description\": \"Show git repository status in compact porcelain format\", \"risk\": \"safe\"}, \"needs_clarification\": false}\n\n"
    "Q: 'summary of latest email'\n"
    "JSON: {\"thought\": \"User requested a summary of the single latest email.\", \"action\": \"email_summary\", \"confidence\": 0.98, \"params\": {\"limit\": 1, \"query_desc\": \"latest email\"}, \"needs_clarification\": false}\n\n"
    "Q: 'cancel that'\n"
    "JSON: {\"thought\": \"Ambiguous target without clear entity.\", \"action\": \"clarify\", \"confidence\": 0.5, \"params\": {\"question\": \"What would you like to cancel?\", \"options\": [{\"label\": \"Cancel last pending task\", \"query\": \"cancel task\"}, {\"label\": \"Dismiss notification\", \"query\": \"dismiss\"}]}, \"needs_clarification\": true}\n\n"
    "Output strictly valid JSON only: {\"thought\": \"...\", \"action\": \"...\", \"confidence\": 0.95, \"params\": {...}, \"needs_clarification\": false}\n"
)

def check_reflex_fast_path(query: str) -> Optional[Dict[str, Any]]:
    """
    System 1: Sub-millisecond Reflex Fast-Path (< 0.1ms).
    Handles exact prompt table hits, media controls, status views, and direct CLI shortcuts
    without invoking an LLM.
    """
    q_strip = query.strip()
    if not q_strip:
        return None
    q_lower = q_strip.lower()

    # 1. Exact Prompt Table Lookup (< 0.1ms)
    fast_hit = lookup_prompt(query)
    if fast_hit:
        if fast_hit.get("direct_response"):
            return {
                "intent": fast_hit["intent"],
                "direct_response": fast_hit["direct_response"],
                "confidence": 1.0,
                "source": "prompt_table"
            }
        if fast_hit.get("intent") in ("mpris_control", "play_music"):
            return None
        return {
            "intent": fast_hit["intent"],
            "confidence": 1.0,
            "source": "prompt_table"
        }

    # 2. Direct Status Views (0ms)
    list_exact = {
        "tasks", "task", "todo", "todoist", "todoist tasks", "my tasks",
        "pending tasks", "list tasks", "show tasks", "view tasks", "get tasks",
        "check tasks", "show todoist", "todoist list"
    }
    if q_lower in list_exact:
        return {"intent": "list_tasks", "confidence": 1.0, "source": "reflex_tasks"}

    morning_exact = {
        "good morning", "morning", "daily horizon", "horizon",
        "morning briefing", "daily briefing", "morning summary", "brief me"
    }
    if q_lower in morning_exact:
        return {"intent": "daily_horizon", "confidence": 1.0, "source": "reflex_horizon"}

    window_exact = {
        "active window", "current window", "what am i doing", "what is on screen",
        "what window is this", "window info", "focused window", "active app"
    }
    if q_lower in window_exact:
        return {"intent": "active_window", "confidence": 1.0, "source": "reflex_window"}

    # 3. Direct Email Views & Summaries (0ms)
    email_fast_regex = r"\b(?:what\s+are\s+(?:the\s+)?emails|summarize\s+(?:my\s+|the\s+)?emails?|(?:summary|digest)\s+of\s+(?:my\s+|the\s+|latest\s+|newest\s+|recent\s+)?emails?|check\s+(?:my\s+)?(?:inbox|emails?)|(?:any\s+)?(?:new\s+)?emails?\s+(?:from\s+)?(?:the\s+)?(?:last|past)\s+\d+\s*(?:hours?|hrs?|mins?|minutes?)|(?:any\s+)?(?:new\s+)?emails?\s+today|(?:last|top|first)\s+\d+\s+emails?|(?:latest|newest|most\s+recent|last)\s+email|email\s+summary|inbox\s+summary)\b"
    if bool(re.search(email_fast_regex, q_lower)):
        from .emails import parse_email_query_params
        p = parse_email_query_params(q_strip)
        return {"intent": "email_summary", "email_params": p, "confidence": 1.0, "source": "reflex_email"}

    # 4. Direct Shell Prefixes (0ms)
    if q_strip.startswith(("$ ", "$", "! ", "!")):
        cmd = q_strip.lstrip("$! ").strip()
        if cmd:
            return {"intent": "run_cmd", "command": cmd, "confidence": 1.0, "source": "reflex_cmd"}

    # 5. Direct Task Complete / Delete (0ms)
    m_comp = re.search(r"^(?:please\s+)?(?:complete|finish|done\s+with|check\s+off)\s+(?:task\s+)?(.+)", q_strip, re.I)
    if m_comp:
        return {"intent": "complete_task", "task_target": m_comp.group(1).strip(), "confidence": 1.0, "source": "reflex_task_action"}
    m_del = re.search(r"^(?:please\s+)?(?:delete|remove)\s+(?:task\s+)?(.+)", q_strip, re.I)
    if m_del:
        return {"intent": "delete_task", "task_target": m_del.group(1).strip(), "confidence": 1.0, "source": "reflex_task_action"}

    return None

def call_direct_cognitive_agent(
    query: str,
    context_history: Optional[List[Dict[str, str]]] = None,
    active_window: Optional[Dict[str, Any]] = None,
    mode: str = "all"
) -> Dict[str, Any]:
    """
    System 2: Single-pass direct cognitive action dispatch with Qwen 2.5.
    Resolves conversational history + Hyprland context and outputs structured action JSON.
    """
    model_name = get_router_model()
    prompt_parts = [DIRECT_AGENT_PROMPT]

    # Inject active window context
    if active_window and (active_window.get("class") or active_window.get("title")):
        w_class = active_window.get("class", "Desktop")
        w_title = active_window.get("title", "")
        prompt_parts.append(f"\nActive Desktop Focus: App='{w_class}', WindowTitle='{w_title}'")

    # Inject conversational turn history
    if context_history and len(context_history) > 0:
        hist_snippet = []
        for turn in context_history[-3:]:
            hist_snippet.append(f"User: {turn.get('q', '')}\nAssistant: {turn.get('a', '')[:120]}")
        prompt_parts.append("\nRecent Conversation History:\n" + "\n---\n".join(hist_snippet))

    prompt_parts.append(f"\nCurrent User Query: \"{query}\"\nJSON:")
    full_prompt = "\n".join(prompt_parts)

    payload = {
        "model": model_name,
        "prompt": full_prompt,
        "format": "json",
        "stream": False,
        "keep_alive": "30m",
        "options": {
            "temperature": 0.0,
            "num_predict": 300
        }
    }

    try:
        req = urllib.request.Request(
            f"{OLLAMA_URL}/api/generate",
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"}
        )
        with urllib.request.urlopen(req, timeout=12.0) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            parsed = json.loads(data.get("response", "{}"))
            action = parsed.get("action", "rag_knowledge")
            params = parsed.get("params", {}) or {}
            conf = float(parsed.get("confidence", 0.90))
            needs_clar = bool(parsed.get("needs_clarification", False)) or (action == "clarify")

            res = {
                "intent": action,
                "confidence": conf,
                "thought": parsed.get("thought", ""),
                "needs_clarification": needs_clar,
                "source": "direct_llm"
            }

            # Guard against small LLM misrouting coding/math requests to add_task
            coding_kw = r"\b(?:code|script|function|program|algorithm|matlab|polyfit|python|rust|c\+\+|numpy|scipy|plot(?:ting)?|graph(?:ing)?|curve\s+fit)\b"
            if action == "add_task" and re.search(coding_kw, query, re.IGNORECASE):
                task_kw = r"\b(?:remind(?:\s+me)?|todo|task|schedule|deadline)\b"
                if not re.search(task_kw, query, re.IGNORECASE):
                    action = "rag_knowledge"
                    res["intent"] = "rag_knowledge"
                    params = {"search_query": query}

            if needs_clar or action == "clarify":
                clar_info = params.get("clarification") or parsed.get("clarification") or {}
                res["intent"] = "clarify"
                res["prompt"] = clar_info.get("question") or params.get("question") or f"Could you clarify what you'd like to do with '{query}'?"
                res["options"] = clar_info.get("options") or params.get("options") or [
                    {"label": f"✓ Proceed with '{query}'", "query": query},
                    {"label": "✗ Cancel Action", "query": "cancel"}
                ]
                return res

            # Map parameters into routed dictionary for downstream tool executors
            if action == "add_task":
                res["task_title"] = params.get("title") or query
                res["task_due"] = params.get("due")
                res["task_priority"] = params.get("priority", 4)
                res["task_description"] = params.get("description")
            elif action == "play_media":
                res["media_title"] = params.get("media_title") or query
            elif action == "email_summary":
                limit_val = params.get("limit")
                q_lower = query.lower()
                is_singular = bool(re.search(r'\b(?:latest|newest|most recent|last)\s+email\b', q_lower) and not re.search(r'\b(?:last|past)\s+\d+', q_lower))
                if is_singular or limit_val == 1:
                    limit_val = 1
                    q_desc = "latest email"
                else:
                    limit_val = limit_val or 5
                    q_desc = params.get("query_desc", "recent emails")

                res["email_params"] = {
                    "limit": limit_val,
                    "duration_seconds": params.get("duration_seconds"),
                    "query_desc": q_desc
                }
            elif action == "rag_knowledge":
                res["search_query"] = params.get("search_query") or query
                res["category_filter"] = params.get("category_filter")
            elif action == "run_cmd":
                res["command"] = params.get("command") or query
                res["cmd_description"] = params.get("description") or "Execute shell command"
                res["cmd_risk"] = params.get("risk") or "safe"

            return res

    except Exception as e:
        logger.warning(f"Direct cognitive agent fallback due to: {e}")
        # Resilient fallback to semantic/regex router if Ollama call fails or times out
        from .router import route_intent
        fallback = route_intent(query, context_history=context_history, mode=mode)
        fallback["source"] = "fallback_router"
        return fallback


# =====================================================================
# Unified Desktop Agent Streaming Generator
# =====================================================================
async def execute_desktop_agent_stream(
    raw_query: str,
    context_history: Optional[List[Dict[str, str]]] = None,
    mode: str = "all",
    session_id: str = "hyprland_desktop"
) -> AsyncGenerator[Dict[str, Any], None]:
    """
    Core cognitive desktop loop:
    Yields JSON packets for the Quickshell dynamic island:
      - phase: voice line & character emotion
      - layout: island layout morph ("toast" | "sheet" | "clarify")
      - status: telemetry & progress
      - action_card: clickable desktop shortcuts
      - token: streamed text chunks
      - done: completion frame
    """
    query = raw_query.strip()
    if not query:
        yield {"type": "status", "text": "Minimo ready — ask anything, search books, media, or tasks.", "reaction": "greet"}
        yield {"type": "done", "reaction": "greet"}
        return

    # Check for fast session clear commands
    if query.lower() in ("clear", "cls", "reset", "new chat"):
        clear_session(session_id)
        yield {"type": "status", "text": "Session reset", "reaction": "sparkles"}
        yield {"type": "clear_session"}
        yield {"type": "done", "reaction": "greet"}
        return

    # Handle confirmation prefixes
    is_confirmed = False
    if query.lower().startswith(("confirm ", "approve ", "yes ")):
        parts = query.split(maxsplit=1)
        query = parts[1].strip() if len(parts) > 1 else query
        is_confirmed = True
    elif query.lower() in ("cancel", "abort"):
        yield {"type": "token", "text": "Action cancelled."}
        yield {"type": "done", "reaction": "greet", "record_history": False}
        return

    # Use warm session history if caller didn't supply context
    effective_history = context_history if (context_history is not None and len(context_history) > 0) else get_session_history(session_id)

    # ── 1. System 1 Reflex Fast-Path Check (< 1ms) ──
    fast_hit = check_reflex_fast_path(query)
    if fast_hit:
        intent = fast_hit["intent"]
        conf = float(fast_hit.get("confidence", 1.0))
        routed = fast_hit
        if fast_hit.get("source") == "reflex_cmd":
            is_confirmed = True
        intent_label = intent.replace("_", " ").title()

        yield {
            "type": "stage",
            "stage": 1,
            "name": "Reflex Fast-Path",
            "intent": intent,
            "confidence": conf,
            "text": f"Direct Execution: {intent_label}",
            "details": {"source": fast_hit.get("source", "reflex"), "model": "Reflex Fast-Path (<0.1ms)"}
        }

        if fast_hit.get("direct_response"):
            yield {
                "type": "stage",
                "stage": 2,
                "name": "Intent Deduced",
                "intent": intent,
                "confidence": 1.0,
                "text": f"Deduced: {intent_label} (100%)",
                "details": {"source": "prompt_table", "model": "SQLite Prompt Table (0ms)"}
            }
            yield {"type": "token", "text": fast_hit["direct_response"]}
            yield {"type": "done", "reaction": "nod", "record_history": True}
            update_session_history(session_id, raw_query, fast_hit["direct_response"])
            return
    else:
        # ── 2. System 2 Direct Cognitive Agent (~250ms) ──
        yield {
            "type": "phase",
            "phase": 1,
            "text": random.choice(KAFKA_ROUTING_PHRASES),
            "accent": "#89B4FA",
            "reaction": "curious"
        }
        yield {
            "type": "stage",
            "stage": 1,
            "name": "Cognitive Reasoning",
            "text": f"Evaluating context & intent for '{query}'...",
            "details": {"query": query}
        }

        active_win = await asyncio.to_thread(get_active_window_info)
        routed = await asyncio.to_thread(
            call_direct_cognitive_agent,
            query,
            effective_history,
            active_win,
            mode
        )
        intent = routed.get("intent", "rag_knowledge")
        conf = float(routed.get("confidence", 0.90))

    if is_confirmed:
        conf = 1.0

    intent_label = intent.replace("_", " ").title()
    yield {
        "type": "stage",
        "stage": 2,
        "name": "Intent Deduced",
        "intent": intent,
        "confidence": conf,
        "text": f"Deduced: {intent_label} ({int(conf * 100)}%)",
        "details": {
            "intent": intent,
            "confidence": conf,
            "source": routed.get("source", "cognitive_agent"),
            "model": "qwen2.5:1.5b-instruct / direct_agent"
        }
    }

    # Gating: Moderate confidence (50% - 80%) requires confirmation before executing actions
    if not is_confirmed and intent in ("add_task", "run_cmd", "delete_task", "complete_task") and (0.50 <= conf < 0.80):
        yield {
            "type": "stage",
            "stage": 3,
            "name": "Confirmation Required",
            "intent": intent,
            "confidence": conf,
            "text": f"Confirmation required before executing {intent_label} ({int(conf * 100)}%)",
            "needs_confirmation": True
        }
        yield {
            "type": "layout",
            "format": "clarify",
            "intent": intent,
            "prompt": f"Kafka deduced '{intent_label}' with {int(conf * 100)}% confidence. Confirm execution?",
            "options": [
                {"label": f"✓ Confirm & Execute {intent_label}", "query": f"confirm {raw_query}"},
                {"label": "✗ Cancel Action", "query": "cancel"}
            ]
        }
        yield {
            "type": "token",
            "text": f"Kafka deduced intent **{intent_label}** with moderate confidence (**{int(conf * 100)}%**).\n\nSelect **Confirm** to proceed, or press **Esc** to cancel."
        }
        yield {"type": "done", "reaction": "curious", "record_history": False}
        return

    # 3. Early Layout Dispatch for Raycast Window
    if intent in ("add_task", "complete_task", "delete_task", "run_cmd", "mindspace_stash"):
        yield {"type": "layout", "format": "sheet", "intent": intent}
    elif intent in ("rag_knowledge", "book_search", "summarize_note", "general_qa", "daily_horizon", "list_tasks", "mindspace_recall", "email_summary"):
        if intent == "list_tasks":
            yield {"type": "layout", "format": "sheet", "intent": intent, "title": "Todoist Tasks", "icon": "󰄬", "accent": "#10B981"}
            yield {"type": "phase", "phase": 2, "text": random.choice(KAFKA_TODOIST_SYNC_PHRASES), "accent": "#10B981", "reaction": "curious"}
        elif intent == "email_summary":
            yield {"type": "layout", "format": "sheet", "intent": intent, "title": "Email Summary", "icon": "󰇮", "accent": "#60A5FA"}
            yield {"type": "phase", "phase": 2, "text": random.choice(KAFKA_MAILBOX_PHRASES), "accent": "#60A5FA", "reaction": "curious"}
        else:
            yield {"type": "layout", "format": "sheet", "intent": intent}
            yield {"type": "phase", "phase": 2, "text": random.choice(KAFKA_NOTES_SEARCH_PHRASES), "accent": "#CBA6F7", "reaction": "curious"}
    elif intent in ("disambiguation", "clarify"):
        yield {"type": "layout", "format": "clarify", "intent": intent}

    streamed_text = ""

    # ── Intent Handlers ──

    # 0. Disambiguation & Clarification
    if intent in ("disambiguation", "clarify"):
        prompt = routed.get("prompt") or f"Could you clarify what you'd like to do with '{raw_query}'?"
        opts = routed.get("options") or []
        yield {
            "type": "layout",
            "format": "clarify",
            "intent": intent,
            "prompt": prompt,
            "options": opts
        }
        yield {
            "type": "action_dispatched",
            "intent": "clarify",
            "action": "ask_clarification",
            "status": "clarification_needed",
            "risk_policy": "safe",
            "payload": {"prompt": prompt, "options": opts}
        }
        yield {"type": "token", "text": prompt}
        yield {"type": "done", "reaction": "confused", "record_history": False}
        return

    # A. Daily Horizon
    elif intent == "daily_horizon":
        yield {"type": "status", "text": "Assembling Daily Horizon briefing...", "reaction": "greet"}
        data = await asyncio.to_thread(get_daily_horizon_data)

        yield {
            "type": "action_card",
            "card_type": "horizon",
            "title": f"🌤️ {data['weather_city']}: {data['weather']} ({data['weather_desc']})",
            "subtitle": f"Feels like {data['weather_feels']} • Clear sky & light breeze",
            "icon": "󰖙",
            "action_type": "run_cmd",
            "action_payload": "/home/krishna/dotfiles/scripts/weather.sh",
            "badge": "WEATHER"
        }
        yield {
            "type": "action_card",
            "card_type": "horizon",
            "title": f"📬 IITK Inbox: {data['emails_count']} unread emails",
            "subtitle": "Click to open Neomutt",
            "icon": "󰇮",
            "action_type": "open_terminal",
            "action_payload": "neomutt",
            "badge": "EMAIL"
        }

        task_lines = []
        for t in data.get("tasks", [])[:4]:
            task_lines.append(f"• **{t.get('content')}** (P{t.get('priority', 4)})")
            yield {
                "type": "action_card",
                "card_type": "todoist",
                "title": f"📋 {t.get('content')}",
                "subtitle": f"Priority {t.get('priority', 4)}",
                "icon": "󰄬",
                "action_type": "complete_task",
                "action_payload": str(t.get('id', '')),
                "badge": "TODOIST"
            }

        greeting = (
            f"### Good morning, Krishna.\n\n"
            f"Here is your **Daily Horizon** briefing:\n\n"
            f"• **Weather:** {data['weather']} in {data['weather_city']}, feels like {data['weather_feels']}.\n"
            f"• **Inbox:** You have **{data['emails_count']}** unread emails waiting in Maildir.\n\n"
            f"**Pending Priorities:**\n" + ("\n".join(task_lines) if task_lines else "• All caught up! No urgent tasks.") + "\n\n"
            f"— Arranged by Kafka"
        )
        yield {"type": "token", "text": greeting}
        yield {"type": "done", "reaction": "greet", "record_history": True}
        update_session_history(session_id, raw_query, greeting)
        return

    # B. Active Window Focus
    elif intent == "active_window":
        yield {"type": "status", "text": "Inspecting active desktop focus...", "reaction": "curious"}
        win = await asyncio.to_thread(get_active_window_info)
        w_title = win.get("title") or "Unknown Window"
        w_class = win.get("class") or "Desktop"
        w_ws = win.get("workspace") or "1"
        w_pid = win.get("pid") or ""

        yield {
            "type": "action_card",
            "card_type": "window",
            "title": w_title[:60],
            "subtitle": f"App: {w_class} · WS {w_ws} · PID {w_pid}",
            "icon": "󰖲",
            "action_type": "copy",
            "action_payload": w_title,
            "badge": "ACTIVE WINDOW"
        }
        resp = f"**Focused Window:** `{w_class}` — *{w_title}* on workspace `{w_ws}` (PID `{w_pid}`)."
        yield {"type": "token", "text": resp}
        yield {"type": "done", "reaction": "nod", "record_history": True}
        update_session_history(session_id, raw_query, resp)
        return

    # C. Media Finder (Movies & Anime)
    elif intent == "play_media":
        m_title = routed.get("media_title") or query
        yield {"type": "status", "text": f"Scanning media storage for '{m_title}'...", "reaction": "curious"}
        matches = await asyncio.to_thread(search_local_movies, m_title, 5)
        yield {
            "type": "action_dispatched",
            "intent": "play_media",
            "action": "local_media" if matches else "search_youtube",
            "status": "ready",
            "risk_policy": "safe",
            "payload": {
                "media_title": m_title,
                "matches_count": len(matches),
                "top_match": matches[0] if matches else None
            }
        }
        if matches:
            top = matches[0]
            yield {"type": "token", "text": f"🎬 Found **{top['title']}** in local storage:\n`{top['filepath']}`\n\n"}
            for m in matches:
                yield {
                    "type": "action_card",
                    "card_type": "movie",
                    "title": m['title'],
                    "subtitle": m['raw_filename'],
                    "snippet": m['filepath'],
                    "icon": "󰐊",
                    "action_type": "play_movie",
                    "action_payload": m['filepath'],
                    "badge": m['badge']
                }
        else:
            yield {"type": "token", "text": f"Nothing found locally for '{m_title}'. Want to stream from YouTube?"}
            yield {
                "type": "action_card",
                "card_type": "youtube",
                "title": f"Search YouTube: {m_title}",
                "subtitle": "Stream via MPV",
                "icon": "󰎆",
                "action_type": "play_youtube",
                "action_payload": m_title,
                "badge": "YOUTUBE"
            }
        yield {"type": "done", "reaction": "curious", "record_history": True}
        update_session_history(session_id, raw_query, f"Found media for {m_title}")
        return

    # F. Task Creation (with Kafka distillation & offline outbox)
    elif intent == "add_task":
        title = routed.get("task_title") or query
        due = routed.get("task_due")
        p = routed.get("task_priority")
        desc = routed.get("task_description")
        is_clar = routed.get("needs_clarification", False)

        if is_clar:
            prompt = routed.get("clarification_prompt") or f"Could you clarify the title for this task?"
            yield {"type": "token", "text": prompt}
            yield {"type": "done", "reaction": "confused"}
            return

        due_str = f" • Due {due}" if due else ""
        p_str = f"Priority P{p}" if p else "Normal Priority"

        yield {
            "type": "stage",
            "stage": 3,
            "name": "Entity Deduction",
            "intent": "add_task",
            "confidence": conf,
            "text": f"Deduced Task: '{title}' [{p_str}{due_str}]",
            "details": {
                "title": title,
                "priority": p or 4,
                "due": due,
                "description": desc
            }
        }
        yield {"type": "status", "text": f"Adding task: {title[:40]}...", "reaction": "writing"}
        created = await asyncio.to_thread(add_task, title, due, p, desc)
        k_title = random.choice(KAFKA_TASK_ADDED_TITLES)
        is_offline = created.get("offline_queued", False) if created else False
        badge_text = "OFFLINE QUEUED" if is_offline else f"P{p or 4}"

        yield {
            "type": "action_dispatched",
            "intent": "add_task",
            "action": "add_task",
            "status": "queued" if is_offline else "executed",
            "risk_policy": "undoable",
            "payload": {
                "title": title,
                "due": due,
                "priority": p or 4,
                "task_id": str(created.get("id", "")) if created else None,
                "offline_queued": is_offline
            }
        }
        yield {
            "type": "layout",
            "format": "sheet",
            "title": k_title,
            "subtitle": f"{title}{due_str}",
            "icon": "󰄬",
            "accent": "#F59E0B" if is_offline else "#10B981"
        }
        yield {
            "type": "action_card",
            "card_type": "todoist",
            "title": title,
            "subtitle": f"{p_str}{due_str}",
            "snippet": desc or "— Noted by Kafka",
            "icon": "󰄬",
            "action_type": "complete_task",
            "action_payload": str(created.get("id", "")) if created else title,
            "badge": badge_text,
            "priority": p or 4,
            "due": due or "Today",
            "project": "Inbox",
            "description": desc or ""
        }
        conf_msg = (
            f"Added **{title}** to local outbox (will sync when online)."
            if is_offline else
            f"Added **{title}** to Todoist ({p_str}{due_str}).\n\n*— Arranged by Kafka*"
        )
        yield {"type": "token", "text": conf_msg}
        yield {"type": "done", "reaction": "happyBounce", "record_history": True}
        update_session_history(session_id, raw_query, conf_msg)
        return

    # G. Task Listing
    elif intent == "list_tasks":
        yield {"type": "status", "text": "Fetching Todoist & local tasks...", "reaction": "curious"}
        tasks = await asyncio.to_thread(get_tasks)
        yield {
            "type": "action_dispatched",
            "intent": "list_tasks",
            "action": "list_tasks",
            "status": "executed",
            "risk_policy": "safe",
            "payload": {
                "count": len(tasks),
                "tasks": [{"id": str(t.get("id")), "content": t.get("content"), "priority": t.get("priority", 4), "due": t.get("due")} for t in tasks]
            }
        }
        if not tasks:
            yield {"type": "token", "text": "✨ No pending tasks found! You're completely caught up."}
        else:
            yield {"type": "token", "text": f"📋 **{len(tasks)} Pending Tasks:**\n\n"}
            for t in tasks:
                d_info = f" · 📅 *{t.get('due')}*" if t.get('due') else ""
                p_val = t.get('priority', 4)
                p_ico = {1: "🔴", 2: "🟠", 3: "🔵"}.get(p_val, "⚪")
                yield {"type": "token", "text": f"- {p_ico} {t['content']}{d_info}\n"}
                yield {
                    "type": "action_card",
                    "card_type": "task",
                    "title": t['content'],
                    "subtitle": f"Priority {p_val}{d_info}",
                    "snippet": t.get('description', ''),
                    "icon": "󰄬",
                    "action_type": "complete_task",
                    "action_payload": str(t['id']),
                    "badge": "OFFLINE" if t.get("offline_queued") else f"P{p_val}"
                }
        yield {"type": "done", "reaction": "happyBounce", "record_history": True}
        update_session_history(session_id, raw_query, f"Listed {len(tasks)} tasks.")
        return

    # H. Task Completion / Deletion
    elif intent in ("complete_task", "delete_task"):
        target = (routed.get("task_target") or "").lower().strip()
        tasks = await asyncio.to_thread(get_tasks)
        matched_id = None
        matched_title = target
        for t in tasks:
            tc = (t.get("content") or "").lower()
            if target in tc or tc in target:
                matched_id = str(t.get("id"))
                matched_title = t.get("content")
                break
        if matched_id:
            if intent == "complete_task":
                await asyncio.to_thread(toggle_task, matched_id)
                msg = f"Done. **{matched_title}** is marked complete."
            else:
                await asyncio.to_thread(delete_task, matched_id)
                msg = f"Removed. **{matched_title}** is off your list."
        else:
            msg = f"Couldn't find a task matching '{target}'."
        yield {
            "type": "action_dispatched",
            "intent": intent,
            "action": intent,
            "status": "executed" if matched_id else "not_found",
            "risk_policy": "undoable",
            "payload": {
                "target": target,
                "task_id": matched_id,
                "title": matched_title
            }
        }
        yield {"type": "token", "text": msg}
        yield {"type": "done", "reaction": "nod", "record_history": True}
        update_session_history(session_id, raw_query, msg)
        return

    # I. Email Summaries (with freshness verification)
    elif intent == "email_summary":
        p = routed.get("email_params") or {}
        dur = p.get("duration_seconds")
        since_ts = p.get("since_timestamp")
        limit = p.get("limit", 5)
        q_desc = p.get("query_desc", "recent emails")

        sync_status = await asyncio.to_thread(get_maildir_sync_status)
        if sync_status.get("is_stale"):
            yield {
                "type": "status",
                "text": f"Scanning Maildir (last synced {sync_status['relative_str']} — triggering sync)...",
                "reaction": "curious"
            }
            # Non-blocking trigger of mail sync
            await asyncio.to_thread(execute_desktop_action, "mail_sync", "")
        else:
            yield {"type": "status", "text": f"Scanning Maildir for {q_desc}...", "reaction": "curious"}

        emails = await asyncio.to_thread(fetch_recent_emails, dur, since_ts, limit)
        if not emails:
            msg = f"📬 **No emails found** for {q_desc}.\n\nYour inbox is clear for this window!"
            yield {"type": "token", "text": msg}
            yield {
                "type": "action_card",
                "card_type": "email",
                "title": "Inbox Up to Date",
                "subtitle": f"No messages in {q_desc}",
                "snippet": f"Last sync: {sync_status['relative_str']}",
                "icon": "󰇮",
                "action_type": "mail_sync",
                "action_payload": "mail_sync",
                "badge": "MAILDIR"
            }
            yield {"type": "done", "reaction": "happyBounce", "record_history": True}
            update_session_history(session_id, raw_query, msg)
            return

        yield {"type": "token", "text": f"### Executive Briefing\n*(Mailbox synced {sync_status['relative_str']})*\n\n"}
        for em in emails:
            yield {
                "type": "action_card",
                "card_type": "email",
                "title": em["sender"],
                "subtitle": f"{em['time_ago']} · {em['subject']}",
                "snippet": em["snippet"][:180] + ("..." if len(em["snippet"]) > 180 else ""),
                "icon": "󰇮",
                "action_type": "open_terminal",
                "action_payload": "neomutt",
                "badge": em["time_ago"].upper()
            }

        synth_prompt = build_email_digest_prompt(emails, q_desc)
        full_synth = []
        async for item in stream_email_synthesis_async(synth_prompt, num_predict=1200):
            if item.get("type") == "token":
                full_synth.append(item.get("text", ""))
                yield item
        full_ans = "".join(full_synth)
        yield {"type": "done", "reaction": "reading", "record_history": True}
        update_session_history(session_id, raw_query, full_ans)
        return

    # J. Clipboard / MindSpace
    elif intent in ("mindspace", "mindspace_recall"):
        s_term = routed.get("search_query") or query
        yield {"type": "status", "text": f"Searching MindSpace clipboard for '{s_term}'...", "reaction": "curious"}
        clips = await asyncio.to_thread(search_mindspace, s_term, 4)
        if not clips:
            msg = f"No clips matching '{s_term}' found in clipboard history."
            yield {"type": "token", "text": msg}
        else:
            yield {"type": "token", "text": f"📋 **Found {len(clips)} clips in MindSpace:**\n\n"}
            for c in clips:
                snip = c.get("text", "")[:120]
                yield {
                    "type": "action_card",
                    "card_type": "clipboard",
                    "title": snip[:45],
                    "subtitle": c.get("relative_time", "Earlier"),
                    "snippet": snip,
                    "icon": "󰅌",
                    "action_type": "copy",
                    "action_payload": c.get("text", ""),
                    "badge": "CLIPBOARD"
                }
        yield {"type": "done", "reaction": "happyBounce", "record_history": True}
        update_session_history(session_id, raw_query, f"Searched clipboard for {s_term}")
        return

    # K. Shell Commands (Structured Approval & Execution)
    elif intent == "run_cmd":
        cmd = routed.get("command") or query
        cmd_desc = routed.get("cmd_description") or "Execute shell command"
        cmd_risk = routed.get("cmd_risk") or ("dangerous" if any(w in cmd.split() for w in ("rm", "mkfs", "dd", "shutdown", "reboot")) else ("mutating" if any(w in cmd.split() for w in ("mv", "kill", "systemctl", "touch", "git", "sed")) else "safe"))

        interactive_tools = ('htop', 'btop', 'top', 'nvim', 'vim', 'nano', 'less', 'man', 'ranger', 'kitty', 'mpv', 'neomutt')
        is_interactive = any(t in cmd.split() for t in interactive_tools)

        # ── Mandatory Approval Check: If not confirmed, require user authorization ──
        if not is_confirmed:
            risk_color = "#00F5FF" if cmd_risk == "safe" else ("#F59E0B" if cmd_risk == "mutating" else "#EF4444")
            yield {
                "type": "stage",
                "stage": 3,
                "name": "Command Review & Approval",
                "intent": "run_cmd",
                "confidence": conf,
                "text": f"Proposed: '{cmd}' [{cmd_risk.upper()}]",
                "details": {
                    "command": cmd,
                    "description": cmd_desc,
                    "risk": cmd_risk,
                    "is_interactive": is_interactive
                }
            }
            yield {
                "type": "layout",
                "format": "command",
                "title": "Command Execution Approval",
                "subtitle": f"$ {cmd}",
                "icon": "󰆍",
                "accent": risk_color
            }
            yield {
                "type": "action_card",
                "card_type": "command",
                "title": cmd,
                "subtitle": cmd_desc,
                "command": cmd,
                "description": cmd_desc,
                "risk": cmd_risk,
                "status": "pending_approval",
                "icon": "󰆍",
                "action_type": "execute_cmd",
                "action_payload": cmd,
                "badge": "APPROVAL REQUIRED" if cmd_risk != "safe" else "PROPOSED (SAFE)"
            }
            yield {
                "type": "token",
                "text": f"Proposed command for execution:\n\n```bash\n$ {cmd}\n```\n\n**Purpose**: {cmd_desc}\n**Risk Level**: `{cmd_risk.upper()}`\n\nPress **[↵] Execute**, **[C] Copy**, or **[Esc]** to cancel."
            }
            yield {"type": "done", "reaction": "curious", "record_history": False}
            return

        # ── User Confirmed: Execute Command ──
        yield {"type": "status", "text": f"Executing command: {cmd[:40]}...", "reaction": "writing"}
        exit_code = 0
        if is_interactive:
            subprocess.Popen(
                ["kitty", "-e", "bash", "-c", f"{cmd}; echo ''; read -p 'Press Enter to exit...'"],
                start_new_session=True
            )
            yield {
                "type": "action_dispatched",
                "intent": "run_cmd",
                "action": "open_terminal",
                "status": "executed",
                "risk_policy": cmd_risk,
                "payload": {"command": cmd, "interactive": True}
            }
            yield {
                "type": "action_card",
                "card_type": "command",
                "title": cmd,
                "subtitle": "Spawned interactive Kitty terminal",
                "command": cmd,
                "description": cmd_desc,
                "risk": cmd_risk,
                "status": "executed",
                "icon": "󰆍",
                "action_type": "copy",
                "action_payload": cmd,
                "badge": "SPAWNED"
            }
            yield {"type": "token", "text": f"💻 Spawned interactive terminal for `$ {cmd}`."}
        else:
            res = await asyncio.to_thread(run_command_safe, cmd)
            out_clean = res["stdout"] or res["stderr"] or "(Command executed with no output)"
            exit_code = res.get("returncode", 0)
            yield {
                "type": "action_dispatched",
                "intent": "run_cmd",
                "action": "run_command_safe",
                "status": "executed",
                "risk_policy": cmd_risk,
                "payload": {
                    "command": cmd,
                    "interactive": False,
                    "stdout": res.get("stdout", ""),
                    "stderr": res.get("stderr", ""),
                    "exit_code": exit_code
                }
            }
            yield {
                "type": "action_card",
                "card_type": "command",
                "title": cmd,
                "subtitle": cmd_desc,
                "command": cmd,
                "description": cmd_desc,
                "risk": cmd_risk,
                "status": "executed",
                "stdout": res.get("stdout", ""),
                "stderr": res.get("stderr", ""),
                "exit_code": exit_code,
                "icon": "󰄬" if exit_code == 0 else "󰅚",
                "action_type": "copy",
                "action_payload": res.get("stdout") or res.get("stderr") or cmd,
                "badge": f"EXIT {exit_code}"
            }
            resp = f"💻 Output of `$ {cmd}`:\n\n```\n{out_clean}\n```"
            yield {"type": "token", "text": resp}

        yield {"type": "done", "reaction": "happyBounce" if exit_code == 0 else "confused", "record_history": True}
        update_session_history(session_id, raw_query, f"Executed command: {cmd}")
        return

    # L. Casual Chat
    elif intent == "chat":
        full_tokens = []
        async for item in stream_chat_async(query, effective_history):
            if item.get("type") == "token":
                full_tokens.append(item.get("text", ""))
            yield item
        update_session_history(session_id, raw_query, "".join(full_tokens))
        return

    # M. Document / Book Open
    elif intent == "open_doc":
        doc_query = routed.get("search_query") or query
        hits = await asyncio.to_thread(search_library_rag, doc_query, 3)
        if hits:
            top = hits[0]
            fp = top.get("filepath", "")
            page = str(top.get("page", 1))
            yield {
                "type": "action_dispatched",
                "intent": "open_doc",
                "action": "open_document",
                "status": "ready",
                "risk_policy": "safe",
                "payload": {"document": top.get('filename', doc_query), "filepath": fp, "page": page}
            }
            yield {"type": "token", "text": f"Found **{top.get('filename', doc_query)}** — opening it now."}
            yield {
                "type": "action_card",
                "card_type": "book" if fp.endswith(".pdf") else "note",
                "title": top.get("filename", doc_query),
                "subtitle": f"Page {page}" if fp.endswith(".pdf") else f"Line {page}",
                "snippet": top.get("snippet", ""),
                "icon": "󰂿" if fp.endswith(".pdf") else "󰠮",
                "action_type": top.get("action_type") or ("open_book" if fp.endswith(".pdf") else "open_note"),
                "action_payload": top.get("action_payload") or f"{fp}:::{page}",
                "badge": top.get("badge") or (f"PDF · p. {page}" if fp.endswith(".pdf") else f"NOTE · L{page}"),
                "citation": top.get("citation") or f"{top.get('filename', doc_query)} (Page {page})"
            }
        else:
            yield {"type": "token", "text": f"Couldn't find anything matching '{doc_query}' in your library."}
        yield {"type": "done", "reaction": "nod", "record_history": True}
        return

    # N. Default: Hybrid RAG & Synthesis
    else:
        s_query = routed.get("search_query") or query
        cat_filter = routed.get("category_filter")

        # Check for active or hovered PDF on screen
        active_pdf = await asyncio.to_thread(get_active_or_hovered_pdf)
        pdf_scoped = False
        target_pdf_path = None
        target_pdf_name = None

        if active_pdf and active_pdf.get("filepath"):
            q_lower = query.lower()
            pdf_ref_keywords = ("this pdf", "the pdf", "this document", "this paper", "this book", "in here", "from here", "in this file")
            is_explicit_pdf = any(k in q_lower for k in pdf_ref_keywords)
            # Scoped if user specifically asks about the document OR if a PDF reader is active/hovered
            if is_explicit_pdf or active_pdf.get("is_active"):
                pdf_scoped = True
                target_pdf_path = active_pdf["filepath"]
                target_pdf_name = active_pdf["filename"]

        if pdf_scoped and target_pdf_path:
            clean_s_query = re.sub(
                r'\b(?:in\s+)?(?:this|the)\s+(?:pdf|document|book|paper|file)\b',
                '',
                s_query,
                flags=re.IGNORECASE
            ).strip()
            clean_s_query = re.sub(
                r'^(?:is\s+there\s+any(?:thing)?(?:\s+about)?|is\s+there|does\s+it\s+have|does\s+it\s+mention|what\s+does\s+it\s+say\s+about)\s+',
                '',
                clean_s_query,
                flags=re.IGNORECASE
            ).strip()
            if not clean_s_query:
                clean_s_query = s_query

            yield {
                "type": "status",
                "text": f"Searching within open PDF: {target_pdf_name}...",
                "reaction": "reading"
            }
            rag_hits = await asyncio.to_thread(search_library_rag, clean_s_query, 5, None, target_pdf_path)

            if not rag_hits:
                not_found_msg = (
                    f"📖 I searched through **{target_pdf_name}**, but found no mention or relevant sections "
                    f"regarding **\"{clean_s_query}\"** in this document."
                )
                yield {"type": "token", "text": not_found_msg}
                yield {
                    "type": "action_card",
                    "card_type": "book",
                    "title": target_pdf_name,
                    "subtitle": "Scoped Search: No matching passages",
                    "snippet": f"The query '{s_query}' was not detected in {target_pdf_name}.",
                    "icon": "󰂿",
                    "action_type": "open_book",
                    "action_payload": f"{target_pdf_path}:::1",
                    "badge": "PDF (SCOPED)"
                }
                yield {"type": "done", "reaction": "nod", "record_history": True}
                update_session_history(session_id, raw_query, not_found_msg)
                return
        else:
            yield {"type": "status", "text": "Searching knowledge base & notes...", "reaction": "reading"}
            rag_hits = await asyncio.to_thread(search_library_rag, s_query, 5, cat_filter)

        yield {
            "type": "action_dispatched",
            "intent": "rag_knowledge",
            "action": "search_library_rag",
            "status": "executed",
            "risk_policy": "safe",
            "payload": {
                "query": s_query,
                "hit_count": len(rag_hits),
                "category_filter": cat_filter,
                "scoped_pdf": target_pdf_name if pdf_scoped else None,
                "sources": [
                    {
                        "filename": h.get("filename"),
                        "page": h.get("page"),
                        "category": h.get("category"),
                        "score": h.get("score")
                    }
                    for h in rag_hits
                ]
            }
        }
        full_tokens = []
        async for item in stream_synthesis_async(query, rag_hits, effective_history):
            if item.get("type") == "token":
                full_tokens.append(item.get("text", ""))
            yield item
        update_session_history(session_id, raw_query, "".join(full_tokens))
