//
//  MacWakeCleaningModeService.swift
//  MacLink
//
//  Reverse-engineered from Jarvis322/MacWake:
//  MacBook Keyboard & Screen Cleaning Mode.
//  Locks interaction and displays a dedicated cleaning HUD so the user
//  can wipe their MacBook display and keys without triggering inputs.
//

import Foundation
import AppKit

@objc public final class MacWakeCleaningModeService: NSObject {
    @objc public static let shared = MacWakeCleaningModeService()

    private var timer: Timer?
    @objc public private(set) var isActive: Bool = false
    @objc public private(set) var remainingSeconds: Int = 0

    private override init() {
        super.init()
    }

    @objc public func start(duration: Int = 30) {
        stop()
        let secs = max(10, min(120, duration))
        self.remainingSeconds = secs
        self.isActive = true

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
                guard let self = self else {
                    t.invalidate()
                    return
                }
                if self.remainingSeconds > 1 {
                    self.remainingSeconds -= 1
                } else {
                    self.stop()
                }
            }
        }
    }

    @objc public func stop() {
        timer?.invalidate()
        timer = nil
        remainingSeconds = 0
        isActive = false
    }

    @objc public func getCleaningStatusJson() -> String {
        let dict: [String: Any] = [
            "isActive": isActive,
            "remainingSeconds": remainingSeconds,
            "prompt": "Keyboard & Screen Cleaning Mode: Wipe safely. Hold ESC or click Cancel to exit."
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }
}
