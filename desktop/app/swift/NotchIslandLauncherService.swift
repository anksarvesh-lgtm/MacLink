// SPDX-License-Identifier: GPL-3.0-or-later
// NotchIslandLauncherService.swift - Spotlight-style fuzzy app launcher, inline math calculator & unit converter
// Reverse-engineered from NotchIsland (https://github.com/Edwardrem/NotchIsland)

import Foundation
import AppKit

public struct NotchLauncherItem: Codable, Sendable {
    public let id: String
    public let kind: String // "calc", "convert", "app", "action"
    public let title: String
    public let subtitle: String
    public let icon: String
    public let appPath: String
}

@MainActor
public final class NotchIslandLauncherService {
    public static let shared = NotchIslandLauncherService()

    public private(set) var currentQuery: String = ""
    public private(set) var results: [NotchLauncherItem] = []
    private var cachedApps: [(name: String, path: String, url: URL)] = []
    private var lastAppScan: Date = .distantPast

    private init() {
        scanInstalledApplications()
    }

    // MARK: - Installed Apps Discovery
    public func scanInstalledApplications() {
        var apps: [(name: String, path: String, url: URL)] = []
        let searchDirs = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]

        for dir in searchDirs {
            guard let enumerator = FileManager.default.enumerator(
                at: dir,
                includingPropertiesForKeys: [.isApplicationKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "app" {
                    let name = fileURL.deletingPathExtension().lastPathComponent
                    apps.append((name: name, path: fileURL.path, url: fileURL))
                }
            }
        }

        self.cachedApps = apps
        self.lastAppScan = Date()
    }

    // MARK: - Query Evaluation
    public func query(_ rawQuery: String) {
        self.currentQuery = rawQuery.trimmingCharacters(in: .whitespaces)
        if currentQuery.isEmpty {
            self.results = defaultQuickActions()
            return
        }

        var items: [NotchLauncherItem] = []

        // 1. Math Calculator
        if NotchCalculator.looksLikeMath(currentQuery), let val = NotchCalculator.evaluate(currentQuery) {
            let formatted = NotchCalculator.format(val)
            items.append(NotchLauncherItem(
                id: "calc:\(formatted)",
                kind: "calc",
                title: formatted,
                subtitle: "= \(currentQuery)   •   Click or Enter to copy",
                icon: "equal",
                appPath: ""
            ))
        }

        // 2. Unit Converter
        if let conv = NotchUnitConverter.convert(currentQuery) {
            let formatted = "\(NotchCalculator.format(conv.value)) \(conv.toSymbol)"
            items.append(NotchLauncherItem(
                id: "convert:\(formatted)",
                kind: "convert",
                title: formatted,
                subtitle: "\(currentQuery)   •   Click or Enter to copy",
                icon: "arrow.left.arrow.right",
                appPath: ""
            ))
        }

        // 3. Quick Actions Match
        let quickActions = allQuickActions()
        let matchingActions = quickActions.filter { a in
            score(currentQuery, a.title) != nil || a.subtitle.lowercased().contains(currentQuery.lowercased())
        }
        items.append(contentsOf: matchingActions.prefix(3))

        // 4. Fuzzy App Search
        if cachedApps.isEmpty || Date().timeIntervalSince(lastAppScan) > 300 {
            scanInstalledApplications()
        }

        let scoredApps = cachedApps.compactMap { app -> (name: String, path: String, score: Int)? in
            guard let s = score(currentQuery, app.name) else { return nil }
            return (name: app.name, path: app.path, score: s)
        }
        .sorted { $0.score > $1.score }

        for a in scoredApps.prefix(6) {
            items.append(NotchLauncherItem(
                id: "app:\(a.path)",
                kind: "app",
                title: a.name,
                subtitle: a.path,
                icon: "app",
                appPath: a.path
            ))
        }

        self.results = Array(items.prefix(8))
    }

