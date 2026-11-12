"""
Minimo Brain Suite - Ultra-Fast In-Process Semantic Vector Router & Cognitive Disambiguator
Combines:
1. Pragmatic Discourse Guards (negation, cancellation, epistemic inquiries, volume controls)
2. Calibrated In-Process ONNX Bi-Encoder (bge-small-en-v1.5) with dense multi-exemplar manifolds
3. Margin-Based Confidence Gating & In-Process Neural Disambiguation Arbiter (Qwen 2.5)
Eliminates brittle regex cascades, false-positive task creation, and natural language blind spots.
"""

import os
import re
import time
import urllib.request
import json
import numpy as np
from typing import Dict, Any, List, Optional, Tuple

from .linear_classifier import get_calibrated_classifier
from .router_registry import validate_and_ground_intent, INTENT_POLICY, IntentRisk

MODEL_DIRS = [
    os.path.expanduser("~/.local/share/quickshell/models/bge-base-en-v1.5"),
    os.path.expanduser("~/.local/share/quickshell/models/bge-small-en-v1.5")
]
MODEL_DIR = next((d for d in MODEL_DIRS if os.path.isdir(d)), MODEL_DIRS[0])
OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://127.0.0.1:11434")

# Comprehensive, high-variance natural language exemplars
ROUTE_DEFINITIONS: Dict[str, List[str]] = {
    "play_media": [
        "play anime", "watch episode", "stream season", "open movie", "play frieren episode 5",
        "watch film", "put on episode", "play video", "stream frieren", "watch anime",
        "play local movie", "watch season 2 episode", "find movie and play", "stream show",
        "play fieren ep 5", "put on frieren", "watch anime episode", "watch steins gate episode 1",
        "stream movie interstellar", "play video clip", "open downloaded episode", "put on the next episode"
    ],
    "play_music": [
        "play song", "listen to music", "stream track", "play aimer", "queue music",
        "put on track", "play audio", "listen to album", "play music", "play track in background",
        "stream song from youtube", "play lofi beats", "put on some music", "play jazz",
        "play reaper by kelsey lu", "play something chill", "stream chillhop beats",
        "play some classical music", "put on background study beats", "drop some lofi music",
        "play acoustic guitar songs", "play ambient electronic music", "play something chill while i read",
        "stream piano playlist", "put on energetic synthwave music", "play soundtrack"
    ],
    "mpris_control": [
        "pause music", "resume music", "stop music", "next track", "skip song",
        "toggle playback", "pause playback", "unpause", "previous track", "stop playback",
        "whats playing", "what is playing", "what song is playing", "now playing", "current track",
        "what track is this", "current song", "play next song", "play next track", "play the next track",
        "play the next song", "play previous song", "play the previous track", "play the previous song",
        "skip to next song", "pause the music", "stop playing", "stop audio", "can we turn this off please it is too loud",
        "turn the music off", "shut off playback", "cut the sound", "drop the volume a bit",
        "turn down the volume", "mute playback", "lower the volume", "what jam is this currently playing",
        "who sings this track playing right now", "what is currently on player", "go back to previous track"
    ],
    "add_task": [
        "remind me to check slides tomorrow", "add a task for database migration", "new todo due 23rd evening p1",
        "schedule task", "create reminder", "assign priority 1 to issue", "add task",
        "finetune the ui interactions and synth background process cycle",
        "refactor database connection pool and fix query latency",
        "implement user authentication and session management",
        "update api endpoints and test webhook integration",
        "fix memory leak in audio playback daemon",
        "organize the sources card and bot reactions for each endpoint",
        "having difficulty in mpv subtitle rendering create a task due 23rd evening p1",
        "having trouble with sound create a reminder for tomorrow",
        "study chapter 3 create a reminder for monday morning",
        "facing issue with waybar audio widget crashing create a reminder for tomorrow morning",
        "bug in opengl rendering please add a task to fix it tonight",
        "create todoist task", "put this on my todo list", "set a reminder for tomorrow morning",
        "create a task for me on that issue", "add a task to review pull request",
        "make sure i dont forget to push git commits before leaving",
        "dont let me forget to submit the paper by friday",
        "remind me to buy groceries today at 6pm", "set an urgent task to inspect database replication",
        "add a reminder to call mom this evening", "schedule a dental appointment task for next week",
        "urgent task to restart production nginx server", "set a high priority task to review pull request",
        "media card and active pill in qs also not working create task"
    ],
    "list_tasks": [
        "what are my pending tasks", "show my todo list", "list tasks", "view upcoming tasks",
        "check my todoist", "display active tasks", "what do i need to do today", "show tasks",
        "show all pending tasks", "what items are left on my agenda", "what are my todos for today",
        "view active tasks in todoist", "list all my priority items", "what tasks are due this week",
        "check my pending action items", "display todo list", "what do i need to do"
    ],
    "active_window": [
        "what window is this", "what is on screen", "focused window info", "active application",
        "current window", "what am i doing", "which app is active", "what application is currently focused",
        "focused window title", "which process has focus", "what program is on top"
    ],
    "daily_horizon": [
        "daily horizon", "morning briefing", "daily briefing", "morning report", "brief me for the day",
        "what is my daily horizon", "good morning summary",
        "give me my morning horizon", "daily agenda overview", "morning overview"
    ],
    "mindspace": [
        "what did i copy to clipboard", "search clipboard stash", "show copied text",
        "find in clipboard", "clips from earlier", "recent clips in stash", "clipboard history",
        "did i copy that bearer token from postman earlier", "what was the last thing i copied",
        "search clipboard for token", "find that snippet i copied earlier", "check my clipboard stash"
    ],
    "chat": [
        "hello", "hi there", "who are you", "what can you do", "thanks a lot",
        "good morning", "how are you doing", "clear chat", "reset", "thank you",
        "hello kafka", "hey kafka", "who are you kafka", "what are we working on",
        "tell me about yourself", "how are you today", "what's up", "good evening",
        "never mind cancel that task", "todo: do not add a task", "stop adding reminders please",
        "forget about it", "cancel that request", "nevermind forget what i said", "no dont do that",
        "stop asking questions", "clear current prompt", "thanks for your help"
    ],
    "email_summary": [
        "what are the emails last hour", "summarize my emails from the last hour", "what emails did i get today",
        "summarize my last 5 emails", "check my recent emails", "any new emails in the last 2 hours",
        "what came into my inbox recently", "give me a summary of my inbox", "summarize unread emails",
        "what are my recent emails", "show recent emails", "read my recent emails", "digest of emails today",
        "what emails came in recently", "check my inbox for new emails", "give me an email summary",
        "summarize emails received today", "any new mail in the last hour", "what emails arrived today",
        "summarize the last 10 emails", "brief me on my recent emails", "give me a digest of recent emails",
        "what are the emails from the past hour", "show me emails from today", "summarize last 3 emails",
        "summary of latest email", "latest email", "summary of newest email", "summary of recent emails"
    ],
    "rag_knowledge": [
        "what is the paxos consensus algorithm", "explain the CAP theorem in distributed systems",
        "ctf writeup in notes", "difference between TCP and UDP",
        "what does marcus aurelius say about stoicism", "explain virtual memory page table translation",
        "how does cellular respiration work in mitochondria", "legal precedents for fair use doctrine",
        "notes on compiler architecture", "what are the formulas for blade element theory",
        "search my notes for python scripts", "explain rust ownership model",
        "how to create a task in celery for background jobs", "what is the linux kernel task scheduling algorithm",
        "how does linux manage task scheduling", "what is the difference between a task and a process in linux",
        "explain cooperative multitasking in embedded systems", "is there any mention in my notes of how to configure cross compilation",
        "i wrote a note about rust lifetimes last week find it",
        "can you remind me what is the definition of mach number",
        "pull up my notes on aerodynamic flutter boundary",
        "what does my org note say about system design",
        "explain the halting problem in computer science",
        "what is the time complexity of quicksort",
        "how does gradient descent work in machine learning",
        "explain bayes theorem with examples",
        "what is the boiling point of water at different altitudes",
        "how does the immune system recognize pathogens",
        "summarize chapter 3 of my book on systems programming",
        "definition of entropy in thermodynamics",
        "derive navier stokes from first principles"
    ]
}

