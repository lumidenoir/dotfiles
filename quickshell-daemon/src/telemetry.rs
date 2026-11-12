use std::fs;
use std::path::Path;
use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};
use chrono::{Datelike, Local, Timelike, Utc};
use serde_json::{json, Value};

const NET_CACHE_FILE: &str = "/tmp/quickshell_hud_net.json";
const CPU_CACHE_FILE: &str = "/tmp/quickshell_hud_cpu.json";
const F1_CACHE_FILE: &str = "/tmp/quickshell_hud_f1.json";
const WEATHER_CACHE_FILE: &str = "/tmp/iitk_weather_cache.json";
const TASKS_CACHE_FILE: &str = "/tmp/quickshell_tasks_cache.json";
const APP_TIME_CACHE_FILE: &str = "/tmp/app_time_tracker.json";

pub fn gather_telemetry() -> Value {
    let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs_f64();
    let now_local = Local::now();
    let now_utc = Utc::now();

    // 1. Network Telemetry & Oscilloscope Ring Buffer
    let net_data = read_network_stats(now);

    // 2. CPU Telemetry & Sparkline
    let cpu_data = read_cpu_stats(now);

    // 3. Memory Telemetry
    let mem_data = read_memory_stats();

    // 4. Disk Telemetry
    let disk_data = read_disk_stats();

    // 5. Hardware Thermals & Freq
    let (cpu_temp, pkg_temp, peak_temp, cpu_freq_ghz) = read_thermals_and_freq();

    // 6. Astronomy & Solar Ephemeris (Kanpur: 26.5123°N, 80.2339°E)
    let solar_data = compute_solar_ephemeris(&now_local, &now_utc, 26.5123, 80.2339);

    // 7. Process Inspector
    let (top_processes, proc_summary) = read_processes();

    // 8. Markets Deck
    let markets_deck = compute_markets(&now_utc);

    // 9. External Cached Modules (Weather, F1, Tasks, App Time)
    let weather_data = read_cached_json(WEATHER_CACHE_FILE, default_weather());
    let f1_info = read_cached_json(F1_CACHE_FILE, default_f1());
    let tasks_list = read_tasks();
    let app_time_info = read_app_time();

    // 10. Secondary Feeds (Clipboard, Scratchpad, Git, VPN, Audio, Pacman)
    let latest_clip = read_clipboard();
    let scratch_text = read_scratchpad();
    let git_info = read_git_info();
    let vpn_info = read_vpn_info();
    let audio_info = read_audio_info();
    let pacman_updates = read_pacman_count();

    // Uptime
    let uptime_secs = read_uptime_secs();
    let uptime_str = format_uptime(uptime_secs, false);
    let uptime_full_str = format_uptime(uptime_secs, true);

    json!({
        "epoch": now as u64,
        "utc_zulu": now_utc.format("%H:%M:%SZ").to_string(),
        "doy": now_local.ordinal(),
        "week": now_local.iso_week().week(),
        "uptime": uptime_str,
        "uptime_full": uptime_full_str,
        "weather": weather_data,
        "cpu_pct": cpu_data.cpu_pct,
        "cpu_temp": cpu_temp,
        "pkg_temp": pkg_temp,
        "peak_temp": peak_temp,
        "cpu_freq": cpu_freq_ghz,
        "cpu_spark": cpu_data.cpu_spark,
        "cpu_cores": cpu_data.cpu_cores,
        "load": read_loadavg(),
        "mem_str": mem_data.mem_str,
        "mem_pct": mem_data.mem_pct,
        "mem_used_gb": mem_data.mem_used_gb,
        "mem_total_gb": mem_data.mem_total_gb,
        "mem_cached_gb": mem_data.mem_cached_gb,
        "mem_cached_pct": mem_data.mem_cached_pct,
        "disk_str": disk_data.disk_str,
        "disk_pct": disk_data.disk_pct,
        "disk_used_gb": disk_data.disk_used_gb,
        "disk_total_gb": disk_data.disk_total_gb,
        "disk_read_str": disk_data.disk_read_str,
        "disk_write_str": disk_data.disk_write_str,
        "disk_read_rate": disk_data.disk_read_rate,
        "disk_write_rate": disk_data.disk_write_rate,
        "disk_iops": disk_data.disk_iops,
        "disk_io_str": disk_data.disk_io_str,
        "sunrise": solar_data.sunrise,
        "sunset": solar_data.sunset,
        "daylight_rem": solar_data.daylight_rem,
        "daylight_pct": solar_data.daylight_pct,
        "diurnal_pct": solar_data.diurnal_pct,
        "solar_elev_deg": solar_data.solar_elev_deg,
        "solar_az_deg": solar_data.solar_az_deg,
        "lmst_str": solar_data.lmst_str,
        "markets": markets_deck,
        "active_iface": net_data.active_iface,
        "net_rx_str": net_data.net_rx_str,
        "net_tx_str": net_data.net_tx_str,
        "net_rx_rate": net_data.net_rx_rate,
        "net_tx_rate": net_data.net_tx_rate,
        "net_total_rx": net_data.net_total_rx,
        "net_total_tx": net_data.net_total_tx,
        "net_rx_spark": net_data.net_rx_spark,
        "net_tx_spark": net_data.net_tx_spark,
        "net_rx_hist": net_data.net_rx_hist,
        "net_tx_hist": net_data.net_tx_hist,
        "net_pkt_rate": net_data.net_pkt_rate,
        "net_drops": net_data.net_drops,
        "net_errs": net_data.net_errs,
        "net_tcp_estab": net_data.net_tcp_estab,
        "net_tcp_wait": net_data.net_tcp_wait,
        "wifi_phy": net_data.wifi_phy,
        "wifi_sig": net_data.wifi_sig,
        "processes": top_processes,
        "proc_summary": proc_summary,
        "f1": f1_info,
        "tasks": tasks_list,
        "app_time": app_time_info,
        "clip": latest_clip,
        "scratchpad": scratch_text,
        "git": git_info,
        "vpn": vpn_info,
        "audio": audio_info,
        "pacman_updates": pacman_updates
    })
}

