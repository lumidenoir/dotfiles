"""
Minimo Brain Suite - Cognitive Intent Router & Tool Extractor
"""

import re
import json
import urllib.request
from typing import Dict, Any, Optional
from .config import OLLAMA_URL, get_router_model

def route_intent(query: str, context_history: Optional[list] = None, mode: str = "all") -> Dict[str, Any]:
    """
    Sub-3ms In-Process Semantic Vector Router & Tool Extractor.
    Uses dense ONNX embeddings against route centroids with decoupled entity matching.
    """
    q_strip = query.strip()
    if not q_strip:
        return {"intent": "chat", "search_query": None}

    # Primary: In-Process Semantic Vector Router (< 3 ms)
    try:
        from .semantic_router import route_intent_semantic
        return route_intent_semantic(query, context_history=context_history, mode=mode)
    except Exception:
        pass

    q_lower = q_strip.lower()

    # ── Tier 1A: Fast Task Listing (0 ms) ──
    list_exact = {
        "tasks", "task", "todo", "todoist", "todoist tasks", "my tasks",
        "pending tasks", "list tasks", "show tasks", "view tasks", "get tasks",
        "check tasks", "show todoist", "todoist list"
    }
    if q_lower in list_exact:
        return {"intent": "list_tasks"}

    list_regex = r"^(?:please\s+)?(?:show|list|view|check|get|what are)\s+(?:all\s+|my\s+|pending\s+)?(?:todoist\s+)?tasks?"
    if re.search(list_regex, q_lower):
        return {"intent": "list_tasks"}

    if mode == "tasks":
        if not q_strip or any(w in q_lower for w in ("show", "list", "pending", "view", "check", "get", "my tasks")):
            return {"intent": "list_tasks"}

    # ── Tier 1B: Complete / Delete Tasks (0 ms) ──
    m_mark = re.search(r"^(?:please\s+)?mark\s+(?:task\s+)?(.+?)\s+(?:as\s+)?(?:done|completed?)$", q_strip, re.I)
    if m_mark:
        return {"intent": "complete_task", "task_target": m_mark.group(1).strip()}

    m_comp = re.search(r"^(?:please\s+)?(?:complete|finish|done\s+with|check\s+off)\s+(?:task\s+)?(.+)", q_strip, re.I)
    if m_comp:
        return {"intent": "complete_task", "task_target": m_comp.group(1).strip()}

    m_del = re.search(r"^(?:please\s+)?(?:delete|remove)\s+(?:task\s+)?(.+)", q_strip, re.I)
    if m_del:
        return {"intent": "delete_task", "task_target": m_del.group(1).strip()}

    # ── Tier 1C: Daily Horizon & Active Window Awareness (0 ms) ──
    morning_exact = {"good morning", "morning", "daily horizon", "horizon", "morning briefing", "daily briefing", "morning summary", "daily summary", "brief me", "morning report"}
    if q_lower in morning_exact or re.search(r"^(?:please\s+)?(?:give\s+me\s+a\s+|show\s+|what\s+is\s+my\s+)?(?:daily\s+horizon|morning\s+briefing|daily\s+briefing)", q_lower):
        return {"intent": "daily_horizon"}

    window_exact = {"active window", "current window", "what am i doing", "what is on screen", "what window is this", "window info", "focused window", "active app", "current app"}
    window_regex = r"\b(?:(?:what|which)\s+(?:is\s+)?(?:the\s+)?(?:active|current|focused)\s+window|(?:what|which)\s+window\s+is\s+(?:active|focused)|active\s+window|focused\s+window|current\s+app|active\s+app)\b"
    if q_lower in window_exact or re.search(window_regex, q_lower):
        return {"intent": "active_window"}

    # ── Tier 1C-2: Email Summaries & Inbox Inquiries (0 ms) ──
    email_regex = r"\b(?:what\s+are\s+(?:the\s+)?emails|summarize\s+(?:my\s+|the\s+)?emails?|(?:summary|digest)\s+of\s+(?:my\s+|the\s+|latest\s+|newest\s+|recent\s+)?emails?|check\s+(?:my\s+)?(?:inbox|emails?)|(?:any\s+)?(?:new\s+)?emails?\s+(?:from\s+)?(?:the\s+)?(?:last|past)\s+\d+\s*(?:hours?|hrs?|mins?|minutes?)|(?:any\s+)?(?:new\s+)?emails?\s+today|(?:last|top|first)\s+\d+\s+emails?|(?:latest|newest|most\s+recent|last)\s+email|email\s+summary|inbox\s+summary)\b"
    if re.search(email_regex, q_lower):
        from .emails import parse_email_query_params
        return {"intent": "email_summary", "email_params": parse_email_query_params(q_strip)}

    # ── Tier 1D: MPRIS Music Playback & Audio Controls (0 ms) ──
    mpris_match = re.search(r"^(?:please\s+)?(pause|play-pause|toggle|unpause|resume|next|skip|prev|previous|stop)\s*(?:music|song|track|playback)?$", q_lower)
    if mpris_match or q_lower in ("play", "pause", "play-pause", "toggle", "unpause", "resume", "next", "prev", "stop music", "pause music"):
        act = mpris_match.group(1).lower() if mpris_match else q_lower.split()[0]
        if act in ("pause", "play-pause", "toggle", "unpause", "resume", "play"):
            return {"intent": "mpris_control", "mpris_action": "play-pause"}
        elif act in ("next", "skip"):
            return {"intent": "mpris_control", "mpris_action": "next"}
        elif act in ("prev", "previous"):
            return {"intent": "mpris_control", "mpris_action": "previous"}
        elif act in ("stop", "stop music"):
            return {"intent": "mpris_control", "mpris_action": "stop"}

    # Explicit song / audio queries
    music_m = re.search(r"^(?:please\s+)?(?:play\s+song|play\s+music|listen\s+to|stream\s+song|play\s+track|queue\s+song|put\s+on\s+music)\s*(.*)", q_strip, re.I)
    if music_m:
        m_target = music_m.group(1).strip()
        if not m_target:
            return {"intent": "mpris_control", "mpris_action": "play-pause"}
        return {"intent": "play_music", "music_query": m_target}

    # ── Tier 1E: Shell Commands & Syntax Guards (0 ms) ──
    # Guard: questions asking what command to use or how to do something must NEVER execute commands!
    is_cmd_query = bool(re.search(r'\b(?:command\s+for|how\s+to|what(?:\s+is)?\s+(?:the\s+)?command|which\s+command|commands?\s+(?:to|for))\b', q_lower)) or (q_strip.endswith('?') and any(w in q_lower for w in ('command', 'systemctl', 'pacman', 'git', 'reload', 'restart', 'status', 'syntax')))
    if is_cmd_query and not q_strip.startswith(('$', '!')):
        return {"intent": "rag_knowledge", "search_query": q_strip}

    if q_strip.startswith(("$", "!", "run ", "exec ", "execute ")) and not any(w in q_lower for w in ('movie', 'book', 'task', 'todoist', 'anime', 'film')):
        cmd = re.sub(r'^(?:\$|!|run\s+|exec\s+|execute\s+)', '', q_strip).strip()
        return {"intent": "run_cmd", "command": cmd}

    # ── Tier 1F: Explicit Document Launcher (Open in Zathura / Neovim) ──
    open_doc_match = re.search(r"^(?:please\s+)?(?:open|launch|view\s+in\s+zathura|read)\s+(?:book|paper|doc|document|pdf|notes?)?\s*(.+)", q_strip, re.I)
    if open_doc_match and not any(w in q_lower for w in ("?", "what", "any", "how", "why", "where", "search", "find")):
        target_doc = open_doc_match.group(1).strip()
        if target_doc and not any(w in target_doc.lower() for w in ("terminal", "command", "task", "song", "movie", "video", "anime")):
            return {"intent": "open_doc", "search_query": target_doc}

    # ── Tier 1G: Explicit Clipboard / MindSpace Memory (0 ms) ──
    clipboard_keywords = ("clipboard", "copied", "clip", "clips", "stash", "copied text", "paste")
    if any(re.search(rf"\b{re.escape(k)}\b", q_lower) for k in clipboard_keywords):
        return {"intent": "mindspace", "search_query": q_strip}

    # ── Tier 1H: Media & Video Stream (Movies, Anime, Episodes) (0 ms) ──
    has_video_signal = any(w in q_lower for w in ('ep', 'episode', 'season', 'movie', 'anime', 'mkv', 'mp4', 'film', 'frieren', 'cinema', 'series')) or bool(re.search(r'\b(?:s\d+|e\d+|ep\s*\d+|part\s*\d+)\b', q_lower))

    if mode == "media" or re.search(r"^(?:play\s+movie|watch|stream\s+movie|put\s+on\s+movie|watch\s+movie)\s+", q_lower):
        m_q = re.sub(r"^(?:play\s+movie|watch\s+movie|stream\s+movie|play|watch|stream|put on)\s+", "", q_strip, flags=re.I).strip()
        return {"intent": "play_media", "media_title": m_q or q_strip}

    # If query starts with "play ", disambiguate media vs music with zero LLM alteration
    if re.search(r"^play\s+", q_lower):
        candidate = re.sub(r"^play\s+", "", q_strip, flags=re.I).strip()
        if candidate:
            if has_video_signal:
                return {"intent": "play_media", "media_title": candidate}
            # Check local movies before music fallback
            from .media import search_local_movies
            try:
                local_movs = search_local_movies(candidate, limit=1)
                if local_movs and local_movs[0].get("score", 0) >= 40:
                    return {"intent": "play_media", "media_title": candidate}
            except Exception:
                pass
            return {"intent": "play_music", "music_query": candidate}
        else:
            return {"intent": "mpris_control", "mpris_action": "play-pause"}

    media_inspect = re.search(r"\b(?:find|search\s+for|look\s+for|do\s+i\s+have|is\s+there|is|where\s+is)\s+(.+?)\s+(?:present|available|downloaded|in\s+(?:local\s+)?storage|in\s+(?:movies|videos|anime)|locally|\?|$)", q_strip, re.I)
    if media_inspect and has_video_signal:
        return {"intent": "play_media", "media_title": media_inspect.group(1).strip()}

    # ── Tier 1I: Fast Deterministic Task Detection & Cross-Matrix NLP Extraction ──
    has_conversational_ref = bool(context_history) and any(w in q_lower for w in ("this", "that", "it", "second", "first", "third", "point", "above", "mentioned", "previous", "issue", "problem"))
    is_add = (mode == "tasks") or bool(re.search(r"\b(?:add|create|new|remind|reminder|schedule|put|set\s+a\s+task)\b", q_lower) and any(w in q_lower for w in ("task", "tasks", "todoist", "todo", "remind me", "reminder", "issue")))

    if is_add:
        reg_priority = None
        p_match = re.search(r'\b(?:assign\s+|set\s+)?(?:priority\s+(?:to\s+)?|p)([1-4])(?:\s+priority)?\b', q_strip, re.I)
        if p_match:
            reg_priority = int(p_match.group(1))

        is_complex = has_conversational_ref or len(q_strip.split()) > 6 or any(w in q_lower for w in ("issue", "difficulty", "trouble", "assign", "due by", "evening", "morning", "tomorrow"))
        if is_complex:
            task_data = extract_task_cross_matrix(q_strip, context_history, reg_priority)
            if task_data and task_data.get("task_title"):
                return task_data

        extracted = clean_deterministic_task(q_strip, reg_priority)
        if extracted.get("task_title"):
            return extracted

    # ── Tier 1J: Deterministic Literature, Notes & Universal Knowledge RAG (0 ms) ──
    doc_type_terms = (
        'paper', 'papers', 'book', 'books', 'notes', 'doc', 'docs', 'document', 'documents',
        'pdf', 'textbook', 'textbooks', 'chapter', 'section', 'article', 'lecture', 'slides',
        'literature', 'thesis', 'author', 'reference', 'bibliography', 'guide', 'handbook', 'manual',
        'writeup', 'write-up', 'cheatsheet', 'org', 'roam', 'obsidian'
    )
    has_doc_signal = any(re.search(rf"\b{re.escape(k)}\b", q_lower) for k in doc_type_terms)

    # All standard question stems across all disciplines
    is_knowledge_inquiry = bool(re.search(
        r'^(?:is|are|can|could|does|do|did|will|would|should|what|how|why|where|which|when|who|explain|describe|summarize|tell\s+me\s+about|give\s+an\s+overview\s+of|definition\s+of|difference\s+between|compare|contrast|derive|proof\s+of|meaning\s+of|origin\s+of|history\s+of)\b',
        q_lower
    )) or q_strip.endswith('?')

    has_concept_marker = bool(re.search(
        r'\b(?:formula|equation|derivation|derive|proof|theorem|law|principle|algorithm|architecture|mechanism|hypothesis|theory|definition|concept|methodology|protocol|flow|cycle|process|system|function|analysis)\b',
        q_lower
    ))

    is_media_or_task = any(w in q_lower for w in ('movie', 'song', 'music', 'track', 'album', 'listen', 'watch', 'play', 'task', 'todo', 'remind'))

    if mode in ("notes", "books") or ((has_doc_signal or is_knowledge_inquiry or has_concept_marker) and not is_media_or_task):
        cat = None
        if mode == "notes" or bool(re.search(r'\b(?:notes?|my\s+notes?|org|roam|obsidian)\b', q_lower)):
            cat = "notes"
        elif mode == "books" or bool(re.search(r'\b(?:books?|papers?|pdfs?|textbooks?|literature|handbooks?)\b', q_lower)):
            cat = "books"
        return {"intent": "rag_knowledge", "category_filter": cat, "search_query": q_strip}

    # Casual Chat Guard: Only exact conversational pleasantries should bypass RAG
    casual_exact = {'hi', 'hello', 'hey', 'good morning', 'morning', 'who are you', 'what can you do', 'thanks', 'thank you', 'bye', 'clear', 'reset', 'how are you', 'how are you doing'}
    if q_lower in casual_exact or len(query.split()) <= 1:
        return {"intent": "chat", "search_query": None}

    # ── Tier 2: Qwen 2.5 1.5B Cognitive Router (~1.0s on CPU) ──
    return classify_intent_llm(query, context_history)