class SemanticRouter:
    """
    Sub-3ms In-Process ONNX Semantic Vector Router with Margin-Based Confidence.
    """
    def __init__(self, model_dir: str = MODEL_DIR):
        self.model_dir = model_dir
        self.session = None
        self.tokenizer = None
        self.centroids: Dict[str, np.ndarray] = {}
        self.exemplar_embeddings: Dict[str, np.ndarray] = {}
        self.is_onnx = False
        self._init_engine()
        self._compute_centroids()

    def _init_engine(self):
        try:
            import onnxruntime as ort
            from tokenizers import Tokenizer

            model_candidates = [
                os.path.join(self.model_dir, "model_quantized.onnx"),
                os.path.join(self.model_dir, "model.onnx")
            ]
            model_path = next((p for p in model_candidates if os.path.isfile(p)), None)
            tok_path = os.path.join(self.model_dir, "tokenizer.json")

            if model_path and os.path.isfile(tok_path):
                opts = ort.SessionOptions()
                opts.intra_op_num_threads = 4
                opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
                self.session = ort.InferenceSession(model_path, opts, providers=["CPUExecutionProvider"])
                self.tokenizer = Tokenizer.from_file(tok_path)
                self.tokenizer.enable_truncation(max_length=512)
                self.tokenizer.enable_padding(direction="right", pad_id=0, pad_token="[PAD]")
                self.dim = 768 if "base" in self.model_dir else 384
                self.is_onnx = True
        except Exception:
            self.is_onnx = False
            self.dim = 768

    def embed_texts(self, texts: List[str]) -> np.ndarray:
        """Embed a list of strings into normalized dense vectors."""
        if not texts:
            return np.empty((0, getattr(self, "dim", 768)))

        if self.is_onnx and self.session and self.tokenizer:
            try:
                encs = self.tokenizer.encode_batch(texts)
                inputs = {
                    "input_ids": np.array([e.ids for e in encs], dtype=np.int64),
                    "attention_mask": np.array([e.attention_mask for e in encs], dtype=np.int64),
                    "token_type_ids": np.array([e.type_ids for e in encs], dtype=np.int64)
                }
                outputs = self.session.run(None, inputs)
                token_embeddings = outputs[0]
                if not hasattr(self, "dim") or self.dim != token_embeddings.shape[-1]:
                    self.dim = token_embeddings.shape[-1]
                mask = np.expand_dims(inputs["attention_mask"], -1)
                embs = np.sum(token_embeddings * mask, axis=1) / np.clip(mask.sum(axis=1), a_min=1e-9, a_max=None)
                norm = np.linalg.norm(embs, axis=1, keepdims=True)
                return embs / np.clip(norm, a_min=1e-9, a_max=None)
            except Exception:
                pass

        # Fallback to Ollama nomic-embed-text
        out = []
        for t in texts:
            try:
                payload = json.dumps({"model": "nomic-embed-text", "prompt": t[:1000]}).encode("utf-8")
                req = urllib.request.Request(f"{OLLAMA_URL}/api/embeddings", data=payload, headers={"Content-Type": "application/json"})
                with urllib.request.urlopen(req, timeout=3.0) as resp:
                    data = json.loads(resp.read().decode("utf-8"))
                    v = np.array(data.get("embedding", []), dtype=np.float32)
                    norm = np.linalg.norm(v)
                    out.append(v / norm if norm > 0 else v)
            except Exception:
                out.append(np.zeros(getattr(self, "dim", 768), dtype=np.float32))
        return np.array(out)

    def _compute_centroids(self):
        """Pre-compute centroid unit vectors and cache exemplar embeddings for each route."""
        for route_name, utterances in ROUTE_DEFINITIONS.items():
            embs = self.embed_texts(utterances)
            if len(embs) > 0:
                self.exemplar_embeddings[route_name] = embs
                mean_vec = np.mean(embs, axis=0)
                norm = np.linalg.norm(mean_vec)
                self.centroids[route_name] = mean_vec / norm if norm > 0 else mean_vec

    def classify_intent(self, query: str, threshold: float = 0.55) -> Tuple[str, float, float, Dict[str, float]]:
        """
        Classifies query intent via calibrated ensemble cosine similarity (Centroid + Top-K Exemplars).
        Returns: (best_route, best_score, margin, all_scores)
        """
        if not self.centroids:
            return ("rag_knowledge", 1.0, 1.0, {})

        q_emb = self.embed_texts([query])[0]
        scores: Dict[str, float] = {}
        for r_name, centroid in self.centroids.items():
            c_sim = float(np.dot(q_emb, centroid))
            e_embs = self.exemplar_embeddings.get(r_name)
            if e_embs is not None and len(e_embs) > 0:
                sims = np.dot(e_embs, q_emb)
                # Take top-2 exemplars average for robust local density
                top2_sim = float(np.mean(np.sort(sims)[-2:]))
                scores[r_name] = 0.40 * c_sim + 0.60 * top2_sim
            else:
                scores[r_name] = c_sim

        sorted_routes = sorted(scores.items(), key=lambda x: x[1], reverse=True)
        best_route, best_score = sorted_routes[0]
        second_score = sorted_routes[1][1] if len(sorted_routes) > 1 else 0.0
        margin = best_score - second_score

        return (best_route, best_score, margin, scores)

