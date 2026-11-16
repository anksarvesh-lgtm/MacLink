import Foundation

@_cdecl("maclink_init_mioisland_services")
public func maclink_init_mioisland_services() {
    MioIslandSoundSynthesizer.shared.start()
    MioIslandTerminalJumperService.shared.start()
}

@_cdecl("maclink_play_synth_sound")
public func maclink_play_synth_sound(_ soundPtr: UnsafePointer<CChar>?) {
    guard let soundPtr = soundPtr else { return }
    let sound = String(cString: soundPtr)
    MioIslandSoundSynthesizer.shared.play(event: sound)
}

@_cdecl("maclink_jump_to_terminal")
public func maclink_jump_to_terminal(_ termPtr: UnsafePointer<CChar>?) -> Bool {
    let term = termPtr != nil ? String(cString: termPtr!) : ""
    return MioIslandTerminalJumperService.shared.jumpToTerminal(name: term)
}

@_cdecl("maclink_get_terminals_json")
public func maclink_get_terminals_json(
    _ outBuf: UnsafeMutablePointer<CChar>,
    _ maxLen: Int
) -> Int {
    let json = MioIslandTerminalJumperService.shared.getTerminalsJson()
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
