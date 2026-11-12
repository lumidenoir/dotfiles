"""
Minimo Brain Suite - High-Speed Local Maildir Reader & Executive Email Summarizer
Scans local Maildir (~/Mail) offline in < 15ms without cloud API latency.
Extracts clean senders, subjects, dates, and plain-text body snippets for LLM synthesis.
"""

import os
import re
import glob
import time
import email
from email.header import decode_header
from email.utils import parsedate_to_datetime
from datetime import datetime
from typing import Dict, Any, List, Optional, Tuple

MAILDIR_ROOT = os.path.expanduser("~/Mail")
IGNORED_FOLDERS = {"drafts", "trash", "sent", "junk", "all mail", "spam"}

def parse_header_str(header_val: Optional[str]) -> str:
    """Decode RFC 2047 encoded email headers to clean unicode."""
    if not header_val:
        return ""
    try:
        parts = decode_header(header_val)
        res = ""
        for str_or_bytes, encoding in parts:
            if isinstance(str_or_bytes, bytes):
                res += str_or_bytes.decode(encoding or 'utf-8', errors='replace')
            else:
                res += str(str_or_bytes)
        return " ".join(res.split())
    except Exception:
        return str(header_val)

def clean_sender_name(from_hdr: str) -> Tuple[str, str]:
    """Return (display_name, email_address)."""
    parsed = parse_header_str(from_hdr)
    addr = ""
    name = parsed
    m = re.search(r"<([^>]+)>", parsed)
    if m:
        addr = m.group(1).strip()
        name = parsed.split("<")[0].strip(' "\'')
    elif "@" in parsed:
        addr = parsed.strip(' "\'')
        name = addr.split("@")[0]
    
    name = re.sub(r'[\r\n\t]+', ' ', name).strip(' "\'')
    if not name:
        name = addr or "Unknown Sender"
    return name, addr

def extract_body_snippet(msg: email.message.Message, max_chars: int = 500) -> str:
    """Extract clean, stripped plain-text snippet from email message."""
    body = ""
    try:
        if msg.is_multipart():
            for part in msg.walk():
                ctype = part.get_content_type()
                cdisp = str(part.get('Content-Disposition') or "")
                if ctype == "text/plain" and "attachment" not in cdisp:
                    payload = part.get_payload(decode=True)
                    if payload:
                        charset = part.get_content_charset() or "utf-8"
                        body = payload.decode(charset, errors="replace")
                        break
        else:
            payload = msg.get_payload(decode=True)
            if payload:
                charset = msg.get_content_charset() or "utf-8"
                body = payload.decode(charset, errors="replace")
    except Exception:
        pass

    if not body:
        return ""

    # Clean up excess whitespace and common noise
    body = re.sub(r'\r\n|\r', '\n', body)
    body = re.sub(r'http[s]?://\S+', '[link]', body) # compress links
    body = re.sub(r'\n{3,}', '\n\n', body)
    lines = [l.strip() for l in body.splitlines() if l.strip()]
    clean_text = " ".join(lines)
    return clean_text[:max_chars].strip()

def get_msg_timestamp(msg: email.message.Message, filepath: str) -> float:
    """Extract timestamp from Date header, Received header, or fallback to file mtime."""
    d_str = msg.get("Date")
    if d_str:
        try:
            return parsedate_to_datetime(d_str).timestamp()
        except Exception:
            pass
            
    r_hdrs = msg.get_all("Received") or []
    for r in r_hdrs:
        m = re.search(r";\s*([A-Za-z]+,\s*\d+\s+[A-Za-z]+\s+\d{4}\s+\d+:\d+:\d+.*)$", r, re.MULTILINE)
        if m:
            try:
                return parsedate_to_datetime(m.group(1).strip()).timestamp()
            except Exception:
                pass
                
    try:
        return os.path.getmtime(filepath)
    except Exception:
        return 0.0

def format_relative_time(ts: float) -> str:
    """Format timestamp into natural relative time string."""
    now = time.time()
    diff = max(0, int(now - ts))
    if diff < 60:
        return "just now"
    elif diff < 3600:
        mins = diff // 60
        return f"{mins}m ago"
    elif diff < 86400:
        hrs = diff // 3600
        return f"{hrs}h ago"
    else:
        dt = datetime.fromtimestamp(ts)
        return dt.strftime("%b %d, %H:%M")

