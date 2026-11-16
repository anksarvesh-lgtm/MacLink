// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

@_cdecl("maclink_init_poshak_island_services")
public func maclink_init_poshak_island_services() {
    DispatchQueue.main.async {
        IslandDownloadService.shared.start()
        IslandPrivacySensorService.shared.start()
    }
}

@_cdecl("maclink_get_download_tracker_json")
public func maclink_get_download_tracker_json(buffer: UnsafeMutablePointer<CChar>, maxLen: Int) -> Int {
    let json = IslandDownloadService.shared.getDownloadsJson()
    guard let cStr = json.cString(using: .utf8) else { return 0 }
    let len = min(cStr.count - 1, maxLen - 1)
    if len > 0 {
        buffer.initialize(from: cStr, count: len)
        buffer[len] = 0
    }
    return len
}

@_cdecl("maclink_cancel_download")
public func maclink_cancel_download(downloadId: UnsafePointer<CChar>) {
    let id = String(cString: downloadId)
    DispatchQueue.main.async {
        IslandDownloadService.shared.cancel(id: id)
    }
}

@_cdecl("maclink_reveal_download")
public func maclink_reveal_download(downloadId: UnsafePointer<CChar>) {
    let id = String(cString: downloadId)
    DispatchQueue.main.async {
        IslandDownloadService.shared.revealInFinder(id: id)
    }
}

@_cdecl("maclink_simulate_download")
public func maclink_simulate_download() {
    DispatchQueue.main.async {
        IslandDownloadService.shared.simulateIncomingDownload()
    }
}

@_cdecl("maclink_get_privacy_sensors_json")
public func maclink_get_privacy_sensors_json(buffer: UnsafeMutablePointer<CChar>, maxLen: Int) -> Int {
    let json = IslandPrivacySensorService.shared.getSensorsJson()
    guard let cStr = json.cString(using: .utf8) else { return 0 }
    let len = min(cStr.count - 1, maxLen - 1)
    if len > 0 {
        buffer.initialize(from: cStr, count: len)
        buffer[len] = 0
    }
    return len
}

@_cdecl("maclink_simulate_privacy_mic_toggle")
public func maclink_simulate_privacy_mic_toggle() {
    DispatchQueue.main.async {
        IslandPrivacySensorService.shared.toggleSimulatedMic()
    }
}

@_cdecl("maclink_simulate_privacy_camera_toggle")
public func maclink_simulate_privacy_camera_toggle() {
    DispatchQueue.main.async {
        IslandPrivacySensorService.shared.toggleSimulatedCamera()
    }
}
