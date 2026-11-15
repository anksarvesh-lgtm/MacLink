// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

@_cdecl("maclink_init_ledge_services")
public func maclink_init_ledge_services() {
    // Initialized on demand
}

@_cdecl("maclink_get_ledge_announcement_json")
public func maclink_get_ledge_announcement_json(buffer: UnsafeMutablePointer<CChar>, maxLen: Int) -> Int {
    let json = LedgeAnnouncementService.shared.getAnnouncementJson()
    guard let cStr = json.cString(using: .utf8) else { return 0 }
    let len = min(cStr.count - 1, maxLen - 1)
    if len > 0 {
        buffer.initialize(from: cStr, count: len)
        buffer[len] = 0
    }
    return len
}

@_cdecl("maclink_trigger_announcement")
public func maclink_trigger_announcement(
    title: UnsafePointer<CChar>,
    symbol: UnsafePointer<CChar>,
    accent: UnsafePointer<CChar>
) {
    let t = String(cString: title)
    let s = String(cString: symbol)
    let a = String(cString: accent)
    DispatchQueue.main.async {
        LedgeAnnouncementService.shared.postAnnouncement(title: t, symbolName: s, accentHex: a)
    }
}

@_cdecl("maclink_dismiss_announcement")
public func maclink_dismiss_announcement() {
    DispatchQueue.main.async {
        LedgeAnnouncementService.shared.dismiss()
    }
}
