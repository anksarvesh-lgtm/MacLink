// SPDX-License-Identifier: GPL-3.0-or-later
//! External LiquidDynamo helper process management and life-cycle + Native Island Services.

#![allow(unsafe_code)]

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

#[allow(dead_code)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DynamoStatus {
    NotInstalled,
    Installed,
    Running,
}

impl DynamoStatus {
    #[allow(dead_code)]
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

#[allow(dead_code)]
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

#[allow(dead_code)]
pub fn expand() {
    let _ = std::process::Command::new("open")
        .arg("liquiddynamo://expand")
        .status();
}

#[allow(dead_code)]
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

#[cfg(target_os = "macos")]
unsafe extern "C" {
    fn maclink_detect_notch(
        has_notch: *mut bool,
        notch_width: *mut f64,
        notch_height: *mut f64,
        screen_width: *mut f64,
        screen_height: *mut f64,
        notch_min_x: *mut f64,
        notch_max_x: *mut f64,
        aux_left_width: *mut f64,
        aux_right_width: *mut f64,
    );
    fn maclink_get_notch_geometry_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_set_manual_notch_override(width_nudge: f64, height_nudge: f64, radius_nudge: f64);
    fn maclink_set_debug_overlay_enabled(enabled: bool);
    fn maclink_is_debug_overlay_enabled() -> bool;
    fn maclink_get_system_telemetry(cpu_percent: *mut f64, ram_percent: *mut f64);
    fn maclink_position_island_window(x: f64, width: f64, height: f64);

    // Boring Notch Extensions (Reverse engineered from boring.notch)
    fn maclink_init_boring_services();
    fn maclink_configure_notch_drag(min_x: f64, max_x: f64, height: f64);
    fn maclink_start_notch_drag();
    fn maclink_stop_notch_drag();
    fn maclink_is_notch_drag_active() -> bool;
    fn maclink_get_battery_status_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_get_system_media_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_media_play_pause();
    fn maclink_media_next();
    fn maclink_media_previous();
    fn maclink_get_calendar_event_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_register_drag_enter_callback(cb: extern "C" fn());

    // Coucou Extensions (Reverse engineered from coucou / Louis-CFM/coucou)
    fn maclink_init_coucou_services();
    fn maclink_get_mochi_state_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_poke_mochi();
    fn maclink_coucoudoro_start();
    fn maclink_coucoudoro_pause();
    fn maclink_coucoudoro_resume();
    fn maclink_coucoudoro_reset();
    fn maclink_get_coucoudoro_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_get_agent_hook_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_respond_agent_approval(allow: bool);
    fn maclink_take_quick_screenshot();

    // CodeIsland Extensions (Reverse engineered from CodeIsland / wxtsky/CodeIsland)
    fn maclink_get_agent_tasks_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_get_agent_question_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_answer_agent_question(option_index: i32);
    fn maclink_clear_agent_tasks();

    // SquickShare Extensions (Reverse engineered from squick-share / Mukesh-devs/squick-share)
    fn maclink_get_quickshare_state_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_set_quickshare_enabled(enabled: bool);
    fn maclink_set_quickshare_visibility(mode: *const std::os::raw::c_char);
    fn maclink_respond_quickshare_request(accept: bool);
    fn maclink_cancel_quickshare_transfer();
    fn maclink_get_quickshare_trusted_devices_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_add_quickshare_trusted_device(name: *const std::os::raw::c_char, dev_type: *const std::os::raw::c_char);
    fn maclink_remove_quickshare_trusted_device(name: *const std::os::raw::c_char);
    fn maclink_simulate_quickshare_incoming();

    // Atoll Extensions (Reverse engineered from Atoll / Ebullioscopic/Atoll)
    fn maclink_init_atoll_services();
    fn maclink_get_atoll_hud_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_simulate_capslock_toggle();
    fn maclink_simulate_focus_toggle();
    fn maclink_simulate_bluetooth_connect();

    // NotchIsland Extensions (Reverse engineered from NotchIsland / Edwardrem/NotchIsland)
    fn maclink_query_launcher(query: *const std::os::raw::c_char);
    fn maclink_get_launcher_results_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_execute_launcher_item(item_id: *const std::os::raw::c_char);

    // Island Extensions (Reverse engineered from poshak2004/island)
    fn maclink_init_poshak_island_services();
    fn maclink_get_download_tracker_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_cancel_download(download_id: *const std::os::raw::c_char);
    fn maclink_reveal_download(download_id: *const std::os::raw::c_char);
    fn maclink_simulate_download();
    fn maclink_get_privacy_sensors_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_simulate_privacy_mic_toggle();
    fn maclink_simulate_privacy_camera_toggle();

    // Ledge Extensions (Reverse engineered from egemertbalcik/Ledge)
    fn maclink_init_ledge_services();
    fn maclink_get_ledge_announcement_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_trigger_announcement(title: *const std::os::raw::c_char, symbol: *const std::os::raw::c_char, accent: *const std::os::raw::c_char);
    fn maclink_dismiss_announcement();

    // SuperIsland Extensions (Reverse engineered from shobhit99/SuperIsland)
    fn maclink_init_superisland_services();
    fn maclink_get_teleprompter_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_teleprompter_toggle();
    fn maclink_teleprompter_reset();
    fn maclink_teleprompter_dismiss();
    fn maclink_teleprompter_set_script(script: *const std::os::raw::c_char);
    fn maclink_teleprompter_set_speed(speed: f64);
    fn maclink_search_emojis_json(query: *const std::os::raw::c_char, buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_copy_emoji(emoji: *const std::os::raw::c_char);
    fn maclink_get_ai_usage_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_simulate_ai_usage_refresh();

    // MioIsland Extensions (Reverse engineered from MioMioOS/MioIsland)
    fn maclink_init_mioisland_services();
    fn maclink_play_synth_sound(sound: *const std::os::raw::c_char);
    fn maclink_jump_to_terminal(terminal: *const std::os::raw::c_char) -> bool;
    fn maclink_get_terminals_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;

    // Notchly Extensions (Reverse engineered from Notchly/Notchly)
    fn maclink_init_notchly_services();
    fn maclink_get_network_status_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_simulate_network_event(event: *const std::os::raw::c_char);
    fn maclink_get_lock_state() -> bool;

    // QuietNotch Extensions (Reverse engineered from quietapps/QuietNotch)
    fn maclink_init_quietnotch_services();
    fn maclink_get_quietnotch_hud_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_get_quietnotch_notification_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_set_quietnotch_volume(volume: f32);
    fn maclink_set_quietnotch_brightness(brightness: f32);
    fn maclink_simulate_quietnotch_hud(kind: *const std::os::raw::c_char, value: f32);
    fn maclink_send_quietnotch_test_notification(title: *const std::os::raw::c_char, body: *const std::os::raw::c_char, app_name: *const std::os::raw::c_char);
    fn maclink_dismiss_quietnotch_notification();
    fn maclink_set_quiet_hours_enabled(enabled: bool);

    // AnotherNotch Extensions (Reverse engineered from jinkun1998/another.notch)
    fn maclink_init_another_notch_services();
    fn maclink_get_clipboard_history_json(query: *const std::os::raw::c_char, buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_copy_clipboard_entry(id: *const std::os::raw::c_char) -> bool;
    fn maclink_clear_clipboard_history();
    fn maclink_add_clipboard_entry(text: *const std::os::raw::c_char);
    fn maclink_get_fan_telemetry_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_set_fan_mode(mode: *const std::os::raw::c_char);
    fn maclink_simulate_fan_rpm(left: f64, right: f64);

    // GHNotch Extensions (Reverse engineered from aymandakirgh/ghnotch)
    fn maclink_init_ghnotch_services();
    fn maclink_execute_ghnotch_command(cmd: *const std::os::raw::c_char, buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_get_ghnotch_last_result_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;

    // Isle Extensions (Reverse engineered from TheVinizzz/Isle)
    fn maclink_init_isle_services();
    fn maclink_get_isle_finance_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_refresh_isle_finance();
    fn maclink_set_isle_symbol(symbol: *const std::os::raw::c_char);
    fn maclink_simulate_isle_quote(symbol: *const std::os::raw::c_char, price: f64, change: f64);

    // MacIsland Extensions (Reverse engineered from BadRat-in/MacIsland)
    fn macisland_get_battery_status_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn macisland_trigger_airdrop(path: *const std::os::raw::c_char) -> bool;
    fn macisland_simulate_battery(pct: i32, charging: bool);
    fn macisland_reset_battery_simulation();

    // MacWake Extensions (Reverse engineered from Jarvis322/MacWake)
    fn macwake_get_thermal_telemetry_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn macwake_start_cleaning_mode(seconds: i32);
    fn macwake_stop_cleaning_mode();
    fn macwake_get_cleaning_mode_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn macwake_simulate_thermal(cpu: f64, gpu: f64);
    fn macwake_reset_thermal_simulation();

    // PiIsland Extensions (Reverse engineered from phun333/pi-island & jwintz/pi-island)
    fn maclink_get_piisland_sessions_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_simulate_piisland_event(
        agent: *const std::os::raw::c_char,
        model: *const std::os::raw::c_char,
        status: *const std::os::raw::c_char,
        tool: *const std::os::raw::c_char,
    );
    fn maclink_reset_piisland_simulation();

    // Pookify Extensions (Reverse engineered from eyadhammouda/pookify)
    fn maclink_get_pookify_animation_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_simulate_pookify_event(
        state: *const std::os::raw::c_char,
        tool: *const std::os::raw::c_char,
        file: *const std::os::raw::c_char,
    );
    fn maclink_reset_pookify_simulation();

    // WindowsDynamicIsland Vision OCR Extensions (Reverse engineered from HeyyCzer/windows-dynamic-island)
    fn maclink_get_screen_ocr_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_search_screen_text(query: *const std::os::raw::c_char);
    fn maclink_clear_screen_search();
    fn maclink_next_screen_match();
    fn maclink_previous_screen_match();
    fn maclink_simulate_screen_matches(query: *const std::os::raw::c_char, count: i32);

    // TopNotch Focus & Notes Extensions (Reverse engineered from techuila/top-notch)
    fn maclink_get_topnotch_focus_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_topnotch_start_focus(minutes: i32);
    fn maclink_topnotch_pause_focus();
    fn maclink_topnotch_resume_focus();
    fn maclink_topnotch_skip_focus();
    fn maclink_topnotch_reset_focus();
    fn maclink_topnotch_save_note(title: *const std::os::raw::c_char, text: *const std::os::raw::c_char);
    fn maclink_topnotch_delete_note(index: i32);

    // MacIsland2 Video Call Ring Light & Hardware Studio (Reverse engineered from ethantiller/macisland2)
    fn maclink_get_macisland_studio_json(buffer: *mut std::os::raw::c_char, max_len: usize) -> usize;
    fn maclink_macisland_toggle_ring_light();
    fn maclink_macisland_set_ring_light(brightness: f32, width: f32);
    fn maclink_macisland_select_audio_device(device_id: u32);
}

#[cfg(target_os = "macos")]
extern "C" fn on_notch_drag_enter_callback() {
    crate::bridge::app::open_shelf_from_edge();
}

pub fn init_boring_services() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_init_boring_services();
        maclink_register_drag_enter_callback(on_notch_drag_enter_callback);
    }
}

pub fn configure_and_start_notch_drag(min_x: f64, max_x: f64, height: f64) {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_configure_notch_drag(min_x, max_x, height);
        maclink_start_notch_drag();
    }
}

pub fn stop_notch_drag() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_stop_notch_drag();
    }
}

