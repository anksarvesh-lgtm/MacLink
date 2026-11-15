// SPDX-License-Identifier: GPL-3.0-or-later
//
//  CoucoudoroService.swift
//  MacLink Native Pomodoro & Focus Timer Engine
//  Reverse-engineered and adapted from coucou (Louis-CFM/coucou)
//

import Cocoa
import Foundation

public final class CoucoudoroService {
    public static let shared = CoucoudoroService()

    public enum Phase: String, Codable {
        case idle = "idle"
        case work = "work"
        case rest = "rest"
    }

    public struct Snapshot: Codable {
        public var active: Bool
        public var phase: String
        public var remainingSeconds: Int
        public var clockString: String
        public var isPaused: Bool
        public var workMinutes: Int
        public var restMinutes: Int
    }

    private var phase: Phase = .idle
    private var isPaused: Bool = false
    private var remainingSeconds: Int = 25 * 60
    private var workSeconds: Int = 25 * 60
    private var restSeconds: Int = 5 * 60

    private var timer: Timer?

    private init() {}

    public func start() {
        phase = .work
        isPaused = false
        remainingSeconds = workSeconds
        startTimer()
        NSSound(named: "Tink")?.play()
    }

    public func pause() {
        guard phase != .idle else { return }
        isPaused = true
        timer?.invalidate()
        timer = nil
    }

    public func resume() {
        guard phase != .idle, isPaused else { return }
        isPaused = false
        startTimer()
    }

    public func reset() {
        phase = .idle
        isPaused = false
        remainingSeconds = workSeconds
        timer?.invalidate()
        timer = nil
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard phase != .idle, !isPaused else { return }

        if remainingSeconds > 0 {
            remainingSeconds -= 1
        } else {
            // Phase transition
            if phase == .work {
                phase = .rest
                remainingSeconds = restSeconds
                NSSound(named: "Glass")?.play()
            } else {
                phase = .work
                remainingSeconds = workSeconds
                NSSound(named: "Ping")?.play()
            }
        }
    }

    public func getSnapshot() -> Snapshot {
        let mins = remainingSeconds / 60
        let secs = remainingSeconds % 60
        let clock = String(format: "%02d:%02d", mins, secs)

        return Snapshot(
            active: (phase != .idle),
            phase: phase.rawValue,
            remainingSeconds: remainingSeconds,
            clockString: clock,
            isPaused: isPaused,
            workMinutes: workSeconds / 60,
            restMinutes: restSeconds / 60
        )
    }
}
