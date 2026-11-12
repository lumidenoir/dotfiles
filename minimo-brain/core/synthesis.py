"""
Minimo Brain Suite - Cognitive Synthesis Engine (Streaming Qwen 2.5 7B)
Supports both Async (FastAPI / WebSockets) and Sync (Desktop IPC / CLI)
"""

import os
import re
import json
import urllib.request
from typing import List, Dict, Any, Optional, AsyncGenerator, Generator
import httpx
from .config import OLLAMA_URL, get_synthesis_model
from .router import select_cpu_synthesis_model

def clean_math_notation(text: str) -> str:
    """
    Ensures mathematical notation uses clean, elegant Unicode symbols
    rather than messy raw LaTeX escapes.
    """
    replacements = [
        (r'\\frac\{([^}]+)\}\{([^}]+)\}', r'(\1 / \2)'),
        (r'\\sqrt\{([^}]+)\}', r'√(\1)'),
        (r'\\cdot', '·'),
        (r'\\times', '×'),
        (r'\\pm', '±'),
        (r'\\approx', '≈'),
        (r'\\neq', '≠'),
        (r'\\leq', '≤'),
        (r'\\geq', '≥'),
        (r'\\alpha', 'α'),
        (r'\\beta', 'β'),
        (r'\\gamma', 'γ'),
        (r'\\delta', 'δ'),
        (r'\\Delta', 'Δ'),
        (r'\\theta', 'θ'),
        (r'\\lambda', 'λ'),
        (r'\\mu', 'μ'),
        (r'\\pi', 'π'),
        (r'\\rho', 'ρ'),
        (r'\\sigma', 'σ'),
        (r'\\tau', 'τ'),
        (r'\\phi', 'φ'),
        (r'\\omega', 'ω'),
        (r'\\dot\{m\}', 'ṁ'),
        (r'\\dot\{x\}', 'ẋ'),
        (r'\\dot\{q\}', 'q̇'),
        (r'\\dot\{V\}', 'V̇'),
        (r'\\dot\{W\}', 'Ẇ'),
        (r'\\left', ''),
        (r'\\right', ''),
        (r'\\\(', ''),
        (r'\\\)', ''),
        (r'\\\[', '\n'),
        (r'\\\]', '\n'),
    ]
    cleaned = text
    for pat, rep in replacements:
        cleaned = re.sub(pat, rep, cleaned)
    return cleaned

def build_context_messages(context_history: list) -> list:
    """Convert [{q, a}] history into Ollama message pairs (last 2 turns max)."""
    messages = []
    if not context_history:
        return messages
    for turn in context_history[-2:]:
        q = (turn.get("q") or "").strip()
        a = (turn.get("a") or "").strip()
        if q:
            messages.append({"role": "user", "content": q})
        if a:
            messages.append({"role": "assistant", "content": a})
    return messages

def get_system_prompt(has_rag: bool = True) -> str:
    rag_clause = (
        "The user has queried their personal library or notes. Relevant excerpts have already been retrieved and provided above.\n"
        if has_rag else
        "The user has asked a direct technical, conceptual, or programming question.\n"
    )
    return (
        "You are Minimo Mind Pilot, speaking with the poised, unhurried cadence of Kafka from Honkai: Star Rail.\n"
        f"{rag_clause}"
        "PERSONA ANCHOR & STYLE:\n"
        "- Begin your response with a brief, poised one-line opening hook suited to the user's question. Do not quote canned examples.\n"
        "- In the main body, provide clear, accurate, and rigorous explanations directly addressing what the user asked. Keep technical facts and formulas completely truthful without compromising substance.\n"
        "- Conclude with a single, elegant one-line closing wrap.\n"
        "SYNTHESIS RULES:\n"
        "- Synthesize a direct, insightful response answering the query directly.\n"
        "- If excerpts are provided, ground your answer in them; if a concept is not fully covered by excerpts or no excerpts are present, answer thoroughly using foundational principles.\n"
        "- Never output meta-search instructions like 'use grep or find to search' — the search is already complete.\n"
        "- Do NOT append a 'Sources Cited', 'References', or bibliography section at the end of your response, as the desktop UI automatically renders dedicated interactive source cards below your answer.\n"
        "- Conclude your explanation directly with your one-line closing wrap.\n"
        "- Be neutral, balanced, and objective. Do not bias the explanation toward any single sub-topic unless explicitly asked.\n"
        "CODING & SCRIPTING:\n"
        "- When the user asks for code, scripts, or implementations (e.g. MATLAB, Python, C++, Bash), provide complete, elegant, and working code blocks enclosed in markdown triple backticks with the language identifier (e.g. ```matlab ... ```).\n"
        "- Include concise comments explaining critical logic, matrix dimensions, and plotting parameters.\n"
        "NOTATION:\n"
        "- Avoid raw LaTeX backslash commands (such as \\frac, \\sqrt, \\left, \\right, \\dot, or \\(...\\)).\n"
        "- Write all formulas and symbols using clean Unicode characters (Greek letters, superscripts, subscripts, standard mathematical operators).\n"
    )


