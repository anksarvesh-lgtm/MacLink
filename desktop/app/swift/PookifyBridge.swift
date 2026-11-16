//
//  PookifyBridge.swift
//  MacLink
//
//  C-bridge exports for eyadhammouda/pookify features:
//  Animated Claude spark/crab status glyphs and multi-session aggregator.
//

import Foundation

@_cdecl("maclink_get_pookify_animation_json")
public func maclink_get_pookify_animation_json(
    _ outBuf: UnsafeMutablePointer<CChar>,
    _ maxLen: Int
) -> Int {
    let json = PookifyAgentAnimationService.shared.getAnimationJson()
    guard let utf8 = json.data(using: .utf8) else { return 0 }
    let count = min(utf8.count, maxLen - 1)
    utf8.withUnsafeBytes { raw in
        if let base = raw.baseAddress {
            outBuf.initialize(from: base.assumingMemoryBound(to: CChar.self), count: count)
        }
    }
    outBuf[count] = 0
    return count
}

@_cdecl("maclink_simulate_pookify_event")
public func maclink_simulate_pookify_event(
    cState: UnsafePointer<CChar>?,
    cTool: UnsafePointer<CChar>?,
    cFile: UnsafePointer<CChar>?
) {
    let state = cState != nil ? String(cString: cState!) : "tool"
    let tool = cTool != nil ? String(cString: cTool!) : "Edit"
    let file = cFile != nil ? String(cString: cFile!) : "IslandWindow.qml"
    PookifyAgentAnimationService.shared.simulatePookifyEvent(state: state, tool: tool, file: file)
}

@_cdecl("maclink_reset_pookify_simulation")
public func maclink_reset_pookify_simulation() {
    PookifyAgentAnimationService.shared.resetSimulation()
}
