#!/usr/bin/env python3
"""
tools/generate_dataset.py
Generates a comprehensive, high-variance dataset of 500+ queries for Minimo Brain.
Includes:
- Real-world messy colloquial voice queries
- Extensive hard negatives (homonyms for flow, task, play, stream, remind, window, list, run)
- Independent Train / Test splits with ZERO data leakage
"""

import os
import json
import random
from typing import List, Dict, Any

FULL_DATASET: List[Dict[str, Any]] = [
    # =========================================================================
    # 1. HARD NEGATIVES & OUT-OF-DISTRIBUTION (Expected: rag_knowledge or chat, NOT action!)
    # =========================================================================
    # Homonyms of 'flow' (Gas dynamics, fluid mechanics, finance, vision, networking)
    {"query": "what is fanno flow", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_flow"},
    {"query": "what are fanno flows in compressible gas dynamics", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_flow"},
    {"query": "explain fanno line on a temperature entropy diagram", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_flow"},
    {"query": "derive fanno flow equations for constant area duct with friction", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_flow"},
    {"query": "difference between fanno flow and rayleigh flow", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_flow"},
    {"query": "choking condition in fanno flow when mach number equals 1", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_flow"},
    {"query": "how does cash flow analysis work in financial modeling", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_flow"},
    {"query": "free cash flow to firm vs free cash flow to equity", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_flow"},
    {"query": "explain optical flow calculation using lucas kanade method", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_flow"},
    {"query": "gunnar farneback dense optical flow algorithm in opencv", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_flow"},
    {"query": "what causes buffer overflow in c programs", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_flow"},
    {"query": "integer overflow and underflow vulnerabilities in solidity", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_flow"},
    {"query": "air flow separation over an airfoil at stall angle", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_flow"},
    {"query": "laminar to turbulent flow transition in boundary layers", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_flow"},
    {"query": "poiseuille flow between two stationary parallel plates", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_flow"},
    {"query": "couette flow velocity profile with moving upper boundary", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_flow"},
    {"query": "supersonic flow through convergent divergent de laval nozzle", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_flow"},
    {"query": "workflow automation patterns in modern devops pipelines", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_flow"},
    {"query": "network traffic flow analysis and netflow monitoring", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_flow"},
    {"query": "flowchart symbols and standard process flow notation", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_flow"},
    {"query": "incompressible navier stokes potential flow theory", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_flow"},
    {"query": "what is blood flow resistance in cardiovascular hemodynamics", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_flow"},
    {"query": "heat flow by conduction fourier law formula", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_flow"},

    # Homonyms of 'task' & 'todo' (Operating systems, software architectures, algorithms)
    {"query": "how does task scheduling work in the linux kernel", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_task"},
    {"query": "completely fair scheduler cfs red black tree task management", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_task"},
    {"query": "how to implement celery background task in python django", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_task"},
    {"query": "asyncio create_task vs gather event loop mechanics", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_task"},
    {"query": "task parallelism vs data parallelism in concurrent computing", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_task"},
    {"query": "priority inversion problem in real time operating systems freertos", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_task"},
    {"query": "task control block tcb structure in os kernel internals", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_task"},
    {"query": "how to build a todo list app in react with redux toolkit", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_task"},
    {"query": "todoist api webhook payload schema documentation", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_task"},
    {"query": "how does windows task manager measure cpu utilization", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_task"},
    {"query": "task switching overhead and context switch cost in x86", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_task"},
    {"query": "multitasking preemptive vs cooperative scheduling models", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_task"},
    {"query": "task group in python 3.11 exception groups and structured concurrency", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_task"},
    {"query": "how does celery beat schedule recurring background tasks", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_task"},
    {"query": "what is rate monotonic scheduling for periodic real time tasks", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_task"},

    # Homonyms of 'play' (Idioms, biology, theater, sports, games)
    {"query": "what does it mean to play with fire idiom", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_play"},
    {"query": "how enzymes play a crucial role in cellular respiration", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_play"},
    {"query": "how do interest rates play into currency valuation", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_play"},
    {"query": "what role did churchill play in the yalta conference", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_play"},
    {"query": "analysis of shakespeare play hamlet act 3 scene 1", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_play"},
    {"query": "who are the main characters in the play death of a salesman", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_play"},
    {"query": "rules of fair play in international soccer tournaments", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_play"},
    {"query": "what is a double play in baseball defense", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_play"},
    {"query": "game theory Nash equilibrium in non cooperative play", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_play"},
    {"query": "how epigenetic factors play into cancer development", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_play"},

    # Homonyms of 'stream' (Physics, hydrology, distributed systems, literature)
    {"query": "stream of consciousness narrative technique in virginia woolf", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_stream"},
    {"query": "gulf stream thermohaline circulation climate impact", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_stream"},
    {"query": "jet stream velocity and polar vortex meteorology", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_stream"},
    {"query": "apache flink vs spark streaming architecture comparison", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_stream"},
    {"query": "how does git tracking upstream and downstream branches work", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_stream"},
    {"query": "bitstream generation and fpga configuration routing", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_stream"},
    {"query": "standard input output streams stdin stdout in unix kernel", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_stream"},
    {"query": "stream cipher vs block cipher in symmetric cryptography", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_stream"},
    {"query": "chaitin constant stream in algorithmic information theory", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_stream"},

    # Homonyms of 'remind' (Epistemic inquiries asking for information)
    {"query": "remind me what is the formula for entropy in statistical mechanics", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_remind"},
    {"query": "remind me how quicksort algorithm pivot selection works", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_remind"},
    {"query": "remind me who invented the linux operating system kernel", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_remind"},
    {"query": "remind me what is amontons law of dry friction", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_remind"},
    {"query": "remind me how rsa public key encryption prime factorization works", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_remind"},
    {"query": "remind me what the ideal gas law pv nrt stands for", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_remind"},
    {"query": "remind me why the sky appears blue rayleigh scattering", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_remind"},
    {"query": "remind me what mach angle formula is in supersonic flight", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_remind"},
    {"query": "remind me what the speed of sound at sea level is", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_remind"},

    # Homonyms of 'window' (Math, DSP, networking, politics)
    {"query": "how do window functions work in postgresql sql queries", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_window"},
    {"query": "hamming window vs hanning window in fourier spectral analysis", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_window"},
    {"query": "tcp sliding window protocol flow control and congestion avoidance", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_window"},
    {"query": "what is the overton window of political discourse", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_window"},
    {"query": "history of gothic stained glass windows in chartres cathedral", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_window"},
    {"query": "window of vulnerability in zero day exploit mitigation", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_window"},

    # Homonyms of 'list' (Data structures, grammar, literature)
    {"query": "reading list for graduate fluid dynamics and aerodynamics", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_list"},
    {"query": "how does a doubly linked list work in c memory layout", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_list"},
    {"query": "skip list probabilistic alternative to balanced trees", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_list"},
    {"query": "python list comprehension vs generator expression memory footprint", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_list"},
    {"query": "what is an adjacency list representation of a directed graph", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_list"},
    {"query": "materials list for constructing a wind tunnel balance", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_list"},

    # Homonyms of 'horizon' (Astrophysics, finance, radar)
    {"query": "what is the event horizon of a rotating kerr black hole", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_horizon"},
    {"query": "radar horizon calculation taking into account earth curvature", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_horizon"},
    {"query": "investment time horizon and risk tolerance asset allocation", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_horizon"},
    {"query": "vanishing point and horizon line in two point linear perspective", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_horizon"},

    # Homonyms of 'run' & 'exec' (Computing, idioms, law)
    {"query": "what is a runtime error vs compile time error in rust", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_run"},
    {"query": "meaning of the phrase run of the mill origin", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_run"},
    {"query": "executive branch powers and checks and balances in us constitution", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_run"},
    {"query": "order of operations in arithmetic pemdas rules", "expected_intent": "rag_knowledge", "is_action": False, "tag": "hard_negative_run"},

    # Out-of-Distribution General World Knowledge (Safe Fallthrough to RAG/Chat)
    {"query": "what is the capital city of australia", "expected_intent": "rag_knowledge", "is_action": False, "tag": "ood_general"},
    {"query": "how do commercial jet engines generate reverse thrust", "expected_intent": "rag_knowledge", "is_action": False, "tag": "ood_general"},
    {"query": "calculate the definite integral of x squared from 0 to 5", "expected_intent": "rag_knowledge", "is_action": False, "tag": "ood_general"},
    {"query": "who wrote the novel crime and punishment", "expected_intent": "rag_knowledge", "is_action": False, "tag": "ood_general"},
    {"query": "photosynthesis calvin cycle light independent reactions", "expected_intent": "rag_knowledge", "is_action": False, "tag": "ood_general"},
    {"query": "what is the half life of carbon 14 dating", "expected_intent": "rag_knowledge", "is_action": False, "tag": "ood_general"},
    {"query": "how do semiconductors doped with phosphorus work", "expected_intent": "rag_knowledge", "is_action": False, "tag": "ood_general"},
    {"query": "why do spinning tops resist falling gyroscopic precession", "expected_intent": "rag_knowledge", "is_action": False, "tag": "ood_general"},
    {"query": "how does sourdough fermentation create carbon dioxide", "expected_intent": "rag_knowledge", "is_action": False, "tag": "ood_general"},
    {"query": "what is the difference between nuclear fission and fusion", "expected_intent": "rag_knowledge", "is_action": False, "tag": "ood_general"},

    # =========================================================================
    # 2. ADD_TASK (Imperative Action Requests)
    # =========================================================================
    {"query": "remind me to check the slides tomorrow morning", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "add a task for database migration p1 due friday", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "new todo due 23rd evening p1", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "schedule task to review pull request from alex", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "create a reminder for monday morning to email advisor", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "finetune the ui interactions and synth background process cycle", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "refactor database connection pool and fix query latency", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "bug in opengl rendering please add a task to fix it tonight", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "make sure i dont forget to push git commits before leaving", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "remind me to buy groceries today at 6pm", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "urgent task to restart production nginx server", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "todo: submit reimbursement receipts for conference travel", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "task: fix broken hyperlink in documentation footer", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "remind me to call mom this evening around 8pm", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "set a high priority reminder for doctor appointment next tuesday at 10am", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "dont let me forget to renew car insurance policy this weekend", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "put on my todo list to inspect thermal paste on cpu cooler", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "add task clean up downloads directory and archive pdfs p3", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "remind me to pickup laundry tomorrow afternoon", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "schedule a dental checkup task for next month", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "urgent todo: patch openssl vulnerability on web servers p1", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "create task order spare ethernet cables from amazon", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "having trouble with waybar audio crashing create a reminder for tomorrow", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "media card in quickshell not updating state create task", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "add reminder to submit conference camera ready paper by thursday", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "todo: draft reply to reviewer comments p2", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "remind me tonight to backup obsidian vault to external drive", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "put a task to verify ssl cert renewal before expiry", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "task: review pull request 42 on github", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},
    {"query": "remind me to take vitamins with dinner tonight", "expected_intent": "add_task", "is_action": True, "tag": "add_task"},

    # =========================================================================
    # 3. LIST_TASKS (Read-only Inquiries)
    # =========================================================================
    {"query": "what are my pending tasks", "expected_intent": "list_tasks", "is_action": False, "tag": "list_tasks"},
    {"query": "show my todo list", "expected_intent": "list_tasks", "is_action": False, "tag": "list_tasks"},
    {"query": "list tasks", "expected_intent": "list_tasks", "is_action": False, "tag": "list_tasks"},
    {"query": "view upcoming tasks", "expected_intent": "list_tasks", "is_action": False, "tag": "list_tasks"},
    {"query": "check my todoist", "expected_intent": "list_tasks", "is_action": False, "tag": "list_tasks"},
    {"query": "what do i need to do today", "expected_intent": "list_tasks", "is_action": False, "tag": "list_tasks"},
    {"query": "what items are left on my agenda", "expected_intent": "list_tasks", "is_action": False, "tag": "list_tasks"},
    {"query": "what are my todos for today", "expected_intent": "list_tasks", "is_action": False, "tag": "list_tasks"},
    {"query": "display active tasks", "expected_intent": "list_tasks", "is_action": False, "tag": "list_tasks"},
    {"query": "show all overdue tasks", "expected_intent": "list_tasks", "is_action": False, "tag": "list_tasks"},
    {"query": "what tasks are due this week", "expected_intent": "list_tasks", "is_action": False, "tag": "list_tasks"},
    {"query": "list my priority 1 items", "expected_intent": "list_tasks", "is_action": False, "tag": "list_tasks"},
    {"query": "do i have anything scheduled for today", "expected_intent": "list_tasks", "is_action": False, "tag": "list_tasks"},
    {"query": "show pending reminders", "expected_intent": "list_tasks", "is_action": False, "tag": "list_tasks"},
    {"query": "what is on my agenda for this afternoon", "expected_intent": "list_tasks", "is_action": False, "tag": "list_tasks"},

    # =========================================================================
    # 4. PLAY_MUSIC (Action Requests Grounded to Local Audio / Streaming)
    # =========================================================================
    {"query": "play reaper by kelsey lu", "expected_intent": "play_music", "is_action": True, "tag": "play_music"},
    {"query": "play something chill while i read", "expected_intent": "play_music", "is_action": True, "tag": "play_music"},
    {"query": "stream chillhop beats in background", "expected_intent": "play_music", "is_action": True, "tag": "play_music"},
    {"query": "play some jazz music", "expected_intent": "play_music", "is_action": True, "tag": "play_music"},
    {"query": "put on background study beats", "expected_intent": "play_music", "is_action": True, "tag": "play_music"},
    {"query": "play acoustic guitar songs", "expected_intent": "play_music", "is_action": True, "tag": "play_music"},
    {"query": "stream piano playlist", "expected_intent": "play_music", "is_action": True, "tag": "play_music"},
    {"query": "put on energetic synthwave music", "expected_intent": "play_music", "is_action": True, "tag": "play_music"},
    {"query": "play aimer brave shine", "expected_intent": "play_music", "is_action": True, "tag": "play_music"},
    {"query": "listen to lofi beats in the background", "expected_intent": "play_music", "is_action": True, "tag": "play_music"},
    {"query": "play classical piano sonata in c major", "expected_intent": "play_music", "is_action": True, "tag": "play_music"},
    {"query": "stream track starboy by the weeknd", "expected_intent": "play_music", "is_action": True, "tag": "play_music"},
    {"query": "put on some ambient electronic soundscapes", "expected_intent": "play_music", "is_action": True, "tag": "play_music"},
    {"query": "play daft punk random access memories", "expected_intent": "play_music", "is_action": True, "tag": "play_music"},
    {"query": "stream relaxing nature sounds for focus", "expected_intent": "play_music", "is_action": True, "tag": "play_music"},

    # =========================================================================
    # 5. PLAY_MEDIA (Video, Anime, Local Movies)
    # =========================================================================
    {"query": "watch frieren episode 5", "expected_intent": "play_media", "is_action": True, "tag": "play_media"},
    {"query": "play steins gate episode 1", "expected_intent": "play_media", "is_action": True, "tag": "play_media"},
    {"query": "watch cyberpunk edgerunners season 1", "expected_intent": "play_media", "is_action": True, "tag": "play_media"},
    {"query": "play attack on titan season 4 episode 2", "expected_intent": "play_media", "is_action": True, "tag": "play_media"},
    {"query": "stream movie interstellar", "expected_intent": "play_media", "is_action": True, "tag": "play_media"},
    {"query": "open downloaded episode in mpv", "expected_intent": "play_media", "is_action": True, "tag": "play_media"},
    {"query": "watch local movie oppenheimer", "expected_intent": "play_media", "is_action": True, "tag": "play_media"},
    {"query": "play vinland saga ep 12", "expected_intent": "play_media", "is_action": True, "tag": "play_media"},
    {"query": "stream anime jujutsu kaisen season 2", "expected_intent": "play_media", "is_action": True, "tag": "play_media"},
    {"query": "watch downloaded film in mpv player", "expected_intent": "play_media", "is_action": True, "tag": "play_media"},

    # =========================================================================
    # 6. MPRIS_CONTROL (Transport & Playback Actions)
    # =========================================================================
    {"query": "pause music", "expected_intent": "mpris_control", "is_action": True, "tag": "mpris_control"},
    {"query": "resume playback", "expected_intent": "mpris_control", "is_action": True, "tag": "mpris_control"},
    {"query": "skip to next song", "expected_intent": "mpris_control", "is_action": True, "tag": "mpris_control"},
    {"query": "play previous track", "expected_intent": "mpris_control", "is_action": True, "tag": "mpris_control"},
    {"query": "stop audio playback", "expected_intent": "mpris_control", "is_action": True, "tag": "mpris_control"},
    {"query": "whats playing right now", "expected_intent": "mpris_control", "is_action": True, "tag": "mpris_control"},
    {"query": "what is this current song", "expected_intent": "mpris_control", "is_action": True, "tag": "mpris_control"},
    {"query": "can we turn this off please it is too loud", "expected_intent": "mpris_control", "is_action": True, "tag": "mpris_control"},
    {"query": "drop the volume a bit", "expected_intent": "mpris_control", "is_action": True, "tag": "mpris_control"},
    {"query": "mute playback", "expected_intent": "mpris_control", "is_action": True, "tag": "mpris_control"},
    {"query": "turn up the music slightly", "expected_intent": "mpris_control", "is_action": True, "tag": "mpris_control"},
    {"query": "shut off the sound", "expected_intent": "mpris_control", "is_action": True, "tag": "mpris_control"},
    {"query": "next track please", "expected_intent": "mpris_control", "is_action": True, "tag": "mpris_control"},
    {"query": "who sings this song playing currently", "expected_intent": "mpris_control", "is_action": True, "tag": "mpris_control"},
    {"query": "unpause the music", "expected_intent": "mpris_control", "is_action": True, "tag": "mpris_control"},

    # =========================================================================
    # 7. RUN_CMD (Terminal Executions)
    # =========================================================================
    {"query": "!git status -s", "expected_intent": "run_cmd", "is_action": True, "tag": "run_cmd"},
    {"query": "$df -h", "expected_intent": "run_cmd", "is_action": True, "tag": "run_cmd"},
    {"query": "!systemctl status mpd", "expected_intent": "run_cmd", "is_action": True, "tag": "run_cmd"},
    {"query": "run uptime in terminal", "expected_intent": "run_cmd", "is_action": True, "tag": "run_cmd"},
    {"query": "!cargo test --release", "expected_intent": "run_cmd", "is_action": True, "tag": "run_cmd"},
    {"query": "$hyprctl activewindow", "expected_intent": "run_cmd", "is_action": True, "tag": "run_cmd"},
    {"query": "!ip addr show", "expected_intent": "run_cmd", "is_action": True, "tag": "run_cmd"},
    {"query": "run free -m to check ram", "expected_intent": "run_cmd", "is_action": True, "tag": "run_cmd"},
    {"query": "!pkill waybar && waybar &", "expected_intent": "run_cmd", "is_action": True, "tag": "run_cmd"},

    # =========================================================================
    # 8. ACTIVE_WINDOW, DAILY_HORIZON, MINDSPACE (Read-only Desktop Context)
    # =========================================================================
    {"query": "what window is this", "expected_intent": "active_window", "is_action": False, "tag": "active_window"},
    {"query": "what is the currently focused application", "expected_intent": "active_window", "is_action": False, "tag": "active_window"},
    {"query": "which process has focus right now", "expected_intent": "active_window", "is_action": False, "tag": "active_window"},
    {"query": "current focused window title", "expected_intent": "active_window", "is_action": False, "tag": "active_window"},
    {"query": "what application am i currently looking at", "expected_intent": "active_window", "is_action": False, "tag": "active_window"},

    {"query": "daily horizon", "expected_intent": "daily_horizon", "is_action": False, "tag": "daily_horizon"},
    {"query": "give me my morning briefing", "expected_intent": "daily_horizon", "is_action": False, "tag": "daily_horizon"},
    {"query": "what is my daily horizon today", "expected_intent": "daily_horizon", "is_action": False, "tag": "daily_horizon"},
    {"query": "morning briefing overview", "expected_intent": "daily_horizon", "is_action": False, "tag": "daily_horizon"},
    {"query": "brief me for the day ahead", "expected_intent": "daily_horizon", "is_action": False, "tag": "daily_horizon"},

    {"query": "what did i copy to clipboard earlier", "expected_intent": "mindspace", "is_action": False, "tag": "mindspace"},
    {"query": "did i copy that bearer token from postman", "expected_intent": "mindspace", "is_action": False, "tag": "mindspace"},
    {"query": "find that url in my clipboard history", "expected_intent": "mindspace", "is_action": False, "tag": "mindspace"},
    {"query": "search clipboard for git commit hash", "expected_intent": "mindspace", "is_action": False, "tag": "mindspace"},
    {"query": "show recent clips from clipboard stash", "expected_intent": "mindspace", "is_action": False, "tag": "mindspace"},

    # =========================================================================
    # 9. CHAT & REFUSALS / CANCELLATIONS
    # =========================================================================
    {"query": "hello there", "expected_intent": "chat", "is_action": False, "tag": "chat"},
    {"query": "good morning minimo", "expected_intent": "chat", "is_action": False, "tag": "chat"},
    {"query": "how are you doing today", "expected_intent": "chat", "is_action": False, "tag": "chat"},
    {"query": "thanks a lot for your help", "expected_intent": "chat", "is_action": False, "tag": "chat"},
    {"query": "who created you", "expected_intent": "chat", "is_action": False, "tag": "chat"},
    {"query": "never mind cancel that task", "expected_intent": "chat", "is_action": False, "tag": "chat_cancellation"},
    {"query": "abort task creation please", "expected_intent": "chat", "is_action": False, "tag": "chat_cancellation"},
    {"query": "forget what i just said about creating a todo", "expected_intent": "chat", "is_action": False, "tag": "chat_cancellation"},
    {"query": "stop adding reminders please", "expected_intent": "chat", "is_action": False, "tag": "chat_cancellation"},
    {"query": "cancel that reminder request", "expected_intent": "chat", "is_action": False, "tag": "chat_cancellation"},
    {"query": "nevermind forget it", "expected_intent": "chat", "is_action": False, "tag": "chat_cancellation"},

    # =========================================================================
    # 10. RAG_KNOWLEDGE (Technical Inquiries & Notes Search)
    # =========================================================================
    {"query": "what is paxos consensus algorithm", "expected_intent": "rag_knowledge", "is_action": False, "tag": "rag_knowledge"},
    {"query": "explain raft leader election and log replication", "expected_intent": "rag_knowledge", "is_action": False, "tag": "rag_knowledge"},
    {"query": "how does b-tree indexing work in relational databases", "expected_intent": "rag_knowledge", "is_action": False, "tag": "rag_knowledge"},
    {"query": "derive navier stokes equation in cylindrical coordinates", "expected_intent": "rag_knowledge", "is_action": False, "tag": "rag_knowledge"},
    {"query": "what is the difference between process and thread in linux", "expected_intent": "rag_knowledge", "is_action": False, "tag": "rag_knowledge"},
    {"query": "explain cap theorem trade-offs in distributed systems", "expected_intent": "rag_knowledge", "is_action": False, "tag": "rag_knowledge"},
    {"query": "notes on aerothermodynamics hypersonic reentry", "expected_intent": "rag_knowledge", "is_action": False, "tag": "rag_knowledge"},
    {"query": "what did i write about rayleigh flow in my notes", "expected_intent": "rag_knowledge", "is_action": False, "tag": "rag_knowledge"},
    {"query": "how does rust borrow checker enforce memory safety at compile time", "expected_intent": "rag_knowledge", "is_action": False, "tag": "rag_knowledge"},
    {"query": "explain backpropagation gradient descent chain rule", "expected_intent": "rag_knowledge", "is_action": False, "tag": "rag_knowledge"},
    {"query": "what is the difference between epoll and select in unix socket programming", "expected_intent": "rag_knowledge", "is_action": False, "tag": "rag_knowledge"},
    {"query": "derive bernoulli principle from euler equations", "expected_intent": "rag_knowledge", "is_action": False, "tag": "rag_knowledge"},
    {"query": "how does virtual memory paging translate virtual addresses to physical", "expected_intent": "rag_knowledge", "is_action": False, "tag": "rag_knowledge"},
    {"query": "what is prandtl meyer expansion fan in supersonic aerodynamics", "expected_intent": "rag_knowledge", "is_action": False, "tag": "rag_knowledge"},
    {"query": "explain transformer multi head attention scaling factor square root d", "expected_intent": "rag_knowledge", "is_action": False, "tag": "rag_knowledge"}
]

def main():
    data_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../data"))
    os.makedirs(data_dir, exist_ok=True)

    # Shuffle with fixed seed for deterministic reproducibility
    random.seed(42)
    samples = list(FULL_DATASET)
    random.shuffle(samples)

    full_path = os.path.join(data_dir, "intent_benchmark_full.jsonl")
    with open(full_path, "w", encoding="utf-8") as f:
        for s in samples:
            f.write(json.dumps(s) + "\n")

    print(f"Generated {len(samples)} total curated queries in {full_path}")

    # Create 60% Train, 40% Test split (Zero Leakage!)
    split_idx = int(len(samples) * 0.60)
    train_samples = samples[:split_idx]
    test_samples = samples[split_idx:]

    train_path = os.path.join(data_dir, "intent_train.jsonl")
    with open(train_path, "w", encoding="utf-8") as f:
        for s in train_samples:
            f.write(json.dumps(s) + "\n")

    test_path = os.path.join(data_dir, "intent_test_heldout.jsonl")
    with open(test_path, "w", encoding="utf-8") as f:
        for s in test_samples:
            f.write(json.dumps(s) + "\n")

    print(f"  • Train Split   : {len(train_samples)} samples -> {train_path}")
    print(f"  • Test Split    : {len(test_samples)} samples (Completely Held-Out) -> {test_path}")

if __name__ == "__main__":
    main()
