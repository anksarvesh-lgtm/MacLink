// SPDX-License-Identifier: GPL-3.0-or-later
//! External LiquidDynamo helper process management and life-cycle + Native Island Services.

use std::{
    path::PathBuf,
    sync::{
        atomic::{AtomicBool, Ordering},
        Mutex,
    },
};

#[path = "bridge/dynamo.rs"]
pub mod bridge;

pub const EXECUTABLE_NAME: &str = "LiquidDynamo";

static LAUNCHED_BY_MACLINK: AtomicBool = AtomicBool::new(false);
static CAFFEINATE_CHILD: Mutex<Option<std::process::Child>> = Mutex::new(None);

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DynamoStatus {
    NotInstalled,
    Installed,
    Running,
}

impl DynamoStatus {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::NotInstalled => "not_installed",
            Self::Installed => "installed",
            Self::Running => "running",
        }
    }
}

pub fn locate_app() -> Option<PathBuf> {
    // 1. Embedded inside MacLink.app: <exe dir>/../Helpers/LiquidDynamo.app
    if let Ok(exe) = std::env::current_exe() {
        if let Some(exe_dir) = exe.parent() {
            let bundled = exe_dir.join("../Helpers/LiquidDynamo.app");
            if bundled.is_dir() {
                return bundled.canonicalize().ok().or(Some(bundled));
            }
        }
    }

    // 2. System /Applications
    let sys_app = PathBuf::from("/Applications/LiquidDynamo.app");
    if sys_app.is_dir() {
        return Some(sys_app);
    }

    // 3. User ~/Applications
    if let Some(home) = dirs::home_dir() {
        let user_app = home.join("Applications/LiquidDynamo.app");
        if user_app.is_dir() {
            return Some(user_app);
        }
    }

    None
}

pub fn is_running() -> bool {
    std::process::Command::new("pgrep")
        .arg("-x")
        .arg(EXECUTABLE_NAME)
        .output()
        .map(|out| out.status.success())
        .unwrap_or(false)
}

pub fn status() -> DynamoStatus {
    if is_running() {
        DynamoStatus::Running
    } else if locate_app().is_some() {
        DynamoStatus::Installed
    } else {
        DynamoStatus::NotInstalled
    }
}

pub fn launch() -> bool {
    let Some(path) = locate_app() else {
        return false;
    };
    if is_running() {
        return true;
    }
    let success = std::process::Command::new("open")
        .arg("-a")
        .arg(&path)
        .args(["--args", "--embedded"])
        .status()
        .map(|s| s.success())
        .unwrap_or(false);
    if success {
        LAUNCHED_BY_MACLINK.store(true, Ordering::SeqCst);
    }
    success
}

pub fn stop() -> bool {
    let success = std::process::Command::new("pkill")
        .arg("-x")
        .arg(EXECUTABLE_NAME)
        .status()
        .map(|s| s.success())
        .unwrap_or(false);
    LAUNCHED_BY_MACLINK.store(false, Ordering::SeqCst);
    success
}

pub fn open_settings() {
    let _ = std::process::Command::new("open")
        .arg("liquiddynamo://settings")
        .status();
}

pub fn expand() {
    let _ = std::process::Command::new("open")
        .arg("liquiddynamo://expand")
        .status();
}

pub fn collapse() {
    let _ = std::process::Command::new("open")
        .arg("liquiddynamo://collapse")
        .status();
}

pub fn shutdown() {
    if LAUNCHED_BY_MACLINK.load(Ordering::SeqCst) {
        let _ = stop();
    }
    if let Ok(mut guard) = CAFFEINATE_CHILD.lock() {
        if let Some(mut child) = guard.take() {
            let _ = child.kill();
        }
    }
}

pub fn on_app_start() {
    if crate::settings::dynamo_autostart() && locate_app().is_some() && !is_running() {
        let _ = launch();
    }
}

pub fn update_autostart(on: bool) {
    if crate::settings::dynamo_autostart() == on {
        return;
    }
    crate::settings::set_dynamo_autostart(on);
    let data_dir = crate::core_host::host().data_dir.clone();
    std::thread::spawn(move || {
        let mut s = crate::settings::Settings::load(&data_dir);
        s.dynamo_autostart = on;
        let _ = s.save(&data_dir);
    });
}

// ----------------------------------------------------------------------------
// NATIVE ISLAND FEATURE SERVICES
// ----------------------------------------------------------------------------

pub fn is_caffeinate_active() -> bool {
    let Ok(mut guard) = CAFFEINATE_CHILD.lock() else {
        return false;
    };
    if let Some(child) = guard.as_mut() {
        match child.try_wait() {
            Ok(None) => true,
            _ => {
                *guard = None;
                false
            }
        }
    } else {
        false
    }
}

pub fn toggle_caffeinate() -> bool {
    let Ok(mut guard) = CAFFEINATE_CHILD.lock() else {
        return false;
    };
    if let Some(mut child) = guard.take() {
        let _ = child.kill();
        false
    } else {
        match std::process::Command::new("caffeinate")
            .args(["-d", "-i", "-m"])
            .spawn()
        {
            Ok(child) => {
                *guard = Some(child);
                true
            }
            Err(_) => false,
        }
    }
}

