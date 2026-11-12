#!/usr/bin/env python3
"""
Mind Pilot Agent Bridge Client
High-speed thin client bridging Quickshell to the persistent Minimo Brain daemon (port 8088).
Eliminates code drift, cold startup lag, and VRAM memory churn.
"""

import sys
import os
import json
import asyncio
import argparse
import urllib.request
import urllib.error

def resolve_endpoints():
    """
    Dynamically resolve the Minimo Brain daemon endpoints.
    Checks environment variable MINIMO_HOST or ~/.config/minimo/endpoint.json.
    Defaults to 127.0.0.1:8088 on PC. On laptop, endpoint.json points to the Tailscale node IP.
    """
    host = os.environ.get("MINIMO_HOST")
    port = os.environ.get("MINIMO_PORT", "8088")

    cfg_file = os.path.expanduser("~/.config/minimo/endpoint.json")
    if not host and os.path.exists(cfg_file):
        try:
            with open(cfg_file, "r") as f:
                c = json.load(f)
                host = c.get("host")
                port = str(c.get("port", port))
        except Exception:
            pass

    if not host:
        host = "127.0.0.1"

    ws_url = f"ws://{host}:{port}/ws/chat"
    action_url = f"http://{host}:{port}/api/action"
    return ws_url, action_url, host

DAEMON_WS_URL, DAEMON_ACTION_URL, DAEMON_HOST = resolve_endpoints()

# Add minimo-brain to path for fallback execution
MINIMO_BRAIN_DIR = "/home/krishna/dotfiles/minimo-brain"
if MINIMO_BRAIN_DIR not in sys.path:
    sys.path.insert(0, MINIMO_BRAIN_DIR)

def emit(data: dict):
    print(json.dumps(data), flush=True)

async def run_query_daemon(query: str, history=None, mode="all"):
    """Connect to live minimo-brain daemon over WebSocket and stream JSON packets."""
    import websockets
    async with websockets.connect(DAEMON_WS_URL, close_timeout=0.2) as ws:
        payload = {
            "query": query,
            "mode": mode,
            "history": history,
            "session_id": "hyprland_desktop"
        }
        await ws.send(json.dumps(payload))
        async for msg in ws:
            print(msg, flush=True)
            try:
                parsed = json.loads(msg)
                if parsed.get("type") == "done":
                    await ws.close()
                    break
            except Exception:
                pass

async def run_query_fallback(query: str, history=None, mode="all"):
    """In-process execution if daemon is temporarily down or restarting on local machine."""
    if DAEMON_HOST not in ("127.0.0.1", "localhost"):
        emit({
            "type": "error",
            "text": f"Cannot reach Minimo Brain server at {DAEMON_HOST}. Ensure your PC is running and connected to Tailscale."
        })
        emit({"type": "done"})
        return

    from core.desktop_agent import execute_desktop_agent_stream
    async for packet in execute_desktop_agent_stream(query, context_history=history, mode=mode, session_id="hyprland_desktop"):
        emit(packet)

