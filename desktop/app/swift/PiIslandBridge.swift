//
//  PiIslandBridge.swift
//  MacLink
//
//  C-bridge exports for phun333/pi-island and jwintz/pi-island:
//  AI coding agent telemetry, live session monitoring, and LLM quota stats.
//

import Foundation

@_cdecl("maclink_get_piisland_sessions_json")
public func maclink_get_piisland_sessions_json(
    _ outBuf: UnsafeMutablePointer<CChar>,
    _ maxLen: Int
) -> Int {
    let json = PiIslandAgentSessionService.shared.getAgentSessionsJson()
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

@_cdecl("maclink_simulate_piisland_event")
public func maclink_simulate_piisland_event(
    cAgent: UnsafePointer<CChar>?,
    cModel: UnsafePointer<CChar>?,
    cStatus: UnsafePointer<CChar>?,
    cTool: UnsafePointer<CChar>?
) {
    let agent = cAgent != nil ? String(cString: cAgent!) : "Antigravity"
    let model = cModel != nil ? String(cString: cModel!) : "Gemini 2.5 Pro"
    let status = cStatus != nil ? String(cString: cStatus!) : "Executing Tool"
    let tool = cTool != nil ? String(cString: cTool!) : "run_command"
    PiIslandAgentSessionService.shared.simulateAgentEvent(agent: agent, model: model, status: status, tool: tool)
}

@_cdecl("maclink_reset_piisland_simulation")
public func maclink_reset_piisland_simulation() {
    PiIslandAgentSessionService.shared.resetSimulation()
}