def parse_email_query_params(query: str) -> Dict[str, Any]:
    """
    Parse natural language query into filter parameters:
    - duration_seconds (e.g. 3600 for 'last hour', 7200 for 'last 2 hours')
    - since_timestamp (e.g. start of today for 'today', 'morning')
    - limit (e.g. 5, 10)
    """
    q = query.lower().strip()
    now = time.time()
    params: Dict[str, Any] = {
        "duration_seconds": None,
        "since_timestamp": None,
        "limit": 5,
        "query_desc": "recent emails"
    }

    # 1. Hour duration matches (e.g. "last 2 hours", "past 3 hrs", "last hour")
    m_hours = re.search(r'\b(?:last|past)\s+(\d+)\s*(?:hours?|hrs?)\b', q)
    if m_hours:
        hrs = int(m_hours.group(1))
        params["duration_seconds"] = hrs * 3600
        params["query_desc"] = f"emails from the last {hrs} hours"
        params["limit"] = 10
    elif re.search(r'\b(?:last|past)\s+hour\b', q) or "last 1 hour" in q:
        params["duration_seconds"] = 3600
        params["query_desc"] = "emails from the last hour"
        params["limit"] = 10

    # 2. Minute duration matches (e.g. "last 30 minutes", "past 45 mins")
    m_mins = re.search(r'\b(?:last|past)\s+(\d+)\s*(?:minutes?|mins?)\b', q)
    if m_mins:
        mins = int(m_mins.group(1))
        params["duration_seconds"] = mins * 60
        params["query_desc"] = f"emails from the last {mins} minutes"
        params["limit"] = 10

    # 3. Today / Morning / Afternoon
    today_start = time.mktime(time.localtime()[:3] + (0, 0, 0, 0, 0, -1))
    if any(k in q for k in ("today", "since morning", "this morning", "today's emails")):
        params["since_timestamp"] = today_start
        params["query_desc"] = "emails received today"
        params["limit"] = 10

    # 4. Explicit limit count (e.g. "last 5 emails", "top 10 emails", "show 3 emails")
    m_cnt = re.search(r'\b(?:last|top|show|first)\s+(\d+)\s+emails?\b', q)
    if m_cnt:
        cnt = min(20, max(1, int(m_cnt.group(1))))
        params["limit"] = cnt
        if not params["duration_seconds"] and not params["since_timestamp"]:
            params["query_desc"] = f"last {cnt} emails"

    # 5. Singular latest / newest email (e.g. "latest email", "summary of latest email", "last email")
    elif re.search(r'\b(?:latest|newest|most recent|last)\s+email\b', q) and not re.search(r'\b(?:last|past)\s+\d+', q):
        params["limit"] = 1
        params["query_desc"] = "latest email"

    return params

def fetch_recent_emails(
    duration_seconds: Optional[int] = None,
    since_timestamp: Optional[float] = None,
    limit: int = 5,
    max_scan: int = 80
) -> List[Dict[str, Any]]:
    """
    High-speed Maildir scanner.
    Sorts recent files by mtime, checks timestamps, and extracts clean email metadata.
    """
    pattern_cur = os.path.join(MAILDIR_ROOT, "*", "**", "cur", "*")
    pattern_new = os.path.join(MAILDIR_ROOT, "*", "**", "new", "*")
    
    files = glob.glob(pattern_cur, recursive=True) + glob.glob(pattern_new, recursive=True)
    if not files:
        return []

    file_tuples: List[Tuple[float, str]] = []
    for fp in files:
        if os.path.isfile(fp):
            path_parts = fp.lower().split(os.sep)
            if any(folder in path_parts for folder in IGNORED_FOLDERS):
                continue
            try:
                mtime = os.path.getmtime(fp)
                file_tuples.append((mtime, fp))
            except Exception:
                pass

    # Sort newest first
    file_tuples.sort(key=lambda x: x[0], reverse=True)

    now = time.time()
    min_cutoff = 0.0
    if duration_seconds is not None:
        min_cutoff = now - duration_seconds
    elif since_timestamp is not None:
        min_cutoff = since_timestamp

    results: List[Dict[str, Any]] = []
    for mtime, fp in file_tuples[:max_scan]:
        if len(results) >= limit:
            break
        try:
            with open(fp, "r", encoding="utf-8", errors="replace") as f:
                msg = email.message_from_file(f)
                ts = get_msg_timestamp(msg, fp)
                
                # Check cutoff if specified
                if min_cutoff > 0.0 and ts < min_cutoff:
                    continue

                subj = parse_header_str(msg.get("Subject", "(No Subject)"))
                from_raw = msg.get("From", "Unknown")
                sender_name, sender_addr = clean_sender_name(from_raw)
                snippet = extract_body_snippet(msg, max_chars=400)
                rel_time = format_relative_time(ts)

                results.append({
                    "id": os.path.basename(fp),
                    "sender": sender_name,
                    "sender_email": sender_addr,
                    "subject": subj,
                    "snippet": snippet,
                    "timestamp": ts,
                    "time_ago": rel_time,
                    "filepath": fp
                })
        except Exception:
            continue

    return results