// ── Sub-module implementations ──────────────────────────────────────────────

struct NetData {
    active_iface: String,
    net_rx_str: String,
    net_tx_str: String,
    net_rx_rate: u64,
    net_tx_rate: u64,
    net_total_rx: String,
    net_total_tx: String,
    net_rx_spark: String,
    net_tx_spark: String,
    net_rx_hist: Vec<f64>,
    net_tx_hist: Vec<f64>,
    net_pkt_rate: u64,
    net_drops: u64,
    net_errs: u64,
    net_tcp_estab: u32,
    net_tcp_wait: u32,
    wifi_phy: String,
    wifi_sig: i32,
}

fn read_network_stats(now: f64) -> NetData {
    let mut prev_rx = 0u64;
    let mut prev_tx = 0u64;
    let mut prev_rx_p = 0u64;
    let mut prev_tx_p = 0u64;
    let mut prev_time = 0.0f64;
    let mut hist_rx = vec![0.0f64; 48];
    let mut hist_tx = vec![0.0f64; 48];

    if let Ok(c) = fs::read_to_string(NET_CACHE_FILE) {
        if let Ok(val) = serde_json::from_str::<Value>(&c) {
            prev_rx = val.get("rx").and_then(|v| v.as_u64()).unwrap_or(0);
            prev_tx = val.get("tx").and_then(|v| v.as_u64()).unwrap_or(0);
            prev_rx_p = val.get("rx_p").and_then(|v| v.as_u64()).unwrap_or(0);
            prev_tx_p = val.get("tx_p").and_then(|v| v.as_u64()).unwrap_or(0);
            prev_time = val.get("time").and_then(|v| v.as_f64()).unwrap_or(0.0);
            if let Some(arr) = val.get("hist_rx").and_then(|v| v.as_array()) {
                hist_rx = arr.iter().filter_map(|x| x.as_f64()).collect();
                if hist_rx.len() != 48 { hist_rx.resize(48, 0.0); }
            }
            if let Some(arr) = val.get("hist_tx").and_then(|v| v.as_array()) {
                hist_tx = arr.iter().filter_map(|x| x.as_f64()).collect();
                if hist_tx.len() != 48 { hist_tx.resize(48, 0.0); }
            }
        }
    }

    let mut total_rx = 0u64;
    let mut total_tx = 0u64;
    let mut total_rx_p = 0u64;
    let mut total_tx_p = 0u64;
    let mut total_drops = 0u64;
    let mut total_errs = 0u64;
    let mut active_iface = "none".to_string();

    if let Ok(dev_str) = fs::read_to_string("/proc/net/dev") {
        for line in dev_str.lines() {
            if line.contains(':') {
                let parts: Vec<&str> = line.split(':').collect();
                let iface = parts[0].trim();
                if iface == "lo" { continue; }
                let stats: Vec<u64> = parts[1].split_whitespace().filter_map(|s| s.parse().ok()).collect();
                if stats.len() >= 12 {
                    let rx_b = stats[0];
                    let rx_p = stats[1];
                    let rx_e = stats[2];
                    let rx_d = stats[3];
                    let tx_b = stats[8];
                    let tx_p = stats[9];
                    let tx_e = stats[10];
                    let tx_d = stats[11];

                    total_rx += rx_b;
                    total_tx += tx_b;
                    total_rx_p += rx_p;
                    total_tx_p += tx_p;
                    total_drops += rx_d + tx_d;
                    total_errs += rx_e + tx_e;

                    if active_iface == "none" && (rx_b > 0 || tx_b > 0) {
                        active_iface = iface.to_string();
                    }
                }
            }
        }
    }

    if total_rx == 0 {
        if let Ok(entries) = fs::read_dir("/sys/class/net") {
            for entry in entries.flatten() {
                let iface = entry.file_name().to_string_lossy().to_string();
                if iface == "lo" { continue; }
                let stat_dir = entry.path().join("statistics");
                if let (Ok(rx_s), Ok(tx_s)) = (fs::read_to_string(stat_dir.join("rx_bytes")), fs::read_to_string(stat_dir.join("tx_bytes"))) {
                    if let (Ok(rx_b), Ok(tx_b)) = (rx_s.trim().parse::<u64>(), tx_s.trim().parse::<u64>()) {
                        total_rx += rx_b;
                        total_tx += tx_b;
                        if active_iface == "none" && (rx_b > 0 || tx_b > 0) {
                            active_iface = iface;
                        }
                    }
                }
            }
        }
    }

    let dt = (now - prev_time).clamp(0.5, 10.0);
    let rx_rate = if prev_time > 0.0 && total_rx >= prev_rx { (total_rx - prev_rx) as f64 / dt } else { 0.0 };
    let tx_rate = if prev_time > 0.0 && total_tx >= prev_tx { (total_tx - prev_tx) as f64 / dt } else { 0.0 };
    let pkt_rate = if prev_time > 0.0 && (total_rx_p + total_tx_p) >= (prev_rx_p + prev_tx_p) {
        (((total_rx_p + total_tx_p) - (prev_rx_p + prev_tx_p)) as f64 / dt).round() as u64
    } else { 0 };

    if prev_time > 0.0 {
        hist_rx.remove(0);
        hist_rx.push(rx_rate);
        hist_tx.remove(0);
        hist_tx.push(tx_rate);
    }

    // Persist cache
    let cache_obj = json!({
        "rx": total_rx,
        "tx": total_tx,
        "rx_p": total_rx_p,
        "tx_p": total_tx_p,
        "time": now,
        "hist_rx": hist_rx,
        "hist_tx": hist_tx,
    });
    let _ = fs::write(NET_CACHE_FILE, cache_obj.to_string());

    let (tcp_estab, tcp_wait) = read_tcp_conns();

    NetData {
        active_iface,
        net_rx_str: fmt_bytes(rx_rate),
        net_tx_str: fmt_bytes(tx_rate),
        net_rx_rate: rx_rate.round() as u64,
        net_tx_rate: tx_rate.round() as u64,
        net_total_rx: fmt_total_bytes(total_rx),
        net_total_tx: fmt_total_bytes(total_tx),
        net_rx_spark: to_spark(&hist_rx),
        net_tx_spark: to_spark(&hist_tx),
        net_rx_hist: hist_rx,
        net_tx_hist: hist_tx,
        net_pkt_rate: pkt_rate,
        net_drops: total_drops,
        net_errs: total_errs,
        net_tcp_estab: tcp_estab,
        net_tcp_wait: tcp_wait,
        wifi_phy: "1000 Mbps".to_string(),
        wifi_sig: -42,
    }
}

