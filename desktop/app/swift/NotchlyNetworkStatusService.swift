import Foundation
import Network
import CoreWLAN
import Darwin

@objc public final class NotchlyNetworkStatusService: NSObject, @unchecked Sendable {
    public static let shared = NotchlyNetworkStatusService()

    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.maclink.network-status-monitor", qos: .utility)
    private let lock = NSLock()

    private var isConnected: Bool = true
    private var isWiFi: Bool = true
    private var isHotspot: Bool = false
    private var currentSSID: String = "Wi-Fi"
    private var signalBars: Int = 3
    private var toastActive: Bool = false
    private var toastMessage: String = ""
    private var toastTimer: Timer?

    // Network throughput telemetry
    private var lastRxBytes: UInt64 = 0
    private var lastTxBytes: UInt64 = 0
    private var lastSampleTime: TimeInterval = 0
    private var downSpeedBps: Double = 0
    private var upSpeedBps: Double = 0
    private var speedTimer: DispatchSourceTimer?

    private override init() {
        super.init()
    }

    private func updateNetworkThroughput() {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return }
        defer { freeifaddrs(ifaddr) }

        var totalRx: UInt64 = 0
        var totalTx: UInt64 = 0

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let p = ptr {
            let flags = Int32(p.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) == IFF_UP
            let isRunning = (flags & IFF_RUNNING) == IFF_RUNNING
            let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK

            if isUp && isRunning && !isLoopback && p.pointee.ifa_addr != nil {
                if p.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                    if let data = p.pointee.ifa_data {
                        let networkData = data.assumingMemoryBound(to: if_data.self)
                        totalRx += UInt64(networkData.pointee.ifi_ibytes)
                        totalTx += UInt64(networkData.pointee.ifi_obytes)
                    }
                }
            }
            ptr = p.pointee.ifa_next
        }

        let now = Date().timeIntervalSince1970
        if lastSampleTime > 0 && now > lastSampleTime {
            let dt = now - lastSampleTime
            if totalRx >= lastRxBytes {
                downSpeedBps = Double(totalRx - lastRxBytes) / dt
            }
            if totalTx >= lastTxBytes {
                upSpeedBps = Double(totalTx - lastTxBytes) / dt
            }
        }
        lastRxBytes = totalRx
        lastTxBytes = totalTx
        lastSampleTime = now
    }

    private func formatSpeed(_ bytesPerSec: Double) -> String {
        if bytesPerSec < 1024 {
            return "\(Int(bytesPerSec)) B/s"
        } else if bytesPerSec < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSec / 1024.0)
        } else {
            return String(format: "%.1f MB/s", bytesPerSec / (1024.0 * 1024.0))
        }
    }

    private func formatSpeedCompact(_ bytesPerSec: Double) -> String {
        if bytesPerSec < 1024 {
            return "\(Int(bytesPerSec))B"
        } else if bytesPerSec < 1024 * 1024 {
            return "\(Int(round(bytesPerSec / 1024.0)))K"
        } else {
            return String(format: "%.1fM", bytesPerSec / (1024.0 * 1024.0))
        }
    }

    public func start() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.lock.lock()
            defer { self.lock.unlock() }

            let connected = (path.status == .satisfied)
            let usesWiFi = path.usesInterfaceType(.wifi)
            let isExpensive = path.isExpensive // cellular hotspot

            var ssid = "Wi-Fi"
            if usesWiFi {
                if let iface = CWWiFiClient.shared().interface() {
                    if let s = iface.ssid() {
                        ssid = s
                    }
                }
            } else if path.usesInterfaceType(.cellular) {
                ssid = "Cellular Hotspot"
            } else if path.usesInterfaceType(.wiredEthernet) {
                ssid = "Ethernet"
            }

            let wasConnected = self.isConnected
            let oldSSID = self.currentSSID

            self.isConnected = connected
            self.isWiFi = usesWiFi
            self.isHotspot = isExpensive
            self.currentSSID = ssid
            self.signalBars = connected ? 3 : 0

            // If connection state changed or new network joined, show transient notch toast
            if connected && (!wasConnected || (oldSSID != ssid && !oldSSID.isEmpty)) {
                let msg = isExpensive ? "Hotspot: \(ssid)" : "Connected to \(ssid)"
                self.triggerToastInternal(message: msg)
            } else if !connected && wasConnected {
                self.triggerToastInternal(message: "Wi-Fi Disconnected")
            }
        }
        pathMonitor.start(queue: monitorQueue)

        // Start throughput telemetry timer (every 1 second)
        let timer = DispatchSource.makeTimerSource(queue: monitorQueue)
        timer.schedule(deadline: .now(), repeating: 1.0)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            self.updateNetworkThroughput()
            self.lock.unlock()
        }
        timer.resume()
        self.speedTimer = timer
    }

    public func simulateNetworkEvent(_ event: String) {
        lock.lock()
        defer { lock.unlock() }

        switch event.lowercased() {
        case "connected", "wifi":
            isConnected = true
            isHotspot = false
            currentSSID = "Studio-5G"
            signalBars = 4
            triggerToastInternal(message: "Connected to Studio-5G")
        case "hotspot":
            isConnected = true
            isHotspot = true
            currentSSID = "iPhone Hotspot"
            signalBars = 3
            triggerToastInternal(message: "Hotspot: iPhone")
        case "disconnected", "offline":
            isConnected = false
            signalBars = 0
            triggerToastInternal(message: "Wi-Fi Disconnected")
        default:
            triggerToastInternal(message: "Network: \(event)")
        }
    }

    private func triggerToastInternal(message: String) {
        toastActive = true
        toastMessage = message
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.toastTimer?.invalidate()
            self.toastTimer = Timer.scheduledTimer(withTimeInterval: 3.2, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                self.lock.lock()
                self.toastActive = false
                self.lock.unlock()
            }
        }
    }

    public func getNetworkStatusJson() -> String {
        lock.lock()
        defer { lock.unlock() }

        let totalSpeedBps = downSpeedBps + upSpeedBps
        let downStr = formatSpeed(downSpeedBps)
        let upStr = formatSpeed(upSpeedBps)
        let combinedStr = formatSpeed(totalSpeedBps)
        let downCompact = formatSpeedCompact(downSpeedBps)
        let upCompact = formatSpeedCompact(upSpeedBps)
        let combinedCompact = formatSpeedCompact(totalSpeedBps)

        return """
        {
          "connected": \(isConnected),
          "isWiFi": \(isWiFi),
          "isHotspot": \(isHotspot),
          "ssid": "\(currentSSID)",
          "signalBars": \(signalBars),
          "toastActive": \(toastActive),
          "toastMessage": "\(toastMessage)",
          "downSpeedStr": "\(downStr)",
          "upSpeedStr": "\(upStr)",
          "combinedSpeedStr": "\(combinedStr)",
          "downCompact": "\(downCompact)",
          "upCompact": "\(upCompact)",
          "combinedCompact": "\(combinedCompact)",
          "downBytes": \(Int64(downSpeedBps)),
          "upBytes": \(Int64(upSpeedBps)),
          "totalBytes": \(Int64(totalSpeedBps))
        }
        """
    }
}
