//
//  PookifyAgentAnimationService.swift
//  MacLink
//
//  Reverse-engineered from eyadhammouda/pookify:
//  Claude Code & AI agent animated crab & spark glyph engine, multi-session
//  priority aggregator, and turn duration tracker for the notch island.
//

import Foundation
import AppKit

@objc public final class PookifyAgentAnimationService: NSObject {
    @objc public static let shared = PookifyAgentAnimationService()

    private var simState: String? = nil
    private var simTool: String? = nil
    private var simFile: String? = nil
    private var frameTicker: Int = 0

    private let sparkFrames = ["✦", "✧", "✶", "✷", "✸", "✹"]
    private let crabFrames = ["🦀", "🦀~", "~🦀", "🦀·"]

    private override init() {
        super.init()
    }

    @objc public func getAnimationJson() -> String {
        frameTicker = (frameTicker + 1) % 60
        let sparkIndex = (frameTicker / 6) % sparkFrames.count
        let crabIndex = (frameTicker / 8) % crabFrames.count

        let state = simState ?? "tool"
        let tool = simTool ?? "Edit"
        let file = simFile ?? "IslandWindow.qml"

        let isWorking = (state == "thinking" || state == "tool")
        let glyph: String
        switch state {
        case "thinking":
            glyph = sparkFrames[sparkIndex]
        case "tool":
            glyph = crabFrames[crabIndex]
        case "permission":
            glyph = "⚠️"
        case "done":
            glyph = "🎉"
        case "error":
            glyph = "💥"
        default:
            glyph = "🦀"
        }

        let dict: [String: Any] = [
            "provider": "Claude Code",
            "accentColor": "#D97757",
            "state": state,
            "glyph": glyph,
            "isWorking": isWorking,
            "currentTurn": [
                "tool": tool,
                "detail": file,
                "label": state == "tool" ? "Editing \(file)" : (state == "thinking" ? "Reasoning..." : "Awaiting approval"),
                "durationSeconds": 18,
                "needsPermission": state == "permission"
            ],
            "sessions": [
                [
                    "sessionId": "ses_claude_01",
                    "project": "MacLink",
                    "state": state,
                    "model": "claude-3-5-sonnet",
                    "priority": state == "permission" ? 3 : (isWorking ? 2 : 1)
                ]
            ],
            "source": simState != nil ? "Simulated" : "PookifyHookEngine"
        ]

        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }

    @objc public func simulatePookifyEvent(state: String, tool: String, file: String) {
        self.simState = state
        self.simTool = tool
        self.simFile = file
    }

    @objc public func resetSimulation() {
        self.simState = nil
        self.simTool = nil
        self.simFile = nil
    }
}