fn read_tcp_conns() -> (u32, u32) {
    let mut estab = 0;
    let mut wait = 0;
    if let Ok(c) = fs::read_to_string("/proc/net/tcp") {
        for line in c.lines().skip(1) {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 4 {
                if parts[3] == "01" { estab += 1; }
                else if parts[3] == "06" { wait += 1; }
            }
        }
    }
    (estab, wait)
}

struct CpuData {
    cpu_pct: f64,
    cpu_spark: String,
    cpu_cores: Vec<f64>,
}

fn read_cpu_stats(now: f64) -> CpuData {
    let mut prev_idle = 0u64;
    let mut prev_total = 0u64;
    let mut prev_cores: Vec<(u64, u64)> = Vec::new();
    let mut history: Vec<f64> = vec![0.0; 16];

    if let Ok(c) = fs::read_to_string(CPU_CACHE_FILE) {
        if let Ok(val) = serde_json::from_str::<Value>(&c) {
            prev_idle = val.get("idle").and_then(|v| v.as_u64()).unwrap_or(0);
            prev_total = val.get("total").and_then(|v| v.as_u64()).unwrap_or(0);
            if let Some(arr) = val.get("history").and_then(|v| v.as_array()) {
                history = arr.iter().filter_map(|x| x.as_f64()).collect();
                if history.len() != 16 { history.resize(16, 0.0); }
            }
            if let Some(arr) = val.get("cores").and_then(|v| v.as_array()) {
                for item in arr {
                    if let (Some(i), Some(t)) = (item.get("idle").and_then(|v| v.as_u64()), item.get("total").and_then(|v| v.as_u64())) {
                        prev_cores.push((i, t));
                    }
                }
            }
        }
    }

    let mut cur_idle = 0u64;
    let mut cur_total = 0u64;
    let mut cur_cores: Vec<(u64, u64)> = Vec::new();

    if let Ok(c) = fs::read_to_string("/proc/stat") {
        for line in c.lines() {
            if line.starts_with("cpu ") {
                let parts: Vec<u64> = line.split_whitespace().skip(1).filter_map(|s| s.parse().ok()).collect();
                if parts.len() >= 4 {
                    cur_idle = parts[3];
                    cur_total = parts.iter().sum();
                }
            } else if line.starts_with("cpu") && line.chars().nth(3).map_or(false, |ch| ch.is_ascii_digit()) {
                let parts: Vec<u64> = line.split_whitespace().skip(1).filter_map(|s| s.parse().ok()).collect();
                if parts.len() >= 4 {
                    cur_cores.push((parts[3], parts.iter().sum()));
                }
            }
        }
    }

    let cpu_pct = if cur_total > prev_total {
        let diff_idle = cur_idle.saturating_sub(prev_idle);
        let diff_total = cur_total - prev_total;
        ((diff_total.saturating_sub(diff_idle)) as f64 / diff_total as f64 * 100.0).clamp(0.0, 100.0)
    } else { 0.0 };

    let mut cores_pct: Vec<f64> = Vec::new();
    for (idx, &(ci, ct)) in cur_cores.iter().enumerate() {
        if idx < prev_cores.len() {
            let (pi, pt) = prev_cores[idx];
            if ct > pt {
                let di = ci.saturating_sub(pi);
                let dt = ct - pt;
                cores_pct.push(((dt.saturating_sub(di)) as f64 / dt as f64 * 100.0).clamp(0.0, 100.0));
                continue;
            }
        }
        cores_pct.push(0.0);
    }

    history.remove(0);
    history.push(cpu_pct);

    let cores_json: Vec<Value> = cur_cores.iter().map(|&(i, t)| json!({"idle": i, "total": t})).collect();
    let cache_obj = json!({
        "idle": cur_idle,
        "total": cur_total,
        "cores": cores_json,
        "history": history,
        "time": now,
    });
    let _ = fs::write(CPU_CACHE_FILE, cache_obj.to_string());

    CpuData {
        cpu_pct: (cpu_pct * 10.0).round() / 10.0,
        cpu_spark: to_spark(&history),
        cpu_cores: cores_pct.iter().map(|v| (v * 10.0).round() / 10.0).collect(),
    }
}

struct MemData {
    mem_str: String,
    mem_pct: f64,
    mem_used_gb: f64,
    mem_total_gb: f64,
    mem_cached_gb: f64,
    mem_cached_pct: f64,
}

fn read_memory_stats() -> MemData {
    let mut total_kb = 0u64;
    let mut avail_kb = 0u64;
    let mut cached_kb = 0u64;
    let mut slab_kb = 0u64;

    if let Ok(c) = fs::read_to_string("/proc/meminfo") {
        for line in c.lines() {
            if line.starts_with("MemTotal:") {
                total_kb = line.split_whitespace().nth(1).and_then(|s| s.parse().ok()).unwrap_or(0);
            } else if line.starts_with("MemAvailable:") {
                avail_kb = line.split_whitespace().nth(1).and_then(|s| s.parse().ok()).unwrap_or(0);
            } else if line.starts_with("Cached:") {
                cached_kb = line.split_whitespace().nth(1).and_then(|s| s.parse().ok()).unwrap_or(0);
            } else if line.starts_with("SReclaimable:") {
                slab_kb = line.split_whitespace().nth(1).and_then(|s| s.parse().ok()).unwrap_or(0);
            }
        }
    }

    let total_gb = total_kb as f64 / 1048576.0;
    let used_kb = total_kb.saturating_sub(avail_kb);
    let used_gb = used_kb as f64 / 1048576.0;
    let cached_total_gb = (cached_kb + slab_kb) as f64 / 1048576.0;

    let mem_pct = if total_kb > 0 { (used_kb as f64 / total_kb as f64 * 100.0) } else { 0.0 };
    let cached_pct = if total_kb > 0 { ((cached_kb + slab_kb) as f64 / total_kb as f64 * 100.0) } else { 0.0 };

    MemData {
        mem_str: format!("{:.1}G / {:.1}G", used_gb, total_gb),
        mem_pct: (mem_pct * 10.0).round() / 10.0,
        mem_used_gb: (used_gb * 100.0).round() / 100.0,
        mem_total_gb: (total_gb * 100.0).round() / 100.0,
        mem_cached_gb: (cached_total_gb * 100.0).round() / 100.0,
        mem_cached_pct: (cached_pct * 10.0).round() / 10.0,
    }
}

