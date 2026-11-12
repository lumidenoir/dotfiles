#!/usr/bin/env python3
"""
scratchpad_manager.py - Persistent Scratchpad & Memo helper
"""

import os
import sys
import base64

SCRATCH_DIR = os.path.expanduser("~/.cache/quickshell")
SCRATCH_FILE = os.path.join(SCRATCH_DIR, "scratchpad.md")

def get_text():
    if os.path.isfile(SCRATCH_FILE):
        try:
            with open(SCRATCH_FILE, "r", encoding="utf-8") as f:
                return f.read()
        except Exception:
            return ""
    return ""

def set_text(content):
    os.makedirs(SCRATCH_DIR, exist_ok=True)
    try:
        with open(SCRATCH_FILE, "w", encoding="utf-8") as f:
            f.write(content)
        return True
    except Exception:
        return False

def main():
    if len(sys.argv) < 2 or sys.argv[1] == "--get":
        print(get_text(), end="")
        return
    if sys.argv[1] == "--set-b64":
        if len(sys.argv) > 2:
            try:
                content = base64.b64decode(sys.argv[2].encode("ascii")).decode("utf-8")
            except Exception:
                content = ""
        else:
            content = ""
        set_text(content)
        print("OK")
        return
    if sys.argv[1] == "--set":
        # Read content from stdin — safe fallback
        content = sys.stdin.read()
        set_text(content)
        print("OK")

if __name__ == "__main__":
    main()
