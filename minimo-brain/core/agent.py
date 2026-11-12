"""
Minimo Brain Suite - Cognitive Agentic Pipeline & Multi-Step Reasoning Engine
Empowers Minimo with tool use, live desktop context, ReAct loops, and rich synthesis.
"""

import os
import re
import json
import asyncio
import subprocess
from typing import Dict, Any, List, Optional, AsyncGenerator

from .config import OLLAMA_URL, get_synthesis_model, get_router_model
from .system_context import get_full_system_context, format_system_context_prompt
from .rag import search_library_rag, search_mindspace
from .tasks import get_tasks, add_task, toggle_task, delete_task
from .media import search_local_movies
from .synthesis import clean_math_notation

# Available agent tools schema for the LLM
TOOLS_REGISTRY = [
    {
        "name": "search_knowledge_vault",
        "description": "Search indexed technical textbooks, academic PDFs, and personal markdown/org notes.",
        "parameters": {"query": "string (technical concept or topic)", "category": "optional 'books' or 'notes'"}
    },
    {
        "name": "search_clipboard_history",
        "description": "Search personal clipboard history, clips, and saved code stashes in Mindspace.",
        "parameters": {"query": "string (search terms for clipped content)"}
    },
    {
        "name": "manage_tasks",
        "description": "Inspect, list, create, or mark Todoist tasks.",
        "parameters": {
            "action": "'list', 'add', 'complete', or 'delete'",
            "title": "task title (required if adding)",
            "due": "optional due date string e.g. 'tomorrow at 5pm'",
            "priority": "optional 1 (urgent/highest, P1) to 4 (normal/lowest, P4)",
            "target": "task ID or keyword to complete/delete"
        }
    },
    {
        "name": "get_desktop_and_system_state",
        "description": "Inspect real-time Hyprland focused window, active application, CPU/RAM telemetry, audio volume, and media playback.",
        "parameters": {}
    },
    {
        "name": "control_media_player",
        "description": "Control audio or video playback (play-pause, stop, play song from MPD/YouTube).",
        "parameters": {
            "action": "'play-pause', 'stop', 'play_song', or 'status'",
            "query": "optional song name or query"
        }
    },
    {
        "name": "run_terminal_command",
        "description": "Execute a safe, non-destructive Linux terminal command and inspect output.",
        "parameters": {"command": "string (bash command line)"}
    },
    {
        "name": "get_email_summary",
        "description": "Scan and summarize recent emails from local Maildir (e.g. last hour, today, last 5 emails).",
        "parameters": {
            "query": "string (e.g. 'last hour', 'today', 'last 5 emails')",
            "limit": "optional integer limit (default 5)"
        }
    }
]

