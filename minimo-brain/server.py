"""
Minimo Brain Suite - Standalone Headless Brain & Cross-Device API Server
Exposed over Tailscale (100.77.57.23:8088) and Localhost (0.0.0.0:8088)
"""

import os
import sys
import json
import asyncio
import subprocess
from typing import Dict, Any, Optional, List
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, FileResponse, StreamingResponse
from pydantic import BaseModel

# Add local path so core modules import cleanly
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from core.config import (
    HOST, PORT, get_tailscale_ip, get_router_model, get_synthesis_model,
    OLLAMA_URL, SYNTHESIS_MODEL, ROUTER_MODEL
)
from core.router import route_intent
from core.decomposer import decompose_query
from core.tasks import get_tasks, add_task, toggle_task, delete_task
from core.media import (
    search_local_movies, search_mpd_library, play_mpd_song,
    play_youtube_audio, stop_all_audio, mpris_control
)
from core.rag import search_library_rag, search_mindspace
from core.synthesis import stream_synthesis_async, stream_synthesis_sync, stream_chat_async, stream_email_synthesis_async, clean_math_notation
from core.system_context import (
    get_full_system_context, format_system_context_prompt,
    get_daily_horizon_data, get_active_window_info
)
from core.agent import run_agent_stream, TOOLS_REGISTRY
from core.desktop_agent import execute_desktop_agent_stream
from core.executor import execute_desktop_action
from core.pdf_context import get_active_or_hovered_pdf
from core.unified_indexer import start_auto_indexer_background, scan_and_index_changes, index_file_incremental

# Check if current machine is marked as client-only in ~/.config/minimo/endpoint.json
CFG_FILE = os.path.expanduser("~/.config/minimo/endpoint.json")
if os.path.exists(CFG_FILE):
    try:
        with open(CFG_FILE, "r") as f:
            c = json.load(f)
            if c.get("role") == "client":
                print("[Minimo Brain] Machine is configured as 'client'. Server startup canceled.", flush=True)
                sys.exit(0)
    except Exception:
        pass

app = FastAPI(title="Minimo Brain Suite", version="2.0.0")

@app.on_event("startup")
async def on_startup():
    start_auto_indexer_background(interval_seconds=180.0)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Data Models ──
class TaskAddRequest(BaseModel):
    title: str
    due: Optional[str] = None
    priority: Optional[int] = None
    description: Optional[str] = None

class TaskActionRequest(BaseModel):
    task_id: str

class MediaPlayRequest(BaseModel):
    filepath: str

class ActionExecRequest(BaseModel):
    action_type: str
    payload: str

class MusicPlayRequest(BaseModel):
    query: str

class MPRISRequest(BaseModel):
    action: str

class TTSRequest(BaseModel):
    text: str

class QueryRequest(BaseModel):
    query: str
    mode: Optional[str] = "all"
    history: Optional[List[Dict[str, str]]] = None

class SynthesizeRequest(BaseModel):
    query: str
    context: Optional[str] = None
    history: Optional[List[Dict[str, str]]] = None
    rag: Optional[bool] = True
    num_predict: Optional[int] = 520

class AgentRunRequest(BaseModel):
    query: str
    history: Optional[List[Dict[str, str]]] = None
    mode: Optional[str] = "all"
    max_steps: Optional[int] = 3

# ── REST API Endpoints ──

@app.get("/api/status")
async def get_status():
    ts_ip = get_tailscale_ip()
    return {
        "status": "online",
        "brain": "Minimo Brain Suite v2.0",
        "tailscale_ip": ts_ip,
        "port": PORT,
        "access_url": f"http://{ts_ip}:{PORT}",
        "router_model": get_router_model(),
        "synthesis_model": get_synthesis_model(),
        "ollama_url": OLLAMA_URL
    }

@app.get("/api/active_pdf")
async def api_get_active_pdf():
    pdf = await asyncio.to_thread(get_active_or_hovered_pdf)
    return {"active_pdf": pdf}

@app.api_route("/api/rag/sync", methods=["GET", "POST"])
async def api_sync_rag(force: bool = False):
    res = await asyncio.to_thread(scan_and_index_changes, force)
    return {"status": "ok", "stats": res}

@app.get("/api/tasks")
async def api_get_tasks():
    tasks = get_tasks()
    return {"status": "ok", "tasks": tasks, "count": len(tasks)}

@app.post("/api/tasks/add")
async def api_add_task(req: TaskAddRequest):
    created = add_task(req.title, req.due, req.priority, req.description)
    if created:
        return {"status": "ok", "task": created}
    raise HTTPException(status_code=500, detail="Failed to add task")

@app.post("/api/tasks/toggle")
async def api_toggle_task(req: TaskActionRequest):
    success = toggle_task(req.task_id)
    return {"status": "ok" if success else "error"}

