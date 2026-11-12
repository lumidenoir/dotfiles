"""
Minimo Brain Suite - Smart Local Movies & Anime Finder
"""

import os
import re
from typing import List, Dict, Any
from .config import MOVIE_DIRS, VIDEO_EXTS

import difflib

def _fuzzy_token_in_text(token: str, text: str) -> bool:
    if token in text:
        return True
    if len(token) >= 4:
        for w in re.findall(r'[a-z0-9]+', text):
            if len(w) >= 4 and difflib.SequenceMatcher(None, token, w).ratio() >= 0.75:
                return True
    return False

def search_local_movies(query: str, limit: int = 5) -> List[Dict[str, Any]]:
    q_clean = query.lower().strip()
    ep_match = re.search(r'\b(?:ep|episode|e|part)\s*0*([0-9]+)\b|(?<![a-z])ep0*([0-9]+)\b', q_clean)
    target_ep = int(ep_match.group(1) or ep_match.group(2)) if ep_match else None

    season_match = re.search(r'\b(?:s|season)\s*0*([0-9]+)\b|([0-9]+)(?:st|nd|rd|th)\s+season', q_clean)
    target_season = int(season_match.group(1) or season_match.group(2)) if season_match else None

    clean_title_query = re.sub(r'\b(?:play|watch|stream|put on|the|movie|film|cinema|ep|episode|e|part|season|s)\s*0*[0-9]*\b', '', q_clean, flags=re.I)
    clean_title_query = re.sub(r'\s+', ' ', clean_title_query).strip()
    title_tokens = [t for t in re.split(r'[^a-z0-9]+', clean_title_query) if len(t) >= 2]

    matches = []
    seen = set()

    for m_dir in MOVIE_DIRS:
        if not os.path.isdir(m_dir):
            continue
        for root, dirs, files in os.walk(m_dir):
            dirs[:] = [d for d in dirs if not d.startswith('.')]
            if "recordings" in root.lower() and "movie" not in root.lower():
                continue
            for file in sorted(files):
                ext = os.path.splitext(file)[1].lower()
                if ext not in VIDEO_EXTS:
                    continue
                full_path = os.path.join(root, file)
                if full_path in seen:
                    continue

                folder_name = os.path.basename(root).lower()
                fn_lower = file.lower()
                combined_name = f"{folder_name} {fn_lower}"

                score = 0
                token_hits = sum(1 for t in title_tokens if _fuzzy_token_in_text(t, combined_name))
                if title_tokens:
                    if token_hits == len(title_tokens):
                        score += 50
                    elif token_hits > 0:
                        score += token_hits * 18
                    else:
                        continue
                else:
                    score += 5

                if target_season is not None:
                    if any(re.search(p, combined_name) for p in [rf'season\s*0*{target_season}\b', rf's0*{target_season}\b', rf'{target_season}(?:st|nd|rd|th)\s+season']):
                        score += 30

                if target_ep is not None:
                    ep_str = str(target_ep)
                    ep_patterns = [
                        rf'[-_\s]0*{ep_str}(?!\.[0-9])[-_\s]',
                        rf'\be0*{ep_str}\b',
                        rf'\bep0*{ep_str}\b',
                        rf'\[0*{ep_str}\]',
                        rf'episode\s*0*{ep_str}\b',
                        rf's\d+e0*{ep_str}\b',
                        rf'-\s*0*{ep_str}\s*\[',
                    ]
                    if any(re.search(p, fn_lower) for p in ep_patterns):
                        score += 120
                    elif any(re.search(p, combined_name) for p in ep_patterns):
                        score += 80
                    else:
                        score -= 20

                if score > 0:
                    seen.add(full_path)
                    base = os.path.splitext(file)[0]
                    clean_title = re.sub(r'[\.\[\]\(\)\-_]', ' ', base)
                    clean_title = re.sub(r'\s+', ' ', clean_title).strip()
                    badge_lbl = f"Ep {target_ep}" if (target_ep and score >= 100) else "Local Media"
                    matches.append({
                        "title": clean_title,
                        "raw_filename": file,
                        "filepath": full_path,
                        "score": score,
                        "badge": badge_lbl,
                    })

    matches.sort(key=lambda x: x['score'], reverse=True)
    return matches[:limit]

# =====================================================================
# Music & Audio Streaming Engine (Local MPD + YouTube MPV Fallback)
# =====================================================================

import subprocess

USER = os.environ.get('USER', 'krishna')

