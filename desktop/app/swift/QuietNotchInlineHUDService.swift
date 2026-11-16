import AppKit
import CoreAudio
import Combine
import Foundation

@objc public final class QuietNotchInlineHUDService: NSObject, @unchecked Sendable {
    public static let shared = QuietNotchInlineHUDService()

    public private(set) var activeKind: String = "volume" // "volume", "brightness", "mic"
    public private(set) var currentValue: Float = 0.5
    public private(set) var isMuted: Bool = false
    public private(set) var isHUDVisible: Bool = false
    public private(set) var lastChangeTime: TimeInterval = 0

    private var hideTimer: Timer?
    private let visibleDuration: TimeInterval = 2.0
    private var defaultOutputDeviceID: AudioObjectID = kAudioObjectUnknown

    // Function pointer type for DisplayServices brightness if available
    private typealias GetBrightnessFunc = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightnessFunc = @convention(c) (UInt32, Float) -> Int32
    private var getBrightnessPtr: GetBrightnessFunc?
    private var setBrightnessPtr: SetBrightnessFunc?

    private override init() {
        super.init()
        loadDisplayServices()
    }

    public func start() {
        setupAudioListener()
        fetchCurrentVolume()
    }

    private func loadDisplayServices() {
        if let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY) {
            if let getSym = dlsym(handle, "DisplayServicesGetBrightness") {
                getBrightnessPtr = unsafeBitCast(getSym, to: GetBrightnessFunc.self)
            }
            if let setSym = dlsym(handle, "DisplayServicesSetBrightness") {
                setBrightnessPtr = unsafeBitCast(setSym, to: SetBrightnessFunc.self)
            }
        }
    }

    // MARK: - Audio Volume & Mute

    private func setupAudioListener() {
        var defaultDeviceAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID: AudioObjectID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioObjectID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddr,
            0,
            nil,
            &size,
            &deviceID
        )

        if status == noErr && deviceID != kAudioObjectUnknown {
            self.defaultOutputDeviceID = deviceID
            registerDeviceListeners(for: deviceID)
        }
    }

    private func registerDeviceListeners(for deviceID: AudioObjectID) {
        var volumeAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectAddPropertyListenerBlock(deviceID, &volumeAddr, DispatchQueue.main) { [weak self] _, _ in
            self?.fetchCurrentVolume()
        }

        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectAddPropertyListenerBlock(deviceID, &muteAddr, DispatchQueue.main) { [weak self] _, _ in
            self?.fetchCurrentVolume()
        }
    }

    public func fetchCurrentVolume() {
        let deviceID = defaultOutputDeviceID != kAudioObjectUnknown ? defaultOutputDeviceID : getSystemOutputDevice()
        guard deviceID != kAudioObjectUnknown else { return }

        var volume: Float32 = 0.5
        var size = UInt32(MemoryLayout<Float32>.size)

        var volumeAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        if AudioObjectGetPropertyData(deviceID, &volumeAddr, 0, nil, &size, &volume) == noErr {
            var mute: UInt32 = 0
            var muteSize = UInt32(MemoryLayout<UInt32>.size)
            var muteAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            let muteStatus = AudioObjectGetPropertyData(deviceID, &muteAddr, 0, nil, &muteSize, &mute)
            let muted = (muteStatus == noErr && mute == 1)

            showHUD(kind: "volume", value: Float(volume), muted: muted)
        }
    }

    private func getSystemOutputDevice() -> AudioObjectID {
        var deviceID: AudioObjectID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID)
        return deviceID
    }

    public func setVolume(_ value: Float) {
        let clamped = max(0.0, min(1.0, value))
        let deviceID = defaultOutputDeviceID != kAudioObjectUnknown ? defaultOutputDeviceID : getSystemOutputDevice()
        guard deviceID != kAudioObjectUnknown else {
            showHUD(kind: "volume", value: clamped, muted: clamped == 0)
            return
        }

        var vol = Float32(clamped)
        let size = UInt32(MemoryLayout<Float32>.size)
        var volumeAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(deviceID, &volumeAddr, 0, nil, size, &vol)
        showHUD(kind: "volume", value: clamped, muted: clamped == 0)
    }

    // MARK: - Display Brightness

    public func getBrightness() -> Float {
        if let getBrightness = getBrightnessPtr {
            var b: Float = 0.5
            let mainDisplay = CGMainDisplayID()
            if getBrightness(mainDisplay, &b) == 0 {
                return b
            }
        }
        return currentValue
    }

    public func setBrightness(_ value: Float) {
        let clamped = max(0.0, min(1.0, value))
        if let setBrightness = setBrightnessPtr {
            let mainDisplay = CGMainDisplayID()
            _ = setBrightness(mainDisplay, clamped)
        }
        showHUD(kind: "brightness", value: clamped, muted: false)
    }

    // MARK: - HUD Display

    public func showHUD(kind: String, value: Float, muted: Bool) {
        self.activeKind = kind
        self.currentValue = max(0.0, min(1.0, value))
        self.isMuted = muted
        self.isHUDVisible = true
        self.lastChangeTime = Date().timeIntervalSince1970

        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: visibleDuration, repeats: false) { [weak self] _ in
            self?.isHUDVisible = false
        }
    }

    public func getHUDJson() -> String {
        let kindEscaped = activeKind.replacingOccurrences(of: "\"", with: "\\\"")
        let title: String
        switch activeKind {
        case "volume":
            title = isMuted ? "Muted" : "\(Int(currentValue * 100))%"
        case "brightness":
            title = "\(Int(currentValue * 100))%"
        case "mic":
            title = isMuted ? "Mic Muted" : "Mic On"
        default:
            title = "\(Int(currentValue * 100))%"
        }

        return """
        {"visible":\(isHUDVisible),"kind":"\(kindEscaped)","value":\(currentValue),"isMuted":\(isMuted),"title":"\(title)"}
        """
    }
}
