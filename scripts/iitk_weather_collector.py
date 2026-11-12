#!/usr/bin/env python3
import json
import time
import urllib.request
import urllib.error
from datetime import datetime

IITK_URL = "https://fog.iitk.ac.in/fog-prediction/apis/sensordata3.php"
CACHE_FILE = "/tmp/iitk_weather_cache.json"

def fetch_open_meteo():
    url = (
        "https://api.open-meteo.com/v1/forecast?latitude=26.5123&longitude=80.2329"
        "&current=temperature_2m,apparent_temperature,precipitation,relative_humidity_2m,"
        "wind_speed_10m,wind_direction_10m,surface_pressure,weather_code,visibility,dew_point_2m"
        "&hourly=temperature_2m,precipitation_probability,weather_code"
        "&daily=temperature_2m_max,temperature_2m_min,sunrise,sunset&timezone=auto"
    )
    req = urllib.request.Request(url, headers={"User-Agent": "IITK-Weather-HUD/1.0"})
    with urllib.request.urlopen(req, timeout=8) as resp:
        return json.loads(resp.read().decode("utf-8"))

def fetch_iitk_fog_sensor():
    url = f"{IITK_URL}?select=4&station=IIT%20Kanpur&interval=1"
    req = urllib.request.Request(url, headers={"User-Agent": "IITK-Weather-HUD/1.0"})
    with urllib.request.urlopen(req, timeout=5) as resp:
        content = resp.read().decode("utf-8", errors="ignore").strip()
        if not content:
            return None
        # Format can be semicolon separated: metadata; [json]
        if ";" in content:
            parts = content.split(";")
            if len(parts) >= 2 and parts[1].strip():
                return json.loads(parts[1].strip())
        return json.loads(content)

def get_weather_desc(code):
    codes = {
        0: ("CLEAR SKY", "󰖙", "#ffd86b"),
        1: ("MAINLY CLEAR", "󰖕", "#adadff"),
        2: ("PARTLY CLOUDY", "󰖕", "#adadff"),
        3: ("OVERCAST", "󰖐", "#94a3b8"),
        45: ("FOGGY", "󰖑", "#84afdb"),
        48: ("DEPOSITED RIME FOG", "󰖑", "#84afdb"),
        51: ("LIGHT DRIZZLE", "󰖗", "#6b95ff"),
        53: ("MODERATE DRIZZLE", "󰖗", "#6b95ff"),
        55: ("DENSE DRIZZLE", "󰖗", "#6b95ff"),
        61: ("SLIGHT RAIN", "󰖖", "#6b95ff"),
        63: ("MODERATE RAIN", "󰖖", "#6b95ff"),
        65: ("HEAVY RAIN", "󰖖", "#6b95ff"),
        71: ("LIGHT SNOW", "", "#e3e6fc"),
        80: ("RAIN SHOWERS", "󰖗", "#6b95ff"),
        95: ("THUNDERSTORM", "󰖓", "#ffeb57")
    }
    return codes.get(code, ("FAIR", "󰖐", "#cbd5e1"))

def collect_weather():
    out = {
        "station": "IIT KANPUR GROUND AWS",
        "station_type": "FOG LAB // AEROSOL & METEOROLOGY",
        "coords": "26.5123°N, 80.2339°E",
        "temp": 28.0,
        "feels_like": 29.0,
        "humidity": 45,
        "pressure": 1014.0,
        "wind_speed": 6.5,
        "wind_dir": 120.0,
        "visibility": 4500,
        "condition": "CLEAR",
        "icon": "󰖙",
        "color": "#ffd86b",
        "dew_point": 14.2,
        "t_min": 18.0,
        "t_max": 31.0,
        "hourly_spark": [22, 21, 20, 22, 26, 29, 31, 30, 27, 24],
        "is_ground_live": False,
        "timestamp": datetime.now().strftime("%H:%M:%S")
    }

    # 1. Fetch Primary Open-Meteo Data
    om = None
    try:
        om = fetch_open_meteo()
        if om and "current" in om:
            c = om["current"]
            out["temp"] = round(float(c.get("temperature_2m", 28.0)), 1)
            out["feels_like"] = round(float(c.get("apparent_temperature", 29.0)), 1)
            out["humidity"] = int(c.get("relative_humidity_2m", 45))
            out["pressure"] = round(float(c.get("surface_pressure", 1014.0)), 1)
            out["wind_speed"] = round(float(c.get("wind_speed_10m", 6.5)), 1)
            out["wind_dir"] = round(float(c.get("wind_direction_10m", 120.0)), 1)
            out["visibility"] = int(c.get("visibility", 5000))
            out["dew_point"] = round(float(c.get("dew_point_2m", 14.0)), 1)
            
            w_code = int(c.get("weather_code", 0))
            desc, icon, col = get_weather_desc(w_code)
            out["condition"] = desc
            out["icon"] = icon
            out["color"] = col

            if "daily" in om:
                d = om["daily"]
                if d.get("temperature_2m_min"):
                    out["t_min"] = round(float(d["temperature_2m_min"][0]), 1)
                if d.get("temperature_2m_max"):
                    out["t_max"] = round(float(d["temperature_2m_max"][0]), 1)

            if "hourly" in om and om["hourly"].get("temperature_2m"):
                # Take current 10 hours
                out["hourly_spark"] = [round(t) for t in om["hourly"]["temperature_2m"][:10]]
    except Exception:
        pass

    # 2. Attempt IITK Fog Sensor Override (Ground truth on campus)
    try:
        raw_iitk = fetch_iitk_fog_sensor()
        if raw_iitk and isinstance(raw_iitk, list) and len(raw_iitk) > 0:
            latest = raw_iitk[-1]
            if isinstance(latest, list) and len(latest) >= 11:
                # Based on weather_api.dart:
                # entry[2] = temp1, entry[3] = temp2
                # entry[5] = hum1, entry[6] = hum2
                # entry[7] = windSpeed (m/s * 3.6 -> km/h)
                # entry[8] = windDir (+180 deg)
                # entry[10] = pressure
                t1 = latest[2]
                t2 = latest[3]
                if t1 is not None and t2 is not None:
                    out["temp"] = round((float(t1) + float(t2)) / 2.0, 1)
                    out["is_ground_live"] = True
                
                h1 = latest[5]
                h2 = latest[6]
                if h1 is not None and h2 is not None:
                    out["humidity"] = round((float(h1) + float(h2)) / 2.0)

                if latest[7] is not None:
                    out["wind_speed"] = round(float(latest[7]) * 3.6, 1)

                if latest[8] is not None:
                    out["wind_dir"] = round((float(latest[8]) + 180.0) % 360.0, 1)

                if latest[10] is not None:
                    out["pressure"] = round(float(latest[10]), 1)
    except Exception:
        pass

    # Save cache
    try:
        with open(CACHE_FILE, "w") as f:
            json.dump(out, f, indent=2)
    except Exception:
        pass

    return out

if __name__ == "__main__":
    res = collect_weather()
    print(json.dumps(res))
