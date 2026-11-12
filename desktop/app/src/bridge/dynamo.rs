// SPDX-License-Identifier: GPL-3.0-or-later
//! `DynamoController`: QML singleton exposing LiquidDynamo controls to QML.

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
    }
}

#[derive(Default)]
pub struct DynamoControllerRust {
    status: QString,
    installed_path: QString,
    is_running: bool,
    is_installed: bool,
    autostart: bool,
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

        self.as_mut().set_status(QString::from(current_status.as_str()));
        self.as_mut().set_is_running(running);
        self.as_mut().set_is_installed(installed);
        self.as_mut().set_installed_path(QString::from(&path_str));
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
}
