// SPDX-License-Identifier: GPL-3.0-or-later
//
//  NotchDetector.swift
//  MacLink Native Display & Hardware Notch Auto-Detection Engine
//

import AppKit
import Foundation
import MachO

private var prevCpuLoad: host_cpu_load_info? = nil

/// Detects physical MacBook camera notch geometry, display dimensions, and auxiliary safe margins
/// delegating directly to the pure NotchGeometry service.
@_cdecl("maclink_detect_notch")
public func maclink_detect_notch(
    hasNotch: UnsafeMutablePointer<Bool>,
    notchWidth: UnsafeMutablePointer<Double>,
    notchHeight: UnsafeMutablePointer<Double>,
    screenWidth: UnsafeMutablePointer<Double>,
    screenHeight: UnsafeMutablePointer<Double>,
    notchMinX: UnsafeMutablePointer<Double>,
    notchMaxX: UnsafeMutablePointer<Double>,
    auxLeftWidth: UnsafeMutablePointer<Double>,
    auxRightWidth: UnsafeMutablePointer<Double>
) {
    let geom = detectCurrentScreenGeometry()
    hasNotch.pointee = geom.hasNotch
    notchWidth.pointee = Double(geom.notchWidth)
    notchHeight.pointee = Double(geom.notchHeight)
    screenWidth.pointee = Double(geom.screenFrame.width)
    screenHeight.pointee = Double(geom.screenFrame.height)
    notchMinX.pointee = Double(geom.notchRect.minX)
    notchMaxX.pointee = Double(geom.notchRect.maxX)
    auxLeftWidth.pointee = Double(geom.leftAvailable)
    auxRightWidth.pointee = Double(geom.rightAvailable)
}

/// Serializes complete detected NotchGeometry value type into JSON for Rust and QML consumers.
@_cdecl("maclink_get_notch_geometry_json")
public func maclink_get_notch_geometry_json(buffer: UnsafeMutablePointer<CChar>, maxLen: Int) -> Int {
    let geom = detectCurrentScreenGeometry()
    let encoder = JSONEncoder()
    guard let data = try? encoder.encode(geom), let str = String(data: data, encoding: .utf8) else {
        return 0
    }
    let count = str.utf8.count
    if count < maxLen {
        str.withCString { ptr in
            buffer.initialize(from: ptr, count: count + 1)
        }
        return count
    }
    return 0
}

/// Retrieves actual hardware CPU load and RAM utilization metrics from the macOS Mach kernel.
@_cdecl("maclink_get_system_telemetry")
public func maclink_get_system_telemetry(
    cpuPercent: UnsafeMutablePointer<Double>,
    ramPercent: UnsafeMutablePointer<Double>
) {
    // 1. RAM Utilization via Mach host_statistics64
    var stats = vm_statistics64()
    var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
    let kerr = withUnsafeMutablePointer(to: &stats) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
        }
    }
    if kerr == KERN_SUCCESS {
        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let total = ProcessInfo.processInfo.physicalMemory
        let used = active + wired + compressed
        ramPercent.pointee = min(100.0, max(0.0, Double(used) / Double(total) * 100.0))
    } else {
        ramPercent.pointee = 50.0
    }

    // 2. CPU Load via Tick Differential
    var load = host_cpu_load_info()
    var cpuCount = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
    let cpuKerr = withUnsafeMutablePointer(to: &load) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(cpuCount)) {
            host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &cpuCount)
        }
    }
    if cpuKerr == KERN_SUCCESS {
        if let prev = prevCpuLoad {
            let uDiff = Double(load.cpu_ticks.0 >= prev.cpu_ticks.0 ? load.cpu_ticks.0 - prev.cpu_ticks.0 : 0)
            let sDiff = Double(load.cpu_ticks.1 >= prev.cpu_ticks.1 ? load.cpu_ticks.1 - prev.cpu_ticks.1 : 0)
            let iDiff = Double(load.cpu_ticks.2 >= prev.cpu_ticks.2 ? load.cpu_ticks.2 - prev.cpu_ticks.2 : 0)
            let nDiff = Double(load.cpu_ticks.3 >= prev.cpu_ticks.3 ? load.cpu_ticks.3 - prev.cpu_ticks.3 : 0)
            let total = uDiff + sDiff + iDiff + nDiff
            prevCpuLoad = load
            if total > 0 {
                cpuPercent.pointee = min(100.0, max(0.0, (uDiff + sDiff + nDiff) / total * 100.0))
            } else {
                cpuPercent.pointee = 15.0
            }
        } else {
            prevCpuLoad = load
            let u = Double(load.cpu_ticks.0)
            let s = Double(load.cpu_ticks.1)
            let i = Double(load.cpu_ticks.2)
            let n = Double(load.cpu_ticks.3)
            let total = u + s + i + n
            cpuPercent.pointee = total > 0 ? min(100.0, max(0.0, (u + s + n) / total * 100.0)) : 15.0
        }
    } else {
        cpuPercent.pointee = 15.0
    }
}
