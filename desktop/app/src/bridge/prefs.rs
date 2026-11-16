// SPDX-License-Identifier: GPL-3.0-or-later
//! `Preferences` and `DeckController`: the app's look, behavior and PC-owned Deck.

#![allow(clippy::too_many_arguments)]

use crate::i18n::tr;
use std::{
    path::PathBuf,
    pin::Pin,
    sync::{
        Mutex,
        atomic::{AtomicU64, Ordering},
    },
};

use cxx_qt::{CxxQtType, Threading};
use cxx_qt_lib::{QString, QUrl};

use crate::{
    core_host,
    settings::{ColorMode, RecordingFormat, Settings, Theme},
};

pub use super::deck::DeckControllerRust;

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    #[auto_cxx_name]
    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qml_singleton]
        /// "bloom" or "graphite".
        #[qproperty(QString, theme)]
        /// Bloom colors: "wallpaper", or a preset: "honey", "sage", "lavender"
        /// or "ocean".
        #[qproperty(QString, seed)]
        /// "system", "light" or "dark".
        #[qproperty(QString, color_mode)]
        /// Pure #000000 OLED black surfaces in dark mode.
        #[qproperty(bool, amoled)]
        /// Mica behind the window.
        #[qproperty(bool, backdrop)]
        /// Hive's comb breathes and pulses.
        #[qproperty(bool, comb_motion)]
        #[qproperty(bool, close_to_tray)]
        /// Send what's copied on this PC to connected phones.
        #[qproperty(bool, auto_clipboard)]
        /// Keep the last 50 synced clips in encrypted local history.
        #[qproperty(bool, clipboard_history)]
        /// Suggest context chips (Open, Open in Maps, Call, Track, Email) for copied text.
        #[qproperty(bool, suggest_clipboard_actions)]
        /// Copy one-time codes from phone notifications and SMS automatically.
        #[qproperty(bool, auto_copy_otp)]
        /// Pause PC media playback while a phone call is ringing or active.
        #[qproperty(bool, pause_media_on_call)]
        /// Mute this PC while a phone watches its playback (Play on phone).
        #[qproperty(bool, mute_while_watched, cxx_name = "muteWhileWatched")]
        /// The app's language: "" for the system's, "en", "zh_CN".
        #[qproperty(QString, language)]
        /// Quiet phone notification pop-ups on the PC while the phone is in Do Not Disturb.
        #[qproperty(bool, sync_dnd)]
        /// Paired phones in Explorer's "Send to" menu.
        #[qproperty(bool, send_to_menu)]
        /// Start when the user signs in.
        #[qproperty(bool, start_with_windows)]
        /// Check for updates on their own.
        #[qproperty(bool, auto_update)]
        /// Install a newer release by itself at a quiet moment.
        #[qproperty(bool, install_updates)]
        /// Tell when a phone's battery is low, or full.
        #[qproperty(bool, battery_alerts)]
        /// Folder where voice recordings from phones are saved.
        #[qproperty(QString, recordings_folder)]
        /// Whether `recordings_folder` is the default (`Documents/MacLink Recordings`).
        #[qproperty(bool, recordings_folder_is_default)]
        /// "m4a", "mp3", "wav" or "flac".
        #[qproperty(QString, recordings_format)]
        /// Timeline retention in days (`0` means keep up to 5,000 entries regardless of age).
        #[qproperty(i32, timeline_retention_days)]
        /// Global hotkey for "Take photo with phone" (e.g. `"Ctrl+Alt+C"`).
        #[qproperty(QString, continuity_photo_hotkey)]
        /// Global hotkey for "Scan document with phone" (e.g. `"Ctrl+Alt+D"`).
        #[qproperty(QString, continuity_scan_hotkey)]
        /// Global hotkey for the Command Palette (e.g. `"Ctrl+Alt+Space"`).
        #[qproperty(QString, command_palette_hotkey)]
        /// Global hotkey for the Shelf panel (e.g. `"Ctrl+Alt+S"`).
        #[qproperty(QString, shelf_hotkey)]
        /// Open Shelf by hovering cursor at left screen edge.
        #[qproperty(bool, shelf_edge_trigger)]
        /// Screen edge area size for opening Shelf ("small", "medium", "large").
        #[qproperty(QString, shelf_edge_size)]
        /// Opt-in localhost HTTP/JSON + SSE automation API (`127.0.0.1`).
        #[qproperty(bool, local_api_enabled)]
        /// TCP port for the localhost automation API (default `53320`).
        #[qproperty(i32, local_api_port)]
        /// Path to `<data_dir>/api-token.json` containing the bearer token.
        #[qproperty(QString, local_api_token_path)]
        /// Copy received files (<= 10) to the Windows clipboard as CF_HDROP.
        #[qproperty(bool, clipboard_auto_copy_received_files)]
        /// Open a single file shared from the phone when it arrives.
        #[qproperty(bool, open_shared_files)]
        /// Send the clipboard to the phone when control moves to it.
        #[qproperty(bool, flow_follow_clipboard)]
        /// Floating MacLink Island pill at the top center of the screen.
        #[qproperty(bool, maclink_island)]
        /// Trigger MacLink Island for phone calls.
        #[qproperty(bool, maclink_island_calls)]
        /// Trigger MacLink Island for file transfers.
        #[qproperty(bool, maclink_island_transfers)]
        /// Trigger MacLink Island for media playback.
        #[qproperty(bool, maclink_island_media)]
        /// Trigger MacLink Island for phone notifications.
        #[qproperty(bool, maclink_island_notifications)]
        /// Enable Live Telemetry Wings (sinusoidal CPU glow and RAM capsule track).
        #[qproperty(bool, notch_wings_enabled, cxx_name = "notchWingsEnabled")]
        /// What info to display in the Left Telemetry Wing.
        #[qproperty(QString, notch_left_wing_content, cxx_name = "notchLeftWingContent")]
        /// What info to display in the Right Telemetry Wing.
        #[qproperty(QString, notch_right_wing_content, cxx_name = "notchRightWingContent")]
        /// Anchor island flush against the hardware camera notch.
        #[qproperty(bool, notch_hardware_attached, cxx_name = "notchHardwareAttached")]
        /// Auto-hide island in fullscreen mode.
        #[qproperty(bool, notch_auto_hide_fullscreen, cxx_name = "notchAutoHideFullscreen")]
        /// Show system HUD feedback for volume and brightness.
        #[qproperty(bool, notch_hud_enabled, cxx_name = "notchHudEnabled")]
        /// Scroll gestures over hardware notch for volume & brightness.
        #[qproperty(bool, notch_scroll_gestures, cxx_name = "notchScrollGestures")]
        /// Draw debug-only geometry overlay over notch and wings.
        #[qproperty(bool, notch_debug_overlay, cxx_name = "notchDebugOverlay")]
        /// Manual calibration nudge for notch width.
        #[qproperty(f64, notch_override_width, cxx_name = "notchOverrideWidth")]
        /// Manual calibration nudge for notch height.
        #[qproperty(f64, notch_override_height, cxx_name = "notchOverrideHeight")]
        /// Manual calibration nudge for island corner radius.
        #[qproperty(f64, notch_override_radius, cxx_name = "notchOverrideRadius")]
        /// Drag and drop files onto hardware notch to open Shelf.
        #[qproperty(bool, notch_drag_to_shelf, cxx_name = "notchDragToShelf")]
        /// Show Mac battery percentage and MagSafe charging HUD in notch wings.
        #[qproperty(bool, notch_battery_hud, cxx_name = "notchBatteryHud")]
        /// Mac system media controls (Apple Music & Spotify) and live visualizer.
        #[qproperty(bool, notch_system_media, cxx_name = "notchSystemMedia")]
        /// Upcoming calendar event sneak-peek on hardware notch and island.
        #[qproperty(bool, notch_calendar_sneak_peek, cxx_name = "notchCalendarSneakPeek")]
        /// Mochi animated notch companion character (Coucou).
        #[qproperty(bool, notch_mochi_companion, cxx_name = "notchMochiCompanion")]
        /// Coucoudoro focus & Pomodoro notch countdown timer.
        #[qproperty(bool, notch_coucoudoro_enabled, cxx_name = "notchCoucoudoroEnabled")]
        /// AI agent session tracker and permission approval queue.
        #[qproperty(bool, notch_agent_hooks_enabled, cxx_name = "notchAgentHooksEnabled")]
        /// CodeIsland AI agent task checklist progress bar.
        #[qproperty(bool, notch_agent_tasks_enabled, cxx_name = "notchAgentTasksEnabled")]
        /// Notch mascot type: "mochi" or "antigravity".
        #[qproperty(QString, notch_mascot_type, cxx_name = "notchMascotType")]
        /// QuickShare Android receiver enabled.
        #[qproperty(bool, notch_quickshare_enabled, cxx_name = "notchQuickshareEnabled")]
        /// QuickShare visibility: "everyone", "temporary", "hidden".
        #[qproperty(QString, notch_quickshare_visibility, cxx_name = "notchQuickshareVisibility")]
        /// QuickShare auto-accept transfers from trusted devices.
        #[qproperty(bool, notch_quickshare_auto_accept_trusted, cxx_name = "notchQuickshareAutoAcceptTrusted")]
        /// Caps Lock visual HUD indicator on notch.
        #[qproperty(bool, notch_capslock_hud, cxx_name = "notchCapsLockHud")]
        /// macOS Focus / Do Not Disturb state change indicator on notch.
        #[qproperty(bool, notch_focus_hud, cxx_name = "notchFocusHud")]
        /// Bluetooth audio device connection & battery HUD.
        #[qproperty(bool, notch_bluetooth_hud, cxx_name = "notchBluetoothHud")]
        /// NotchIsland quick command launcher, math evaluator & unit converter.
        #[qproperty(bool, notch_launcher_enabled, cxx_name = "notchLauncherEnabled")]
        /// Island live system download progress HUD on notch.
        #[qproperty(bool, notch_downloads_hud, cxx_name = "notchDownloadsHud")]
        /// Island real-time hardware microphone & camera sensor indicator HUD.
        #[qproperty(bool, notch_privacy_sensor_hud, cxx_name = "notchPrivacySensorHud")]
        /// Ledge standing notch announcements & peripheral vision alerts.
        #[qproperty(bool, notch_announcements_enabled, cxx_name = "notchAnnouncementsEnabled")]
        /// SuperIsland camera-aligned notch teleprompter for presentations & meetings.
        #[qproperty(bool, notch_teleprompter_enabled, cxx_name = "notchTeleprompterEnabled")]
        /// SuperIsland docked instant emoji picker & fuzzy search.
        #[qproperty(bool, notch_emoji_picker_enabled, cxx_name = "notchEmojiPickerEnabled")]
        /// SuperIsland AI token quota and usage monitor rings.
        #[qproperty(bool, notch_ai_usage_enabled, cxx_name = "notchAiUsageEnabled")]
        /// MioIsland synthesized 8-bit chiptune audio cues for agent states & transitions.
        #[qproperty(bool, notch_synth_audio_enabled, cxx_name = "notchSynthAudioEnabled")]
        /// MioIsland direct-to-terminal activation jumper (Ghostty, iTerm, Terminal, Warp, etc.).
        #[qproperty(bool, notch_terminal_jumper_enabled, cxx_name = "notchTerminalJumperEnabled")]
        /// Notchly real-time Wi-Fi & Hotspot network tracking and connection toasts.
        #[qproperty(bool, notch_network_status_enabled, cxx_name = "notchNetworkStatusEnabled")]
        /// Notchly lock screen state detection and island presentation.
        #[qproperty(bool, notch_lock_screen_overlay_enabled, cxx_name = "notchLockScreenOverlayEnabled")]
        /// QuietNotch inline Volume & Brightness HUD directly in the notch.
        #[qproperty(bool, notch_quiet_inline_hud_enabled, cxx_name = "notchQuietInlineHudEnabled")]
        /// QuietNotch system notifications drop/toast directly at the notch.
        #[qproperty(bool, notch_quiet_notifications_enabled, cxx_name = "notchQuietNotificationsEnabled")]
        /// QuietNotch Quiet Hours / DND filter suppressing non-critical alerts.
        #[qproperty(bool, notch_quiet_hours_enabled, cxx_name = "notchQuietHoursEnabled")]
        /// AnotherNotch clipboard history shelf and quick-paste directly in the notch.
        #[qproperty(bool, notch_clipboard_shelf_enabled, cxx_name = "notchClipboardShelfEnabled")]
        /// AnotherNotch Mac fan speed and thermal telemetry monitor.
        #[qproperty(bool, notch_fan_telemetry_enabled, cxx_name = "notchFanTelemetryEnabled")]
        /// GHNotch fast local command bar and natural language expression evaluator.
        #[qproperty(bool, notch_command_engine_enabled, cxx_name = "notchCommandEngineEnabled")]
        /// Isle crypto and foreign exchange financial market ticker.
        #[qproperty(bool, notch_isle_finance_enabled, cxx_name = "notchIsleFinanceEnabled")]
        /// Isle preferred finance ticker symbol (e.g. "BTC", "ETH", "SOL", "EUR").
        #[qproperty(QString, notch_isle_finance_symbol, cxx_name = "notchIsleFinanceSymbol")]
        /// MacIsland battery and fast charge HUD indicator at the notch.
        #[qproperty(bool, notch_macisland_battery_hud_enabled, cxx_name = "notchMacislandBatteryHudEnabled")]
        /// MacIsland direct AirDrop target from notch shelf.
        #[qproperty(bool, notch_macisland_airdrop_enabled, cxx_name = "notchMacislandAirdropEnabled")]
        /// MacWake keyboard and screen cleaning lock mode.
        #[qproperty(bool, notch_macwake_cleaning_mode_enabled, cxx_name = "notchMacwakeCleaningModeEnabled")]
        /// MacWake CPU/GPU thermal telemetry monitor.
        #[qproperty(bool, notch_macwake_thermal_monitor_enabled, cxx_name = "notchMacwakeThermalMonitorEnabled")]
        /// PiIsland AI coding agent session monitor and LLM quota telemetry.
        #[qproperty(bool, notch_piisland_session_monitor_enabled, cxx_name = "notchPiislandSessionMonitorEnabled")]
        /// Pookify Claude Code animated spark/crab glyphs and multi-session aggregator.
        #[qproperty(bool, notch_pookify_agent_glyphs_enabled, cxx_name = "notchPookifyAgentGlyphsEnabled")]
        /// Windows Dynamic Island "Find on Screen" Live Vision OCR Search Engine.
        #[qproperty(bool, notch_vision_ocr_search_enabled, cxx_name = "notchVisionOcrSearchEnabled")]
        /// TopNotch Pomodoro Focus & Quick Scratchpad Engine.
        #[qproperty(bool, notch_topnotch_focus_enabled, cxx_name = "notchTopnotchFocusEnabled")]
        /// MacIsland2 Video Call Ring Light & Audio Hardware Switcher.
        #[qproperty(bool, notch_macisland_studio_enabled, cxx_name = "notchMacislandStudioEnabled")]
        /// Stream PC system audio to the connected phone via WASAPI loopback.
        #[qproperty(bool, stream_pc_audio_to_phone)]
        /// Share PC user folders (Downloads, Documents, Desktop, Pictures) with phones.
        #[qproperty(bool, share_pc_storage)]
        /// Forward PC notifications to connected phones (opt-in privacy toggle).
        #[qproperty(bool, forward_pc_notifications_to_phone)]
        /// Stay connected over mobile data (LTE/5G) or relay when away from Wi-Fi.
        #[qproperty(bool, away_mode)]
        /// Alias for `start_with_windows` used by the walkthrough and settings bindings.
        #[qproperty(bool, start_at_login)]
        /// When started at login, start hidden in menu bar without opening window.
        #[qproperty(bool, start_hidden)]
        /// Live macOS SMAppService login item status (0: NotRegistered, 1: Enabled, 2: RequiresApproval, 3: NotFound).
        #[qproperty(i32, login_item_status)]
        /// Whether the first-run setup walkthrough has been completed or skipped.
        #[qproperty(bool, walkthrough_completed)]
        /// Current step index (`0..=6`) in the first-run setup walkthrough.
        #[qproperty(i32, walkthrough_step)]
        /// Whether the gentle "What's new" card on Home has been dismissed.
        #[qproperty(bool, whats_new_dismissed)]
        /// Whether the card on Home inviting to try Hive has been answered.
        #[qproperty(bool, hive_invite_dismissed)]
        /// JSON array of configured `FolderSyncRule` items.
        #[qproperty(QString, folder_sync_rules_json)]
        /// JSON array of configured `AutomationRule` items.
        #[qproperty(QString, automation_rules_json)]
        /// Identifier or name of the monitor where the main window was last placed.
        #[qproperty(QString, window_screen)]
        /// Whether a saved main window `(x, y)` position exists.
        #[qproperty(bool, has_window_position)]
        /// Saved main window X offset relative to the target screen in logical pixels.
        #[qproperty(i32, window_x)]
        /// Saved main window Y offset relative to the target screen in logical pixels.
        #[qproperty(i32, window_y)]
        /// Saved main window normal width in logical pixels.
        #[qproperty(i32, window_width)]
        /// Saved main window normal height in logical pixels.
        #[qproperty(i32, window_height)]
        /// Whether the main window was maximized when last open.
        #[qproperty(bool, window_maximized)]
        type Preferences = super::PreferencesRust;

        /// Resets the setup walkthrough to step 0 and opens it again.
        #[qinvokable]
        fn restart_walkthrough(self: Pin<&mut Preferences>);
        /// The languages the app speaks besides the system's, as a JSON array of
        /// `{ code, name }`, each named in its own language.
        #[qinvokable]
        fn languages(self: &Preferences) -> QString;
        /// Saves the main window's monitor name/identifier, screen-relative position, dimensions, and maximized state.
        #[qinvokable]
        fn save_window_geometry(
            self: Pin<&mut Preferences>,
            screen: &QString,
            has_position: bool,
            x: i32,
            y: i32,
            width: i32,
            height: i32,
            maximized: bool,
        );
        /// OBS Studio's WebSocket port, for `obs:` Deck commands.
        #[qinvokable]
        fn obs_port(self: &Preferences) -> i32;
        /// Whether an OBS password is saved.
        #[qinvokable]
        fn obs_has_password(self: &Preferences) -> bool;
        /// Saves the OBS port and, when `replace_password` is set, the password (empty clears it).
        #[qinvokable]
        fn save_obs(self: Pin<&mut Preferences>, port: i32, password: &QString, replace_password: bool);
        /// Connects to OBS with the saved settings and shows the result as a message.
        #[qinvokable]
        fn test_obs(self: &Preferences);
        /// Toggles or requests registration of the SMAppService login item.
        #[qinvokable]
        fn toggle_login_item(self: Pin<&mut Preferences>);
        /// Refreshes login_item_status from the system.
        #[qinvokable]
        fn refresh_login_item_status(self: Pin<&mut Preferences>);
        /// Opens System Settings -> General -> Login Items.
        #[qinvokable]
        fn open_login_item_settings(self: &Preferences);

        /// Sets the folder where voice recordings are saved (from a `file:` URL or path).
        #[qinvokable]
        fn choose_recordings_folder(self: Pin<&mut Preferences>, url: &QString);
        /// Resets the recordings folder to `Documents/MacLink Recordings`.
        #[qinvokable]
        fn reset_recordings_folder(self: Pin<&mut Preferences>);
        /// Adds a folder sync rule between a phone folder and a PC folder.
        #[qinvokable]
        fn add_folder_sync_rule(
            self: Pin<&mut Preferences>,
            device_id: &QString,
            phone_folder: &QString,
            pc_folder: &QString,
            two_way: bool,
        );
        /// Removes a folder sync rule by ID.
        #[qinvokable]
        fn remove_folder_sync_rule(self: Pin<&mut Preferences>, rule_id: &QString);
        /// Enables or disables a folder sync rule by ID.
        #[qinvokable]
        fn set_folder_sync_rule_enabled(self: Pin<&mut Preferences>, rule_id: &QString, enabled: bool);
        /// Runs all enabled folder sync rules immediately.
        #[qinvokable]
        fn sync_folders_now(self: Pin<&mut Preferences>);
        /// Adds a trigger-action automation rule.
        #[qinvokable]
        fn add_automation_rule(
            self: Pin<&mut Preferences>,
            trigger: &QString,
            action: &QString,
            param: &QString,
        );
        /// Removes an automation rule by ID.
        #[qinvokable]
        fn remove_automation_rule(self: Pin<&mut Preferences>, rule_id: &QString);
        /// Enables or disables an automation rule by ID.
        #[qinvokable]
        fn set_automation_rule_enabled(self: Pin<&mut Preferences>, rule_id: &QString, enabled: bool);

        #[qobject]
        #[qml_element]
        #[qml_singleton]
        #[qproperty(QString, pages_json)]
        #[qproperty(i32, volume)]
        #[qproperty(bool, muted)]
        /// `-1`: no mic, `0`: live, `1`: muted.
        #[qproperty(i32, mic_state)]
        #[qproperty(bool, playing)]
        type DeckController = super::DeckControllerRust;

        #[qinvokable]
        fn default_label_for(self: &DeckController, kind: &QString) -> QString;
        #[qinvokable]
        fn default_icon_for(self: &DeckController, kind: &QString) -> QString;
        #[qinvokable]
        fn default_color_for(self: &DeckController, kind: &QString) -> QString;
        #[qinvokable]
        fn add_page(self: Pin<&mut DeckController>, name: &QString) -> QString;
        #[qinvokable]
        fn rename_page(self: Pin<&mut DeckController>, page_id: &QString, name: &QString);
        #[qinvokable]
        fn remove_page(self: Pin<&mut DeckController>, page_id: &QString);
        #[qinvokable]
        fn reset_default(self: Pin<&mut DeckController>);
        #[qinvokable]
        fn move_tile(self: Pin<&mut DeckController>, page_id: &QString, from_index: i32, to_index: i32);
        #[qinvokable]
        fn remove_tile(self: Pin<&mut DeckController>, page_id: &QString, tile_id: &QString);
        #[qinvokable]
        fn save_tile(
            self: Pin<&mut DeckController>,
            page_id: &QString,
            tile_id: &QString,
            label: &QString,
            icon: &QString,
            color: &QString,
            kind: &QString,
            param: &QString,
            ctrl: bool,
            alt: bool,
            shift: bool,
            win_mod: bool,
        ) -> QString;
        #[qinvokable]
        fn test_tile(self: Pin<&mut DeckController>, tile_id: &QString);
        #[qinvokable]
        fn url_to_local_path(self: &DeckController, url: &QString) -> QString;
        #[qinvokable]
        fn set_page_active(self: &DeckController, active: bool);
    }

    impl cxx_qt::Threading for Preferences {}
    impl cxx_qt::Initialize for Preferences {}
    impl cxx_qt::Threading for DeckController {}
    impl cxx_qt::Initialize for DeckController {}
}

