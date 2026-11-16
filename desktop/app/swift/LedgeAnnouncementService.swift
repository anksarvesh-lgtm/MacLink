// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import Foundation

/// Service reverse-engineered from egemertbalcik/Ledge (NotchAnnouncement.swift)
/// "A thing the notch says out loud, by standing up for a moment."
/// Drops down slightly below the hardware cutout (~52px) for high-priority transient events
/// (e.g. Pomodoro/Coucoudoro session done, break ended, Keep Awake timed out)
/// so peripheral vision notices it without demanding a full intrusive window.
@objc public final class LedgeAnnouncementService: NSObject, @unchecked Sendable {
    @objc public static let shared = LedgeAnnouncementService()

    private let lock = NSLock()
    private var dismissTimer: Timer?

    @objc public private(set) var active = false
    @objc public private(set) var title = ""
    @objc public private(set) var symbolName = "bell.fill"
    @objc public private(set) var accentColorHex = "#38BDF8"
    @objc public private(set) var completedSessions = 0

    private override init() {
        super.init()
    }

    @objc public func postAnnouncement(
        title: String,
        symbolName: String = "bell.fill",
        accentHex: String = "#38BDF8",
        completedSessions: Int = 0,
        duration: TimeInterval = 3.2
    ) {
        lock.lock()
        dismissTimer?.invalidate()
        self.active = true
        self.title = title
        self.symbolName = symbolName
        self.accentColorHex = accentHex
        self.completedSessions = completedSessions
        lock.unlock()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.dismissTimer?.invalidate()
            self.dismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                self?.dismiss()
            }
        }
    }

    @objc public func dismiss() {
        lock.lock()
        dismissTimer?.invalidate()
        dismissTimer = nil
        active = false
        lock.unlock()
    }

    @objc public func getAnnouncementJson() -> String {
        lock.lock()
        defer { lock.unlock() }

        let dict: [String: Any] = [
            "active": active,
            "title": title,
            "symbol": symbolName,
            "accent": accentColorHex,
            "sessions": completedSessions
        ]

        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{\"active\":false,\"title\":\"\",\"symbol\":\"\",\"accent\":\"#38BDF8\",\"sessions\":0}"
    }
}