def get_email_system_prompt() -> str:
    """Dedicated system prompt for email briefing — Kafka as an executive assistant."""
    return (
        "You are Kafka — poised, perceptive, and unhurried. You serve as a personal executive secretary briefing your employer on their incoming correspondence.\n"
        "Your tone is calm, precise, and slightly wry — like a trusted aide who has already read everything so they don't have to.\n"
        "BRIEFING STYLE:\n"
        "- Go through each email one by one in a clean bullet format.\n"
        "- For each email: mention who sent it, what it is actually about (not just the subject), and flag any deadlines, action items, or things that need attention.\n"
        "- Keep each email strictly to 1–2 tight sentences. No filler. Never produce numbered sub-lists.\n"
        "- Highlight important dates or deadlines in **bold**.\n"
        "- You MUST complete the summary for all emails without stopping mid-sentence.\n"
        "- End with a brief one-liner observation or closing remark in character.\n"
        "OUTPUT FORMAT:\n"
        "- Use bullet items (•) per email.\n"
        "- Separate each with a blank line.\n"
        "- Do NOT add section headers like 'Summary' or 'Overview'. Just the briefing, directly.\n"
    )

def _prepare_synthesis_context(
    query: str,
    rag_results: Optional[List[Dict[str, Any]]] = None,
    context_history: Optional[list] = None
) -> tuple:
    action_cards = []
    context_parts = []
    if rag_results:
        max_score = rag_results[0].get('score', 1.0) if rag_results else 1.0
        for r in rag_results:
            is_note = r.get('is_note', r['filepath'].lower().endswith(('.org', '.md', '.txt')))
            card_t = "note" if is_note else "book"
            icon = "󰠮" if is_note else "󰂿"
            act_type = r.get("action_type") or ("open_note" if is_note else "open_book")
            label = r.get('filename', 'Document')
            p_val = str(r.get('page', 1))
            subtitle = f"Line {p_val}" if is_note else f"Page {p_val}"
            badge_lbl = r.get("badge") or (f"NOTE · L{p_val}" if is_note else f"PDF · p. {p_val}")
            citation_str = r.get("citation") or f"{label} ({subtitle})"
            act_payload = r.get("action_payload") or f"{r['filepath']}:::{p_val}"

            raw_ratio = (r.get('score', 0) / max_score) if max_score > 0 else 1.0
            rel_pct = max(45, min(98, round(raw_ratio * 95)))
            context_parts.append(f"[{citation_str}]:\n{r['snippet']}")
            action_cards.append({
                "type": "action_card",
                "card_type": card_t,
                "title": label,
                "subtitle": subtitle,
                "snippet": r['snippet'],
                "icon": icon,
                "action_type": act_type,
                "action_payload": act_payload,
                "badge": badge_lbl,
                "citation": citation_str,
                "relevance_pct": rel_pct
            })

    user_content = query
    if context_parts:
        user_content = "Relevant excerpts from local library and notes:\n" + "\n---\n".join(context_parts) + f"\n\nUser question: {query}"

    messages = [{"role": "system", "content": get_system_prompt(has_rag=bool(context_parts))}]
    if context_history:
        messages.extend(build_context_messages(context_history))
    messages.append({"role": "user", "content": user_content})

    return action_cards, messages

