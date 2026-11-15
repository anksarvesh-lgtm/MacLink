//
//  MacIslandBridge.swift
//  MacLink
//
//  C-bridge exports for BadRat-in/MacIsland features:
//  Battery status telemetry and AirDrop file dispatcher.
//

import Foundation

@_cdecl("macisland_get_battery_status_json")
public func macisland_get_battery_status_json(
    _ outBuf: UnsafeMutablePointer<CChar>,
    _ maxLen: Int
) -> Int {
    let json = MacIslandBatteryService.shared.getBatteryStatusJson()
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

@_cdecl("macisland_trigger_airdrop")
public func macisland_trigger_airdrop(cPath: UnsafePointer<CChar>?) -> Bool {
    let path = cPath != nil ? String(cString: cPath!) : ""
    return MacIslandAirDropService.shared.triggerAirDrop(forPath: path)
}

@_cdecl("macisland_simulate_battery")
public func macisland_simulate_battery(pct: Int32, charging: Bool) {
    MacIslandBatteryService.shared.simulateBattery(percentage: Int(pct), isCharging: charging)
}

@_cdecl("macisland_reset_battery_simulation")
public func macisland_reset_battery_simulation() {
    MacIslandBatteryService.shared.resetSimulation()
}
