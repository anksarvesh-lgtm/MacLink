// SPDX-License-Identifier: GPL-3.0-or-later
//! `DynamoController`: QML singleton exposing LiquidDynamo and Native Island controls to QML.

#![allow(unsafe_code)]

use std::pin::Pin;
use cxx_qt_lib::QString;

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
        #[qproperty(QString, telemetry_json, cxx_name = "telemetryJson")]
        #[qproperty(QString, system_hud_json, cxx_name = "systemHudJson")]
        #[qproperty(QString, privacy_guard_json, cxx_name = "privacyGuardJson")]
        #[qproperty(bool, caffeinate_active, cxx_name = "caffeinateActive")]
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
        fn expand(self: &DynamoController);
        #[qinvokable]
        fn collapse(self: &DynamoController);

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
    }
}

pub struct DynamoControllerRust {
    status: QString,
    installed_path: QString,
    is_running: bool,
    is_installed: bool,
    autostart: bool,
    telemetry_json: QString,
    system_hud_json: QString,
    privacy_guard_json: QString,
    caffeinate_active: bool,
}

impl Default for DynamoControllerRust {
    fn default() -> Self {
        Self {
            status: QString::from("installed"),
            installed_path: QString::default(),
            is_running: true,
            is_installed: true,
            autostart: true,
            telemetry_json: QString::from(crate::dynamo::get_telemetry_json().as_str()),
            system_hud_json: QString::from(r#"{"visible":false}"#),
            privacy_guard_json: QString::from(r#"{"cameraActive":false,"micActive":false}"#),
            caffeinate_active: false,
        }
    }
}

impl cxx_qt::Initialize for qobject::DynamoController {
    fn initialize(mut self: Pin<&mut Self>) {
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
        let current_status = crate::dynamo::status();
        let running = current_status == crate::dynamo::DynamoStatus::Running;
        let installed = current_status != crate::dynamo::DynamoStatus::NotInstalled;
        let path_str = crate::dynamo::locate_app()
            .map(|p| p.to_string_lossy().into_owned())
            .unwrap_or_default();
        let autostart = crate::settings::dynamo_autostart();
        let telemetry = crate::dynamo::get_telemetry_json();
        let is_caff = crate::dynamo::is_caffeinate_active();

        self.as_mut().set_status(QString::from(current_status.as_str()));
        self.as_mut().set_is_running(running);
        self.as_mut().set_is_installed(installed);
        self.as_mut().set_installed_path(QString::from(&path_str));
        self.as_mut().set_telemetry_json(QString::from(&telemetry));
        self.as_mut().set_caffeinate_active(is_caff);
        if *self.autostart() != autostart {
            self.as_mut().set_autostart(autostart);
        }
    }

    pub fn launch(mut self: Pin<&mut Self>) {
        crate::dynamo::launch();
        self.as_mut().refresh();
    }

    pub fn stop(mut self: Pin<&mut Self>) {
        crate::dynamo::stop();
        self.as_mut().refresh();
    }

    pub fn open_settings(self: &Self) {
        crate::dynamo::open_settings();
    }

    pub fn expand(self: &Self) {
        crate::dynamo::expand();
    }

    pub fn collapse(self: &Self) {
        crate::dynamo::collapse();
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
}
