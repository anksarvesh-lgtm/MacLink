// SPDX-License-Identifier: GPL-3.0-or-later
// NotchIslandBridge.swift - C-ABI bindings for NotchIslandLauncherService

import Foundation

@_cdecl("maclink_query_launcher")
public func maclink_query_launcher(query: UnsafePointer<CChar>?) {
    guard let query = query, let qStr = String(validatingUTF8: query) else {
        DispatchQueue.main.async {
            NotchIslandLauncherService.shared.query("")
        }
        return
    }
    DispatchQueue.main.async {
        NotchIslandLauncherService.shared.query(qStr)
    }
}

@_cdecl("maclink_get_launcher_results_json")
public func maclink_get_launcher_results_json(buffer: UnsafeMutablePointer<CChar>, maxLen: Int) -> Int {
    let json: String
    if Thread.isMainThread {
        json = MainActor.assumeIsolated {
            NotchIslandLauncherService.shared.getResultsJSON()
        }
    } else {
        json = DispatchQueue.main.sync {
            NotchIslandLauncherService.shared.getResultsJSON()
        }
    }
    let count = json.utf8.count
    if count < maxLen {
        json.withCString { ptr in
            buffer.initialize(from: ptr, count: count + 1)
        }
        return count
    }
    return 0
}

@_cdecl("maclink_execute_launcher_item")
public func maclink_execute_launcher_item(itemId: UnsafePointer<CChar>?) {
    guard let itemId = itemId, let idStr = String(validatingUTF8: itemId) else { return }
    DispatchQueue.main.async {
        NotchIslandLauncherService.shared.executeItem(id: idStr)
    }
}
