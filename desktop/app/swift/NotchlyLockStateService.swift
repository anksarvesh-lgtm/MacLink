import Foundation
import AppKit

@objc public final class NotchlyLockStateService: NSObject, @unchecked Sendable {
    public static let shared = NotchlyLockStateService()

    private let lock = NSLock()
    private var isScreenLocked: Bool = false
    private var isStarted: Bool = false

    private override init() {
        super.init()
    }

    public func start() {
        lock.lock()
        defer { lock.unlock() }
        if isStarted { return }
        isStarted = true

        let center = DistributedNotificationCenter.default()
        center.addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.lock.lock()
            self.isScreenLocked = true
            self.lock.unlock()
        }

        center.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.lock.lock()
            self.isScreenLocked = false
            self.lock.unlock()
        }
    }

    public func getIsScreenLocked() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return isScreenLocked
    }
}