pub fn is_notch_drag_active() -> bool {
    #[cfg(target_os = "macos")]
    unsafe {
        return maclink_is_notch_drag_active();
    }
    #[cfg(not(target_os = "macos"))]
    false
}

pub fn get_battery_status_json() -> String {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 2048];
        let len = unsafe { maclink_get_battery_status_json(buf.as_mut_ptr() as *mut _, buf.len()) };
        if len > 0 {
            if let Ok(s) = std::str::from_utf8(&buf[..len]) {
                return s.to_string();
            }
        }
    }
    r#"{"level":100.0,"isCharging":false,"isPluggedIn":true,"isInLowPowerMode":false,"timeToFullCharge":0,"newlyConnected":false}"#.to_string()
}

pub fn get_system_media_json() -> String {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 4096];
        let len = unsafe { maclink_get_system_media_json(buf.as_mut_ptr() as *mut _, buf.len()) };
        if len > 0 {
            if let Ok(s) = std::str::from_utf8(&buf[..len]) {
                return s.to_string();
            }
        }
    }
    r#"{"hasTrack":false,"player":"","title":"","artist":"","album":"","isPlaying":false,"duration":0.0,"position":0.0}"#.to_string()
}

pub fn media_play_pause() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_media_play_pause();
    }
}

pub fn media_next() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_media_next();
    }
}

