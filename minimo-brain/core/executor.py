"""
Minimo Brain Suite - Structured Desktop Action & Command Execution Engine
Captures stdout, stderr, return codes, and provides actionable status feedback.
"""

import os
import sys
import subprocess
from typing import Dict, Any, Optional
from .media import (
    play_mpd_song, play_youtube_audio, mpris_control, stop_all_audio
)
from .tasks import toggle_task, add_task

def run_command_safe(cmd: str, timeout: float = 8.0) -> Dict[str, Any]:
    """Execute shell command with timeout, capturing output, errors, and return code."""
    try:
        res = subprocess.run(
            cmd,
            shell=True,
            text=True,
            capture_output=True,
            timeout=timeout
        )
        return {
            "status": "ok" if res.returncode == 0 else "error",
            "returncode": res.returncode,
            "stdout": (res.stdout or "").strip(),
            "stderr": (res.stderr or "").strip(),
            "command": cmd
        }
    except subprocess.TimeoutExpired:
        return {
            "status": "timeout",
            "returncode": -1,
            "stdout": "",
            "stderr": f"Command timed out after {timeout} seconds.",
            "command": cmd
        }
    except Exception as e:
        return {
            "status": "error",
            "returncode": -1,
            "stdout": "",
            "stderr": str(e),
            "command": cmd
        }

def execute_desktop_action(action_type: str, payload: str) -> Dict[str, Any]:
    """
    Executes an action triggered from an action card or REST API.
    Returns structured result dict.
    """
    act = (action_type or "").strip().lower()
    p = (payload or "").strip()

    try:
        if act == "complete_task":
            success = toggle_task(p)
            subprocess.Popen(["notify-send", "-a", "Mind Pilot", "Task Completed", f"Toggled task #{p}"])
            return {"status": "ok" if success else "error", "message": f"Toggled task #{p}"}

        elif act == "add_task":
            created = add_task(p)
            subprocess.Popen(["notify-send", "-a", "Mind Pilot", "Task Added", f"Added: {p[:50]}"])
            return {"status": "ok", "task": created, "message": f"Added task: {p}"}

        elif act == "copy":
            proc = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE, start_new_session=True)
            proc.communicate(input=p.encode("utf-8"))
            subprocess.Popen(["notify-send", "-a", "Mind Pilot", "Copied to Clipboard", p[:60]])
            return {"status": "ok", "message": "Copied to clipboard"}

        elif act in ("run_cmd", "open_terminal"):
            subprocess.Popen(
                ["kitty", "-e", "bash", "-c", f"{p}; echo ''; read -p 'Press Enter to exit...'"],
                start_new_session=True
            )
            subprocess.Popen(["notify-send", "-a", "Mind Pilot", "Opened in Terminal", p[:60]])
            return {"status": "ok", "message": f"Spawned terminal for: {p}"}

        elif act in ("execute_cmd", "run_command_safe"):
            res = run_command_safe(p)
            out = res.get("stdout") or res.get("stderr") or "Command completed with no output."
            ret = res.get("returncode", 0)
            subprocess.Popen(["notify-send", "-a", "Mind Pilot", f"Exit {ret}", f"$ {p[:40]}: {out[:50]}"])
            return res

        elif act == "play_mpd":
            play_mpd_song(p)
            subprocess.Popen(["notify-send", "-a", "Mind Pilot", "Playing in MPD", os.path.basename(p)])
            return {"status": "ok", "message": f"Playing {os.path.basename(p)}"}

        elif act in ("play_youtube_music", "play_youtube"):
            play_youtube_audio(p)
            subprocess.Popen(["notify-send", "-a", "Mind Pilot", "Streaming YouTube Audio", p[:60]])
            return {"status": "ok", "message": f"Streaming audio: {p}"}

        elif act == "play_movie":
            subprocess.Popen(["mpv", "--fs", p], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            subprocess.Popen(["notify-send", "-a", "Mind Pilot", "Playing Video", os.path.basename(p)])
            return {"status": "ok", "message": f"Playing {os.path.basename(p)}"}

        elif act == "mpris":
            res = mpris_control(p)
            return {"status": "ok", "result": res}

        elif act in ("stop_music", "stop_audio", "stop_mpv"):
            stop_all_audio()
            subprocess.Popen(["notify-send", "-a", "Mind Pilot", "Audio Stopped", "Terminated all audio and MPV background streams."])
            return {"status": "ok", "message": "All audio stopped"}

        elif act == "speak":
            subprocess.Popen(
                ["/home/krishna/dotfiles/scripts/minimo_tts.py", "--speak", p],
                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                start_new_session=True
            )
            return {"status": "ok", "message": "TTS speaking"}

        elif act == "stop_speak":
            subprocess.Popen(
                ["/home/krishna/dotfiles/scripts/minimo_tts.py", "--stop"],
                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                start_new_session=True
            )
            return {"status": "ok", "message": "TTS stopped"}

        elif act in ("open_note", "open_doc", "open_book"):
            fp = p.split(":::")[0] if ":::" in p else p
            line = p.split(":::")[1] if ":::" in p else "1"
            if fp.endswith(".pdf"):
                subprocess.Popen(["zathura", f"--page={line}", fp], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            else:
                subprocess.Popen(["kitty", "-e", "nvim", f"+{line}", fp], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            return {"status": "ok", "message": f"Opened {os.path.basename(fp)}"}

        elif act in ("view_email", "mail_sync"):
            if act == "mail_sync":
                subprocess.Popen(["mbsync", "-a"], start_new_session=True)
                subprocess.Popen(["notify-send", "-a", "Mind Pilot", "Mail Sync", "Triggered background mbsync."])
                return {"status": "ok", "message": "Mail sync triggered"}
            else:
                subprocess.Popen(["kitty", "-e", "neomutt"], start_new_session=True)
                return {"status": "ok", "message": "Opened Neomutt"}

        return {"status": "error", "message": f"Unknown action type: {act}"}

    except Exception as e:
        return {"status": "error", "message": str(e)}