# Curated mapping of moods, listening contexts, and colloquial tags to MPD genres
MOOD_GENRE_MAP: Dict[str, List[str]] = {
    'chill': ['Chill-out', 'Trip Hop', 'Soul', 'R&B'],
    'relax': ['Chill-out', 'Trip Hop', 'Classical', 'Jazz'],
    'relaxing': ['Chill-out', 'Trip Hop', 'Classical', 'Jazz'],
    'calm': ['Chill-out', 'Classical', 'Jazz'],
    'study': ['Classical', 'Chill-out', 'Electronic'],
    'focus': ['Classical', 'Chill-out', 'Electronic'],
    'work': ['Classical', 'Chill-out', 'Electronic', 'Jazz'],
    'jazz': ['Jazz'],
    'classical': ['Classical'],
    'lofi': ['Chill-out', 'Trip Hop', 'Hip-Hop/Rap'],
    'hiphop': ['Hip-Hop/Rap', 'Rap/Hip Hop'],
    'hip-hop': ['Hip-Hop/Rap', 'Rap/Hip Hop'],
    'rap': ['Hip-Hop/Rap', 'Rap/Hip Hop'],
    'rock': ['Rock', 'Indie Rock', 'Metal'],
    'metal': ['Metal', 'Rock'],
    'indie': ['Alternative & Indie', 'Indie Rock', 'Alternatif et Indé'],
    'anime': ['Anime', 'J-Pop', 'Asian Music'],
    'jpop': ['J-Pop', 'Asian Music', 'Asian Music, Pop'],
    'kpop': ['K-Pop', 'Asian Music'],
    'electronic': ['Electronic', 'Électronique', 'Electro, Techno/House', 'Dance'],
    'techno': ['Electro, Techno/House', 'Electronic'],
    'synth': ['Electronic', 'Électronique', 'Electro, Techno/House'],
    'cyberpunk': ['Electronic', 'Électronique', 'Electro, Techno/House'],
    'dance': ['Dance', 'Electro, Techno/House'],
    'soul': ['Soul', 'R&B, Soul & Funk', 'R&B'],
    'rnb': ['R&B', 'R&B, Soul & Funk'],
    'pop': ['Pop', 'Asian Music, Pop', 'Pop, International Pop, Rock'],
}

