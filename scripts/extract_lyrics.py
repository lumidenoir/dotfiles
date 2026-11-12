#!/usr/bin/env python3
import os
import sys
import json
import re
import argparse
import subprocess
import tempfile
import hashlib
import urllib.request
import urllib.parse
import colorsys
import math
from pathlib import Path

try:
    from mutagen.flac import FLAC
    from mutagen.id3 import ID3
except ImportError:
    FLAC = None
    ID3 = None

CACHE_DIR = os.path.expanduser("~/.cache/audiophile_lyrics")
USER_AGENT = "AudiophilePlayer/2.0 (https://github.com/lumidenoir/dotfiles)"

def get_cache_key(artist, title, duration=0, file_path=""):
    key_str = f"{artist.lower().strip()}_{title.lower().strip()}_{int(float(duration or 0))}"
    if file_path:
        key_str += f"_{file_path}"
    return hashlib.md5(key_str.encode("utf-8")).hexdigest()

def load_cache(cache_key, file_path=None):
    os.makedirs(CACHE_DIR, exist_ok=True)
    key_path = os.path.join(CACHE_DIR, cache_key + ".json")
    if os.path.exists(key_path):
        try:
            # If local file exists, check if file was modified after cache
            if file_path and os.path.exists(file_path):
                if os.path.getmtime(key_path) < os.path.getmtime(file_path):
                    return None
            with open(key_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return None

def save_cache(cache_key, data):
    try:
        os.makedirs(CACHE_DIR, exist_ok=True)
        key_path = os.path.join(CACHE_DIR, cache_key + ".json")
        with open(key_path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
    except Exception:
        pass

def extract_colors_from_image_bytes(image_data):
    dominant = "#1a1a1e"
    accent = "#6366f1"
    try:
        with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
            tmp.write(image_data)
            tmp_path = tmp.name

        # Dominant average color
        res_dom = subprocess.run(
            ["magick", tmp_path, "-scale", "1x1!", "-format", "%[hex:u]", "info:"],
            capture_output=True, text=True, timeout=2
        )
        if res_dom.returncode == 0 and res_dom.stdout.strip():
            dominant = f"#{res_dom.stdout.strip()[:6]}"

        # Quantize image into 16 distinct colors and score by HSV vibrancy * area weight
        res_pal = subprocess.run(
            ["magick", tmp_path, "-resize", "64x64", "-colors", "16", "-format", "%c\n", "histogram:info:"],
            capture_output=True, text=True, timeout=2
        )
        if res_pal.returncode == 0 and res_pal.stdout:
            lines = res_pal.stdout.strip().split("\n")
            total_pixels = 0
            entries = []
            for line in lines:
                m = re.search(r"^\s*(\d+):.*#(?:[0-9a-fA-F]{2})?([0-9a-fA-F]{6})", line)
                if m:
                    count = int(m.group(1))
                    hex_c = f"#{m.group(2)}"
                    total_pixels += count
                    entries.append((count, hex_c))

            scored = []
            for count, c in entries:
                r = int(c[1:3], 16) / 255.0
                g = int(c[3:5], 16) / 255.0
                b = int(c[5:7], 16) / 255.0
                h, s, v = colorsys.rgb_to_hsv(r, g, b)
                area_ratio = count / max(1, total_pixels)
                area_weight = math.pow(area_ratio, 0.35)
                # Vibrancy Score: heavily rewards high saturation and good visibility
                vibrancy = (s ** 1.25) * (v ** 0.85)
                # Penalize near-black and washed-out white/grey
                if v < 0.16 or (v > 0.93 and s < 0.12):
                    vibrancy *= 0.05
                score = vibrancy * area_weight
                scored.append((score, c))

            scored.sort(key=lambda x: x[0], reverse=True)
            if scored and scored[0][0] > 0.005:
                accent = scored[0][1]
            elif entries:
                accent = entries[0][1]

        os.remove(tmp_path)
    except Exception:
        pass
    return dominant, accent

def extract_colors_from_url(art_url):
    if not art_url:
        return "#1a1a1e", "#6366f1"
    
    if art_url.startswith("file://"):
        local_path = urllib.parse.unquote(art_url[7:])
        if os.path.exists(local_path):
            try:
                with open(local_path, "rb") as f:
                    return extract_colors_from_image_bytes(f.read())
            except Exception:
                pass
    elif art_url.startswith("http://") or art_url.startswith("https://"):
        try:
            req = urllib.request.Request(art_url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=3) as resp:
                return extract_colors_from_image_bytes(resp.read())
        except Exception:
            pass
    elif os.path.exists(art_url):
        try:
            with open(art_url, "rb") as f:
                return extract_colors_from_image_bytes(f.read())
        except Exception:
            pass

    return "#1a1a1e", "#6366f1"

def parse_lrc(lrc_text):
    lyrics = []
    if not lrc_text:
        return lyrics

    pattern = re.compile(r'\[(\d+):(\d+(?:\.\d+)?)\](.*)')
    for line in lrc_text.splitlines():
        line = line.strip()
        if not line:
            continue
        if re.match(r'^\[[a-zA-Z]+:', line):
            continue

        match = pattern.search(line)
        if match:
            minutes = int(match.group(1))
            seconds = float(match.group(2))
            text = match.group(3).strip()
            time_sec = (minutes * 60) + seconds
            lyrics.append({"time": round(time_sec, 2), "text": text})
        elif "]" in line:
            pass
        else:
            lyrics.append({"time": -1, "text": line})

    synced_items = [item for item in lyrics if item["time"] >= 0]
    synced_items.sort(key=lambda x: x["time"])
    
    if synced_items:
        return synced_items
    return lyrics

def score_lrclib_candidate(item, target_duration=0, prefer_english=True):
    if not item or not isinstance(item, dict):
        return -1000
    synced = item.get("syncedLyrics")
    plain = item.get("plainLyrics")
    text = synced or plain or ""
    if not text.strip():
        return -1000

    score = 0
    if synced:
        score += 500
    elif plain:
        score += 100

    # Duration match
    if target_duration > 0 and item.get("duration"):
        diff = abs(item["duration"] - target_duration)
        if diff <= 2:
            score += 300
        elif diff <= 5:
            score += 200
        elif diff <= 10:
            score += 100
        else:
            score -= int(diff * 15)

    # Language / Latin Script preference
    if prefer_english and text:
        ascii_chars = sum(1 for c in text if ord(c) < 128)
        total_chars = len(text)
        if total_chars > 0:
            ratio = ascii_chars / total_chars
            if ratio > 0.80:
                score += 250
            elif ratio > 0.50:
                score += 80
            else:
                score -= 180

    return score

def clean_track_title(title):
    if not title:
        return ""
    cleaned = title
    # Strip common suffixes: (feat. ...), [feat. ...], - Single, - EP, (Remastered...)
    cleaned = re.sub(r'(?i)\s*[\(\[](feat|with|ft)\.?\s+[^\)\]]+[\)\]]', '', cleaned)
    cleaned = re.sub(r'(?i)\s*-\s*(single|ep|deluxe|remastered|bonus\s+track\s+version|anniversary\s+edition).*', '', cleaned)
    cleaned = re.sub(r'(?i)\s*[\(\[](remastered|live|acoustic|mono|stereo|bonus\s+track)[\)\]]', '', cleaned)
    return cleaned.strip()

def fetch_lrclib(artist, title, album="", duration=0):
    if not artist or not title:
        return None

    cleaned_title = clean_track_title(title)
    candidates = []

    # Step 1: Direct get query
    try:
        params = {"artist_name": artist, "track_name": title}
        if album:
            params["album_name"] = album
        if duration and duration > 0:
            params["duration"] = int(duration)

        url = f"https://lrclib.net/api/get?{urllib.parse.urlencode(params)}"
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=4) as resp:
            if resp.status == 200:
                data = json.loads(resp.read().decode("utf-8"))
                if data:
                    candidates.append(data)
    except Exception:
        pass

    # Step 1b: Direct get query with cleaned title
    if cleaned_title and cleaned_title != title:
        try:
            params = {"artist_name": artist, "track_name": cleaned_title}
            if duration and duration > 0:
                params["duration"] = int(duration)
            url = f"https://lrclib.net/api/get?{urllib.parse.urlencode(params)}"
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=3) as resp:
                if resp.status == 200:
                    data = json.loads(resp.read().decode("utf-8"))
                    if data:
                        candidates.append(data)
        except Exception:
            pass

    # Step 2: Search queries (original and cleaned)
    search_queries = [f"{artist} {title}".strip()]
    if cleaned_title and cleaned_title != title:
        search_queries.append(f"{artist} {cleaned_title}".strip())
    # Also primary artist if artist has commas/&
    primary_artist = re.split(r'[,&]|\bfeat\.?\b|\bft\.?\b', artist, flags=re.IGNORECASE)[0].strip()
    if primary_artist and primary_artist != artist:
        search_queries.append(f"{primary_artist} {cleaned_title or title}".strip())

    for sq in search_queries:
        try:
            url = f"https://lrclib.net/api/search?{urllib.parse.urlencode({'q': sq})}"
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=4) as resp:
                if resp.status == 200:
                    results = json.loads(resp.read().decode("utf-8"))
                    if isinstance(results, list):
                        candidates.extend(results)
                        if any(c.get("syncedLyrics") for c in results):
                            break
        except Exception:
            pass

    if not candidates:
        return None

    # Score candidates to prefer English and closest duration match
    scored = []
    for c in candidates:
        s = score_lrclib_candidate(c, target_duration=duration, prefer_english=True)
        scored.append((s, c))

    scored.sort(key=lambda x: x[0], reverse=True)
    best_item = scored[0][1] if scored and scored[0][0] > -500 else None

    if best_item:
        if best_item.get("syncedLyrics"):
            return {"lyrics": parse_lrc(best_item["syncedLyrics"]), "synced": True, "source": "lrclib_synced"}
        elif best_item.get("plainLyrics"):
            return {"lyrics": parse_lrc(best_item["plainLyrics"]), "synced": False, "source": "lrclib_plain"}

    return None