    // MARK: - Execution
    public func executeItem(id: String) {
        if id.hasPrefix("calc:") {
            let res = String(id.dropFirst(5))
            copyToClipboard(res)
        } else if id.hasPrefix("convert:") {
            let res = String(id.dropFirst(8))
            copyToClipboard(res)
        } else if id.hasPrefix("app:") {
            let path = String(id.dropFirst(4))
            let url = URL(fileURLWithPath: path)
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
        } else if id.hasPrefix("action:") {
            let actionName = String(id.dropFirst(7))
            executeQuickAction(actionName)
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func executeQuickAction(_ action: String) {
        switch action {
        case "lock":
            let lib = "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession"
            if FileManager.default.fileExists(atPath: lib) {
                Process.launchedProcess(launchPath: lib, arguments: ["-suspend"])
            }
        case "sleep":
            let script = "tell application \"Finder\" to sleep"
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(nil)
            }
        case "trash":
            let script = "tell application \"Finder\" to empty trash"
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(nil)
            }
        case "terminal":
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
            }
        case "finder":
            NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser)
        default:
            break
        }
    }

    private func defaultQuickActions() -> [NotchLauncherItem] {
        return [
            NotchLauncherItem(id: "action:lock", kind: "action", title: "Lock Screen", subtitle: "Lock Mac immediately", icon: "lock", appPath: ""),
            NotchLauncherItem(id: "action:sleep", kind: "action", title: "Sleep Mac", subtitle: "Put system to sleep", icon: "moon", appPath: ""),
            NotchLauncherItem(id: "action:trash", kind: "action", title: "Empty Trash", subtitle: "Clear deleted files from Trash", icon: "trash", appPath: ""),
            NotchLauncherItem(id: "action:terminal", kind: "action", title: "Open Terminal", subtitle: "Launch macOS command line", icon: "terminal", appPath: "")
        ]
    }

    private func allQuickActions() -> [NotchLauncherItem] {
        return [
            NotchLauncherItem(id: "action:lock", kind: "action", title: "Lock Screen", subtitle: "Lock Mac display immediately", icon: "lock", appPath: ""),
            NotchLauncherItem(id: "action:sleep", kind: "action", title: "Sleep Display", subtitle: "Put displays and system to sleep", icon: "moon", appPath: ""),
            NotchLauncherItem(id: "action:trash", kind: "action", title: "Empty Trash", subtitle: "Clean trash bin safely", icon: "trash", appPath: ""),
            NotchLauncherItem(id: "action:terminal", kind: "action", title: "Open Terminal", subtitle: "macOS Terminal CLI", icon: "terminal", appPath: ""),
            NotchLauncherItem(id: "action:finder", kind: "action", title: "Open Home in Finder", subtitle: "Navigate to user home folder", icon: "folder", appPath: "")
        ]
    }

    private func score(_ query: String, _ name: String) -> Int? {
        let q = query.lowercased()
        let n = name.lowercased()
        if n == q { return 1000 }
        if n.hasPrefix(q) { return 600 - n.count }
        if let r = n.range(of: q) {
            let offset = n.distance(from: n.startIndex, to: r.lowerBound)
            return 350 - offset
        }
        var idx = n.startIndex
        var gaps = 0
        for ch in q {
            guard let found = n[idx...].firstIndex(of: ch) else { return nil }
            gaps += n.distance(from: idx, to: found)
            idx = n.index(after: found)
        }
        return gaps > 10 ? nil : 150 - gaps * 8
    }

    // MARK: - JSON Output
    public func getResultsJSON() -> String {
        var list: [String] = []
        for it in results {
            let escId = it.id.replacingOccurrences(of: "\"", with: "\\\"")
            let escTitle = it.title.replacingOccurrences(of: "\"", with: "\\\"")
            let escSub = it.subtitle.replacingOccurrences(of: "\"", with: "\\\"")
            let escIcon = it.icon.replacingOccurrences(of: "\"", with: "\\\"")
            let escPath = it.appPath.replacingOccurrences(of: "\"", with: "\\\"")
            list.append("""
            {"id":"\(escId)","kind":"\(it.kind)","title":"\(escTitle)","subtitle":"\(escSub)","icon":"\(escIcon)","appPath":"\(escPath)"}
            """)
        }
        return "[\(list.joined(separator: ","))]"
    }
}

// MARK: - Pure Recursive Descent Math Calculator
public enum NotchCalculator {
    public static func looksLikeMath(_ s: String) -> Bool {
        let t = s.replacingOccurrences(of: " ", with: "")
        guard t.rangeOfCharacter(from: .decimalDigits) != nil,
              t.rangeOfCharacter(from: CharacterSet(charactersIn: "+-*/^%×÷")) != nil,
              t.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789.+-*/^%()×÷ ").inverted) == nil
        else { return false }
        return true
    }

