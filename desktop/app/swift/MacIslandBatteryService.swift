//
//  MacIslandBatteryService.swift
//  MacLink
//
//  Reverse-engineered from BadRat-in/MacIsland:
//  Real-time IOKit power source monitoring, live battery percentage,
//  AC adapter / MagSafe connection detection, time-to-full/empty calculation,
//  and notch charging HUD badge state.
//

import Foundation
import AppKit
import IOKit.ps

@objc public final class MacIslandBatteryService: NSObject {
    @objc public static let shared = MacIslandBatteryService()

    private let queue = DispatchQueue(label: "com.maclink.dynamo.battery", qos: .utility)
    private var simulatedPercentage: Int? = nil
    private var simulatedCharging: Bool? = nil
    private var lastChargingState: Bool = false

    private override init() {
        super.init()
        setupNotificationSource()
    }

    private func setupNotificationSource() {
        // Register IOKit power source run loop notification
        if let runLoopSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let ctx = context else { return }
            let service = Unmanaged<MacIslandBatteryService>.fromOpaque(ctx).takeUnretainedValue()
            service.handlePowerChanged()
        }, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        }
    }

    private func handlePowerChanged() {
        queue.async { [weak self] in
            guard let self = self else { return }
            let isCharging = self.checkIsCharging()
            if isCharging != self.lastChargingState {
                self.lastChargingState = isCharging
            }
        }
    }

    private func checkIsCharging() -> Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return false
        }
        for ps in sources {
            if let desc = IOPSGetPowerSourceDescription(snapshot, ps)?.takeUnretainedValue() as? [String: Any] {
                if let state = desc[kIOPSPowerSourceStateKey] as? String {
                    return (state == kIOPSACPowerValue)
                }
            }
        }
        return false
    }

    @objc public func getBatteryStatusJson() -> String {
        if let simPct = simulatedPercentage, let simCharge = simulatedCharging {
            let json: [String: Any] = [
                "hasBattery": true,
                "percentage": simPct,
                "isCharging": simCharge,
                "isACPower": simCharge,
                "timeRemaining": simCharge ? "45m until full" : "5h 20m left",
                "stateDescription": simCharge ? "Charging (Simulated)" : "On Battery (Simulated)",
                "source": "Simulated"
            ]
            if let data = try? JSONSerialization.data(withJSONObject: json, options: []),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
        }

        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else {
            let fallback: [String: Any] = [
                "hasBattery": false,
                "percentage": 100,
                "isCharging": false,
                "isACPower": true,
                "timeRemaining": "AC Connected",
                "stateDescription": "Desktop / AC Connected",
                "source": "Desktop"
            ]
            if let data = try? JSONSerialization.data(withJSONObject: fallback, options: []),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
            return "{}"
        }

        var percentage: Int = 100
        var isCharging: Bool = false
        var isAC: Bool = true
        var timeRemainingStr: String = ""

        for ps in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, ps)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            if let cap = desc[kIOPSCurrentCapacityKey] as? Int,
               let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0 {
                percentage = Int((Double(cap) / Double(max)) * 100.0)
            }

            if let state = desc[kIOPSPowerSourceStateKey] as? String {
                isAC = (state == kIOPSACPowerValue)
                isCharging = isAC
            }

            if let isChargingKey = desc[kIOPSIsChargingKey] as? Bool {
                isCharging = isChargingKey
            }

            if isCharging {
                if let time = desc[kIOPSTimeToFullChargeKey] as? Int, time > 0 {
                    let hrs = time / 60
                    let mins = time % 60
                    timeRemainingStr = hrs > 0 ? "\(hrs)h \(mins)m until full" : "\(mins)m until full"
                } else if percentage >= 100 {
                    timeRemainingStr = "Fully Charged"
                } else {
                    timeRemainingStr = "Charging"
                }
            } else {
                if let time = desc[kIOPSTimeToEmptyKey] as? Int, time > 0 {
                    let hrs = time / 60
                    let mins = time % 60
                    timeRemainingStr = hrs > 0 ? "\(hrs)h \(mins)m left" : "\(mins)m left"
                } else {
                    timeRemainingStr = "Calculating..."
                }
            }
        }

        let result: [String: Any] = [
            "hasBattery": true,
            "percentage": percentage,
            "isCharging": isCharging,
            "isACPower": isAC,
            "timeRemaining": timeRemainingStr,
            "stateDescription": isCharging ? "Charging" : (isAC ? "Power Adapter (Not Charging)" : "On Battery"),
            "source": "IOKit"
        ]

        if let data = try? JSONSerialization.data(withJSONObject: result, options: []),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }

    @objc public func simulateBattery(percentage: Int, isCharging: Bool) {
        self.simulatedPercentage = percentage
        self.simulatedCharging = isCharging
    }

    @objc public func resetSimulation() {
        self.simulatedPercentage = nil
        self.simulatedCharging = nil
    }
}
