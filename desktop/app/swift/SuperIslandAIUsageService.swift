import Foundation

@objc public final class SuperIslandAIUsageService: NSObject, @unchecked Sendable {
    public static let shared = SuperIslandAIUsageService()

    private let lock = NSLock()
    private var claudePercent: Double = 68.0 // % remaining
    private var codexPercent: Double = 82.0  // % remaining
    private var claudeTokens: String = "42.5k / 100k"
    private var codexTokens: String = "18.2k / 100k"
    private var status: String = "Healthy"

    private override init() {
        super.init()
    }

    public func simulateRefresh() {
        lock.lock()
        defer { lock.unlock() }
        // Jiggle values slightly to demonstrate live activity
        claudePercent = max(15.0, min(95.0, claudePercent + Double.random(in: -5.0...5.0)))
        codexPercent = max(20.0, min(98.0, codexPercent + Double.random(in: -4.0...4.0)))
    }

    public func getAIUsageJson() -> String {
        lock.lock()
        defer { lock.unlock() }

        return """
        {
          "claudePercent": \(String(format: "%.1f", claudePercent)),
          "codexPercent": \(String(format: "%.1f", codexPercent)),
          "claudeTokens": "\(claudeTokens)",
          "codexTokens": "\(codexTokens)",
          "status": "\(status)"
        }
        """
    }
}