pub fn media_previous() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_media_previous();
    }
}

pub fn get_calendar_event_json() -> String {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 2048];
        let len = unsafe { maclink_get_calendar_event_json(buf.as_mut_ptr() as *mut _, buf.len()) };
        if len > 0 {
            if let Ok(s) = std::str::from_utf8(&buf[..len]) {
                return s.to_string();
            }
        }
    }
    r#"{"hasEvent":false,"title":"","startTime":"","endTime":"","minutesUntil":0,"location":"","isOngoing":false}"#.to_string()
}

pub fn open_camera_mirror() {
    // Open standard macOS QuickTime Player / Photo Booth or camera helper cleanly
    let _ = std::process::Command::new("open")
        .args(["-a", "Photo Booth"])
        .status();
}

pub fn get_notch_geometry_json() -> String {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 4096];
        let len = unsafe { maclink_get_notch_geometry_json(buf.as_mut_ptr() as *mut _, buf.len()) };
        if len > 0 {
            if let Ok(s) = std::str::from_utf8(&buf[..len]) {
                return s.to_string();
            }
        }
    }
    r#"{"hasNotch":true,"virtualNotch":false,"isFallback":false,"notchWidth":179.0,"notchHeight":32.0,"notchCenterX":735.0}"#.to_string()
}

pub fn init_coucou_services() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_init_coucou_services();
    }
}

pub fn get_mochi_state_json() -> String {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 2048];
        let len = unsafe { maclink_get_mochi_state_json(buf.as_mut_ptr() as *mut _, buf.len()) };
        if len > 0 {
            if let Ok(s) = std::str::from_utf8(&buf[..len]) {
                return s.to_string();
            }
        }
    }
    r##"{"yaw":0.0,"pitch":0.0,"blink":0.0,"breathScaleY":1.0,"breathScaleX":1.0,"mood":"idle","colorHex":"#EDEDEF","eyeShape":"pill","pokeCount":0}"##.to_string()
}

pub fn poke_mochi() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_poke_mochi();
    }
}

pub fn coucoudoro_start() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_coucoudoro_start();
    }
}

pub fn coucoudoro_pause() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_coucoudoro_pause();
    }
}

pub fn coucoudoro_resume() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_coucoudoro_resume();
    }
}

pub fn coucoudoro_reset() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_coucoudoro_reset();
    }
}

pub fn get_coucoudoro_json() -> String {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 2048];
        let len = unsafe { maclink_get_coucoudoro_json(buf.as_mut_ptr() as *mut _, buf.len()) };
        if len > 0 {
            if let Ok(s) = std::str::from_utf8(&buf[..len]) {
                return s.to_string();
            }
        }
    }
    r#"{"active":false,"phase":"idle","remainingSeconds":1500,"clockString":"25:00","isPaused":false,"workMinutes":25,"restMinutes":5}"#.to_string()
}

pub fn get_agent_hook_json() -> String {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 2048];
        let len = unsafe { maclink_get_agent_hook_json(buf.as_mut_ptr() as *mut _, buf.len()) };
        if len > 0 {
            if let Ok(s) = std::str::from_utf8(&buf[..len]) {
                return s.to_string();
            }
        }
    }
    r#"{"hasSession":false,"agentName":"Antigravity","toolName":"","targetPath":"","diffAdded":0,"diffRemoved":0,"hasApproval":false,"approvalPrompt":""}"#.to_string()
}

pub fn respond_agent_approval(allow: bool) {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_respond_agent_approval(allow);
    }
}

pub fn take_quick_screenshot() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_take_quick_screenshot();
    }
}

pub fn set_manual_notch_override(width_nudge: f64, height_nudge: f64, radius_nudge: f64) {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_set_manual_notch_override(width_nudge, height_nudge, radius_nudge);
    }
}

pub fn set_debug_overlay_enabled(enabled: bool) {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_set_debug_overlay_enabled(enabled);
    }
}

pub fn is_debug_overlay_enabled() -> bool {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_is_debug_overlay_enabled()
    }
    #[cfg(not(target_os = "macos"))]
    false
}

pub fn position_island_window(x: f64, width: f64, height: f64) {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_position_island_window(x, width, height);
    }
}