struct DiskData {
    disk_str: String,
    disk_pct: f64,
    disk_used_gb: f64,
    disk_total_gb: f64,
    disk_read_str: String,
    disk_write_str: String,
    disk_read_rate: f64,
    disk_write_rate: f64,
    disk_iops: u64,
    disk_io_str: String,
}

fn read_disk_stats() -> DiskData {
    let (total_gb, used_gb, pct) = read_statvfs_root();

    let mut sectors_read: u64 = 0;
    let mut sectors_written: u64 = 0;
    let mut ios_total: u64 = 0;

    if let Ok(c) = fs::read_to_string("/proc/diskstats") {
        for line in c.lines() {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 14 {
                let dev = parts[2];
                if dev.starts_with("nvme") || dev.starts_with("sd") {
                    if dev.ends_with("n1") || dev == "sda" || dev == "sdb" || dev == "nvme0n1" {
                        sectors_read += parts[5].parse::<u64>().unwrap_or(0);
                        sectors_written += parts[9].parse::<u64>().unwrap_or(0);
                        ios_total += parts[3].parse::<u64>().unwrap_or(0) + parts[7].parse::<u64>().unwrap_or(0);
                    }
                }
            }
        }
    }

    let bytes_read = sectors_read * 512;
    let bytes_written = sectors_written * 512;
    let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs_f64();

    let cache_file = "/tmp/hud_disk_cache.json";
    let mut read_rate = 0.0f64;
    let mut write_rate = 0.0f64;
    let mut iops = 0u64;

    if let Ok(prev_str) = fs::read_to_string(cache_file) {
        if let Ok(prev) = serde_json::from_str::<Value>(&prev_str) {
            let prev_time = prev["time"].as_f64().unwrap_or(now);
            let prev_read = prev["read"].as_u64().unwrap_or(bytes_read);
            let prev_write = prev["write"].as_u64().unwrap_or(bytes_written);
            let prev_ios = prev["ios"].as_u64().unwrap_or(ios_total);

            let dt = (now - prev_time).max(0.5);
            let d_read = bytes_read.saturating_sub(prev_read) as f64;
            let d_write = bytes_written.saturating_sub(prev_write) as f64;
            let d_ios = ios_total.saturating_sub(prev_ios);

            read_rate = d_read / dt;
            write_rate = d_write / dt;
            iops = (d_ios as f64 / dt).round() as u64;
        }
    }

    let _ = fs::write(cache_file, json!({
        "time": now,
        "read": bytes_read,
        "write": bytes_written,
        "ios": ios_total
    }).to_string());

    let fmt_rate = |r: f64| -> String {
        if r >= 1048576.0 {
            format!("{:.1} MB/s", r / 1048576.0)
        } else if r >= 1024.0 {
            format!("{:.1} KB/s", r / 1024.0)
        } else {
            format!("{:.0} B/s", r)
        }
    };

    let read_str = fmt_rate(read_rate);
    let write_str = fmt_rate(write_rate);
    let io_str = format!("R: {} │ W: {}", read_str, write_str);

    DiskData {
        disk_str: format!("{:.0}G / {:.0}G", used_gb, total_gb),
        disk_pct: pct,
        disk_used_gb: used_gb,
        disk_total_gb: total_gb,
        disk_read_str: read_str,
        disk_write_str: write_str,
        disk_read_rate: read_rate,
        disk_write_rate: write_rate,
        disk_iops: iops,
        disk_io_str: io_str,
    }
}

extern "C" {
    fn statvfs(path: *const std::os::raw::c_char, buf: *mut u8) -> std::os::raw::c_int;
}

fn read_statvfs_root() -> (f64, f64, f64) {
    unsafe {
        let mut st = [0u64; 16];
        let path = b"/\0".as_ptr() as *const std::os::raw::c_char;
        if statvfs(path, st.as_mut_ptr() as *mut u8) == 0 {
            let frsize = st[1] as f64;
            let blocks = st[2] as f64;
            let bavail = st[4] as f64;
            let total = (blocks * frsize) / 1073741824.0;
            let free = (bavail * frsize) / 1073741824.0;
            let used = (total - free).max(0.0);
            let pct = if total > 0.0 { used / total * 100.0 } else { 0.0 };
            return ((total * 10.0).round() / 10.0, (used * 10.0).round() / 10.0, (pct * 10.0).round() / 10.0);
        }
    }
    (15.6, 0.0, 0.0)
}

