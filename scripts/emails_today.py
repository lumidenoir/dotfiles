#!/usr/bin/env python3
import subprocess
import json
import sys

def main():
    try:
        res = subprocess.run(["mu", "find", "date:today..now", "-z", "-s", "date", "-o", "json"], capture_output=True, text=True)
        raw = json.loads(res.stdout) if res.returncode == 0 else []
        for item in raw:
            subj = item.get(":subject", "(No Subject)")
            from_list = item.get(":from", [])
            from_name = ""
            if from_list:
                from_name = from_list[0].get(":name", "")
                if not from_name:
                    from_name = from_list[0].get(":email", "")
                    if from_name and "@" in from_name:
                        from_name = from_name.split("@")[0]
            if not from_name:
                from_name = "Unknown"
            print(f"{from_name}|{subj}")
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)

if __name__ == "__main__":
    main()