def execute_tool_sync(tool_name: str, args: Dict[str, Any]) -> Dict[str, Any]:
    """Execute tool deterministically and return structured result."""
    try:
        if tool_name == "search_knowledge_vault":
            q = args.get("query", "")
            cat = args.get("category")
            hits = search_library_rag(q, limit=4, category_filter=cat)
            return {"hits": hits, "count": len(hits)}

        elif tool_name == "search_clipboard_history":
            q = args.get("query", "")
            items = search_mindspace(q, limit=4)
            return {"items": items, "count": len(items)}

        elif tool_name == "manage_tasks":
            act = args.get("action", "list")
            if act == "list":
                tasks = get_tasks()
                return {"tasks": tasks, "count": len(tasks)}
            elif act == "add":
                title = args.get("title", "New Task")
                due = args.get("due")
                p = args.get("priority")
                created = add_task(title, due=due, priority=p)
                return {"created": created, "status": "ok" if created else "error"}
            elif act in ("complete", "delete"):
                target = args.get("target", "").lower()
                tasks = get_tasks()
                matched = next((t for t in tasks if target in (t.get("content") or "").lower() or t.get("id") == target), None)
                if matched:
                    if act == "complete":
                        toggle_task(matched["id"])
                    else:
                        delete_task(matched["id"])
                    return {"status": "ok", "action": act, "task": matched["content"]}
                return {"status": "not_found", "target": target}

        elif tool_name == "get_desktop_and_system_state":
            return get_full_system_context()

        elif tool_name == "control_media_player":
            act = args.get("action", "play-pause")
            if act == "stop":
                from .media import stop_all_audio
                stop_all_audio()
                return {"status": "stopped"}
            elif act == "play-pause":
                subprocess.run(["playerctl", "play-pause"], capture_output=True, timeout=1.0)
                return {"status": "toggled"}
            elif act == "play_song":
                q = args.get("query", "")
                from .media import search_mpd_library, play_mpd_song, play_youtube_audio
                hits = search_mpd_library(q)
                if hits:
                    play_mpd_song(hits[0])
                    return {"status": "playing_mpd", "track": hits[0]}
                else:
                    play_youtube_audio(q)
                    return {"status": "streaming_youtube", "track": q}

        elif tool_name == "run_terminal_command":
            cmd = args.get("command", "").strip()
            # Safety filter against catastrophic commands
            forbidden = ("rm -rf /", "mkfs", "dd if=", ":(){ :|:& };:", "shutdown", "reboot")
            if any(f in cmd for f in forbidden):
                return {"error": "Command blocked by security policy"}
            res = subprocess.run(cmd, shell=True, text=True, capture_output=True, timeout=8.0)
            return {
                "exit_code": res.returncode,
                "stdout": (res.stdout or "").strip()[:1500],
                "stderr": (res.stderr or "").strip()[:500]
            }

        elif tool_name == "get_email_summary":
            from .emails import parse_email_query_params, fetch_recent_emails
            q_str = args.get("query", "")
            p = parse_email_query_params(q_str)
            limit = args.get("limit") or p.get("limit", 5)
            emails = fetch_recent_emails(
                duration_seconds=p.get("duration_seconds"),
                since_timestamp=p.get("since_timestamp"),
                limit=limit
            )
            return {
                "query_desc": p.get("query_desc"),
                "count": len(emails),
                "emails": [
                    {
                        "sender": em["sender"],
                        "subject": em["subject"],
                        "time_ago": em["time_ago"],
                        "snippet": em["snippet"][:200]
                    }
                    for em in emails
                ]
            }

        return {"error": f"Unknown tool: {tool_name}"}
    except Exception as e:
        return {"error": str(e)}

