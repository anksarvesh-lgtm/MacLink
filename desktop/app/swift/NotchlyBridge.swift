import Foundation

@_cdecl("maclink_init_notchly_services")
public func maclink_init_notchly_services() {
    NotchlyNetworkStatusService.shared.start()
    NotchlyLockStateService.shared.start()
}

@_cdecl("maclink_get_network_status_json")
public func maclink_get_network_status_json(
    _ outBuf: UnsafeMutablePointer<CChar>,
    _ maxLen: Int
) -> Int {
    let json = NotchlyNetworkStatusService.shared.getNetworkStatusJson()
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

@_cdecl("maclink_simulate_network_event")
public func maclink_simulate_network_event(_ eventPtr: UnsafePointer<CChar>?) {
    guard let eventPtr = eventPtr else { return }
    let event = String(cString: eventPtr)
    NotchlyNetworkStatusService.shared.simulateNetworkEvent(event)
}

@_cdecl("maclink_get_lock_state")
public func maclink_get_lock_state() -> Bool {
    return NotchlyLockStateService.shared.getIsScreenLocked()
}