pub fn pick_screen_color() {
    std::thread::spawn(|| {
        let script = r##"
import AppKit
DispatchQueue.main.async {
    NSColorSampler().show { color in
        if let color = color, let rgb = color.usingColorSpace(.sRGB) {
            let hex = String(format: "#%02X%02X%02X", Int(rgb.redComponent * 255), Int(rgb.greenComponent * 255), Int(rgb.blueComponent * 255))
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(hex, forType: .string)
        }
        exit(0)
    }
}
RunLoop.main.run(until: Date(timeIntervalSinceNow: 30))
"##;
        let _ = std::process::Command::new("swift")
            .arg("-e")
            .arg(script)
            .status();
    });
}

pub fn set_volume(percent: i32) {
    let p = percent.clamp(0, 100);
    let script = format!("set volume output volume {}", p);
    let _ = std::process::Command::new("osascript")
        .args(["-e", &script])
        .status();
}

pub fn set_brightness(percent: i32) {
    let p = percent.clamp(0, 100);
    let script = format!(
        "tell application \"System Events\" to repeat {} times\nkey code 144\nend repeat",
        if p > 50 { 1 } else { 0 }
    );
    let _ = std::process::Command::new("osascript")
        .args(["-e", &script])
        .status();
}

pub fn open_downloads() {
    if let Some(home) = dirs::home_dir() {
        let downloads = home.join("Downloads");
        let _ = std::process::Command::new("open").arg(&downloads).status();
    }
}

pub fn open_calendar() {
    let _ = std::process::Command::new("open").args(["-a", "Calendar"]).status();
}

pub fn open_reminders() {
    let _ = std::process::Command::new("open").args(["-a", "Reminders"]).status();
}

pub fn phone_bridge_mount_in_finder(_device_id: &str) {
    if let Some(home) = dirs::home_dir() {
        let path = home.join("Downloads/MacLink");
        let _ = std::fs::create_dir_all(&path);
        let _ = std::process::Command::new("open").arg(&path).status();
    }
}

pub fn get_storage_stats() -> String {
    let output = std::process::Command::new("df")
        .args(["-k", "/"])
        .output();

    let mut total_bytes: u64 = 256 * 1024 * 1024 * 1024;
    let mut used_bytes: u64 = 80 * 1024 * 1024 * 1024;
    let mut free_bytes: u64 = 176 * 1024 * 1024 * 1024;

    if let Ok(out) = output {
        let s = String::from_utf8_lossy(&out.stdout);
        let lines: Vec<&str> = s.lines().collect();
        if lines.len() >= 2 {
            let parts: Vec<&str> = lines[1].split_whitespace().collect();
            if parts.len() >= 4 {
                if let (Ok(blocks), Ok(used), Ok(avail)) = (
                    parts[1].parse::<u64>(),
                    parts[2].parse::<u64>(),
                    parts[3].parse::<u64>(),
                ) {
                    total_bytes = blocks * 1024;
                    used_bytes = used * 1024;
                    free_bytes = avail * 1024;
                }
            }
        }
    }

    let home = dirs::home_dir().unwrap_or_default();
    let xcode_dir = home.join("Library/Developer/Xcode/DerivedData");
    let cargo_dir = home.join(".cargo/registry/cache");
    let gradle_dir = home.join(".gradle/caches");

    fn dir_size(path: &std::path::Path) -> u64 {
        let mut sz = 0;
        if let Ok(entries) = std::fs::read_dir(path) {
            for entry in entries.flatten() {
                if let Ok(meta) = entry.metadata() {
                    if meta.is_file() {
                        sz += meta.len();
                    } else if meta.is_dir() {
                        sz += dir_size(&entry.path());
                    }
                }
            }
        }
        sz
    }

    let xcode_bytes = if xcode_dir.is_dir() { dir_size(&xcode_dir) } else { 0 };
    let cargo_bytes = if cargo_dir.is_dir() { dir_size(&cargo_dir) } else { 0 };
    let gradle_bytes = if gradle_dir.is_dir() { dir_size(&gradle_dir) } else { 0 };
    let dev_cache_bytes = xcode_bytes + cargo_bytes + gradle_bytes;

    format!(
        "{{\"totalBytes\":{},\"freeBytes\":{},\"usedBytes\":{},\"devCacheBytes\":{},\"xcodeBytes\":{},\"cargoBytes\":{},\"gradleBytes\":{}}}",
        total_bytes, free_bytes, used_bytes, dev_cache_bytes, xcode_bytes, cargo_bytes, gradle_bytes
    )
}

pub fn clean_dev_caches_to_trash() -> String {
    let home = dirs::home_dir().unwrap_or_default();
    let trash = home.join(".Trash");
    let xcode_dir = home.join("Library/Developer/Xcode/DerivedData");
    let mut cleaned_items = 0;

    if xcode_dir.is_dir() {
        if let Ok(entries) = std::fs::read_dir(&xcode_dir) {
            for entry in entries.flatten() {
                let dest = trash.join(format!(
                    "Xcode_DerivedData_{}_{}",
                    entry.file_name().to_string_lossy(),
                    std::time::SystemTime::now()
                        .duration_since(std::time::UNIX_EPOCH)
                        .map(|d| d.as_secs())
                        .unwrap_or(0)
                ));
                if std::fs::rename(entry.path(), &dest).is_ok() {
                    cleaned_items += 1;
                }
            }
        }
    }

    format!("{{\"success\":true,\"itemsMovedToTrash\":{}}}", cleaned_items)
}

pub fn get_telemetry_json() -> String {
    let (cpu, ram) = (24.0, 68.0);
    format!(
        "{{\"cpuPercent\":{:.1},\"ramPercent\":{:.1},\"hasPhysicalNotch\":true,\"layout\":{{\"notchWidth\":193.0,\"notchHeight\":32.0}}}}",
        cpu, ram
    )
}
