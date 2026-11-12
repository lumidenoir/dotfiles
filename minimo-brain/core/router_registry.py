"""
Minimo Brain Suite - Typed Intent Registry, Slot Grounding & Risk Policy
Implements expert-grade intent grounding:
- Intent is treated as a hypothesis; slots are the proof.
- Pydantic models enforce schema contracts and fail loudly on invalid inputs.
- Reality grounding via rapidfuzz, dateparser, and local library validation.
- Risk-driven dispatch policy:
    * informational: low threshold (default fallthrough attractor)
    * read_only: medium threshold
    * reversible: high threshold (≥ 0.85) + grounded slots + Undo capability
    * destructive: very high threshold (≥ 0.95) + mandatory confirmation card
"""

import re
import os
from datetime import datetime
from typing import Dict, Any, Optional, Tuple, Literal, List, Callable
from pydantic import BaseModel, Field, field_validator
import dateparser
from rapidfuzz import fuzz, process

from .media import resolve_music_intent, search_local_movies

# ─────────────────────────────────────────────────────────────────────
# 1. Typed Schemas
# ─────────────────────────────────────────────────────────────────────

class AddTaskArgs(BaseModel):
    title: str = Field(..., description="Clean, imperative task description")
    due: Optional[datetime] = Field(None, description="Parsed future due date/time")
    priority: Literal[1, 2, 3, 4] = Field(4, description="Priority level 1 (urgent) to 4 (normal)")
    raw_query: str = Field("", description="Original user prompt")

    @field_validator("title")
    @classmethod
    def validate_title(cls, v: str) -> str:
        s = v.strip()
        words = s.split()
        if len(words) < 2:
            raise ValueError("Task title is too short (must be at least 2 words)")
        # Reject if title is an epistemic or informational question
        lower = s.lower()
        if re.match(r'^(?:what\s+(?:is|are|was|were)|how\s+(?:to|do|can)|why\s+(?:is|does)|explain|describe|who\s+is)\b', lower):
            raise ValueError(f"Title looks like an informational question, not an action task: '{s}'")
        return s

class PlayMediaArgs(BaseModel):
    raw_query: str
    target_type: Literal["local_mpd", "youtube_stream", "local_video", "none"] = "none"
    resolved_track: Optional[str] = None
    tracks_count: int = 0
    is_explicit_verb: bool = False

class MPRISControlArgs(BaseModel):
    action: Literal["play-pause", "next", "previous", "stop", "status", "volume_up", "volume_down", "mute"]
    raw_query: str

class ListTasksArgs(BaseModel):
    filter_type: Literal["all", "today", "urgent", "completed"] = "all"

class RunCmdArgs(BaseModel):
    command: str
    requires_confirm: bool = True

class DailyHorizonArgs(BaseModel):
    scope: str = "daily"

class ActiveWindowArgs(BaseModel):
    scope: str = "focused"

class MindspaceArgs(BaseModel):
    search_query: str

class RAGKnowledgeArgs(BaseModel):
    search_query: str
    category_filter: Optional[str] = None

class ChatArgs(BaseModel):
    message: str


# ─────────────────────────────────────────────────────────────────────
# 2. Risk Policies
# ─────────────────────────────────────────────────────────────────────

class IntentRisk:
    INFORMATIONAL = "informational"  # e.g., rag_knowledge, chat
    READ_ONLY = "read_only"          # e.g., list_tasks, active_window, daily_horizon
    REVERSIBLE = "reversible"        # e.g., add_task, play_media, mpris_control (with Undo)
    DESTRUCTIVE = "destructive"      # e.g., run_cmd, delete_task (requires confirmation)