def fetch_online_artwork(artist, title):
    if not artist or not title:
        return ""
    try:
        query = f"{artist} {title}".strip()
        url = f"https://itunes.apple.com/search?term={urllib.parse.quote(query)}&entity=song&limit=1"
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=3) as resp:
            if resp.status == 200:
                data = json.loads(resp.read().decode("utf-8"))
                if data.get("results") and len(data["results"]) > 0:
                    art = data["results"][0].get("artworkUrl100", "")
                    if art:
                        return art.replace("100x100bb", "600x600bb")
    except Exception:
        pass
    return ""

def extract_from_local_file(file_path, cache_key):
    result = {"lyrics": [], "synced": False, "dominant_color": None, "accent_color": None, "art_url": ""}
    if not file_path or not os.path.exists(file_path):
        return result

    # 1. Check directory for cover.jpg / folder.jpg
    file_dir = os.path.dirname(file_path)
    for cover_name in ["cover.jpg", "cover.png", "folder.jpg", "folder.png", "front.jpg", "front.png"]:
        c_path = os.path.join(file_dir, cover_name)
        if os.path.exists(c_path):
            result["art_url"] = "file://" + c_path
            dom, acc = extract_colors_from_url(result["art_url"])
            result["dominant_color"] = dom
            result["accent_color"] = acc
            break

    # 2. Neighboring .lrc file
    lrc_path = os.path.splitext(file_path)[0] + ".lrc"
    if os.path.exists(lrc_path):
        try:
            with open(lrc_path, "r", encoding="utf-8", errors="ignore") as f:
                parsed = parse_lrc(f.read())
                if parsed:
                    result["lyrics"] = parsed
                    result["synced"] = any(l["time"] >= 0 for l in parsed)
                    result["source"] = "local_lrc"
        except Exception:
            pass

    # 3. Embedded FLAC / MP3 tags
    try:
        ext = os.path.splitext(file_path)[1].lower()
        if ext == ".flac" and FLAC:
            audio = FLAC(file_path)
            if not result["lyrics"]:
                for tag in ["LYRICS", "SYNCEDLYRICS", "UNSYNCEDLYRICS"]:
                    if tag in audio.tags:
                        parsed = parse_lrc(audio.tags[tag][0])
                        if parsed:
                            result["lyrics"] = parsed
                            result["synced"] = any(l["time"] >= 0 for l in parsed)
                            result["source"] = "embedded_flac"
                            break
            if audio.pictures:
                pic_data = audio.pictures[0].data
                art_save_path = os.path.join(CACHE_DIR, f"{cache_key}_art.jpg")
                try:
                    with open(art_save_path, "wb") as f_art:
                        f_art.write(pic_data)
                    result["art_url"] = "file://" + art_save_path
                except Exception:
                    pass
                dom, acc = extract_colors_from_image_bytes(pic_data)
                result["dominant_color"] = dom
                result["accent_color"] = acc

        elif ext in [".mp3", ".m4a"] and ID3:
            audio = ID3(file_path)
            if not result["lyrics"]:
                sylt = audio.getall("SYLT")
                if sylt:
                    parsed = []
                    for s in sylt:
                        for text, time_ms in s.text:
                            parsed.append({"time": round(time_ms / 1000.0, 2), "text": text.strip()})
                    if parsed:
                        result["lyrics"] = parsed
                        result["synced"] = True
                        result["source"] = "embedded_sylt"
                if not result["lyrics"]:
                    uslt = audio.getall("USLT")
                    if uslt:
                        parsed = parse_lrc(uslt[0].text)
                        if parsed:
                            result["lyrics"] = parsed
                            result["synced"] = any(l["time"] >= 0 for l in parsed)
                            result["source"] = "embedded_uslt"

            apic = audio.getall("APIC")
            if apic:
                pic_data = apic[0].data
                art_save_path = os.path.join(CACHE_DIR, f"{cache_key}_art.jpg")
                try:
                    with open(art_save_path, "wb") as f_art:
                        f_art.write(pic_data)
                    result["art_url"] = "file://" + art_save_path
                except Exception:
                    pass
                dom, acc = extract_colors_from_image_bytes(pic_data)
                result["dominant_color"] = dom
                result["accent_color"] = acc
    except Exception:
        pass

    return result

