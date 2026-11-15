//
//  DynamicIslandVisionBridge.swift
//  MacLink
//
//  C-bridge exports for HeyyCzer/windows-dynamic-island features:
//  Find on screen live Vision OCR search and match navigation.
//

import Foundation

@_cdecl("maclink_get_screen_ocr_json")
public func maclink_get_screen_ocr_json(
    _ outBuf: UnsafeMutablePointer<CChar>,
    _ maxLen: Int
) -> Int {
    let json = DynamicIslandVisionOCRService.shared.getScreenOcrJson()
    guard let utf8 = json.data(using: .utf8) else { return 0 }
    let count = min(utf8.count, maxLen - 1)
    utf8.withUnsafeBytes { raw in
        if let base = raw.baseAddress {
            outBuf.initialize(from: base.assumingMemoryBound(to: CChar.self), count: count)
        }
    }
    outBuf[count] = 0
    return count
}

@_cdecl("maclink_search_screen_text")
public func maclink_search_screen_text(cQuery: UnsafePointer<CChar>?) {
    let query = cQuery != nil ? String(cString: cQuery!) : ""
    DynamicIslandVisionOCRService.shared.searchScreen(forQuery: query)
}

@_cdecl("maclink_clear_screen_search")
public func maclink_clear_screen_search() {
    DynamicIslandVisionOCRService.shared.clear()
}

@_cdecl("maclink_next_screen_match")
public func maclink_next_screen_match() {
    DynamicIslandVisionOCRService.shared.nextMatch()
}

@_cdecl("maclink_previous_screen_match")
public func maclink_previous_screen_match() {
    DynamicIslandVisionOCRService.shared.previousMatch()
}

@_cdecl("maclink_simulate_screen_matches")
public func maclink_simulate_screen_matches(cQuery: UnsafePointer<CChar>?, count: Int32) {
    let query = cQuery != nil ? String(cString: cQuery!) : "Test"
    DynamicIslandVisionOCRService.shared.simulateMatches(query: query, count: Int(count))
}