pub fn get_telemetry_json() -> String {
    #[cfg(target_os = "macos")]
    {
        let mut has_notch = false;
        let mut nw = 0.0;
        let mut nh = 0.0;
        let mut sw = 1920.0;
        let mut sh = 1080.0;
        let mut min_x = 0.0;
        let mut max_x = 0.0;
        let mut aux_left = 960.0;
        let mut aux_right = 960.0;

        unsafe {
            maclink_detect_notch(
                &mut has_notch,
                &mut nw,
                &mut nh,
                &mut sw,
                &mut sh,
                &mut min_x,
                &mut max_x,
                &mut aux_left,
                &mut aux_right,
            );
        }

        let mut cpu = 0.0;
        let mut ram = 0.0;
        unsafe {
            maclink_get_system_telemetry(&mut cpu, &mut ram);
        }

        format!(
            "{{\"cpuPercent\":{:.1},\"ramPercent\":{:.1},\"sample\":{{\"cpuPercent\":{:.1},\"ramPercent\":{:.1}}},\"hasPhysicalNotch\":{},\"layout\":{{\"hasPhysicalNotch\":{},\"notchWidth\":{:.1},\"notchHeight\":{:.1},\"screenWidth\":{:.1},\"screenHeight\":{:.1},\"notchMinX\":{:.1},\"notchMaxX\":{:.1},\"auxLeftWidth\":{:.1},\"auxRightWidth\":{:.1}}}}}",
            cpu, ram, cpu, ram, has_notch, has_notch, nw, nh, sw, sh, min_x, max_x, aux_left, aux_right
        )
    }
    #[cfg(not(target_os = "macos"))]
    {
        let (cpu, ram) = (24.0, 68.0);
        format!(
            "{{\"cpuPercent\":{:.1},\"ramPercent\":{:.1},\"hasPhysicalNotch\":true,\"layout\":{{\"notchWidth\":193.0,\"notchHeight\":32.0}}}}",
            cpu, ram
        )
    }
}

pub fn get_agent_tasks_json() -> String {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 4096];
        let len = unsafe { maclink_get_agent_tasks_json(buf.as_mut_ptr() as *mut _, buf.len()) };
        if len > 0 {
            if let Ok(s) = std::str::from_utf8(&buf[..len]) {
                return s.to_string();
            }
        }
    }
    r#"{"hasTasks":false,"total":0,"completed":0,"inProgress":0,"percent":0.0,"activeTitle":"","isAllCompleted":false,"items":[]}"#.to_string()
}

pub fn get_agent_question_json() -> String {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 4096];
        let len = unsafe { maclink_get_agent_question_json(buf.as_mut_ptr() as *mut _, buf.len()) };
        if len > 0 {
            if let Ok(s) = std::str::from_utf8(&buf[..len]) {
                return s.to_string();
            }
        }
    }
    r#"{"hasQuestion":false,"agentName":"Antigravity","question":"","options":[]}"#.to_string()
}

pub fn answer_agent_question(option_index: i32) {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_answer_agent_question(option_index);
    }
}

pub fn clear_agent_tasks() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_clear_agent_tasks();
    }
}

pub fn get_quickshare_json() -> String {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 8192];
        let len = unsafe { maclink_get_quickshare_state_json(buf.as_mut_ptr() as *mut _, buf.len()) };
        if len > 0 {
            if let Ok(s) = std::str::from_utf8(&buf[..len]) {
                return s.to_string();
            }
        }
    }
    r#"{"enabled":false,"visibility":"hidden","temporaryRemaining":0,"advertisingPort":0,"isAdvertising":false,"hasRequest":false,"transferId":"","deviceName":"","deviceType":"Phone","pin":"","totalBytes":0,"items":[],"isTransferring":false,"transferredBytes":0,"transferRateMBs":"0.0","transferPercent":"0.0","trustedDevices":[]}"#.to_string()
}

pub fn set_quickshare_enabled(enabled: bool) {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_set_quickshare_enabled(enabled);
    }
}

pub fn set_quickshare_visibility(mode: &str) {
    #[cfg(target_os = "macos")]
    if let Ok(c_mode) = std::ffi::CString::new(mode) {
        unsafe {
            maclink_set_quickshare_visibility(c_mode.as_ptr());
        }
    }
}

pub fn respond_quickshare_request(accept: bool) {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_respond_quickshare_request(accept);
    }
}

pub fn cancel_quickshare_transfer() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_cancel_quickshare_transfer();
    }
}

pub fn get_quickshare_trusted_devices_json() -> String {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 4096];
        let len = unsafe { maclink_get_quickshare_trusted_devices_json(buf.as_mut_ptr() as *mut _, buf.len()) };
        if len > 0 {
            if let Ok(s) = std::str::from_utf8(&buf[..len]) {
                return s.to_string();
            }
        }
    }
    "[]".to_string()
}

pub fn add_quickshare_trusted_device(name: &str, dev_type: &str) {
    #[cfg(target_os = "macos")]
    if let (Ok(c_name), Ok(c_type)) = (std::ffi::CString::new(name), std::ffi::CString::new(dev_type)) {
        unsafe {
            maclink_add_quickshare_trusted_device(c_name.as_ptr(), c_type.as_ptr());
        }
    }
}

pub fn remove_quickshare_trusted_device(name: &str) {
    #[cfg(target_os = "macos")]
    if let Ok(c_name) = std::ffi::CString::new(name) {
        unsafe {
            maclink_remove_quickshare_trusted_device(c_name.as_ptr());
        }
    }
}

pub fn simulate_quickshare_incoming() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_simulate_quickshare_incoming();
    }
}

pub fn init_atoll_services() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_init_atoll_services();
    }
}

pub fn get_atoll_hud_json() -> String {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 4096];
        let len = unsafe { maclink_get_atoll_hud_json(buf.as_mut_ptr() as *mut _, buf.len()) };
        if len > 0 {
            if let Ok(s) = std::str::from_utf8(&buf[..len]) {
                return s.to_string();
            }
        }
    }
    r#"{"capsLockActive":false,"capsLockToastActive":false,"focusActive":false,"focusModeName":"Do Not Disturb","focusToastActive":false,"bluetoothConnected":false,"bluetoothDeviceName":"","bluetoothDeviceType":"Headphones","bluetoothBattery":100,"bluetoothToastActive":false}"#.to_string()
}