_ROUTER_INSTANCE: Optional[SemanticRouter] = None

def get_semantic_router() -> SemanticRouter:
    global _ROUTER_INSTANCE
    if _ROUTER_INSTANCE is None:
        _ROUTER_INSTANCE = SemanticRouter()
    return _ROUTER_INSTANCE

# =====================================================================
# In-Process Neural Disambiguation Arbiter (Stage 2 Judge)
# =====================================================================

def neural_arbitrate_candidates(query: str, candidates: List[str]) -> Optional[str]:
    """
    Sub-second In-Process Neural Judge using local Qwen 2.5.
    Invoked strictly when vector similarity margin is ambiguous (Δ < 0.12)
    or when edge-case indicators exist.
    """
    if not candidates:
        return None
    if len(candidates) == 1:
        return candidates[0]

    # Constrained prompt with candidate descriptions
    intent_descs = {
        "mpris_control": "controlling music playback (pause, stop, resume, next, prev, volume, turn off, now playing)",
        "play_music": "streaming or playing music, artists, tracks, moods, or genres",
        "play_media": "watching videos, movies, anime, or video files",
        "add_task": "user genuinely asking to create a task, reminder, or to-do action item (e.g. 'add a task', 'remind me', 'remind me to call')",
        "list_tasks": "user asking to view, list, or check pending tasks, todos, or what they need to do today",
        "mindspace": "searching clipboard history or past copied items",
        "active_window": "querying information about the currently active or focused desktop window",
        "daily_horizon": "morning briefing, daily horizon report, or general daily overview",
        "rag_knowledge": "technical questions, coding, explanations, literature, formulas, or searching personal notes",
        "chat": "conversational pleasantries, small talk, refusals, or cancellations (e.g. 'never mind', 'cancel that')"
    }

    cand_lines = "\n".join([f"- {c}: {intent_descs.get(c, c)}" for c in candidates])
    prompt = (
        f"<|im_start|>system\n"
        f"You are Minimo's Intent Arbiter. Choose which of the candidate intents best matches the user query.\n"
        f"Candidates:\n{cand_lines}\n\n"
        f"CRITICAL RULES:\n"
        f"1. Informational/technical questions ('how to create a task in celery', 'task scheduling in os') are rag_knowledge, NOT add_task.\n"
        f"2. Queries asking to cancel or NOT add something ('never mind', 'do not add a task') are chat, NOT add_task.\n"
        f"3. Standalone 'remind me', 'add a task', or 'remind me to [do something]' is add_task, NOT list_tasks. But 'remind me what is [X]' is asking for information (rag_knowledge).\n"
        f"4. 'turn this off' or 'too loud' is mpris_control.\n"
        f"5. Questions like 'what do i need to do' or 'what are my tasks/todos' are list_tasks, NOT daily_horizon.\n"
        f"6. Conceptual/technical questions ('what are fanno flows', 'explain entropy', 'how does x work') are rag_knowledge, NEVER play_media or play_music unless explicitly asking to play/watch/stream.\n\n"
        f"Output JSON: {{\"intent\": \"<intent>\"}}\n"
        f"<|im_end|>\n"
        f"<|im_start|>user\n"
        f"Query: \"{query}\"\n"
        f"<|im_end|>\n"
        f"<|im_start|>assistant\n"
    )

    try:
        req = urllib.request.Request(
            f"{OLLAMA_URL}/api/generate",
            data=json.dumps({
                "model": "qwen2.5:1.5b-instruct",
                "prompt": prompt,
                "stream": False,
                "format": "json",
                "options": {"temperature": 0.0, "num_predict": 20}
            }).encode("utf-8"),
            headers={"Content-Type": "application/json"}
        )
        with urllib.request.urlopen(req, timeout=3.5) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            out_obj = json.loads(data.get("response", "{}"))
            predicted = out_obj.get("intent", "").strip()
            if predicted in candidates:
                return predicted
    except Exception:
        pass
    return None

