#!/usr/bin/env python3
import subprocess
import json
import sys
import os
import glob
import email
import time
import re
from email.header import decode_header
from email.utils import parsedate_to_datetime

def parse_header_str(header_val):
    if not header_val:
        return ""
    parts = decode_header(header_val)
    res = ""
    for str_or_bytes, encoding in parts:
        if isinstance(str_or_bytes, bytes):
            res += str_or_bytes.decode(encoding or 'utf-8', errors='replace')
        else:
            res += str(str_or_bytes)
    return res

def get_msg_timestamp(msg, filepath):
    # 1. Try standard Date header
    d_str = msg.get("Date")
    if d_str:
        try:
            return parsedate_to_datetime(d_str).timestamp()
        except Exception:
            pass
    # 2. Try Received header fallback (e.g. for Pingala system notification emails)
    r_hdrs = msg.get_all("Received") or []
    for r in r_hdrs:
        m = re.search(r";\s*([A-Za-z]+,\s*\d+\s+[A-Za-z]+\s+\d{4}\s+\d+:\d+:\d+.*)$", r, re.MULTILINE)
        if m:
            try:
                return parsedate_to_datetime(m.group(1).strip()).timestamp()
            except Exception:
                pass
    # 3. Fallback to file mtime
    try:
        return os.path.getmtime(filepath)
    except Exception:
        return 0

def get_maildir_emails():
    emails = []
    pattern = os.path.expanduser("~/Mail/*/**/cur/*")
    files = glob.glob(pattern, recursive=True) + glob.glob(os.path.expanduser("~/Mail/*/**/new/*"), recursive=True)

    file_tuples = []
    ignored_folders = {"drafts", "trash", "sent", "junk", "all mail", "spam"}
    for fp in files:
        if os.path.isfile(fp):
            path_parts = fp.lower().split(os.sep)
            if any(folder in path_parts for folder in ignored_folders):
                continue
            try:
                mtime = os.path.getmtime(fp)
                file_tuples.append((mtime, fp))
            except Exception:
                pass
    file_tuples.sort(key=lambda x: x[0], reverse=True)

    now = time.time()
    today_start = time.mktime(time.localtime()[:3] + (0, 0, 0, 0, 0, -1))
    hour_ago = now - 3600
    check_window = now - 2 * 86400

    today_count = 0
    hour_count = 0
    processed_count = 0

    for mtime, fp in file_tuples:
        if mtime < check_window:
            break
        if processed_count >= 150:
            break
        try:
            with open(fp, 'r', encoding='utf-8', errors='replace') as f:
                msg = email.message_from_file(f)
                ts = get_msg_timestamp(msg, fp)
                processed_count += 1
                if ts >= today_start:
                    today_count += 1
                if ts >= hour_ago:
                    hour_count += 1
        except Exception:
            pass

    for mtime, fp in file_tuples[:40]:
        if len(emails) >= 20:
            break
        try:
            with open(fp, 'r', encoding='utf-8', errors='replace') as f:
                msg = email.message_from_file(f)
                subj = " ".join(parse_header_str(msg.get('Subject', '(No Subject)')).split())
                from_hdr = parse_header_str(msg.get('From', 'Unknown'))
                if '<' in from_hdr:
                    from_name = from_hdr.split('<')[0].strip(' "\'')
                else:
                    from_name = from_hdr.split('@')[0].strip(' "\'')
                if not from_name:
                    from_name = "Unknown"
                emails.append({"from": from_name, "subject": subj})
        except Exception:
            continue

    return today_count, hour_count, emails

def main():
    json_mode = "--json" in sys.argv
    today_count, hour_count, found_emails = get_maildir_emails()

    xapian_dir = os.path.expanduser("~/.cache/mu/xapian")
    last_sync_str = ""
    if os.path.exists(xapian_dir):
        try:
            sync_files = [os.path.join(xapian_dir, f) for f in os.listdir(xapian_dir)]
            sync_mtime = max(os.path.getmtime(f) for f in sync_files) if sync_files else os.path.getmtime(xapian_dir)
            last_sync_str = time.strftime("%I:%M %p", time.localtime(sync_mtime)).lstrip('0')
        except Exception:
            pass

    if json_mode:
        print(json.dumps({
            "today_count": today_count,
            "hour_count": hour_count,
            "latest": found_emails,
            "last_sync": last_sync_str
        }))
    else:
        for item in found_emails:
            print(f"{item['from']}|{item['subject']}")

if __name__ == "__main__":
    main()