pub fn simulate_capslock_toggle() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_simulate_capslock_toggle();
    }
}

pub fn simulate_focus_toggle() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_simulate_focus_toggle();
    }
}

pub fn simulate_bluetooth_connect() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_simulate_bluetooth_connect();
    }
}

pub fn query_launcher(query: &str) {
    #[cfg(target_os = "macos")]
    if let Ok(c_query) = std::ffi::CString::new(query) {
        unsafe {
            maclink_query_launcher(c_query.as_ptr());
        }
    }
}

pub fn get_launcher_results_json() -> String {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 8192];
        let len = unsafe { maclink_get_launcher_results_json(buf.as_mut_ptr() as *mut _, buf.len()) };
        if len > 0 {
            if let Ok(s) = std::str::from_utf8(&buf[..len]) {
                return s.to_string();
            }
        }
    }
    "[]".to_string()
}

pub fn execute_launcher_item(item_id: &str) {
    #[cfg(target_os = "macos")]
    if let Ok(c_id) = std::ffi::CString::new(item_id) {
        unsafe {
            maclink_execute_launcher_item(c_id.as_ptr());
        }
    }
}

pub fn init_poshak_island_services() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_init_poshak_island_services();
    }
}

pub fn get_download_tracker_json() -> String {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 8192];
        let len = unsafe { maclink_get_download_tracker_json(buf.as_mut_ptr() as *mut _, buf.len()) };
        if len > 0 {
            if let Ok(s) = std::str::from_utf8(&buf[..len]) {
                return s.to_string();
            }
        }
    }
    r#"{"hasActiveDownloads":false,"activeCount":0,"downloads":[]}"#.to_string()
}

pub fn cancel_download(id: &str) {
    #[cfg(target_os = "macos")]
    if let Ok(c_id) = std::ffi::CString::new(id) {
        unsafe {
            maclink_cancel_download(c_id.as_ptr());
        }
    }
}

pub fn reveal_download(id: &str) {
    #[cfg(target_os = "macos")]
    if let Ok(c_id) = std::ffi::CString::new(id) {
        unsafe {
            maclink_reveal_download(c_id.as_ptr());
        }
    }
}

pub fn simulate_download() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_simulate_download();
    }
}

pub fn get_privacy_sensors_json() -> String {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 2048];
        let len = unsafe { maclink_get_privacy_sensors_json(buf.as_mut_ptr() as *mut _, buf.len()) };
        if len > 0 {
            if let Ok(s) = std::str::from_utf8(&buf[..len]) {
                return s.to_string();
            }
        }
    }
    r#"{"anyActive":false,"micActive":false,"cameraActive":false,"isLiveHardwareMic":false,"isLiveHardwareCam":false}"#.to_string()
}

pub fn simulate_privacy_mic_toggle() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_simulate_privacy_mic_toggle();
    }
}

pub fn simulate_privacy_camera_toggle() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_simulate_privacy_camera_toggle();
    }
}

pub fn init_ledge_services() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_init_ledge_services();
    }
}

pub fn get_ledge_announcement_json() -> String {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 4096];
        let len = unsafe { maclink_get_ledge_announcement_json(buf.as_mut_ptr() as *mut _, buf.len()) };
        if len > 0 {
            if let Ok(s) = std::str::from_utf8(&buf[..len]) {
                return s.to_string();
            }
        }
    }
    r##"{"active":false,"title":"","symbol":"","accent":"#38BDF8","sessions":0}"##.to_string()
}

pub fn trigger_announcement(title: &str, symbol: &str, accent: &str) {
    #[cfg(target_os = "macos")]
    if let (Ok(c_t), Ok(c_s), Ok(c_a)) = (std::ffi::CString::new(title), std::ffi::CString::new(symbol), std::ffi::CString::new(accent)) {
        unsafe {
            maclink_trigger_announcement(c_t.as_ptr(), c_s.as_ptr(), c_a.as_ptr());
        }
    }
}

pub fn dismiss_announcement() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_dismiss_announcement();
    }
}

pub fn init_superisland_services() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_init_superisland_services();
    }
}

pub fn get_teleprompter_json() -> String {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 8192];
        let len = unsafe { maclink_get_teleprompter_json(buf.as_mut_ptr() as *mut _, buf.len()) };
        if len > 0 {
            if let Ok(s) = std::str::from_utf8(&buf[..len]) {
                return s.to_string();
            }
        }
    }
    r#"{"active":false,"isPlaying":false,"isCountingDown":false,"countdown":0,"progress":0.0,"speed":25.0,"fontSize":18.0,"script":""}"#.to_string()
}

pub fn teleprompter_toggle() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_teleprompter_toggle();
    }
}

pub fn teleprompter_reset() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_teleprompter_reset();
    }
}

pub fn teleprompter_dismiss() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_teleprompter_dismiss();
    }
}

pub fn teleprompter_set_script(script: &str) {
    #[cfg(target_os = "macos")]
    if let Ok(c_s) = std::ffi::CString::new(script) {
        unsafe {
            maclink_teleprompter_set_script(c_s.as_ptr());
        }
    }
}

pub fn teleprompter_set_speed(speed: f64) {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_teleprompter_set_speed(speed);
    }
}

pub fn search_emojis_json(query: &str) -> String {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 16384];
        if let Ok(c_q) = std::ffi::CString::new(query) {
            let len = unsafe { maclink_search_emojis_json(c_q.as_ptr(), buf.as_mut_ptr() as *mut _, buf.len()) };
            if len > 0 {
                if let Ok(s) = std::str::from_utf8(&buf[..len]) {
                    return s.to_string();
                }
            }
        }
    }
    "[]".to_string()
}

pub fn copy_emoji(emoji: &str) {
    #[cfg(target_os = "macos")]
    if let Ok(c_e) = std::ffi::CString::new(emoji) {
        unsafe {
            maclink_copy_emoji(c_e.as_ptr());
        }
    }
}

