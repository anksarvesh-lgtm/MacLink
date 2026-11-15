import Foundation

@_cdecl("maclink_init_ghnotch_services")
public func maclink_init_ghnotch_services() {
    GHNotchCommandEngineService.shared.start()
}

@_cdecl("maclink_execute_ghnotch_command")
public func maclink_execute_ghnotch_command(
    _ cmdPtr: UnsafePointer<CChar>?,
    _ outBuf: UnsafeMutablePointer<CChar>,
    _ maxLen: Int
) -> Int {
    guard let cmdPtr = cmdPtr else { return 0 }
    let cmd = String(cString: cmdPtr)
    let output = GHNotchCommandEngineService.shared.executeCommand(cmd)
    guard let utf8 = output.data(using: .utf8) else { return 0 }
    let count = min(utf8.count, maxLen - 1)
    utf8.withUnsafeBytes { raw in
        if let base = raw.baseAddress {
            outBuf.initialize(from: base.assumingMemoryBound(to: CChar.self), count: count)
        }
    }
    outBuf[count] = 0
    return count
}

@_cdecl("maclink_get_ghnotch_last_result_json")
public func maclink_get_ghnotch_last_result_json(
    _ outBuf: UnsafeMutablePointer<CChar>,
    _ maxLen: Int
) -> Int {
    let json = GHNotchCommandEngineService.shared.getLastResultJson()
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