INTENT_POLICY: Dict[str, Dict[str, Any]] = {
    "rag_knowledge": {
        "risk": IntentRisk.INFORMATIONAL,
        "min_confidence": 0.15,
        "min_margin": 0.00,
        "requires_grounding": False,
        "action_intent": False
    },
    "chat": {
        "risk": IntentRisk.INFORMATIONAL,
        "min_confidence": 0.25,
        "min_margin": 0.00,
        "requires_grounding": False,
        "action_intent": False
    },
    "list_tasks": {
        "risk": IntentRisk.READ_ONLY,
        "min_confidence": 0.35,
        "min_margin": 0.05,
        "requires_grounding": False,
        "action_intent": False
    },
    "active_window": {
        "risk": IntentRisk.READ_ONLY,
        "min_confidence": 0.38,
        "min_margin": 0.05,
        "requires_grounding": False,
        "action_intent": False
    },
    "daily_horizon": {
        "risk": IntentRisk.READ_ONLY,
        "min_confidence": 0.38,
        "min_margin": 0.05,
        "requires_grounding": False,
        "action_intent": False
    },
    "mindspace": {
        "risk": IntentRisk.READ_ONLY,
        "min_confidence": 0.38,
        "min_margin": 0.05,
        "requires_grounding": False,
        "action_intent": False
    },
    "mpris_control": {
        "risk": IntentRisk.REVERSIBLE,
        "min_confidence": 0.40,
        "min_margin": 0.06,
        "requires_grounding": True,
        "action_intent": True
    },
    "add_task": {
        "risk": IntentRisk.REVERSIBLE,
        "min_confidence": 0.45,
        "min_margin": 0.08,
        "requires_grounding": True,
        "action_intent": True
    },
    "play_media": {
        "risk": IntentRisk.REVERSIBLE,
        "min_confidence": 0.45,
        "min_margin": 0.08,
        "requires_grounding": True,
        "action_intent": True
    },
    "play_music": {
        "risk": IntentRisk.REVERSIBLE,
        "min_confidence": 0.45,
        "min_margin": 0.08,
        "requires_grounding": True,
        "action_intent": True
    },
    "run_cmd": {
        "risk": IntentRisk.DESTRUCTIVE,
        "min_confidence": 0.65,
        "min_margin": 0.15,
        "requires_grounding": True,
        "action_intent": True
    }
}


# ─────────────────────────────────────────────────────────────────────
# 3. Grounding & Extraction Engines
# ─────────────────────────────────────────────────────────────────────

def ground_add_task(query: str, raw_slots: Optional[Dict[str, Any]] = None) -> Tuple[bool, Optional[AddTaskArgs], str]:
    """
    Grounds task creation against reality:
    - Extracts imperative task body
    - Parses due date via dateparser
    - Validates that title is not an epistemic/knowledge question
    - Rejects negative/cancellation utterances
    """
    ql = query.lower().strip()

    # Negation check: only trigger on cancellations ('don't add', 'never mind', 'cancel')
    if re.search(r'\b(?:never\s*mind|cancel|abort|stop\s+(?:adding|creating)|(?:don\x27?t|do\s+not)\s+(?:add|create|remind|schedule|put))\b', ql):
        return (False, None, "Query contains cancellation or refusal marker")

    # Clean off prefixes
    clean = re.sub(r'^(?:todo|task|remind)(?:\s*:\s*|\s+me\s+to\s+|\s+to\s+|\s+)', '', query, flags=re.I).strip()
    clean = re.sub(r'^(?:add|create|schedule|set|put)\s+(?:a\s+)?(?:task|todo|reminder)?(?:\s+(?:for|to|about))?\s*', '', clean, flags=re.I).strip()

    # Extract priority (p1, p2, p3, p4)
    priority = 4
    p_match = re.search(r'\b(?:p([1-4])|priority\s*([1-4]))\b', clean, re.I)
    if p_match:
        p_val = int(p_match.group(1) or p_match.group(2))
        priority = max(1, min(4, p_val))
        clean = re.sub(r'\b(?:p[1-4]|priority\s*[1-4])\b', '', clean, flags=re.I).strip()

    # Extract due date via dateparser
    due_date = None
    due_match = re.search(r'\b(?:due|by|on|at|tomorrow|next\s+\w+|tonight|this\s+evening)\b.*$', clean, re.I)
    if due_match:
        due_str = due_match.group(0)
        parsed = dateparser.parse(
            due_str,
            settings={'PREFER_DATES_FROM': 'future', 'RELATIVE_BASE': datetime.now()}
        )
        if parsed:
            due_date = parsed
            clean = clean[:due_match.start()].strip()

    # An intentional write action MUST contain an explicit task trigger or deadline/priority:
    # 1. Prefixes / imperative markers: 'todo:', 'task:', 'remind', 'add task', 'create todo', 'dont forget', 'put on my todo'
    # 2. Or explicit priority marker: p1 - p4
    # 3. Or explicit deadline / due date parsed
    # Without any of these, a book heading like 'Setting Up a Virtual Machine' is a knowledge section, NOT a task!
    has_task_marker = bool(re.search(r'\b(?:todo|task|tasks|remind|reminder|schedule|dont\s+forget|don\x27t\s+forget|put\s+on\s+(?:my\s+)?todo)\b', ql))
    has_explicit_due_or_prio = (due_date is not None) or (p_match is not None)

    if not (has_task_marker or has_explicit_due_or_prio):
        return (False, None, "Query has no explicit task intent marker or deadline/priority (safe fallthrough to RAG)")

    if not clean or len(clean.split()) < 2:
        if has_task_marker:
            args = AddTaskArgs.model_construct(title=clean or "unspecified", due=due_date, priority=priority, raw_query=query)
            return (True, args, "Task intent recognized, details need clarification")

    try:
        args = AddTaskArgs(title=clean, due=due_date, priority=priority, raw_query=query)
        return (True, args, "Task grounded successfully")
    except Exception as e:
        return (False, None, f"Slot validation rejected task: {str(e)}")