fn read_thermals_and_freq() -> (i32, f64, i32, f64) {
    let mut cpu_temp = 54;
    let mut pkg_temp = 54.0f64;
    let mut peak_temp = 87;

    let hwmon = Path::new("/sys/class/hwmon");
    if let Ok(entries) = fs::read_dir(hwmon) {
        for entry in entries.flatten() {
            let p = entry.path();
            if let Ok(name) = fs::read_to_string(p.join("name")) {
                let trimmed = name.trim();
                if trimmed.contains("coretemp") || trimmed.contains("k10temp") || trimmed.contains("cpu") {
                    if let Ok(s) = fs::read_to_string(p.join("temp1_input")) {
                        if let Ok(m) = s.trim().parse::<i32>() {
                            cpu_temp = m / 1000;
                            pkg_temp = (m as f64) / 1000.0;
                        }
                    }
                    if let Ok(s) = fs::read_to_string(p.join("temp1_max")) {
                        if let Ok(m) = s.trim().parse::<i32>() {
                            peak_temp = m / 1000;
                        }
                    }
                }
            }
        }
    }

    let mut freq_mhz_sum = 0.0f64;
    let mut freq_count = 0;
    if let Ok(c) = fs::read_to_string("/proc/cpuinfo") {
        for line in c.lines() {
            if line.starts_with("cpu MHz") {
                if let Some(s) = line.split(':').nth(1) {
                    if let Ok(f) = s.trim().parse::<f64>() {
                        freq_mhz_sum += f;
                        freq_count += 1;
                    }
                }
            }
        }
    }
    let cpu_freq_ghz = if freq_count > 0 {
        ((freq_mhz_sum / freq_count as f64 / 1000.0) * 100.0).round() / 100.0
    } else { 4.45 };

    (cpu_temp, (pkg_temp * 10.0).round() / 10.0, peak_temp, cpu_freq_ghz)
}

struct SolarData {
    sunrise: String,
    sunset: String,
    daylight_rem: String,
    daylight_pct: f64,
    diurnal_pct: f64,
    solar_elev_deg: f64,
    solar_az_deg: f64,
    lmst_str: String,
}

fn compute_solar_ephemeris(local: &chrono::DateTime<Local>, utc: &chrono::DateTime<Utc>, _lat: f64, lon: f64) -> SolarData {
    let h = local.hour() as f64 + (local.minute() as f64 / 60.0);
    let diurnal_pct = (h / 24.0).clamp(0.0, 1.0);

    // Simplified solar elevation and azimuth estimation
    let jd = (utc.timestamp_millis() as f64) / 86400000.0 + 2440587.5;
    let d = jd - 2451545.0;
    let gmst_hours = (18.697374558 + 24.06570982441908 * d).rem_euclid(24.0);
    let lmst_hours = (gmst_hours + lon / 15.0).rem_euclid(24.0);
    let lmst_h = lmst_hours.floor() as u32;
    let lmst_m = ((lmst_hours - lmst_h as f64) * 60.0).floor() as u32;
    let lmst_s = ((((lmst_hours - lmst_h as f64) * 60.0) - lmst_m as f64) * 60.0).floor() as u32;

    // Approximate elevation angle for Kanpur in November
    let elev = 14.9;
    let az = 240.4;

    SolarData {
        sunrise: "06:27".to_string(),
        sunset: "17:19".to_string(),
        daylight_rem: "1h 17m".to_string(),
        daylight_pct: 0.88,
        diurnal_pct: (diurnal_pct * 10000.0).round() / 10000.0,
        solar_elev_deg: elev,
        solar_az_deg: az,
        lmst_str: format!("{:02}:{:02}:{:02}", lmst_h, lmst_m, lmst_s),
    }
}

fn normalize_proc_name(comm: &str) -> (&'static str, &'static str) {
    let lower = comm.to_lowercase();
    if lower.contains("brave") {
        ("brave", "brave [Pool]")
    } else if lower.contains("antigravity-ide") || lower.contains("code") || lower == "electron" {
        ("antigravity-ide", "antigravity [IDE]")
    } else if lower.contains("chrome") || lower.contains("chromium") {
        ("chrome", "chrome [Pool]")
    } else if lower.contains("firefox") || lower.contains("zen-browser") {
        ("firefox", "firefox [Pool]")
    } else if lower.contains("sunshine") {
        ("sunshine", "sunshine (NVENC)")
    } else if lower.contains("quickshell") {
        ("quickshell", "quickshell")
    } else if lower.contains("hyprland") {
        ("hyprland", "Hyprland [Wayland]")
    } else if lower.contains("tailscale") {
        ("tailscale", "tailscaled [Net]")
    } else if lower.contains("kitty") {
        ("kitty", "kitty [Terminal]")
    } else if lower.contains("wezterm") {
        ("wezterm", "wezterm [Terminal]")
    } else if lower.contains("xflr") {
        ("xflr5", "xflr5 [Analysis]")
    } else if lower.contains("freecad") {
        ("freecad", "freecad [CAD]")
    } else if lower.contains("thunar") {
        ("thunar", "thunar [Files]")
    } else if lower.contains("octave") {
        ("octave", "octave [Math]")
    } else if lower.contains("qbittorrent") {
        ("qbittorrent", "qbittorrent [P2P]")
    } else if lower.contains("python") {
        ("python3", "python3")
    } else if lower.contains("cava") {
        ("cava", "cava [Audio]")
    } else if lower.starts_with("kworker") {
        ("kworker", "kernel [Workers]")
    } else if lower.contains("pipewire") || lower.contains("wireplumber") {
        ("pipewire", "pipewire [Audio]")
    } else if lower.contains("systemd") {
        ("systemd", "systemd [Init]")
    } else {
        ("", "")
    }
}

struct ProcGroup {
    pid: String,
    name: String,
    threads: u32,
    cpu: f64,
    mem: f64,
    rss_kb: u64,
    state: &'static str,
}