#[derive(Default)]
pub struct PreferencesRust {
    theme: QString,
    seed: QString,
    color_mode: QString,
    amoled: bool,
    backdrop: bool,
    comb_motion: bool,
    close_to_tray: bool,
    auto_clipboard: bool,
    clipboard_history: bool,
    suggest_clipboard_actions: bool,
    auto_copy_otp: bool,
    pause_media_on_call: bool,
    mute_while_watched: bool,
    language: QString,
    sync_dnd: bool,
    send_to_menu: bool,
    start_with_windows: bool,
    start_hidden: bool,
    login_item_status: i32,
    auto_update: bool,
    install_updates: bool,
    battery_alerts: bool,
    recordings_folder: QString,
    recordings_folder_is_default: bool,
    recordings_format: QString,
    timeline_retention_days: i32,
    continuity_photo_hotkey: QString,
    continuity_scan_hotkey: QString,
    command_palette_hotkey: QString,
    shelf_hotkey: QString,
    shelf_edge_trigger: bool,
    shelf_edge_size: QString,
    local_api_enabled: bool,
    local_api_port: i32,
    local_api_token_path: QString,
    clipboard_auto_copy_received_files: bool,
    open_shared_files: bool,
    flow_follow_clipboard: bool,
    maclink_island: bool,
    maclink_island_calls: bool,
    maclink_island_transfers: bool,
    maclink_island_media: bool,
    maclink_island_notifications: bool,
    notch_wings_enabled: bool,
    notch_left_wing_content: QString,
    notch_right_wing_content: QString,
    notch_hardware_attached: bool,
    notch_auto_hide_fullscreen: bool,
    notch_hud_enabled: bool,
    notch_scroll_gestures: bool,
    notch_debug_overlay: bool,
    notch_override_width: f64,
    notch_override_height: f64,
    notch_override_radius: f64,
    notch_drag_to_shelf: bool,
    notch_battery_hud: bool,
    notch_system_media: bool,
    notch_calendar_sneak_peek: bool,
    notch_mochi_companion: bool,
    notch_coucoudoro_enabled: bool,
    notch_agent_hooks_enabled: bool,
    notch_agent_tasks_enabled: bool,
    notch_mascot_type: QString,
    notch_quickshare_enabled: bool,
    notch_quickshare_visibility: QString,
    notch_quickshare_auto_accept_trusted: bool,
    notch_capslock_hud: bool,
    notch_focus_hud: bool,
    notch_bluetooth_hud: bool,
    notch_launcher_enabled: bool,
    notch_downloads_hud: bool,
    notch_privacy_sensor_hud: bool,
    notch_announcements_enabled: bool,
    notch_teleprompter_enabled: bool,
    notch_emoji_picker_enabled: bool,
    notch_ai_usage_enabled: bool,
    notch_synth_audio_enabled: bool,
    notch_terminal_jumper_enabled: bool,
    notch_network_status_enabled: bool,
    notch_lock_screen_overlay_enabled: bool,
    notch_quiet_inline_hud_enabled: bool,
    notch_quiet_notifications_enabled: bool,
    notch_quiet_hours_enabled: bool,
    notch_clipboard_shelf_enabled: bool,
    notch_fan_telemetry_enabled: bool,
    notch_command_engine_enabled: bool,
    notch_isle_finance_enabled: bool,
    notch_isle_finance_symbol: QString,
    notch_macisland_battery_hud_enabled: bool,
    notch_macisland_airdrop_enabled: bool,
    notch_macwake_cleaning_mode_enabled: bool,
    notch_macwake_thermal_monitor_enabled: bool,
    notch_piisland_session_monitor_enabled: bool,
    notch_pookify_agent_glyphs_enabled: bool,
    notch_vision_ocr_search_enabled: bool,
    notch_topnotch_focus_enabled: bool,
    notch_macisland_studio_enabled: bool,
    stream_pc_audio_to_phone: bool,
    share_pc_storage: bool,
    forward_pc_notifications_to_phone: bool,
    away_mode: bool,
    start_at_login: bool,
    walkthrough_completed: bool,
    walkthrough_step: i32,
    whats_new_dismissed: bool,
    hive_invite_dismissed: bool,
    folder_sync_rules_json: QString,
    automation_rules_json: QString,
    window_screen: QString,
    has_window_position: bool,
    window_x: i32,
    window_y: i32,
    window_width: i32,
    window_height: i32,
    window_maximized: bool,
    /// What the user chose (`start_with_windows` shows the default until then).
    start_choice: Option<bool>,
    /// Custom recordings folder if chosen (`None` means default).
    custom_recordings_folder: Option<PathBuf>,
}

