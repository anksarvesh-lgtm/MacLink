// SPDX-License-Identifier: GPL-3.0-or-later
//! `DynamoController`: QML singleton exposing LiquidDynamo and Native Island controls to QML.

#![allow(unsafe_code)]

use std::pin::Pin;
use std::sync::{Mutex, OnceLock};
use cxx_qt::{CxxQtThread, Threading};
use cxx_qt_lib::QString;

static DYNAMO_QT_THREAD: OnceLock<Mutex<Option<CxxQtThread<qobject::DynamoController>>>> = OnceLock::new();

#[unsafe(no_mangle)]
pub extern "C" fn maclink_set_island_hover_state(expanded: bool) {
    if let Some(lock) = DYNAMO_QT_THREAD.get() {
        if let Ok(guard) = lock.lock() {
            if let Some(thread) = guard.as_ref() {
                let _ = thread.queue(move |mut qobj| {
                    if *qobj.as_ref().island_expanded() != expanded {
                        qobj.as_mut().set_island_expanded(expanded);
                    }
                });
            }
        }
    }
}

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qml_singleton]
        #[qproperty(QString, status)]
        #[qproperty(QString, installed_path, cxx_name = "installedPath")]
        #[qproperty(bool, is_running, cxx_name = "isRunning")]
        #[qproperty(bool, is_installed, cxx_name = "isInstalled")]
        #[qproperty(bool, autostart)]
        #[qproperty(bool, island_expanded, cxx_name = "islandExpanded")]
        #[qproperty(QString, telemetry_json, cxx_name = "telemetryJson")]
        #[qproperty(QString, system_hud_json, cxx_name = "systemHudJson")]
        #[qproperty(QString, privacy_guard_json, cxx_name = "privacyGuardJson")]
        #[qproperty(bool, caffeinate_active, cxx_name = "caffeinateActive")]
        #[qproperty(QString, notch_geometry_json, cxx_name = "notchGeometryJson")]
        #[qproperty(bool, debug_overlay_enabled, cxx_name = "debugOverlayEnabled")]
        #[qproperty(QString, battery_json, cxx_name = "batteryJson")]
        #[qproperty(QString, system_media_json, cxx_name = "systemMediaJson")]
        #[qproperty(QString, calendar_json, cxx_name = "calendarJson")]
        #[qproperty(bool, notch_drag_active, cxx_name = "notchDragActive")]
        #[qproperty(QString, mochi_json, cxx_name = "mochiJson")]
        #[qproperty(QString, coucoudoro_json, cxx_name = "coucoudoroJson")]
        #[qproperty(QString, agent_hook_json, cxx_name = "agentHookJson")]
        #[qproperty(QString, agent_tasks_json, cxx_name = "agentTasksJson")]
        #[qproperty(QString, agent_question_json, cxx_name = "agentQuestionJson")]
        #[qproperty(QString, quickshare_json, cxx_name = "quickshareJson")]
        #[qproperty(QString, quickshare_trusted_json, cxx_name = "quickshareTrustedJson")]
        #[qproperty(QString, atoll_hud_json, cxx_name = "atollHudJson")]
        #[qproperty(QString, launcher_results_json, cxx_name = "launcherResultsJson")]
        #[qproperty(QString, downloads_json, cxx_name = "downloadsJson")]
        #[qproperty(QString, privacy_sensors_json, cxx_name = "privacySensorsJson")]
        #[qproperty(QString, ledge_announcement_json, cxx_name = "ledgeAnnouncementJson")]
        #[qproperty(QString, teleprompter_json, cxx_name = "teleprompterJson")]
        #[qproperty(QString, emoji_results_json, cxx_name = "emojiResultsJson")]
        #[qproperty(QString, ai_usage_json, cxx_name = "aiUsageJson")]
        #[qproperty(QString, terminals_json, cxx_name = "terminalsJson")]
        #[qproperty(QString, network_status_json, cxx_name = "networkStatusJson")]
        #[qproperty(bool, screen_locked, cxx_name = "screenLocked")]
        #[qproperty(QString, quietnotch_hud_json, cxx_name = "quietnotchHudJson")]
        #[qproperty(QString, quietnotch_notification_json, cxx_name = "quietnotchNotificationJson")]
        #[qproperty(QString, clipboard_history_json, cxx_name = "clipboardHistoryJson")]
        #[qproperty(QString, fan_telemetry_json, cxx_name = "fanTelemetryJson")]
        #[qproperty(QString, ghnotch_result_json, cxx_name = "ghnotchResultJson")]
        #[qproperty(QString, isle_finance_json, cxx_name = "isleFinanceJson")]
        #[qproperty(QString, macisland_battery_json, cxx_name = "macislandBatteryJson")]
        #[qproperty(QString, macwake_thermal_json, cxx_name = "macwakeThermalJson")]
        #[qproperty(QString, macwake_cleaning_json, cxx_name = "macwakeCleaningJson")]
        #[qproperty(QString, piisland_sessions_json, cxx_name = "piislandSessionsJson")]
        #[qproperty(QString, pookify_animation_json, cxx_name = "pookifyAnimationJson")]
        #[qproperty(QString, screen_ocr_json, cxx_name = "screenOcrJson")]
        #[qproperty(QString, topnotch_focus_json, cxx_name = "topnotchFocusJson")]
        #[qproperty(QString, macisland_studio_json, cxx_name = "macislandStudioJson")]
        type DynamoController = super::DynamoControllerRust;
    }

    impl cxx_qt::Threading for DynamoController {}
    impl cxx_qt::Initialize for DynamoController {}

    unsafe extern "RustQt" {
        #[qinvokable]
        fn refresh(self: Pin<&mut DynamoController>);
        #[qinvokable]
        fn launch(self: Pin<&mut DynamoController>);
        #[qinvokable]
        fn stop(self: Pin<&mut DynamoController>);
        #[qinvokable]
        #[cxx_name = "openSettings"]
        fn open_settings(self: &DynamoController);
        #[qinvokable]
        fn expand(self: Pin<&mut DynamoController>);
        #[qinvokable]
        fn collapse(self: Pin<&mut DynamoController>);
        #[qinvokable]
        #[cxx_name = "positionIslandWindow"]
        fn position_island_window(self: &DynamoController, x: f64, width: f64, height: f64);

        #[qinvokable]
        #[cxx_name = "pickScreenColor"]
        fn pick_screen_color(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "toggleCaffeinate"]
        fn toggle_caffeinate(self: Pin<&mut DynamoController>) -> bool;
        #[qinvokable]
        #[cxx_name = "isCaffeinateActive"]
        fn is_caffeinate_active(self: &DynamoController) -> bool;
        #[qinvokable]
        #[cxx_name = "setVolume"]
        fn set_volume(self: &DynamoController, percent: i32);
        #[qinvokable]
        #[cxx_name = "setBrightness"]
        fn set_brightness(self: &DynamoController, percent: i32);
        #[qinvokable]
        #[cxx_name = "openDownloads"]
        fn open_downloads(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "openCalendar"]
        fn open_calendar(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "openReminders"]
        fn open_reminders(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "openCameraMirror"]
        fn open_camera_mirror(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "mediaPlayPause"]
        fn media_play_pause(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "mediaNext"]
        fn media_next(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "mediaPrevious"]
        fn media_previous(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "startNotchDragDetector"]
        fn start_notch_drag_detector(self: &DynamoController, min_x: f64, max_x: f64, height: f64);
        #[qinvokable]
        #[cxx_name = "stopNotchDragDetector"]
        fn stop_notch_drag_detector(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "phoneBridgeMountInFinder"]
        fn phone_bridge_mount_in_finder(self: &DynamoController, dev_id: &QString);
        #[qinvokable]
        #[cxx_name = "getStorageStats"]
        fn get_storage_stats(self: &DynamoController) -> QString;
        #[qinvokable]
        #[cxx_name = "cleanDevCachesToTrash"]
        fn clean_dev_caches_to_trash(self: &DynamoController) -> QString;
        #[qinvokable]
        #[cxx_name = "toggleGestureTarget"]
        fn toggle_gesture_target(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "updateNotchGestureBounds"]
        fn update_notch_gesture_bounds(self: &DynamoController, x: f64, y: f64, w: f64, h: f64);
        #[qinvokable]
        #[cxx_name = "refreshTelemetry"]
        fn refresh_telemetry(self: Pin<&mut DynamoController>);
        #[qinvokable]
        #[cxx_name = "setManualNotchOverride"]
        fn set_manual_notch_override(self: Pin<&mut DynamoController>, width_nudge: f64, height_nudge: f64, radius_nudge: f64);
        #[qinvokable]
        #[cxx_name = "pokeMochi"]
        fn poke_mochi(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "coucoudoroStart"]
        fn coucoudoro_start(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "coucoudoroPause"]
        fn coucoudoro_pause(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "coucoudoroResume"]
        fn coucoudoro_resume(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "coucoudoroReset"]
        fn coucoudoro_reset(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "respondAgentApproval"]
        fn respond_agent_approval(self: &DynamoController, allow: bool);
        #[qinvokable]
        #[cxx_name = "takeQuickScreenshot"]
        fn take_quick_screenshot(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "answerAgentQuestion"]
        fn answer_agent_question(self: &DynamoController, option_index: i32);
        #[qinvokable]
        #[cxx_name = "clearAgentTasks"]
        fn clear_agent_tasks(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "setQuickShareVisibility"]
        fn set_quickshare_visibility(self: &DynamoController, mode: &QString);
        #[qinvokable]
        #[cxx_name = "respondQuickShare"]
        fn respond_quickshare(self: &DynamoController, accept: bool);
        #[qinvokable]
        #[cxx_name = "cancelQuickShare"]
        fn cancel_quickshare(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "addQuickShareTrusted"]
        fn add_quickshare_trusted(self: &DynamoController, name: &QString, dev_type: &QString);
        #[qinvokable]
        #[cxx_name = "removeQuickShareTrusted"]
        fn remove_quickshare_trusted(self: &DynamoController, name: &QString);
        #[qinvokable]
        #[cxx_name = "simulateQuickShareIncoming"]
        fn simulate_quickshare_incoming(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "simulateCapsLock"]
        fn simulate_caps_lock(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "simulateFocusMode"]
        fn simulate_focus_mode(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "simulateBluetoothAudio"]
        fn simulate_bluetooth_audio(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "queryLauncher"]
        fn query_launcher(self: Pin<&mut DynamoController>, q: &QString);
        #[qinvokable]
        #[cxx_name = "executeLauncherItem"]
        fn execute_launcher_item(self: &DynamoController, item_id: &QString);
        #[qinvokable]
        #[cxx_name = "cancelDownload"]
        fn cancel_download(self: &DynamoController, id: &QString);
        #[qinvokable]
        #[cxx_name = "revealDownload"]
        fn reveal_download(self: &DynamoController, id: &QString);
        #[qinvokable]
        #[cxx_name = "simulateDownload"]
        fn simulate_download(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "simulatePrivacyMic"]
        fn simulate_privacy_mic(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "simulatePrivacyCamera"]
        fn simulate_privacy_camera(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "triggerAnnouncement"]
        fn trigger_announcement(self: &DynamoController, title: &QString, symbol: &QString, accent: &QString);
        #[qinvokable]
        #[cxx_name = "dismissAnnouncement"]
        fn dismiss_announcement(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "teleprompterToggle"]
        fn teleprompter_toggle(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "teleprompterReset"]
        fn teleprompter_reset(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "teleprompterDismiss"]
        fn teleprompter_dismiss(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "teleprompterSetScript"]
        fn teleprompter_set_script(self: &DynamoController, script: &QString);
        #[qinvokable]
        #[cxx_name = "teleprompterSetSpeed"]
        fn teleprompter_set_speed(self: &DynamoController, speed: f64);
        #[qinvokable]
        #[cxx_name = "searchEmojis"]
        fn search_emojis(self: Pin<&mut DynamoController>, query: &QString);
        #[qinvokable]
        #[cxx_name = "copyEmoji"]
        fn copy_emoji(self: &DynamoController, emoji: &QString);
        #[qinvokable]
        #[cxx_name = "simulateAiUsageRefresh"]
        fn simulate_ai_usage_refresh(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "playSynthSound"]
        fn play_synth_sound(self: &DynamoController, sound: &QString);
        #[qinvokable]
        #[cxx_name = "jumpToTerminal"]
        fn jump_to_terminal(self: &DynamoController, terminal: &QString) -> bool;
        #[qinvokable]
        #[cxx_name = "simulateNetworkEvent"]
        fn simulate_network_event(self: &DynamoController, event: &QString);
        #[qinvokable]
        #[cxx_name = "setQuietnotchVolume"]
        fn set_quietnotch_volume(self: &DynamoController, volume: f32);
        #[qinvokable]
        #[cxx_name = "setQuietnotchBrightness"]
        fn set_quietnotch_brightness(self: &DynamoController, brightness: f32);
        #[qinvokable]
        #[cxx_name = "simulateQuietnotchHud"]
        fn simulate_quietnotch_hud(self: &DynamoController, kind: &QString, value: f32);
        #[qinvokable]
        #[cxx_name = "sendQuietnotchTestNotification"]
        fn send_quietnotch_test_notification(self: &DynamoController, title: &QString, body: &QString, app_name: &QString);
        #[qinvokable]
        #[cxx_name = "dismissQuietnotchNotification"]
        fn dismiss_quietnotch_notification(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "setQuietHoursEnabled"]
        fn set_quiet_hours_enabled(self: &DynamoController, enabled: bool);
        #[qinvokable]
        #[cxx_name = "searchClipboardHistory"]
        fn search_clipboard_history(self: Pin<&mut DynamoController>, query: &QString);
        #[qinvokable]
        #[cxx_name = "copyClipboardEntry"]
        fn copy_clipboard_entry(self: &DynamoController, id: &QString) -> bool;
        #[qinvokable]
        #[cxx_name = "clearClipboardHistory"]
        fn clear_clipboard_history(self: Pin<&mut DynamoController>);
        #[qinvokable]
        #[cxx_name = "addClipboardEntry"]
        fn add_clipboard_entry(self: Pin<&mut DynamoController>, text: &QString);
        #[qinvokable]
        #[cxx_name = "setFanMode"]
        fn set_fan_mode(self: Pin<&mut DynamoController>, mode: &QString);
        #[qinvokable]
        #[cxx_name = "simulateFanRpm"]
        fn simulate_fan_rpm(self: Pin<&mut DynamoController>, left: f64, right: f64);
        #[qinvokable]
        #[cxx_name = "executeNotchCommand"]
        fn execute_notch_command(self: Pin<&mut DynamoController>, cmd: &QString) -> QString;
        #[qinvokable]
        #[cxx_name = "refreshIsleFinance"]
        fn refresh_isle_finance(self: Pin<&mut DynamoController>);
        #[qinvokable]
        #[cxx_name = "setIsleSymbol"]
        fn set_isle_symbol(self: Pin<&mut DynamoController>, symbol: &QString);
        #[qinvokable]
        #[cxx_name = "simulateIsleQuote"]
        fn simulate_isle_quote(self: Pin<&mut DynamoController>, symbol: &QString, price: f64, change: f64);
        #[qinvokable]
        #[cxx_name = "triggerAirDrop"]
        fn trigger_airdrop(self: &DynamoController, path: &QString) -> bool;
        #[qinvokable]
        #[cxx_name = "simulateMacIslandBattery"]
        fn simulate_macisland_battery(self: Pin<&mut DynamoController>, pct: i32, charging: bool);
        #[qinvokable]
        #[cxx_name = "resetMacIslandBattery"]
        fn reset_macisland_battery(self: Pin<&mut DynamoController>);
        #[qinvokable]
        #[cxx_name = "startCleaningMode"]
        fn start_cleaning_mode(self: &DynamoController, seconds: i32);
        #[qinvokable]
        #[cxx_name = "stopCleaningMode"]
        fn stop_cleaning_mode(self: &DynamoController);
        #[qinvokable]
        #[cxx_name = "simulateMacWakeThermal"]
        fn simulate_macwake_thermal(self: Pin<&mut DynamoController>, cpu: f64, gpu: f64);
        #[qinvokable]
        #[cxx_name = "resetMacWakeThermal"]
        fn reset_macwake_thermal(self: Pin<&mut DynamoController>);
        #[qinvokable]
        #[cxx_name = "simulatePiIslandEvent"]
        fn simulate_piisland_event(self: Pin<&mut DynamoController>, agent: &QString, model: &QString, status: &QString, tool: &QString);
        #[qinvokable]
        #[cxx_name = "resetPiIslandSimulation"]
        fn reset_piisland_simulation(self: Pin<&mut DynamoController>);
        #[qinvokable]
        #[cxx_name = "simulatePookifyEvent"]
        fn simulate_pookify_event(self: Pin<&mut DynamoController>, state: &QString, tool: &QString, file: &QString);
        #[qinvokable]
        #[cxx_name = "resetPookifySimulation"]
        fn reset_pookify_simulation(self: Pin<&mut DynamoController>);
        #[qinvokable]
        #[cxx_name = "searchScreenText"]
        fn search_screen_text(self: Pin<&mut DynamoController>, query: &QString);
        #[qinvokable]
        #[cxx_name = "clearScreenSearch"]
        fn clear_screen_search(self: Pin<&mut DynamoController>);
        #[qinvokable]
        #[cxx_name = "nextScreenMatch"]
        fn next_screen_match(self: Pin<&mut DynamoController>);
        #[qinvokable]
        #[cxx_name = "previousScreenMatch"]
        fn previous_screen_match(self: Pin<&mut DynamoController>);
        #[qinvokable]
        #[cxx_name = "simulateScreenMatches"]
        fn simulate_screen_matches(self: Pin<&mut DynamoController>, query: &QString, count: i32);
        #[qinvokable]
        #[cxx_name = "topnotchStartFocus"]
        fn topnotch_start_focus(self: Pin<&mut DynamoController>, minutes: i32);
        #[qinvokable]
        #[cxx_name = "topnotchPauseFocus"]
        fn topnotch_pause_focus(self: Pin<&mut DynamoController>);
        #[qinvokable]
        #[cxx_name = "topnotchResumeFocus"]
        fn topnotch_resume_focus(self: Pin<&mut DynamoController>);
        #[qinvokable]
        #[cxx_name = "topnotchSkipFocus"]
        fn topnotch_skip_focus(self: Pin<&mut DynamoController>);
        #[qinvokable]
        #[cxx_name = "topnotchResetFocus"]
        fn topnotch_reset_focus(self: Pin<&mut DynamoController>);
        #[qinvokable]
        #[cxx_name = "topnotchSaveNote"]
        fn topnotch_save_note(self: Pin<&mut DynamoController>, title: &QString, text: &QString);
        #[qinvokable]
        #[cxx_name = "topnotchDeleteNote"]
        fn topnotch_delete_note(self: Pin<&mut DynamoController>, index: i32);
        #[qinvokable]
        #[cxx_name = "macislandToggleRingLight"]
        fn macisland_toggle_ring_light(self: Pin<&mut DynamoController>);
        #[qinvokable]
        #[cxx_name = "macislandSetRingLight"]
        fn macisland_set_ring_light(self: Pin<&mut DynamoController>, brightness: f32, width: f32);
        #[qinvokable]
        #[cxx_name = "macislandSelectAudioDevice"]
        fn macisland_select_audio_device(self: Pin<&mut DynamoController>, device_id: u32);
    }
}

