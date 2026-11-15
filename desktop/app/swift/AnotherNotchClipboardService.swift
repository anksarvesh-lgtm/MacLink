// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import Foundation

@objc public final class AnotherNotchClipboardService: NSObject, @unchecked Sendable {
    public static let shared = AnotherNotchClipboardService()

    public struct ClipItem: Codable, Sendable {
        public let id: String
        public let text: String
        public let preview: String
        public let timestamp: Double
        public let charCount: Int
    }

    private var items: [ClipItem] = []
    private var lastChangeCount: Int = -1
    private var timerSource: DispatchSourceTimer?
    private let maxHistoryCount = 50
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "com.maclink.clipboard.monitor", qos: .utility)

    private var storageFileURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let maclinkDir = appSupport.appendingPathComponent("MacLink")
        try? FileManager.default.createDirectory(at: maclinkDir, withIntermediateDirectories: true, attributes: nil)
        return maclinkDir.appendingPathComponent("clipboard_history.json")
    }

    private override init() {
        super.init()
        loadFromDisk()
    }

    private func loadFromDisk() {
        guard let url = storageFileURL,
              let data = try? Data(contentsOf: url),
              let loaded = try? JSONDecoder().decode([ClipItem].self, from: data) else {
            return
        }
        lock.lock()
        items = loaded
        lock.unlock()
    }

    private func saveToDisk() {
        lock.lock()
        let toSave = items
        lock.unlock()

        guard let url = storageFileURL,
              let data = try? JSONEncoder().encode(toSave) else {
            return
        }
        try? data.write(to: url, options: .atomic)
    }

    public func start() {
        // Read current pasteboard immediately
        checkPasteboard()

        // Start background GCD DispatchSourceTimer that continuously checks every 350ms on main queue
        timerSource?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now() + 0.35, repeating: .milliseconds(350))
        timer.setEventHandler { [weak self] in
            self?.checkPasteboard()
        }
        timer.resume()
        timerSource = timer
    }

    public func checkPasteboard() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.checkPasteboard()
            }
            return
        }

        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        lock.lock()
        let prevCount = lastChangeCount
        lock.unlock()

        guard currentCount != prevCount else { return }

        var text: String? = nil
        if let s = pasteboard.string(forType: .string) {
            text = s
        } else if let objs = pasteboard.readObjects(forClasses: [NSString.self], options: nil) as? [String], let s = objs.first {
            text = s
        } else if let s = pasteboard.string(forType: .URL) {
            text = s
        } else if let s = pasteboard.string(forType: .fileURL) {
            text = s
        }

        guard let raw = text, !raw.isEmpty else {
            lock.lock()
            lastChangeCount = currentCount
            lock.unlock()
            return
        }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lock.lock()
            lastChangeCount = currentCount
            lock.unlock()
            return
        }

        lock.lock()
        lastChangeCount = currentCount

        // Don't duplicate if identical to the most recent item
        if let first = items.first, first.text == trimmed {
            lock.unlock()
            return
        }

        // Cap stored text at 4,000 characters to prevent unbounded memory or JSON bloat
        let storedText = trimmed.count > 4000 ? String(trimmed.prefix(4000)) : trimmed
        let preview = String(storedText.prefix(80)).replacingOccurrences(of: "\n", with: " ")
        let item = ClipItem(
            id: UUID().uuidString,
            text: storedText,
            preview: preview,
            timestamp: Date().timeIntervalSince1970,
            charCount: trimmed.count
        )

        items.insert(item, at: 0)
        if items.count > maxHistoryCount {
            items.removeLast()
        }
        lock.unlock()

        saveToDisk()
    }

    public func addEntry(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        lock.lock()
        if let first = items.first, first.text == trimmed {
            lock.unlock()
            return
        }

        let preview = String(trimmed.prefix(80)).replacingOccurrences(of: "\n", with: " ")
        let item = ClipItem(
            id: UUID().uuidString,
            text: trimmed,
            preview: preview,
            timestamp: Date().timeIntervalSince1970,
            charCount: trimmed.count
        )

        items.insert(item, at: 0)
        if items.count > maxHistoryCount {
            items.removeLast()
        }
        lock.unlock()

        saveToDisk()
    }

    public func copyEntry(id: String) -> Bool {
        lock.lock()
        guard let item = items.first(where: { $0.id == id }) else {
            lock.unlock()
            return false
        }
        let text = item.text
        lock.unlock()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        lock.lock()
        lastChangeCount = pasteboard.changeCount
        lock.unlock()
        return true
    }

    public func clearHistory() {
        lock.lock()
        items.removeAll()
        lock.unlock()
        saveToDisk()
    }

    public func getHistoryJson(query: String = "") -> String {
        // Ensure fresh state from pasteboard
        checkPasteboard()

        lock.lock()
        let currentItems = items
        lock.unlock()

        let filtered: [ClipItem]
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            filtered = currentItems
        } else {
            let lower = q.lowercased()
            filtered = currentItems.filter { $0.text.lowercased().contains(lower) }
        }

        guard let data = try? JSONEncoder().encode(filtered),
              let jsonStr = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return jsonStr
    }
}