@app.post("/api/tasks/delete")
async def api_delete_task(req: TaskActionRequest):
    success = delete_task(req.task_id)
    return {"status": "ok" if success else "error"}

@app.get("/api/media/search")
async def api_search_media(q: str = Query(..., min_length=1), limit: int = 5):
    results = search_local_movies(q, limit)
    return {"status": "ok", "query": q, "results": results}

@app.post("/api/media/play")
async def api_play_media(req: MediaPlayRequest, request: Request):
    client_ip = request.client.host if request.client else "unknown"
    if client_ip not in ("127.0.0.1", "::1", "localhost"):
        return {"status": "ignored", "message": "Host playback is disabled for remote devices."}
    if not os.path.isfile(req.filepath):
        raise HTTPException(status_code=404, detail="Media file not found")
    subprocess.Popen(["mpv", "--fs", req.filepath], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    subprocess.Popen(["notify-send", "-a", "Minimo Brain", "Now Playing", os.path.basename(req.filepath)])
    return {"status": "ok", "playing": req.filepath}

@app.get("/api/rag/search")
async def api_search_rag(q: str = Query(..., min_length=1), limit: int = 5, cat: Optional[str] = None):
    results = search_library_rag(q, limit, cat)
    return {"status": "ok", "query": q, "results": results}

@app.get("/api/mindspace/search")
async def api_search_mindspace(q: str = Query(..., min_length=1), limit: int = 5):
    results = search_mindspace(q, limit)
    return {"status": "ok", "query": q, "results": results}

@app.post("/api/action")
async def api_execute_action(req: ActionExecRequest, request: Request):
    client_ip = request.client.host if request.client else "unknown"
    if client_ip not in ("127.0.0.1", "::1", "localhost"):
        return {"status": "ignored", "message": "Host application launching is disabled for remote devices."}
    res = await asyncio.to_thread(execute_desktop_action, req.action_type, req.payload)
    return res

@app.get("/api/briefing")
async def api_get_briefing():
    """Daily Horizon briefing endpoint for cross-device dashboards."""
    try:
        data = get_daily_horizon_data()
        return {"status": "ok", "briefing": data}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.get("/api/activewindow")
async def api_get_active_window():
    """Real-time active window focus on the primary Hyprland desktop."""
    try:
        win = get_active_window_info()
        return {"status": "ok", "window": win}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.get("/api/emails/recent")
async def api_get_emails_recent(
    hours: Optional[int] = Query(None, description="Filter to emails in the last N hours"),
    limit: int = Query(5, ge=1, le=25, description="Number of recent emails to return")
):
    """Scan local Maildir for recent emails with snippets and sender info."""
    try:
        from core.emails import fetch_recent_emails
        duration_sec = (hours * 3600) if hours else None
        emails = await asyncio.to_thread(fetch_recent_emails, duration_sec, None, limit)
        return {"status": "ok", "count": len(emails), "emails": emails}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.get("/api/emails/summary")
async def api_get_emails_summary(
    hours: Optional[int] = Query(None, description="Summarize emails in the last N hours"),
    limit: int = Query(5, ge=1, le=20, description="Max emails to include in summary")
):
    """Synthesize an executive summary of recent Maildir emails."""
    try:
        from core.emails import fetch_recent_emails, build_email_digest_prompt
        duration_sec = (hours * 3600) if hours else None
        desc = f"emails from the last {hours} hours" if hours else f"last {limit} emails"
        emails = await asyncio.to_thread(fetch_recent_emails, duration_sec, None, limit)
        if not emails:
            return {"status": "ok", "summary": f"Nothing in the inbox for {desc}.", "count": 0, "emails": []}
        
        prompt = build_email_digest_prompt(emails, desc)
        full_text = []
        async for item in stream_email_synthesis_async(prompt, num_predict=1200):
            if item.get("type") == "token":
                full_text.append(item.get("text", ""))
        
        return {
            "status": "ok",
            "summary": clean_math_notation("".join(full_text)),
            "count": len(emails),
            "emails": emails
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.post("/api/music/play")
async def api_music_play(req: MusicPlayRequest):
    """Play song via local MPD or stream audio via YouTube MPV fallback with mood/genre awareness."""
    try:
        from core.media import resolve_music_intent, play_mpd_playlist, optimize_youtube_query
        info = resolve_music_intent(req.query)
        m_type = info.get("type", "track")
        tracks = info.get("tracks", [])

        if m_type in ("mood_playlist", "artist_playlist") and tracks:
            play_mpd_playlist(tracks, shuffle=True)
            return {"status": "ok", "source": "mpd_playlist", "type": m_type, "count": len(tracks), "tracks": tracks[:5]}
        elif tracks:
            play_mpd_song(tracks[0])
            return {"status": "ok", "source": "mpd", "track": tracks[0]}
        else:
            opt = optimize_youtube_query(req.query)
            play_youtube_audio(opt)
            return {"status": "ok", "source": "youtube", "track": opt}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.post("/api/music/stop")
async def api_music_stop():
    """Halt all music, MPD playback, and background YouTube MPV streams."""
    try:
        stop_all_audio()
        return {"status": "ok", "message": "All audio and background streams stopped."}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.post("/api/music/mpris")
async def api_music_mpris(req: MPRISRequest):
    """Control desktop audio playback (play-pause, next, prev, status)."""
    try:
        res = mpris_control(req.action)
        return {"status": "ok", "result": res}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.post("/api/tts/speak")
async def api_tts_speak(req: TTSRequest):
    """Read text aloud using local neural Piper TTS."""
    try:
        subprocess.Popen(["/home/krishna/dotfiles/scripts/minimo_tts.py", "--speak", req.text], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        return {"status": "ok"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.post("/api/tts/stop")
async def api_tts_stop():
    """Halt ongoing neural TTS audio playback."""
    try:
        subprocess.Popen(["/home/krishna/dotfiles/scripts/minimo_tts.py", "--stop"], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        return {"status": "ok"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

# ── Dedicated Direct Synthesis APIs (for external desktop bots & apps) ──

@app.post("/api/synthesize")
async def api_synthesize(req: SynthesizeRequest):
    """
    Direct synthesis endpoint for other desktop bots / systems.
    Bypasses UI routing and delivers full synthesized text directly.
    """
    q = req.query.strip()
    if not q:
        raise HTTPException(status_code=400, detail="Query cannot be empty")
    
    rag_hits = await asyncio.to_thread(search_library_rag, q, 4) if req.rag else []
    full_text = []
    cards = []
    async for item in stream_synthesis_async(q, rag_hits, req.history, req.num_predict or 520):
        if item.get("type") == "token":
            full_text.append(item.get("text", ""))
        elif item.get("type") == "action_card":
            cards.append(item)
            
    return {
        "status": "ok",
        "response": clean_math_notation("".join(full_text)),
        "model": get_synthesis_model(),
        "sources": cards
    }

@app.api_route("/api/synthesize/stream", methods=["GET", "POST"])
async def api_synthesize_stream(
    req: Optional[SynthesizeRequest] = None,
    q: Optional[str] = Query(None)
):
    """
    Server-Sent Events (SSE) streaming synthesis endpoint.
    Streams token-by-token chunks to any external desktop bot, script, or browser.
    """
    query_text = (req.query if req else q) or ""
    query_text = query_text.strip()
    if not query_text:
        raise HTTPException(status_code=400, detail="Query text is required")
        
    history = req.history if req else None
    use_rag = req.rag if (req and req.rag is not None) else True
    num_predict = req.num_predict if req else 520

    async def sse_generator():
        rag_hits = await asyncio.to_thread(search_library_rag, query_text, 4) if use_rag else []
        async for item in stream_synthesis_async(query_text, rag_hits, history, num_predict):
            yield f"data: {json.dumps(item)}\n\n"

    return StreamingResponse(sse_generator(), media_type="text/event-stream")

@app.websocket("/ws/synthesize")
async def websocket_synthesize(websocket: WebSocket):
    """
    Low-latency WebSocket streaming synthesis endpoint.
    Accepts: {"query": "...", "context": "...", "history": [...], "rag": bool}
    Streams pure synthesis packets directly to any desktop bot client.
    """
    await websocket.accept()
    try:
        while True:
            raw = await websocket.receive_text()
            try:
                data = json.loads(raw)
            except Exception:
                await websocket.send_json({"type": "token", "text": "*(Invalid JSON)*"})
                await websocket.send_json({"type": "done"})
                continue

            query = (data.get("query") or "").strip()
            if not query:
                continue

            history = data.get("history")
            use_rag = data.get("rag", True)
            num_predict = data.get("num_predict", 520)

            rag_hits = await asyncio.to_thread(search_library_rag, query, 4) if use_rag else []
            async for item in stream_synthesis_async(query, rag_hits, history, num_predict):
                await websocket.send_json(item)
    except WebSocketDisconnect:
        pass
    except Exception as e:
        try:
            await websocket.send_json({"type": "token", "text": f"\n*(Synthesis error: {e})*"})
            await websocket.send_json({"type": "done"})
        except Exception:
            pass

# ── Deep System Context & Agentic Pipeline Endpoints ──

@app.get("/api/system/context")
async def api_get_system_context():
    """Real-time situational telemetry (Hyprland window, CPU/RAM, media, ambient)."""
    return {
        "status": "ok",
        "context": get_full_system_context()
    }

@app.get("/api/agent/tools")
async def api_get_agent_tools():
    """List of available tools for cognitive agentic workflows."""
    return {
        "status": "ok",
        "tools": TOOLS_REGISTRY
    }

@app.post("/api/agent/run")
async def api_agent_run(req: AgentRunRequest):
    """
    Execute full multi-step cognitive agent query with tool calling and system context.
    Returns complete response, executed tools, and action cards.
    """
    q = req.query.strip()
    if not q:
        raise HTTPException(status_code=400, detail="Query cannot be empty")
    
    tokens = []
    actions = []
    cards = []
    
    async for item in run_agent_stream(q, req.history, req.mode or "all", req.max_steps or 3):
        t = item.get("type")
        if t == "token":
            tokens.append(item.get("text", ""))
        elif t == "agent_action":
            actions.append(item)
        elif t == "action_card":
            cards.append(item)
            
    return {
        "status": "ok",
        "response": clean_math_notation("".join(tokens)),
        "actions": actions,
        "cards": cards,
        "model": get_synthesis_model()
    }

@app.api_route("/api/agent/stream", methods=["GET", "POST"])
async def api_agent_stream(
    req: Optional[AgentRunRequest] = None,
    q: Optional[str] = Query(None)
):
    """
    SSE stream for the cognitive agent loop. Emits thoughts, status, tool calls, and tokens.
    """
    query_text = (req.query if req else q) or ""
    query_text = query_text.strip()
    if not query_text:
        raise HTTPException(status_code=400, detail="Query text is required")
        
    history = req.history if req else None
    mode = req.mode if req else "all"
    max_steps = req.max_steps if req else 3

    async def sse_gen():
        async for item in run_agent_stream(query_text, history, mode, max_steps):
            yield f"data: {json.dumps(item)}\n\n"

    return StreamingResponse(sse_gen(), media_type="text/event-stream")

@app.websocket("/ws/agent")
async def websocket_agent(websocket: WebSocket):
    """
    Full-duplex WebSocket for the cognitive agentic pipeline.
    Streams real-time thoughts, tool calls, tool results, tokens, and action cards.
    """
    await websocket.accept()
    try:
        while True:
            raw = await websocket.receive_text()
            try:
                data = json.loads(raw)
            except Exception:
                await websocket.send_json({"type": "token", "text": "*(Invalid JSON request)*"})
                await websocket.send_json({"type": "done", "reaction": "neutral"})
                continue

            query = (data.get("query") or "").strip()
            if not query:
                continue

            history = data.get("history")
            mode = data.get("mode", "all")
            max_steps = data.get("max_steps", 3)

            async for item in run_agent_stream(query, history, mode, max_steps):
                await websocket.send_json(item)
    except WebSocketDisconnect:
        pass
    except Exception as e:
        try:
            await websocket.send_json({"type": "token", "text": f"\n*(Agent error: {e})*"})
            await websocket.send_json({"type": "done", "reaction": "neutral"})
        except Exception:
            pass

# ── WebSocket Real-Time Chat & Streaming ──

@app.websocket("/ws/chat")
async def websocket_chat(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            raw = await websocket.receive_text()
            try:
                data = json.loads(raw)
            except Exception:
                await websocket.send_json({"type": "token", "text": "*(Invalid JSON request)*"})
                await websocket.send_json({"type": "done", "reaction": "neutral"})
                continue

            query = (data.get("query") or "").strip()
            mode = data.get("mode") or "all"
            history = data.get("history")
            session_id = data.get("session_id") or "hyprland_desktop"

            if not query:
                continue

            async for item in execute_desktop_agent_stream(query, history, mode, session_id):
                await websocket.send_json(item)

    except WebSocketDisconnect:
        pass
    except Exception as e:
        try:
            await websocket.send_json({"type": "token", "text": f"\n\n*(Error: {e})*"})
            await websocket.send_json({"type": "done", "reaction": "neutral"})
        except Exception:
            pass

# ── Static Web App Serving ──
web_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "web")
if os.path.isdir(web_dir):
    app.mount("/static", StaticFiles(directory=web_dir), name="static")

    @app.api_route("/", methods=["GET", "HEAD"])
    async def serve_index():
        index_file = os.path.join(web_dir, "index.html")
        if os.path.isfile(index_file):
            return FileResponse(index_file)
        return HTMLResponse("<h1>Minimo Brain Suite is running</h1>")

if __name__ == "__main__":
    import uvicorn
    print(f"🚀 Starting Minimo Brain Suite on {HOST}:{PORT}")
    print(f"🌐 Tailscale IP: {get_tailscale_ip()}")
    print(f"📡 Access URL: http://{get_tailscale_ip()}:{PORT}")
    uvicorn.run(app, host=HOST, port=PORT, log_level="info")
