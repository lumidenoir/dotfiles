#!/usr/bin/env python3
"""
tasks_manager.py - Todoist & Local Task Sync Manager with Alarms and Reminders Engine
Handles:
- Bi-directional cloud task sync with Todoist REST API v1/v2
- Offline local JSON task caching
- Standalone alarms management
- 5-minute advance warnings and exact-due reminders
- Snooze and dismissal state tracking
"""

import sys
import os
import re
import json
import time
import urllib.request
import urllib.parse
import urllib.error
from datetime import datetime

TOKEN_FILE = os.path.expanduser("~/.config/quickshell/todoist_token")
CACHE_DIR = os.path.expanduser("~/.cache/quickshell")
CACHE_FILE = os.path.join(CACHE_DIR, "tasks_cache.json")
LOCAL_FILE = os.path.join(CACHE_DIR, "local_tasks.json")
ALARMS_FILE = os.path.join(CACHE_DIR, "alarms.json")
STATE_FILE = os.path.join(CACHE_DIR, "reminded_state.json")

API_BASE = "https://api.todoist.com/api/v1"

def get_token():
    token = os.environ.get("TODOIST_API_TOKEN", "").strip()
    if token:
        return token
    if os.path.isfile(TOKEN_FILE):
        try:
            with open(TOKEN_FILE, "r") as f:
                return f.read().strip()
        except Exception:
            pass
    return None

def api_request(endpoint, method="GET", data=None):
    token = get_token()
    if not token:
        return None
    url = f"{API_BASE}{endpoint}"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    body = json.dumps(data).encode("utf-8") if data is not None else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    
    try:
        with urllib.request.urlopen(req, timeout=8) as response:
            status = response.status
            if status == 204:
                return True
            res_data = response.read().decode("utf-8")
            return json.loads(res_data) if res_data else True
    except Exception:
        return None

def parse_natural_task(raw_text):
    text = raw_text.strip()
    priority = 1
    
    # Priority tags: p1 -> 4 (high), p2 -> 3, p3 -> 2, p4 -> 1
    p_match = re.search(r"\b[pP]([1-4])\b", text)
    if p_match:
        p_val = int(p_match.group(1))
        priority = 5 - p_val
        text = re.sub(r"\b[pP][1-4]\b", "", text).strip()

    # NLP date trigger regex
    date_pattern = r"\b(?:(today|tomorrow|tonight|yesterday)|(?:next|this)\s+(?:week|month|monday|tuesday|wednesday|thursday|friday|saturday|sunday)|(?:on\s+)?(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)|every\s+\w+|in\s+\d+\s+(?:days?|weeks?|hours?)|at\s+\d+(?::\d+)?\s*(?:am|pm)?|\d{1,2}(?:st|nd|rd|th)?\s+(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*)\b(?:\s+at\s+\d+(?::\d+)?\s*(?:am|pm)?)?"
    
    match = re.search(date_pattern, text, re.IGNORECASE)
    due_string = None
    if match:
        due_string = match.group(0).strip()
        cleaned_content = (text[:match.start()] + text[match.end():]).strip()
        cleaned_content = re.sub(r"\s+", " ", cleaned_content)
        if cleaned_content:
            text = cleaned_content

    return text, due_string, priority

def parse_due_info(due_dict):
    """
    Extracts due string, unix timestamp, and whether it's a specific time or all-day.
    """
    if not due_dict or not isinstance(due_dict, dict):
        return "", None, False
    
    due_str = due_dict.get("string") or due_dict.get("date") or ""
    dt_str = due_dict.get("datetime") or due_dict.get("date")
    if not dt_str:
        return due_str, None, False
    
    is_timed = "T" in dt_str
    try:
        if is_timed:
            if dt_str.endswith("Z"):
                dt = datetime.fromisoformat(dt_str.replace("Z", "+00:00"))
            else:
                dt = datetime.fromisoformat(dt_str)
            return due_str, int(dt.timestamp()), True
        else:
            # All-day task: set to 09:00 local time
            dt = datetime.fromisoformat(dt_str).replace(hour=9, minute=0, second=0)
            return due_str, int(dt.timestamp()), False
    except Exception:
        return due_str, None, False

