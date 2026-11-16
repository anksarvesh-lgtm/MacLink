import Foundation
import AppKit

@objc public final class MioIslandTerminalJumperService: NSObject, @unchecked Sendable {
    public static let shared = MioIslandTerminalJumperService()

    private struct TerminalApp {
        let name: String
        let bundleId: String
    }

    private let supportedTerminals: [TerminalApp] = [
        TerminalApp(name: "Ghostty", bundleId: "com.mitchellh.ghostty"),
        TerminalApp(name: "iTerm2", bundleId: "com.googlecode.iterm2"),
        TerminalApp(name: "Warp", bundleId: "dev.warp.Warp-Stable"),
        TerminalApp(name: "Terminal", bundleId: "com.apple.Terminal"),
        TerminalApp(name: "Alacritty", bundleId: "org.alacritty"),
        TerminalApp(name: "Kitty", bundleId: "net.kovidgoyal.kitty"),
        TerminalApp(name: "WezTerm", bundleId: "com.github.wez.wezterm"),
        TerminalApp(name: "VS Code", bundleId: "com.microsoft.VSCode")
    ]

    private override init() {
        super.init()
    }

    public func start() {
        // Ready
    }

    public func getRunningTerminals() -> [String] {
        var running: [String] = []
        for term in supportedTerminals {
            if !NSRunningApplication.runningApplications(withBundleIdentifier: term.bundleId).isEmpty {
                running.append(term.name)
            }
        }
        return running
    }

    public func jumpToTerminal(name: String) -> Bool {
        let target = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Match specified app or pick first running terminal
        var candidateBundleId: String? = nil
        for term in supportedTerminals {
            if !target.isEmpty && term.name.lowercased().contains(target) {
                candidateBundleId = term.bundleId
                break
            }
        }

        if candidateBundleId == nil {
            for term in supportedTerminals {
                if !NSRunningApplication.runningApplications(withBundleIdentifier: term.bundleId).isEmpty {
                    candidateBundleId = term.bundleId
                    break
                }
            }
        }

        guard let bundleId = candidateBundleId else {
            // Default fallback: open Terminal.app
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"),
                                              configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
            return true
        }

        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        if let app = apps.first {
            DispatchQueue.main.async {
                app.activate()
            }
            return true
        } else {
            if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                NSWorkspace.shared.openApplication(at: appUrl, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
                return true
            }
        }
        return false
    }

    public func getTerminalsJson() -> String {
        let running = getRunningTerminals()
        let runningList = running.map { "\"\($0)\"" }.joined(separator: ",")
        let preferred = running.first ?? "Terminal"
        return """
        {
          "running": [\(runningList)],
          "preferred": "\(preferred)"
        }
        """
    }
}