def resolve_music_intent(query: str) -> Dict[str, Any]:
    """
    Intelligent Music Entity & Mood Resolver:
    1. Mood & Genre auto-playlist matching (e.g. 'play something chill', 'play jazz', 'focus music')
    2. Structured '<title> by <artist>' extraction (e.g. 'reaper by kelsey lu')
    3. Artist library aggregation (e.g. 'all songs by kelsey lu' -> 10 tracks)
    4. Multi-token non-stopword search across MPD tags
    5. Local filesystem fuzzy match in ~/Music
    """
    clean = re.sub(r'^(?:play\s+(?:some\s+|a\s+|the\s+|all\s+)?(?:songs?\s+|music\s+|tracks?\s+|playlist\s+)?(?:by\s+|from\s+)?|stream\s+|listen\s+to\s+|put\s+on\s+)', '', query, flags=re.I).strip()
    clean = re.sub(r'\s+(?:music|songs?|tracks?|playlist|mood)$', '', clean, flags=re.I).strip()
    q_lower = clean.lower()

    if not clean:
        return {'type': 'none', 'tracks': [], 'query': clean}

    # 1. Mood or Genre check (auto-playlist)
    for mood, genres in MOOD_GENRE_MAP.items():
        if re.search(rf'\b{mood}\b', q_lower):
            seen = set()
            hits = []
            for g in genres:
                res = subprocess.run(['mpc', 'search', 'genre', g], capture_output=True, text=True, timeout=2.0)
                for line in res.stdout.split('\n'):
                    l = line.strip()
                    if l and l not in seen:
                        seen.add(l)
                        hits.append(l)
            if hits:
                return {
                    'type': 'mood_playlist',
                    'mood': mood,
                    'genre': genres[0],
                    'tracks': hits,
                    'count': len(hits),
                    'query': clean
                }

    # 2. Check '<title> by <artist>' pattern (guard against 'songs by <artist>')
    m_by = re.match(r'^(?P<title>.+?)\s+by\s+(?P<artist>.+)$', query, re.I)
    if m_by:
        raw_title = re.sub(r'^(?:play\s+(?:the\s+|a\s+|some\s+|song\s+|track\s+)?|stream\s+|put\s+on\s+)', '', m_by.group('title'), flags=re.I).strip()
        raw_artist = m_by.group('artist').strip()
        if raw_title.lower() not in ('songs', 'tracks', 'all', 'music', 'playlist', 'everything'):
            res = subprocess.run(['mpc', 'search', 'title', raw_title, 'artist', raw_artist], capture_output=True, text=True, timeout=2.0)
            hits = [l.strip() for l in res.stdout.split('\n') if l.strip()]
            if hits:
                return {'type': 'track', 'title': raw_title, 'artist': raw_artist, 'tracks': hits, 'count': len(hits), 'query': clean}
            res = subprocess.run(['mpc', 'search', 'any', raw_title, 'any', raw_artist], capture_output=True, text=True, timeout=2.0)
            hits = [l.strip() for l in res.stdout.split('\n') if l.strip()]
            if hits:
                return {'type': 'track', 'title': raw_title, 'artist': raw_artist, 'tracks': hits, 'count': len(hits), 'query': clean}

    # 3. Check Artist matching (e.g. 'all songs by Kelsey Lu' or 'kelsey lu')
    res_artist = subprocess.run(['mpc', 'search', 'artist', clean], capture_output=True, text=True, timeout=2.0)
    artist_hits = [l.strip() for l in res_artist.stdout.split('\n') if l.strip()]
    if len(artist_hits) > 1:
        return {'type': 'artist_playlist', 'artist': clean, 'tracks': artist_hits, 'count': len(artist_hits), 'query': clean}
    elif len(artist_hits) == 1:
        return {'type': 'track', 'tracks': artist_hits, 'count': 1, 'query': clean}

    def _calc_conf(hit_list):
        if not hit_list or not tokens:
            return 0.0
        fn = os.path.basename(hit_list[0]).lower()
        matched = sum(1 for t in tokens if t in fn)
        return matched / len(tokens)

    # 4. Multi-token search across MPD tags (filtering conversational stopwords)
    stopwords = {'by', 'from', 'the', 'a', 'an', 'song', 'track', 'music', 'please', 'put', 'on', 'listen', 'to', 'play'}
    tokens = [t for t in re.split(r'[^a-zA-Z0-9]+', q_lower) if t and t not in stopwords]
    if len(tokens) >= 2:
        cmd = ['mpc', 'search']
        for t in tokens:
            cmd.extend(['any', t])
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=2.0)
        hits = [l.strip() for l in res.stdout.split('\n') if l.strip()]
        if hits:
            c = _calc_conf(hits)
            return {'type': 'track' if len(hits) == 1 else 'multi_track', 'tracks': hits, 'count': len(hits), 'query': clean, 'exact_match': (c >= 0.70), 'confidence': c, 'top_track': hits[0]}

    # 5. Single token search
    for t in tokens:
        res = subprocess.run(['mpc', 'search', 'any', t], capture_output=True, text=True, timeout=2.0)
        hits = [l.strip() for l in res.stdout.split('\n') if l.strip()]
        if hits:
            c = _calc_conf(hits)
            return {'type': 'track' if len(hits) == 1 else 'multi_track', 'tracks': hits, 'count': len(hits), 'query': clean, 'exact_match': (c >= 0.70), 'confidence': c, 'top_track': hits[0]}

    # 6. Fallback: Local Music directory filesystem scan
    music_dir = os.path.expanduser("~/Music")
    hits = []
    if os.path.isdir(music_dir):
        for root, _, files in os.walk(music_dir):
            for f in files:
                if f.lower().endswith(('.mp3', '.flac', '.m4a', '.ogg', '.wav', '.opus')):
                    fn_lower = f.lower()
                    if all(t in fn_lower for t in tokens if len(t) >= 3):
                        hits.append(os.path.join(root, f))
                        if len(hits) >= 10:
                            break
    if hits:
        c = _calc_conf(hits)
        return {'type': 'track' if len(hits) == 1 else 'multi_track', 'tracks': hits, 'count': len(hits), 'query': clean, 'exact_match': (c >= 0.70), 'confidence': c, 'top_track': hits[0]}

    return {'type': 'not_found', 'tracks': [], 'query': clean, 'exact_match': False, 'confidence': 0.0, 'top_track': None}

def search_mpd_library(query: str) -> List[str]:
    """Search local MPD music database for tracks matching query."""
    info = resolve_music_intent(query)
    return info.get("tracks", [])

def play_mpd_playlist(tracks: List[str], shuffle: bool = True) -> bool:
    """Queue a collection of tracks into an MPD auto-playlist with optional shuffle."""
    if not tracks:
        return False
    try:
        subprocess.run(["mpc", "clear"], capture_output=True, timeout=1.5)
        for t in tracks:
            subprocess.run(["mpc", "add", t], capture_output=True, timeout=1.0)
        if shuffle:
            subprocess.run(["mpc", "random", "on"], capture_output=True, timeout=1.0)
        subprocess.run(["mpc", "play", "1"], capture_output=True, timeout=1.5)
        return True
    except Exception:
        return False