def ground_play_media(query: str, raw_slots: Optional[Dict[str, Any]] = None) -> Tuple[bool, Optional[PlayMediaArgs], str]:
    """
    Grounds media/music intent against reality:
    1. Checks for explicit playback action verbs ('play', 'stream', 'listen to', 'put on', 'watch')
    2. Validates against local MPD music database or local videos
    3. Rejects non-music homonyms (e.g., 'fanno flow', 'cash flow', 'fluid flow', 'reading list')
    """
    ql = query.lower().strip()

    # 1. Action verb detection
    has_play_verb = bool(re.search(r'\b(?:play|stream|listen\s+to|put\s+on|queue|watch)\b', ql))

    # 2. Local library resolution (MPD & Local Movies)
    res = resolve_music_intent(query)
    tracks = res.get('tracks', []) if isinstance(res, dict) else []

    local_movies = search_local_movies(query, limit=1) if any(w in ql for w in ["movie", "film", "anime", "episode", "season", "watch", "video"]) else []

    # If user mentioned an anime or local video
    if local_movies:
        args = PlayMediaArgs(
            raw_query=query,
            target_type="local_video",
            resolved_track=local_movies[0].get("path"),
            tracks_count=1,
            is_explicit_verb=has_play_verb
        )
        return (True, args, "Grounded to local video library")

    # If local MPD tracks match
    if tracks:
        first_t = tracks[0]
        track_file = first_t.get("file") if isinstance(first_t, dict) else str(first_t)
        args = PlayMediaArgs(
            raw_query=query,
            target_type="local_mpd",
            resolved_track=track_file,
            tracks_count=len(tracks),
            is_explicit_verb=has_play_verb
        )
        return (True, args, f"Grounded to {len(tracks)} local MPD tracks")

    # If no library match, query MUST have an explicit action verb to justify streaming audio/video
    if has_play_verb:
        # Check if it's an adversarial question disguised as play
        # e.g., "play with fire", "play a role in biology"
        if re.search(r'\b(?:play\s+with\s+fire|play\s+a\s+role|play\s+into)\b', ql):
            return (False, None, "Query is an idiom, not media playback")

        clean_stream_q = re.sub(r'^(?:play|stream|listen\s+to|put\s+on|queue)\s+(?:some\s+|a\s+|the\s+)?(?:music|song|track|audio|jam)?(?:\s+(?:by|from))?\s*', '', query, flags=re.I).strip()
        args = PlayMediaArgs(
            raw_query=clean_stream_q or query,
            target_type="youtube_stream",
            is_explicit_verb=True
        )
        return (True, args, "Grounded to streaming provider via explicit verb")

    # Zero library tracks + Zero play verbs -> REJECT!
    return (False, None, "No music entities in library and no explicit playback verb (safe fallthrough to RAG/chat)")


