// SPDX-License-Identifier: GPL-3.0-or-later
//
//  CoucouBridge.swift
//  MacLink Native Coucou Extensions C-ABI Bridge
//  Connects MochiEngine, CoucoudoroService, and AgentHookRelay to Rust & QML
//

import Cocoa
import Foundation

@_cdecl("maclink_init_coucou_services")
public func maclink_init_coucou_services() {
    _ = MochiEngine.shared
    _ = CoucoudoroService.shared
    AgentHookRelay.shared.startSocketServer()
}

@_cdecl("maclink_get_mochi_state_json")
public func maclink_get_mochi_state_json(buffer: UnsafeMutablePointer<CChar>, maxLen: Int) -> Int {
    let state = MochiEngine.shared.getCurrentState()
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

@_cdecl("maclink_poke_mochi")
public func maclink_poke_mochi() {
    MochiEngine.shared.poke()
}

@_cdecl("maclink_set_mochi_mood")
public func maclink_set_mochi_mood(moodPtr: UnsafePointer<CChar>) {
    let moodStr = String(cString: moodPtr)
    if let mood = MochiEngine.Mood(rawValue: moodStr) {
        MochiEngine.shared.setMood(mood)
    }
}

@_cdecl("maclink_coucoudoro_start")
public func maclink_coucoudoro_start() {
    CoucoudoroService.shared.start()
}

@_cdecl("maclink_coucoudoro_pause")
public func maclink_coucoudoro_pause() {
    CoucoudoroService.shared.pause()
}

@_cdecl("maclink_coucoudoro_resume")
public func maclink_coucoudoro_resume() {
    CoucoudoroService.shared.resume()
}

@_cdecl("maclink_coucoudoro_reset")
public func maclink_coucoudoro_reset() {
    CoucoudoroService.shared.reset()
}

@_cdecl("maclink_get_coucoudoro_json")
public func maclink_get_coucoudoro_json(buffer: UnsafeMutablePointer<CChar>, maxLen: Int) -> Int {
    let snap = CoucoudoroService.shared.getSnapshot()
    guard let data = try? JSONEncoder().encode(snap),
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

@_cdecl("maclink_get_agent_hook_json")
public func maclink_get_agent_hook_json(buffer: UnsafeMutablePointer<CChar>, maxLen: Int) -> Int {
    let state = AgentHookRelay.shared.getSnapshot()
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

@_cdecl("maclink_respond_agent_approval")
public func maclink_respond_agent_approval(allow: Bool) {
    AgentHookRelay.shared.respondApproval(allow: allow)
}

@_cdecl("maclink_take_quick_screenshot")
public func maclink_take_quick_screenshot() {
    AgentHookRelay.shared.takeQuickScreenshot()
}