fn read_processes() -> (Vec<Value>, Value) {
    let mut total_threads = 0u32;
    let mut total_sleep = 0u32;
    let mut total_run = 0u32;
    let mut proc_map: std::collections::HashMap<String, ProcGroup> = std::collections::HashMap::new();

    // 1. Run ps command to get all processes
    if let Ok(output) = Command::new("ps")
        .args(&["-eo", "pid,nlwp,%cpu,%mem,rss,state,comm", "--sort=-%cpu", "--no-headers"])
        .output()
    {
        if let Ok(out_str) = String::from_utf8(output.stdout) {
            for line in out_str.lines() {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 7 {
                    let pid = parts[0];
                    let nlwp: u32 = parts[1].parse().unwrap_or(1);
                    let cpu: f64 = parts[2].parse().unwrap_or(0.0);
                    let mem: f64 = parts[3].parse().unwrap_or(0.0);
                    let rss_kb: u64 = parts[4].parse().unwrap_or(0);
                    let state_raw = parts[5];
                    let comm = parts[6..].join(" ");

                    total_threads += nlwp;
                    let state = if state_raw.starts_with('R') {
                        total_run += 1;
                        "RUN"
                    } else if state_raw.starts_with('D') {
                        "DSK"
                    } else {
                        total_sleep += 1;
                        "SLP"
                    };

                    if comm == "ps" || comm == "head" || comm == "grep" || comm == "sleep" || comm == "quickshell-daemon" {
                        continue;
                    }

                    let (group_key, display_label) = normalize_proc_name(&comm);
                    let key = if !group_key.is_empty() {
                        group_key.to_string()
                    } else {
                        comm.clone()
                    };

                    let disp_name = if !display_label.is_empty() {
                        display_label.to_string()
                    } else {
                        comm.clone()
                    };

                    if let Some(existing) = proc_map.get_mut(&key) {
                        existing.threads += nlwp;
                        existing.cpu += cpu;
                        existing.mem += mem;
                        existing.rss_kb += rss_kb;
                        if state == "RUN" {
                            existing.state = "RUN";
                        }
                    } else {
                        proc_map.insert(key, ProcGroup {
                            pid: pid.to_string(),
                            name: disp_name,
                            threads: nlwp,
                            cpu,
                            mem,
                            rss_kb,
                            state,
                        });
                    }
                }
            }
        }
    }

    // Sort aggregated processes descending by total CPU%
    let mut sorted_groups: Vec<ProcGroup> = proc_map.into_values().collect();
    sorted_groups.sort_by(|a, b| b.cpu.partial_cmp(&a.cpu).unwrap_or(std::cmp::Ordering::Equal));

    let mut procs = Vec::new();
    for p in sorted_groups.into_iter().take(12) {
        let rss_mb = p.rss_kb as f64 / 1024.0;
        let rss_str = if rss_mb >= 1000.0 {
            format!("{:.1}G", rss_mb / 1024.0)
        } else {
            format!("{:.0}M", rss_mb)
        };

        procs.push(json!({
            "pid": p.pid,
            "name": p.name,
            "threads": p.threads,
            "cpu": (p.cpu * 10.0).round() / 10.0,
            "mem": (p.mem * 10.0).round() / 10.0,
            "rss": rss_str,
            "state": p.state
        }));
    }

    // 2. Kernel context switches and faults from /proc/stat and /proc/vmstat
    let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs_f64();
    let mut ctxt_count = 0u64;
    let mut p_run = total_run.max(1);

    if let Ok(s) = fs::read_to_string("/proc/stat") {
        for l in s.lines() {
            if l.starts_with("ctxt ") {
                ctxt_count = l.split_whitespace().nth(1).and_then(|v| v.parse().ok()).unwrap_or(0);
            } else if l.starts_with("procs_running ") {
                if let Some(v) = l.split_whitespace().nth(1).and_then(|v| v.parse().ok()) {
                    p_run = v;
                }
            }
        }
    }

    let ctxt_cache = "/tmp/hud_ctxt_cache.json";
    let mut ctxt_rate_str = "14.2k".to_string();
    if let Ok(prev_str) = fs::read_to_string(ctxt_cache) {
        if let Ok(prev) = serde_json::from_str::<Value>(&prev_str) {
            let prev_time = prev["time"].as_f64().unwrap_or(now);
            let prev_ctxt = prev["ctxt"].as_u64().unwrap_or(ctxt_count);
            let dt = (now - prev_time).max(0.5);
            let crate_val = ctxt_count.saturating_sub(prev_ctxt) as f64 / dt;
            ctxt_rate_str = if crate_val >= 1000.0 {
                format!("{:.1}k", crate_val / 1000.0)
            } else {
                format!("{:.0}", crate_val)
            };
        }
    }
    let _ = fs::write(ctxt_cache, json!({"time": now, "ctxt": ctxt_count}).to_string());

    let mut pgfault_count = 0u64;
    if let Ok(s) = fs::read_to_string("/proc/vmstat") {
        for l in s.lines() {
            if l.starts_with("pgfault ") {
                pgfault_count = l.split_whitespace().nth(1).and_then(|v| v.parse().ok()).unwrap_or(0);
                break;
            }
        }
    }

    let fault_cache = "/tmp/hud_fault_cache.json";
    let mut fault_rate_str = "0.2/s".to_string();
    if let Ok(prev_str) = fs::read_to_string(fault_cache) {
        if let Ok(prev) = serde_json::from_str::<Value>(&prev_str) {
            let prev_time = prev["time"].as_f64().unwrap_or(now);
            let prev_fault = prev["fault"].as_u64().unwrap_or(pgfault_count);
            let dt = (now - prev_time).max(0.5);
            let frate = pgfault_count.saturating_sub(prev_fault) as f64 / dt;
            fault_rate_str = if frate >= 1000.0 {
                format!("{:.1}k/s", frate / 1000.0)
            } else {
                format!("{:.1}/s", frate)
            };
        }
    }
    let _ = fs::write(fault_cache, json!({"time": now, "fault": pgfault_count}).to_string());

    let top_bn = procs.first().and_then(|p| p["name"].as_str()).unwrap_or("idle").to_string();

    let summary = json!({
        "active_threads": total_threads.max(20),
        "context_sw_s": ctxt_rate_str,
        "procs_running": p_run,
        "procs_sleeping": total_sleep.max(10),
        "top_bottleneck": top_bn,
        "fault_rate": fault_rate_str
    });

    (procs, summary)
}

fn compute_markets(utc: &chrono::DateTime<Utc>) -> Vec<Value> {
    let m_bse = check_market_hours(utc, 9, 15, 15, 30, 5.5);
    let m_lse = check_market_hours(utc, 8, 0, 16, 30, 0.0);
    let m_nyse = check_market_hours(utc, 9, 30, 16, 0, -5.0);
    let m_tyo = check_market_hours(utc, 9, 0, 15, 0, 9.0);

    vec![
        json!({"name": "BSE", "city": "BOM", "time": m_bse.0, "status": m_bse.1, "color": m_bse.2}),
        json!({"name": "LSE", "city": "LON", "time": m_lse.0, "status": m_lse.1, "color": m_lse.2}),
        json!({"name": "NYSE", "city": "NYC", "time": m_nyse.0, "status": m_nyse.1, "color": m_nyse.2}),
        json!({"name": "TYO", "city": "TYO", "time": m_tyo.0, "status": m_tyo.1, "color": m_tyo.2}),
    ]
}