def build_email_digest_prompt(emails: List[Dict[str, Any]], query_desc: str) -> str:
    """
    Constructs a clean, email-by-email executive summary prompt for the LLM.
    """
    if not emails:
        return f"No emails were found for {query_desc}."

    items_text = []
    for i, e in enumerate(emails, 1):
        items_text.append(
            f"[Email {i}]\n"
            f"Sender: {e['sender']} ({e['time_ago']})\n"
            f"Subject: {e['subject']}\n"
            f"Body snippet: {e['snippet'] or '(No text preview)'}"
        )

    if len(emails) == 1:
        e = emails[0]
        return (
            f"You are an executive inbox assistant. Summarize this single latest email ({query_desc}):\n\n"
            f"Sender: {e['sender']} ({e['time_ago']})\n"
            f"Subject: {e['subject']}\n"
            f"Body snippet: {e['snippet'] or '(No text preview)'}\n\n"
            "INSTRUCTIONS:\n"
            "- Provide a single clean bullet (•) formatted as:\n"
            f"  • **{e['sender']}** — *{e['subject']}* `({e['time_ago']})`\n"
            "    1 to 2 punchy sentences summarizing the core content, any deadlines, and next steps.\n"
            "- Highlight key dates or action items in **bold**.\n"
            "- Do not produce repetitive loops, sub-lists, or filler."
        )

    prompt = (
        f"You are an executive inbox assistant. Summarize these {len(emails)} emails ({query_desc}) email-by-email in order.\n\n"
        "FORMATTING INSTRUCTIONS:\n"
        "- Summarize EACH email individually under its own bullet item (•).\n"
        "- Format each bullet exactly as:\n"
        "  • **[Sender Name]** — *[Subject]* `([Time ago])`\n"
        "    1 to 2 punchy, insightful sentences summarizing the actual content, any key dates/deadlines, or required actions.\n"
        "- Do NOT write long sub-lists or itemized numbered lists. Keep each email strictly to 1-2 concise sentences.\n"
        "- Highlight important dates, times, and deadlines in **bold**.\n"
        f"- Ensure you complete the summary for ALL {len(emails)} emails completely.\n\n"
        "Emails to summarize:\n"
        + "\n\n".join(items_text)
    )
    return prompt

def get_maildir_sync_status() -> Dict[str, Any]:
    """
    Check the true freshness of the inbox by inspecting the newest received email timestamp
    and maildir directory modification times.
    """
    latest_mtime = 0.0
    try:
        recent = fetch_recent_emails(limit=1)
        if recent and len(recent) > 0:
            latest_mtime = float(recent[0].get("timestamp", 0.0))
    except Exception:
        pass

    if latest_mtime == 0.0:
        # Fallback to directory mtimes of INBOX/new or INBOX/cur
        for p in glob.glob(os.path.join(MAILDIR_ROOT, "*", "INBOX", "*")):
            if os.path.isdir(p):
                try:
                    latest_mtime = max(latest_mtime, os.path.getmtime(p))
                except Exception:
                    pass

    if latest_mtime == 0.0:
        latest_mtime = time.time()

    diff_sec = max(0, time.time() - latest_mtime)
    mins = int(diff_sec // 60)
    is_stale = mins > 45

    if mins < 1:
        rel = "just now"
    elif mins < 60:
        rel = f"{mins}m ago"
    else:
        hrs = mins // 60
        rel = f"{hrs}h ago"

    return {
        "last_sync_time": latest_mtime,
        "minutes_ago": mins,
        "relative_str": rel,
        "is_stale": is_stale
    }

