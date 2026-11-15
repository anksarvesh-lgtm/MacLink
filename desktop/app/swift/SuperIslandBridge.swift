import Foundation

@_cdecl("maclink_init_superisland_services")
public func maclink_init_superisland_services() {
    SuperIslandTeleprompterService.shared.start()
}

@_cdecl("maclink_get_teleprompter_json")
public func maclink_get_teleprompter_json(
    _ outBuf: UnsafeMutablePointer<CChar>,
    _ maxLen: Int
) -> Int {
    let json = SuperIslandTeleprompterService.shared.getTeleprompterJson()
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

@_cdecl("maclink_teleprompter_toggle")
public func maclink_teleprompter_toggle() {
    SuperIslandTeleprompterService.shared.toggleTeleprompter()
}

@_cdecl("maclink_teleprompter_reset")
public func maclink_teleprompter_reset() {
    SuperIslandTeleprompterService.shared.resetTeleprompter()
}

@_cdecl("maclink_teleprompter_dismiss")
public func maclink_teleprompter_dismiss() {
    SuperIslandTeleprompterService.shared.dismiss()
}

@_cdecl("maclink_teleprompter_set_script")
public func maclink_teleprompter_set_script(_ scriptPtr: UnsafePointer<CChar>?) {
    guard let scriptPtr = scriptPtr else { return }
    let script = String(cString: scriptPtr)
    SuperIslandTeleprompterService.shared.setScript(script)
}

@_cdecl("maclink_teleprompter_set_speed")
public func maclink_teleprompter_set_speed(_ speed: Double) {
    SuperIslandTeleprompterService.shared.setSpeed(speed)
}

@_cdecl("maclink_search_emojis_json")
public func maclink_search_emojis_json(
    _ queryPtr: UnsafePointer<CChar>?,
    _ outBuf: UnsafeMutablePointer<CChar>,
    _ maxLen: Int
) -> Int {
    let query = queryPtr != nil ? String(cString: queryPtr!) : ""
    let json = SuperIslandEmojiService.shared.searchJson(query: query)
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

@_cdecl("maclink_copy_emoji")
public func maclink_copy_emoji(_ emojiPtr: UnsafePointer<CChar>?) {
    guard let emojiPtr = emojiPtr else { return }
    let emoji = String(cString: emojiPtr)
    SuperIslandEmojiService.shared.copyEmojiToClipboard(emoji)
}

@_cdecl("maclink_get_ai_usage_json")
public func maclink_get_ai_usage_json(
    _ outBuf: UnsafeMutablePointer<CChar>,
    _ maxLen: Int
) -> Int {
    let json = SuperIslandAIUsageService.shared.getAIUsageJson()
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

@_cdecl("maclink_simulate_ai_usage_refresh")
public func maclink_simulate_ai_usage_refresh() {
    SuperIslandAIUsageService.shared.simulateRefresh()
}