def extract_audio_specs(file_path, player=""):
    p_low = (player or "").lower()
    if not file_path or not os.path.exists(file_path):
        if "brave" in p_low or "chrome" in p_low or "firefox" in p_low or "browser" in p_low or "plasma" in p_low:
            return {
                "format": "WEB",
                "bit_depth": 0,
                "sample_rate": 0,
                "bitrate": 0,
                "lossless": False,
                "badge": "WEB AUDIO"
            }
        elif "cider" in p_low or "apple" in p_low:
            return {
                "format": "AAC",
                "bit_depth": 24,
                "sample_rate": 48000,
                "bitrate": 256,
                "lossless": True,
                "badge": "APPLE MUSIC"
            }
        return {
            "format": "",
            "bit_depth": 0,
            "sample_rate": 0,
            "bitrate": 0,
            "lossless": False,
            "badge": "HI-FI"
        }
    ext = os.path.splitext(file_path)[1].lstrip(".").upper()
    specs = {
        "format": ext,
        "bit_depth": 0,
        "sample_rate": 0,
        "bitrate": 0,
        "lossless": ext in ["FLAC", "ALAC", "WAV", "AIFF"],
        "badge": ext
    }

    try:
        if ext == "FLAC":
            from mutagen.flac import FLAC
            audio = FLAC(file_path)
        elif ext == "MP3":
            from mutagen.mp3 import MP3
            audio = MP3(file_path)
        elif ext in ["M4A", "AAC", "ALAC", "MP4"]:
            from mutagen.mp4 import MP4
            audio = MP4(file_path)
        elif ext in ["OGG", "OPUS"]:
            from mutagen.oggvorbis import OggVorbis
            audio = OggVorbis(file_path)
        else:
            audio = MutagenFile(file_path)

        if audio and hasattr(audio, "info") and audio.info:
            info = audio.info
            specs["sample_rate"] = int(getattr(info, "sample_rate", 0) or 0)
            specs["bit_depth"] = int(getattr(info, "bits_per_sample", 0) or 0)
            specs["bitrate"] = int(getattr(info, "bitrate", 0) or 0)
            if specs["bitrate"] > 1000:
                specs["bitrate"] = int(specs["bitrate"] / 1000)

            parts = [ext] if ext else []
            if specs["bit_depth"] > 0:
                parts.append(f"{specs['bit_depth']}-bit")
            if specs["sample_rate"] > 0:
                sr_khz = specs["sample_rate"] / 1000.0
                sr_str = f"{sr_khz:.1f}".rstrip("0").rstrip(".") + " kHz"
                parts.append(sr_str)
            elif specs["bitrate"] > 0:
                parts.append(f"{specs['bitrate']} kbps")

            if parts:
                specs["badge"] = " • ".join(parts)
    except Exception:
        pass

    return specs

