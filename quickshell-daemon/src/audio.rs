use std::fs::{self, OpenOptions};
use std::io::Read;
use std::path::Path;
use std::process::Command;
use std::thread;
use std::time::{Duration, Instant};

const NUM_BANDS: usize = 24;
const FIFO_PATH: &str = "/tmp/cava.fifo";
const CONFIG_PATH: &str = "/home/krishna/.config/cava/quickshell_config";
const GRAVITY: f64 = 6.5;
const PEAK_GRAVITY: f64 = 5.2;
const PEAK_LATCH_SEC: f64 = 0.35;

fn ensure_cava_running() {
    // Check if cava is already running with quickshell_config
    if let Ok(output) = Command::new("pgrep").args(["-f", "cava -p.*quickshell_config"]).output() {
        if output.status.success() && !output.stdout.is_empty() {
            return;
        }
    }

    // Create FIFO if it doesn't exist
    if !Path::new(FIFO_PATH).exists() {
        let _ = Command::new("mkfifo").arg(FIFO_PATH).status();
    }

    // Spawn headless cava in background
    let _ = Command::new("cava")
        .args(["-p", CONFIG_PATH])
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .spawn();
}

pub fn run_audio_engine() {
    ensure_cava_running();

    let mut smooth_bars = [0.0f64; NUM_BANDS];
    let mut peak_heights = [0.0f64; NUM_BANDS];
    let mut peak_velocities = [0.0f64; NUM_BANDS];
    let mut peak_times = [Instant::now(); NUM_BANDS];
    let mut last_instant = Instant::now();

    loop {
        ensure_cava_running();

        let mut file = match OpenOptions::new().read(true).open(FIFO_PATH) {
            Ok(f) => f,
            Err(_) => {
                thread::sleep(Duration::from_millis(100));
                continue;
            }
        };

        let mut buf = [0u8; NUM_BANDS];
        loop {
            match file.read_exact(&mut buf) {
                Ok(_) => {
                    let now = Instant::now();
                    let dt = (now.duration_since(last_instant).as_secs_f64()).clamp(0.001, 0.05);
                    last_instant = now;

                    // Apply calibrated musical transient attack & fluid gravity falloff
                    for i in 0..NUM_BANDS {
                        let raw_val = (buf[i] as f64) / 255.0;
                        let cur = smooth_bars[i];
                        if raw_val >= cur {
                            // Rises to transient peak smoothly in ~30ms (no single-frame ceiling slapping)
                            smooth_bars[i] = cur + (raw_val - cur) * 0.72;
                        } else {
                            // Fluid physical gravity falloff
                            let decay_step = 0.012f64.max((cur - raw_val) * 0.32);
                            smooth_bars[i] = raw_val.max(cur - decay_step);
                        }

                        // Peak hold with 350ms latch
                        let h = smooth_bars[i];
                        let cur_pk = peak_heights[i];
                        if h >= cur_pk {
                            peak_heights[i] = h;
                            peak_velocities[i] = 0.0;
                            peak_times[i] = now;
                        } else {
                            if now.duration_since(peak_times[i]).as_secs_f64() >= PEAK_LATCH_SEC {
                                peak_velocities[i] += PEAK_GRAVITY * dt;
                                peak_heights[i] = (cur_pk - peak_velocities[i] * dt).max(0.0);
                            }
                        }
                    }

                    // Print JSON packet directly to stdout at 60 FPS
                    print!("{{\"bands\":[");
                    for i in 0..NUM_BANDS {
                        if i > 0 { print!(","); }
                        print!("{:.3}", smooth_bars[i]);
                    }
                    print!("],\"peaks\":[");
                    for i in 0..NUM_BANDS {
                        if i > 0 { print!(","); }
                        print!("{:.3}", peak_heights[i]);
                    }
                    println!("]}}");
                }
                Err(_) => {
                    break;
                }
            }
        }

        thread::sleep(Duration::from_millis(50));
    }
}