# =====================================================================
# Pragmatic Discourse & Linguistic Guards
# =====================================================================

def check_discourse_guards(query: str) -> Optional[Dict[str, Any]]:
    """
    Deterministic discourse & pragmatic intent guards.
    Evaluates in < 0.05ms to resolve negations, cancellations, epistemic inquiries,
    and physical audio controls that bag-of-words or vector cosine metrics misclassify.
    """
    q_strip = query.strip()
    ql = q_strip.lower()

    # 1. Cancellation, Refusal & Negative Task Markers
    if bool(re.search(r'\b(?:never\s*mind|cancel\s+(?:that|it|this|task|reminder)|abort(?:\s+(?:task|it|this|creation))?|stop\s+(?:adding|creating|putting|making)\s+tasks?|(?:don\x27?t|do\s+not)\s+(?:add|create|make|put|schedule|remind)|forget\s+(?:about\s+it|that|this|what\s+i\s+(?:just\s+)?said))\b', ql)):
        return {"intent": "chat", "search_query": None, "confidence": 0.99}

    if ql.startswith("todo:") and bool(re.search(r'\b(?:do\s+not|don\x27?t|cancel|never\s*mind|ignore)\b', ql)):
        return {"intent": "chat", "search_query": None, "confidence": 0.99}

    # 1B. Programming / Coding "Todo List" Data Structures (NOT user task listing)
    if bool(re.search(r'\b(?:implement|build|create|code|write|design)\s+(?:a\s+)?(?:todo\s+list|task\s+queue|task\s+scheduler)\b', ql)):
        return {"intent": "rag_knowledge", "category_filter": None, "search_query": q_strip, "confidence": 0.99}

    # 1C. Explicit Task Listing Queries ('my tasks', 'what are my tasks', 'show tasks', 'todo list', 'todoist')
    if bool(re.search(r'^(?:(?:show|list|view|check|see|get|what\s+are|display|open)\s+)?(?:all\s+)?(?:my\s+)?(?:tasks?|todos?)(?:\s+(?:for\s+)?today)?$', ql)) or ql in (
        "my tasks", "my todos", "tasks", "todos", "todo list", "task list", "pending tasks",
        "what to do", "what do i need to do", "todoist", "show todoist", "open todoist", "open tasks",
        "check tasks", "view tasks", "see tasks", "list tasks", "my todoist"
    ):
        return {"intent": "list_tasks", "confidence": 1.0}

    # 2. Epistemic Inquiries ('remind me what is X', 'remind me how X works')
    if bool(re.match(r'^(?:(?:can|could)\s+you\s+)?remind\s+me\s+(?:what|how|why|who|where|which|formula|definition)\b', ql)):
        return {"intent": "rag_knowledge", "category_filter": None, "search_query": q_strip, "confidence": 0.98}

    # 3. Technical Queries Involving "Task" as a Software/System Concept
    # e.g. "how to create a task in celery", "task scheduling in linux kernel", "todo list in python"
    if bool(re.search(r'\b(?:how\s+(?:to|do\s+i|can\s+i)\s+(?:create|add|run|write|use)\s+(?:a\s+)?(?:background\s+)?task\s+in\s+[a-zA-Z0-9_-]+|task\s+scheduling\s+(?:in|algorithm)|task\s+priority\s+inversion|todo\s+list\s+implementation|celery\s+task|asyncio\s+task)\b', ql)):
        return {"intent": "rag_knowledge", "category_filter": None, "search_query": q_strip, "confidence": 0.99}

    # 4. Physical Audio Volume, Mute & Silence Controls
    if bool(re.search(r'\b(?:turn\s+(?:this|it|music|audio)\s+off|too\s+loud|lower\s+(?:the\s+)?volume|drop\s+(?:the\s+)?volume|cut\s+the\s+sound|mute\s+playback|shut\s+(?:this|the\s+music)\s+(?:down|off))\b', ql)):
        return {"intent": "mpris_control", "mpris_action": "play-pause", "confidence": 0.99}

    # 5. Clipboard Memory Inquiries
    if bool(re.search(r'\b(?:did\s+i\s+copy|what\s+did\s+i\s+copy|copied\s+to\s+clipboard|in\s+my\s+clipboard|clipboard\s+history|token\s+from\s+postman|copied\s+snippet)\b', ql)):
        return {"intent": "mindspace", "search_query": q_strip, "confidence": 0.98}

    # 6. Personal Notes & Vault Inquiries
    if bool(re.search(r'\b(?:i\s+wrote\s+a\s+note|in\s+my\s+notes|search\s+my\s+notes|notes?\s+about|notes?\s+on|find\s+(?:the|my)?\s*note|mention\s+in\s+my\s+notes|notes?\s+vault)\b', ql)):
        clean_note_q = re.sub(r'^(?:is\s+there\s+any\s+mention\s+in\s+my\s+notes\s+of|i\s+wrote\s+a\s+note\s+about|search\s+my\s+notes\s+for|find\s+my\s+notes?\s+on)\s*', '', q_strip, flags=re.I).strip()
        clean_note_q = re.sub(r'\s+(?:last\s+week|yesterday|find\s+it|please)\s*$', '', clean_note_q, flags=re.I).strip()
        return {"intent": "rag_knowledge", "category_filter": "notes", "search_query": clean_note_q or q_strip, "confidence": 0.98}



    return None

# =====================================================================
# Disambiguation & Clarification Builders
# =====================================================================

