// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import Foundation

/// Service reverse-engineered from poshak2004/island (DownloadProvider.swift)
/// Subscribes to system-wide file downloads under ~/Downloads using the public
/// Foundation `Progress.addSubscriber(forFileURL:)` API used by Safari, Chrome, Edge, and Arc.
@objc public final class IslandDownloadService: NSObject, @unchecked Sendable {
    @objc public static let shared = IslandDownloadService()

    public final class DownloadItem: @unchecked Sendable {
        public let id: String
        public let progress: Progress
        public var observations: [NSKeyValueObservation] = []
        public var filename: String
        public var fileURL: URL?
        public var lastEmit = Date.distantPast
        public var lastBytes: Int64 = 0
        public var lastBytesAt = Date()
        public var speed: Double = 0.0 // bytes per second
        public var fraction: Double = 0.0
        public var completedBytes: Int64 = 0
        public var totalBytes: Int64 = 0
        public var isPaused: Bool = false
        public var isIndeterminate: Bool = false

        public init(id: String, progress: Progress) {
            self.id = id
            self.progress = progress
            self.filename = progress.fileURL?.lastPathComponent ?? "Downloading file…"
            self.fileURL = progress.fileURL
        }
    }

    private var subscriber: Any?
    private var downloads: [String: DownloadItem] = [:]
    private var simulatedDownload: DownloadItem?
    private var simTimer: Timer?
    private let lock = NSLock()
    private let downloadsDirectory: URL

    private override init() {
        self.downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
        super.init()
    }

    @objc public func start() {
        guard subscriber == nil else { return }

        subscriber = Progress.addSubscriber(forFileURL: downloadsDirectory) { [weak self] progress in
            let id = "dl_\(UUID().uuidString.prefix(8))"
            DispatchQueue.main.async {
                self?.track(progress: progress, id: id)
            }
            return {
                DispatchQueue.main.async {
                    self?.untrack(id: id)
                }
            }
        }
    }

    @objc public func stop() {
        if let sub = subscriber {
            Progress.removeSubscriber(sub)
            subscriber = nil
        }
        lock.lock()
        for item in downloads.values {
            item.observations.removeAll()
        }
        downloads.removeAll()
        simTimer?.invalidate()
        simTimer = nil
        simulatedDownload = nil
        lock.unlock()
    }

