#!/usr/bin/env python3
import sys
import os
import re
import urllib.request
from datetime import datetime, timezone, timedelta

ICS_URL = "https://f1.vidmar.net/calendar.ics"
CACHE_FILE = "/tmp/f1_calendar.ics"
LAST_ALERT_FILE = "/tmp/f1_last_alert"

def update_cache():
    # Only update cache if it doesn't exist or is older than 12 hours
    if os.path.exists(CACHE_FILE):
        mtime = os.path.getmtime(CACHE_FILE)
        if datetime.now().timestamp() - mtime < 43200:
            return
    try:
        urllib.request.urlretrieve(ICS_URL, CACHE_FILE)
    except Exception as e:
        # Fallback to existing cache if offline
        pass

def parse_ics():
    if not os.path.exists(CACHE_FILE):
        return []

    with open(CACHE_FILE, 'r', encoding='utf-8') as f:
        content = f.read()

    events = []
    # Match VEVENT blocks
    vevents = re.findall(r'BEGIN:VEVENT.*?END:VEVENT', content, re.DOTALL)

    for vevent in vevents:
        summary_match = re.search(r'SUMMARY:(.*?)(?:\r?\n)', vevent)
        dtstart_match = re.search(r'DTSTART:(.*?)(?:\r?\n)', vevent)
        location_match = re.search(r'LOCATION:(.*?)(?:\r?\n)', vevent)
        uid_match = re.search(r'UID:(.*?)(?:\r?\n)', vevent)

        if summary_match and dtstart_match and uid_match:
            summary = summary_match.group(1).replace('\\,', ',').strip()
            dtstart_raw = dtstart_match.group(1).strip()
            location = location_match.group(1).replace('\\,', ',').strip() if location_match else "TBD"
            uid = uid_match.group(1).strip()

            # We only care about sessions with timed start times (YYYYMMDDTHHMMSSZ)
            if 'T' in dtstart_raw and dtstart_raw.endswith('Z'):
                try:
                    # Parse UTC time
                    dt_utc = datetime.strptime(dtstart_raw, "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc)
                    events.append({
                        'uid': uid,
                        'summary': summary,
                        'start': dt_utc,
                        'location': location
                    })
                except Exception:
                    pass

    # Sort events by start time
    events.sort(key=lambda e: e['start'])
    return events

def main():
    update_cache()
    events = parse_ics()
    now = datetime.now(timezone.utc)

    if len(sys.argv) < 2:
        print("Usage: f1_checker.py [--next | --list | --alert | --four-weeks]")
        sys.exit(1)

    opt = sys.argv[1]

    if opt == "--next":
        # Find first event in the future
        for e in events:
            if e['start'] > now:
                # Format to local time
                local_dt = e['start'].astimezone(None)
                local_str = local_dt.strftime("%a %b %d at %H:%M")
                print(f"{e['summary']}|{local_str}|{e['location']}")
                return
        print("No upcoming events")

    elif opt == "--list":
        # Print next 4 future events
        count = 0
        for e in events:
            if e['start'] > now:
                local_dt = e['start'].astimezone(None)
                local_str = local_dt.strftime("%a %b %d at %H:%M")
                # Strip emoji prefix for clean text in list if desired, but let's keep them!
                print(f"{e['summary']}|{local_str}")
                count += 1
                if count >= 4:
                    break

    elif opt == "--four-weeks":
        # Print all events in the next 28 days (4 weeks)
        four_weeks_limit = now + timedelta(days=28)
        for e in events:
            if now <= e['start'] <= four_weeks_limit:
                local_dt = e['start'].astimezone(None)
                local_str = local_dt.strftime("%a %b %d at %H:%M")
                print(f"{e['summary']}|{local_str}|{e['location']}")

    elif opt == "--this-week-race":
        # Find the next event that is a "Race"
        for e in events:
            if e['start'] > now and "🏁 Race" in e['summary']:
                local_dt = e['start'].astimezone(None)
                local_str = local_dt.strftime("%a %b %d at %H:%M")
                print(f"{e['summary']}|{local_str}")
                return
        print("No upcoming race")

    elif opt == "--alert":
        # Check if an event starts in the next 15 minutes (900 seconds)
        for e in events:
            diff = (e['start'] - now).total_seconds()
            if 0 <= diff <= 900:
                # Check if we already alerted for this event
                last_alert_uid = ""
                if os.path.exists(LAST_ALERT_FILE):
                    with open(LAST_ALERT_FILE, 'r') as f:
                        last_alert_uid = f.read().strip()

                if last_alert_uid != e['uid']:
                    # Write to prevent duplicate alert
                    with open(LAST_ALERT_FILE, 'w') as f:
                        f.write(e['uid'])
                    
                    mins = int(diff / 60)
                    local_dt = e['start'].astimezone(None)
                    local_str = local_dt.strftime("%H:%M")
                    print(f"ALERT|{e['summary']}|{mins}|{local_str}")
                    return
        print("NO_ALERT")

if __name__ == "__main__":
    main()
