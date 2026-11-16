// SPDX-License-Identifier: GPL-3.0-or-later
//
//  MochiEngine.swift
//  MacLink Native Mochi Animated Notch Companion Engine
//  Reverse-engineered and adapted from coucou (Louis-CFM/coucou)
//

import Cocoa
import Foundation
import QuartzCore

public final class MochiEngine {
    public static let shared = MochiEngine()

    public enum Mood: String, Codable {
        case idle = "idle"
        case working = "working"
        case thinking = "thinking"
        case searching = "searching"
        case happy = "happy"
        case dizzy = "dizzy"
        case asleep = "asleep"
        case approval = "approval"
    }

    public struct MochiState: Codable {
        public var yaw: Double         // -1.0 to 1.0 (looking left/right)
        public var pitch: Double       // -1.0 to 1.0 (looking up/down)
        public var blink: Double       // 0.0 (wide open) to 1.0 (fully closed)
        public var breathScaleY: Double // 0.98 to 1.02 sinusoidal breathing
        public var breathScaleX: Double
        public var mood: String
        public var colorHex: String
        public var eyeShape: String    // "pill", "happy", "spiral", "closed"
        public var pokeCount: Int
    }

    private var currentMood: Mood = .idle
    private var yaw: Double = 0.0
    private var pitch: Double = 0.0
    private var targetYaw: Double = 0.0
    private var targetPitch: Double = 0.0

    private var blinkProgress: Double = 0.0
    private var isBlinking: Bool = false
    private var nextBlinkTime: Double = 0.0

    private var pokeCount: Int = 0
    private var dizzyExpiryTime: Double = 0.0
    private var happyExpiryTime: Double = 0.0

    private var timer: Timer?

    private init() {
        nextBlinkTime = CACurrentMediaTime() + Double.random(in: 2.5...5.0)
        startLoop()
    }

    public func startLoop() {
        stopLoop()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    public func stopLoop() {
        timer?.invalidate()
        timer = nil
    }

    public func lookAt(screenPoint: CGPoint, notchCenter: CGPoint) {
        let dx = (screenPoint.x - notchCenter.x) / 450.0
        let dy = (screenPoint.y - notchCenter.y) / 350.0
        targetYaw = Double(max(-1.0, min(1.0, dx)))
        targetPitch = Double(max(-1.0, min(1.0, dy)))
    }

    public func poke() {
        pokeCount += 1
        let now = CACurrentMediaTime()
        if pokeCount >= 3 {
            currentMood = .dizzy
            dizzyExpiryTime = now + 4.5
        } else {
            currentMood = .happy
            happyExpiryTime = now + 2.0
        }
    }

    public func setMood(_ newMood: Mood) {
        currentMood = newMood
    }

    private func tick() {
        let now = CACurrentMediaTime()

        // Expire dizzy or happy
        if currentMood == .dizzy && now > dizzyExpiryTime {
            currentMood = .idle
            pokeCount = 0
        } else if currentMood == .happy && now > happyExpiryTime {
            currentMood = .idle
        }

        // Auto cursor look if no external input
        if currentMood == .idle || currentMood == .happy {
            let mouse = NSEvent.mouseLocation
            let mainScreen = NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main
            let screenW = mainScreen?.frame.width ?? 1440.0
            let screenH = mainScreen?.frame.height ?? 900.0
            let notchCenter = CGPoint(x: screenW / 2.0, y: screenH - 16.0)
            lookAt(screenPoint: mouse, notchCenter: notchCenter)
        } else if currentMood == .thinking {
            targetYaw = 0.55
            targetPitch = 0.55
        } else if currentMood == .searching {
            targetYaw = sin(now * 3.5) * 0.75
            targetPitch = 0.1
        } else {
            targetYaw = 0.0
            targetPitch = 0.0
        }

        // Smooth gaze spring
        yaw += (targetYaw - yaw) * 0.22
        pitch += (targetPitch - pitch) * 0.22

        // Blinking
        if now >= nextBlinkTime && !isBlinking {
            isBlinking = true
            blinkProgress = 0.0
        }

        if isBlinking {
            blinkProgress += 0.25
            if blinkProgress >= 1.0 {
                isBlinking = false
                blinkProgress = 0.0
                nextBlinkTime = now + Double.random(in: 2.5...6.0)
            }
        }
    }

    public func getCurrentState() -> MochiState {
        let now = CACurrentMediaTime()
        let breath = sin(now * 2.4) * 0.025
        let breathSx = 1.0 - breath * 0.5
        let breathSy = 1.0 + breath

        var colorHex = "#EDEDEF"
        var eyeShape = "pill"

        switch currentMood {
        case .idle:
            colorHex = "#EDEDEF"
            eyeShape = "pill"
        case .working:
            colorHex = "#3B9EFF"
            eyeShape = "pill"
        case .thinking:
            colorHex = "#8B5CF6"
            eyeShape = "pill"
        case .searching:
            colorHex = "#6366F1"
            eyeShape = "pill"
        case .happy:
            colorHex = "#10B981"
            eyeShape = "happy"
        case .dizzy:
            colorHex = "#F59E0B"
            eyeShape = "spiral"
        case .asleep:
            colorHex = "#64748B"
            eyeShape = "closed"
        case .approval:
            colorHex = "#F97316"
            eyeShape = "pill"
        }

        return MochiState(
            yaw: yaw,
            pitch: pitch,
            blink: (currentMood == .asleep) ? 1.0 : blinkProgress,
            breathScaleY: breathSy,
            breathScaleX: breathSx,
            mood: currentMood.rawValue,
            colorHex: colorHex,
            eyeShape: eyeShape,
            pokeCount: pokeCount
        )
    }
}
