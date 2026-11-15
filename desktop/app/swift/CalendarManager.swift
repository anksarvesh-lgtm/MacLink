// SPDX-License-Identifier: GPL-3.0-or-later
//
//  CalendarManager.swift
//  MacLink Native Calendar & Upcoming Events Sneak-Peek Engine
//  Reverse-engineered and adapted from boring.notch (TheBoredTeam/boring.notch)
//

import Foundation
import EventKit

public final class CalendarManager {
    public static let shared = CalendarManager()

    public struct CalendarEventInfo: Codable {
        public var hasEvent: Bool
        public var title: String
        public var startTime: String
        public var endTime: String
        public var minutesUntil: Int
        public var location: String
        public var isOngoing: Bool
    }

    private let eventStore = EKEventStore()
    private var cachedEvent: CalendarEventInfo = CalendarEventInfo(
        hasEvent: false,
        title: "",
        startTime: "",
        endTime: "",
        minutesUntil: 0,
        location: "",
        isOngoing: false
    )

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCalendarStoreChange),
            name: .EKEventStoreChanged,
            object: nil
        )
        requestAccessAndRefresh()
    }

    @objc private func handleCalendarStoreChange() {
        refresh()
    }

    public func requestAccessAndRefresh() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .notDetermined {
            if #available(macOS 14.0, *) {
                eventStore.requestFullAccessToEvents { [weak self] granted, _ in
                    if granted { self?.refresh() }
                }
            } else {
                eventStore.requestAccess(to: .event) { [weak self] granted, _ in
                    if granted { self?.refresh() }
                }
            }
        } else {
            var isAuth = (status.rawValue == 3 || status.rawValue == 4)
            if #available(macOS 14.0, *) {
                isAuth = isAuth || (status == .fullAccess)
            }
            if isAuth {
                refresh()
            }
        }
    }

    public func getCurrentEvent() -> CalendarEventInfo {
        return cachedEvent
    }

    public func refresh() {
        let status = EKEventStore.authorizationStatus(for: .event)
        var isAuth = (status.rawValue == 3 || status.rawValue == 4)
        if #available(macOS 14.0, *) {
            isAuth = isAuth || (status == .fullAccess)
        }
        guard isAuth else {
            return
        }

        let now = Date()
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: now)
        guard let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)

        // Find the first event that hasn't finished yet
        let upcoming = events
            .filter { !$0.isAllDay && $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }

        if let next = upcoming.first {
            let isOngoing = (next.startDate <= now && next.endDate > now)
            let diffSec = next.startDate.timeIntervalSince(now)
            let mins = max(0, Int(diffSec / 60.0))

            cachedEvent = CalendarEventInfo(
                hasEvent: true,
                title: next.title ?? "Untitled Event",
                startTime: timeFormatter.string(from: next.startDate),
                endTime: timeFormatter.string(from: next.endDate),
                minutesUntil: isOngoing ? 0 : mins,
                location: next.location ?? "",
                isOngoing: isOngoing
            )
        } else {
            cachedEvent = CalendarEventInfo(
                hasEvent: false,
                title: "",
                startTime: "",
                endTime: "",
                minutesUntil: 0,
                location: "",
                isOngoing: false
            )
        }
    }
}