def clean_deterministic_task(raw: str, pre_priority: Optional[int] = None) -> Dict[str, Any]:
    """Pure regex deterministic extractor for simple task inputs (0 ms latency)."""
    text = raw.strip()
    priority = pre_priority

    if priority is None:
        p_m = re.search(r'\b[pP]([1-4])\b', text)
        if p_m:
            priority = int(p_m.group(1))
            text = text[:p_m.start()] + ' ' + text[p_m.end():]

    # Composite due date matcher
    due = None
    date_pattern = r'\b(?:(?:due\s+(?:by|on|at|for)|by|on|at)\s+)?((?:today|tomorrow|tonight|yesterday|this\s+evening|this\s+morning|monday|tuesday|wednesday|thursday|friday|saturday|sunday|\d{1,2}(?:st|nd|rd|th)?(?:\s+(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*)?)(?:\s+(?:at\s+)?\d{1,2}(?::\d{2})?\s*(?:am|pm)?|\s+(?:morning|evening|afternoon|night))?)\b'
    d_m = re.search(date_pattern, text, re.IGNORECASE)
    if d_m and len(d_m.group(1).strip()) >= 3:
        start_idx = d_m.start()
        due = d_m.group(1).strip()
        text = text[:start_idx] + ' ' + text[d_m.end():]

    # Strip command and glue prefixes
    clean = re.sub(r'^(?:(?:please|can\s+you|could\s+you|also|and|hey|minimo)\s+)*', '', text, flags=re.I).strip()
    clean = re.sub(r'^(?:add\s+(?:a\s+|an\s+|the\s+)?(?:new\s+)?task\s+(?:to|in|into|on)\s+todoist|add\s+(?:a\s+|an\s+|the\s+)?(?:new\s+)?task|create\s+(?:a\s+)?(?:new\s+)?task|remind\s+me\s+(?:to|about|that|for)?|reminder\s+(?:for|to|about)?|todoist\s+add|todo:|task:|add|create|put)\s*', '', clean, flags=re.I).strip()
    clean = re.sub(r'^(?:for|to|about|that|and|on|in|at|:\s*|-)\s+', '', clean, flags=re.I).strip()
    clean = re.sub(r'\s+(?:and\s+)?(?:due(?:\s+by|\s+on|\s+at)?|assign(?:\s+priority)?|priority)\s*$', '', clean, flags=re.I).strip()
    clean = re.sub(r'\s{2,}', ' ', clean).strip()

    title = clean if clean else text
    vague_titles = {"", "this", "that", "it", "something", "task", "new task", "the task", "issue", "the issue", "problem", "the problem", "add task", "create task", "add a task", "on this", "on that", "about this", "about that"}
    is_vague = (not clean) or (title.lower() in vague_titles) or (len(title) < 3)
    
    return {
        "intent": "add_task",
        "task_title": title,
        "task_due": due,
        "task_priority": priority or 4,
        "confidence": 0.35 if is_vague else 0.85,
        "needs_clarification": is_vague,
        "clarification_prompt": "Could you please specify the details or title for this task?" if is_vague else None
    }