def _format_clarify_option(intent: str, query: str) -> Dict[str, str]:
    labels = {
        "play_music": ("🎵 Play Audio / Music", f"play music {query}"),
        "play_media": ("🎬 Watch Video / Movie", f"watch movie {query}"),
        "mpris_control": ("⏯ Media Playback Control", f"{query}"),
        "add_task": ("📋 Add as Todoist Task", f"todo: {query}"),
        "run_cmd": ("💻 Run as Shell Command", f"${query}"),
        "mindspace": ("📋 Search Clipboard History", f"clipboard {query}"),
        "rag_knowledge": ("🔍 Search Notes & Library", f"search {query}")
    }
    lbl, q = labels.get(intent, (f"Action: {intent}", query))
    return {"label": lbl, "query": q}

def build_disambiguation_route(query: str, intent_a: str, intent_b: str, score: float) -> Dict[str, Any]:
    return {
        "intent": "disambiguation",
        "confidence": score,
        "prompt": f"I found multiple ways to handle \"{query}\". Which one did you mean?",
        "options": [
            _format_clarify_option(intent_a, query),
            _format_clarify_option(intent_b, query)
        ]
    }

# =====================================================================
# Main Hybrid Semantic Router
# =====================================================================

def route_intent_semantic(query: str, context_history: Optional[list] = None, mode: str = "all") -> Dict[str, Any]:
    """
    Cognitive Intent & Slot Resolver:
    1. Layer 1: Strict Prefix Fast-Path (0 ms)
    2. Layer 1B: Pragmatic Discourse & Negation Guards (< 0.1 ms)
    3. Layer 2: In-Process ONNX Dense Vector Matcher (< 3 ms)
    4. Layer 2B: Margin-Based Neural Disambiguation Arbiter (~400-700ms when ambiguous)
    5. Layer 3: Decoupled Slot & Entity Extraction
    """
    q_strip = query.strip()
    q_lower = q_strip.lower()

    if not q_strip:
        return {"intent": "chat", "search_query": None}

    # ── Layer 1: Strict Prefix Fast-Path (0 ms) ──
    if q_strip.startswith(("$", "!", "run ", "exec ")):
        cmd = re.sub(r'^(?:\$|!|run\s+|exec\s+)', '', q_strip).strip()
        return {"intent": "run_cmd", "command": cmd}

    if q_lower.startswith(("note:", "notes:", "book:", "rag:")):
        clean_q = re.sub(r'^(?:note|notes|book|rag):\s*', '', q_strip, flags=re.I).strip()
        cat = "notes" if q_lower.startswith(("note", "notes")) else "books"
        return {"intent": "rag_knowledge", "category_filter": cat, "search_query": clean_q}

    # ── Layer 1B: Pragmatic Discourse & Negation Guards ──
    guard_res = check_discourse_guards(q_strip)
    if guard_res:
        return guard_res

    # ── Layer 1C: Direct Task Prefix (after negation guard) ──
    if q_lower.startswith(("todo:", "task:", "remind:")):
        task_text = re.sub(r'^(?:todo|task|remind):\s*', '', q_strip, flags=re.I).strip()
        return _extract_task_entities(task_text, context_history)

    # ── Layer 1D: MPRIS Transport & Status Fast-Path ──
    # 1. Status / Now-playing
    if bool(re.search(r'\b(?:what(?:\x27s|s|\s+is|\s+was)?\s+(?:that\s+)?(?:song|track|jam)?\s*(?:is|was)?\s*playing|now\s+playing|current\s+song|current\s+track|track\s+info|what\s+jam\s+(?:is|was)\s+this)\b', q_lower)):
        return {"intent": "mpris_control", "mpris_action": "status"}

    # 2. Next track / skip
    if bool(re.match(r'^(?:play\s+)?(?:the\s+)?(?:next|skip)(?:\s+(?:to\s+)?(?:the\s+)?)?(?:song|track|music|audio)?$', q_lower)) or q_lower in ("next", "skip", "next track", "next song", "skip song", "play next", "play next song", "play next track", "play the next song", "skip to next song"):
        return {"intent": "mpris_control", "mpris_action": "next"}

    # 3. Previous track
    if bool(re.match(r'^(?:play\s+)?(?:the\s+)?(?:prev|previous|last)(?:\s+(?:song|track|music|audio))?$', q_lower)) or bool(re.match(r'^(?:go\s+back(?:\s+(?:a|to))?)(?:\s+(?:the\s+)?(?:song|track|music|audio))?$', q_lower)) or q_lower in ("prev", "previous", "previous track", "previous song", "play previous song", "play prev track", "play the previous track"):
        return {"intent": "mpris_control", "mpris_action": "previous"}

    # 4. Pause
    if bool(re.match(r'^(?:pause|hold)(?:\s+(?:the\s+)?(?:music|song|track|playback|audio))?$', q_lower)):
        return {"intent": "mpris_control", "mpris_action": "play-pause"}

    # 5. Stop
    if bool(re.match(r'^(?:stop|halt|kill)(?:\s+(?:the\s+)?(?:music|song|track|playback|audio|stream|playing))?$', q_lower)):
        return {"intent": "mpris_control", "mpris_action": "stop"}

    # 6. Resume / unpause
    if bool(re.match(r'^(?:resume|unpause)(?:\s+(?:the\s+)?(?:music|song|track|playback|audio))?$', q_lower)):
        return {"intent": "mpris_control", "mpris_action": "play-pause"}

    # 7. Fast Volume controls
    if bool(re.search(r'\b(?:turn\s+down|turn\s+up|lower|drop|increase|raise|crank\s+up)\s+(?:the\s+)?volume\b', q_lower)) or bool(re.search(r'\b(?:volume\s+(?:up|down)|louder|quieter|mute\s+playback)\b', q_lower)):
        act = "volume_up" if any(w in q_lower for w in ("up", "louder", "increase", "crank", "raise")) else "volume_down"
        return {"intent": "mpris_control", "mpris_action": act, "confidence": 0.99}

    # ── Layer 1D2: Music Playback Prefix Fast-Path (0 ms) ──
    has_video_signal = any(w in q_lower for w in ('ep', 'episode', 'season', 'movie', 'anime', 'mkv', 'mp4', 'film', 'frieren', 'cinema', 'series')) or bool(re.search(r'\b(?:s\d+|e\d+|ep\s*\d+|part\s*\d+)\b', q_lower))
    is_music_prefix = bool(re.match(r'^(?:please\s+)?(?:play\s+song|play\s+music|play\s+track|play\s+|listen\s+to|stream\s+song|stream\s+|queue\s+song|queue\s+|put\s+on\s+music|put\s+on\s+)(.+)', q_strip, re.I))
    if is_music_prefix and not has_video_signal and not bool(re.search(r'\b(?:play\s+with\s+fire|play\s+a\s+role|play\s+into)\b', q_lower)):
        m_target = re.sub(r'^(?:please\s+)?(?:play\s+song|play\s+music|play\s+track|play\s+|listen\s+to|stream\s+song|stream\s+|queue\s+song|queue\s+|put\s+on\s+music|put\s+on\s+)', '', q_strip, flags=re.I).strip()
        if m_target:
            return {"intent": "play_music", "music_query": m_target, "confidence": 0.99}

    # ── Layer 1E: Fast Email Summary Inquiries (0 ms) ──
    email_fast_regex = r"\b(?:what\s+are\s+(?:the\s+)?emails|summarize\s+(?:my\s+|the\s+)?emails?|(?:summary|digest)\s+of\s+(?:my\s+|the\s+|latest\s+|newest\s+|recent\s+)?emails?|check\s+(?:my\s+)?(?:inbox|emails?)|(?:any\s+)?(?:new\s+)?emails?\s+(?:from\s+)?(?:the\s+)?(?:last|past)\s+\d+\s*(?:hours?|hrs?|mins?|minutes?)|(?:any\s+)?(?:new\s+)?emails?\s+today|(?:last|top|first)\s+\d+\s+emails?|(?:latest|newest|most\s+recent|last)\s+email|email\s+summary|inbox\s+summary)\b"
    if bool(re.search(email_fast_regex, q_lower)):
        from .emails import parse_email_query_params
        p = parse_email_query_params(q_strip)
        return {"intent": "email_summary", "email_params": p, "confidence": 0.99}

    # Mode Override
    if mode == "notes":
        return {"intent": "rag_knowledge", "category_filter": "notes", "search_query": q_strip}
    if mode == "books":
        return {"intent": "rag_knowledge", "category_filter": "books", "search_query": q_strip}
    if mode == "tasks":
        return _extract_task_entities(q_strip, context_history)

    # ── Layer 2: Calibrated In-Process Linear Classifier (< 3 ms) ──
    router = get_semantic_router()
    q_emb = router.embed_texts([q_strip])[0]
    clf = get_calibrated_classifier(router.embed_texts)
    probs = clf.predict_proba(q_emb)

    candidates = list(probs.items())
    top1_route, top1_score = candidates[0]
    top2_route, top2_score = candidates[1] if len(candidates) > 1 else ("", 0.0)
    margin = top1_score - top2_score

    best_route = top1_route
    score = top1_score

    # Out-of-Distribution / Hard Negative check
    if best_route == "other":
        has_imperative_action = bool(re.match(r'^(?:play\s+|stream\s+|watch\s+|remind\s+me\s+to\s+|todo:)', q_lower))
        is_known_idiom = bool(re.search(r'\b(?:play\s+with\s+fire|play\s+a\s+role|play\s+into)\b', q_lower))
        
        # Check if an action candidate exists that can be validated by reality grounding
        action_cand = next((c for c, p in candidates if c in ("play_music", "play_media", "add_task") and p > 0.15), None)
        if has_imperative_action and not is_known_idiom and action_cand:
            best_route = action_cand
            score = probs.get(action_cand, 0.50)
        else:
            cat = None
            if bool(re.search(r'\b(?:notes?|my\s+notes?|org|roam|obsidian)\b', q_lower)):
                cat = "notes"
            elif bool(re.search(r'\b(?:books?|papers?|pdfs?|textbooks?|literature|handbooks?)\b', q_lower)):
                cat = "books"
            return {"intent": "rag_knowledge", "category_filter": cat, "search_query": q_strip, "confidence": 0.95}

    # ── Layer 2B: Neural Disambiguation Arbiter (Stage 2 Judge for uncertain band) ──
    has_ambiguity = (margin < 0.12 or score < 0.65) and top2_route != "" and top2_route != "other"
    has_potential_edge_indicators = any(w in q_lower for w in ("task", "remind", "note", "song", "play", "copy", "show", "what"))

    if has_ambiguity and has_potential_edge_indicators:
        arbitrated = neural_arbitrate_candidates(q_strip, [top1_route, top2_route])
        if arbitrated:
            best_route = arbitrated
            score = 0.95
        elif top1_route != "rag_knowledge" and top2_route != "rag_knowledge" and margin < 0.08:
            return build_disambiguation_route(q_strip, top1_route, top2_route, score)

    # ── Layer 3: Typed Pydantic & Grounding Gatekeeper ──
    final_intent, final_conf, validated_args, audit_reason = validate_and_ground_intent(
        best_route, score, margin, q_strip
    )

    # ── Layer 4: Structured Return Payload ──
    if final_intent == "disambiguation":
        return build_disambiguation_route(q_strip, top1_route, top2_route, final_conf)
    if final_intent == "play_media":
        title = validated_args.raw_query if (validated_args and hasattr(validated_args, "raw_query")) else q_strip
        return {"intent": "play_media", "media_title": title, "confidence": final_conf}

    if final_intent == "play_music":
        m_q = validated_args.raw_query if (validated_args and hasattr(validated_args, "raw_query")) else q_strip
        return {"intent": "play_music", "music_query": m_q, "confidence": final_conf}

    if final_intent == "mpris_control":
        m_act = validated_args.action if (validated_args and hasattr(validated_args, "action")) else "play-pause"
        return {"intent": "mpris_control", "mpris_action": m_act, "confidence": final_conf}

    if final_intent == "add_task":
        return _extract_task_entities(q_strip, context_history)

    if final_intent == "list_tasks":
        return {"intent": "list_tasks", "confidence": final_conf}

    if final_intent == "run_cmd":
        cmd = validated_args.command if (validated_args and hasattr(validated_args, "command")) else q_strip
        return {"intent": "run_cmd", "command": cmd, "confidence": final_conf}

    if final_intent == "active_window":
        return {"intent": "active_window", "confidence": final_conf}

    if final_intent == "daily_horizon":
        return {"intent": "daily_horizon", "confidence": final_conf}

    if final_intent == "mindspace":
        return {"intent": "mindspace", "search_query": q_strip, "confidence": final_conf}

    if final_intent == "chat":
        return {"intent": "chat", "search_query": None, "confidence": final_conf}

    # Default / Fallthrough to RAG Knowledge
    cat = None
    if bool(re.search(r'\b(?:notes?|my\s+notes?|org|roam|obsidian)\b', q_lower)):
        cat = "notes"
    elif bool(re.search(r'\b(?:books?|papers?|pdfs?|textbooks?|literature|handbooks?)\b', q_lower)):
        cat = "books"
    return {"intent": "rag_knowledge", "category_filter": cat, "search_query": q_strip, "confidence": final_conf}