async def stream_synthesis_async(
    query: str,
    rag_results: Optional[List[Dict[str, Any]]] = None,
    context_history: Optional[list] = None,
    num_predict: int = 520
) -> AsyncGenerator[Dict[str, Any], None]:
    """
    Asynchronous generator for FastAPI and WebSocket streaming.
    """
    action_cards, messages = _prepare_synthesis_context(query, rag_results, context_history)

    for card in action_cards:
        yield card

    yield {"type": "status", "text": "Synthesizing answer...", "reaction": "curious"}

    target_model = select_cpu_synthesis_model(query, rag_count=len(rag_results or []))
    should_think = any(w in query.lower() for w in ("derive", "step-by-step", "formal proof", "rigorous", "deep derivation", "think"))
    payload = {
        "model": target_model,
        "messages": messages,
        "stream": True,
        "think": should_think,
        "keep_alive": "30m",
        "options": {
            "temperature": 0.35,
            "num_predict": num_predict,
            "top_p": 0.9,
            "num_thread": 4,
        }
    }

    STOP_SOURCES_REGEX = re.compile(r'(?:\n+\s*(?:###?\s*)?(?:Sources(?:\s+Cited)?|References|Bibliography)\b)', re.IGNORECASE)
    buffer = ""
    emitted_len = 0
    should_stop = False

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            async with client.stream("POST", f"{OLLAMA_URL}/api/chat", json=payload) as resp:
                async for raw_line in resp.aiter_lines():
                    line = raw_line.strip()
                    if not line:
                        continue
                    try:
                        data = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    content = data.get("message", {}).get("content", "")
                    if content and not should_stop:
                        buffer += content
                        m = STOP_SOURCES_REGEX.search(buffer)
                        if m:
                            clean_part = buffer[:m.start()].rstrip()
                            to_emit = clean_part[emitted_len:]
                            if to_emit:
                                yield {"type": "token", "text": to_emit}
                            should_stop = True
                            break
                        else:
                            if len(buffer) - emitted_len > 25:
                                safe_len = len(buffer) - 20
                                to_emit = buffer[emitted_len:safe_len]
                                if to_emit:
                                    yield {"type": "token", "text": to_emit}
                                    emitted_len += len(to_emit)

                    if data.get("done", False):
                        break

        if not should_stop and len(buffer) > emitted_len:
            tail = buffer[emitted_len:]
            if tail:
                yield {"type": "token", "text": tail}
    except Exception as e:
        yield {"type": "token", "text": f"\n\n*(Synthesis connection error: {e})*"}

    yield {"type": "done", "reaction": "happyBounce"}


async def stream_email_synthesis_async(
    emails_prompt: str,
    num_predict: int = 1200
) -> AsyncGenerator[Dict[str, Any], None]:
    """
    Dedicated email briefing generator using Kafka executive-assistant persona.
    Uses a separate system prompt — never the library RAG prompt.
    """
    messages = [
        {"role": "system", "content": get_email_system_prompt()},
        {"role": "user", "content": emails_prompt}
    ]

    payload = {
        "model": "qwen2.5:1.5b-instruct",
        "messages": messages,
        "stream": True,
        "think": False,
        "keep_alive": "30m",
        "options": {
            "temperature": 0.35,
            "repeat_penalty": 1.15,
            "num_predict": num_predict,
            "top_p": 0.9,
            "num_thread": 4,
        }
    }

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            async with client.stream("POST", f"{OLLAMA_URL}/api/chat", json=payload) as resp:
                async for raw_line in resp.aiter_lines():
                    line = raw_line.strip()
                    if not line:
                        continue
                    try:
                        data = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    content = data.get("message", {}).get("content", "")
                    if content:
                        yield {"type": "token", "text": content}
                    if data.get("done", False):
                        break
    except Exception as e:
        yield {"type": "token", "text": f"\n\n*(Email synthesis error: {e})*"}

    yield {"type": "done", "reaction": "reading"}

