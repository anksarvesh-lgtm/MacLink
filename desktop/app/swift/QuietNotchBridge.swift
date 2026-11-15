import Foundation

@_cdecl("maclink_init_quietnotch_services")
public func maclink_init_quietnotch_services() {
    QuietNotchInlineHUDService.shared.start()
    QuietNotchNotificationFilterService.shared.start()
}

@_cdecl("maclink_get_quietnotch_hud_json")
public func maclink_get_quietnotch_hud_json(
    _ outBuf: UnsafeMutablePointer<CChar>,
    _ maxLen: Int
) -> Int {
    let json = QuietNotchInlineHUDService.shared.getHUDJson()
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

@_cdecl("maclink_get_quietnotch_notification_json")
public func maclink_get_quietnotch_notification_json(
    _ outBuf: UnsafeMutablePointer<CChar>,
    _ maxLen: Int
) -> Int {
    let json = QuietNotchNotificationFilterService.shared.getNotificationJson()
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

@_cdecl("maclink_set_quietnotch_volume")
public func maclink_set_quietnotch_volume(_ volume: Float) {
    QuietNotchInlineHUDService.shared.setVolume(volume)
}

@_cdecl("maclink_set_quietnotch_brightness")
public func maclink_set_quietnotch_brightness(_ brightness: Float) {
    QuietNotchInlineHUDService.shared.setBrightness(brightness)
}

@_cdecl("maclink_simulate_quietnotch_hud")
public func maclink_simulate_quietnotch_hud(_ kindPtr: UnsafePointer<CChar>?, _ value: Float) {
    let kind = kindPtr != nil ? String(cString: kindPtr!) : "volume"
    QuietNotchInlineHUDService.shared.showHUD(kind: kind, value: value, muted: value <= 0)
}

@_cdecl("maclink_send_quietnotch_test_notification")
public func maclink_send_quietnotch_test_notification(
    _ titlePtr: UnsafePointer<CChar>?,
    _ bodyPtr: UnsafePointer<CChar>?,
    _ appPtr: UnsafePointer<CChar>?
) {
    let title = titlePtr != nil ? String(cString: titlePtr!) : "Test Alert"
    let body = bodyPtr != nil ? String(cString: bodyPtr!) : "QuietNotch alert triggered directly on the notch."
    let app = appPtr != nil ? String(cString: appPtr!) : "Quiet Notch"
    QuietNotchNotificationFilterService.shared.sendTestNotification(title: title, body: body, appName: app)
}

@_cdecl("maclink_dismiss_quietnotch_notification")
public func maclink_dismiss_quietnotch_notification() {
    QuietNotchNotificationFilterService.shared.dismissNotification()
}

@_cdecl("maclink_set_quiet_hours_enabled")
public func maclink_set_quiet_hours_enabled(_ enabled: Bool) {
    QuietNotchNotificationFilterService.shared.setQuietHours(enabled)
}
