// SPDX-License-Identifier: GPL-3.0-or-later
// QuickShareBridge.swift - C-ABI bindings for QuickShareService

import Foundation

@_cdecl("maclink_get_quickshare_state_json")
public func maclink_get_quickshare_state_json(buffer: UnsafeMutablePointer<CChar>, maxLen: Int) -> Int {
    let json: String
    if Thread.isMainThread {
        json = MainActor.assumeIsolated {
            QuickShareService.shared.getStateJSON()
        }
    } else {
        json = DispatchQueue.main.sync {
            QuickShareService.shared.getStateJSON()
        }
    }
    let count = json.utf8.count
    if count < maxLen {
        json.withCString { ptr in
            buffer.initialize(from: ptr, count: count + 1)
        }
        return count
    }
    return 0
}

@_cdecl("maclink_set_quickshare_enabled")
public func maclink_set_quickshare_enabled(enabled: Bool) {
    DispatchQueue.main.async {
        QuickShareService.shared.setEnabled(enabled)
    }
}

@_cdecl("maclink_set_quickshare_visibility")
public func maclink_set_quickshare_visibility(mode: UnsafePointer<CChar>?) {
    guard let mode = mode, let str = String(validatingUTF8: mode) else { return }
    let vis = QuickShareVisibility(rawValue: str) ?? .everyone
    DispatchQueue.main.async {
        QuickShareService.shared.setVisibility(vis)
    }
}

@_cdecl("maclink_respond_quickshare_request")
public func maclink_respond_quickshare_request(accept: Bool) {
    DispatchQueue.main.async {
        QuickShareService.shared.respondToRequest(accept: accept)
    }
}

@_cdecl("maclink_cancel_quickshare_transfer")
public func maclink_cancel_quickshare_transfer() {
    DispatchQueue.main.async {
        QuickShareService.shared.cancelTransfer()
    }
}

@_cdecl("maclink_get_quickshare_trusted_devices_json")
public func maclink_get_quickshare_trusted_devices_json(buffer: UnsafeMutablePointer<CChar>, maxLen: Int) -> Int {
    let json: String
    if Thread.isMainThread {
        json = MainActor.assumeIsolated {
            QuickShareService.shared.getTrustedDevicesJSON()
        }
    } else {
        json = DispatchQueue.main.sync {
            QuickShareService.shared.getTrustedDevicesJSON()
        }
    }
    let count = json.utf8.count
    if count < maxLen {
        json.withCString { ptr in
            buffer.initialize(from: ptr, count: count + 1)
        }
        return count
    }
    return 0
}

@_cdecl("maclink_add_quickshare_trusted_device")
public func maclink_add_quickshare_trusted_device(name: UnsafePointer<CChar>?, devType: UnsafePointer<CChar>?) {
    guard let name = name, let nameStr = String(validatingUTF8: name) else { return }
    let typeStr = devType.flatMap { String(validatingUTF8: $0) } ?? "Phone"
    DispatchQueue.main.async {
        QuickShareService.shared.addTrustedDevice(name: nameStr, type: typeStr)
    }
}

@_cdecl("maclink_remove_quickshare_trusted_device")
public func maclink_remove_quickshare_trusted_device(name: UnsafePointer<CChar>?) {
    guard let name = name, let nameStr = String(validatingUTF8: name) else { return }
    DispatchQueue.main.async {
        QuickShareService.shared.removeTrustedDevice(name: nameStr)
    }
}

@_cdecl("maclink_simulate_quickshare_incoming")
public func maclink_simulate_quickshare_incoming() {
    DispatchQueue.main.async {
        let sampleFiles = [
            QuickShareTransferItem(name: "IMG_2026_QuickShare.jpg", size: 4_210_800, mimeType: "image/jpeg"),
            QuickShareTransferItem(name: "Project_Proposal.pdf", size: 12_850_000, mimeType: "application/pdf")
        ]
        QuickShareService.shared.presentIncomingRequest(
            deviceName: "Galaxy S24 Ultra",
            deviceType: "Phone",
            pinCode: "5821",
            files: sampleFiles
        )
    }
}