def main():
    parser = argparse.ArgumentParser(description="Extract and synchronize lyrics with online LRCLIB fallback and caching.")
    parser.add_argument("--artist", default="", help="Track artist name")
    parser.add_argument("--title", default="", help="Track title")
    parser.add_argument("--album", default="", help="Track album name")
    parser.add_argument("--duration", type=float, default=0.0, help="Track duration in seconds")
    parser.add_argument("--file", default="", help="Path to local audio file")
    parser.add_argument("--art-url", default="", help="MPRIS artwork URL")
    parser.add_argument("--player", default="", help="Active media player name (e.g. mpd, brave, cider)")
    args = parser.parse_args()

    artist = args.artist.strip()
    title = args.title.strip()
    album = args.album.strip()
    duration = args.duration
    file_path = args.file.strip()
    art_url = args.art_url.strip()
    player = args.player.strip().lower()

    # Only try resolving from mpc if player is MPD or if artist/title match MPC current
    is_mpd_player = player in ["mpd", "mpdris2", "music player daemon"]
    if not file_path and is_mpd_player:
        try:
            mpc_out = subprocess.check_output(["mpc", "-f", "%file%|@|%title%|@|%artist%|@|%album%|@|%time%", "current"], text=True, timeout=2).strip()
            if mpc_out:
                parts = mpc_out.split("|@|")
                file_rel = parts[0].strip() if len(parts) > 0 else ""
                mpc_title = parts[1].strip() if len(parts) > 1 else ""
                mpc_artist = parts[2].strip() if len(parts) > 2 else ""
                if not title or title.lower() in mpc_title.lower() or mpc_title.lower() in title.lower():
                    if file_rel:
                        if file_rel.startswith("/"):
                            file_path = file_rel
                        else:
                            cand1 = os.path.join(os.path.expanduser("~/Music"), file_rel)
                            if os.path.exists(cand1):
                                file_path = cand1
                    if not title and mpc_title:
                        title = mpc_title
                    if not artist and mpc_artist:
                        artist = mpc_artist
                    if not album and len(parts) > 3:
                        album = parts[3].strip()
        except Exception:
            pass

    cache_key = get_cache_key(artist, title, duration, file_path)
    audio_specs = extract_audio_specs(file_path, player)

    # 1. Check local cache
    cached = load_cache(cache_key, file_path)
    if cached:
        cached["audio_specs"] = audio_specs
        if art_url and not cached.get("art_url"):
            cached["art_url"] = art_url
        if (cached.get("dominant_color") in ["#121218", "#121216", "#1a1a1e", None]) and cached.get("art_url"):
            dom, acc = extract_colors_from_url(cached["art_url"])
            if dom:
                cached["dominant_color"] = dom
            if acc:
                cached["accent_color"] = acc
            save_cache(cache_key, cached)
        print(json.dumps(cached))
        return

    output = {
        "title": title,
        "artist": artist,
        "album": album,
        "lyrics": [],
        "synced": False,
        "dominant_color": "#121218",
        "accent_color": "#6366f1",
        "art_url": art_url,
        "source": "none",
        "audio_specs": audio_specs
    }

    # 2. Extract from local file if available
    local_info = extract_from_local_file(file_path, cache_key)
    local_has_synced = bool(local_info["lyrics"] and local_info["synced"])
    local_unsynced_lyrics = local_info["lyrics"] if (local_info["lyrics"] and not local_info["synced"]) else []

    if local_has_synced:
        output["lyrics"] = local_info["lyrics"]
        output["synced"] = True
        output["source"] = local_info.get("source", "local_synced")
    
    if local_info.get("dominant_color"):
        output["dominant_color"] = local_info["dominant_color"]
    if local_info.get("accent_color"):
        output["accent_color"] = local_info["accent_color"]
    if local_info.get("art_url"):
        output["art_url"] = local_info["art_url"]

    # 3. If local file has NO SYNCED lyrics, try fetching synced lyrics from LRCLIB
    if not output["synced"] and (artist or title):
        online_info = fetch_lrclib(artist, title, album, duration)
        if online_info and online_info.get("lyrics"):
            if online_info.get("synced"):
                # Online has synced lyrics! Use them
                output["lyrics"] = online_info["lyrics"]
                output["synced"] = True
                output["source"] = online_info["source"]
            elif not local_unsynced_lyrics:
                # Online only has unsynced, and we didn't have local metadata unsynced
                output["lyrics"] = online_info["lyrics"]
                output["synced"] = False
                output["source"] = online_info["source"]

    # If online did not provide synced lyrics, but we had local metadata unsynced, use local metadata!
    if not output["lyrics"] and local_unsynced_lyrics:
        output["lyrics"] = local_unsynced_lyrics
        output["synced"] = False
        output["source"] = local_info.get("source", "local_unsynced")

    # 4. If no art url found yet, query iTunes search
    if not output["art_url"] and (artist or title):
        online_art = fetch_online_artwork(artist, title)
        if online_art:
            output["art_url"] = online_art
            dom, acc = extract_colors_from_url(online_art)
            output["dominant_color"] = dom
            output["accent_color"] = acc

    # 5. Extract colors from art_url if not already extracted
    if output["dominant_color"] in ["#121218", "#121216", "#1a1a1e", None] and output["art_url"]:
        dom, acc = extract_colors_from_url(output["art_url"])
        if dom:
            output["dominant_color"] = dom
        if acc:
            output["accent_color"] = acc

    # 6. Cache result and print
    save_cache(cache_key, output)
    print(json.dumps(output))

if __name__ == "__main__":
    main()