def extract_task_cross_matrix(query: str, context_history: Optional[list] = None, regex_priority: Optional[int] = None) -> Dict[str, Any]:
    """
    Cross-Matrix Entity Extractor:
    Uses Qwen 2.5 1.5B (lightweight on CPU) to resolve complex conversational anaphora,
    messy/ungrammatical inputs, and generate clean titles + helpful descriptions.
    """
    system_prompt = (
        "You are an expert NLP entity extractor for Minimo Task Manager.\n"
        "Extract:\n"
        "- title: Short, clean, actionable imperative task title (3-7 words, e.g. 'Fix waybar audio widget crashing', 'Buy groceries', 'Restart production nginx server'). NEVER use meta words like 'Create a reminder' or 'New task' or dates as the title. If the user mentions a bug, glitch, crash, or problem, the title MUST start with 'Fix <issue>'.\n"
        "- description: Synthesize the user's rambling context, backstory, reasons, or details into 1-3 clear sentences. NEVER just repeat the title. End with '\\n\\n— Noted by Kafka'. If user gave zero extra details, set description to '— Noted by Kafka'.\n"
        "- due: Natural language due date/time (e.g. '23rd evening 7pm', 'tomorrow at 10am') or null.\n"
        "- priority: 1 (highest/urgent), 2 (high), 3 (medium), 4 (low/default) or null.\n"
        "- confidence: Float between 0.0 and 1.0 reflecting extraction certainty.\n"
        "Output strictly valid JSON only: {\"title\": \"...\", \"description\": \"...\", \"due\": \"...\"|null, \"priority\": 1|2|3|4|null, \"confidence\": 0.9}\n\n"
        "Examples:\n"
        "Query: \"finetune the ui interactiosn and synth background process cycle also the way how the sources will look in the card with also defining the bot reactions with each end point\"\n"
        "JSON: {\"title\": \"Finetune UI interactions & synth process cycle\", \"description\": \"Finetune UI interactions and synth background process cycle. Refine source card appearance and define bot reactions for each endpoint.\\n\\n— Arranged by Kafka\", \"due\": null, \"priority\": 2, \"confidence\": 0.95}\n\n"
        "Query: \"having difficulty in mpv subtitle rendering create a task due 23rd evening p1\"\n"
        "JSON: {\"title\": \"Fix MPV subtitle rendering\", \"description\": \"Having difficulty in MPV subtitle rendering.\\n\\n— Noted by Kafka\", \"due\": \"23rd evening\", \"priority\": 1, \"confidence\": 0.95}\n\n"
        "Query: \"urgent task to restart production nginx server tonight\"\n"
        "JSON: {\"title\": \"Restart production nginx server\", \"description\": \"Restart production nginx server tonight.\\n\\n— Noted by Kafka\", \"due\": \"tonight\", \"priority\": 1, \"confidence\": 0.95}\n"
    )

    prompt = system_prompt + "\n"
    if context_history:
        prompt += "Recent Context:\n" + json.dumps(context_history[-2:]) + "\n"
    prompt += f'User Query: "{query}"\nJSON:'

    payload = {
        "model": "qwen2.5:1.5b-instruct",
        "prompt": prompt,
        "format": "json",
        "stream": False,
        "think": False,
        "keep_alive": "30m",
        "options": {"temperature": 0.0, "num_predict": 260}
    }

    try:
        req = urllib.request.Request(
            f"{OLLAMA_URL}/api/generate",
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"}
        )
        with urllib.request.urlopen(req, timeout=6.0) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            parsed = json.loads(data.get("response", "{}"))

            raw_title = (parsed.get("title") or query).strip()
            # Clean any residual command prefixes that the LLM left behind
            clean_title = re.sub(r'^(?:(?:please\s+)?(?:create|add|make|set)\s+(?:a\s+|an\s+|the\s+)?(?:new\s+)?(?:task|reminder|todo|alert)\s+(?:for|to|about|on)?|remind\s+me\s+(?:to|about)?)\s*', '', raw_title, flags=re.I).strip()
            clean_title = re.sub(r'^(?:for|to|about|on|that|me\s+on|me\s+to|:\s*|-)\s+', '', clean_title, flags=re.I).strip()

            # If LLM returned a meta title or a date, fall back to query deterministic cleaner
            meta_junk = {"", "tomorrow morning", "tomorrow evening", "today", "tonight", "reminder", "a reminder", "task", "a task"}
            is_date_title = bool(re.search(r'^(?:due|tomorrow|today|tonight|by\s+|at\s+)', clean_title.lower()))
            if clean_title.lower() in meta_junk or is_date_title:
                clean_title = clean_deterministic_task(query, regex_priority).get("task_title", query)

            final_title = clean_title or raw_title
            final_p = regex_priority if regex_priority is not None else parsed.get("priority")
            if final_p is not None:
                try:
                    final_p = int(final_p)
                except Exception:
                    final_p = 4
            else:
                final_p = 2

            desc = (parsed.get("description") or "").strip()
            if desc and "Kafka" not in desc and "Minimo" not in desc:
                desc += "\n\n— Noted by Kafka"
            elif not desc:
                desc = "— Noted by Kafka"

            conf = float(parsed.get("confidence") or 0.85)

            vague_titles = {"", "this", "that", "it", "something", "task", "new task", "the task", "issue", "the issue", "problem", "the problem"}
            if final_title.lower() in vague_titles or len(final_title) < 3:
                conf = min(conf, 0.35)
                needs_clar = True
                prompt_text = f"I detected you want to create a task, but the title '{final_title}' is ambiguous. What would you like to name this task?"
            elif conf < 0.60:
                needs_clar = True
                prompt_text = f"I parsed the task as '{final_title}'. Could you confirm or clarify what you would like to add?"
            else:
                needs_clar = False
                prompt_text = None

            return {
                "intent": "add_task",
                "task_title": final_title,
                "task_description": desc,
                "task_due": parsed.get("due"),
                "task_priority": final_p,
                "confidence": conf,
                "needs_clarification": needs_clar,
                "clarification_prompt": prompt_text
            }
    except Exception:
        return clean_deterministic_task(query, regex_priority)

