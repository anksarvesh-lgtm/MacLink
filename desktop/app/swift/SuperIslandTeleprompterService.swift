import Foundation
import AppKit

@objc public final class SuperIslandTeleprompterService: NSObject, @unchecked Sendable {
    public static let shared = SuperIslandTeleprompterService()

    private let lock = NSLock()
    private var scriptText: String = "Welcome to MacLink Island Teleprompter.\nPositioned directly below your MacBook camera, you can deliver presentations and pitches while looking straight into the lens."
    private var isPlaying: Bool = false
    private var countdownValue: Int = 0 // 0 = not counting down, 3, 2, 1
    private var scrollProgress: Double = 0.0 // 0.0 to 1.0
    private var scrollSpeed: Double = 25.0 // points per second
    private var fontSize: Double = 18.0
    private var active: Bool = false

    private var countdownTimer: Timer?
    private var scrollTimer: Timer?

    private override init() {
        super.init()
    }

    public func start() {
        // Ready
    }

    public func toggleTeleprompter() {
        lock.lock()
        defer { lock.unlock() }

        if active && isPlaying {
            pauseInternal()
        } else if active && !isPlaying {
            startCountdownInternal()
        } else {
            active = true
            startCountdownInternal()
        }
    }

    public func resetTeleprompter() {
        lock.lock()
        defer { lock.unlock() }
        pauseInternal()
        scrollProgress = 0.0
        countdownValue = 0
    }

    public func dismiss() {
        lock.lock()
        defer { lock.unlock() }
        pauseInternal()
        active = false
    }

    public func setScript(_ text: String) {
        lock.lock()
        defer { lock.unlock() }
        scriptText = text
        scrollProgress = 0.0
    }

    public func setSpeed(_ speed: Double) {
        lock.lock()
        defer { lock.unlock() }
        scrollSpeed = max(5.0, min(100.0, speed))
    }

    private func startCountdownInternal() {
        countdownTimer?.invalidate()
        scrollTimer?.invalidate()
        countdownValue = 3
        isPlaying = false

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
                guard let self = self else { return }
                self.lock.lock()
                if self.countdownValue > 1 {
                    self.countdownValue -= 1
                    self.lock.unlock()
                } else {
                    self.countdownValue = 0
                    t.invalidate()
                    self.countdownTimer = nil
                    self.startScrollInternal()
                    self.lock.unlock()
                }
            }
        }
    }

    private func startScrollInternal() {
        isPlaying = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.scrollTimer?.invalidate()
            self.scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] t in
                guard let self = self else { return }
                self.lock.lock()
                defer { self.lock.unlock() }
                if !self.isPlaying {
                    t.invalidate()
                    return
                }
                // Advance progress
                let delta = 0.05 * (self.scrollSpeed / 500.0)
                self.scrollProgress += delta
                if self.scrollProgress >= 1.0 {
                    self.scrollProgress = 1.0
                    self.isPlaying = false
                    t.invalidate()
                }
            }
        }
    }

    private func pauseInternal() {
        isPlaying = false
        countdownValue = 0
        countdownTimer?.invalidate()
        countdownTimer = nil
        scrollTimer?.invalidate()
        scrollTimer = nil
    }

    public func getTeleprompterJson() -> String {
        lock.lock()
        defer { lock.unlock() }

        func sanitize(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\")
             .replacingOccurrences(of: "\"", with: "\\\"")
             .replacingOccurrences(of: "\n", with: "\\n")
             .replacingOccurrences(of: "\r", with: "")
        }

        let cleanScript = sanitize(scriptText)
        return """
        {
          "active": \(active),
          "isPlaying": \(isPlaying),
          "isCountingDown": \(countdownValue > 0),
          "countdown": \(countdownValue),
          "progress": \(scrollProgress),
          "speed": \(scrollSpeed),
          "fontSize": \(fontSize),
          "script": "\(cleanScript)"
        }
        """
    }
}
