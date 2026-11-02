// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

public typealias CCallActionCallback = @convention(c) (UnsafePointer<CChar>, UnsafePointer<CChar>) -> Void

private var globalActionCallback: CCallActionCallback?

@_cdecl("maclink_calls_init")
public func maclink_calls_init() {
    _ = CallNotifier.shared
}

@_cdecl("maclink_calls_register_action_callback")
public func maclink_calls_register_action_callback(callback: CCallActionCallback?) {
    globalActionCallback = callback
    CallNotifier.shared.onAction = { callId, action in
        callId.withCString { cCallId in
            action.withCString { cAction in
                globalActionCallback?(cCallId, cAction)
            }
        }
    }
}

@_cdecl("maclink_calls_notify_ringing")
public func maclink_calls_notify_ringing(
    callId: UnsafePointer<CChar>?,
    callerName: UnsafePointer<CChar>?,
    callerNumber: UnsafePointer<CChar>?
) {
    guard let callId = callId.flatMap({ String(validatingUTF8: $0) }) else { return }
    let name = callerName.flatMap { String(validatingUTF8: $0) }
    let number = callerNumber.flatMap { String(validatingUTF8: $0) }
    CallNotifier.shared.showRinging(callId: callId, callerName: name, callerNumber: number)
}

@_cdecl("maclink_calls_notify_active")
public func maclink_calls_notify_active(
    callId: UnsafePointer<CChar>?,
    callerName: UnsafePointer<CChar>?,
    callerNumber: UnsafePointer<CChar>?
) {
    guard let callId = callId.flatMap({ String(validatingUTF8: $0) }) else { return }
    let name = callerName.flatMap { String(validatingUTF8: $0) }
    let number = callerNumber.flatMap { String(validatingUTF8: $0) }
    CallNotifier.shared.showActive(callId: callId, callerName: name, callerNumber: number)
}

@_cdecl("maclink_calls_dismiss")
public func maclink_calls_dismiss(callId: UnsafePointer<CChar>?) {
    guard let callId = callId.flatMap({ String(validatingUTF8: $0) }) else { return }
    CallNotifier.shared.dismiss(callId: callId)
}