def classify_intent_llm(query: str, context_history: Optional[list] = None) -> Dict[str, Any]:
    """Lightweight 1.5B Intent Classifier for non-deterministic queries (~1.0s on CPU)."""
    system_prompt = (
        "You are the high-precision intent classifier for Minimo Mind Pilot.\n"
        "Select the SINGLE most appropriate intent:\n"
        "- 'rag_knowledge': Technical, academic, engineering, literature, notes, programming, or factual questions (DEFAULT).\n"
        "- 'chat': Casual greetings (e.g. 'hi', 'how are you'), jokes, or persona questions.\n"
        "- 'add_task': Explicitly create or schedule a new task or reminder.\n"
        "- 'list_tasks': View or check pending tasks.\n"
        "- 'play_media': Stream or play a movie, video, or anime.\n"
        "- 'open_doc': Launch a document viewer (ONLY when user explicitly commands 'open X' or 'view X in zathura', NEVER for questions about content!).\n"
        "- 'run_cmd': Explicit terminal command execution.\n\n"
        "Output strictly valid JSON: {\"intent\": \"...\", \"search_query\": \"...\"|null, \"command\": \"...\"|null, \"media_title\": \"...\"|null}"
    )

    prompt = system_prompt + "\n"
    if context_history:
        prompt += "\nRecent Context:\n" + json.dumps(context_history[-2:]) + "\n"
    prompt += f'\nUser Query: "{query}"\nJSON:'

    payload = {
        "model": "qwen2.5:1.5b-instruct",
        "prompt": prompt,
        "format": "json",
        "stream": False,
        "keep_alive": "30m",
        "options": {"temperature": 0.0, "num_predict": 70}
    }

    try:
        req = urllib.request.Request(
            f"{OLLAMA_URL}/api/generate",
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"}
        )
        with urllib.request.urlopen(req, timeout=5.0) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            parsed = json.loads(data.get("response", "{}"))
            intent = parsed.get("intent")
            if intent in ("rag_knowledge", "chat", "add_task", "list_tasks", "play_media", "run_cmd"):
                return parsed
            elif intent == "open_doc":
                # Guard against false open_doc on query questions
                if any(w in query.lower() for w in ("?", "what", "any", "how", "why", "where", "explain", "derive")):
                    return {"intent": "rag_knowledge", "search_query": query}
                return parsed
    except Exception:
        pass

    return {"intent": "rag_knowledge", "search_query": query}

def select_cpu_synthesis_model(query: str, category_filter: Optional[str] = None, rag_count: int = 0) -> str:
    """
    Granular CPU-Optimized Model Selector:
    - Qwen 3.5 2B / Qwen 2.5 3B: Standard synthesis for notes, books, fluid dynamics, engineering, code, and RAG.
    - Qwen 3.5 0.8B / Qwen 2.5 1.5B: Chitchat, greetings, trivial short queries.
    """
    from .config import get_available_models, get_synthesis_model
    models = get_available_models()
    q_lower = query.lower()

    # Chitchat & Trivial Triggers -> 0.8B / 1.5B
    casual_exact = {'hi', 'hello', 'hey', 'who are you', 'what can you do', 'thanks', 'thank you', 'clear', 'reset'}
    if q_lower in casual_exact or len(query.split()) <= 2:
        if any("qwen3.5:0.8b" in m for m in models):
            return "qwen3.5:0.8b"
        return "qwen2.5:1.5b-instruct"

    # Primary Synthesis Model (Qwen 3.5 2B or Qwen 2.5 3B)
    return get_synthesis_model()