    private func track(progress: Progress, id: String) {
        lock.lock()
        let item = DownloadItem(id: id, progress: progress)
        let handler: @Sendable (Progress, NSKeyValueObservedChange<Double>) -> Void = { [weak self] p, _ in
            DispatchQueue.main.async { self?.update(item: item) }
        }
        item.observations.append(progress.observe(\.fractionCompleted, options: [.initial, .new], changeHandler: handler))
        item.observations.append(progress.observe(\.isPaused, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.update(item: item) }
        })
        downloads[id] = item
        lock.unlock()
        update(item: item)
    }

    private func untrack(id: String) {
        lock.lock()
        if let item = downloads.removeValue(forKey: id) {
            item.observations.removeAll()
        }
        lock.unlock()
    }

    private func update(item: DownloadItem) {
        let p = item.progress
        let now = Date()
        let completed = p.completedUnitCount
        let dt = now.timeIntervalSince(item.lastBytesAt)
        if dt >= 0.4 {
            let instant = Double(completed - item.lastBytes) / dt
            if instant >= 0 {
                item.speed = item.speed > 0 ? (item.speed * 0.7 + instant * 0.3) : instant
            }
            item.lastBytes = completed
            item.lastBytesAt = now
        }
        item.fraction = p.isIndeterminate ? 0.0 : p.fractionCompleted
        item.completedBytes = max(0, completed)
        item.totalBytes = p.totalUnitCount
        item.isPaused = p.isPaused
        item.isIndeterminate = p.isIndeterminate
        if let url = p.fileURL {
            item.fileURL = url
            item.filename = url.lastPathComponent
        }
    }

    @objc public func cancel(id: String) {
        lock.lock()
        defer { lock.unlock() }
        if id == "simulated" {
            simTimer?.invalidate()
            simTimer = nil
            simulatedDownload = nil
            return
        }
        if let item = downloads[id] {
            item.progress.cancel()
            downloads.removeValue(forKey: id)
        }
    }

    @objc public func revealInFinder(id: String) {
        lock.lock()
        let url = (id == "simulated") ? simulatedDownload?.fileURL : downloads[id]?.fileURL
        lock.unlock()

        if let targetUrl = url ?? downloadsDirectory as URL? {
            NSWorkspace.shared.activateFileViewerSelecting([targetUrl])
        }
    }

    @objc public func simulateIncomingDownload() {
        lock.lock()
        simTimer?.invalidate()
        let p = Progress(totalUnitCount: 1024 * 1024 * 45) // 45 MB
        p.completedUnitCount = 1024 * 1024 * 5
        let dummyUrl = downloadsDirectory.appendingPathComponent("Xcode_16.2_Release.dmg")
        p.fileURL = dummyUrl
        let item = DownloadItem(id: "simulated", progress: p)
        item.filename = "Xcode_16.2_Release.dmg"
        item.fileURL = dummyUrl
        item.completedBytes = p.completedUnitCount
        item.totalBytes = p.totalUnitCount
        item.fraction = Double(p.completedUnitCount) / Double(p.totalUnitCount)
        item.speed = 1024 * 1024 * 3.8 // 3.8 MB/s
        self.simulatedDownload = item
        lock.unlock()

        simTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            self.lock.lock()
            guard let sim = self.simulatedDownload else {
                timer.invalidate()
                self.lock.unlock()
                return
            }
            let step: Int64 = 1024 * 1024 * 2 // +2MB each tick
            sim.completedBytes += step
            sim.speed = 1024 * 1024 * 4.2
            if sim.completedBytes >= sim.totalBytes {
                sim.completedBytes = sim.totalBytes
                sim.fraction = 1.0
                timer.invalidate()
                self.simTimer = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.lock.lock()
                    self.simulatedDownload = nil
                    self.lock.unlock()
                }
            } else {
                sim.fraction = Double(sim.completedBytes) / Double(sim.totalBytes)
            }
            self.lock.unlock()
        }
    }

    @objc public func getDownloadsJson() -> String {
        lock.lock()
        var items: [[String: Any]] = []

        if let sim = simulatedDownload {
            let etaSecs: Int = sim.speed > 0 ? max(0, Int(Double(sim.totalBytes - sim.completedBytes) / sim.speed)) : 0
            items.append([
                "id": sim.id,
                "filename": sim.filename,
                "fraction": sim.fraction,
                "percent": Int(sim.fraction * 100),
                "completedMB": String(format: "%.1f", Double(sim.completedBytes) / (1024 * 1024)),
                "totalMB": String(format: "%.1f", Double(sim.totalBytes) / (1024 * 1024)),
                "speedMBs": String(format: "%.1f", sim.speed / (1024 * 1024)),
                "etaSeconds": etaSecs,
                "isPaused": sim.isPaused
            ])
        }

        for (id, dl) in downloads {
            let etaSecs: Int = dl.speed > 0 ? max(0, Int(Double(dl.totalBytes - dl.completedBytes) / dl.speed)) : 0
            items.append([
                "id": id,
                "filename": dl.filename,
                "fraction": dl.fraction,
                "percent": Int(dl.fraction * 100),
                "completedMB": String(format: "%.1f", Double(dl.completedBytes) / (1024 * 1024)),
                "totalMB": String(format: "%.1f", Double(dl.totalBytes) / (1024 * 1024)),
                "speedMBs": String(format: "%.1f", dl.speed / (1024 * 1024)),
                "etaSeconds": etaSecs,
                "isPaused": dl.isPaused
            ])
        }
        lock.unlock()

        let root: [String: Any] = [
            "hasActiveDownloads": !items.isEmpty,
            "activeCount": items.count,
            "downloads": items
        ]

        if let data = try? JSONSerialization.data(withJSONObject: root, options: []),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{\"hasActiveDownloads\":false,\"activeCount\":0,\"downloads\":[]}"
    }
}