async def run_agent_stream(
    query: str,
    context_history: Optional[List[Dict[str, str]]] = None,
    mode: str = "all",
    max_steps: int = 3
) -> AsyncGenerator[Dict[str, Any], None]:
    """
    Cognitive Agent Reasoning & Execution Loop:
    1. Obtains real-time system context (Hyprland window, resource loads, media).
    2. Plans tools or executes direct synthesis.
    3. Streams status, thoughts, tool executions, and tokens.
    """
    sys_context = await asyncio.to_thread(get_full_system_context)
    prompt_context = format_system_context_prompt(sys_context)

    # Convert conversation history
    messages = [
        {
            "role": "system",
            "content": (
                "You are Minimo Mind Pilot — a sleek, highly capable desktop AI companion and cognitive OS brain.\n"
                f"{prompt_context}\n\n"
                "You have access to desktop tools to inspect system state, search personal knowledge vaults/notes, "
                "manage Todoist tasks, control media playback, and run shell commands.\n"
                "If answering the user's query requires real-time facts, textbook definitions, task operations, or system inspection, "
                "CALL THE APPROPRIATE TOOL using this strict format:\n"
                "`TOOL_CALL: tool_name(json_args)`\n\n"
                "Example:\n"
                "`TOOL_CALL: search_knowledge_vault({\"query\": \"fanno flows adiabatic\"})`\n"
                "`TOOL_CALL: manage_tasks({\"action\": \"list\"})`\n"
                "`TOOL_CALL: get_desktop_and_system_state({})`\n\n"
                "If no tools are required (e.g. casual chat, general conceptual logic, or simple questions), synthesize directly in markdown.\n"
                "Format math with clean Unicode (α, β, γ, ṁ, q̇, √, ±, ², ·). Avoid raw LaTeX backslashes."
            )
        }
    ]

    if context_history:
        for turn in context_history[-3:]:
            if turn.get("q"):
                messages.append({"role": "user", "content": turn["q"]})
            if turn.get("a"):
                messages.append({"role": "assistant", "content": turn["a"]})

    messages.append({"role": "user", "content": query})

    current_step = 0
    from .router import select_cpu_synthesis_model
    synthesis_model = select_cpu_synthesis_model(query)

    while current_step < max_steps:
        current_step += 1
        yield {"type": "status", "text": f"Reasoning (Step {current_step})...", "reaction": "thinking"}

        # Request response from synthesis model
        payload = {
            "model": synthesis_model,
            "messages": messages,
            "stream": True,
            "keep_alive": "30m",
            "options": {"temperature": 0.2, "num_predict": 450}
        }

        import httpx
        collected_text = []
        is_tool_call = False
        tool_call_match = None

        try:
            async with httpx.AsyncClient(timeout=45.0) as client:
                async with client.stream("POST", f"{OLLAMA_URL}/api/chat", json=payload) as resp:
                    async for line in resp.aiter_lines():
                        if not line:
                            continue
                        chunk = json.loads(line)
                        msg = chunk.get("message", {})
                        tok = msg.get("content", "")
                        collected_text.append(tok)
                        current_str = "".join(collected_text)

                        # Check if model began emitting a TOOL_CALL
                        if "TOOL_CALL:" in current_str and not is_tool_call:
                            is_tool_call = True
                            yield {"type": "status", "text": "Selecting agentic tool...", "reaction": "curious"}

                        if not is_tool_call:
                            # Stream tokens to client in real-time
                            yield {"type": "token", "text": tok}

                        if chunk.get("done", False):
                            break
        except Exception as e:
            yield {"type": "token", "text": f"\n\n*(Agent engine error: {e})*"}
            yield {"type": "done", "reaction": "neutral"}
            return

        full_output = "".join(collected_text).strip()

        # Check for tool call
        m = re.search(r'TOOL_CALL:\s*([a-zA-Z0-9_]+)\s*\((.*?)\)', full_output, re.DOTALL)
        if m:
            tool_name = m.group(1).strip()
            args_str = m.group(2).strip()
            try:
                tool_args = json.loads(args_str) if args_str else {}
            except Exception:
                tool_args = {}

            yield {"type": "status", "text": f"Executing `{tool_name}`...", "reaction": "writing"}
            yield {
                "type": "agent_action",
                "tool": tool_name,
                "args": tool_args
            }

            # Execute tool
            tool_result = await asyncio.to_thread(execute_tool_sync, tool_name, tool_args)

            # Emit action cards if RAG or Tasks returned results
            if tool_name == "search_knowledge_vault" and "hits" in tool_result:
                for hit in tool_result["hits"]:
                    fp = hit["filepath"]
                    is_pdf = fp.lower().endswith(".pdf")
                    yield {
                        "type": "action_card",
                        "card_type": "book" if is_pdf else "note",
                        "title": hit["filename"],
                        "subtitle": f"{hit['category'].upper()} • Page/Line {hit['page']}",
                        "snippet": hit.get("snippet", ""),
                        "icon": "book-open" if is_pdf else "file-document",
                        "action_type": "open_book" if is_pdf else "open_note",
                        "action_payload": f"{fp}:::{hit['page']}",
                        "badge": f"{int(hit['score'] * 100)}% REL"
                    }

            # Feed tool result back to the conversation
            messages.append({"role": "assistant", "content": full_output})
            messages.append({
                "role": "user",
                "content": f"[TOOL_RESULT for {tool_name}]:\n{json.dumps(tool_result, ensure_ascii=False)}\n\nNow synthesize the complete, direct answer for the user based on these results."
            })
            # Continue to next step to let the model generate the final synthesis
            continue
        else:
            # Final direct answer completed
            break

    yield {"type": "done", "reaction": "happyBounce"}
