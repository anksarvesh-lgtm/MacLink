import Foundation
import Combine

@objc public final class TopNotchFocusService: NSObject {
    @objc public static let shared = TopNotchFocusService()

    private var workDuration: TimeInterval = 25 * 60
    private var shortBreakDuration: TimeInterval = 5 * 60
    private var longBreakDuration: TimeInterval = 15 * 60

    private var phase: String = "work" // "work", "shortBreak", "longBreak"
    private var state: String = "idle" // "idle", "running", "paused"
    private var remainingSeconds: TimeInterval = 25 * 60
    private var totalRoundsToday: Int = 0
    private var currentCycle: Int = 1
    private var targetDeadline: Date?
    private var timer: Timer?

    private struct QuickNote: Codable {
        var id: String
        var title: String
        var text: String
        var wordCount: Int
        var charCount: Int
        var updatedAt: String
    }
    private var notes: [QuickNote] = []

    private override init() {
        super.init()
        notes = [
            QuickNote(id: "1", title: "MacLink Polish", text: "- TopNotch Pomodoro HUD\n- Dynamic Island Quick Notes\n- Verified REA integration", wordCount: 11, charCount: 75, updatedAt: "Just now"),
            QuickNote(id: "2", title: "Ideas", text: "Persistent Pomodoro ring directly on the notch bezel.", wordCount: 8, charCount: 54, updatedAt: "10m ago")
        ]
    }

    @objc public func startFocus(minutes: Int32 = 25) {
        if minutes > 0 {
            workDuration = TimeInterval(minutes * 60)
        }
        phase = "work"
        state = "running"
        remainingSeconds = workDuration
        targetDeadline = Date().addingTimeInterval(remainingSeconds)
        startTimer()
    }

    @objc public func pauseFocus() {
        guard state == "running" else { return }
        state = "paused"
        if let deadline = targetDeadline {
            remainingSeconds = max(0, deadline.timeIntervalSince(Date()))
        }
        stopTimer()
    }

    @objc public func resumeFocus() {
        guard state == "paused" else { return }
        state = "running"
        targetDeadline = Date().addingTimeInterval(remainingSeconds)
        startTimer()
    }

    @objc public func skipFocus() {
        advancePhase()
    }

    @objc public func resetFocus() {
        stopTimer()
        state = "idle"
        phase = "work"
        remainingSeconds = workDuration
        targetDeadline = nil
    }

    private func advancePhase() {
        stopTimer()
        if phase == "work" {
            totalRoundsToday += 1
            if currentCycle >= 4 {
                phase = "longBreak"
                remainingSeconds = longBreakDuration
                currentCycle = 1
            } else {
                phase = "shortBreak"
                remainingSeconds = shortBreakDuration
                currentCycle += 1
            }
        } else {
            phase = "work"
            remainingSeconds = workDuration
        }
        state = "idle"
        targetDeadline = nil
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if let deadline = self.targetDeadline {
                let rem = deadline.timeIntervalSince(Date())
                if rem <= 0 {
                    self.advancePhase()
                } else {
                    self.remainingSeconds = rem
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    @objc public func saveNote(title: String, text: String) {
        let words = text.split { $0.isWhitespace || $0.isNewline }.count
        let chars = text.count
        let note = QuickNote(id: UUID().uuidString, title: title.isEmpty ? "Quick Note" : title, text: text, wordCount: words, charCount: chars, updatedAt: "Just now")
        notes.insert(note, at: 0)
    }

    @objc public func deleteNote(index: Int32) {
        let idx = Int(index)
        if idx >= 0 && idx < notes.count {
            notes.remove(at: idx)
        }
    }

    @objc public func getFocusJson() -> String {
        let duration = phase == "work" ? workDuration : (phase == "shortBreak" ? shortBreakDuration : longBreakDuration)
        let progress = duration > 0 ? max(0.0, min(1.0, (duration - remainingSeconds) / duration)) : 0.0
        let minutes = Int(remainingSeconds) / 60
        let seconds = Int(remainingSeconds) % 60
        let formattedTime = String(format: "%02d:%02d", minutes, seconds)

        let notesDict = notes.map { n in
            [
                "id": n.id,
                "title": n.title,
                "text": n.text,
                "wordCount": n.wordCount,
                "charCount": n.charCount,
                "updatedAt": n.updatedAt
            ]
        }

        let dict: [String: Any] = [
            "phase": phase,
            "phaseLabel": phase == "work" ? "Focus" : (phase == "shortBreak" ? "Short Break" : "Long Break"),
            "state": state,
            "isRunning": state == "running",
            "isPaused": state == "paused",
            "remainingSeconds": Int(remainingSeconds),
            "formattedTime": formattedTime,
            "progress": progress,
            "totalRoundsToday": totalRoundsToday,
            "currentCycle": currentCycle,
            "notes": notesDict,
            "noteCount": notes.count,
            "source": "TopNotchEngine"
        ]

        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }
}