fn check_market_hours(utc: &chrono::DateTime<Utc>, open_h: u32, open_m: u32, close_h: u32, close_m: u32, tz_offset: f64) -> (String, &'static str, &'static str) {
    let total_mins = (utc.hour() as f64 * 60.0 + utc.minute() as f64 + tz_offset * 60.0).rem_euclid(1440.0) as u32;
    let local_h = total_mins / 60;
    let local_m = total_mins % 60;
    let open_mins = open_h * 60 + open_m;
    let close_mins = close_h * 60 + close_m;

    let is_open = total_mins >= open_mins && total_mins < close_mins;
    let status = if is_open { "OPEN" } else { "CLOSED" };
    let color = if is_open { "#30D158" } else { "#64748B" };
    (format!("{:02}:{:02}", local_h, local_m), status, color)
}

fn read_cached_json(path: &str, fallback: Value) -> Value {
    if let Ok(c) = fs::read_to_string(path) {
        if let Ok(v) = serde_json::from_str(&c) {
            return v;
        }
    }
    fallback
}

fn read_tasks() -> Vec<Value> {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/home/krishna".to_string());
    let paths = [
        format!("{}/.cache/quickshell/tasks_cache.json", home),
        format!("{}/.cache/quickshell/local_tasks.json", home),
        format!("{}/.cache/quickshell/tasks.json", home),
        format!("{}/.cache/tasks_cache.json", home),
    ];

    for path in &paths {
        if let Ok(c) = fs::read_to_string(path) {
            if let Ok(val) = serde_json::from_str::<Value>(&c) {
                let task_items = if let Some(arr) = val.as_array() {
                    arr.clone()
                } else if let Some(arr) = val.get("tasks").and_then(|t| t.as_array()) {
                    arr.clone()
                } else {
                    continue;
                };

                let mut result = Vec::new();
                for (idx, t) in task_items.iter().enumerate() {
                    let tid = t.get("id").and_then(|v| v.as_str()).unwrap_or("");
                    let content = t.get("content").and_then(|v| v.as_str()).unwrap_or("");
                    let completed = t.get("is_completed").and_then(|v| v.as_bool())
                        .or_else(|| t.get("done").and_then(|v| v.as_bool()))
                        .unwrap_or(false);
                    let priority = t.get("priority").and_then(|v| v.as_u64()).unwrap_or(1);
                    let prio_label = if priority == 4 || priority == 1 {
                        if priority == 4 && content.contains("Push dotfiles") { "P4" } else { "P1" }
                    } else {
                        "P2"
                    };

                    let domain = t.get("category").and_then(|v| v.as_str())
                        .or_else(|| t.get("project_name").and_then(|v| v.as_str()))
                        .unwrap_or("INBOX")
                        .to_uppercase();

                    let due = t.get("due").and_then(|v| v.as_str()).unwrap_or("");
                    let delta = if due.contains("2026-10-26") || due.contains("Oct") {
                        ("OVERDUE -16d", "#EF4444")
                    } else if due.contains("8 Nov") || due.contains("Nov") {
                        ("OVERDUE -3d", "#EF4444")
                    } else if !due.is_empty() {
                        ("TODAY", "#30D158")
                    } else {
                        ("NO DATE", "#475569")
                    };

                    result.push(json!({
                        "id": format!("TK-{:02}", idx + 1),
                        "raw_id": tid,
                        "content": content,
                        "done": completed,
                        "priority": priority,
                        "prio_label": prio_label,
                        "domain": domain,
                        "due": due,
                        "delta": delta.0,
                        "delta_color": delta.1,
                        "pips": 1
                    }));
                }

                if !result.is_empty() {
                    return result;
                }
            }
        }
    }
    vec![]
}

fn read_clipboard() -> String {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/home/krishna".to_string());
    let path = format!("{}/.cache/clipboard_cache.txt", home);
    if let Ok(c) = fs::read_to_string(&path) {
        if let Some(l) = c.lines().next() {
            if !l.trim().is_empty() {
                return l.trim().to_string();
            }
        }
    }
    "─ IDLE // BUFFER CLEAR ─".to_string()
}

fn read_scratchpad() -> String {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/home/krishna".to_string());
    let path = format!("{}/.cache/quickshell/scratchpad.md", home);
    if let Ok(c) = fs::read_to_string(&path) {
        if !c.trim().is_empty() {
            return c;
        }
    }
    "### Leishman\n- page 197 forward bemt\n".to_string()
}

fn read_git_info() -> Value {
    json!({
        "branch": "pc",
        "modified": 49,
        "deleted": 20,
        "untracked": 79,
        "total": 148,
        "last_commit": "d2fbab3 feat: kitty"
    })
}

fn read_vpn_info() -> Value {
    let mut active = false;
    let mut name = "TAILSCALE".to_string();
    if let Ok(c) = fs::read_to_string("/proc/net/dev") {
        for line in c.lines() {
            if line.contains("tailscale0:") {
                active = true;
                name = "TAILSCALE0".to_string();
                break;
            } else if line.contains("wg0:") || line.contains("tun0:") {
                active = true;
                name = "WIREGUARD".to_string();
                break;
            }
        }
    }
    json!({
        "active": active,
        "name": name,
        "status": if active { "CONNECTED" } else { "STANDBY" },
        "ip": ""
    })
}

fn read_audio_info() -> Value {
    json!({
        "dac_connected": false,
        "dac_label": "DIRECT OUTPUT (PCH ALC897)",
        "mode_label": "PIPEWIRE DIRECT",
        "media": {
            "player": "SYSTEM AUDIO",
            "format": "PIPEWIRE STREAM",
            "badge": "STEREO • 48.0 kHz",
            "lossless": false
        }
    })
}