    public static func evaluate(_ s: String) -> Double? {
        var p = Parser(s.replacingOccurrences(of: "×", with: "*").replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: " ", with: ""))
        guard let v = p.expression(), p.atEnd, v.isFinite else { return nil }
        return v
    }

    public static func format(_ v: Double) -> String {
        if v == v.rounded(), abs(v) < 1e15 { return String(Int64(v)) }
        let f = NumberFormatter()
        f.maximumFractionDigits = 6
        f.minimumFractionDigits = 0
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }

    private struct Parser {
        let chars: [Character]
        var i = 0
        init(_ s: String) { chars = Array(s) }
        var atEnd: Bool { i >= chars.count }
        var peek: Character? { i < chars.count ? chars[i] : nil }

        mutating func expression() -> Double? {
            guard var v = term() else { return nil }
            while let c = peek, c == "+" || c == "-" {
                i += 1
                guard let r = term() else { return nil }
                v = c == "+" ? v + r : v - r
            }
            return v
        }

        mutating func term() -> Double? {
            guard var v = power() else { return nil }
            while let c = peek, c == "*" || c == "/" || c == "%" {
                i += 1
                guard let r = power() else { return nil }
                switch c {
                case "*": v *= r
                case "/": v /= r
                default: v = v.truncatingRemainder(dividingBy: r)
                }
            }
            return v
        }

        mutating func power() -> Double? {
            guard let base = unary() else { return nil }
            if peek == "^" {
                i += 1
                guard let e = power() else { return nil }
                return pow(base, e)
            }
            return base
        }

        mutating func unary() -> Double? {
            if peek == "-" { i += 1; return unary().map { -$0 } }
            if peek == "+" { i += 1; return unary() }
            return primary()
        }

        mutating func primary() -> Double? {
            if peek == "(" {
                i += 1
                guard let v = expression(), peek == ")" else { return nil }
                i += 1
                return v
            }
            var text = ""
            while let c = peek, c.isNumber || c == "." { text.append(c); i += 1 }
            return Double(text)
        }
    }
}

// MARK: - Unit Converter
public enum NotchUnitConverter {
    public struct Result {
        public let value: Double
        public let fromSymbol: String
        public let toSymbol: String
    }

    private static let table: [String: Dimension] = [
        "mm": UnitLength.millimeters, "cm": UnitLength.centimeters, "m": UnitLength.meters,
        "km": UnitLength.kilometers, "in": UnitLength.inches, "inch": UnitLength.inches, "inches": UnitLength.inches,
        "ft": UnitLength.feet, "feet": UnitLength.feet, "foot": UnitLength.feet, "yd": UnitLength.yards,
        "mi": UnitLength.miles, "mile": UnitLength.miles, "miles": UnitLength.miles,
        "g": UnitMass.grams, "kg": UnitMass.kilograms, "lb": UnitMass.pounds, "lbs": UnitMass.pounds,
        "oz": UnitMass.ounces,
        "c": UnitTemperature.celsius, "°c": UnitTemperature.celsius, "f": UnitTemperature.fahrenheit,
        "°f": UnitTemperature.fahrenheit, "k": UnitTemperature.kelvin,
        "ml": UnitVolume.milliliters, "l": UnitVolume.liters, "gal": UnitVolume.gallons,
        "cup": UnitVolume.cups, "cups": UnitVolume.cups,
        "kmh": UnitSpeed.kilometersPerHour, "km/h": UnitSpeed.kilometersPerHour,
        "mph": UnitSpeed.milesPerHour, "ms": UnitSpeed.metersPerSecond,
        "kb": UnitInformationStorage.kilobytes, "mb": UnitInformationStorage.megabytes,
        "gb": UnitInformationStorage.gigabytes, "tb": UnitInformationStorage.terabytes
    ]

    private static let pattern = try! NSRegularExpression(
        pattern: #"^\s*(-?\d+(?:\.\d+)?)\s*([a-zA-Z°/]+)\s+(?:to|in|->|as)\s+([a-zA-Z°/]+)\s*$"#,
        options: [.caseInsensitive]
    )

    public static func convert(_ query: String) -> Result? {
        let ns = query as NSString
        guard let m = pattern.firstMatch(in: query, range: NSRange(location: 0, length: ns.length)) else { return nil }
        guard let value = Double(ns.substring(with: m.range(at: 1))) else { return nil }
        let fromKey = ns.substring(with: m.range(at: 2)).lowercased()
        let toKey = ns.substring(with: m.range(at: 3)).lowercased()
        guard let from = table[fromKey], let to = table[toKey],
              type(of: from) == type(of: to) else { return nil }
        let converted = Measurement(value: value, unit: from).converted(to: to).value
        return Result(value: converted, fromSymbol: from.symbol, toSymbol: to.symbol)
    }
}
