// SPDX-License-Identifier: GPL-3.0-or-later
//
//  DragDetector.swift
//  MacLink Native Notch Drag & Drop Detection Engine
//  Reverse-engineered and adapted from boring.notch (TheBoredTeam/boring.notch)
//

import Cocoa
import UniformTypeIdentifiers

public final class NotchDragDetector {
    public static let shared = NotchDragDetector()

    public var onDragEnter: (() -> Void)?
    public var onDragExit: (() -> Void)?

    private var mouseDownMonitor: Any?
    private var mouseDraggedMonitor: Any?
    private var mouseUpMonitor: Any?

    private var pasteboardChangeCount: Int = -1
    private var isDragging: Bool = false
    private var isContentDragging: Bool = false
    public private(set) var hasEnteredNotchRegion: Bool = false

    private var notchRegion: CGRect = .zero
    private let dragPasteboard = NSPasteboard(name: .drag)

    private init() {}

    public func configureNotchRegion(rect: CGRect) {
        self.notchRegion = rect
    }

    private func hasValidDragContent() -> Bool {
        let validTypes: [NSPasteboard.PasteboardType] = [
            .fileURL,
            NSPasteboard.PasteboardType(UTType.url.identifier),
            .string
        ]
        return dragPasteboard.types?.contains(where: validTypes.contains) ?? false
    }

    public func startMonitoring() {
        stopMonitoring()

        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            guard let self = self else { return }
            self.pasteboardChangeCount = self.dragPasteboard.changeCount
            self.isDragging = true
            self.isContentDragging = false
            self.hasEnteredNotchRegion = false
        }

        mouseDraggedMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] _ in
            guard let self = self else { return }
            guard self.isDragging else { return }

            let newContent = self.dragPasteboard.changeCount != self.pasteboardChangeCount
            if newContent && !self.isContentDragging && self.hasValidDragContent() {
                self.isContentDragging = true
            }

            if self.isContentDragging {
                let mouseLocation = NSEvent.mouseLocation
                let containsMouse = self.notchRegion.contains(mouseLocation)
                if containsMouse && !self.hasEnteredNotchRegion {
                    self.hasEnteredNotchRegion = true
                    DispatchQueue.main.async {
                        self.onDragEnter?()
                    }
                } else if !containsMouse && self.hasEnteredNotchRegion {
                    self.hasEnteredNotchRegion = false
                    DispatchQueue.main.async {
                        self.onDragExit?()
                    }
                }
            }
        }

        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            guard let self = self else { return }
            guard self.isDragging else { return }
            if self.hasEnteredNotchRegion {
                self.hasEnteredNotchRegion = false
                DispatchQueue.main.async {
                    self.onDragExit?()
                }
            }
            self.isDragging = false
            self.isContentDragging = false
            self.pasteboardChangeCount = -1
        }
    }

    public func stopMonitoring() {
        if let monitor = mouseDownMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = mouseDraggedMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = mouseUpMonitor { NSEvent.removeMonitor(monitor) }
        mouseDownMonitor = nil
        mouseDraggedMonitor = nil
        mouseUpMonitor = nil
        isDragging = false
        isContentDragging = false
        hasEnteredNotchRegion = false
    }

    deinit {
        stopMonitoring()
    }
}
