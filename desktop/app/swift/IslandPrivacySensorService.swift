// SPDX-License-Identifier: GPL-3.0-or-later
import CoreAudio
import CoreMediaIO
import Foundation

/// Service reverse-engineered from poshak2004/island (RecordingProvider.swift)
/// Detects real-time microphone and camera usage by ANY macOS application
/// using public CoreAudio and CoreMediaIO hardware property listeners.
@objc public final class IslandPrivacySensorService: NSObject {
    @objc public static let shared = IslandPrivacySensorService()

    private var audioListeners: [(AudioObjectID, AudioObjectPropertyListenerBlock)] = []
    private var cameraListeners: [(CMIOObjectID, CMIOObjectPropertyListenerBlock)] = []
    private var deviceListListener: AudioObjectPropertyListenerBlock?

    @objc public private(set) var micActive = false
    @objc public private(set) var cameraActive = false
    @objc public private(set) var simulatedMicActive = false
    @objc public private(set) var simulatedCameraActive = false

    private static var devicesAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private static var runningAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private static var cmioRunningAddress = CMIOObjectPropertyAddress(
        mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
        mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
        mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
    )

    private override init() {
        super.init()
    }

    @objc public func start() {
        guard deviceListListener == nil else { return }

        // Enable CMIO device discovery for cameras
        var allowScreenCapture: UInt32 = 1
        var prop = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
        )
        CMIOObjectSetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject),
            &prop,
            0,
            nil,
            UInt32(MemoryLayout<UInt32>.size),
            &allowScreenCapture
        )

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async { self?.rebuild() }
        }
        deviceListListener = block
        var addr = Self.devicesAddress
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, DispatchQueue.main, block)
        rebuild()
    }

    @objc public func stop() {
        removeDeviceListeners()
        if let l = deviceListListener {
            var addr = Self.devicesAddress
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, DispatchQueue.main, l)
        }
        deviceListListener = nil
    }

    private func removeDeviceListeners() {
        for (id, l) in audioListeners {
            var addr = Self.runningAddress
            AudioObjectRemovePropertyListenerBlock(id, &addr, DispatchQueue.main, l)
        }
        audioListeners.removeAll()
        for (id, l) in cameraListeners {
            var addr = Self.cmioRunningAddress
            CMIOObjectRemovePropertyListenerBlock(id, &addr, DispatchQueue.main, l)
        }
        cameraListeners.removeAll()
    }

    private func rebuild() {
        removeDeviceListeners()
        for id in Self.inputDevices() {
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                DispatchQueue.main.async { self?.evaluate() }
            }
            var addr = Self.runningAddress
            if AudioObjectAddPropertyListenerBlock(id, &addr, DispatchQueue.main, block) == noErr {
                audioListeners.append((id, block))
            }
        }
        for id in Self.cameraDevices() {
            let block: CMIOObjectPropertyListenerBlock = { [weak self] _, _ in
                DispatchQueue.main.async { self?.evaluate() }
            }
            var addr = Self.cmioRunningAddress
            if CMIOObjectAddPropertyListenerBlock(id, &addr, DispatchQueue.main, block) == noErr {
                cameraListeners.append((id, block))
            }
        }
        evaluate()
    }

    private func evaluate() {
        let mic = audioListeners.contains { Self.isRunning($0.0) }
        let cam = cameraListeners.contains { Self.cameraRunning($0.0) }
        micActive = mic
        cameraActive = cam
    }

    @objc public func toggleSimulatedMic() {
        simulatedMicActive.toggle()
    }

    @objc public func toggleSimulatedCamera() {
        simulatedCameraActive.toggle()
    }

    // MARK: CoreAudio / CoreMediaIO Helpers

    private static func inputDevices() -> [AudioObjectID] {
        var addr = devicesAddress
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.filter(hasInput)
    }

    private static func hasInput(_ id: AudioObjectID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr else { return false }
        return size > 0
    }

    private static func isRunning(_ id: AudioObjectID) -> Bool {
        var addr = runningAddress
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &running) == noErr else { return false }
        return running != 0
    }

    private static func cameraDevices() -> [CMIOObjectID] {
        var addr = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &addr, 0, nil, size, &used, &ids) == noErr else { return [] }
        return ids
    }

    private static func cameraRunning(_ id: CMIOObjectID) -> Bool {
        var addr = cmioRunningAddress
        var running: UInt32 = 0
        var used: UInt32 = 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        guard CMIOObjectGetPropertyData(id, &addr, 0, nil, size, &used, &running) == noErr else { return false }
        return running != 0
    }

    @objc public func getSensorsJson() -> String {
        let isMic = micActive || simulatedMicActive
        let isCam = cameraActive || simulatedCameraActive
        let anyActive = isMic || isCam

        let dict: [String: Any] = [
            "anyActive": anyActive,
            "micActive": isMic,
            "cameraActive": isCam,
            "isLiveHardwareMic": micActive,
            "isLiveHardwareCam": cameraActive
        ]

        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{\"anyActive\":false,\"micActive\":false,\"cameraActive\":false,\"isLiveHardwareMic\":false,\"isLiveHardwareCam\":false}"
    }
}
