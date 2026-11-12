#!/usr/bin/env python3
import os
import re
import sys
import urllib.request
import urllib.parse
import ssl

CONFIG_FILE = os.path.expanduser("~/.config/iitk_gateway.conf")
DEFAULT_KEEPALIVE = "https://gateway.iitk.ac.in:1003/keepalive?060a0201053d4cd3"

# Create SSL context ignoring self-signed certificate errors
ssl_ctx = ssl.create_default_context()
ssl_ctx.check_hostname = False
ssl_ctx.verify_mode = ssl.CERT_NONE

def load_config():
    cfg = {
        "keepalive_url": DEFAULT_KEEPALIVE,
        "username": "",
        "password": "",
        "auto_login": "true"
    }
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, "r") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    cfg[k.strip().lower()] = v.strip().strip('"').strip("'")
    else:
        save_config(cfg)
    return cfg

def save_config(cfg):
    os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
    with open(CONFIG_FILE, "w") as f:
        f.write(f'KEEPALIVE_URL="{cfg.get("keepalive_url", DEFAULT_KEEPALIVE)}"\n')
        f.write(f'USERNAME="{cfg.get("username", "")}"\n')
        f.write(f'PASSWORD="{cfg.get("password", "")}"\n')
        f.write(f'AUTO_LOGIN="{cfg.get("auto_login", "true")}"\n')


def check_internet():
    """Checks internet reachability using multiple endpoints."""
    test_urls = [
        ("http://connectivitycheck.gstatic.com/generate_204", 204),
        ("http://cp.cloudflare.com/generate_204", 204)
    ]
    for url, expected_status in test_urls:
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=3) as resp:
                if resp.status == expected_status:
                    return True
        except Exception:
            continue

    return False

def is_wired_active():
    """Checks if a wired (ethernet) interface is currently connected."""
    try:
        # Check sysfs net interfaces for ethernet carrying link
        for dev in os.listdir("/sys/class/net"):
            if dev.startswith(("e", "eth", "en")):
                carrier_path = f"/sys/class/net/{dev}/carrier"
                if os.path.exists(carrier_path):
                    with open(carrier_path, "r") as f:
                        if f.read().strip() == "1":
                            return True
    except Exception:
        pass
    return False

def ping_keepalive(url):
    if not url:
        return None
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=5, context=ssl_ctx) as resp:
            html = resp.read().decode("utf-8", errors="ignore")
            m = re.search(r'location\.href\s*=\s*["\'](https://gateway\.iitk\.ac\.in:1003/keepalive\?[^"\']+)["\']', html)
            if m:
                return m.group(1)
            if "Keepalive" in html or "2400" in html:
                return url
    except Exception:
        pass
    return None

def do_login(username, password):
    if not username or not password:
        return None
    try:
        login_page_url = "https://gateway.iitk.ac.in:1003/login?"
        req = urllib.request.Request(login_page_url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=5, context=ssl_ctx) as resp:
            html = resp.read().decode("utf-8", errors="ignore")
        
        m_magic = re.search(r'name="magic"\s+value="([^"]+)"', html)
        magic = m_magic.group(1) if m_magic else ""

        post_data = urllib.parse.urlencode({
            "username": username,
            "password": password,
            "magic": magic,
            "4Tredir": login_page_url
        }).encode("utf-8")

        post_req = urllib.request.Request("https://gateway.iitk.ac.in:1003/", data=post_data, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(post_req, timeout=5, context=ssl_ctx) as resp:
            post_html = resp.read().decode("utf-8", errors="ignore")

        m_keep = re.search(r'location\.href\s*=\s*["\'](https://gateway\.iitk\.ac\.in:1003/keepalive\?[^"\']+)["\']', post_html)
        if m_keep:
            return m_keep.group(1)
    except Exception:
        pass
    return None

def main():
    cfg = load_config()
    current_keepalive = cfg.get("keepalive_url", DEFAULT_KEEPALIVE)

    # 1. Check if internet is already working
    if check_internet():
        print("Internet connection active.")
        sys.exit(0)

    # 2. Only attempt wired gateway authentication if a wired interface has link UP
    if not is_wired_active():
        print("No active wired interface detected. Skipping gateway login (wireless managed separately).")
        sys.exit(0)

    # 3. Test if existing keepalive url responds and refreshes session
    new_url = ping_keepalive(current_keepalive)
    if new_url:
        if new_url != current_keepalive:
            cfg["keepalive_url"] = new_url
            save_config(cfg)
        print(f"Keepalive successful: {new_url}")
        sys.exit(0)

    # 4. If disconnected on wired & auto_login is enabled, attempt gateway login
    if cfg.get("auto_login", "true").lower() == "true":
        username = cfg.get("username", "")
        password = cfg.get("password", "")
        if username and password:
            print("Attempting Gateway Login...")
            logged_keepalive = do_login(username, password)
            if logged_keepalive:
                cfg["keepalive_url"] = logged_keepalive
                save_config(cfg)
                print(f"Login successful! New keepalive: {logged_keepalive}")
                sys.exit(0)
            else:
                print("Login failed.")
        else:
            print("Credentials missing in ~/.config/iitk_gateway.conf")
    sys.exit(1)

if __name__ == "__main__":
    main()
