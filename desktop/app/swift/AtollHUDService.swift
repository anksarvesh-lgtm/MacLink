// SPDX-License-Identifier: GPL-3.0-or-later
// AtollHUDService.swift - Caps Lock HUD, Focus / Do Not Disturb, and Bluetooth Audio indicators
// Reverse-engineered from Atoll (https://github.com/Ebullioscopic/Atoll)

import Foundation
import AppKit
import IOBluetooth
import Combine

@MainActor
public final class AtollHUDService {
    public static let shared = AtollHUDService()

    // 1. Caps Lock State
    public private(set) var isCapsLockActive: Bool = false
    public private(set) var capsLockToastActive: Bool = false

    // 2. Focus / Do Not Disturb State
    public private(set) var isFocusActive: Bool = false
    public private(set) var focusModeName: String = "Do Not Disturb"
    public private(set) var focusToastActive: Bool = false

    // 3. Bluetooth Audio State
    public private(set) var isBluetoothAudioConnected: Bool = false
    public private(set) var bluetoothDeviceName: String = ""
    public private(set) var bluetoothDeviceType: String = "Headphones"
    public private(set) var bluetoothBatteryPercent: Int = 100
    public private(set) var bluetoothToastActive: Bool = false

    private var localFlagsMonitor: Any?
    private var globalFlagsMonitor: Any?
    private var capsLockDismissTimer: Timer?
    private var focusDismissTimer: Timer?
    private var bluetoothDismissTimer: Timer?

    private init() {
        // Read initial caps lock state
        self.isCapsLockActive = NSEvent.modifierFlags.contains(.capsLock)

        setupCapsLockMonitoring()
        setupFocusMonitoring()
        setupBluetoothMonitoring()
    }

    // MARK: - Caps Lock Monitoring
    private func setupCapsLockMonitoring() {
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }

        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                self?.handleFlagsChanged(event)
            }
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let newState = event.modifierFlags.contains(.capsLock)
        guard newState != isCapsLockActive else { return }

        self.isCapsLockActive = newState
        self.capsLockToastActive = true

        capsLockDismissTimer?.invalidate()
        capsLockDismissTimer = Timer.scheduledTimer(withTimeInterval: 2.2, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.capsLockToastActive = false
            }
        }
    }

    // MARK: - Focus / Do Not Disturb Monitoring
    private func setupFocusMonitoring() {
        let center = DistributedNotificationCenter.default()
        let enabledName = Notification.Name("_NSDoNotDisturbEnabledNotification")
        let disabledName = Notification.Name("_NSDoNotDisturbDisabledNotification")

        center.addObserver(
            forName: enabledName,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleFocusStateChanged(active: true, mode: "Do Not Disturb")
            }
        }

        center.addObserver(
            forName: disabledName,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleFocusStateChanged(active: false, mode: "Do Not Disturb")
            }
        }
    }

    private func handleFocusStateChanged(active: Bool, mode: String) {
        self.isFocusActive = active
        self.focusModeName = mode
        self.focusToastActive = true

        focusDismissTimer?.invalidate()
        focusDismissTimer = Timer.scheduledTimer(withTimeInterval: 2.8, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.focusToastActive = false
            }
        }
    }

    // MARK: - Bluetooth Audio Monitoring
    private func setupBluetoothMonitoring() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("IOBluetoothDeviceNotificationDidConnect"),
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let device = notif.object as? IOBluetoothDevice else { return }
            Task { @MainActor in
                self?.handleBluetoothConnected(device)
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("IOBluetoothDeviceNotificationDidDisconnect"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isBluetoothAudioConnected = false
            }
        }
    }

    private func handleBluetoothConnected(_ device: IOBluetoothDevice) {
        let name = device.nameOrAddress ?? "Headphones"
        let lower = name.lowercased()
        let type: String
        if lower.contains("pro") { type = "AirPods Pro" }
        else if lower.contains("max") { type = "AirPods Max" }
        else if lower.contains("airpod") { type = "AirPods" }
        else if lower.contains("beats") { type = "Beats" }
        else { type = "Headphones" }

        presentBluetoothToast(deviceName: name, type: type, battery: 92)
    }

    public func presentBluetoothToast(deviceName: String, type: String = "AirPods Pro", battery: Int = 95) {
        self.bluetoothDeviceName = deviceName
        self.bluetoothDeviceType = type
        self.bluetoothBatteryPercent = battery
        self.isBluetoothAudioConnected = true
        self.bluetoothToastActive = true

        bluetoothDismissTimer?.invalidate()
        bluetoothDismissTimer = Timer.scheduledTimer(withTimeInterval: 3.2, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.bluetoothToastActive = false
            }
        }
    }

    // MARK: - Simulation Triggers for Quick Testing
    public func simulateCapsLockToggle() {
        isCapsLockActive = !isCapsLockActive
        capsLockToastActive = true
        capsLockDismissTimer?.invalidate()
        capsLockDismissTimer = Timer.scheduledTimer(withTimeInterval: 2.2, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.capsLockToastActive = false
            }
        }
    }

    public func simulateFocusToggle() {
        handleFocusStateChanged(active: !isFocusActive, mode: isFocusActive ? "Do Not Disturb" : "Work Focus")
    }

    public func simulateBluetoothConnect() {
        presentBluetoothToast(deviceName: "AirPods Pro (2nd gen)", type: "AirPods Pro", battery: 98)
    }

    // MARK: - JSON Snapshot
    public func getStateJSON() -> String {
        let escDev = bluetoothDeviceName.replacingOccurrences(of: "\"", with: "\\\"")
        let escFocus = focusModeName.replacingOccurrences(of: "\"", with: "\\\"")

        return """
        {
          "capsLockActive": \(isCapsLockActive),
          "capsLockToastActive": \(capsLockToastActive),
          "focusActive": \(isFocusActive),
          "focusModeName": "\(escFocus)",
          "focusToastActive": \(focusToastActive),
          "bluetoothConnected": \(isBluetoothAudioConnected),
          "bluetoothDeviceName": "\(escDev)",
          "bluetoothDeviceType": "\(bluetoothDeviceType)",
          "bluetoothBattery": \(bluetoothBatteryPercent),
          "bluetoothToastActive": \(bluetoothToastActive)
        }
        """
    }
}
