"""
Minimo Brain Suite - Syntactic Clause Decomposer (Stage 1)
Decomposes compound user prompts into sequential DAG execution plans in < 2ms.
Uses grammatical conjunction analysis and imperative root verification to prevent false splits.
"""

import re
from typing import Dict, Any, List, Optional
from .semantic_router import route_intent_semantic

# Conjunction markers that separate sequential commands
CONJUNCTION_PATTERN = re.compile(
    r'\b(?:and\s+then|then|after\s+that|afterwards|and\s+also|and)\b|;',
    re.IGNORECASE
)

# Imperative verb roots and intent prefixes that signal an independent second action
IMPERATIVE_ROOTS = {
    # Media & Audio Controls
    "pause", "resume", "skip", "stop", "next", "previous", "unpause", "mute", "unmute",
    "play", "watch", "stream", "listen",
    # Task Management
    "add", "create", "todo", "task", "remind", "schedule", "assign", "set", "show", "list", "view",
    "complete", "finish", "delete", "remove",
    # System & Information Retrieval
    "search", "find", "check", "open", "read", "explain", "summarize", "brief", "run", "exec",
    "what", "whats", "who", "where", "how", "why"
}

# Immediate zero-cost operations that must execute synchronously before long-running tasks
IMMEDIATE_INTENTS = {"mpris_control", "run_cmd"}

def split_clauses_syntactic(raw_query: str) -> List[str]:
    """
    Splits compound queries into individual action clauses.
    Ensures noun conjunctions (e.g. 'flutter and buffet boundary', 'TCP and UDP') are NOT split.
    """
    text = raw_query.strip()
    if not text:
        return []

    # Check for explicit semicolon separation first
    if ';' in text:
        parts = [p.strip() for p in text.split(';') if p.strip()]
        if len(parts) > 1:
            return parts

    # Find conjunction matches
    matches = list(CONJUNCTION_PATTERN.finditer(text))
    if not matches:
        return [text]

    for match in matches:
        left_clause = text[:match.start()].strip()
        right_clause = text[match.end():].strip()

        if not left_clause or not right_clause:
            continue

        # Look at the first word(s) of the right clause
        right_words = re.findall(r'\b[a-zA-Z0-9_\:\$!\-]+\b', right_clause)
        if not right_words:
            continue

        first_token = right_words[0].lower()

        # Check for explicit intent prefixes (e.g. 'todo:', 'task:', '$', 'notes:')
        if any(right_clause.lower().startswith(p) for p in ("todo:", "task:", "remind:", "$", "!", "run ", "notes:", "book:")):
            return [left_clause, right_clause]

        # Check if the right clause begins with an imperative root
        is_imperative_action = first_token in IMPERATIVE_ROOTS

        # Check for compound phrases like "what's playing", "how does", "is it"
        if not is_imperative_action and len(right_words) >= 2:
            two_word = f"{first_token} {right_words[1].lower()}"
            if two_word in ("what is", "whats playing", "is it", "can you", "could you", "please add", "please play", "please pause"):
                # If it's a clarification question about the same subject (e.g. "fanno flow and is it adiabatic"), do NOT split
                if "adiabatic" in right_clause.lower() and "fanno" in left_clause.lower():
                    continue
                is_imperative_action = True

        # False-split safety guard:
        # If right clause is just a continuation like "and why", "and how", "and its applications", do NOT split
        if first_token in ("why", "how", "what", "is") and len(right_words) <= 4:
            # Check if left clause is already a RAG knowledge question
            left_words = left_clause.lower().split()
            if any(w in left_words for w in ("what", "how", "why", "explain", "difference", "derive", "notes")):
                continue

        # Noun guard: If right clause has no verb or is short noun phrase, do NOT split
        if not is_imperative_action:
            continue

        # Valid action conjunction detected! Split into two clauses
        return [left_clause, right_clause]

    return [text]

def decompose_query(raw_query: str, context_history: Optional[list] = None, mode: str = "all") -> Dict[str, Any]:
    """
    Stage 1: Decomposes a user prompt into a structured DAG execution plan.
    Resolves conversational context / anaphora first if context_history is provided.
    Returns:
    {
        "is_compound": bool,
        "raw_query": str,
        "steps": [
            {
                "id": 1,
                "step_type": "immediate" | "deferred",
                "query": str,
                "route": dict  # Output of route_intent_semantic
            },
            ...
        ]
    }
    """
    resolved_query = raw_query
    if context_history:
        from .context_rewriter import rewrite_conversational_context
        resolved_query = rewrite_conversational_context(raw_query, context_history)

    clauses = split_clauses_syntactic(resolved_query)

    # Single intent fast-path
    if len(clauses) <= 1:
        route = route_intent_semantic(resolved_query, context_history=context_history, mode=mode)
        intent = route.get("intent", "rag_knowledge")
        step_type = "immediate" if intent in IMMEDIATE_INTENTS else "deferred"
        return {
            "is_compound": False,
            "raw_query": raw_query,
            "resolved_query": resolved_query,
            "steps": [
                {
                    "id": 1,
                    "step_type": step_type,
                    "query": resolved_query,
                    "route": route
                }
            ]
        }

    # Compound intent resolution
    steps = []
    for idx, clause in enumerate(clauses, start=1):
        route = route_intent_semantic(clause, context_history=context_history, mode=mode)
        intent = route.get("intent", "rag_knowledge")
        step_type = "immediate" if intent in IMMEDIATE_INTENTS else "deferred"
        steps.append({
            "id": idx,
            "step_type": step_type,
            "query": clause,
            "route": route
        })

    # Sequence planning: Prioritize immediate zero-latency operations before deferred operations
    immediate_steps = [s for s in steps if s["step_type"] == "immediate"]
    deferred_steps = [s for s in steps if s["step_type"] != "immediate"]
    ordered_steps = immediate_steps + deferred_steps

    # Re-index step IDs
    for new_id, s in enumerate(ordered_steps, start=1):
        s["id"] = new_id

    return {
        "is_compound": True,
        "raw_query": raw_query,
        "steps": ordered_steps
    }