def stream_synthesis_sync(
    query: str,
    rag_results: Optional[List[Dict[str, Any]]] = None,
    context_history: Optional[list] = None,
    num_predict: int = 520
) -> Generator[Dict[str, Any], None, None]:
    """
    Synchronous generator for local desktop CLI or Mind Pilot agent.
    """
    action_cards, messages = _prepare_synthesis_context(query, rag_results, context_history)

    for card in action_cards:
        yield card

    yield {"type": "status", "text": "Synthesizing answer...", "reaction": "curious"}

    target_model = select_cpu_synthesis_model(query, rag_count=len(rag_results or []))
    should_think = any(w in query.lower() for w in ("derive", "step-by-step", "formal proof", "rigorous", "deep derivation", "think"))
    payload = {
        "model": target_model,
        "messages": messages,
        "stream": True,
        "think": should_think,
        "keep_alive": "30m",
        "options": {
            "temperature": 0.35,
            "num_predict": num_predict,
            "top_p": 0.9,
            "num_thread": 4,
        }
    }
    req = urllib.request.Request(
        f"{OLLAMA_URL}/api/chat",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"}
    )
    STOP_SOURCES_REGEX = re.compile(r'(?:\n+\s*(?:###?\s*)?(?:Sources(?:\s+Cited)?|References|Bibliography)\b)', re.IGNORECASE)
    buffer = ""
    emitted_len = 0
    should_stop = False

    try:
        with urllib.request.urlopen(req, timeout=25) as resp:
            for raw_line in resp:
                line = raw_line.decode("utf-8").strip()
                if not line:
                    continue
                try:
                    data = json.loads(line)
                except json.JSONDecodeError:
                    continue
                content = data.get("message", {}).get("content", "")
                if content and not should_stop:
                    buffer += content
                    m = STOP_SOURCES_REGEX.search(buffer)
                    if m:
                        clean_part = buffer[:m.start()].rstrip()
                        to_emit = clean_part[emitted_len:]
                        if to_emit:
                            yield {"type": "token", "text": to_emit}
                        should_stop = True
                        break
                    else:
                        if len(buffer) - emitted_len > 25:
                            safe_len = len(buffer) - 20
                            to_emit = buffer[emitted_len:safe_len]
                            if to_emit:
                                yield {"type": "token", "text": to_emit}
                                emitted_len += len(to_emit)

                if data.get("done", False):
                    break

        if not should_stop and len(buffer) > emitted_len:
            tail = buffer[emitted_len:]
            if tail:
                yield {"type": "token", "text": tail}
    except Exception as e:
        yield {"type": "token", "text": f"\n\n*(Synthesis connection error: {e})*"}

    yield {"type": "done", "reaction": "happyBounce"}


async def stream_chat_async(
    query: str,
    context_history: Optional[list] = None,
    num_predict: int = 350
) -> AsyncGenerator[Dict[str, Any], None]:
    """
    Direct conversational chat generator with Kafka persona (zero RAG clutter).
    """
    sys_prompt = (
        "You are Kafka — the calm, elegant, teasing, and perceptive companion from Honkai: Star Rail.\n"
        "You speak with an unhurried, hypnotic, and poised cadence. You often begin with 'Listen...', address the user warmly yet knowingly, and exude effortless control.\n"
        "Keep your responses direct, stylish, concise, and helpful. You are running as their personal desktop pilot on Hyprland.\n"
        "Format commands, code, or key points in clean markdown.\n"
    )
    messages = [{"role": "system", "content": sys_prompt}]
    if context_history:
        messages.extend(build_context_messages(context_history))
    messages.append({"role": "user", "content": query})

    yield {"type": "status", "text": "Listening...", "reaction": "curious"}

    payload = {
        "model": "qwen2.5:1.5b-instruct",
        "messages": messages,
        "stream": True,
        "think": False,
        "keep_alive": "30m",
        "options": {
            "temperature": 0.65,
            "num_predict": num_predict,
            "top_p": 0.9,
            "num_thread": 4,
        }
    }

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            async with client.stream("POST", f"{OLLAMA_URL}/api/chat", json=payload) as resp:
                async for raw_line in resp.aiter_lines():
                    line = raw_line.strip()
                    if not line:
                        continue
                    try:
                        data = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    content = data.get("message", {}).get("content", "")
                    if content:
                        yield {"type": "token", "text": content}
                    if data.get("done", False):
                        break
    except Exception as e:
        yield {"type": "token", "text": f"\n\n*(Chat error: {e})*"}

    yield {"type": "done", "reaction": "nod"}

