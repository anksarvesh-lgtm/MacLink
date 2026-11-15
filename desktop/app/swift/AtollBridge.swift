// SPDX-License-Identifier: GPL-3.0-or-later
// AtollBridge.swift - C-ABI bindings for AtollHUDService

import Foundation

@_cdecl("maclink_init_atoll_services")
public func maclink_init_atoll_services() {
    DispatchQueue.main.async {
        _ = AtollHUDService.shared
    }
}

@_cdecl("maclink_get_atoll_hud_json")
public func maclink_get_atoll_hud_json(buffer: UnsafeMutablePointer<CChar>, maxLen: Int) -> Int {
    let json: String
    if Thread.isMainThread {
        json = MainActor.assumeIsolated {
            AtollHUDService.shared.getStateJSON()
        }
    } else {
        json = DispatchQueue.main.sync {
            AtollHUDService.shared.getStateJSON()
        }
    }
    let count = json.utf8.count
    if count < maxLen {
        json.withCString { ptr in
            buffer.initialize(from: ptr, count: count + 1)
        }
        return count
    }
    return 0
}

@_cdecl("maclink_simulate_capslock_toggle")
public func maclink_simulate_capslock_toggle() {
    DispatchQueue.main.async {
        AtollHUDService.shared.simulateCapsLockToggle()
    }
}

@_cdecl("maclink_simulate_focus_toggle")
public func maclink_simulate_focus_toggle() {
    DispatchQueue.main.async {
        AtollHUDService.shared.simulateFocusToggle()
    }
}

@_cdecl("maclink_simulate_bluetooth_connect")
public func maclink_simulate_bluetooth_connect() {
    DispatchQueue.main.async {
        AtollHUDService.shared.simulateBluetoothConnect()
    }
}
