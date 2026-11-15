import AppKit
import Accessibility
import UserNotifications
import Foundation

@objc public final class QuietNotchNotificationFilterService: NSObject, @unchecked Sendable, UNUserNotificationCenterDelegate {
    public static let shared = QuietNotchNotificationFilterService()

    public struct NotchNotificationItem: Sendable {
        public let id: String
        public let title: String
        public let body: String
        public let appName: String
        public let timestamp: TimeInterval
    }

    public private(set) var activeNotification: NotchNotificationItem?
    public private(set) var isQuietHoursEnabled: Bool = false
    public private(set) var hasNotification: Bool = false

    private var dismissTimer: Timer?
    private let displayDuration: TimeInterval = 4.0
    private var windowPollTimer: Timer?
    private var seenWindowIDs: Set<Int> = []

    private let notifOwnerNames: Set<String> = [
        "NotificationCenter",
        "UserNotificationCenter",
        "Notification Center",
        "notificationcenterui",
        "UserNotifications"
    ]

    private override init() {
        super.init()
    }

    public func start() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }

        windowPollTimer?.invalidate()
        windowPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pollNotificationWindows()
        }
    }

    public func setQuietHours(_ enabled: Bool) {
        self.isQuietHoursEnabled = enabled
        if enabled && hasNotification {
            dismissNotification()
        }
    }

    public func dismissNotification() {
        self.hasNotification = false
        self.activeNotification = nil
        dismissTimer?.invalidate()
        dismissTimer = nil
    }

    public func sendTestNotification(title: String, body: String, appName: String) {
        showNotification(title: title, body: body, appName: appName)
    }

    public func showNotification(title: String, body: String, appName: String) {
        guard !isQuietHoursEnabled else {
            NSLog("QuietNotch: Notification suppressed by Quiet Hours")
            return
        }

        let item = NotchNotificationItem(
            id: UUID().uuidString,
            title: title.isEmpty ? "MacLink Notification" : title,
            body: body,
            appName: appName.isEmpty ? "System" : appName,
            timestamp: Date().timeIntervalSince1970
        )

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.activeNotification = item
            self.hasNotification = true

            self.dismissTimer?.invalidate()
            self.dismissTimer = Timer.scheduledTimer(withTimeInterval: self.displayDuration, repeats: false) { [weak self] _ in
                self?.dismissNotification()
            }
        }
    }

    private func pollNotificationWindows() {
        guard !isQuietHoursEnabled else { return }

        guard let allWindows = CGWindowListCopyWindowInfo(
            CGWindowListOption(rawValue: 0), kCGNullWindowID
        ) as? [[String: Any]] else { return }

        var currentIDs = Set<Int>()

        for window in allWindows {
            guard let ownerName = window[kCGWindowOwnerName as String] as? String,
                  notifOwnerNames.contains(ownerName),
                  let windowID = window[kCGWindowNumber as String] as? Int else { continue }

            currentIDs.insert(windowID)

            if !seenWindowIDs.contains(windowID) {
                seenWindowIDs.insert(windowID)

                if let pidInt = window[kCGWindowOwnerPID as String] as? Int {
                    let pid = pid_t(pidInt)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        self?.inspectAccessibility(for: pid)
                    }
                }
            }
        }

        seenWindowIDs = seenWindowIDs.intersection(currentIDs)
    }

    private func inspectAccessibility(for pid: pid_t) {
        guard AXIsProcessTrusted() else { return }

        let appEl = AXUIElementCreateApplication(pid)
        var windowsObj: AnyObject?
        guard AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &windowsObj) == .success,
              let windows = windowsObj as? [AXUIElement],
              let firstWin = windows.first else { return }

        let texts = collectStaticTexts(from: firstWin)
        if !texts.isEmpty {
            let appName = texts.count >= 3 ? texts[0] : "Notification"
            let title = texts.count >= 2 ? texts[texts.count - 2] : texts[0]
            let body = texts.last ?? ""
            showNotification(title: title, body: body, appName: appName)
        }
    }

    private func collectStaticTexts(from element: AXUIElement, depth: Int = 0) -> [String] {
        guard depth < 6 else { return [] }
        var result: [String] = []

        var valObj: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valObj) == .success,
           let text = valObj as? String,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.append(text)
        }

        var childrenObj: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenObj) == .success,
           let children = childrenObj as? [AXUIElement] {
            for child in children {
                result += collectStaticTexts(from: child, depth: depth + 1)
            }
        }
        return result
    }

    // UNUserNotificationCenterDelegate
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let content = notification.request.content
        showNotification(title: content.title, body: content.body, appName: "Quiet Notch")
        completionHandler([])
    }

    public func getNotificationJson() -> String {
        guard let item = activeNotification, hasNotification else {
            return """
            {"hasNotification":false,"title":"","body":"","appName":"","quietHours":\(isQuietHoursEnabled),"timestamp":0.0}
            """
        }

        let escTitle = item.title.replacingOccurrences(of: "\"", with: "\\\"")
        let escBody = item.body.replacingOccurrences(of: "\"", with: "\\\"")
        let escApp = item.appName.replacingOccurrences(of: "\"", with: "\\\"")

        return """
        {"hasNotification":true,"title":"\(escTitle)","body":"\(escBody)","appName":"\(escApp)","quietHours":\(isQuietHoursEnabled),"timestamp":\(item.timestamp)}
        """
    }
}