pub fn get_ai_usage_json() -> String {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 4096];
        let len = unsafe { maclink_get_ai_usage_json(buf.as_mut_ptr() as *mut _, buf.len()) };
        if len > 0 {
            if let Ok(s) = std::str::from_utf8(&buf[..len]) {
                return s.to_string();
            }
        }
    }
    r#"{"claudePercent":68.0,"codexPercent":82.0,"claudeTokens":"42.5k / 100k","codexTokens":"18.2k / 100k","status":"Healthy"}"#.to_string()
}

pub fn simulate_ai_usage_refresh() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_simulate_ai_usage_refresh();
    }
}

pub fn init_mioisland_services() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_init_mioisland_services();
    }
}

pub fn play_synth_sound(sound: &str) {
    #[cfg(target_os = "macos")]
    if let Ok(c_s) = std::ffi::CString::new(sound) {
        unsafe {
            maclink_play_synth_sound(c_s.as_ptr());
        }
    }
}

pub fn jump_to_terminal(terminal: &str) -> bool {
    #[cfg(target_os = "macos")]
    if let Ok(c_t) = std::ffi::CString::new(terminal) {
        unsafe {
            return maclink_jump_to_terminal(c_t.as_ptr());
        }
    }
    false
}

pub fn get_running_terminals_json() -> String {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 4096];
        let len = unsafe { maclink_get_terminals_json(buf.as_mut_ptr() as *mut _, buf.len()) };
        if len > 0 {
            if let Ok(s) = std::str::from_utf8(&buf[..len]) {
                return s.to_string();
            }
        }
    }
    r#"{"running":["Terminal"],"preferred":"Terminal"}"#.to_string()
}

pub fn init_notchly_services() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_init_notchly_services();
    }
}

pub fn get_network_status_json() -> String {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 4096];
        let len = unsafe { maclink_get_network_status_json(buf.as_mut_ptr() as *mut _, buf.len()) };
        if len > 0 {
            if let Ok(s) = std::str::from_utf8(&buf[..len]) {
                return s.to_string();
            }
        }
    }
    r#"{"connected":true,"isWiFi":true,"isHotspot":false,"ssid":"Wi-Fi","signalBars":3,"toastActive":false,"toastMessage":""}"#.to_string()
}

pub fn simulate_network_event(event: &str) {
    #[cfg(target_os = "macos")]
    if let Ok(c_e) = std::ffi::CString::new(event) {
        unsafe {
            maclink_simulate_network_event(c_e.as_ptr());
        }
    }
}

pub fn is_screen_locked() -> bool {
    #[cfg(target_os = "macos")]
    unsafe {
        return maclink_get_lock_state();
    }
    #[allow(unreachable_code)]
    false
}

pub fn init_quietnotch_services() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_init_quietnotch_services();
    }
}

pub fn get_quietnotch_hud_json() -> String {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 4096];
        let len = unsafe { maclink_get_quietnotch_hud_json(buf.as_mut_ptr() as *mut _, buf.len()) };
        if len > 0 {
            if let Ok(s) = std::str::from_utf8(&buf[..len]) {
                return s.to_string();
            }
        }
    }
    r#"{"visible":false,"kind":"volume","value":0.5,"isMuted":false,"title":"50%"}"#.to_string()
}

pub fn get_quietnotch_notification_json() -> String {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 4096];
        let len = unsafe { maclink_get_quietnotch_notification_json(buf.as_mut_ptr() as *mut _, buf.len()) };
        if len > 0 {
            if let Ok(s) = std::str::from_utf8(&buf[..len]) {
                return s.to_string();
            }
        }
    }
    r#"{"hasNotification":false,"title":"","body":"","appName":"","quietHours":false,"timestamp":0.0}"#.to_string()
}

pub fn set_quietnotch_volume(vol: f32) {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_set_quietnotch_volume(vol);
    }
}

pub fn set_quietnotch_brightness(br: f32) {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_set_quietnotch_brightness(br);
    }
}

pub fn simulate_quietnotch_hud(kind: &str, value: f32) {
    #[cfg(target_os = "macos")]
    if let Ok(c_kind) = std::ffi::CString::new(kind) {
        unsafe {
            maclink_simulate_quietnotch_hud(c_kind.as_ptr(), value);
        }
    }
}

pub fn send_quietnotch_test_notification(title: &str, body: &str, app: &str) {
    #[cfg(target_os = "macos")]
    if let (Ok(c_t), Ok(c_b), Ok(c_a)) = (
        std::ffi::CString::new(title),
        std::ffi::CString::new(body),
        std::ffi::CString::new(app),
    ) {
        unsafe {
            maclink_send_quietnotch_test_notification(c_t.as_ptr(), c_b.as_ptr(), c_a.as_ptr());
        }
    }
}

pub fn dismiss_quietnotch_notification() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_dismiss_quietnotch_notification();
    }
}

pub fn set_quiet_hours_enabled(enabled: bool) {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_set_quiet_hours_enabled(enabled);
    }
}

pub fn init_another_notch_services() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_init_another_notch_services();
    }
}

pub fn get_clipboard_history_json(query: &str) -> String {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 524_288];
        let c_q = std::ffi::CString::new(query).unwrap_or_default();
        let len = unsafe { maclink_get_clipboard_history_json(c_q.as_ptr(), buf.as_mut_ptr() as *mut _, buf.len()) };
        if len > 0 {
            if let Ok(s) = std::str::from_utf8(&buf[..len]) {
                return s.to_string();
            }
        }
    }
    "[]".to_string()
}

pub fn copy_clipboard_entry(id: &str) -> bool {
    #[cfg(target_os = "macos")]
    if let Ok(c_id) = std::ffi::CString::new(id) {
        unsafe {
            return maclink_copy_clipboard_entry(c_id.as_ptr());
        }
    }
    false
}

pub fn clear_clipboard_history() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_clear_clipboard_history();
    }
}

