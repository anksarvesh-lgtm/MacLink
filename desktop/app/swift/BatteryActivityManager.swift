// SPDX-License-Identifier: GPL-3.0-or-later
//
//  BatteryActivityManager.swift
//  MacLink Native Battery & Power Telemetry Engine
//  Reverse-engineered and adapted from boring.notch (TheBoredTeam/boring.notch)
//

import Foundation
import IOKit.ps

public final class BatteryActivityManager {
    public static let shared = BatteryActivityManager()

    public struct BatteryStatus: Codable {
        public var level: Double
        public var isCharging: Bool
        public var isPluggedIn: Bool
        public var isInLowPowerMode: Bool
        public var timeToFullCharge: Int
        public var newlyConnected: Bool
    }

    public var onBatteryChange: ((BatteryStatus) -> Void)?
    public var onPowerConnected: (() -> Void)?

    private var runLoopSource: CFRunLoopSource?
    private var previousStatus: BatteryStatus?
    private var currentStatus: BatteryStatus

    private init() {
        self.currentStatus = BatteryStatus(
            level: 100.0,
            isCharging: false,
            isPluggedIn: true,
            isInLowPowerMode: false,
            timeToFullCharge: 0,
            newlyConnected: false
        )
        refresh()
        startMonitoring()
    }

    public func getCurrentStatus() -> BatteryStatus {
        refresh()
        return currentStatus
    }

    public func startMonitoring() {
        guard runLoopSource == nil else { return }

        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ info in
            guard let info = info else { return }
            let manager = Unmanaged<BatteryActivityManager>.fromOpaque(info).takeUnretainedValue()
            manager.handlePowerChange()
        }, context)?.takeRetainedValue() {
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePowerChange),
            name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil
        )
    }

    public func stopMonitoring() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = nil
        }
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handlePowerChange() {
        refresh()
    }

    public func refresh() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return }
        guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else { return }

        var foundBattery = false
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            let curCap = desc[kIOPSCurrentCapacityKey] as? Double ?? 100.0
            let maxCap = desc[kIOPSMaxCapacityKey] as? Double ?? 100.0
            let isCharging = desc["Is Charging"] as? Bool ?? false
            let pSource = desc[kIOPSPowerSourceStateKey] as? String ?? ""
            let isPlugged = (pSource == kIOPSACPowerValue)
            let timeToFull = desc[kIOPSTimeToFullChargeKey] as? Int ?? 0
            let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

            let pct = maxCap > 0 ? min(100.0, max(0.0, (curCap / maxCap) * 100.0)) : curCap

            let newlyConnected = (previousStatus?.isPluggedIn == false && isPlugged)

            let newStatus = BatteryStatus(
                level: pct,
                isCharging: isCharging,
                isPluggedIn: isPlugged,
                isInLowPowerMode: lowPower,
                timeToFullCharge: timeToFull,
                newlyConnected: newlyConnected
            )

            currentStatus = newStatus
            foundBattery = true

            if newlyConnected {
                DispatchQueue.main.async {
                    self.onPowerConnected?()
                }
            }

            DispatchQueue.main.async {
                self.onBatteryChange?(newStatus)
            }
            break
        }

        if !foundBattery {
            // Desktop Macs without internal batteries
            currentStatus = BatteryStatus(
                level: 100.0,
                isCharging: false,
                isPluggedIn: true,
                isInLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
                timeToFullCharge: 0,
                newlyConnected: false
            )
        }

        previousStatus = currentStatus
    }

    deinit {
        stopMonitoring()
    }
}
