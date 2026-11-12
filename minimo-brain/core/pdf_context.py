"""
Minimo Brain Suite - Active Window & Hover PDF Context Resolver
Detects PDF documents currently open in the active or hovered window
(Zathura, Sioyek, Evince, Okular, Chrome, Firefox, etc.) by inspecting Hyprland
telemetry, cursor position, and process file descriptors (/proc/<pid>/fd).
"""

import os
import re
import json
import subprocess
from typing import Dict, Any, Optional, List

try:
    from .config import DOC_DIRS
except ImportError:
    from core.config import DOC_DIRS


KNOWN_PDF_CLASSES = (
    "zathura", "org.pwmt.zathura", "sioyek", "evince", "org.gnome.Evince",
    "okular", "org.kde.okular", "mupdf", "qpdfview", "xreader",
    "google-chrome", "chromium", "firefox", "brave-browser", "zen-alpha", "zen"
)


def get_hyprland_cursor_pos() -> Optional[tuple[int, int]]:
    """Retrieve current global cursor (x, y) coordinates from Hyprland."""
    try:
        raw = subprocess.check_output(["hyprctl", "cursorpos"], text=True, timeout=0.8).strip()
        parts = [p.strip() for p in raw.split(",")]
        if len(parts) == 2:
            return int(parts[0]), int(parts[1])
    except Exception:
        pass
    return None


def get_hyprland_clients() -> List[Dict[str, Any]]:
    """Retrieve all open Hyprland window clients with geometry and PIDs."""
    try:
        raw = subprocess.check_output(["hyprctl", "clients", "-j"], text=True, timeout=1.0)
        data = json.loads(raw)
        if isinstance(data, list):
            return data
    except Exception:
        pass
    return []


def get_window_under_cursor() -> Optional[Dict[str, Any]]:
    """Find the window geometry currently under the cursor (hovered)."""
    cursor = get_hyprland_cursor_pos()
    if not cursor:
        return None
    cx, cy = cursor

    clients = get_hyprland_clients()
    for win in clients:
        at = win.get("at", [0, 0])
        size = win.get("size", [0, 0])
        x, y = at[0], at[1]
        w, h = size[0], size[1]
        if x <= cx <= (x + w) and y <= cy <= (y + h):
            return win
    return None


def get_active_window_raw() -> Optional[Dict[str, Any]]:
    """Retrieve the currently focused active window from Hyprland."""
    try:
        raw = subprocess.check_output(["hyprctl", "activewindow", "-j"], text=True, timeout=0.8)
        win = json.loads(raw)
        if win and isinstance(win, dict) and win.get("class"):
            return win
    except Exception:
        pass
    return None


def extract_pdf_from_pid(pid: int) -> Optional[str]:
    """
    Given a process PID, inspect /proc/<pid>/fd/ to find open .pdf files.
    Falls back to inspecting /proc/<pid>/cmdline.
    """
    if not pid or pid <= 0:
        return None

    # 1. Inspect open file descriptors (/proc/<pid>/fd)
    fd_dir = f"/proc/{pid}/fd"
    try:
        if os.path.isdir(fd_dir):
            for entry in os.listdir(fd_dir):
                fd_path = os.path.join(fd_dir, entry)
                try:
                    target = os.readlink(fd_path)
                    if target.lower().endswith(".pdf") and os.path.isfile(target):
                        return target
                except (OSError, PermissionError):
                    continue
    except (OSError, PermissionError):
        pass

    # 2. Inspect process commandline arguments (/proc/<pid>/cmdline)
    cmdline_path = f"/proc/{pid}/cmdline"
    try:
        if os.path.isfile(cmdline_path):
            with open(cmdline_path, "rb") as f:
                args = f.read().split(b"\x00")
            for raw_arg in args:
                arg = raw_arg.decode("utf-8", errors="replace").strip()
                if arg.lower().endswith(".pdf"):
                    # Resolve relative path if needed
                    if os.path.isabs(arg) and os.path.isfile(arg):
                        return arg
                    # Try resolving against /proc/<pid>/cwd
                    cwd_link = f"/proc/{pid}/cwd"
                    if os.path.islink(cwd_link):
                        try:
                            cwd = os.readlink(cwd_link)
                            resolved = os.path.abspath(os.path.join(cwd, arg))
                            if os.path.isfile(resolved):
                                return resolved
                        except OSError:
                            pass
                    # Try home expansion
                    expanded = os.path.expanduser(arg)
                    if os.path.isfile(expanded):
                        return expanded
    except (OSError, PermissionError):
        pass

    return None