async def run_simulation_stream(query: str, delay: float = 5.0):
    """
    Simulate step-by-step cognitive reasoning stages with a customizable delay (default 5s)
    to visually inspect and appreciate every UI element in MindPilot.
    """
    clean_query = query.strip()
    if clean_query.lower().startswith(("simulate", "demo")):
        parts = clean_query.split(maxsplit=1)
        sub_query = parts[1] if len(parts) > 1 and parts[1].strip() else "add task buy sourdough bread and whole milk on way home because guests arriving tonight p2"
    else:
        sub_query = clean_query or "add task buy sourdough bread and whole milk on way home because guests arriving tonight p2"

    # Stage 0: Context & Query Analysis
    emit({
        "type": "stage",
        "stage": 0,
        "name": "Context & Query Analysis",
        "text": f"Analyzing discourse & anaphora: '{sub_query}'",
        "details": {"query": sub_query}
    })
    emit({
        "type": "phase",
        "phase": 1,
        "text": "⚡ Tracing context threads and semantic anchors...",
        "accent": "#89B4FA",
        "reaction": "curious"
    })
    await asyncio.sleep(delay)

    # Branch according to query topic
    sq_lower = sub_query.lower()
    if any(k in sq_lower for k in ("music", "song", "lofi", "play")):
        # MUSIC FLOW
        emit({
            "type": "stage",
            "stage": 1,
            "name": "Decomposing & Intent Routing",
            "text": "Routing to media controller & MPD local library...",
            "details": {"query": sub_query}
        })
        await asyncio.sleep(delay)
        emit({
            "type": "stage",
            "stage": 2,
            "name": "Intent Deduced",
            "intent": "play_music",
            "confidence": 0.98,
            "text": "Deduced Intent: Play Music (98% High Confidence)",
            "details": {"intent": "play_music", "model": "qwen2.5:1.5b-instruct"}
        })
        emit({
            "type": "action_card",
            "card_type": "music",
            "title": "Midnight City",
            "subtitle": "M83 · Hurry Up, We're Dreaming",
            "snippet": "Local MPD Library · Lossless FLAC · 24-bit/96kHz",
            "icon": "󰝚",
            "action_type": "mpris",
            "action_payload": "play-pause",
            "badge": "MPD PLAYING"
        })
        emit({
            "type": "token",
            "text": "🎵 Playing **Midnight City** by **M83** from your local MPD library."
        })
        emit({"type": "done", "reaction": "sway", "record_history": True})
        return

    elif any(k in sq_lower for k in ("email", "mail", "inbox")):
        # EMAIL SUMMARY FLOW
        emit({
            "type": "stage",
            "stage": 1,
            "name": "Decomposing & Intent Routing",
            "text": "Scanning maildir correspondence across threads...",
            "details": {"query": sub_query}
        })
        await asyncio.sleep(delay)
        emit({
            "type": "stage",
            "stage": 2,
            "name": "Intent Deduced",
            "intent": "email_summary",
            "confidence": 0.95,
            "text": "Deduced Intent: Email Summary (95% Confidence)",
            "details": {"intent": "email_summary", "model": "qwen2.5:1.5b-instruct"}
        })
        # Emit email cards (to be placed at bottom as sources/attachments)
        emit({
            "type": "action_card",
            "card_type": "email",
            "title": "General Secretary, Games and Sports",
            "subtitle": "1h ago · [students] Red Bull Wings Cup | Games Carnival",
            "snippet": "Registrations open for intra-campus esports and football cup...",
            "icon": "󰇮",
            "action_type": "open_terminal",
            "action_payload": "neomutt",
            "badge": "1H AGO"
        })
        emit({
            "type": "action_card",
            "card_type": "email",
            "title": "General Secretary, Media and Culture",
            "subtitle": "1h ago · Re: [students] Antaragni '24 Merchandise Collection",
            "snippet": "Final call for department hoodie and tee size submissions...",
            "icon": "󰇮",
            "action_type": "open_terminal",
            "action_payload": "neomutt",
            "badge": "1H AGO"
        })
        emit({
            "type": "action_card",
            "card_type": "email",
            "title": "ppathak",
            "subtitle": "6h ago · [Aero-ug] SPASI Seminar: 5:00 PM, Thursday",
            "snippet": "Seminar on Hypersonic Shock-Boundary Layer Interactions...",
            "icon": "󰇮",
            "action_type": "open_terminal",
            "action_payload": "neomutt",
            "badge": "6H AGO"
        })
        # Emit chat stream synthesis
        emit({
            "type": "token",
            "text": "### Executive Briefing\n*(Mailbox synced 12 minutes ago)*\n\n1. **Red Bull Wings Cup & Games Carnival** (1h ago)\n   Registrations have officially opened for intra-campus esports tournaments (Valorant, FIFA) and 5v5 futsal.\n\n2. **Antaragni '24 Merchandise Distribution** (1h ago)\n   Final round distribution starts this evening at SAC. Verify your order ID before collection.\n\n3. **Aero UG Seminar Notice** (6h ago)\n   Prof. P. Pathak announced the SPASI seminar on Hypersonic aerodynamics scheduled for Thursday at 5:00 PM in AE 01."
        })
        emit({"type": "done", "reaction": "reading", "record_history": True})
        return

    elif any(k in sq_lower for k in ("rayleigh", "flow", "rag", "thermo", "gas")):
        # RAG KNOWLEDGE FLOW
        emit({
            "type": "stage",
            "stage": 1,
            "name": "Decomposing & Intent Routing",
            "text": "Retrieving semantic vectors from aerodynamics & thermal textbooks...",
            "details": {"query": sub_query}
        })
        await asyncio.sleep(delay)
        emit({
            "type": "stage",
            "stage": 2,
            "name": "Intent Deduced",
            "intent": "rag_knowledge",
            "confidence": 0.94,
            "text": "Deduced Intent: Technical Knowledge RAG (94% Confidence)",
            "details": {"intent": "rag_knowledge", "model": "qwen2.5:1.5b-instruct"}
        })
        emit({
            "type": "action_card",
            "card_type": "book",
            "title": "Yunus A. Cengel - Thermodynamics, An Engineering Approach (2018).pdf",
            "subtitle": "Page 885 · Rayleigh Flow Relations",
            "snippet": "Rayleigh flow refers to 1D frictionless flow through a constant-area duct with heat transfer...",
            "icon": "󰂿",
            "action_type": "open_book",
            "action_payload": "thermo.pdf:::885",
            "badge": "PDF"
        })
        emit({
            "type": "action_card",
            "card_type": "note",
            "title": "20240112143254-basic_thermodynamics_of_gases.org",
            "subtitle": "Line 24 · Thermal choking limits",
            "snippet": "Adding heat to a subsonic flow accelerates it toward Mach 1.0 (thermal choking)...",
            "icon": "󰠮",
            "action_type": "open_note",
            "action_payload": "gases.org:::24",
            "badge": "NOTE"
        })
        emit({
            "type": "token",
            "text": "### Rayleigh Flow Dynamics\n\n**Rayleigh flow** is idealized one-dimensional, compressible flow through a constant-cross-sectional-area duct in the presence of **heat transfer** (heating or cooling), while neglecting the effects of wall friction.\n\nKey governing characteristics:\n- **Heating a Subsonic Flow ($M < 1$):** Increases the Mach number, decreases stagnation pressure ($P_0$), and moves the state toward the sonic point ($M = 1$).\n- **Heating a Supersonic Flow ($M > 1$):** Decelerates the flow toward $M = 1$, increasing pressure and reducing velocity.\n- **Thermal Choking:** Maximum heat addition occurs at $M = 1$. Attempting to add more heat causes inlet flow conditions to adjust (reducing mass flow rate)."
        })
        emit({"type": "done", "reaction": "nod", "record_history": True})
        return

    # DEFAULT: TODO CREATION
    # Stage 1: Decomposing & Intent Routing
    emit({
        "type": "stage",
        "stage": 1,
        "name": "Decomposing & Intent Routing",
        "text": "Routing through calibrated linear classifier...",
        "details": {"query": sub_query}
    })
    emit({
        "type": "phase",
        "phase": 1,
        "text": "⚡ Evaluating intent candidate logits across multi-task heads...",
        "accent": "#C084FC",
        "reaction": "writing"
    })
    await asyncio.sleep(delay)

    # Stage 2: Intent Deduced
    emit({
        "type": "stage",
        "stage": 2,
        "name": "Intent Deduced",
        "intent": "add_task",
        "confidence": 0.96,
        "text": "Deduced Intent: Add Task (96% High Confidence)",
        "details": {
            "intent": "add_task",
            "confidence": 0.96,
            "source": "classifier",
            "model": "qwen2.5:1.5b-instruct / linear_calibrated_head"
        }
    })
    emit({
        "type": "phase",
        "phase": 2,
        "text": "󰄬 Confidence exceeds 80% — preparing entity slot extraction...",
        "accent": "#00F5FF",
        "reaction": "curious"
    })
    await asyncio.sleep(delay)

    # Stage 3: Entity Deduction (Title, Priority, Due, Distilled Description)
    emit({
        "type": "stage",
        "stage": 3,
        "name": "Entity Deduction",
        "intent": "add_task",
        "confidence": 0.96,
        "text": "Deduced Task: 'Buy milk' [Priority P2 • Due tonight]",
        "details": {
            "title": "Buy milk",
            "priority": 2,
            "due": "tonight",
            "description": "Pick up whole milk on the way home.\n\n— Noted by Kafka",
            "model": "qwen2.5:1.5b-instruct / linear_calibrated_head"
        }
    })
    emit({
        "type": "status",
        "text": "Synthesized entities & rambling context successfully.",
        "reaction": "writing"
    })
    await asyncio.sleep(delay)

    # Stage 4: Action Execution & Synthesis Sheet
    emit({
        "type": "action_dispatched",
        "intent": "add_task",
        "action": "add_task",
        "status": "executed",
        "risk_policy": "undoable",
        "payload": {
            "title": "Buy milk",
            "due": "tonight",
            "priority": 2,
            "task_id": "simulated_task_demo",
            "offline_queued": False
        }
    })
    emit({
        "type": "layout",
        "format": "sheet",
        "title": "Tied to your strings now.",
        "subtitle": "Buy milk • Due tonight",
        "icon": "󰄬",
        "accent": "#10B981"
    })
    emit({
        "type": "action_card",
        "card_type": "todoist",
        "title": "Buy milk",
        "subtitle": "Priority P2 • Due tonight",
        "snippet": "Pick up whole milk on the way home.\n\n— Noted by Kafka",
        "icon": "󰄬",
        "action_type": "complete_task",
        "action_payload": "simulated_task_demo",
        "badge": "P2"
    })
    emit({
        "type": "token",
        "text": "Added **Buy milk** to Todoist (Priority P2 • Due tonight).\n\n*— Arranged by Kafka*"
    })
    emit({
        "type": "done",
        "reaction": "happyBounce",
        "record_history": True
    })

