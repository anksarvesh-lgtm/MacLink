import Foundation

@_cdecl("maclink_init_another_notch_services")
public func maclink_init_another_notch_services() {
    AnotherNotchClipboardService.shared.start()
    AnotherNotchFanService.shared.start()
}

@_cdecl("maclink_get_clipboard_history_json")
public func maclink_get_clipboard_history_json(
    _ queryPtr: UnsafePointer<CChar>?,
    _ outBuf: UnsafeMutablePointer<CChar>,
    _ maxLen: Int
) -> Int {
    let query = queryPtr != nil ? String(cString: queryPtr!) : ""
    let json = AnotherNotchClipboardService.shared.getHistoryJson(query: query)
    guard let utf8 = json.data(using: .utf8) else { return 0 }
    if utf8.count >= maxLen {
        let fallback = "[]".data(using: .utf8)!
        let count = min(fallback.count, maxLen - 1)
        fallback.withUnsafeBytes { raw in
            if let base = raw.baseAddress {
                outBuf.initialize(from: base.assumingMemoryBound(to: CChar.self), count: count)
            }
        }
        outBuf[count] = 0
        return count
    }
    let count = min(utf8.count, maxLen - 1)
    utf8.withUnsafeBytes { raw in
        if let base = raw.baseAddress {
            outBuf.initialize(from: base.assumingMemoryBound(to: CChar.self), count: count)
        }
    }
    outBuf[count] = 0
    return count
}

@_cdecl("maclink_copy_clipboard_entry")
public func maclink_copy_clipboard_entry(_ idPtr: UnsafePointer<CChar>?) -> Bool {
    guard let idPtr = idPtr else { return false }
    let id = String(cString: idPtr)
    return AnotherNotchClipboardService.shared.copyEntry(id: id)
}

@_cdecl("maclink_clear_clipboard_history")
public func maclink_clear_clipboard_history() {
    AnotherNotchClipboardService.shared.clearHistory()
}

@_cdecl("maclink_add_clipboard_entry")
public func maclink_add_clipboard_entry(_ textPtr: UnsafePointer<CChar>?) {
    guard let textPtr = textPtr else { return }
    let text = String(cString: textPtr)
    AnotherNotchClipboardService.shared.addEntry(text: text)
}

@_cdecl("maclink_get_fan_telemetry_json")
public func maclink_get_fan_telemetry_json(
    _ outBuf: UnsafeMutablePointer<CChar>,
    _ maxLen: Int
) -> Int {
    let json = AnotherNotchFanService.shared.getFanTelemetryJson()
    guard let utf8 = json.data(using: .utf8) else { return 0 }
    if utf8.count >= maxLen {
        let fallback = "[]".data(using: .utf8)!
        let count = min(fallback.count, maxLen - 1)
        fallback.withUnsafeBytes { raw in
            if let base = raw.baseAddress {
                outBuf.initialize(from: base.assumingMemoryBound(to: CChar.self), count: count)
            }
        }
        outBuf[count] = 0
        return count
    }
    let count = min(utf8.count, maxLen - 1)
    utf8.withUnsafeBytes { raw in
        if let base = raw.baseAddress {
            outBuf.initialize(from: base.assumingMemoryBound(to: CChar.self), count: count)
        }
    }
    outBuf[count] = 0
    return count
}

@_cdecl("maclink_set_fan_mode")
public func maclink_set_fan_mode(_ modePtr: UnsafePointer<CChar>?) {
    guard let modePtr = modePtr else { return }
    let mode = String(cString: modePtr)
    AnotherNotchFanService.shared.setFanMode(mode)
}

@_cdecl("maclink_simulate_fan_rpm")
public func maclink_simulate_fan_rpm(_ left: Double, _ right: Double) {
    AnotherNotchFanService.shared.simulateFanRPM(left: left, right: right)
}