def find_pdf_by_filename(filename_query: str) -> Optional[str]:
    """Search known document directories for a matching PDF filename."""
    clean = os.path.basename(filename_query).strip()
    if not clean:
        return None
    for _, base_dir in DOC_DIRS:
        if not os.path.isdir(base_dir):
            continue
        candidate = os.path.join(base_dir, clean)
        if os.path.isfile(candidate):
            return candidate
        # Recursive check for exact filename
        for root, _, files in os.walk(base_dir):
            if clean in files:
                return os.path.join(root, clean)
    return None


def get_active_or_hovered_pdf() -> Optional[Dict[str, Any]]:
    """
    Locates the PDF file associated with:
    1. The currently focused active window,
    2. The window currently hovered by the mouse cursor,
    3. The most recently active open PDF viewer client in Hyprland, or
    4. Any active PDF viewer process (e.g. zathura, sioyek).

    Returns a dict with:
      - filepath: absolute path to PDF
      - filename: base name of PDF
      - title: sanitized document title
      - pid: process PID
      - window_class: application class
      - is_active: whether window currently has keyboard focus
    """
    candidates = []

    # Candidate 1: Active focused window
    active_win = get_active_window_raw()
    if active_win:
        candidates.append((active_win, True, active_win.get("pid")))

    # Candidate 2: Hovered window under cursor
    hovered_win = get_window_under_cursor()
    if hovered_win and (not active_win or hovered_win.get("address") != active_win.get("address")):
        candidates.append((hovered_win, False, hovered_win.get("pid")))

    # Candidate 3: Open PDF viewer client sorted by Hyprland focusHistoryID (most recently active first)
    try:
        clients = get_hyprland_clients()
        pdf_clients = []
        for c in clients:
            c_class = (c.get("class") or "").lower()
            c_init_class = (c.get("initialClass") or "").lower()
            c_title = c.get("title") or ""
            pid = c.get("pid")

            is_pdf_viewer = any(k in c_class or k in c_init_class for k in KNOWN_PDF_CLASSES)
            if is_pdf_viewer or c_title.lower().endswith(".pdf"):
                pdf_clients.append((c.get("focusHistoryID", 999), c, pid))

        if pdf_clients:
            pdf_clients.sort(key=lambda x: x[0])
            for _, c, pid in pdf_clients:
                candidates.append((c, False, pid))
    except Exception:
        pass

    # Check candidates in priority order
    for win, is_active, pid in candidates:
        win_class = (win.get("class") or win.get("initialClass") or "").lower()
        win_title = win.get("title") or ""

        pdf_path = None

        # Check PID fd / cmdline
        if pid:
            pdf_path = extract_pdf_from_pid(pid)

        # Fallback: inspect window title for .pdf pattern
        if not pdf_path and win_title:
            m = re.search(r'([A-Za-z0-9_\-\.\s]+\.pdf)\b', win_title, re.IGNORECASE)
            if m:
                pdf_path = find_pdf_by_filename(m.group(1).strip())

        if pdf_path and os.path.isfile(pdf_path):
            filename = os.path.basename(pdf_path)
            title = os.path.splitext(filename)[0].replace("_", " ").strip()
            return {
                "filepath": pdf_path,
                "filename": filename,
                "title": title,
                "pid": pid,
                "window_class": win.get("class", "Unknown"),
                "is_active": is_active,
                "window_title": win_title
            }

    # Candidate 4: Process inspection fallback (pgrep for zathura, sioyek)
    for proc_name in ("zathura", "sioyek", "evince"):
        try:
            p_out = subprocess.check_output(["pgrep", "-x", proc_name], text=True, timeout=0.5).strip()
            for p_str in p_out.split():
                if p_str.isdigit():
                    p_id = int(p_str)
                    pdf_path = extract_pdf_from_pid(p_id)
                    if pdf_path and os.path.isfile(pdf_path):
                        filename = os.path.basename(pdf_path)
                        title = os.path.splitext(filename)[0].replace("_", " ").strip()
                        return {
                            "filepath": pdf_path,
                            "filename": filename,
                            "title": title,
                            "pid": p_id,
                            "window_class": proc_name,
                            "is_active": False,
                            "window_title": filename
                        }
        except Exception:
            pass

    return None