def execute_query(query: str, history=None, mode="all", simulate=False, delay=5.0):
    clean = (query or "").strip().lower()
    if simulate or clean.startswith(("simulate", "demo")):
        asyncio.run(run_simulation_stream(query, delay=delay))
        return

    try:
        asyncio.run(run_query_daemon(query, history, mode))
    except Exception:
        # Fallback to in-process execution
        asyncio.run(run_query_fallback(query, history, mode))

def execute_action(action_type: str, payload: str):
    """Trigger desktop card action via daemon REST API or local executor."""
    try:
        req_data = json.dumps({"action_type": action_type, "payload": payload}).encode("utf-8")
        req = urllib.request.Request(
            DAEMON_ACTION_URL,
            data=req_data,
            headers={"Content-Type": "application/json"}
        )
        with urllib.request.urlopen(req, timeout=3.0) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            print(json.dumps(data), flush=True)
            return data
    except Exception:
        from core.executor import execute_desktop_action
        res = execute_desktop_action(action_type, payload)
        print(json.dumps(res), flush=True)
        return res

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Mind Pilot Agent Bridge Client")
    parser.add_argument("--query", "-q", type=str, help="Execute natural language agent query")
    parser.add_argument("--mode", "-m", type=str, default="all",
                        choices=["all", "tasks", "notes", "books", "media"],
                        help="Filter search scope or force specific intent mode")
    parser.add_argument("--context", "-c", type=str, default=None,
                        help="JSON array of {q, a} conversation history")
    parser.add_argument("--exec", "-e", nargs=2, metavar=("TYPE", "PAYLOAD"),
                        help="Execute an action card directly")
    parser.add_argument("--search", "-s", type=str, help="Direct RAG search")
    parser.add_argument("--simulate", action="store_true",
                        help="Simulate stages slowly for visual UI testing")
    parser.add_argument("--delay", type=float, default=5.0,
                        help="Delay in seconds per simulated stage (default: 5.0)")
    args = parser.parse_args()

    ctx = None
    if args.context:
        try:
            ctx = json.loads(args.context)
        except Exception:
            ctx = None

    if args.exec:
        execute_action(args.exec[0], args.exec[1])
    elif args.search:
        from core.rag import search_library_rag
        results = search_library_rag(args.search, limit=5)
        print(f"\nResults for '{args.search}':")
        for i, r in enumerate(results, 1):
            print(f"{i}. [{r.get('category', 'doc').upper()}] {r.get('filename')} (p. {r.get('page')})")
            print(f"   {r.get('snippet', '')[:160]}\n")
    elif args.query or args.simulate:
        q = args.query or "simulate"
        execute_query(q, history=ctx, mode=args.mode, simulate=args.simulate, delay=args.delay)