impl cxx_qt::Initialize for qobject::Preferences {
    fn initialize(mut self: Pin<&mut Self>) {
        let settings = Settings::load(&core_host::host().data_dir);
        settings.apply_runtime();
        self.as_mut().set_theme(QString::from(match settings.theme {
            Theme::Hive => "hive",
            Theme::Bloom => "bloom",
            Theme::Glass => "glass",
            Theme::Graphite => "graphite",
        }));
        self.as_mut().set_seed(QString::from(&settings.seed));
        self.as_mut().set_color_mode(QString::from(match settings.color_mode {
            ColorMode::System => "system",
            ColorMode::Light => "light",
            ColorMode::Dark => "dark",
        }));
        self.as_mut().set_amoled(settings.amoled);
        self.as_mut().set_backdrop(settings.backdrop);
        self.as_mut().set_comb_motion(settings.comb_motion);
        let close_to_tray = if cfg!(target_os = "macos") { true } else { settings.close_to_tray };
        self.as_mut().set_close_to_tray(close_to_tray);
        self.as_mut().set_auto_clipboard(settings.auto_clipboard);
        crate::clipboard::set_auto_send(settings.auto_clipboard);
        self.as_mut().set_clipboard_history(settings.clipboard_history);
        crate::clipboard::set_history_enabled(settings.clipboard_history);
        self.as_mut().set_suggest_clipboard_actions(settings.suggest_clipboard_actions);
        crate::clipboard::set_suggest_actions(settings.suggest_clipboard_actions);
        self.as_mut().set_auto_copy_otp(settings.auto_copy_otp);
        crate::notifications::set_auto_copy_otp(settings.auto_copy_otp);
        self.as_mut().set_pause_media_on_call(settings.pause_media_on_call);
        self.as_mut().set_mute_while_watched(settings.mute_while_watched);
        self.as_mut().set_language(QString::from(&settings.language));
        crate::pc_mirror::set_mute_while_watched(settings.mute_while_watched);
        crate::calls::set_pause_media_on_call(settings.pause_media_on_call);
        self.as_mut().set_sync_dnd(settings.sync_dnd);
        crate::notifications::set_sync_dnd(settings.sync_dnd);
        self.as_mut().set_send_to_menu(settings.send_to_menu);
        self.as_mut().set_auto_update(settings.auto_update);
        self.as_mut().set_install_updates(settings.install_updates);
        self.as_mut().set_battery_alerts(settings.battery_alerts);
        let start_effective = crate::startup::effective(settings.start_with_windows);
        self.as_mut().set_start_with_windows(start_effective);
        self.as_mut().set_start_at_login(start_effective);
        self.as_mut().rust_mut().start_choice = settings.start_with_windows;
        self.as_mut().set_start_hidden(settings.start_hidden);
        let login_status = crate::mac::autostart::status();
        self.as_mut().set_login_item_status(login_status);
        self.as_mut().set_start_at_login(login_status == crate::mac::autostart::STATUS_ENABLED);
        let effective_folder = crate::recordings::effective_folder(settings.recordings_folder.as_deref());
        self.as_mut().set_recordings_folder(QString::from(&effective_folder.to_string_lossy().into_owned()));
        self.as_mut().set_recordings_folder_is_default(settings.recordings_folder.is_none());
        self.as_mut().rust_mut().custom_recordings_folder = settings.recordings_folder.clone();
        self.as_mut().set_recordings_format(QString::from(settings.recordings_format.as_str()));
        self.as_mut().set_timeline_retention_days(settings.timeline_retention_days as i32);
        self.as_mut().set_continuity_photo_hotkey(QString::from(&settings.continuity_photo_hotkey));
        self.as_mut().set_continuity_scan_hotkey(QString::from(&settings.continuity_scan_hotkey));
        self.as_mut().set_command_palette_hotkey(QString::from(&settings.command_palette_hotkey));
        self.as_mut().set_shelf_hotkey(QString::from(&settings.shelf_hotkey));
        self.as_mut().set_shelf_edge_trigger(settings.shelf_edge_trigger);
        self.as_mut().set_shelf_edge_size(QString::from(&settings.shelf_edge_size));
        crate::win::shelf_edge::set_enabled(settings.shelf_edge_trigger);
        crate::win::shelf_edge::set_size(&settings.shelf_edge_size);
        self.as_mut().set_local_api_enabled(settings.local_api_enabled);
        self.as_mut().set_local_api_port(i32::from(settings.local_api_port));
        let token_path = crate::local_api::token_file_path();
        self.as_mut().set_local_api_token_path(QString::from(&token_path.to_string_lossy().into_owned()));
        self.as_mut().set_clipboard_auto_copy_received_files(settings.clipboard_auto_copy_received_files);
        self.as_mut().set_open_shared_files(settings.open_shared_files);
        self.as_mut().set_flow_follow_clipboard(settings.flow_follow_clipboard);
        self.as_mut().set_maclink_island(settings.maclink_island);
        self.as_mut().set_maclink_island_calls(settings.maclink_island_calls);
        self.as_mut().set_maclink_island_transfers(settings.maclink_island_transfers);
        self.as_mut().set_maclink_island_media(settings.maclink_island_media);
        self.as_mut().set_maclink_island_notifications(settings.maclink_island_notifications);
        self.as_mut().set_notch_wings_enabled(settings.notch_wings_enabled);
        self.as_mut().set_notch_left_wing_content(QString::from(&settings.notch_left_wing_content));
        self.as_mut().set_notch_right_wing_content(QString::from(&settings.notch_right_wing_content));
        self.as_mut().set_notch_hardware_attached(settings.notch_hardware_attached);
        self.as_mut().set_notch_auto_hide_fullscreen(settings.notch_auto_hide_fullscreen);
        self.as_mut().set_notch_hud_enabled(settings.notch_hud_enabled);
        self.as_mut().set_notch_scroll_gestures(settings.notch_scroll_gestures);
        self.as_mut().set_notch_debug_overlay(settings.notch_debug_overlay);
        self.as_mut().set_notch_override_width(settings.notch_override_width);
        self.as_mut().set_notch_override_height(settings.notch_override_height);
        self.as_mut().set_notch_override_radius(settings.notch_override_radius);
        self.as_mut().set_notch_drag_to_shelf(settings.notch_drag_to_shelf);
        self.as_mut().set_notch_battery_hud(settings.notch_battery_hud);
        self.as_mut().set_notch_system_media(settings.notch_system_media);
        self.as_mut().set_notch_calendar_sneak_peek(settings.notch_calendar_sneak_peek);
        self.as_mut().set_notch_mochi_companion(settings.notch_mochi_companion);
        self.as_mut().set_notch_coucoudoro_enabled(settings.notch_coucoudoro_enabled);
        self.as_mut().set_notch_agent_hooks_enabled(settings.notch_agent_hooks_enabled);
        self.as_mut().set_notch_agent_tasks_enabled(settings.notch_agent_tasks_enabled);
        self.as_mut().set_notch_mascot_type(QString::from(&settings.notch_mascot_type));
        self.as_mut().set_notch_quickshare_enabled(settings.notch_quickshare_enabled);
        self.as_mut().set_notch_quickshare_visibility(QString::from(&settings.notch_quickshare_visibility));
        self.as_mut().set_notch_quickshare_auto_accept_trusted(settings.notch_quickshare_auto_accept_trusted);
        self.as_mut().set_notch_capslock_hud(settings.notch_capslock_hud);
        self.as_mut().set_notch_focus_hud(settings.notch_focus_hud);
        self.as_mut().set_notch_bluetooth_hud(settings.notch_bluetooth_hud);
        self.as_mut().set_notch_launcher_enabled(settings.notch_launcher_enabled);
        self.as_mut().set_notch_downloads_hud(settings.notch_downloads_hud);
        self.as_mut().set_notch_privacy_sensor_hud(settings.notch_privacy_sensor_hud);
        self.as_mut().set_notch_announcements_enabled(settings.notch_announcements_enabled);
        self.as_mut().set_notch_teleprompter_enabled(settings.notch_teleprompter_enabled);
        self.as_mut().set_notch_emoji_picker_enabled(settings.notch_emoji_picker_enabled);
        self.as_mut().set_notch_ai_usage_enabled(settings.notch_ai_usage_enabled);
        self.as_mut().set_notch_synth_audio_enabled(settings.notch_synth_audio_enabled);
        self.as_mut().set_notch_terminal_jumper_enabled(settings.notch_terminal_jumper_enabled);
        self.as_mut().set_notch_network_status_enabled(settings.notch_network_status_enabled);
        self.as_mut().set_notch_lock_screen_overlay_enabled(settings.notch_lock_screen_overlay_enabled);
        self.as_mut().set_notch_quiet_inline_hud_enabled(settings.notch_quiet_inline_hud_enabled);
        self.as_mut().set_notch_quiet_notifications_enabled(settings.notch_quiet_notifications_enabled);
        self.as_mut().set_notch_quiet_hours_enabled(settings.notch_quiet_hours_enabled);
        self.as_mut().set_notch_clipboard_shelf_enabled(settings.notch_clipboard_shelf_enabled);
        self.as_mut().set_notch_fan_telemetry_enabled(settings.notch_fan_telemetry_enabled);
        self.as_mut().set_notch_command_engine_enabled(settings.notch_command_engine_enabled);
        self.as_mut().set_notch_isle_finance_enabled(settings.notch_isle_finance_enabled);
        self.as_mut().set_notch_isle_finance_symbol(QString::from(&settings.notch_isle_finance_symbol));
        self.as_mut().set_notch_macisland_battery_hud_enabled(settings.notch_macisland_battery_hud_enabled);
        self.as_mut().set_notch_macisland_airdrop_enabled(settings.notch_macisland_airdrop_enabled);
        self.as_mut().set_notch_macwake_cleaning_mode_enabled(settings.notch_macwake_cleaning_mode_enabled);
        self.as_mut().set_notch_macwake_thermal_monitor_enabled(settings.notch_macwake_thermal_monitor_enabled);
        self.as_mut().set_notch_piisland_session_monitor_enabled(settings.notch_piisland_session_monitor_enabled);
        self.as_mut().set_notch_pookify_agent_glyphs_enabled(settings.notch_pookify_agent_glyphs_enabled);
        self.as_mut().set_notch_vision_ocr_search_enabled(settings.notch_vision_ocr_search_enabled);
        self.as_mut().set_notch_topnotch_focus_enabled(settings.notch_topnotch_focus_enabled);
        self.as_mut().set_notch_macisland_studio_enabled(settings.notch_macisland_studio_enabled);
        crate::dynamo::set_debug_overlay_enabled(settings.notch_debug_overlay);
        crate::dynamo::set_manual_notch_override(
            settings.notch_override_width,
            settings.notch_override_height,
            settings.notch_override_radius,
        );
        self.as_mut().set_stream_pc_audio_to_phone(settings.stream_pc_audio_to_phone);
        self.as_mut().set_share_pc_storage(settings.share_pc_storage);
        self.as_mut().set_forward_pc_notifications_to_phone(settings.forward_pc_notifications_to_phone);
        self.as_mut().set_away_mode(settings.away_mode);
        self.as_mut().set_walkthrough_completed(settings.walkthrough_completed);
        self.as_mut().set_walkthrough_step(i32::from(settings.walkthrough_step.min(6)));
        self.as_mut().set_whats_new_dismissed(settings.whats_new_dismissed);
        self.as_mut().set_hive_invite_dismissed(settings.hive_invite_dismissed);
        let folder_rules_json =
            serde_json::to_string(&settings.folder_sync_rules).unwrap_or_else(|_| "[]".into());
        self.as_mut().set_folder_sync_rules_json(QString::from(&folder_rules_json));
        let automation_rules_json =
            serde_json::to_string(&settings.automation_rules).unwrap_or_else(|_| "[]".into());
        self.as_mut().set_automation_rules_json(QString::from(&automation_rules_json));
        self.as_mut().set_window_screen(QString::from(settings.window_screen.as_deref().unwrap_or("")));
        self.as_mut().set_has_window_position(settings.window_x.is_some() && settings.window_y.is_some());
        self.as_mut().set_window_x(settings.window_x.unwrap_or(0));
        self.as_mut().set_window_y(settings.window_y.unwrap_or(0));
        self.as_mut().set_window_width(settings.window_width as i32);
        self.as_mut().set_window_height(settings.window_height as i32);
        self.as_mut().set_window_maximized(settings.window_maximized);
        crate::win::tray::update_hotkeys(
            &settings.continuity_photo_hotkey,
            &settings.continuity_scan_hotkey,
            &settings.command_palette_hotkey,
            &settings.shelf_hotkey,
        );
        crate::recordings::init(&settings);

        // Save after any change (connected after loading, so loading doesn't
        // rewrite the file).
        self.as_mut().on_theme_changed(|p| p.save()).release();
        self.as_mut().on_seed_changed(|p| p.save()).release();
        self.as_mut().on_color_mode_changed(|p| p.save()).release();
        self.as_mut().on_amoled_changed(|p| p.save()).release();
        self.as_mut().on_backdrop_changed(|p| p.save()).release();
        self.as_mut().on_comb_motion_changed(|p| p.save()).release();
        self.as_mut()
            .on_close_to_tray_changed(|p| {
                #[cfg(target_os = "macos")]
                let mut p = p;
                #[cfg(target_os = "macos")]
                if p.close_to_tray {
                    p.as_mut().set_close_to_tray(false);
                    return;
                }
                p.save();
            })
            .release();
        self.as_mut()
            .on_auto_clipboard_changed(|p| {
                crate::clipboard::set_auto_send(p.auto_clipboard);
                p.save();
            })
            .release();
        self.as_mut()
            .on_clipboard_history_changed(|p| {
                crate::clipboard::set_history_enabled(p.clipboard_history);
                p.save();
            })
            .release();
        self.as_mut()
            .on_suggest_clipboard_actions_changed(|p| {
                crate::clipboard::set_suggest_actions(p.suggest_clipboard_actions);
                p.save();
            })
            .release();
        self.as_mut()
            .on_auto_copy_otp_changed(|p| {
                crate::notifications::set_auto_copy_otp(p.auto_copy_otp);
                p.save();
            })
            .release();
        self.as_mut()
            .on_language_changed(|p| {
                crate::i18n::install(&String::from(&p.language));
                p.save();
            })
            .release();
        self.as_mut()
            .on_mute_while_watched_changed(|p| {
                crate::pc_mirror::set_mute_while_watched(p.mute_while_watched);
                p.save();
            })
            .release();
        self.as_mut()
            .on_pause_media_on_call_changed(|p| {
                crate::calls::set_pause_media_on_call(p.pause_media_on_call);
                p.save();
            })
            .release();
        self.as_mut()
            .on_sync_dnd_changed(|p| {
                crate::notifications::set_sync_dnd(p.sync_dnd);
                p.save();
            })
            .release();
        self.as_mut()
            .on_send_to_menu_changed(|p| {
                crate::send_to::set_enabled(p.send_to_menu);
                p.save();
            })
            .release();
        self.as_mut()
            .on_auto_update_changed(|p| {
                crate::updater::set_auto(p.auto_update);
                p.save();
            })
            .release();
        self.as_mut()
            .on_install_updates_changed(|p| {
                crate::updater::set_auto_install(p.install_updates);
                p.save();
            })
            .release();
        self.as_mut()
            .on_battery_alerts_changed(|p| {
                crate::battery::set_enabled(p.battery_alerts);
                p.save();
            })
            .release();
        self.as_mut()
            .on_start_hidden_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_start_with_windows_changed(|mut p| {
                let on = p.start_with_windows;
                if *p.start_at_login() != on {
                    p.as_mut().set_start_at_login(on);
                }
                p.as_mut().rust_mut().start_choice = Some(on);
                crate::startup::apply(on);
                p.save();
            })
            .release();
        self.as_mut()
            .on_start_at_login_changed(|mut p| {
                let on = p.start_at_login;
                if *p.start_with_windows() != on {
                    p.as_mut().set_start_with_windows(on);
                }
            })
            .release();
        self.as_mut()
            .on_recordings_format_changed(|p| {
                let fmt = RecordingFormat::from_str_lossy(&String::from(&p.recordings_format));
                crate::recordings::set_format(fmt);
                p.save();
            })
            .release();
        self.as_mut()
            .on_timeline_retention_days_changed(|p| {
                let days = p.timeline_retention_days.max(0) as u32;
                if let Some(node) = core_host::node() {
                    let _ = node.set_timeline_retention(maclink_core::TimelineRetention {
                        max_days: days,
                        max_entries: maclink_core::DEFAULT_TIMELINE_MAX_ENTRIES,
                    });
                }
                p.save();
            })
            .release();
        self.as_mut()
            .on_continuity_photo_hotkey_changed(|p| {
                crate::win::tray::update_hotkeys(
                    &String::from(&p.continuity_photo_hotkey),
                    &String::from(&p.continuity_scan_hotkey),
                    &String::from(&p.command_palette_hotkey),
                    &String::from(&p.shelf_hotkey),
                );
                p.save();
            })
            .release();
        self.as_mut()
            .on_continuity_scan_hotkey_changed(|p| {
                crate::win::tray::update_hotkeys(
                    &String::from(&p.continuity_photo_hotkey),
                    &String::from(&p.continuity_scan_hotkey),
                    &String::from(&p.command_palette_hotkey),
                    &String::from(&p.shelf_hotkey),
                );
                p.save();
            })
            .release();
        self.as_mut()
            .on_command_palette_hotkey_changed(|p| {
                crate::win::tray::update_hotkeys(
                    &String::from(&p.continuity_photo_hotkey),
                    &String::from(&p.continuity_scan_hotkey),
                    &String::from(&p.command_palette_hotkey),
                    &String::from(&p.shelf_hotkey),
                );
                p.save();
            })
            .release();
        self.as_mut()
            .on_shelf_hotkey_changed(|p| {
                crate::win::tray::update_hotkeys(
                    &String::from(&p.continuity_photo_hotkey),
                    &String::from(&p.continuity_scan_hotkey),
                    &String::from(&p.command_palette_hotkey),
                    &String::from(&p.shelf_hotkey),
                );
                p.save();
            })
            .release();
        self.as_mut()
            .on_shelf_edge_trigger_changed(|p| {
                let on = p.shelf_edge_trigger;
                crate::settings::set_shelf_edge_trigger(on);
                crate::win::shelf_edge::set_enabled(on);
                p.save();
            })
            .release();
        self.as_mut()
            .on_shelf_edge_size_changed(|p| {
                let size = String::from(&p.shelf_edge_size);
                crate::settings::set_shelf_edge_size(&size);
                crate::win::shelf_edge::set_size(&size);
                p.save();
            })
            .release();
        self.as_mut()
            .on_local_api_enabled_changed(|mut p| {
                let token_path = crate::local_api::token_file_path();
                p.as_mut()
                    .set_local_api_token_path(QString::from(&token_path.to_string_lossy().into_owned()));
                let settings = p.current_settings();
                let _ = settings.save(&core_host::host().data_dir);
                crate::local_api::sync_from_settings();
                save_in_background(settings);
            })
            .release();
        self.as_mut()
            .on_local_api_port_changed(|mut p| {
                let token_path = crate::local_api::token_file_path();
                p.as_mut()
                    .set_local_api_token_path(QString::from(&token_path.to_string_lossy().into_owned()));
                let settings = p.current_settings();
                let _ = settings.save(&core_host::host().data_dir);
                crate::local_api::sync_from_settings();
                save_in_background(settings);
            })
            .release();
        self.as_mut()
            .on_clipboard_auto_copy_received_files_changed(|p| {
                crate::settings::set_clipboard_auto_copy_received_files(p.clipboard_auto_copy_received_files);
                p.save();
            })
            .release();
        self.as_mut()
            .on_open_shared_files_changed(|p| {
                crate::settings::set_open_shared_files(p.open_shared_files);
                p.save();
            })
            .release();
        self.as_mut()
            .on_flow_follow_clipboard_changed(|p| {
                crate::settings::set_flow_follow_clipboard(p.flow_follow_clipboard);
                p.save();
            })
            .release();
        self.as_mut()
            .on_maclink_island_changed(|p| {
                crate::settings::set_maclink_island(p.maclink_island);
                p.save();
            })
            .release();
        self.as_mut().on_maclink_island_calls_changed(|p| p.save()).release();
        self.as_mut().on_maclink_island_transfers_changed(|p| p.save()).release();
        self.as_mut().on_maclink_island_media_changed(|p| p.save()).release();
        self.as_mut().on_maclink_island_notifications_changed(|p| p.save()).release();
        self.as_mut().on_notch_wings_enabled_changed(|p| p.save()).release();
        self.as_mut().on_notch_left_wing_content_changed(|p| p.save()).release();
        self.as_mut().on_notch_right_wing_content_changed(|p| p.save()).release();
        self.as_mut().on_notch_hardware_attached_changed(|p| p.save()).release();
        self.as_mut().on_notch_auto_hide_fullscreen_changed(|p| p.save()).release();
        self.as_mut().on_notch_hud_enabled_changed(|p| p.save()).release();
        self.as_mut().on_notch_scroll_gestures_changed(|p| p.save()).release();
        self.as_mut()
            .on_notch_debug_overlay_changed(|p| {
                crate::dynamo::set_debug_overlay_enabled(*p.notch_debug_overlay());
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_override_width_changed(|p| {
                crate::dynamo::set_manual_notch_override(
                    *p.notch_override_width(),
                    *p.notch_override_height(),
                    *p.notch_override_radius(),
                );
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_override_height_changed(|p| {
                crate::dynamo::set_manual_notch_override(
                    *p.notch_override_width(),
                    *p.notch_override_height(),
                    *p.notch_override_radius(),
                );
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_override_radius_changed(|p| {
                crate::dynamo::set_manual_notch_override(
                    *p.notch_override_width(),
                    *p.notch_override_height(),
                    *p.notch_override_radius(),
                );
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_drag_to_shelf_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_battery_hud_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_system_media_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_calendar_sneak_peek_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_mochi_companion_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_coucoudoro_enabled_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_agent_hooks_enabled_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_agent_tasks_enabled_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_mascot_type_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_quickshare_enabled_changed(|p| {
                crate::dynamo::set_quickshare_enabled(p.notch_quickshare_enabled);
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_quickshare_visibility_changed(|p| {
                crate::dynamo::set_quickshare_visibility(&p.notch_quickshare_visibility.to_string());
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_quickshare_auto_accept_trusted_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_capslock_hud_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_focus_hud_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_bluetooth_hud_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_launcher_enabled_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_downloads_hud_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_privacy_sensor_hud_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_announcements_enabled_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_teleprompter_enabled_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_emoji_picker_enabled_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_ai_usage_enabled_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_synth_audio_enabled_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_terminal_jumper_enabled_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_network_status_enabled_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_lock_screen_overlay_enabled_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_quiet_inline_hud_enabled_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_quiet_notifications_enabled_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_quiet_hours_enabled_changed(|p| {
                crate::dynamo::set_quiet_hours_enabled(p.notch_quiet_hours_enabled);
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_clipboard_shelf_enabled_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_fan_telemetry_enabled_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_command_engine_enabled_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_isle_finance_enabled_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_isle_finance_symbol_changed(|p| {
                crate::dynamo::set_isle_symbol(&p.notch_isle_finance_symbol.to_string());
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_macisland_battery_hud_enabled_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_macisland_airdrop_enabled_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_macwake_cleaning_mode_enabled_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_macwake_thermal_monitor_enabled_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_piisland_session_monitor_enabled_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_pookify_agent_glyphs_enabled_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_vision_ocr_search_enabled_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_topnotch_focus_enabled_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_notch_macisland_studio_enabled_changed(|p| {
                p.save();
            })
            .release();
        self.as_mut()
            .on_stream_pc_audio_to_phone_changed(|p| {
                crate::settings::set_stream_pc_audio_to_phone(p.stream_pc_audio_to_phone);
                p.save();
            })
            .release();
        self.as_mut()
            .on_share_pc_storage_changed(|p| {
                crate::settings::set_share_pc_storage(p.share_pc_storage);
                p.save();
            })
            .release();
        self.as_mut()
            .on_forward_pc_notifications_to_phone_changed(|p| {
                crate::settings::set_forward_pc_notifications_to_phone(p.forward_pc_notifications_to_phone);
                p.save();
            })
            .release();
        self.as_mut()
            .on_away_mode_changed(|p| {
                crate::settings::set_away_mode(p.away_mode);
                p.save();
            })
            .release();
        self.as_mut().on_walkthrough_completed_changed(|p| p.save()).release();
        self.as_mut()
            .on_walkthrough_step_changed(|mut p| {
                let clamped = p.walkthrough_step.clamp(0, 6);
                if p.walkthrough_step != clamped {
                    p.as_mut().set_walkthrough_step(clamped);
                    return;
                }
                p.save();
            })
            .release();
        self.as_mut().on_whats_new_dismissed_changed(|p| p.save()).release();
        self.as_mut().on_hive_invite_dismissed_changed(|p| p.save()).release();

        super::subscribe(self.qt_thread(), crate::state::Changes::PREFS, Self::refresh_runtime_flags);
    }
}

impl qobject::Preferences {
    fn refresh_runtime_flags(mut self: Pin<&mut Self>) {
        let on = crate::pc_audio_stream::is_enabled();
        if *self.stream_pc_audio_to_phone() != on {
            self.as_mut().set_stream_pc_audio_to_phone(on);
        }
        let disk = Settings::load(&core_host::host().data_dir);
        let disk_theme = QString::from(match disk.theme {
            Theme::Hive => "hive",
            Theme::Bloom => "bloom",
            Theme::Glass => "glass",
            Theme::Graphite => "graphite",
        });
        let disk_mode = QString::from(match disk.color_mode {
            ColorMode::System => "system",
            ColorMode::Light => "light",
            ColorMode::Dark => "dark",
        });
        let disk_step = i32::from(disk.walkthrough_step.min(6));
        if *self.theme() != disk_theme {
            self.as_mut().set_theme(disk_theme);
        }
        if *self.color_mode() != disk_mode {
            self.as_mut().set_color_mode(disk_mode);
        }
        if *self.walkthrough_step() != disk_step {
            self.as_mut().set_walkthrough_step(disk_step);
        }
        if *self.walkthrough_completed() != disk.walkthrough_completed {
            self.as_mut().set_walkthrough_completed(disk.walkthrough_completed);
        }
        if *self.whats_new_dismissed() != disk.whats_new_dismissed {
            self.as_mut().set_whats_new_dismissed(disk.whats_new_dismissed);
        }
        let _ = disk.save(&core_host::host().data_dir);
    }

    pub fn restart_walkthrough(mut self: Pin<&mut Self>) {
        self.as_mut().set_walkthrough_step(0);
        self.as_mut().set_walkthrough_completed(false);
        self.save();
    }

    pub fn toggle_login_item(mut self: Pin<&mut Self>) {
        let current_status = crate::mac::autostart::status();
        if current_status == crate::mac::autostart::STATUS_ENABLED {
            let _ = crate::mac::autostart::set_enabled(false);
        } else if current_status == crate::mac::autostart::STATUS_REQUIRES_APPROVAL {
            crate::mac::autostart::open_settings();
        } else {
            let _ = crate::mac::autostart::set_enabled(true);
        }
        let new_status = crate::mac::autostart::status();
        self.as_mut().set_login_item_status(new_status);
        self.as_mut().set_start_at_login(new_status == crate::mac::autostart::STATUS_ENABLED);
    }

    pub fn refresh_login_item_status(mut self: Pin<&mut Self>) {
        let status = crate::mac::autostart::status();
        self.as_mut().set_login_item_status(status);
        self.as_mut().set_start_at_login(status == crate::mac::autostart::STATUS_ENABLED);
    }

    pub fn open_login_item_settings(&self) {
        crate::mac::autostart::open_settings();
    }

    pub fn languages(&self) -> QString {
        QString::from(&crate::i18n::languages_json())
    }

    pub fn save_window_geometry(
        mut self: Pin<&mut Self>,
        screen: &QString,
        has_position: bool,
        x: i32,
        y: i32,
        width: i32,
        height: i32,
        maximized: bool,
    ) {
        let clamped_w = (width.max(crate::settings::MIN_WINDOW_WIDTH as i32) as u32)
            .min(crate::settings::MAX_WINDOW_WIDTH);
        let clamped_h = (height.max(crate::settings::MIN_WINDOW_HEIGHT as i32) as u32)
            .min(crate::settings::MAX_WINDOW_HEIGHT);
        let screen_str = String::from(screen).trim().to_owned();
        let opt_screen = if screen_str.is_empty() { None } else { Some(screen_str.clone()) };
        let (opt_x, opt_y) = if has_position { (Some(x), Some(y)) } else { (None, None) };
        crate::settings::set_window_geometry(opt_screen, opt_x, opt_y, clamped_w, clamped_h, maximized);
        let qscreen = QString::from(&screen_str);
        if *self.window_screen() != qscreen {
            self.as_mut().set_window_screen(qscreen);
        }
        if *self.has_window_position() != has_position {
            self.as_mut().set_has_window_position(has_position);
        }
        if has_position {
            if *self.window_x() != x {
                self.as_mut().set_window_x(x);
            }
            if *self.window_y() != y {
                self.as_mut().set_window_y(y);
            }
        }
        if *self.window_width() != clamped_w as i32 {
            self.as_mut().set_window_width(clamped_w as i32);
        }
        if *self.window_height() != clamped_h as i32 {
            self.as_mut().set_window_height(clamped_h as i32);
        }
        if *self.window_maximized() != maximized {
            self.as_mut().set_window_maximized(maximized);
        }
        let settings = self.current_settings();
        let _ = settings.save(&core_host::host().data_dir);
    }

    pub fn obs_port(&self) -> i32 {
        i32::from(crate::settings::obs_settings().0)
    }

    pub fn obs_has_password(&self) -> bool {
        crate::settings::obs_settings().1.is_some()
    }

    pub fn save_obs(self: Pin<&mut Self>, port: i32, password: &QString, replace_password: bool) {
        let (current_port, current_password) = crate::settings::obs_settings();
        let port = u16::try_from(port).ok().filter(|&p| p >= 1024).unwrap_or(current_port);
        let protected = if replace_password {
            let password = String::from(password);
            if password.is_empty() { None } else { crate::settings::protect_obs_password(&password) }
        } else {
            current_password
        };
        crate::settings::set_obs_settings(port, protected);
        self.save();
    }

    pub fn test_obs(&self) {
        let spawned = std::thread::Builder::new().name("obs-test".into()).spawn(|| {
            let message = match crate::deck::send_obs_command("GetVersion") {
                Ok(()) => tr!("Prefs", "Connected to OBS."),
                Err(e) => e,
            };
            crate::bridge::app::show_message(message);
        });
        if let Err(e) = spawned {
            tracing::warn!(error = %e, "can't test the OBS connection");
        }
    }

    pub fn choose_recordings_folder(mut self: Pin<&mut Self>, url: &QString) {
        let raw = QUrl::from(url)
            .to_local_file()
            .map(|p| String::from(&p))
            .filter(|s| !s.is_empty())
            .unwrap_or_else(|| String::from(url));
        let trimmed = raw.trim();
        if trimmed.is_empty() {
            return;
        }
        let path = PathBuf::from(trimmed);
        self.as_mut().rust_mut().custom_recordings_folder = Some(path.clone());
        self.as_mut().set_recordings_folder(QString::from(&path.to_string_lossy().into_owned()));
        self.as_mut().set_recordings_folder_is_default(false);
        crate::recordings::set_folder(Some(path));
        self.save();
    }

    pub fn reset_recordings_folder(mut self: Pin<&mut Self>) {
        let default = crate::recordings::default_folder();
        self.as_mut().rust_mut().custom_recordings_folder = None;
        self.as_mut().set_recordings_folder(QString::from(&default.to_string_lossy().into_owned()));
        self.as_mut().set_recordings_folder_is_default(true);
        crate::recordings::set_folder(None);
        self.save();
    }

    pub fn add_folder_sync_rule(
        mut self: Pin<&mut Self>,
        device_id: &QString,
        phone_folder: &QString,
        pc_folder: &QString,
        two_way: bool,
    ) {
        let raw_pc = QUrl::from(pc_folder)
            .to_local_file()
            .map(|p| String::from(&p))
            .filter(|s| !s.is_empty())
            .unwrap_or_else(|| String::from(pc_folder));
        let pc_trimmed = raw_pc.trim();
        let phone_trimmed = String::from(phone_folder).trim().to_owned();
        if pc_trimmed.is_empty() || phone_trimmed.is_empty() {
            return;
        }
        let mut rules = crate::settings::folder_sync_rules();
        let next_id = format!("sync-{}", rules.len() + 1);
        rules.push(crate::folder_sync::FolderSyncRule {
            id: next_id,
            phone_id: String::from(device_id).trim().to_owned(),
            phone_folder: phone_trimmed,
            pc_folder: pc_trimmed.to_owned(),
            mode: if two_way { "two_way".into() } else { "one_way_phone_to_pc".into() },
            enabled: true,
        });
        let json = serde_json::to_string(&rules).unwrap_or_else(|_| "[]".into());
        crate::settings::set_folder_sync_rules(rules);
        self.as_mut().set_folder_sync_rules_json(QString::from(&json));
        self.save();
    }

    pub fn remove_folder_sync_rule(mut self: Pin<&mut Self>, rule_id: &QString) {
        let id = String::from(rule_id);
        let mut rules = crate::settings::folder_sync_rules();
        rules.retain(|r| r.id != id);
        let json = serde_json::to_string(&rules).unwrap_or_else(|_| "[]".into());
        crate::settings::set_folder_sync_rules(rules);
        self.as_mut().set_folder_sync_rules_json(QString::from(&json));
        self.save();
    }

    pub fn set_folder_sync_rule_enabled(mut self: Pin<&mut Self>, rule_id: &QString, enabled: bool) {
        let id = String::from(rule_id);
        let mut rules = crate::settings::folder_sync_rules();
        if let Some(rule) = rules.iter_mut().find(|r| r.id == id) {
            rule.enabled = enabled;
        }
        let json = serde_json::to_string(&rules).unwrap_or_else(|_| "[]".into());
        crate::settings::set_folder_sync_rules(rules);
        self.as_mut().set_folder_sync_rules_json(QString::from(&json));
        self.save();
    }

    pub fn sync_folders_now(self: Pin<&mut Self>) {
        let _ = self;
        crate::folder_sync::trigger_sync_now();
    }

    pub fn add_automation_rule(
        mut self: Pin<&mut Self>,
        trigger: &QString,
        action: &QString,
        param: &QString,
    ) {
        let trig = String::from(trigger).trim().to_owned();
        let act = String::from(action).trim().to_owned();
        if trig.is_empty() || act.is_empty() {
            return;
        }
        let mut rules = crate::settings::automation_rules();
        let next_id = format!("auto-{}", rules.len() + 1);
        rules.push(crate::automations::AutomationRule {
            id: next_id,
            name: format!("{trig} → {act}"),
            enabled: true,
            trigger: trig,
            action_kind: act,
            action_arg: String::from(param).trim().to_owned(),
        });
        let json = serde_json::to_string(&rules).unwrap_or_else(|_| "[]".into());
        crate::settings::set_automation_rules(rules);
        self.as_mut().set_automation_rules_json(QString::from(&json));
        self.save();
    }

    pub fn remove_automation_rule(mut self: Pin<&mut Self>, rule_id: &QString) {
        let id = String::from(rule_id);
        let mut rules = crate::settings::automation_rules();
        rules.retain(|r| r.id != id);
        let json = serde_json::to_string(&rules).unwrap_or_else(|_| "[]".into());
        crate::settings::set_automation_rules(rules);
        self.as_mut().set_automation_rules_json(QString::from(&json));
        self.save();
    }

    pub fn set_automation_rule_enabled(mut self: Pin<&mut Self>, rule_id: &QString, enabled: bool) {
        let id = String::from(rule_id);
        let mut rules = crate::settings::automation_rules();
        if let Some(rule) = rules.iter_mut().find(|r| r.id == id) {
            rule.enabled = enabled;
        }
        let json = serde_json::to_string(&rules).unwrap_or_else(|_| "[]".into());
        crate::settings::set_automation_rules(rules);
        self.as_mut().set_automation_rules_json(QString::from(&json));
        self.save();
    }

    fn current_settings(&self) -> Settings {
        let p = self.rust();
        let (win_screen, win_x, win_y, win_w, win_h, win_max) = crate::settings::window_geometry();
        Settings {
            theme: match String::from(&p.theme).as_str() {
                "hive" => Theme::Hive,
                "graphite" => Theme::Graphite,
                "glass" | "blurry" => Theme::Glass,
                _ => Theme::Bloom,
            },
            seed: String::from(&p.seed),
            color_mode: match String::from(&p.color_mode).as_str() {
                "light" => ColorMode::Light,
                "dark" => ColorMode::Dark,
                _ => ColorMode::System,
            },
            amoled: p.amoled,
            backdrop: p.backdrop,
            comb_motion: p.comb_motion,
            close_to_tray: if cfg!(target_os = "macos") { true } else { p.close_to_tray },
            auto_clipboard: p.auto_clipboard,
            clipboard_history: p.clipboard_history,
            suggest_clipboard_actions: p.suggest_clipboard_actions,
            auto_copy_otp: p.auto_copy_otp,
            pause_media_on_call: p.pause_media_on_call,
            mute_while_watched: p.mute_while_watched,
            language: String::from(&p.language),
            sync_dnd: p.sync_dnd,
            send_to_menu: p.send_to_menu,
            auto_update: p.auto_update,
            install_updates: p.install_updates,
            battery_alerts: p.battery_alerts,
            start_with_windows: p.start_choice,
            start_hidden: p.start_hidden,
            recordings_folder: p.custom_recordings_folder.clone(),
            recordings_format: RecordingFormat::from_str_lossy(&String::from(&p.recordings_format)),
            webcam_phone: crate::webcam::selected_phone().map(|d| d.to_string()),
            webcam_height: crate::webcam::height(),
            webcam_mirror: crate::webcam::mirror(),
            webcam_camera: crate::webcam::camera().to_owned(),
            phone_mic_output: crate::phone_mic::chosen_output(),
            phone_mic_gain: crate::phone_mic::gain(),
            timeline_retention_days: p.timeline_retention_days.max(0) as u32,
            continuity_photo_hotkey: String::from(&p.continuity_photo_hotkey),
            continuity_scan_hotkey: String::from(&p.continuity_scan_hotkey),
            command_palette_hotkey: String::from(&p.command_palette_hotkey),
            shelf_hotkey: String::from(&p.shelf_hotkey),
            shelf_edge_trigger: p.shelf_edge_trigger,
            shelf_edge_size: String::from(&p.shelf_edge_size),
            local_api_enabled: p.local_api_enabled,
            local_api_port: u16::try_from(p.local_api_port)
                .ok()
                .filter(|&port| port > 0)
                .unwrap_or(crate::settings::DEFAULT_LOCAL_API_PORT),
            clipboard_auto_copy_received_files: p.clipboard_auto_copy_received_files,
            open_shared_files: p.open_shared_files,
            flow_follow_clipboard: p.flow_follow_clipboard,
            folder_sync_rules: crate::settings::folder_sync_rules(),
            maclink_island: p.maclink_island,
            maclink_island_calls: p.maclink_island_calls,
            maclink_island_transfers: p.maclink_island_transfers,
            maclink_island_media: p.maclink_island_media,
            maclink_island_notifications: p.maclink_island_notifications,
            notch_wings_enabled: p.notch_wings_enabled,
            notch_left_wing_content: p.notch_left_wing_content.to_string(),
            notch_right_wing_content: p.notch_right_wing_content.to_string(),
            notch_hardware_attached: p.notch_hardware_attached,
            notch_auto_hide_fullscreen: p.notch_auto_hide_fullscreen,
            notch_hud_enabled: p.notch_hud_enabled,
            notch_scroll_gestures: p.notch_scroll_gestures,
            notch_debug_overlay: p.notch_debug_overlay,
            notch_override_width: p.notch_override_width,
            notch_override_height: p.notch_override_height,
            notch_override_radius: p.notch_override_radius,
            notch_drag_to_shelf: p.notch_drag_to_shelf,
            notch_battery_hud: p.notch_battery_hud,
            notch_system_media: p.notch_system_media,
            notch_calendar_sneak_peek: p.notch_calendar_sneak_peek,
            notch_mochi_companion: p.notch_mochi_companion,
            notch_coucoudoro_enabled: p.notch_coucoudoro_enabled,
            notch_agent_hooks_enabled: p.notch_agent_hooks_enabled,
            notch_agent_tasks_enabled: p.notch_agent_tasks_enabled,
            notch_mascot_type: p.notch_mascot_type.to_string(),
            notch_quickshare_enabled: p.notch_quickshare_enabled,
            notch_quickshare_visibility: p.notch_quickshare_visibility.to_string(),
            notch_quickshare_auto_accept_trusted: p.notch_quickshare_auto_accept_trusted,
            notch_capslock_hud: p.notch_capslock_hud,
            notch_focus_hud: p.notch_focus_hud,
            notch_bluetooth_hud: p.notch_bluetooth_hud,
            notch_launcher_enabled: p.notch_launcher_enabled,
            notch_downloads_hud: p.notch_downloads_hud,
            notch_privacy_sensor_hud: p.notch_privacy_sensor_hud,
            notch_announcements_enabled: p.notch_announcements_enabled,
            notch_teleprompter_enabled: p.notch_teleprompter_enabled,
            notch_emoji_picker_enabled: p.notch_emoji_picker_enabled,
            notch_ai_usage_enabled: p.notch_ai_usage_enabled,
            notch_synth_audio_enabled: p.notch_synth_audio_enabled,
            notch_terminal_jumper_enabled: p.notch_terminal_jumper_enabled,
            notch_network_status_enabled: p.notch_network_status_enabled,
            notch_lock_screen_overlay_enabled: p.notch_lock_screen_overlay_enabled,
            notch_quiet_inline_hud_enabled: p.notch_quiet_inline_hud_enabled,
            notch_quiet_notifications_enabled: p.notch_quiet_notifications_enabled,
            notch_quiet_hours_enabled: p.notch_quiet_hours_enabled,
            notch_clipboard_shelf_enabled: p.notch_clipboard_shelf_enabled,
            notch_fan_telemetry_enabled: p.notch_fan_telemetry_enabled,
            notch_command_engine_enabled: p.notch_command_engine_enabled,
            notch_isle_finance_enabled: p.notch_isle_finance_enabled,
            notch_isle_finance_symbol: p.notch_isle_finance_symbol.to_string(),
            notch_macisland_battery_hud_enabled: p.notch_macisland_battery_hud_enabled,
            notch_macisland_airdrop_enabled: p.notch_macisland_airdrop_enabled,
            notch_macwake_cleaning_mode_enabled: p.notch_macwake_cleaning_mode_enabled,
            notch_macwake_thermal_monitor_enabled: p.notch_macwake_thermal_monitor_enabled,
            notch_piisland_session_monitor_enabled: p.notch_piisland_session_monitor_enabled,
            notch_pookify_agent_glyphs_enabled: p.notch_pookify_agent_glyphs_enabled,
            notch_vision_ocr_search_enabled: p.notch_vision_ocr_search_enabled,
            notch_topnotch_focus_enabled: p.notch_topnotch_focus_enabled,
            notch_macisland_studio_enabled: p.notch_macisland_studio_enabled,
            automation_rules: crate::settings::automation_rules(),
            stream_pc_audio_to_phone: p.stream_pc_audio_to_phone,
            share_pc_storage: p.share_pc_storage,
            forward_pc_notifications_to_phone: p.forward_pc_notifications_to_phone,
            away_mode: p.away_mode,
            walkthrough_completed: p.walkthrough_completed,
            walkthrough_step: p.walkthrough_step.clamp(0, 6) as u8,
            whats_new_dismissed: p.whats_new_dismissed,
            hive_invite_dismissed: p.hive_invite_dismissed,
            obs_port: crate::settings::obs_settings().0,
            obs_password: crate::settings::obs_settings().1,
            window_screen: win_screen,
            window_x: win_x,
            window_y: win_y,
            window_width: win_w,
            window_height: win_h,
            window_maximized: win_max,
            dynamo_autostart: crate::settings::dynamo_autostart(),
        }
    }

    fn save(self: Pin<&mut Self>) {
        save_in_background(self.current_settings());
    }
}

/// Saves off the UI thread (the write is flushed to disk, which can take a
/// moment), newest settings last even when changes come in quick succession.
fn save_in_background(settings: Settings) {
    static NEXT: AtomicU64 = AtomicU64::new(0);
    static WRITTEN: Mutex<u64> = Mutex::new(0);
    let seq = NEXT.fetch_add(1, Ordering::SeqCst) + 1;
    let save = move || {
        let mut written = WRITTEN.lock().unwrap_or_else(|e| e.into_inner());
        if *written > seq {
            return; // A newer save already ran.
        }
        if let Err(e) = settings.save(&core_host::host().data_dir) {
            tracing::warn!(error = %e, "can't save preferences");
        } else {
            crate::local_api::sync_from_settings();
        }
        *written = seq;
    };
    if let Err(e) = std::thread::Builder::new().name("save-preferences".into()).spawn(save) {
        tracing::warn!(error = %e, "can't save preferences");
    }
}
