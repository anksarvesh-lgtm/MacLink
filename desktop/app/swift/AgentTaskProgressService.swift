// SPDX-License-Identifier: GPL-3.0-or-later
//
//  AgentTaskProgressService.swift
//  MacLink Native AI Agent Task Checklist & Progress Engine
//  Reverse-engineered and adapted from CodeIsland (wxtsky/CodeIsland)
//

import Cocoa
import Foundation

public final class AgentTaskProgressService {
    public static let shared = AgentTaskProgressService()

    public struct TaskItem: Codable {
        public var title: String
        public var status: String // "pending", "in_progress", "completed"
        public var activeForm: String?
    }

    public struct Snapshot: Codable {
        public var hasTasks: Bool
        public var total: Int
        public var completed: Int
        public var inProgress: Int
        public var percent: Double
        public var activeTitle: String
        public var isAllCompleted: Bool
        public var items: [TaskItem]
    }

    private var items: [TaskItem] = []
    private let lock = NSLock()

    private init() {
        // Pre-populate with clean default / sample task state
        self.items = [
            TaskItem(title: "Reverse Engineer Repositories", status: "completed", activeForm: nil),
            TaskItem(title: "CodeIsland Integration", status: "in_progress", activeForm: "Integrating CodeIsland"),
            TaskItem(title: "SquickShare & Atoll Modules", status: "pending", activeForm: nil)
        ]
    }

    public func setTasks(_ newItems: [TaskItem]) {
        lock.lock()
        defer { lock.unlock() }
        self.items = newItems
    }

    public func updateTask(index: Int, status: String) {
        lock.lock()
        defer { lock.unlock() }
        guard index >= 0 && index < items.count else { return }
        items[index].status = status
    }

    public func clearTasks() {
        lock.lock()
        defer { lock.unlock() }
        self.items = []
    }

    public func getSnapshot() -> Snapshot {
        lock.lock()
        defer { lock.unlock() }

        let total = items.count
        let completed = items.filter { $0.status == "completed" }.count
        let inProgress = items.filter { $0.status == "in_progress" }.count
        let percent = total > 0 ? Double(completed) / Double(total) : 0.0
        let active = items.first(where: { $0.status == "in_progress" })?.activeForm
            ?? items.first(where: { $0.status == "in_progress" })?.title
            ?? ""
        let isAllCompleted = total > 0 && completed == total

        return Snapshot(
            hasTasks: total > 0,
            total: total,
            completed: completed,
            inProgress: inProgress,
            percent: percent,
            activeTitle: active,
            isAllCompleted: isAllCompleted,
            items: items
        )
    }
}
