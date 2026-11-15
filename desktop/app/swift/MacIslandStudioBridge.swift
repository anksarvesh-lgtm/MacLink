import Foundation

@_cdecl("maclink_get_macisland_studio_json")
public func maclink_get_macisland_studio_json(buffer: UnsafeMutablePointer<CChar>, max_len: Int) -> Int {
    let json = MacIslandStudioService.shared.getStudioJson()
    guard let cStr = json.cString(using: .utf8) else { return 0 }
    let len = min(cStr.count - 1, max_len - 1)
    if len > 0 {
        memcpy(buffer, cStr, len)
        buffer[len] = 0
        return len
    }
    return 0
}

@_cdecl("maclink_macisland_toggle_ring_light")
public func maclink_macisland_toggle_ring_light() {
    DispatchQueue.main.async {
        MacIslandStudioService.shared.toggleRingLight()
    }
}

@_cdecl("maclink_macisland_set_ring_light")
public func maclink_macisland_set_ring_light(brightness: Float, width: Float) {
    DispatchQueue.main.async {
        MacIslandStudioService.shared.setRingLight(brightness: brightness, width: width)
    }
}

@_cdecl("maclink_macisland_select_audio_device")
public func maclink_macisland_select_audio_device(deviceId: UInt32) {
    DispatchQueue.main.async {
        MacIslandStudioService.shared.selectAudioDevice(deviceId: deviceId)
    }
}