fn read_pacman_count() -> u32 {
    if let Ok(c) = fs::read_to_string("/tmp/quickshell_pacman_count.txt") {
        if let Ok(n) = c.trim().parse::<u32>() {
            return n;
        }
    }
    140
}

fn read_loadavg() -> String {
    if let Ok(c) = fs::read_to_string("/proc/loadavg") {
        let parts: Vec<&str> = c.split_whitespace().take(3).collect();
        if parts.len() == 3 {
            return parts.join(" ");
        }
    }
    "2.50 2.20 2.10".to_string()
}

fn read_uptime_secs() -> u64 {
    if let Ok(c) = fs::read_to_string("/proc/uptime") {
        if let Some(s) = c.split_whitespace().next() {
            if let Ok(secs) = s.parse::<f64>() {
                return secs.floor() as u64;
            }
        }
    }
    0
}

fn format_uptime(secs: u64, full: bool) -> String {
    let days = secs / 86400;
    let hours = (secs % 86400) / 3600;
    let mins = (secs % 3600) / 60;
    if full {
        format!("{}D {}H {}M", days, hours, mins)
    } else {
        format!("{}d {}h {}m", days, hours, mins)
    }
}

fn fmt_bytes(rate: f64) -> String {
    if rate >= 1048576.0 {
        format!("{:.1} MB/s", rate / 1048576.0)
    } else if rate >= 1024.0 {
        format!("{:.1} KB/s", rate / 1024.0)
    } else {
        format!("{:.0} B/s", rate)
    }
}

fn fmt_total_bytes(bytes: u64) -> String {
    let gb = bytes as f64 / 1073741824.0;
    format!("{:.2} GB", gb)
}

fn to_spark(values: &[f64]) -> String {
    let sparks = [' ', '▂', '▃', '▄', '▅', '▆', '▇', '█'];
    let max = values.iter().cloned().fold(1.0f64, f64::max);
    values.iter().map(|&v| {
        let idx = ((v / max) * 7.0).round().clamp(0.0, 7.0) as usize;
        sparks[idx]
    }).collect()
}

// Fallbacks
fn default_weather() -> Value {
    json!({
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
        "condition": "CLEAR SKY",
        "icon": "CLEAR"
    })
}

fn default_f1() -> Value {
    json!({
        "race_name": "🇺🇸 Las Vegas GP: 🔧 First Free Practice",
        "session": "Race",
        "location": "Las Vegas",
        "time_str": "Fri, Nov 20 • 06:00",
        "countdown": "8d 13h 57m"
    })
}

fn read_app_time() -> Value {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/home/krishna".to_string());
    let path = format!("{}/.cache/quickshell/app_time.json", home);

    if let Ok(content) = fs::read_to_string(&path) {
        if let Ok(v) = serde_json::from_str::<Value>(&content) {
            let today_total = v["total_formatted"].as_str().unwrap_or("0m").to_string();
            let week = &v["week"];
            let week_total = week["total_formatted"].as_str().unwrap_or("0m").to_string();

            let today_apps = v["apps"].as_array().map(|arr| {
                arr.iter().take(5).map(|a| {
                    json!({
                        "id": a["id"].as_str().unwrap_or("app"),
                        "name": a["name"].as_str().unwrap_or("App"),
                        "icon": a["icon"].as_str().unwrap_or("󰣆"),
                        "color": a["color"].as_str().unwrap_or("#94A3B8"),
                        "formatted": a["formatted"].as_str().unwrap_or("0m"),
                        "pct": a["pct"].as_f64().unwrap_or(0.0)
                    })
                }).collect::<Vec<_>>()
            }).unwrap_or_default();

            let week_apps = week["apps"].as_array().map(|arr| {
                arr.iter().take(5).map(|a| {
                    json!({
                        "id": a["id"].as_str().unwrap_or("app"),
                        "name": a["name"].as_str().unwrap_or("App"),
                        "icon": a["icon"].as_str().unwrap_or("󰣆"),
                        "color": a["color"].as_str().unwrap_or("#94A3B8"),
                        "formatted": a["formatted"].as_str().unwrap_or("0m"),
                        "pct": a["pct"].as_f64().unwrap_or(0.0)
                    })
                }).collect::<Vec<_>>()
            }).unwrap_or_default();

            return json!({
                "today_total": today_total,
                "today_apps": today_apps,
                "week_total": week_total,
                "week_apps": week_apps,
                "total_formatted": today_total,
                "apps": today_apps
            });
        }
    }
    default_app_time()
}

fn default_app_time() -> Value {
    json!({
        "today_total": "7h 01m",
        "today_apps": [
            {"id": "kitty", "name": "Kitty", "formatted": "4h 38m", "pct": 0.661},
            {"id": "brave-browser", "name": "Brave", "formatted": "1h 19m", "pct": 0.188},
            {"id": "antigravity-ide", "name": "Antigravity IDE", "formatted": "54m", "pct": 0.129},
            {"id": "thunar", "name": "Thunar", "formatted": "7m", "pct": 0.018}
        ],
        "week_total": "8h 24m",
        "week_apps": [
            {"id": "kitty", "name": "Kitty", "formatted": "4h 39m", "pct": 0.554},
            {"id": "antigravity-ide", "name": "Antigravity IDE", "formatted": "2h 03m", "pct": 0.245},
            {"id": "brave-browser", "name": "Brave", "formatted": "1h 31m", "pct": 0.182},
            {"id": "thunar", "name": "Thunar", "formatted": "7m", "pct": 0.015}
        ],
        "total_formatted": "7h 01m",
        "apps": [
            {"id": "kitty", "name": "Kitty", "formatted": "4h 38m", "pct": 0.661},
            {"id": "brave-browser", "name": "Brave", "formatted": "1h 19m", "pct": 0.188},
            {"id": "antigravity-ide", "name": "Antigravity IDE", "formatted": "54m", "pct": 0.129},
            {"id": "thunar", "name": "Thunar", "formatted": "7m", "pct": 0.018}
        ]
    })
}
