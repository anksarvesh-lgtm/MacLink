// SPDX-License-Identifier: GPL-3.0-or-later
//
//  BoringNotchBridge.swift
//  MacLink Native Boring Notch C-ABI Bridge
//  Connects Swift DragDetector, BatteryActivityManager, SystemMediaController, and CalendarManager to Rust & QML
//

import Cocoa
import Foundation

private var dragEnterCallback: (@convention(c) () -> Void)?
private var powerConnectedCallback: (@convention(c) () -> Void)?

@_cdecl("maclink_init_boring_services")
public func maclink_init_boring_services() {
    _ = BatteryActivityManager.shared
    _ = SystemMediaController.shared
    _ = CalendarManager.shared

    NotchDragDetector.shared.onDragEnter = {
        dragEnterCallback?()
    }

    BatteryActivityManager.shared.onPowerConnected = {
        powerConnectedCallback?()
    }
}

@_cdecl("maclink_register_drag_enter_callback")
public func maclink_register_drag_enter_callback(cb: @convention(c) () -> Void) {
    dragEnterCallback = cb
}

@_cdecl("maclink_register_power_connected_callback")
public func maclink_register_power_connected_callback(cb: @convention(c) () -> Void) {
    powerConnectedCallback = cb
}

@_cdecl("maclink_configure_notch_drag")
public func maclink_configure_notch_drag(minX: Double, maxX: Double, height: Double) {
    let mainScreen = NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main
    let screenH = mainScreen?.frame.height ?? 1080.0
    // AppKit coordinates: origin is bottom-left
    let rect = CGRect(
        x: CGFloat(minX),
        y: screenH - CGFloat(height) - 10.0,
        width: CGFloat(maxX - minX),
        height: CGFloat(height) + 10.0
    )
    NotchDragDetector.shared.configureNotchRegion(rect: rect)
}

@_cdecl("maclink_start_notch_drag")
public func maclink_start_notch_drag() {
    NotchDragDetector.shared.startMonitoring()
}

@_cdecl("maclink_stop_notch_drag")
public func maclink_stop_notch_drag() {
    NotchDragDetector.shared.stopMonitoring()
}

@_cdecl("maclink_is_notch_drag_active")
public func maclink_is_notch_drag_active() -> Bool {
    return NotchDragDetector.shared.hasEnteredNotchRegion
}

@_cdecl("maclink_get_battery_status_json")
public func maclink_get_battery_status_json(buffer: UnsafeMutablePointer<CChar>, maxLen: Int) -> Int {
    let status = BatteryActivityManager.shared.getCurrentStatus()
    guard let data = try? JSONEncoder().encode(status),
          let str = String(data: data, encoding: .utf8) else {
        return 0
    }
    let count = str.utf8.count
    if count < maxLen {
        str.withCString { ptr in
            buffer.initialize(from: ptr, count: count + 1)
        }
        return count
    }
    return 0
}

@_cdecl("maclink_get_system_media_json")
public func maclink_get_system_media_json(buffer: UnsafeMutablePointer<CChar>, maxLen: Int) -> Int {
    let state = SystemMediaController.shared.getCurrentState()
    guard let data = try? JSONEncoder().encode(state),
          let str = String(data: data, encoding: .utf8) else {
        return 0
    }
    let count = str.utf8.count
    if count < maxLen {
        str.withCString { ptr in
            buffer.initialize(from: ptr, count: count + 1)
        }
        return count
    }
    return 0
}

@_cdecl("maclink_media_play_pause")
public func maclink_media_play_pause() {
    SystemMediaController.shared.playPause()
}

@_cdecl("maclink_media_next")
public func maclink_media_next() {
    SystemMediaController.shared.nextTrack()
}

@_cdecl("maclink_media_previous")
public func maclink_media_previous() {
    SystemMediaController.shared.previousTrack()
}

@_cdecl("maclink_get_calendar_event_json")
public func maclink_get_calendar_event_json(buffer: UnsafeMutablePointer<CChar>, maxLen: Int) -> Int {
    let evt = CalendarManager.shared.getCurrentEvent()
    guard let data = try? JSONEncoder().encode(evt),
          let str = String(data: data, encoding: .utf8) else {
        return 0
    }
    let count = str.utf8.count
    if count < maxLen {
        str.withCString { ptr in
            buffer.initialize(from: ptr, count: count + 1)
        }
        return count
    }
    return 0
}
