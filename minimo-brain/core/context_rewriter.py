"""
Minimo Brain Suite - Conversational Context Rewriter (Stage 0)
Resolves anaphora, pronouns, and elliptical follow-up queries using qwen2.5:1.5b-instruct.
"""

import re
import json
import urllib.request
from typing import List, Dict, Optional
from .config import ROUTER_MODEL, OLLAMA_URL

# Fast-path negative filters: queries that are self-contained and should NOT invoke LLM rewriter
NON_REWRITE_PREFIXES = (
    "$", "!", "todo:", "task:", "remind:", "notes:", "book:", "weather", "uptime", "date"
)
EXPLICIT_ATOMIC_COMMANDS = {
    "pause", "resume", "stop", "next", "prev", "previous", "mute", "unmute",
    "clear", "cls", "reset", "quit", "exit"
}

# Indicators of conversational dependence or anaphora
ANAPHORA_PATTERN = re.compile(
    r'\b(?:it|its|that|this|these|those|them|the other|the first|the second|the former|the latter|again)\b',
    re.IGNORECASE
)
CONVERSATIONAL_LEADS = re.compile(
    r'^(?:and|also|then|what about|how about|what of|why|how come|is it|does it|can it|how is it|make that)\b',
    re.IGNORECASE
)

def should_rewrite(query: str, history: Optional[List[Dict[str, str]]]) -> bool:
    """Zero-latency heuristic filter to avoid LLM calls on self-contained queries."""
    if not history or len(history) == 0:
        return False
    
    q = query.strip()
    if not q:
        return False
    
    q_lower = q.lower()
    if q_lower in EXPLICIT_ATOMIC_COMMANDS:
        return False
    if any(q_lower.startswith(p) for p in NON_REWRITE_PREFIXES):
        return False

    # Check for pronoun or anaphora references
    if ANAPHORA_PATTERN.search(q):
        return True
    
    # Check for conversational lead-in
    if CONVERSATIONAL_LEADS.search(q):
        return True
    
    # Very short elliptical follow-up queries (< 4 words) without explicit action/subject
    words = q.split()
    if len(words) <= 3 and not any(w in ("play", "search", "open", "find", "add", "run") for w in words):
        return True

    return False

def rewrite_conversational_context(
    query: str,
    history: Optional[List[Dict[str, str]]],
    model: str = ROUTER_MODEL,
    timeout_sec: float = 2.0
) -> str:
    """
    Rewrites a follow-up query into a self-contained standalone sentence.
    Falls back gracefully to the original query on error or timeout.
    """
    if not should_rewrite(query, history):
        return query

    try:
        # Build compact history summary (last 2 turns)
        hist_turns = []
        for h in history[-2:]:
            q_txt = h.get("q", "").strip()
            a_txt = h.get("a", "").strip()
            if q_txt:
                # Truncate assistant answer if too long to keep prompt tiny
                a_snippet = (a_txt[:120] + "...") if len(a_txt) > 120 else a_txt
                hist_turns.append(f"User: {q_txt}\nAssistant: {a_snippet}")
        
        if not hist_turns:
            return query
            
        hist_text = "\n".join(hist_turns)

        prompt = f"""<|im_start|>system
You are a search query reformulation tool.
Your job is to rewrite follow-up questions or commands into a standalone search query or command by replacing pronouns (it, that, them, its) and references with the actual subjects from context.
Never answer the question. Never guess new facts. Only substitute the missing context.

Examples:
Context:
User: what is Fanno flow?
Assistant: Fanno flow refers to adiabatic flow through a constant area duct.
Follow-up: and what about Rayleigh flow?
Standalone: what is Rayleigh flow?

Context:
User: what is Fanno flow?
Assistant: Fanno flow is adiabatic flow with friction.
Follow-up: is it adiabatic or frictionless?
Standalone: is Fanno flow adiabatic or frictionless?

Context:
User: add task finish homework due tomorrow
Assistant: Added task to Todoist.
Follow-up: make that p1
Standalone: add task finish homework due tomorrow p1

Context:
User: search local movies Spirited Away
Assistant: Found Spirited Away in local movies.
Follow-up: play it
Standalone: play movie Spirited Away
<|im_end|>
<|im_start|>user
Context:
{hist_text}
Follow-up: {query}
Standalone:
<|im_end|>
<|im_start|>assistant
"""
        req_data = {
            "model": model,
            "prompt": prompt,
            "stream": False,
            "options": {
                "num_predict": 28,
                "temperature": 0.0,
                "stop": ["\n", "<|im_end|>", "User:", "Assistant:", "Context:"]
            }
        }
        req = urllib.request.Request(
            f"{OLLAMA_URL}/api/generate",
            data=json.dumps(req_data).encode("utf-8"),
            headers={"Content-Type": "application/json"}
        )
        with urllib.request.urlopen(req, timeout=timeout_sec) as r:
            res = json.loads(r.read().decode("utf-8"))
            candidate = res.get("response", "").strip()
            
            # Post-clean: strip accidental 'Standalone:' or quotes
            candidate = re.sub(r'^(?:Standalone\s*:\s*|Query\s*:\s*)', '', candidate, flags=re.IGNORECASE).strip()
            candidate = candidate.strip('"`\'')
            if candidate and len(candidate) > 2 and not candidate.lower().startswith("i cannot"):
                return candidate
    except Exception:
        pass

    return query
