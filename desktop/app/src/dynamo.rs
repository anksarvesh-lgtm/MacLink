// SPDX-License-Identifier: GPL-3.0-or-later
//! External LiquidDynamo helper process management and life-cycle.

use std::{
    path::PathBuf,
    sync::atomic::{AtomicBool, Ordering},
};

#[path = "bridge/dynamo.rs"]
pub mod bridge;

pub const EXECUTABLE_NAME: &str = "LiquidDynamo";

static LAUNCHED_BY_MACLINK: AtomicBool = AtomicBool::new(false);

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
