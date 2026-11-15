//
//  DynamicIslandVisionOCRService.swift
//  MacLink
//
//  Reverse-engineered from HeyyCzer/windows-dynamic-island:
//  "Find on Screen" / Live Screen OCR Search.
//  Uses Apple's native ScreenCaptureKit and Vision framework (VNRecognizeTextRequest)
//  to OCR the display, locate any on-screen text matching the user's query, and report bounding coordinates.
//

import Foundation
import AppKit
import Vision
import CoreGraphics
import ScreenCaptureKit

@objc public final class DynamicIslandVisionOCRService: NSObject {
    @objc public static let shared = DynamicIslandVisionOCRService()

    private let queue = DispatchQueue(label: "com.maclink.dynamo.visionocr", qos: .userInitiated)
    private var isScanning: Bool = false
    private var lastQuery: String = ""
    private var matches: [[String: Any]] = []
    private var currentIndex: Int = 0

    private override init() {
        super.init()
    }

    @objc public func searchScreen(forQuery query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clear()
            return
        }

        self.lastQuery = trimmed
        self.isScanning = true

        Task { [weak self] in
            guard let self = self else { return }
            do {
                let shareable = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = shareable.displays.first else {
                    await MainActor.run { self.isScanning = false }
                    return
                }

                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.width = Int(display.width)
                config.height = Int(display.height)
                config.showsCursor = false

                let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

                let request = VNRecognizeTextRequest { [weak self] req, err in
                    guard let self = self else { return }
                    guard let results = req.results as? [VNRecognizedTextObservation] else {
                        DispatchQueue.main.async { self.isScanning = false }
                        return
                    }

                    var found: [[String: Any]] = []
                    let queryLower = trimmed.lowercased()
                    let displayW = CGFloat(cgImage.width)
                    let displayH = CGFloat(cgImage.height)

                    for obs in results {
                        guard let topCandidate = obs.topCandidates(1).first else { continue }
                        let string = topCandidate.string
                        if string.lowercased().contains(queryLower) {
                            let box = obs.boundingBox
                            let x = Int(box.origin.x * displayW)
                            let y = Int((1.0 - box.origin.y - box.size.height) * displayH)
                            let w = Int(box.size.width * displayW)
                            let h = Int(box.size.height * displayH)

                            found.append([
                                "text": string,
                                "x": x,
                                "y": y,
                                "width": w,
                                "height": h,
                                "confidence": Double(round(topCandidate.confidence * 100) / 100)
                            ])
                        }
                    }

                    DispatchQueue.main.async {
                        self.matches = found
                        self.currentIndex = found.isEmpty ? 0 : 1
                        self.isScanning = false
                    }
                }

                request.recognitionLevel = .fast
                request.usesLanguageCorrection = false

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try handler.perform([request])
            } catch {
                await MainActor.run {
                    self.isScanning = false
                }
            }
        }
    }

    @objc public func nextMatch() {
        guard !matches.isEmpty else { return }
        currentIndex = (currentIndex % matches.count) + 1
    }

    @objc public func previousMatch() {
        guard !matches.isEmpty else { return }
        currentIndex = (currentIndex - 2 + matches.count) % matches.count + 1
    }

    @objc public func clear() {
        self.lastQuery = ""
        self.matches = []
        self.currentIndex = 0
        self.isScanning = false
    }

    @objc public func getScreenOcrJson() -> String {
        let dict: [String: Any] = [
            "isScanning": isScanning,
            "hasScanned": !lastQuery.isEmpty && !isScanning,
            "query": lastQuery,
            "matchCount": matches.count,
            "currentIndex": currentIndex,
            "matches": matches,
            "source": "ScreenCaptureKitVisionOCR"
        ]

        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }

    @objc public func simulateMatches(query: String, count: Int) {
        self.lastQuery = query
        self.isScanning = false
        var sim: [[String: Any]] = []
        for i in 1...max(1, count) {
            sim.append([
                "text": "\(query) occurrence #\(i)",
                "x": 300 + (i * 80),
                "y": 200 + (i * 50),
                "width": 120,
                "height": 24,
                "confidence": 0.96
            ])
        }
        self.matches = sim
        self.currentIndex = 1
    }
}
