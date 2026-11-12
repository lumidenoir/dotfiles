#![recursion_limit = "256"]

mod audio;
mod telemetry;

use std::env;

fn main() {
    let args: Vec<String> = env::args().collect();
    let cmd = if args.len() > 1 {
        args[1].as_str()
    } else {
        "audio"
    };

    match cmd {
        "audio" => {
            audio::run_audio_engine();
        }
        "telemetry" => {
            let data = telemetry::gather_telemetry();
            println!("{}", data);
        }
        _ => {
            eprintln!("Usage: quickshell-daemon [audio | telemetry]");
        }
    }
}