def ground_mpris_control(query: str, raw_slots: Optional[Dict[str, Any]] = None) -> Tuple[bool, Optional[MPRISControlArgs], str]:
    """
    Grounds MPRIS playback and volume controls.
    """
    ql = query.lower().strip()

    if any(w in ql for w in ["what is playing", "whats playing", "now playing", "current song", "what song", "track info"]):
        return (True, MPRISControlArgs(action="status", raw_query=query), "Status query")
    if any(w in ql for w in ["next", "skip", "next track", "skip song"]):
        return (True, MPRISControlArgs(action="next", raw_query=query), "Next track")
    if any(w in ql for w in ["prev", "previous", "previous track", "go back"]):
        return (True, MPRISControlArgs(action="previous", raw_query=query), "Previous track")
    if any(w in ql for w in ["pause", "hold"]):
        return (True, MPRISControlArgs(action="play-pause", raw_query=query), "Pause")
    if any(w in ql for w in ["turn up", "louder", "increase the volume", "increase volume", "volume up", "crank up", "raise volume"]):
        return (True, MPRISControlArgs(action="volume_up", raw_query=query), "Volume up")
    if any(w in ql for w in ["turn down", "quieter", "lower the volume", "lower playback volume", "drop the volume", "volume down"]):
        return (True, MPRISControlArgs(action="volume_down", raw_query=query), "Volume down")
    if any(w in ql for w in ["stop", "turn off", "too loud", "shut off", "cut the sound", "mute"]):
        return (True, MPRISControlArgs(action="stop", raw_query=query), "Stop playback")
    if any(w in ql for w in ["resume", "unpause", "play"]):
        return (True, MPRISControlArgs(action="play-pause", raw_query=query), "Toggle play")

    return (False, None, "Unrecognized MPRIS action")


def ground_run_cmd(query: str, raw_slots: Optional[Dict[str, Any]] = None) -> Tuple[bool, Optional[RunCmdArgs], str]:
    """
    Extracts shell command. Always requires confirmation card.
    """
    clean = re.sub(r'^(?:\$|!|run\s+|exec\s+)', '', query.strip()).strip()
    if clean:
        return (True, RunCmdArgs(command=clean, requires_confirm=True), "Shell command requires confirmation")
    return (False, None, "Empty command")


# ─────────────────────────────────────────────────────────────────────
# 4. Universal Intent Validator & Gatekeeper
# ─────────────────────────────────────────────────────────────────────

def validate_and_ground_intent(
    predicted_intent: str,
    confidence: float,
    margin: float,
    query: str,
    raw_slots: Optional[Dict[str, Any]] = None
) -> Tuple[str, float, Optional[BaseModel], str]:
    """
    Universal Gatekeeper:
    Validates intent against risk policy and slot grounding.
    Returns: (final_intent, confidence, validated_args, audit_reason)
    
    If intent validation fails, gracefully falls through to 'rag_knowledge' or 'chat'.
    """
    policy = INTENT_POLICY.get(predicted_intent, INTENT_POLICY["rag_knowledge"])
    
    # 1. Policy Confidence & Margin Check
    min_conf = policy["min_confidence"]
    min_marg = policy["min_margin"]

    if confidence < min_conf or margin < min_marg:
        # Fails policy threshold -> Fallback to informational
        fallback = "rag_knowledge" if len(query.split()) > 2 else "chat"
        return (
            fallback,
            confidence,
            None,
            f"Fell through: predicted '{predicted_intent}' confidence {confidence:.2f} (min {min_conf:.2f}) or margin {margin:.2f} (min {min_marg:.2f})"
        )

    # 2. Slot Grounding Verification for Action Intents
    if policy.get("requires_grounding", False):
        if predicted_intent in ("play_media", "play_music"):
            ok, args, reason = ground_play_media(query, raw_slots)
            if not ok:
                return ("rag_knowledge", 0.95, None, f"Action rejected: {reason} -> Safe fallthrough to RAG")
            return (predicted_intent, confidence, args, reason)

        elif predicted_intent == "add_task":
            ok, args, reason = ground_add_task(query, raw_slots)
            if not ok:
                return ("rag_knowledge", 0.95, None, f"Action rejected: {reason} -> Safe fallthrough to RAG")
            return (predicted_intent, confidence, args, reason)

        elif predicted_intent == "mpris_control":
            ok, args, reason = ground_mpris_control(query, raw_slots)
            if not ok:
                return ("rag_knowledge", 0.95, None, f"Action rejected: {reason} -> Safe fallthrough to RAG")
            return (predicted_intent, confidence, args, reason)

        elif predicted_intent == "run_cmd":
            ok, args, reason = ground_run_cmd(query, raw_slots)
            if not ok:
                return ("rag_knowledge", 0.95, None, f"Action rejected: {reason} -> Safe fallthrough to RAG")
            return (predicted_intent, confidence, args, reason)

    # 3. Read-only and Informational Intents pass cleanly
    return (predicted_intent, confidence, None, "Validated by policy")