def _extract_task_entities(raw_query: str, context_history: Optional[list] = None) -> Dict[str, Any]:
    """
    Decoupled natural-language friendly task entity extractor:
    - Strips priority, due dates, and command verbs anywhere in the prompt.
    - Rephrases conversational problem statements ('having difficulty in X') into actionable titles ('Fix X').
    - Resolves conversational anaphora using cross-matrix extractor when context is available.
    - Enforces confidence gating: vague titles trigger a friendly clarification request.
    """
    text = raw_query.strip()
    q_lower = text.lower()

    # 1. Regex Priority (P1 - P4 or words)
    priority = None
    p_m = re.search(r'\b(?:assign\s+|set\s+)?(?:priority\s+(?:to\s+|:\s*)?|[pP]\s*)([1-4])(?:\s+priority)?\b', text)
    if p_m:
        priority = int(p_m.group(1))
        text = text[:p_m.start()] + ' ' + text[p_m.end():]
    elif re.search(r'\b(?:urgent|highest\s+priority|critical\s+priority)\b', text, re.I):
        priority = 1
        text = re.sub(r'\b(?:urgent|highest\s+priority|critical\s+priority)\b', '', text, flags=re.I)
    elif re.search(r'\b(?:high\s+priority)\b', text, re.I):
        priority = 2
        text = re.sub(r'\b(?:high\s+priority)\b', '', text, flags=re.I)
    elif re.search(r'\b(?:medium\s+priority|normal\s+priority)\b', text, re.I):
        priority = 3
        text = re.sub(r'\b(?:medium\s+priority|normal\s+priority)\b', '', text, flags=re.I)
    elif re.search(r'\b(?:low\s+priority|lowest\s+priority)\b', text, re.I):
        priority = 4
        text = re.sub(r'\b(?:low\s+priority|lowest\s+priority)\b', '', text, flags=re.I)

    # 2. Composite Due Date & Time
    due_str = None
    due_patterns = [
        r'\b(?:due(?:\s+by|\s+on|\s+at|\s+for)?|by|on|at)\s+([0-9]{1,2}(?:st|nd|rd|th)?(?:\s+(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*)?(?:\s+(?:morning|evening|afternoon|night))?(?:\s+(?:at\s+)?[0-9]{1,2}(?::[0-9]{2})?\s*(?:am|pm)?)?|tomorrow(?:\s+(?:morning|evening|afternoon|night))?(?:\s+(?:at\s+)?[0-9]{1,2}(?::[0-9]{2})?\s*(?:am|pm)?)?|today(?:\s+(?:morning|evening|afternoon|night))?|tonight|next\s+\w+|monday|tuesday|wednesday|thursday|friday|saturday|sunday)(?:\s+(?:at\s+)?[0-9]{1,2}(?::[0-9]{2})?\s*(?:am|pm)?)?\b',
        r'\b(?:tomorrow|today|tonight)(?:\s+(?:morning|evening|afternoon|night))?(?:\s+(?:at\s+)?[0-9]{1,2}(?::[0-9]{2})?\s*(?:am|pm)?)?\b'
    ]
    for dp in due_patterns:
        d_m = re.search(dp, text, re.I)
        if d_m:
            raw_due = d_m.group(0).strip()
            clean_due = re.sub(r'^(?:due(?:\s+by|\s+on|\s+at|\s+for)?|by|on|at)\s+', '', raw_due, flags=re.I).strip()
            due_str = clean_due or raw_due
            text = text[:d_m.start()] + ' ' + text[d_m.end():]
            break

    # 3. Check for Conversational Anaphora & Complex / Messy Inputs
    has_explicit_problem = bool(re.search(r'\b(?:not working|broken|crashing|fails|failing|error|glitch|difficulty|trouble|problem\s+with|issue\s+with|bug\s+in)\b', q_lower))
    has_action_verb = bool(re.match(r'^(?:buy|clean|read|re-read|fix|restart|deploy|check|update|install|review|submit|push)\b', q_lower))
    is_self_contained = (has_explicit_problem or has_action_verb) and len(raw_query.split()) > 4

    effective_context = None if is_self_contained else context_history
    has_conversational_ref = bool(effective_context) and any(w in q_lower for w in ("this", "that", "it", "issue", "problem", "above", "mentioned", "previous"))

    has_rambling_markers = any(w in q_lower for w in ("because", "since", "due to", "so that", "and also", "as well", "mom said", "check if", "make sure", "don't forget to", "dont forget to", "remember to", "need to", "gotta", "have to", "down the street", "when you get a chance"))
    is_complex = has_conversational_ref or (len(raw_query.split()) > 5) or has_explicit_problem or has_rambling_markers
    if is_complex:
        try:
            from .router import extract_task_cross_matrix
            llm_res = extract_task_cross_matrix(raw_query, context_history=effective_context, regex_priority=priority)
            if llm_res and llm_res.get("task_title") and not llm_res.get("needs_clarification"):
                if due_str:
                    llm_res["task_due"] = due_str
                if priority:
                    llm_res["task_priority"] = priority
                return llm_res
        except Exception:
            pass

    # 4. Strip command verbs anywhere in the text
    cmd_patterns = [
        r'\b(?:please\s+)?(?:create|add|make|set|schedule|put)\s+(?:a\s+|an\s+|the\s+|this\s+|that\s+)?(?:new\s+)?(?:tasks?|reminders?|todos?|alerts?|events?|notes?)(?:\s+(?:for\s+me|on\s+(?:my\s+)?todoist|in\s+(?:my\s+)?todoist|to\s+(?:my\s+)?todoist|on\s+my\s+list|to\s+my\s+list|to\s+todoist:?|to\s+tasks?:?))?(?:\s+(?:for|on|about|to)\b)?',
        r'\b(?:please\s+)?(?:remind\s+me|alert\s+me)(?:\s+to)?\b',
        r'\b(?:put\s+this\s+on\s+my\s+todo\s+list|put\s+on\s+my\s+todo\s+list)\b',
        r'\b(?:on\s+that\s+issue|about\s+that\s+issue|for\s+that\s+issue|on\s+this\s+issue|for\s+this\s+issue)\b',
        r'\b(?:to\s+)?(?:fix\s+it|fix\s+this|resolve\s+it|solve\s+it|look\s+into\s+it|investigate\s+it|debug\s+it)\b',
        r'\b(?:(?:a\s+|an\s+)?(?:tasks?|reminders?|todos?)\s+to)\b',
        r'\b(?:also|too|as\s+well)\s*$',
        r'^(?:todos?|tasks?|reminders?):\s*'
    ]
    for cp in cmd_patterns:
        text = re.sub(cp, '', text, flags=re.I)

    # Convert problem phrasing to natural actionable titles ('having difficulty in X' -> 'Fix X', 'X not working' -> 'Fix X')
    text = re.sub(r'^(?:(?:i\s+|we\s+)?(?:am|are|\'m|\'re)?\s*(?:having|facing|seeing|got|have|discovered|encountering|there\s+is\s+a)\s+)?(?:a\s+|an\s+)?(?:difficulty|trouble|problem|issue|bug|glitch|error)\s+(?:in|with)\s+', 'Fix ', text, flags=re.I)
    text = re.sub(r'^(?:a\s+|an\s+)?(?:difficulty|trouble|problem|issue|bug|glitch|error)\s+(?:in|with)\s+', 'Fix ', text, flags=re.I)
    text = re.sub(r'^(?:(?:the|my)\s+)?(.+?)\s+(?:is\s+|are\s+)?(?:also\s+)?(?:not\s+working|broken|crashing|failing)$', r'Fix \1', text, flags=re.I)

    # Conversational imperatives / obligation phrasing to strip
    text = re.sub(r'^(?:remember\s+to|don\'t\s+forget\s+to|dont\s+forget\s+to|make\s+sure\s+to|be\s+sure\s+to)\s+', '', text, flags=re.I)
    text = re.sub(r'^(?:(?:i\s+|we\s+)?(?:need|have|got|want)\s+to|must)\s+', '', text, flags=re.I)

    # Clean leading glue words & trailing leftover words
    for _ in range(3):
        text = re.sub(r'^(?:please|can\s+you|could\s+you|also|and|hey|hi|to|for|about|on|in|at)\s+', '', text, flags=re.I)
        text = re.sub(r'\s+(?:due|assign|priority|by|on|at|for|to|too|as\s+well|also)\s*$', '', text, flags=re.I)

    clean_title = re.sub(r'\s{2,}', ' ', text).strip()

    vague_titles = {'', 'this', 'that', 'it', 'task', 'tasks', 'new task', 'a task', 'add task', 'add tasks', 'create task', 'the task', 'reminder', 'a reminder', 'todo', 'todos', 'new todo', 'issue', 'problem', 'something', 'please', 'thanks', 'thank you', 'ok', 'to todoist', 's to todoist', 's to todoist:'}
    is_vague = (not clean_title) or (clean_title.lower() in vague_titles) or (len(clean_title) < 3) or bool(re.match(r'^(?:s\s+)?(?:to\s+todoist|to\s+tasks?|todoist)\b', clean_title.lower()))

    final_title = clean_title if not is_vague else raw_query
    if final_title and len(final_title) > 1:
        final_title = final_title[0].upper() + final_title[1:]

    desc = f"{raw_query}\n\n\u2014 Noted by Kafka" if len(raw_query) > len(final_title) + 5 else "\u2014 Noted by Kafka"

    return {
        "intent": "add_task",
        "task_title": final_title,
        "task_description": desc,
        "task_due": due_str,
        "task_priority": priority or 2,
        "confidence": 0.35 if is_vague else 0.90,
        "needs_clarification": is_vague,
        "clarification_prompt": "Could you please specify the title or details for this task?" if is_vague else None
    }
