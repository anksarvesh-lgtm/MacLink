//
//  MacIslandAirDropService.swift
//  MacLink
//
//  Reverse-engineered from BadRat-in/MacIsland:
//  AirDrop file sharing dispatcher directly from the notch shelf using
//  NSSharingService(named: .sendViaAirDrop).
//

import Foundation
import AppKit

@objc public final class MacIslandAirDropService: NSObject, NSSharingServiceDelegate {
    @objc public static let shared = MacIslandAirDropService()

    private var activeService: NSSharingService?

    private override init() {
        super.init()
    }

    @objc public func triggerAirDrop(forPath path: String) -> Bool {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let url: URL
        if trimmed.isEmpty {
            // Default to ~/Downloads or Desktop if empty path specified
            url = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: "/tmp")
        } else if trimmed.hasPrefix("file://") {
            guard let parsed = URL(string: trimmed) else { return false }
            url = parsed
        } else {
            url = URL(fileURLWithPath: trimmed)
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let service = NSSharingService(named: .sendViaAirDrop),
                  service.canPerform(withItems: [url]) else {
                return
            }
            service.delegate = self
            self.activeService = service
            service.perform(withItems: [url])
        }
        return true
    }

    public func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        self.activeService = nil
    }

    public func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        self.activeService = nil
    }
}
