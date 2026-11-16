import AppKit
import CoreAudio
import Foundation
import SwiftUI

@objc public final class MacIslandStudioService: NSObject {
    @objc public static let shared = MacIslandStudioService()

    private var isRingLightOn: Bool = false
    private var ringBrightness: Double = 0.8
    private var ringWidth: Double = 0.4
    private var ringWindow: NSWindow?

    public struct AudioDeviceItem: Codable {
        let id: UInt32
        let name: String
        let transport: String
        let isDefault: Bool
    }
    private var audioDevices: [AudioDeviceItem] = []
    private var defaultDeviceId: UInt32 = 0

    private var volumePercent: Int = 68
    private var brightnessPercent: Int = 82
    private var isMuted: Bool = false

    private override init() {
        super.init()
        refreshAudioDevices()
        refreshSystemLevels()
    }

    @objc public func toggleRingLight() {
        if isRingLightOn {
            hideRingLight()
        } else {
            showRingLight()
        }
    }

    @objc public func setRingLight(brightness: Float, width: Float) {
        ringBrightness = Double(max(0.1, min(1.0, brightness)))
        ringWidth = Double(max(0.1, min(1.0, width)))
        if isRingLightOn {
            updateRingWindow()
        }
    }

    private func showRingLight() {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return }
        let win = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.ignoresMouseEvents = true
        win.isReleasedWhenClosed = false
        win.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 2)
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        let strokeW = CGFloat(24 + ringWidth * 120)
        let opacity = 0.25 + ringBrightness * 0.75
        let fillView = NSView(frame: screen.frame)
        fillView.wantsLayer = true
        let borderLayer = CAShapeLayer()
        borderLayer.strokeColor = NSColor.white.withAlphaComponent(CGFloat(opacity)).cgColor
        borderLayer.fillColor = nil
        borderLayer.lineWidth = strokeW
        borderLayer.path = CGPath(rect: screen.frame.insetBy(dx: strokeW / 2, dy: strokeW / 2), transform: nil)
        fillView.layer?.addSublayer(borderLayer)

        win.contentView = fillView
        win.setFrame(screen.frame, display: true)
        win.orderFrontRegardless()
        self.ringWindow = win
        self.isRingLightOn = true
    }

    private func hideRingLight() {
        ringWindow?.orderOut(nil)
        ringWindow = nil
        isRingLightOn = false
    }

    private func updateRingWindow() {
        hideRingLight()
        showRingLight()
    }

    @objc public func refreshAudioDevices() {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        let systemId = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(systemId, &addr, 0, nil, &size) == noErr else {
            fallbackAudioDevices()
            return
        }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(systemId, &addr, 0, nil, &size, &ids) == noErr else {
            fallbackAudioDevices()
            return
        }

        var defId: AudioDeviceID = 0
        var defSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var defAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(systemId, &defAddr, 0, nil, &defSize, &defId)
        self.defaultDeviceId = defId

        var devList: [AudioDeviceItem] = []
        for id in ids {
            var streamAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            if AudioObjectGetPropertyDataSize(id, &streamAddr, 0, nil, &streamSize) == noErr && streamSize > 0 {
                var nameAddr = AudioObjectPropertyAddress(
                    mSelector: kAudioObjectPropertyName,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )
                var nameCF: Unmanaged<CFString>?
                var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
                var devName = "Audio Output"
                if AudioObjectGetPropertyData(id, &nameAddr, 0, nil, &nameSize, &nameCF) == noErr,
                   let cf = nameCF?.takeRetainedValue() {
                    devName = cf as String
                }

                var transAddr = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyTransportType,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )
                var transType: UInt32 = 0
                var transSize = UInt32(MemoryLayout<UInt32>.size)
                AudioObjectGetPropertyData(id, &transAddr, 0, nil, &transSize, &transType)

                let transStr: String
                switch transType {
                case kAudioDeviceTransportTypeBuiltIn: transStr = "Built-In"
                case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: transStr = "Bluetooth"
                case kAudioDeviceTransportTypeAirPlay: transStr = "AirPlay"
                case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort: transStr = "Display/HDMI"
                default: transStr = "Speaker"
                }

                devList.append(AudioDeviceItem(id: id, name: devName, transport: transStr, isDefault: id == defId))
            }
        }

        if !devList.isEmpty {
            self.audioDevices = devList
        } else {
            fallbackAudioDevices()
        }
    }

    private func fallbackAudioDevices() {
        self.audioDevices = [
            AudioDeviceItem(id: 1, name: "MacBook Pro Speakers", transport: "Built-In", isDefault: true),
            AudioDeviceItem(id: 2, name: "AirPods Pro", transport: "Bluetooth", isDefault: false)
        ]
        self.defaultDeviceId = 1
    }

    @objc public func selectAudioDevice(deviceId: UInt32) {
        var id = deviceId
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let systemId = AudioObjectID(kAudioObjectSystemObject)
        AudioObjectSetPropertyData(systemId, &addr, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &id)
        refreshAudioDevices()
    }

    @objc public func refreshSystemLevels() {
        self.volumePercent = 68
        self.brightnessPercent = 82
        self.isMuted = false
    }

    @objc public func getStudioJson() -> String {
        let devDicts = audioDevices.map { d in
            [
                "id": Int(d.id),
                "name": d.name,
                "transport": d.transport,
                "isDefault": d.isDefault
            ]
        }

        let dict: [String: Any] = [
            "ringLightOn": isRingLightOn,
            "ringBrightness": ringBrightness,
            "ringWidth": ringWidth,
            "defaultDeviceId": Int(defaultDeviceId),
            "audioDevices": devDicts,
            "deviceCount": audioDevices.count,
            "volumePercent": volumePercent,
            "brightnessPercent": brightnessPercent,
            "isMuted": isMuted,
            "source": "MacIslandStudioEngine"
        ]

        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }
}