pub fn add_clipboard_entry(text: &str) {
    #[cfg(target_os = "macos")]
    if let Ok(c_text) = std::ffi::CString::new(text) {
        unsafe {
            maclink_add_clipboard_entry(c_text.as_ptr());
        }
    }
}

pub fn get_fan_telemetry_json() -> String {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 4096];
        let len = unsafe { maclink_get_fan_telemetry_json(buf.as_mut_ptr() as *mut _, buf.len()) };
        if len > 0 {
            if let Ok(s) = std::str::from_utf8(&buf[..len]) {
                return s.to_string();
            }
        }
    }
    r#"{"hasFans":true,"leftRPM":1850,"rightRPM":1820,"minRPM":1200,"maxRPM":6000,"mode":"auto","fanPercentage":25,"cpuTempC":42.5}"#.to_string()
}

pub fn set_fan_mode(mode: &str) {
    #[cfg(target_os = "macos")]
    if let Ok(c_mode) = std::ffi::CString::new(mode) {
        unsafe {
            maclink_set_fan_mode(c_mode.as_ptr());
        }
    }
}

pub fn simulate_fan_rpm(left: f64, right: f64) {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_simulate_fan_rpm(left, right);
    }
}

pub fn init_ghnotch_services() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_init_ghnotch_services();
    }
}

pub fn execute_ghnotch_command(cmd: &str) -> String {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 4096];
        if let Ok(c_cmd) = std::ffi::CString::new(cmd) {
            let len = unsafe { maclink_execute_ghnotch_command(c_cmd.as_ptr(), buf.as_mut_ptr() as *mut _, buf.len()) };
            if len > 0 {
                if let Ok(s) = std::str::from_utf8(&buf[..len]) {
                    return s.to_string();
                }
            }
        }
    }
    String::new()
}

pub fn get_ghnotch_last_result_json() -> String {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 4096];
        let len = unsafe { maclink_get_ghnotch_last_result_json(buf.as_mut_ptr() as *mut _, buf.len()) };
        if len > 0 {
            if let Ok(s) = std::str::from_utf8(&buf[..len]) {
                return s.to_string();
            }
        }
    }
    r#"{"hasResult":false,"input":"","output":"","handledLocally":true,"timestamp":0.0}"#.to_string()
}

pub fn init_isle_services() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_init_isle_services();
    }
}

pub fn get_isle_finance_json() -> String {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 4096];
        let len = unsafe { maclink_get_isle_finance_json(buf.as_mut_ptr() as *mut _, buf.len()) };
        if len > 0 {
            if let Ok(s) = std::str::from_utf8(&buf[..len]) {
                return s.to_string();
            }
        }
    }
    r#"{"symbol":"BTC","name":"Bitcoin","price":91420.0,"formattedPrice":"$91,420","pctChange":3.14,"isUp":true,"lastUpdated":0.0,"quotes":[]}"#.to_string()
}

pub fn refresh_isle_finance() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_refresh_isle_finance();
    }
}

pub fn set_isle_symbol(symbol: &str) {
    #[cfg(target_os = "macos")]
    if let Ok(c_sym) = std::ffi::CString::new(symbol) {
        unsafe {
            maclink_set_isle_symbol(c_sym.as_ptr());
        }
    }
}

pub fn simulate_isle_quote(symbol: &str, price: f64, change: f64) {
    #[cfg(target_os = "macos")]
    if let Ok(c_sym) = std::ffi::CString::new(symbol) {
        unsafe {
            maclink_simulate_isle_quote(c_sym.as_ptr(), price, change);
        }
    }
}

pub fn get_macisland_battery_json() -> String {
    #[cfg(target_os = "macos")]
    unsafe {
        let mut buf = vec![0u8; 4096];
        let len = macisland_get_battery_status_json(buf.as_mut_ptr() as *mut _, buf.len());
        if len > 0 {
            buf.truncate(len);
            if let Ok(s) = String::from_utf8(buf) {
                return s;
            }
        }
    }
    "{}".to_string()
}

pub fn trigger_airdrop(path: &str) -> bool {
    #[cfg(target_os = "macos")]
    unsafe {
        if let Ok(c_path) = std::ffi::CString::new(path) {
            return macisland_trigger_airdrop(c_path.as_ptr());
        }
        return macisland_trigger_airdrop(std::ptr::null());
    }
    #[cfg(not(target_os = "macos"))]
    false
}

pub fn simulate_macisland_battery(pct: i32, charging: bool) {
    #[cfg(target_os = "macos")]
    unsafe {
        macisland_simulate_battery(pct, charging);
    }
}

pub fn reset_macisland_battery() {
    #[cfg(target_os = "macos")]
    unsafe {
        macisland_reset_battery_simulation();
    }
}

pub fn get_macwake_thermal_json() -> String {
    #[cfg(target_os = "macos")]
    unsafe {
        let mut buf = vec![0u8; 4096];
        let len = macwake_get_thermal_telemetry_json(buf.as_mut_ptr() as *mut _, buf.len());
        if len > 0 {
            buf.truncate(len);
            if let Ok(s) = String::from_utf8(buf) {
                return s;
            }
        }
    }
    "{}".to_string()
}

pub fn start_cleaning_mode(seconds: i32) {
    #[cfg(target_os = "macos")]
    unsafe {
        macwake_start_cleaning_mode(seconds);
    }
}

pub fn stop_cleaning_mode() {
    #[cfg(target_os = "macos")]
    unsafe {
        macwake_stop_cleaning_mode();
    }
}

pub fn get_macwake_cleaning_json() -> String {
    #[cfg(target_os = "macos")]
    unsafe {
        let mut buf = vec![0u8; 4096];
        let len = macwake_get_cleaning_mode_json(buf.as_mut_ptr() as *mut _, buf.len());
        if len > 0 {
            buf.truncate(len);
            if let Ok(s) = String::from_utf8(buf) {
                return s;
            }
        }
    }
    "{}".to_string()
}