def load_local_tasks():
    os.makedirs(CACHE_DIR, exist_ok=True)
    if os.path.isfile(LOCAL_FILE):
        try:
            with open(LOCAL_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    default_tasks = [
        {"id": "loc_1", "content": "Welcome to Quick Tasks!", "is_completed": False, "priority": 1, "due": "Today", "due_timestamp": int(time.time()), "is_timed": False},
        {"id": "loc_2", "content": "Add your first daily goal", "is_completed": False, "priority": 2, "due": "", "due_timestamp": None, "is_timed": False}
    ]
    save_local_tasks(default_tasks)
    return default_tasks

def save_local_tasks(tasks):
    os.makedirs(CACHE_DIR, exist_ok=True)
    with open(LOCAL_FILE, "w") as f:
        json.dump(tasks, f, indent=2)

def save_cache(tasks, source="todoist"):
    os.makedirs(CACHE_DIR, exist_ok=True)
    with open(CACHE_FILE, "w") as f:
        json.dump({"source": source, "tasks": tasks}, f, indent=2)

def get_cached_tasks():
    if os.path.isfile(CACHE_FILE):
        try:
            with open(CACHE_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return {"source": "local", "tasks": load_local_tasks()}

def format_tasks():
    token = get_token()
    if token:
        # Fetch project names map
        projects_map = {}
        try:
            p_res = api_request("/projects")
            p_list = p_res if isinstance(p_res, list) else (p_res.get("results", []) if isinstance(p_res, dict) else [])
            for p in p_list:
                projects_map[p.get("id")] = p.get("name", "Inbox")
        except Exception:
            pass

        res = api_request("/tasks")
        raw_list = []
        if isinstance(res, list):
            raw_list = res
        elif isinstance(res, dict) and "results" in res:
            raw_list = res["results"]
            
        if raw_list:
            tasks = []
            for t in raw_list:
                if t.get("is_deleted") or t.get("checked"):
                    continue
                due_dict = t.get("due")
                due_str, due_ts, is_timed = parse_due_info(due_dict)
                labels = t.get("labels", [])
                proj_id = t.get("project_id")
                proj_name = projects_map.get(proj_id, "Inbox")
                
                # Category priority: first label (e.g. '@dotfiles', '@rust'), or project name (e.g. 'Inbox', 'Dev')
                category = ("@" + labels[0]) if labels else proj_name

                tasks.append({
                    "id": str(t.get("id", "")),
                    "content": t.get("content", ""),
                    "description": t.get("description", ""),
                    "is_completed": t.get("checked", False),
                    "priority": t.get("priority", 1),
                    "due": due_str,
                    "due_timestamp": due_ts,
                    "is_timed": is_timed,
                    "labels": labels,
                    "project_name": proj_name,
                    "category": category
                })
            save_cache(tasks, "todoist")
            return json.dumps({"source": "todoist", "tasks": tasks})
    
    # Fallback to cache or local
    return json.dumps(get_cached_tasks())

def add_task(raw_content, explicit_due=None, explicit_priority=None, description=None):
    nlp_content, nlp_due, nlp_priority = parse_natural_task(raw_content)
    content = nlp_content if (explicit_due is None and explicit_priority is None) else raw_content.strip()
    due_string = explicit_due if explicit_due is not None else nlp_due
    priority = explicit_priority if explicit_priority is not None else nlp_priority
    token = get_token()
    
    if token:
        payload = {"content": content, "priority": priority}
        if due_string:
            payload["due_string"] = due_string
        if description:
            payload["description"] = description
        res = api_request("/tasks", method="POST", data=payload)
        if res:
            return format_tasks()
    
    # Local fallback
    tasks = load_local_tasks()
    new_id = f"loc_{len(tasks) + 1}_{int(time.time() * 100) % 100000}"
    tasks.append({
        "id": new_id,
        "content": content,
        "description": description or "",
        "is_completed": False,
        "priority": priority,
        "due": due_string or "",
        "due_timestamp": None,
        "is_timed": False
    })
    save_local_tasks(tasks)
    save_cache(tasks, "local")
    return json.dumps({"source": "local", "tasks": tasks})

def toggle_task(task_id):
    token = get_token()
    if token and not task_id.startswith("loc_"):
        res = api_request(f"/tasks/{task_id}/close", method="POST")
        dismiss_alert("task_" + task_id)
        if res:
            return format_tasks()
    
    # Local fallback
    tasks = load_local_tasks()
    for t in tasks:
        if str(t.get("id")) == str(task_id):
            t["is_completed"] = not t.get("is_completed", False)
            break
    save_local_tasks(tasks)
    save_cache(tasks, "local")
    dismiss_alert("task_" + task_id)
    return json.dumps({"source": "local", "tasks": tasks})

def delete_task(task_id):
    token = get_token()
    if token and not task_id.startswith("loc_"):
        res = api_request(f"/tasks/{task_id}", method="DELETE")
        dismiss_alert("task_" + task_id)
        if res:
            return format_tasks()

    tasks = load_local_tasks()
    tasks = [t for t in tasks if str(t.get("id")) != str(task_id)]
    save_local_tasks(tasks)
    save_cache(tasks, "local")
    dismiss_alert("task_" + task_id)
    return json.dumps({"source": "local", "tasks": tasks})

# =========================================================================
# ⏰ ALARMS MANAGEMENT
# =========================================================================
def load_alarms():
    os.makedirs(CACHE_DIR, exist_ok=True)
    if os.path.isfile(ALARMS_FILE):
        try:
            with open(ALARMS_FILE, "r") as f:
                data = json.load(f)
                if isinstance(data, list):
                    return data
        except Exception:
            pass
    default_alarms = [
        {"id": "alarm_standup", "time": "10:00", "label": "Morning Standup", "enabled": False}
    ]
    save_alarms(default_alarms)
    return default_alarms

def save_alarms(alarms):
    os.makedirs(CACHE_DIR, exist_ok=True)
    with open(ALARMS_FILE, "w") as f:
        json.dump(alarms, f, indent=2)

def add_alarm(time_str, label="Alarm"):
    alarms = load_alarms()
    time_clean = time_str.strip().zfill(5) if len(time_str.strip()) == 4 else time_str.strip()
    new_alarm = {
        "id": f"alarm_{int(time.time() * 100) % 1000000}",
        "time": time_clean,
        "label": label.strip() if label.strip() else "Alarm",
        "enabled": True
    }
    alarms.append(new_alarm)
    save_alarms(alarms)
    return json.dumps({"alarms": alarms, "added": new_alarm})

def toggle_alarm(alarm_id):
    alarms = load_alarms()
    for a in alarms:
        if a.get("id") == alarm_id:
            a["enabled"] = not a.get("enabled", True)
            break
    save_alarms(alarms)
    return json.dumps({"alarms": alarms})

def delete_alarm(alarm_id):
    alarms = load_alarms()
    alarms = [a for a in alarms if a.get("id") != alarm_id]
    save_alarms(alarms)
    dismiss_alert(alarm_id)
    return json.dumps({"alarms": alarms})

# =========================================================================
# 🔔 REMINDED & SNOOZE STATE MANAGEMENT
# =========================================================================
def load_reminded_state():
    os.makedirs(CACHE_DIR, exist_ok=True)
    if os.path.isfile(STATE_FILE):
        try:
            with open(STATE_FILE, "r") as f:
                data = json.load(f)
                if isinstance(data, dict):
                    return data
        except Exception:
            pass
    return {}

def save_reminded_state(state):
    os.makedirs(CACHE_DIR, exist_ok=True)
    # Prune entries older than 3 days
    now = int(time.time())
    pruned = {}
    for k, v in state.items():
        updated_at = v.get("updated_at", now)
        if (now - updated_at) < (3 * 86400):
            pruned[k] = v
    with open(STATE_FILE, "w") as f:
        json.dump(pruned, f, indent=2)

def snooze_alert(alert_key, minutes=10):
    state = load_reminded_state()
    now = int(time.time())
    snooze_until = now + (int(minutes) * 60)
    item = state.setdefault(alert_key, {})
    item["snoozed_until"] = snooze_until
    item["dismissed"] = False
    item["updated_at"] = now
    save_reminded_state(state)
    return json.dumps({"status": "snoozed", "id": alert_key, "snoozed_until": snooze_until})

def dismiss_alert(alert_key):
    state = load_reminded_state()
    now = int(time.time())
    item = state.setdefault(alert_key, {})
    item["dismissed"] = True
    item["snoozed_until"] = 0
    item["updated_at"] = now
    save_reminded_state(state)
    return json.dumps({"status": "dismissed", "id": alert_key})

# =========================================================================
# 🔍 CHECK DUE ALERTS & REMINDERS
# =========================================================================
def check_due_alerts():
    now_dt = datetime.now()
    now = int(time.time())
    today_date = now_dt.strftime("%Y-%m-%d")
    current_time_str = now_dt.strftime("%H:%M")

    state = load_reminded_state()
    active_alerts = []

    # 1. Check Standalone Alarms
    alarms = load_alarms()
    for a in alarms:
        if not a.get("enabled"):
            continue
        a_id = a.get("id")
        a_time = a.get("time", "")
        a_state = state.setdefault(a_id, {})
        
        # Check snooze first
        snoozed_until = a_state.get("snoozed_until", 0)
        if snoozed_until > 0 and now >= snoozed_until and not a_state.get("dismissed"):
            a_state["snoozed_until"] = 0
            a_state["updated_at"] = now
            active_alerts.append({
                "id": a_id,
                "type": "alarm",
                "title": a.get("label", "Alarm"),
                "subtitle": "Snooze Finished",
                "is_warning": False,
                "is_snoozed": True,
                "is_alarm": True,
                "priority": 4,
                "timestamp": now
            })
            continue

        # Check regular daily alarm trigger
        if a_time == current_time_str:
            if a_state.get("last_fired_date") != today_date and not a_state.get("dismissed"):
                a_state["last_fired_date"] = today_date
                a_state["updated_at"] = now
                active_alerts.append({
                    "id": a_id,
                    "type": "alarm",
                    "title": a.get("label", "Alarm"),
                    "subtitle": f"Alarm • {a_time}",
                    "is_warning": False,
                    "is_snoozed": False,
                    "is_alarm": True,
                    "priority": 4,
                    "timestamp": now
                })

    # 2. Check Tasks (Todoist / Local)
    cached = get_cached_tasks()
    tasks = cached.get("tasks", []) if isinstance(cached, dict) else []
    
    for t in tasks:
        if t.get("is_completed"):
            continue
        t_id = "task_" + str(t.get("id"))
        due_ts = t.get("due_timestamp")
        is_timed = t.get("is_timed", False)

        if not due_ts or not is_timed:
            continue

        t_state = state.setdefault(t_id, {})

        # Check snooze
        snoozed_until = t_state.get("snoozed_until", 0)
        if snoozed_until > 0 and now >= snoozed_until and not t_state.get("dismissed"):
            t_state["snoozed_until"] = 0
            t_state["updated_at"] = now
            active_alerts.append({
                "id": t_id,
                "type": "task",
                "task_id": str(t.get("id")),
                "title": t.get("content", "Task Due"),
                "subtitle": "Snoozed Task Due",
                "is_warning": False,
                "is_snoozed": True,
                "is_alarm": False,
                "priority": t.get("priority", 1),
                "timestamp": now
            })
            continue

        if t_state.get("dismissed"):
            continue

        # 5-minute advance warning
        if (due_ts - 300) <= now < due_ts:
            if not t_state.get("warning_5m_fired"):
                t_state["warning_5m_fired"] = True
                t_state["updated_at"] = now
                active_alerts.append({
                    "id": t_id,
                    "type": "task",
                    "task_id": str(t.get("id")),
                    "title": t.get("content", "Upcoming Task"),
                    "subtitle": "Due in 5 mins",
                    "is_warning": True,
                    "is_snoozed": False,
                    "is_alarm": False,
                    "priority": t.get("priority", 1),
                    "timestamp": due_ts
                })

        # Exact due time alert (valid for up to 10 minutes past due so old backlog doesn't spam)
        elif due_ts <= now <= (due_ts + 600):
            if not t_state.get("due_fired"):
                t_state["due_fired"] = True
                t_state["updated_at"] = now
                active_alerts.append({
                    "id": t_id,
                    "type": "task",
                    "task_id": str(t.get("id")),
                    "title": t.get("content", "Task Due"),
                    "subtitle": f"Due now ({t.get('due', '')})",
                    "is_warning": False,
                    "is_snoozed": False,
                    "is_alarm": False,
                    "priority": t.get("priority", 1),
                    "timestamp": due_ts
                })

    save_reminded_state(state)
    return json.dumps({
        "alerts": active_alerts,
        "alarms": alarms,
        "count": len(active_alerts)
    })

def main():
    if len(sys.argv) < 2 or sys.argv[1] == "--get":
        print(format_tasks())
        return

    cmd = sys.argv[1]
    if cmd == "--add" and len(sys.argv) > 2:
        content = " ".join(sys.argv[2:])
        print(add_task(content))
    elif cmd == "--add-json" and len(sys.argv) > 2:
        try:
            data = json.loads(sys.argv[2])
            content = data.get("title") or data.get("content") or "New Task"
            due_str = data.get("due") or data.get("due_string")
            desc = data.get("description") or data.get("desc")
            p_val = data.get("priority")
            api_priority = None
            if p_val is not None:
                try:
                    p_int = int(p_val)
                    api_priority = 5 - p_int if 1 <= p_int <= 4 else p_int
                except Exception:
                    pass
            print(add_task(content, explicit_due=due_str, explicit_priority=api_priority, description=desc))
        except Exception as e:
            print(json.dumps({"error": str(e)}))
    elif cmd == "--toggle" and len(sys.argv) > 2:
        task_id = sys.argv[2]
        print(toggle_task(task_id))
    elif cmd == "--delete" and len(sys.argv) > 2:
        task_id = sys.argv[2]
        print(delete_task(task_id))
    elif cmd == "--check-due":
        print(check_due_alerts())
    elif cmd == "--snooze" and len(sys.argv) > 2:
        alert_id = sys.argv[2]
        mins = int(sys.argv[3]) if len(sys.argv) > 3 else 10
        print(snooze_alert(alert_id, mins))
    elif cmd == "--dismiss" and len(sys.argv) > 2:
        alert_id = sys.argv[2]
        print(dismiss_alert(alert_id))
    elif cmd == "--get-alarms":
        print(json.dumps(load_alarms()))
    elif cmd == "--add-alarm" and len(sys.argv) > 2:
        time_val = sys.argv[2]
        label = " ".join(sys.argv[3:]) if len(sys.argv) > 3 else "Alarm"
        print(add_alarm(time_val, label))
    elif cmd == "--toggle-alarm" and len(sys.argv) > 2:
        print(toggle_alarm(sys.argv[2]))
    elif cmd == "--delete-alarm" and len(sys.argv) > 2:
        print(delete_alarm(sys.argv[2]))
    else:
        print(format_tasks())

if __name__ == "__main__":
    main()