pub struct DynamoControllerRust {
    status: QString,
    installed_path: QString,
    is_running: bool,
    is_installed: bool,
    autostart: bool,
    island_expanded: bool,
    telemetry_json: QString,
    system_hud_json: QString,
    privacy_guard_json: QString,
    caffeinate_active: bool,
    notch_geometry_json: QString,
    debug_overlay_enabled: bool,
    battery_json: QString,
    system_media_json: QString,
    calendar_json: QString,
    notch_drag_active: bool,
    mochi_json: QString,
    coucoudoro_json: QString,
    agent_hook_json: QString,
    agent_tasks_json: QString,
    agent_question_json: QString,
    quickshare_json: QString,
    quickshare_trusted_json: QString,
    atoll_hud_json: QString,
    launcher_results_json: QString,
    downloads_json: QString,
    privacy_sensors_json: QString,
    ledge_announcement_json: QString,
    teleprompter_json: QString,
    emoji_results_json: QString,
    ai_usage_json: QString,
    terminals_json: QString,
    network_status_json: QString,
    screen_locked: bool,
    quietnotch_hud_json: QString,
    quietnotch_notification_json: QString,
    clipboard_history_json: QString,
    fan_telemetry_json: QString,
    ghnotch_result_json: QString,
    isle_finance_json: QString,
    macisland_battery_json: QString,
    macwake_thermal_json: QString,
    macwake_cleaning_json: QString,
    piisland_sessions_json: QString,
    pookify_animation_json: QString,
    screen_ocr_json: QString,
    topnotch_focus_json: QString,
    macisland_studio_json: QString,
}

