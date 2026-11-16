//
//  MacWakeBridge.swift
//  MacLink
//
//  C-bridge exports for Jarvis322/MacWake features:
//  Cleaning mode and thermal telemetry monitor.
//

import Foundation

@_cdecl("macwake_get_thermal_telemetry_json")
public func macwake_get_thermal_telemetry_json(
    _ outBuf: UnsafeMutablePointer<CChar>,
    _ maxLen: Int
) -> Int {
    let json = MacWakeThermalMonitorService.shared.getThermalTelemetryJson()
    guard let utf8 = json.data(using: .utf8) else { return 0 }
    let count = min(utf8.count, maxLen - 1)
    utf8.withUnsafeBytes { raw in
        if let base = raw.baseAddress {
            outBuf.initialize(from: base.assumingMemoryBound(to: CChar.self), count: count)
        }
    }
    outBuf[count] = 0
    return count
}

@_cdecl("macwake_start_cleaning_mode")
public func macwake_start_cleaning_mode(seconds: Int32) {
    MacWakeCleaningModeService.shared.start(duration: Int(seconds))
}

@_cdecl("macwake_stop_cleaning_mode")
public func macwake_stop_cleaning_mode() {
    MacWakeCleaningModeService.shared.stop()
}

@_cdecl("macwake_get_cleaning_mode_json")
public func macwake_get_cleaning_mode_json(
    _ outBuf: UnsafeMutablePointer<CChar>,
    _ maxLen: Int
) -> Int {
    let json = MacWakeCleaningModeService.shared.getCleaningStatusJson()
    guard let utf8 = json.data(using: .utf8) else { return 0 }
    let count = min(utf8.count, maxLen - 1)
    utf8.withUnsafeBytes { raw in
        if let base = raw.baseAddress {
            outBuf.initialize(from: base.assumingMemoryBound(to: CChar.self), count: count)
        }
    }
    outBuf[count] = 0
    return count
}

@_cdecl("macwake_simulate_thermal")
public func macwake_simulate_thermal(cpu: Double, gpu: Double) {
    MacWakeThermalMonitorService.shared.simulateThermal(cpu: cpu, gpu: gpu)
}

@_cdecl("macwake_reset_thermal_simulation")
public func macwake_reset_thermal_simulation() {
    MacWakeThermalMonitorService.shared.resetSimulation()
}
