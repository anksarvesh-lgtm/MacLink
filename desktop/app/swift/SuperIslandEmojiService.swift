import Foundation
import AppKit

public struct SuperIslandEmojiItem: Sendable {
    public let emoji: String
    public let name: String
    public let category: String
    public let keywords: [String]
}

@objc public final class SuperIslandEmojiService: NSObject, @unchecked Sendable {
    public static let shared = SuperIslandEmojiService()

    private let lock = NSLock()
    private let emojiCatalog: [SuperIslandEmojiItem] = [
        SuperIslandEmojiItem(emoji: "🚀", name: "Rocket", category: "Tech", keywords: ["space", "launch", "fast", "speed"]),
        SuperIslandEmojiItem(emoji: "🔥", name: "Fire", category: "Trending", keywords: ["lit", "hot", "flame", "burn"]),
        SuperIslandEmojiItem(emoji: "⚡️", name: "Zap", category: "Tech", keywords: ["electric", "lightning", "fast", "energy"]),
        SuperIslandEmojiItem(emoji: "✨", name: "Sparkles", category: "Smileys", keywords: ["magic", "clean", "shine", "stars"]),
        SuperIslandEmojiItem(emoji: "👍", name: "Thumbs Up", category: "Gestures", keywords: ["agree", "yes", "good", "approve"]),
        SuperIslandEmojiItem(emoji: "❤️", name: "Red Heart", category: "Smileys", keywords: ["love", "heart", "favorite"]),
        SuperIslandEmojiItem(emoji: "🎉", name: "Party Popper", category: "Celebration", keywords: ["celebrate", "party", "tada", "congrats"]),
        SuperIslandEmojiItem(emoji: "💡", name: "Light Bulb", category: "Tech", keywords: ["idea", "bright", "smart"]),
        SuperIslandEmojiItem(emoji: "💻", name: "Laptop", category: "Tech", keywords: ["computer", "code", "work", "mac"]),
        SuperIslandEmojiItem(emoji: "📱", name: "Mobile Phone", category: "Tech", keywords: ["iphone", "android", "cell", "device"]),
        SuperIslandEmojiItem(emoji: "🎯", name: "Direct Hit", category: "Celebration", keywords: ["target", "bullseye", "goal", "accuracy"]),
        SuperIslandEmojiItem(emoji: "✅", name: "Check Mark", category: "Symbols", keywords: ["done", "complete", "ok", "verify"]),
        SuperIslandEmojiItem(emoji: "☕️", name: "Hot Beverage", category: "Food", keywords: ["coffee", "tea", "cafe", "break"]),
        SuperIslandEmojiItem(emoji: "🧠", name: "Brain", category: "Tech", keywords: ["smart", "think", "intellect", "ai"]),
        SuperIslandEmojiItem(emoji: "🤖", name: "Robot", category: "Tech", keywords: ["bot", "ai", "machine", "agent"]),
        SuperIslandEmojiItem(emoji: "👀", name: "Eyes", category: "Gestures", keywords: ["look", "see", "watch", "glance"]),
        SuperIslandEmojiItem(emoji: "🙌", name: "Raising Hands", category: "Gestures", keywords: ["cheer", "praise", "celebration", "woohoo"]),
        SuperIslandEmojiItem(emoji: "🛠️", name: "Hammer and Wrench", category: "Tech", keywords: ["tools", "build", "fix", "repair"]),
        SuperIslandEmojiItem(emoji: "📦", name: "Package", category: "Symbols", keywords: ["box", "delivery", "shipping", "parcel"]),
        SuperIslandEmojiItem(emoji: "🔒", name: "Locked", category: "Symbols", keywords: ["security", "private", "safe", "key"])
    ]

    private override init() {
        super.init()
    }

    public func search(query: String, limit: Int = 12) -> [SuperIslandEmojiItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty {
            return Array(emojiCatalog.prefix(limit))
        }

        let filtered = emojiCatalog.filter { item in
            item.name.lowercased().contains(q) ||
            item.category.lowercased().contains(q) ||
            item.keywords.contains(where: { $0.lowercased().contains(q) })
        }
        return Array(filtered.prefix(limit))
    }

    public func copyEmojiToClipboard(_ emoji: String) {
        DispatchQueue.main.async {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(emoji, forType: .string)
        }
    }

    public func searchJson(query: String) -> String {
        let results = search(query: query)
        var itemsJson: [String] = []
        for r in results {
            itemsJson.append("""
            {"emoji":"\(r.emoji)","name":"\(r.name)","category":"\(r.category)"}
            """)
        }
        return "[\(itemsJson.joined(separator: ","))]"
    }
}