def optimize_youtube_query(query: str, query_type: str = "track") -> str:
    """Optimizes query for high-fidelity YouTube audio streaming."""
    clean = re.sub(r'^(?:play\s+(?:some\s+|a\s+|the\s+)?(?:song\s+|music\s+|track\s+|playlist\s+)?|stream\s+|listen\s+to\s+|put\s+on\s+)', '', query, flags=re.I).strip()
    clean = re.sub(r'\s+(?:music|songs?|tracks?|playlist|mood)$', '', clean, flags=re.I).strip()
    q_lower = clean.lower()

    if any(m in q_lower for m in ('chill', 'lofi', 'relax', 'study', 'focus', 'ambient', 'calm', 'sleep')):
        return f"{clean} lofi chill beats live radio"
    elif any(g in q_lower for g in ('jazz', 'classical', 'synthwave', 'cyberpunk', 'electronic')):
        return f"{clean} mix official audio"
    return f"{clean} official audio"

def play_mpd_song(song_target: str) -> bool:
    """Queue and immediately play a song in local MPD."""
    try:
        subprocess.run(["mpc", "clear"], capture_output=True, timeout=1.0)
        subprocess.run(["mpc", "add", song_target], capture_output=True, text=True, timeout=2.0)
        subprocess.run(["mpc", "play"], capture_output=True, timeout=1.5)
        return True
    except Exception:
        return False

def stop_background_mpv():
    """Halt any background MPV YouTube audio streaming processes."""
    if os.path.exists("/tmp/minimo_yt_mpv.pid"):
        try:
            with open("/tmp/minimo_yt_mpv.pid", "r") as f:
                pid = int(f.read().strip())
            os.kill(pid, 9)
        except Exception:
            pass
        try:
            os.remove("/tmp/minimo_yt_mpv.pid")
        except Exception:
            pass
    subprocess.run(["pkill", "-u", USER, "-f", "mpv.*ytdl://ytsearch"], capture_output=True)
    subprocess.run(["pkill", "-u", USER, "-f", "mpv.*ytsearch1:"], capture_output=True)

def stop_all_audio():
    """Stop all desktop audio: MPD, background MPV YouTube streams, and TTS."""
    stop_background_mpv()
    subprocess.run(["mpc", "stop"], capture_output=True, timeout=1.5)
    subprocess.run(["playerctl", "-a", "pause"], capture_output=True, timeout=1.5)
    subprocess.run(["playerctl", "-a", "stop"], capture_output=True, timeout=1.5)
    subprocess.run(["/home/krishna/dotfiles/scripts/minimo_tts.py", "--stop"], capture_output=True, timeout=1.5)

def play_youtube_audio(query: str):
    """Play YouTube audio in background with tracking PID."""
    stop_background_mpv()
    proc = subprocess.Popen(
        ["mpv", "--no-video", f"ytdl://ytsearch1:{query}"],
        stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        start_new_session=True
    )
    try:
        with open("/tmp/minimo_yt_mpv.pid", "w") as f:
            f.write(str(proc.pid))
    except Exception:
        pass

def mpris_control(action_cmd: str) -> Dict[str, str]:
    """Execute playerctl command and return new status + metadata."""
    act_map = {
        "play-pause": ["play-pause"],
        "toggle": ["play-pause"],
        "play": ["play"],
        "pause": ["pause"],
        "next": ["next"],
        "skip": ["next"],
        "prev": ["previous"],
        "previous": ["previous"],
        "stop": ["stop"]
    }
    cmd_args = act_map.get(action_cmd.lower(), ["play-pause"])
    if action_cmd.lower() == "stop":
        stop_all_audio()
        return {"status": "Stopped", "track": "Playback stopped"}

    subprocess.run(["playerctl"] + cmd_args, capture_output=True, timeout=1.5)

    status = "Stopped"
    track = "No active player"
    try:
        s_proc = subprocess.run(["playerctl", "status"], capture_output=True, text=True, timeout=1.0)
        if s_proc.returncode == 0:
            status = s_proc.stdout.strip()
        t_proc = subprocess.run(["playerctl", "metadata", "--format", "{{artist}} - {{title}}"], capture_output=True, text=True, timeout=1.0)
        if t_proc.returncode == 0 and t_proc.stdout.strip():
            track = t_proc.stdout.strip()
    except Exception:
        pass
    return {"status": status, "track": track}