impl Default for DynamoControllerRust {
    fn default() -> Self {
        Self {
            status: QString::from("running"),
            installed_path: QString::from("/Applications/MacLink.app"),
            is_running: true,
            is_installed: true,
            autostart: true,
            island_expanded: false,
            telemetry_json: QString::from(crate::dynamo::get_telemetry_json().as_str()),
            system_hud_json: QString::from(r#"{"visible":false}"#),
            privacy_guard_json: QString::from(r#"{"cameraActive":false,"micActive":false}"#),
            caffeinate_active: false,
            notch_geometry_json: QString::from(crate::dynamo::get_notch_geometry_json().as_str()),
            debug_overlay_enabled: crate::dynamo::is_debug_overlay_enabled(),
            battery_json: QString::from(crate::dynamo::get_battery_status_json().as_str()),
            system_media_json: QString::from(crate::dynamo::get_system_media_json().as_str()),
            calendar_json: QString::from(crate::dynamo::get_calendar_event_json().as_str()),
            notch_drag_active: crate::dynamo::is_notch_drag_active(),
            mochi_json: QString::from(crate::dynamo::get_mochi_state_json().as_str()),
            coucoudoro_json: QString::from(crate::dynamo::get_coucoudoro_json().as_str()),
            agent_hook_json: QString::from(crate::dynamo::get_agent_hook_json().as_str()),
            agent_tasks_json: QString::from(crate::dynamo::get_agent_tasks_json().as_str()),
            agent_question_json: QString::from(crate::dynamo::get_agent_question_json().as_str()),
            quickshare_json: QString::from(crate::dynamo::get_quickshare_json().as_str()),
            quickshare_trusted_json: QString::from(crate::dynamo::get_quickshare_trusted_devices_json().as_str()),
            atoll_hud_json: QString::from(crate::dynamo::get_atoll_hud_json().as_str()),
            launcher_results_json: QString::from(crate::dynamo::get_launcher_results_json().as_str()),
            downloads_json: QString::from(crate::dynamo::get_download_tracker_json().as_str()),
            privacy_sensors_json: QString::from(crate::dynamo::get_privacy_sensors_json().as_str()),
            ledge_announcement_json: QString::from(crate::dynamo::get_ledge_announcement_json().as_str()),
            teleprompter_json: QString::from(crate::dynamo::get_teleprompter_json().as_str()),
            emoji_results_json: QString::from(crate::dynamo::search_emojis_json("").as_str()),
            ai_usage_json: QString::from(crate::dynamo::get_ai_usage_json().as_str()),
            terminals_json: QString::from(crate::dynamo::get_running_terminals_json().as_str()),
            network_status_json: QString::from(crate::dynamo::get_network_status_json().as_str()),
            screen_locked: crate::dynamo::is_screen_locked(),
            quietnotch_hud_json: QString::from(crate::dynamo::get_quietnotch_hud_json().as_str()),
            quietnotch_notification_json: QString::from(crate::dynamo::get_quietnotch_notification_json().as_str()),
            clipboard_history_json: QString::from(crate::dynamo::get_clipboard_history_json("").as_str()),
            fan_telemetry_json: QString::from(crate::dynamo::get_fan_telemetry_json().as_str()),
            ghnotch_result_json: QString::from(crate::dynamo::get_ghnotch_last_result_json().as_str()),
            isle_finance_json: QString::from(crate::dynamo::get_isle_finance_json().as_str()),
            macisland_battery_json: QString::from(crate::dynamo::get_macisland_battery_json().as_str()),
            macwake_thermal_json: QString::from(crate::dynamo::get_macwake_thermal_json().as_str()),
            macwake_cleaning_json: QString::from(crate::dynamo::get_macwake_cleaning_json().as_str()),
            piisland_sessions_json: QString::from(crate::dynamo::get_piisland_sessions_json().as_str()),
            pookify_animation_json: QString::from(crate::dynamo::get_pookify_animation_json().as_str()),
            screen_ocr_json: QString::from(crate::dynamo::get_screen_ocr_json().as_str()),
            topnotch_focus_json: QString::from(crate::dynamo::get_topnotch_focus_json().as_str()),
            macisland_studio_json: QString::from(crate::dynamo::get_macisland_studio_json().as_str()),
        }
    }
}

impl cxx_qt::Initialize for qobject::DynamoController {
    fn initialize(mut self: Pin<&mut Self>) {
        if let Ok(mut guard) = DYNAMO_QT_THREAD.get_or_init(|| Mutex::new(None)).lock() {
            *guard = Some(self.qt_thread());
        }
        crate::dynamo::init_boring_services();
        crate::dynamo::init_coucou_services();
        crate::dynamo::init_atoll_services();
        crate::dynamo::init_poshak_island_services();
        crate::dynamo::init_ledge_services();
        crate::dynamo::init_superisland_services();
        crate::dynamo::init_mioisland_services();
        crate::dynamo::init_notchly_services();
        crate::dynamo::init_quietnotch_services();
        crate::dynamo::init_another_notch_services();
        crate::dynamo::init_ghnotch_services();
        crate::dynamo::init_isle_services();
        self.as_mut()
            .on_autostart_changed(|c| {
                let on = *c.autostart();
                crate::dynamo::update_autostart(on);
            })
            .release();
        self.refresh();
    }
}

impl qobject::DynamoController {
    pub fn refresh(mut self: Pin<&mut Self>) {
        let running = crate::settings::maclink_island();
        let installed = true;
        let path_str = "/Applications/MacLink.app".to_string();
        let autostart = true;
        let telemetry = crate::dynamo::get_telemetry_json();
        let is_caff = crate::dynamo::is_caffeinate_active();
        let battery = crate::dynamo::get_battery_status_json();
        let media = crate::dynamo::get_system_media_json();
        let cal = crate::dynamo::get_calendar_event_json();
        let drag_act = crate::dynamo::is_notch_drag_active();
        let mochi = crate::dynamo::get_mochi_state_json();
        let coucou = crate::dynamo::get_coucoudoro_json();
        let agent = crate::dynamo::get_agent_hook_json();
        let agent_tasks = crate::dynamo::get_agent_tasks_json();
        let agent_q = crate::dynamo::get_agent_question_json();
        let quickshare = crate::dynamo::get_quickshare_json();
        let quickshare_trusted = crate::dynamo::get_quickshare_trusted_devices_json();
        let atoll_hud = crate::dynamo::get_atoll_hud_json();

        self.as_mut().set_status(QString::from(if running { "running" } else { "installed" }));
        self.as_mut().set_is_running(running);
        self.as_mut().set_is_installed(installed);
        self.as_mut().set_installed_path(QString::from(&path_str));
        self.as_mut().set_telemetry_json(QString::from(&telemetry));
        let notch_geom = crate::dynamo::get_notch_geometry_json();
        self.as_mut().set_notch_geometry_json(QString::from(&notch_geom));
        self.as_mut().set_debug_overlay_enabled(crate::dynamo::is_debug_overlay_enabled());
        self.as_mut().set_caffeinate_active(is_caff);
        self.as_mut().set_battery_json(QString::from(&battery));
        self.as_mut().set_system_media_json(QString::from(&media));
        self.as_mut().set_calendar_json(QString::from(&cal));
        self.as_mut().set_notch_drag_active(drag_act);
        self.as_mut().set_mochi_json(QString::from(&mochi));
        self.as_mut().set_coucoudoro_json(QString::from(&coucou));
        self.as_mut().set_agent_hook_json(QString::from(&agent));
        self.as_mut().set_agent_tasks_json(QString::from(&agent_tasks));
        self.as_mut().set_agent_question_json(QString::from(&agent_q));
        self.as_mut().set_quickshare_json(QString::from(&quickshare));
        self.as_mut().set_quickshare_trusted_json(QString::from(&quickshare_trusted));
        self.as_mut().set_atoll_hud_json(QString::from(&atoll_hud));
        if *self.autostart() != autostart {
            self.as_mut().set_autostart(autostart);
        }
    }

    pub fn refresh_telemetry(mut self: Pin<&mut Self>) {
        let telemetry = crate::dynamo::get_telemetry_json();
        let notch_geom = crate::dynamo::get_notch_geometry_json();
        let battery = crate::dynamo::get_battery_status_json();
        let media = crate::dynamo::get_system_media_json();
        let cal = crate::dynamo::get_calendar_event_json();
        let drag_act = crate::dynamo::is_notch_drag_active();
        let mochi = crate::dynamo::get_mochi_state_json();
        let coucou = crate::dynamo::get_coucoudoro_json();
        let agent = crate::dynamo::get_agent_hook_json();
        let agent_tasks = crate::dynamo::get_agent_tasks_json();
        let agent_q = crate::dynamo::get_agent_question_json();
        let quickshare = crate::dynamo::get_quickshare_json();
        let quickshare_trusted = crate::dynamo::get_quickshare_trusted_devices_json();
        let atoll_hud = crate::dynamo::get_atoll_hud_json();
        let launcher_res = crate::dynamo::get_launcher_results_json();
        let downloads = crate::dynamo::get_download_tracker_json();
        let privacy_sensors = crate::dynamo::get_privacy_sensors_json();
        let ledge_announcement = crate::dynamo::get_ledge_announcement_json();
        let teleprompter = crate::dynamo::get_teleprompter_json();
        let ai_usage = crate::dynamo::get_ai_usage_json();
        let terminals = crate::dynamo::get_running_terminals_json();
        let net = crate::dynamo::get_network_status_json();
        let locked = crate::dynamo::is_screen_locked();
        let qn_hud = crate::dynamo::get_quietnotch_hud_json();
        let qn_notif = crate::dynamo::get_quietnotch_notification_json();

        self.as_mut().set_telemetry_json(QString::from(&telemetry));
        self.as_mut().set_notch_geometry_json(QString::from(&notch_geom));
        self.as_mut().set_debug_overlay_enabled(crate::dynamo::is_debug_overlay_enabled());
        self.as_mut().set_battery_json(QString::from(&battery));
        self.as_mut().set_system_media_json(QString::from(&media));
        self.as_mut().set_calendar_json(QString::from(&cal));
        self.as_mut().set_notch_drag_active(drag_act);
        self.as_mut().set_mochi_json(QString::from(&mochi));
        self.as_mut().set_coucoudoro_json(QString::from(&coucou));
        self.as_mut().set_agent_hook_json(QString::from(&agent));
        self.as_mut().set_agent_tasks_json(QString::from(&agent_tasks));
        self.as_mut().set_agent_question_json(QString::from(&agent_q));
        self.as_mut().set_quickshare_json(QString::from(&quickshare));
        self.as_mut().set_quickshare_trusted_json(QString::from(&quickshare_trusted));
        self.as_mut().set_atoll_hud_json(QString::from(&atoll_hud));
        self.as_mut().set_launcher_results_json(QString::from(&launcher_res));
        self.as_mut().set_downloads_json(QString::from(&downloads));
        self.as_mut().set_privacy_sensors_json(QString::from(&privacy_sensors));
        self.as_mut().set_ledge_announcement_json(QString::from(&ledge_announcement));
        self.as_mut().set_teleprompter_json(QString::from(&teleprompter));
        self.as_mut().set_ai_usage_json(QString::from(&ai_usage));
        self.as_mut().set_terminals_json(QString::from(&terminals));
        self.as_mut().set_network_status_json(QString::from(&net));
        self.as_mut().set_screen_locked(locked);
        self.as_mut().set_quietnotch_hud_json(QString::from(&qn_hud));
        self.as_mut().set_quietnotch_notification_json(QString::from(&qn_notif));
        let clips = crate::dynamo::get_clipboard_history_json("");
        let fans = crate::dynamo::get_fan_telemetry_json();
        self.as_mut().set_clipboard_history_json(QString::from(&clips));
        self.as_mut().set_fan_telemetry_json(QString::from(&fans));
        let finance = crate::dynamo::get_isle_finance_json();
        self.as_mut().set_isle_finance_json(QString::from(&finance));
        let battery = crate::dynamo::get_macisland_battery_json();
        self.as_mut().set_macisland_battery_json(QString::from(&battery));
        let thermal = crate::dynamo::get_macwake_thermal_json();
        self.as_mut().set_macwake_thermal_json(QString::from(&thermal));
        let cleaning = crate::dynamo::get_macwake_cleaning_json();
        self.as_mut().set_macwake_cleaning_json(QString::from(&cleaning));
        let pi = crate::dynamo::get_piisland_sessions_json();
        self.as_mut().set_piisland_sessions_json(QString::from(&pi));
        let pookify = crate::dynamo::get_pookify_animation_json();
        self.as_mut().set_pookify_animation_json(QString::from(&pookify));
        let ocr = crate::dynamo::get_screen_ocr_json();
        self.as_mut().set_screen_ocr_json(QString::from(&ocr));
        let topnotch = crate::dynamo::get_topnotch_focus_json();
        self.as_mut().set_topnotch_focus_json(QString::from(&topnotch));
        let studio = crate::dynamo::get_macisland_studio_json();
        self.as_mut().set_macisland_studio_json(QString::from(&studio));
    }

    pub fn set_manual_notch_override(
        mut self: Pin<&mut Self>,
        width_nudge: f64,
        height_nudge: f64,
        radius_nudge: f64,
    ) {
        crate::dynamo::set_manual_notch_override(width_nudge, height_nudge, radius_nudge);
        self.as_mut().refresh_telemetry();
    }



    pub fn launch(mut self: Pin<&mut Self>) {
        crate::settings::set_maclink_island(true);
        self.as_mut().refresh();
    }

    pub fn stop(mut self: Pin<&mut Self>) {
        crate::settings::set_maclink_island(false);
        self.as_mut().refresh();
    }

    pub fn open_settings(self: &Self) {
        crate::dynamo::open_settings();
    }

    pub fn expand(mut self: Pin<&mut Self>) {
        self.as_mut().set_island_expanded(true);
    }

    pub fn collapse(mut self: Pin<&mut Self>) {
        self.as_mut().set_island_expanded(false);
    }

    pub fn position_island_window(self: &Self, x: f64, width: f64, height: f64) {
        crate::dynamo::position_island_window(x, width, height);
    }

    pub fn pick_screen_color(self: &Self) {
        crate::dynamo::pick_screen_color();
    }

    pub fn toggle_caffeinate(mut self: Pin<&mut Self>) -> bool {
        let active = crate::dynamo::toggle_caffeinate();
        self.as_mut().set_caffeinate_active(active);
        active
    }

    pub fn is_caffeinate_active(self: &Self) -> bool {
        crate::dynamo::is_caffeinate_active()
    }

    pub fn set_volume(self: &Self, percent: i32) {
        crate::dynamo::set_volume(percent);
    }

    pub fn set_brightness(self: &Self, percent: i32) {
        crate::dynamo::set_brightness(percent);
    }

    pub fn open_downloads(self: &Self) {
        crate::dynamo::open_downloads();
    }

    pub fn open_calendar(self: &Self) {
        crate::dynamo::open_calendar();
    }

    pub fn open_reminders(self: &Self) {
        crate::dynamo::open_reminders();
    }

    pub fn open_camera_mirror(self: &Self) {
        crate::dynamo::open_camera_mirror();
    }

    pub fn media_play_pause(self: &Self) {
        crate::dynamo::media_play_pause();
    }

    pub fn media_next(self: &Self) {
        crate::dynamo::media_next();
    }

    pub fn media_previous(self: &Self) {
        crate::dynamo::media_previous();
    }

    pub fn start_notch_drag_detector(self: &Self, min_x: f64, max_x: f64, height: f64) {
        crate::dynamo::configure_and_start_notch_drag(min_x, max_x, height);
    }

    pub fn stop_notch_drag_detector(self: &Self) {
        crate::dynamo::stop_notch_drag();
    }

    pub fn phone_bridge_mount_in_finder(self: &Self, dev_id: &QString) {
        crate::dynamo::phone_bridge_mount_in_finder(&dev_id.to_string());
    }

    pub fn get_storage_stats(self: &Self) -> QString {
        QString::from(&crate::dynamo::get_storage_stats())
    }

    pub fn clean_dev_caches_to_trash(self: &Self) -> QString {
        QString::from(&crate::dynamo::clean_dev_caches_to_trash())
    }

    pub fn toggle_gesture_target(self: &Self) {}

    pub fn update_notch_gesture_bounds(self: &Self, _x: f64, _y: f64, _w: f64, _h: f64) {}

    pub fn poke_mochi(self: &Self) {
        crate::dynamo::poke_mochi();
    }

    pub fn coucoudoro_start(self: &Self) {
        crate::dynamo::coucoudoro_start();
    }

    pub fn coucoudoro_pause(self: &Self) {
        crate::dynamo::coucoudoro_pause();
    }

    pub fn coucoudoro_resume(self: &Self) {
        crate::dynamo::coucoudoro_resume();
    }

    pub fn coucoudoro_reset(self: &Self) {
        crate::dynamo::coucoudoro_reset();
    }

    pub fn respond_agent_approval(self: &Self, allow: bool) {
        crate::dynamo::respond_agent_approval(allow);
    }

    pub fn take_quick_screenshot(self: &Self) {
        crate::dynamo::take_quick_screenshot();
    }

    pub fn answer_agent_question(self: &Self, option_index: i32) {
        crate::dynamo::answer_agent_question(option_index);
    }

    pub fn clear_agent_tasks(self: &Self) {
        crate::dynamo::clear_agent_tasks();
    }

    pub fn set_quickshare_visibility(self: &Self, mode: &QString) {
        crate::dynamo::set_quickshare_visibility(&mode.to_string());
    }

    pub fn respond_quickshare(self: &Self, accept: bool) {
        crate::dynamo::respond_quickshare_request(accept);
    }

    pub fn cancel_quickshare(self: &Self) {
        crate::dynamo::cancel_quickshare_transfer();
    }

    pub fn add_quickshare_trusted(self: &Self, name: &QString, dev_type: &QString) {
        crate::dynamo::add_quickshare_trusted_device(&name.to_string(), &dev_type.to_string());
    }

    pub fn remove_quickshare_trusted(self: &Self, name: &QString) {
        crate::dynamo::remove_quickshare_trusted_device(&name.to_string());
    }

    pub fn simulate_quickshare_incoming(self: &Self) {
        crate::dynamo::simulate_quickshare_incoming();
    }

    pub fn simulate_caps_lock(self: &Self) {
        crate::dynamo::simulate_capslock_toggle();
    }

    pub fn simulate_focus_mode(self: &Self) {
        crate::dynamo::simulate_focus_toggle();
    }

    pub fn simulate_bluetooth_audio(self: &Self) {
        crate::dynamo::simulate_bluetooth_connect();
    }

    pub fn query_launcher(mut self: Pin<&mut Self>, q: &QString) {
        crate::dynamo::query_launcher(&q.to_string());
        let res = crate::dynamo::get_launcher_results_json();
        self.as_mut().set_launcher_results_json(QString::from(&res));
    }

    pub fn execute_launcher_item(self: &Self, item_id: &QString) {
        crate::dynamo::execute_launcher_item(&item_id.to_string());
    }

    pub fn cancel_download(self: &Self, id: &QString) {
        crate::dynamo::cancel_download(&id.to_string());
    }

    pub fn reveal_download(self: &Self, id: &QString) {
        crate::dynamo::reveal_download(&id.to_string());
    }

    pub fn simulate_download(self: &Self) {
        crate::dynamo::simulate_download();
    }

    pub fn simulate_privacy_mic(self: &Self) {
        crate::dynamo::simulate_privacy_mic_toggle();
    }

    pub fn simulate_privacy_camera(self: &Self) {
        crate::dynamo::simulate_privacy_camera_toggle();
    }

    pub fn trigger_announcement(self: &Self, title: &QString, symbol: &QString, accent: &QString) {
        crate::dynamo::trigger_announcement(&title.to_string(), &symbol.to_string(), &accent.to_string());
    }

    pub fn dismiss_announcement(self: &Self) {
        crate::dynamo::dismiss_announcement();
    }

    pub fn teleprompter_toggle(self: &Self) {
        crate::dynamo::teleprompter_toggle();
    }

    pub fn teleprompter_reset(self: &Self) {
        crate::dynamo::teleprompter_reset();
    }

    pub fn teleprompter_dismiss(self: &Self) {
        crate::dynamo::teleprompter_dismiss();
    }

    pub fn teleprompter_set_script(self: &Self, script: &QString) {
        crate::dynamo::teleprompter_set_script(&script.to_string());
    }

    pub fn teleprompter_set_speed(self: &Self, speed: f64) {
        crate::dynamo::teleprompter_set_speed(speed);
    }

    pub fn search_emojis(mut self: Pin<&mut Self>, query: &QString) {
        let res = crate::dynamo::search_emojis_json(&query.to_string());
        self.as_mut().set_emoji_results_json(QString::from(&res));
    }

    pub fn copy_emoji(self: &Self, emoji: &QString) {
        crate::dynamo::copy_emoji(&emoji.to_string());
    }

    pub fn simulate_ai_usage_refresh(self: &Self) {
        crate::dynamo::simulate_ai_usage_refresh();
    }

    pub fn play_synth_sound(self: &Self, sound: &QString) {
        crate::dynamo::play_synth_sound(&sound.to_string());
    }

    pub fn jump_to_terminal(self: &Self, terminal: &QString) -> bool {
        crate::dynamo::jump_to_terminal(&terminal.to_string())
    }

    pub fn simulate_network_event(self: &Self, event: &QString) {
        crate::dynamo::simulate_network_event(&event.to_string());
    }

    pub fn set_quietnotch_volume(self: &Self, volume: f32) {
        crate::dynamo::set_quietnotch_volume(volume);
    }

    pub fn set_quietnotch_brightness(self: &Self, brightness: f32) {
        crate::dynamo::set_quietnotch_brightness(brightness);
    }

    pub fn simulate_quietnotch_hud(self: &Self, kind: &QString, value: f32) {
        crate::dynamo::simulate_quietnotch_hud(&kind.to_string(), value);
    }

    pub fn send_quietnotch_test_notification(self: &Self, title: &QString, body: &QString, app_name: &QString) {
        crate::dynamo::send_quietnotch_test_notification(&title.to_string(), &body.to_string(), &app_name.to_string());
    }

    pub fn dismiss_quietnotch_notification(self: &Self) {
        crate::dynamo::dismiss_quietnotch_notification();
    }

    pub fn set_quiet_hours_enabled(self: &Self, enabled: bool) {
        crate::dynamo::set_quiet_hours_enabled(enabled);
    }

    pub fn search_clipboard_history(mut self: Pin<&mut Self>, query: &QString) {
        let res = crate::dynamo::get_clipboard_history_json(&query.to_string());
        self.as_mut().set_clipboard_history_json(QString::from(&res));
    }

    pub fn copy_clipboard_entry(self: &Self, id: &QString) -> bool {
        crate::dynamo::copy_clipboard_entry(&id.to_string())
    }

    pub fn clear_clipboard_history(mut self: Pin<&mut Self>) {
        crate::dynamo::clear_clipboard_history();
        self.as_mut().set_clipboard_history_json(QString::from("[]"));
    }

    pub fn add_clipboard_entry(mut self: Pin<&mut Self>, text: &QString) {
        crate::dynamo::add_clipboard_entry(&text.to_string());
        let res = crate::dynamo::get_clipboard_history_json("");
        self.as_mut().set_clipboard_history_json(QString::from(&res));
    }

    pub fn set_fan_mode(mut self: Pin<&mut Self>, mode: &QString) {
        crate::dynamo::set_fan_mode(&mode.to_string());
        let fans = crate::dynamo::get_fan_telemetry_json();
        self.as_mut().set_fan_telemetry_json(QString::from(&fans));
    }

    pub fn simulate_fan_rpm(mut self: Pin<&mut Self>, left: f64, right: f64) {
        crate::dynamo::simulate_fan_rpm(left, right);
        let fans = crate::dynamo::get_fan_telemetry_json();
        self.as_mut().set_fan_telemetry_json(QString::from(&fans));
    }

    pub fn execute_notch_command(mut self: Pin<&mut Self>, cmd: &QString) -> QString {
        let out = crate::dynamo::execute_ghnotch_command(&cmd.to_string());
        let res = crate::dynamo::get_ghnotch_last_result_json();
        self.as_mut().set_ghnotch_result_json(QString::from(&res));
        QString::from(&out)
    }

    pub fn refresh_isle_finance(mut self: Pin<&mut Self>) {
        crate::dynamo::refresh_isle_finance();
        let res = crate::dynamo::get_isle_finance_json();
        self.as_mut().set_isle_finance_json(QString::from(&res));
    }

    pub fn set_isle_symbol(mut self: Pin<&mut Self>, symbol: &QString) {
        crate::dynamo::set_isle_symbol(&symbol.to_string());
        let res = crate::dynamo::get_isle_finance_json();
        self.as_mut().set_isle_finance_json(QString::from(&res));
    }

    pub fn simulate_isle_quote(mut self: Pin<&mut Self>, symbol: &QString, price: f64, change: f64) {
        crate::dynamo::simulate_isle_quote(&symbol.to_string(), price, change);
        let res = crate::dynamo::get_isle_finance_json();
        self.as_mut().set_isle_finance_json(QString::from(&res));
    }

    pub fn trigger_airdrop(self: &Self, path: &QString) -> bool {
        crate::dynamo::trigger_airdrop(&path.to_string())
    }

    pub fn simulate_macisland_battery(mut self: Pin<&mut Self>, pct: i32, charging: bool) {
        crate::dynamo::simulate_macisland_battery(pct, charging);
        let res = crate::dynamo::get_macisland_battery_json();
        self.as_mut().set_macisland_battery_json(QString::from(&res));
    }

    pub fn reset_macisland_battery(mut self: Pin<&mut Self>) {
        crate::dynamo::reset_macisland_battery();
        let res = crate::dynamo::get_macisland_battery_json();
        self.as_mut().set_macisland_battery_json(QString::from(&res));
    }

    pub fn start_cleaning_mode(self: &Self, seconds: i32) {
        crate::dynamo::start_cleaning_mode(seconds);
    }

    pub fn stop_cleaning_mode(self: &Self) {
        crate::dynamo::stop_cleaning_mode();
    }

    pub fn simulate_macwake_thermal(mut self: Pin<&mut Self>, cpu: f64, gpu: f64) {
        crate::dynamo::simulate_macwake_thermal(cpu, gpu);
        let res = crate::dynamo::get_macwake_thermal_json();
        self.as_mut().set_macwake_thermal_json(QString::from(&res));
    }

    pub fn reset_macwake_thermal(mut self: Pin<&mut Self>) {
        crate::dynamo::reset_macwake_thermal();
        let res = crate::dynamo::get_macwake_thermal_json();
        self.as_mut().set_macwake_thermal_json(QString::from(&res));
    }

    pub fn simulate_piisland_event(
        mut self: Pin<&mut Self>,
        agent: &QString,
        model: &QString,
        status: &QString,
        tool: &QString,
    ) {
        crate::dynamo::simulate_piisland_event(
            &agent.to_string(),
            &model.to_string(),
            &status.to_string(),
            &tool.to_string(),
        );
        let res = crate::dynamo::get_piisland_sessions_json();
        self.as_mut().set_piisland_sessions_json(QString::from(&res));
    }

    pub fn reset_piisland_simulation(mut self: Pin<&mut Self>) {
        crate::dynamo::reset_piisland_simulation();
        let res = crate::dynamo::get_piisland_sessions_json();
        self.as_mut().set_piisland_sessions_json(QString::from(&res));
    }

    pub fn simulate_pookify_event(
        mut self: Pin<&mut Self>,
        state: &QString,
        tool: &QString,
        file: &QString,
    ) {
        crate::dynamo::simulate_pookify_event(
            &state.to_string(),
            &tool.to_string(),
            &file.to_string(),
        );
        let res = crate::dynamo::get_pookify_animation_json();
        self.as_mut().set_pookify_animation_json(QString::from(&res));
    }

    pub fn reset_pookify_simulation(mut self: Pin<&mut Self>) {
        crate::dynamo::reset_pookify_simulation();
        let res = crate::dynamo::get_pookify_animation_json();
        self.as_mut().set_pookify_animation_json(QString::from(&res));
    }

    pub fn search_screen_text(mut self: Pin<&mut Self>, query: &QString) {
        crate::dynamo::search_screen_text(&query.to_string());
        let res = crate::dynamo::get_screen_ocr_json();
        self.as_mut().set_screen_ocr_json(QString::from(&res));
    }

    pub fn clear_screen_search(mut self: Pin<&mut Self>) {
        crate::dynamo::clear_screen_search();
        let res = crate::dynamo::get_screen_ocr_json();
        self.as_mut().set_screen_ocr_json(QString::from(&res));
    }

    pub fn next_screen_match(mut self: Pin<&mut Self>) {
        crate::dynamo::next_screen_match();
        let res = crate::dynamo::get_screen_ocr_json();
        self.as_mut().set_screen_ocr_json(QString::from(&res));
    }

    pub fn previous_screen_match(mut self: Pin<&mut Self>) {
        crate::dynamo::previous_screen_match();
        let res = crate::dynamo::get_screen_ocr_json();
        self.as_mut().set_screen_ocr_json(QString::from(&res));
    }

    pub fn simulate_screen_matches(mut self: Pin<&mut Self>, query: &QString, count: i32) {
        crate::dynamo::simulate_screen_matches(&query.to_string(), count);
        let res = crate::dynamo::get_screen_ocr_json();
        self.as_mut().set_screen_ocr_json(QString::from(&res));
    }

    pub fn topnotch_start_focus(mut self: Pin<&mut Self>, minutes: i32) {
        crate::dynamo::topnotch_start_focus(minutes);
        let res = crate::dynamo::get_topnotch_focus_json();
        self.as_mut().set_topnotch_focus_json(QString::from(&res));
    }

    pub fn topnotch_pause_focus(mut self: Pin<&mut Self>) {
        crate::dynamo::topnotch_pause_focus();
        let res = crate::dynamo::get_topnotch_focus_json();
        self.as_mut().set_topnotch_focus_json(QString::from(&res));
    }

    pub fn topnotch_resume_focus(mut self: Pin<&mut Self>) {
        crate::dynamo::topnotch_resume_focus();
        let res = crate::dynamo::get_topnotch_focus_json();
        self.as_mut().set_topnotch_focus_json(QString::from(&res));
    }

    pub fn topnotch_skip_focus(mut self: Pin<&mut Self>) {
        crate::dynamo::topnotch_skip_focus();
        let res = crate::dynamo::get_topnotch_focus_json();
        self.as_mut().set_topnotch_focus_json(QString::from(&res));
    }

    pub fn topnotch_reset_focus(mut self: Pin<&mut Self>) {
        crate::dynamo::topnotch_reset_focus();
        let res = crate::dynamo::get_topnotch_focus_json();
        self.as_mut().set_topnotch_focus_json(QString::from(&res));
    }

    pub fn topnotch_save_note(mut self: Pin<&mut Self>, title: &QString, text: &QString) {
        crate::dynamo::topnotch_save_note(&title.to_string(), &text.to_string());
        let res = crate::dynamo::get_topnotch_focus_json();
        self.as_mut().set_topnotch_focus_json(QString::from(&res));
    }

    pub fn topnotch_delete_note(mut self: Pin<&mut Self>, index: i32) {
        crate::dynamo::topnotch_delete_note(index);
        let res = crate::dynamo::get_topnotch_focus_json();
        self.as_mut().set_topnotch_focus_json(QString::from(&res));
    }

    pub fn macisland_toggle_ring_light(mut self: Pin<&mut Self>) {
        crate::dynamo::macisland_toggle_ring_light();
        let res = crate::dynamo::get_macisland_studio_json();
        self.as_mut().set_macisland_studio_json(QString::from(&res));
    }

    pub fn macisland_set_ring_light(mut self: Pin<&mut Self>, brightness: f32, width: f32) {
        crate::dynamo::macisland_set_ring_light(brightness, width);
        let res = crate::dynamo::get_macisland_studio_json();
        self.as_mut().set_macisland_studio_json(QString::from(&res));
    }

    pub fn macisland_select_audio_device(mut self: Pin<&mut Self>, device_id: u32) {
        crate::dynamo::macisland_select_audio_device(device_id);
        let res = crate::dynamo::get_macisland_studio_json();
        self.as_mut().set_macisland_studio_json(QString::from(&res));
    }
}