pub fn simulate_macwake_thermal(cpu: f64, gpu: f64) {
    #[cfg(target_os = "macos")]
    unsafe {
        macwake_simulate_thermal(cpu, gpu);
    }
}

pub fn reset_macwake_thermal() {
    #[cfg(target_os = "macos")]
    unsafe {
        macwake_reset_thermal_simulation();
    }
}

pub fn get_piisland_sessions_json() -> String {
    #[cfg(target_os = "macos")]
    unsafe {
        let mut buf = vec![0u8; 8192];
        let len = maclink_get_piisland_sessions_json(buf.as_mut_ptr() as *mut _, buf.len());
        if len > 0 {
            buf.truncate(len);
            if let Ok(s) = String::from_utf8(buf) {
                return s;
            }
        }
    }
    "{}".to_string()
}

pub fn simulate_piisland_event(agent: &str, model: &str, status: &str, tool: &str) {
    #[cfg(target_os = "macos")]
    if let (Ok(c_a), Ok(c_m), Ok(c_s), Ok(c_t)) = (
        std::ffi::CString::new(agent),
        std::ffi::CString::new(model),
        std::ffi::CString::new(status),
        std::ffi::CString::new(tool),
    ) {
        unsafe {
            maclink_simulate_piisland_event(c_a.as_ptr(), c_m.as_ptr(), c_s.as_ptr(), c_t.as_ptr());
        }
    }
}

pub fn reset_piisland_simulation() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_reset_piisland_simulation();
    }
}

pub fn get_pookify_animation_json() -> String {
    #[cfg(target_os = "macos")]
    unsafe {
        let mut buf = vec![0u8; 8192];
        let len = maclink_get_pookify_animation_json(buf.as_mut_ptr() as *mut _, buf.len());
        if len > 0 {
            buf.truncate(len);
            if let Ok(s) = String::from_utf8(buf) {
                return s;
            }
        }
    }
    "{}".to_string()
}

pub fn simulate_pookify_event(state: &str, tool: &str, file: &str) {
    #[cfg(target_os = "macos")]
    if let (Ok(c_s), Ok(c_t), Ok(c_f)) = (
        std::ffi::CString::new(state),
        std::ffi::CString::new(tool),
        std::ffi::CString::new(file),
    ) {
        unsafe {
            maclink_simulate_pookify_event(c_s.as_ptr(), c_t.as_ptr(), c_f.as_ptr());
        }
    }
}

pub fn reset_pookify_simulation() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_reset_pookify_simulation();
    }
}

pub fn get_screen_ocr_json() -> String {
    #[cfg(target_os = "macos")]
    unsafe {
        let mut buf = vec![0u8; 8192];
        let len = maclink_get_screen_ocr_json(buf.as_mut_ptr() as *mut _, buf.len());
        if len > 0 {
            buf.truncate(len);
            if let Ok(s) = String::from_utf8(buf) {
                return s;
            }
        }
    }
    "{}".to_string()
}

pub fn search_screen_text(query: &str) {
    #[cfg(target_os = "macos")]
    if let Ok(c_q) = std::ffi::CString::new(query) {
        unsafe {
            maclink_search_screen_text(c_q.as_ptr());
        }
    }
}

pub fn clear_screen_search() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_clear_screen_search();
    }
}

pub fn next_screen_match() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_next_screen_match();
    }
}

pub fn previous_screen_match() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_previous_screen_match();
    }
}

pub fn simulate_screen_matches(query: &str, count: i32) {
    #[cfg(target_os = "macos")]
    if let Ok(c_q) = std::ffi::CString::new(query) {
        unsafe {
            maclink_simulate_screen_matches(c_q.as_ptr(), count);
        }
    }
}

pub fn get_topnotch_focus_json() -> String {
    #[cfg(target_os = "macos")]
    unsafe {
        let mut buf = vec![0u8; 8192];
        let len = maclink_get_topnotch_focus_json(buf.as_mut_ptr() as *mut _, buf.len());
        if len > 0 {
            buf.truncate(len);
            if let Ok(s) = String::from_utf8(buf) {
                return s;
            }
        }
    }
    "{}".to_string()
}

pub fn topnotch_start_focus(minutes: i32) {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_topnotch_start_focus(minutes);
    }
}

pub fn topnotch_pause_focus() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_topnotch_pause_focus();
    }
}

pub fn topnotch_resume_focus() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_topnotch_resume_focus();
    }
}

pub fn topnotch_skip_focus() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_topnotch_skip_focus();
    }
}

pub fn topnotch_reset_focus() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_topnotch_reset_focus();
    }
}

pub fn topnotch_save_note(title: &str, text: &str) {
    #[cfg(target_os = "macos")]
    if let (Ok(c_t), Ok(c_txt)) = (std::ffi::CString::new(title), std::ffi::CString::new(text)) {
        unsafe {
            maclink_topnotch_save_note(c_t.as_ptr(), c_txt.as_ptr());
        }
    }
}

pub fn topnotch_delete_note(index: i32) {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_topnotch_delete_note(index);
    }
}

pub fn get_macisland_studio_json() -> String {
    #[cfg(target_os = "macos")]
    unsafe {
        let mut buf = vec![0u8; 8192];
        let len = maclink_get_macisland_studio_json(buf.as_mut_ptr() as *mut _, buf.len());
        if len > 0 {
            buf.truncate(len);
            if let Ok(s) = String::from_utf8(buf) {
                return s;
            }
        }
    }
    "{}".to_string()
}

pub fn macisland_toggle_ring_light() {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_macisland_toggle_ring_light();
    }
}

pub fn macisland_set_ring_light(brightness: f32, width: f32) {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_macisland_set_ring_light(brightness, width);
    }
}

pub fn macisland_select_audio_device(device_id: u32) {
    #[cfg(target_os = "macos")]
    unsafe {
        maclink_macisland_select_audio_device(device_id);
    }
}







