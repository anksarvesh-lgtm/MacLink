// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Window
import QtQuick.Shapes
import QtQuick.Layouts
import QtQuick.Controls
import app.maclink

// ============================================================================
// MacLink Dynamic Island & Live Telemetry Wings (Native Liquid Dynamo Engine)
// ============================================================================
// Exact 1:1 mathematical match to dynamo-mac (LiquidDynamo):
//   - Notched displays: LeftNotchDropShape & RightNotchDropShape anchored FLUSH
//     against the hardware notch walls (0px margin, seamless transparent seam).
//   - Left Wing: CPUTempGlowEdge with 6 independent sinusoidal flame tongues
//     oscillating via Canvas at 30 fps + additive hot bottom glow edge.
//   - Right Wing: RAMBottomBar with 2.5px continuous capsule track & dynamic glow.
//   - Collapsed Center: Transparent hardware notch activation zone with sneak peek
//     HUD, localized camera/mic privacy glow, and under-notch download progress.
//   - Expanded Island: DynamicIslandShape with concave top ears (rTop = 6.0)
//     blending into bezel, continuous squircle bottom chin (rBot = 14.0, 0.448
//     Apple Bezier weight), and 5-layer frosted obsidian liquid glass optical stack.
//   - Non-notched / external displays: Central 160×32px floating capsule with
//     camera dot flanked symmetrically by 84×32px floating capsules (8px gap).
// ============================================================================
Window {
    id: islandWin

    // Live Telemetry Heartbeat & Fallback Animation Driver
    property real mockCpuPercent: 24.0
    property real mockRamPercent: 68.0
    Timer {
        id: telemetryTickTimer
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            mockCpuPercent = Math.max(8.0, Math.min(85.0, mockCpuPercent + (Math.random() * 8.0 - 4.0)))
            mockRamPercent = Math.max(50.0, Math.min(82.0, mockRamPercent + (Math.random() * 2.0 - 1.0)))
            if (DynamoController && typeof DynamoController.refreshTelemetry === "function") {
                DynamoController.refreshTelemetry()
            }
        }
    }

    title: qsTr("MacLink Island")
    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
    color: "transparent"

    readonly property int availW: Screen.desktopAvailableWidth > 0 ? Screen.desktopAvailableWidth : 1920

    // Work area and screen positioning
    property var workArea: AppController.workArea()
    readonly property int workAreaKey: Screen.desktopAvailableWidth * 100000 + Screen.desktopAvailableHeight
    onWorkAreaKeyChanged: workArea = AppController.workArea()
    readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
    readonly property real areaX: workArea && workArea.width ? workArea.x / dpr : Screen.virtualX
    readonly property real areaY: workArea && workArea.height ? workArea.y / dpr : Screen.virtualY
    readonly property real areaW: workArea && workArea.width ? workArea.width / dpr : availW

    // ---- Active Media Tracking ----
    property string mediaDeviceId: ""
    property string mediaPlayerId: ""
    property string mediaApp: ""
    property string mediaTitle: ""
    property string mediaArtist: ""
    property string mediaArt: ""
    property bool mediaPlaying: false
    property bool mediaCanPlay: true
    property bool mediaCanPause: true
    property bool mediaCanNext: true
    property bool mediaCanPrev: true
    property real mediaDuration: 0
    property real mediaPosition: 0

    // ---- Active File Transfer Tracking ----
    property string activeTransferId: ""
    property string activeTransferTitle: ""
    property real activeTransferProgress: 0
    property real activeTransferRate: 0
    property bool activeTransferIncoming: false
    property bool transferJustFinished: false

    // ---- Transient Notification Toast ----
    property bool notificationToastActive: false
    property int lastNotificationCount: NotificationList.count
    Timer {
        id: notificationToastTimer
        interval: 4200
        repeat: false
        onTriggered: islandWin.notificationToastActive = false
    }
    Connections {
        target: NotificationList
        function onCountChanged() {
            const cur = NotificationList.count
            if (cur > islandWin.lastNotificationCount && Preferences.maclinkIslandNotifications) {
                islandWin.notificationToastActive = true
                notificationToastTimer.restart()
            } else if (cur === 0) {
                islandWin.notificationToastActive = false
            }
            islandWin.lastNotificationCount = cur
        }
    }

    Timer {
        id: transferDoneTimer
        interval: 3200
        repeat: false
        onTriggered: islandWin.transferJustFinished = false
    }

    property int lastActiveTransfers: TransferList.active
    onLastActiveTransfersChanged: {
        if (lastActiveTransfers === 0 && activeTransferTitle.length > 0) {
            transferJustFinished = true
            transferDoneTimer.restart()
        }
    }

    function recomputeMedia() {
        let best = null
        const count = mediaRepeater.count
        for (let i = 0; i < count; i++) {
            const item = mediaRepeater.itemAt(i)
            if (!item) continue
            if (item.deviceId === "local") continue
            if (item.playing) {
                if (!best || !best.playing) {
                    best = item
                }
            }
        }
        if (best) {
            mediaDeviceId = best.deviceId
            mediaPlayerId = best.playerId
            mediaApp = best.app
            mediaTitle = best.title
            mediaArtist = best.artist
            mediaArt = best.art
            mediaPlaying = best.playing
            mediaCanPlay = best.canPlay
            mediaCanPause = best.canPause
            mediaCanNext = best.canNext
            mediaCanPrev = best.canPrevious
            mediaDuration = best.duration
            mediaPosition = best.position
        } else if (Preferences.notchSystemMedia && sysMedia && sysMedia.hasTrack) {
            mediaDeviceId = "local_system"
            mediaPlayerId = sysMedia.player || "Music"
            mediaApp = sysMedia.player || "Music"
            mediaTitle = sysMedia.title || ""
            mediaArtist = sysMedia.artist || ""
            mediaArt = ""
            mediaPlaying = sysMedia.isPlaying
            mediaCanPlay = true
            mediaCanPause = true
            mediaCanNext = true
            mediaCanPrev = true
            mediaDuration = sysMedia.duration || 0
            mediaPosition = sysMedia.position || 0
        } else {
            mediaDeviceId = ""
            mediaPlayerId = ""
            mediaApp = ""
            mediaTitle = ""
            mediaArtist = ""
            mediaArt = ""
            mediaPlaying = false
        }
    }

    function recomputeTransfer() {
        let found = null
        const count = transferRepeater.count
        for (let i = 0; i < count; i++) {
            const item = transferRepeater.itemAt(i)
            if (!item) continue
            if (item.status === "running" || item.status === "waiting" || item.status === "requested") {
                found = item
                break
            }
        }
        if (found) {
            activeTransferId = found.transferId
            activeTransferTitle = found.title
            activeTransferProgress = Math.max(0, Math.min(1, found.progress || 0))
            activeTransferRate = found.rate || 0
            activeTransferIncoming = found.incoming
        } else if (!transferJustFinished) {
            activeTransferId = ""
            activeTransferTitle = ""
            activeTransferProgress = 0
            activeTransferRate = 0
        }
    }

    function formatRate(bytesPerSec) {
        const b = Number(bytesPerSec) || 0
        if (b <= 0) return ""
        if (b < 1024 * 1024)
            return Math.round(b / 1024) + " KB/s"
        return Qt.locale().toString(b / (1024 * 1024), "f", 1) + " MB/s"
    }

    readonly property var telemetry: {
        try { return JSON.parse(DynamoController.telemetryJson || "{}") } catch (e) { return {} }
    }
    readonly property var sysHud: {
        try { return JSON.parse(DynamoController.systemHudJson || "{}") } catch (e) { return {} }
    }
    readonly property var hudEvent: sysHud && sysHud.event ? sysHud.event : null
    readonly property bool hudActive: !!(sysHud && sysHud.visible && hudEvent)
    readonly property bool wingsActive: (Preferences.notchWingsEnabled !== undefined) ? Preferences.notchWingsEnabled : true
    readonly property bool hasPhysicalNotch: {
        if (telemetry && (telemetry.hasPhysicalNotch !== undefined))
            return !!telemetry.hasPhysicalNotch
        if (telemetry && telemetry.layout && (telemetry.layout.hasPhysicalNotch !== undefined))
            return !!telemetry.layout.hasPhysicalNotch
        return true
    }
    readonly property bool isNotchAttached: (Preferences.notchHardwareAttached !== undefined) ? (Preferences.notchHardwareAttached && hasPhysicalNotch) : hasPhysicalNotch
    readonly property bool isFullscreen: !!(telemetry && telemetry.isFullscreen)

    readonly property real centerNotchWidth: {
        if (telemetry && telemetry.layout && telemetry.layout.notchWidth > 50)
            return telemetry.layout.notchWidth
        return 179.0
    }
    readonly property real centerNotchHeight: {
        if (telemetry && telemetry.layout && telemetry.layout.notchHeight > 10)
            return telemetry.layout.notchHeight
        return 32.0
    }
    readonly property real detectedNotchMinX: (telemetry && telemetry.layout && telemetry.layout.notchMinX !== undefined && telemetry.layout.notchMinX > 0) ? telemetry.layout.notchMinX : 0.0
    readonly property real detectedNotchMaxX: (telemetry && telemetry.layout && telemetry.layout.notchMaxX !== undefined && telemetry.layout.notchMaxX > 0) ? telemetry.layout.notchMaxX : 0.0
    readonly property real detectedNotchCenterX: (detectedNotchMinX > 0 && centerNotchWidth > 0) ? (detectedNotchMinX + (centerNotchWidth / 2.0)) : (areaX + (areaW / 2.0))

    // Live Clock String for Menu Bar Anchor Status
    property string liveClockStr: Qt.formatTime(new Date(), "h:mm")
    Timer {
        id: liveClockTimer
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            islandWin.liveClockStr = Qt.formatTime(new Date(), "h:mm")
        }
    }

    // Media Playback Helpers
    function playPauseMedia() {
        if (islandWin.mediaDeviceId === "local_system") {
            if (DynamoController && typeof DynamoController.mediaPlayPause === "function") {
                DynamoController.mediaPlayPause()
            }
        } else if (islandWin.mediaDeviceId.length > 0 && islandWin.mediaPlayerId.length > 0) {
            MediaList.command(islandWin.mediaDeviceId, islandWin.mediaPlayerId, islandWin.mediaPlaying ? "pause" : "play", 0)
        } else if (DynamoController && typeof DynamoController.mediaPlayPause === "function") {
            DynamoController.mediaPlayPause()
        }
    }
    function prevMedia() {
        if (islandWin.mediaDeviceId === "local_system") {
            if (DynamoController && typeof DynamoController.mediaPrevious === "function") {
                DynamoController.mediaPrevious()
            }
        } else if (islandWin.mediaDeviceId.length > 0 && islandWin.mediaPlayerId.length > 0) {
            MediaList.command(islandWin.mediaDeviceId, islandWin.mediaPlayerId, "previous", 0)
        } else if (DynamoController && typeof DynamoController.mediaPrevious === "function") {
            DynamoController.mediaPrevious()
        }
    }
    function nextMedia() {
        if (islandWin.mediaDeviceId === "local_system") {
            if (DynamoController && typeof DynamoController.mediaNext === "function") {
                DynamoController.mediaNext()
            }
        } else if (islandWin.mediaDeviceId.length > 0 && islandWin.mediaPlayerId.length > 0) {
            MediaList.command(islandWin.mediaDeviceId, islandWin.mediaPlayerId, "next", 0)
        } else if (DynamoController && typeof DynamoController.mediaNext === "function") {
            DynamoController.mediaNext()
        }
    }

    // 3-Bar Audio Visualizer Oscillators
    property real visualizerBar1: 6.0
    property real visualizerBar2: 12.0
    property real visualizerBar3: 8.0
    Timer {
        id: visualizerTimer
        interval: 100
        repeat: true
        running: islandWin.visible && (islandWin.mediaPlaying || islandWin.localMediaPlaying) && !Theme.reduceMotion
        onTriggered: {
            visualizerBar1 = Math.max(3.0, Math.min(14.0, Math.random() * 11.0 + 3.0))
            visualizerBar2 = Math.max(4.0, Math.min(16.0, Math.random() * 12.0 + 4.0))
            visualizerBar3 = Math.max(3.0, Math.min(14.0, Math.random() * 11.0 + 3.0))
        }
    }

    // Dynamic Independent Liquid Wing Dimensions (Menu Bar Origin, Content Auto-Resizing)
    readonly property string activeLeftWingWidget: (Preferences.notchLeftWingContent && Preferences.notchLeftWingContent.length > 0)
        ? Preferences.notchLeftWingContent : "cpu_temp_flame"
    readonly property string activeRightWingWidget: (Preferences.notchRightWingContent && Preferences.notchRightWingContent.length > 0)
        ? Preferences.notchRightWingContent : "ram_bar"

    // Multi-Stop Thermal & RAM Color Scales:
    // Fireflame: 35°C is Green (#22C55E), 70°C is Blood Red (#DC2626)
    function getCpuThermalColor(tempC) {
        const minT = 35.0
        const maxT = 70.0
        const t = Math.max(minT, Math.min(maxT, (tempC !== undefined && tempC > 0) ? Number(tempC) : 48.0))
        const f = (t - minT) / (maxT - minT) // 0.0 at 35°C, 1.0 at 70°C

        if (f <= 0.35) {
            const k = f / 0.35
            const r = 34 + k * (234 - 34)
            const g = 197 + k * (179 - 197)
            const b = 94 + k * (8 - 94)
            return Qt.rgba(r / 255.0, g / 255.0, b / 255.0, 1.0)
        } else if (f <= 0.70) {
            const k = (f - 0.35) / (0.70 - 0.35)
            const r = 234 + k * (249 - 234)
            const g = 179 + k * (115 - 179)
            const b = 8 + k * (22 - 8)
            return Qt.rgba(r / 255.0, g / 255.0, b / 255.0, 1.0)
        } else {
            const k = (f - 0.70) / (1.00 - 0.70)
            const r = 249 + k * (220 - 249)
            const g = 115 + k * (38 - 115)
            const b = 22 + k * (38 - 22)
            return Qt.rgba(r / 255.0, g / 255.0, b / 255.0, 1.0)
        }
    }

    // RAM Bar: 35% is Green (#22C55E), 90% is Blood Red (#DC2626)
    function getRamBarColor(ramPct) {
        const minP = 35.0
        const maxP = 90.0
        const p = Math.max(minP, Math.min(maxP, (ramPct !== undefined && ramPct > 0) ? Number(ramPct) : 55.0))
        const f = (p - minP) / (maxP - minP) // 0.0 at 35%, 1.0 at 90%

        if (f <= 0.35) {
            const k = f / 0.35
            const r = 34 + k * (234 - 34)
            const g = 197 + k * (179 - 197)
            const b = 94 + k * (8 - 94)
            return Qt.rgba(r / 255.0, g / 255.0, b / 255.0, 1.0)
        } else if (f <= 0.70) {
            const k = (f - 0.35) / (0.70 - 0.35)
            const r = 234 + k * (249 - 234)
            const g = 179 + k * (115 - 179)
            const b = 8 + k * (22 - 8)
            return Qt.rgba(r / 255.0, g / 255.0, b / 255.0, 1.0)
        } else {
            const k = (f - 0.70) / (1.00 - 0.70)
            const r = 249 + k * (220 - 249)
            const g = 115 + k * (38 - 115)
            const b = 22 + k * (38 - 22)
            return Qt.rgba(r / 255.0, g / 255.0, b / 255.0, 1.0)
        }
    }

    // Content-Driven Independent Wing Sizing (Zero Wasted Space, Independent Left/Right)
    readonly property real leftWingTargetWidth: {
        if (!wingsActive || expanded || activeLeftWingWidget === "none") return 0.0
        if (activeLeftWingWidget === "cpu_temp_flame") {
            const toolsW = (islandWin.leftHovered && leftToolsRow) ? (leftToolsRow.implicitWidth + 8.0) : 0.0
            const flareW = 36.0
            return Math.round(flareW + toolsW)
        }
        const naturalW = (leftWingContentRow ? leftWingContentRow.implicitWidth : 18.0) + (isNotchAttached ? 14.0 : 12.0)
        return Math.max(26.0, Math.min(320.0, Math.round(naturalW)))
    }

    readonly property real rightWingTargetWidth: {
        if (!wingsActive || expanded || activeRightWingWidget === "none") return 0.0
        if (activeRightWingWidget === "ram_bar") {
            const toolsW = (islandWin.rightHovered && rightToolsRow) ? (rightToolsRow.implicitWidth + 8.0) : 0.0
            const barW = 36.0
            return Math.round(barW + toolsW)
        }
        const naturalW = (rightWingContentRow ? rightWingContentRow.implicitWidth : 18.0) + (isNotchAttached ? 14.0 : 12.0)
        return Math.max(26.0, Math.min(320.0, Math.round(naturalW)))
    }

    property real leftWingWidth: leftWingTargetWidth
    property real rightWingWidth: rightWingTargetWidth

    Behavior on leftWingWidth {
        enabled: !Theme.reduceMotion
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }
    Behavior on rightWingWidth {
        enabled: !Theme.reduceMotion
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    // Boring Notch Extensions (Reverse engineered from boring.notch)
    readonly property var sysMedia: {
        try { return JSON.parse(DynamoController.systemMediaJson || "{}") } catch (e) { return {} }
    }
    readonly property var sysBattery: {
        try { return JSON.parse(DynamoController.batteryJson || "{}") } catch (e) { return {} }
    }
    readonly property var sysCal: {
        try { return JSON.parse(DynamoController.calendarJson || "{}") } catch (e) { return {} }
    }
    readonly property bool localMediaPlaying: Preferences.notchSystemMedia && sysMedia && sysMedia.hasTrack && sysMedia.isPlaying

    // Coucou Extensions (Reverse engineered from coucou)
    readonly property var mochiState: {
        try { return JSON.parse(DynamoController.mochiJson || "{}") } catch (e) { return {} }
    }
    readonly property var coucoudoro: {
        try { return JSON.parse(DynamoController.coucoudoroJson || "{}") } catch (e) { return {} }
    }
    readonly property var agentHook: {
        try { return JSON.parse(DynamoController.agentHookJson || "{}") } catch (e) { return {} }
    }
    readonly property var agentTasks: {
        try { return JSON.parse(DynamoController.agentTasksJson || "{}") } catch (e) { return {} }
    }
    readonly property var agentQuestion: {
        try { return JSON.parse(DynamoController.agentQuestionJson || "{}") } catch (e) { return {} }
    }
    readonly property var quickShare: {
        try { return JSON.parse(DynamoController.quickshareJson || "{}") } catch (e) { return {} }
    }
    readonly property var atollHud: {
        try { return JSON.parse(DynamoController.atollHudJson || "{}") } catch (e) { return {} }
    }
    readonly property var launcherResults: {
        try { return JSON.parse(DynamoController.launcherResultsJson || "[]") } catch (e) { return [] }
    }
    readonly property var downloadsData: {
        try { return JSON.parse(DynamoController.downloadsJson || "{}") } catch (e) { return {} }
    }
    readonly property var privacySensors: {
        try { return JSON.parse(DynamoController.privacySensorsJson || "{}") } catch (e) { return {} }
    }
    readonly property var ledgeAnnouncement: {
        try { return JSON.parse(DynamoController.ledgeAnnouncementJson || "{}") } catch (e) { return {} }
    }
    readonly property var teleprompterData: {
        try { return JSON.parse(DynamoController.teleprompterJson || "{}") } catch (e) { return {} }
    }
    readonly property var emojiResults: {
        try { return JSON.parse(DynamoController.emojiResultsJson || "[]") } catch (e) { return [] }
    }
    readonly property var aiUsage: {
        try { return JSON.parse(DynamoController.aiUsageJson || "{}") } catch (e) { return {} }
    }
    readonly property var runningTerminals: {
        try { return JSON.parse(DynamoController.terminalsJson || "{}") } catch (e) { return {} }
    }
    readonly property var networkStatus: {
        try { return JSON.parse(DynamoController.networkStatusJson || "{}") } catch (e) { return {} }
    }
    readonly property var quietnotchHud: {
        try { return JSON.parse(DynamoController.quietnotchHudJson || "{}") } catch (e) { return {} }
    }
    readonly property var quietnotchNotification: {
        try { return JSON.parse(DynamoController.quietnotchNotificationJson || "{}") } catch (e) { return {} }
    }
    readonly property var clipboardHistory: {
        try { return JSON.parse(DynamoController.clipboardHistoryJson || "[]") } catch (e) { return [] }
    }
    readonly property var fanTelemetry: {
        try { return JSON.parse(DynamoController.fanTelemetryJson || "{}") } catch (e) { return {} }
    }
    readonly property var ghnotchResult: {
        try { return JSON.parse(DynamoController.ghnotchResultJson || "{}") } catch (e) { return {} }
    }
    readonly property var isleFinance: {
        try { return JSON.parse(DynamoController.isleFinanceJson || "{}") } catch (e) { return {} }
    }
    readonly property var macislandBattery: {
        try { return JSON.parse(DynamoController.macislandBatteryJson || "{}") } catch (e) { return {} }
    }
    readonly property var macwakeThermal: {
        try { return JSON.parse(DynamoController.macwakeThermalJson || "{}") } catch (e) { return {} }
    }
    readonly property var macwakeCleaning: {
        try { return JSON.parse(DynamoController.macwakeCleaningJson || "{}") } catch (e) { return {} }
    }
    readonly property var piislandSessions: {
        try { return JSON.parse(DynamoController.piislandSessionsJson || "{}") } catch (e) { return {} }
    }
    readonly property var pookifyAnim: {
        try { return JSON.parse(DynamoController.pookifyAnimationJson || "{}") } catch (e) { return {} }
    }
    readonly property var screenOcr: {
        try { return JSON.parse(DynamoController.screenOcrJson || "{}") } catch (e) { return {} }
    }
    readonly property var topnotchFocus: {
        try { return JSON.parse(DynamoController.topnotchFocusJson || "{}") } catch (e) { return {} }
    }
    readonly property var macislandStudio: {
        try { return JSON.parse(DynamoController.macislandStudioJson || "{}") } catch (e) { return {} }
    }

    Connections {
        target: DynamoController
        function onAgentHookJsonChanged() {
            if (Preferences.notchSynthAudioEnabled && islandWin.agentHook && islandWin.agentHook.approvalPrompt) {
                DynamoController.playSynthSound("needs_approval")
            }
        }
        function onAgentTasksJsonChanged() {
            if (Preferences.notchSynthAudioEnabled && islandWin.agentTasks && islandWin.agentTasks.isAllCompleted) {
                DynamoController.playSynthSound("session_complete")
            }
        }
    }

    readonly property bool hasMediaCandidate: (mediaPlaying && mediaDeviceId !== "local" && mediaTitle.length > 0) || localMediaPlaying
    readonly property string mode: {
        if (Preferences.maclinkIslandCalls && PhoneCall.active) return "call"
        if (Preferences.maclinkIslandTransfers && (TransferList.active > 0 || transferJustFinished)) return "transfer"
        if (Preferences.notchDownloadsHud && downloadsData && downloadsData.hasActiveDownloads) return "download"
        if (Preferences.maclinkIslandMedia && hasMediaCandidate) return "media"
        if (Preferences.maclinkIslandNotifications && notificationToastActive && NotificationList.count > 0) return "notification"
        if (Preferences.maclinkIslandTransfers && TransferList.waitingCount > 0) return "waiting"
        if (hudActive) return "hud"
        return "idle"
    }

    function updateDragDetector() {
        if (Preferences.notchDragToShelf && DynamoController && typeof DynamoController.startNotchDragDetector === "function") {
            DynamoController.startNotchDragDetector(islandWin.detectedNotchMinX, islandWin.detectedNotchMaxX, islandWin.centerNotchHeight)
        }
    }
    onDetectedNotchMinXChanged: updateDragDetector()
    onDetectedNotchMaxXChanged: updateDragDetector()
    onCenterNotchHeightChanged: updateDragDetector()

    property bool lastCharging: false
    Connections {
        target: DynamoController
        function onBatteryJsonChanged() {
            if (Preferences.notchBatteryHud && sysBattery) {
                if (sysBattery.newlyConnected || (!islandWin.lastCharging && sysBattery.isCharging)) {
                    chargingPulseTimer.restart()
                    chargingPulseAnim.restart()
                }
                islandWin.lastCharging = sysBattery.isCharging
            }
        }
        function onSystemMediaJsonChanged() {
            recomputeMedia()
        }
        function onAgentHookJsonChanged() {
            if (Preferences.notchAgentHooksEnabled && islandWin.agentHook && islandWin.agentHook.hasApproval) {
                islandWin.userPinnedOpen = true
                islandWin.expanded = true
            }
        }
        function onAgentQuestionJsonChanged() {
            if (Preferences.notchAgentHooksEnabled && islandWin.agentQuestion && islandWin.agentQuestion.hasQuestion) {
                islandWin.userPinnedOpen = true
                islandWin.expanded = true
            }
        }
        function onQuickshareJsonChanged() {
            if (Preferences.notchQuickshareEnabled && islandWin.quickShare && islandWin.quickShare.hasRequest) {
                islandWin.userPinnedOpen = true
                islandWin.expanded = true
            }
        }
    }

    readonly property bool hasActivity: (mode !== "idle") || wingsActive
    visible: Preferences.maclinkIsland && (!Preferences.notchAutoHideFullscreen || !isFullscreen)

    property string activeTab: "home"
    onModeChanged: {
        if (mode === "call" || mode === "media" || mode === "transfer") {
            activeTab = mode
        }
    }

    onVisibleChanged: {
        console.warn("=== IslandWindow visibleChanged:", visible, "maclinkIsland:", Preferences.maclinkIsland, "hasActivity:", hasActivity, "wingsActive:", wingsActive, "mode:", mode)
        if (visible) {
            Qt.callLater(() => {
                AppController.styleShelfWindow()
                syncNativeWindow()
            })
            if (!Theme.reduceMotion)
                dropInAnim.restart()
        }
    }

    Component.onCompleted: {
        console.warn("=== IslandWindow Component.onCompleted, visible:", visible, "maclinkIsland:", Preferences.maclinkIsland, "hasActivity:", hasActivity, "wingsActive:", wingsActive, "mode:", mode)
        Qt.callLater(() => {
            recomputeMedia()
            recomputeTransfer()
            updateDragDetector()
            AppController.styleShelfWindow()
            syncNativeWindow()
        })
    }

    Connections {
        target: Preferences
        function onMaclinkIslandChanged() {
            if (Preferences.maclinkIsland) Qt.callLater(() => AppController.styleShelfWindow())
        }
    }

    property bool notchHovered: false
    property bool expHovered: false
    property bool floatingHovered: false
    property bool leftHovered: false
    property bool rightHovered: false
    property bool userPinnedOpen: false
    property bool isHoverExpanded: false

    function checkHoverState() {
        const inNotchOrWings = notchHovered || floatingHovered || leftHovered || rightHovered
        if (expanded) {
            if (expHovered || inNotchOrWings) {
                autoCollapseTimer.stop()
            } else {
                autoCollapseTimer.restart()
            }
        } else {
            if (inNotchOrWings) {
                autoCollapseTimer.stop()
                isHoverExpanded = true
            } else {
                autoCollapseTimer.restart()
            }
        }
    }

    onNotchHoveredChanged: checkHoverState()
    onExpHoveredChanged: checkHoverState()
    onFloatingHoveredChanged: checkHoverState()
    onLeftHoveredChanged: checkHoverState()
    onRightHoveredChanged: checkHoverState()

    onExpandedChanged: {
        if (!expanded) {
            userPinnedOpen = false
            isHoverExpanded = false
            expHovered = false
        } else {
            if (DynamoController && typeof DynamoController.refreshTelemetry === "function") {
                DynamoController.refreshTelemetry()
            }
        }
    }

    onUserPinnedOpenChanged: {
        if (DynamoController.islandExpanded !== userPinnedOpen) {
            DynamoController.islandExpanded = userPinnedOpen
        }
    }

    Connections {
        target: DynamoController
        function onIslandExpandedChanged() {
            islandWin.isHoverExpanded = DynamoController.islandExpanded
            if (!DynamoController.islandExpanded) {
                islandWin.userPinnedOpen = false
                islandWin.expHovered = false
                islandWin.notchHovered = false
                islandWin.floatingHovered = false
                islandWin.leftHovered = false
                islandWin.rightHovered = false
            }
        }
    }

    Timer {
        id: autoCollapseTimer
        interval: 200
        repeat: false
        onTriggered: {
            if (!PhoneCall.active) {
                islandWin.isHoverExpanded = false
                islandWin.userPinnedOpen = false
                islandWin.notchHovered = false
                islandWin.floatingHovered = false
                islandWin.leftHovered = false
                islandWin.rightHovered = false
                islandWin.expHovered = false
                if (DynamoController) DynamoController.islandExpanded = false
            }
        }
    }

    readonly property bool expanded: userPinnedOpen
        || isHoverExpanded
        || DynamoController.islandExpanded
        || (Preferences.maclinkIslandCalls && PhoneCall.active && PhoneCall.ringing)

    readonly property real maxWingW: wingsActive ? Math.max(leftWingWidth, rightWingWidth) : 0.0

    readonly property real collapsedW: {
        if (isNotchAttached) {
            return centerNotchWidth + (wingsActive ? (2.0 * maxWingW) : 0.0)
        } else {
            return 160.0 + (wingsActive ? (2.0 * (maxWingW + 8.0)) : 0.0)
        }
    }

    readonly property real targetW: expanded ? Math.max(680.0, Math.min(840.0, areaW - 32.0)) : collapsedW
    readonly property real targetH: {
        if (expanded) {
            if (activeTab === "home") return isNotchAttached ? 244.0 : 260.0
            if (activeTab === "teleprompter" || activeTab === "emojiPicker" || activeTab === "launcher" || activeTab === "clipboard") return isNotchAttached ? 244.0 : 260.0
            return (mode === "call" || mode === "media") ? 180.0 : 130.0
        }
        if (Preferences.notchAnnouncementsEnabled && ledgeAnnouncement && ledgeAnnouncement.active) {
            return (isNotchAttached ? centerNotchHeight : 34.0) + 26.0
        }
        if (Preferences.notchQuietNotificationsEnabled && quietnotchNotification && quietnotchNotification.hasNotification) {
            return (isNotchAttached ? centerNotchHeight : 34.0) + 40.0
        }
        return (isNotchAttached ? centerNotchHeight : 34.0) + 4.0
    }

    readonly property real screenCenterX: {
        return Screen.virtualX + (Screen.width / 2.0)
    }

    width: targetW
    height: targetH
    x: Math.round(screenCenterX - (width / 2.0))
    y: Screen.virtualY

    Behavior on width {
        enabled: !Theme.reduceMotion
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }
    Behavior on height {
        enabled: !Theme.reduceMotion
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }
    Behavior on x {
        enabled: !Theme.reduceMotion
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    function syncNativeWindow() {
        if (DynamoController && typeof DynamoController.positionIslandWindow === "function") {
            DynamoController.positionIslandWindow(x, width, height)
        }
        if (DynamoController && typeof DynamoController.updateNotchGestureBounds === "function") {
            DynamoController.updateNotchGestureBounds(x, y, width, height)
        }
    }
    onXChanged: syncNativeWindow()
    onYChanged: syncNativeWindow()
    onWidthChanged: syncNativeWindow()
    onHeightChanged: syncNativeWindow()

    readonly property string primaryLabel: {
        if (mode === "call")
            return PhoneCall.caller.length > 0 ? PhoneCall.caller : qsTr("Phone call")
        if (mode === "transfer") {
            if (transferJustFinished && TransferList.active === 0)
                return qsTr("Transfer complete")
            return activeTransferTitle.length > 0
                ? activeTransferTitle
                : qsTr("Transferring %1 file(s)…").arg(TransferList.active)
        }
        if (mode === "download") {
            const firstDl = (downloadsData && downloadsData.downloads && downloadsData.downloads.length > 0) ? downloadsData.downloads[0] : null
            return firstDl ? firstDl.filename : qsTr("Downloading file…")
        }
        if (mode === "media")
            return mediaTitle.length > 0 ? mediaTitle : (mediaApp.length > 0 ? mediaApp : qsTr("Now playing"))
        if (mode === "notification")
            return qsTr("%1 phone notification(s)").arg(NotificationList.count)
        if (mode === "waiting")
            return qsTr("%1 waiting").arg(TransferList.waitingCount)
        if (mode === "hud") {
            const kind = hudEvent ? hudEvent.kind : ""
            const pct = hudEvent && hudEvent.percent !== undefined ? hudEvent.percent : 0
            if (kind === "brightness") return qsTr("Brightness: %1%").arg(pct)
            if (kind === "keyboard_backlight") return qsTr("Keyboard: %1%").arg(pct)
            if (kind === "magsafe_connected") return qsTr("MagSafe Connected")
            if (kind === "low_battery") return qsTr("Low Battery (%1%)").arg(pct)
            if (kind === "volume") return hudEvent && hudEvent.muted ? qsTr("Muted") : qsTr("Volume: %1%").arg(pct)
            return qsTr("System HUD")
        }
        return DeviceList.count > 0
            ? qsTr("MacLink Island · %1").arg(DeviceList.deviceNameAt(0))
            : qsTr("MacLink Island · Ready")
    }

    readonly property string secondaryLabel: {
        if (mode === "call") {
            if (PhoneCall.ringing) return qsTr("Incoming call")
            if (PhoneCall.held) return qsTr("On hold")
            return PhoneCall.number.length > 0 ? PhoneCall.number : qsTr("Call in progress")
        }
        if (mode === "transfer") {
            if (transferJustFinished && TransferList.active === 0)
                return activeTransferTitle
            const pct = Math.round(activeTransferProgress * 100) + "%"
            const spd = formatRate(activeTransferRate)
            const base = spd.length > 0 ? (pct + " · " + spd) : pct
            return TransferList.waitingCount > 0
                ? (base + " · " + qsTr("%1 waiting").arg(TransferList.waitingCount))
                : base
        }
        if (mode === "download") {
            const firstDl = (downloadsData && downloadsData.downloads && downloadsData.downloads.length > 0) ? downloadsData.downloads[0] : null
            if (firstDl) {
                return qsTr("%1% • %2 MB/s • %3 MB of %4 MB").arg(firstDl.percent).arg(firstDl.speedMBs).arg(firstDl.completedMB).arg(firstDl.totalMB)
            }
            return qsTr("In progress…")
        }
        if (mode === "media") {
            const src = mediaDeviceId === "local" ? qsTr("This PC") : qsTr("Phone")
            const base = mediaArtist.length > 0
                ? (mediaArtist + " · " + src)
                : (mediaApp.length > 0 ? (mediaApp + " · " + src) : src)
            return TransferList.waitingCount > 0
                ? (base + " · " + qsTr("%1 waiting").arg(TransferList.waitingCount))
                : base
        }
        if (mode === "notification")
            return qsTr("Click to view in MacLink")
        if (mode === "waiting") {
            return DeviceList.count > 0
                ? qsTr("Will send when %1 is back").arg(DeviceList.deviceNameAt(0))
                : qsTr("Will send when connected")
        }
        if (mode === "hud") {
            const kind = hudEvent ? hudEvent.kind : ""
            if (kind === "volume") return qsTr("Audio Output")
            if (kind === "brightness") return qsTr("Built-in Display")
            if (kind === "magsafe_connected") return hudEvent && hudEvent.watts ? qsTr("%1W Fast Charging").arg(Math.round(hudEvent.watts)) : qsTr("Power Adapter")
            if (kind === "low_battery") return qsTr("Connect charger soon")
            return qsTr("System Controls")
        }
        return qsTr("Live calls, transfers & media")
    }

    Item {
        id: root
        anchors.fill: parent

        // Repeaters for dynamic updates
        Repeater {
            id: mediaRepeater
            model: MediaList
            onItemAdded: islandWin.recomputeMedia()
            onItemRemoved: islandWin.recomputeMedia()
            delegate: Item {
                required property int index
                required property string deviceId
                required property string playerId
                required property string app
                required property string title
                required property string artist
                required property string art
                required property bool playing
                required property bool canPlay
                required property bool canPause
                required property bool canNext
                required property bool canPrevious
                required property real duration
                required property real position
                visible: false
                onPlayingChanged: islandWin.recomputeMedia()
                onTitleChanged: islandWin.recomputeMedia()
                onArtistChanged: islandWin.recomputeMedia()
                onArtChanged: islandWin.recomputeMedia()
                onDeviceIdChanged: islandWin.recomputeMedia()
            }
        }

        Repeater {
            id: transferRepeater
            model: TransferList
            onItemAdded: islandWin.recomputeTransfer()
            onItemRemoved: islandWin.recomputeTransfer()
            delegate: Item {
                required property int index
                required property string transferId
                required property string title
                required property real progress
                required property real rate
                required property bool incoming
                required property string status
                visible: false
                onStatusChanged: islandWin.recomputeTransfer()
                onProgressChanged: islandWin.recomputeTransfer()
                onRateChanged: islandWin.recomputeTransfer()
                onTitleChanged: islandWin.recomputeTransfer()
            }
        }

        transform: Translate { id: dropSlide; y: 0 }
        NumberAnimation {
            id: dropInAnim
            target: dropSlide
            property: "y"
            from: 0
            to: 0
            duration: 100
        }

        // ====================================================================
        // 1. HARDWARE NOTCH CENTER ANCHOR ZONE (Collapsed Hardware Notch)
        // ====================================================================
        Item {
            id: centerNotchAnchor
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: islandWin.centerNotchWidth
            height: islandWin.centerNotchHeight
            visible: islandWin.isNotchAttached && !islandWin.expanded
            onVisibleChanged: if (!visible && !islandWin.expanded) islandWin.notchHovered = false
            z: 1

            // 1. Activation surface overlay (0.02 alpha triggers macOS hit-test while perfectly invisible over physical notch)
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.02)
            }

            MouseArea {
                id: notchMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                z: 100
                onEntered: {
                    islandWin.notchHovered = true
                    islandWin.isHoverExpanded = true
                }
                onExited: islandWin.notchHovered = false
                onClicked: {
                    islandWin.userPinnedOpen = !islandWin.userPinnedOpen
                    if (islandWin.userPinnedOpen) autoCollapseTimer.restart()
                }
            }

            HoverHandler {
                id: notchHoverHandler
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onHoveredChanged: {
                    islandWin.notchHovered = hovered
                    if (hovered) {
                        islandWin.isHoverExpanded = true
                    }
                }
            }

            // 2. Hardware Privacy Indicator Glow Dot (Camera = Green, Mic = Amber)
            Rectangle {
                id: hardwarePrivacyDot
                width: 6; height: 6; radius: 3
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                visible: !!(DynamoController.privacyGuardJson && (JSON.parse(DynamoController.privacyGuardJson || "{}").cameraActive || JSON.parse(DynamoController.privacyGuardJson || "{}").micActive))
                color: (DynamoController.privacyGuardJson && JSON.parse(DynamoController.privacyGuardJson || "{}").cameraActive) ? "#22C55E" : "#F59E0B"
                Rectangle {
                    anchors.centerIn: parent
                    width: 12; height: 12; radius: 6
                    color: parent.color
                    opacity: 0.35
                    z: -1
                }
            }

            // 3. Powerload Under-Notch Download / Transfer Progress Bar
            Rectangle {
                id: underNotchProgress
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 24
                height: 2.0
                radius: 1.0
                visible: islandWin.mode === "transfer"
                color: Qt.rgba(1, 1, 1, 0.16)

                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    color: islandWin.transferJustFinished ? "#4ADE80" : Theme.primary
                    width: Math.max(3, parent.width * Math.min(1.0, Math.max(0.0, islandWin.activeTransferProgress)))
                    Behavior on width { NumberAnimation { duration: 180 } }
                }
            }

            // 4. Sneak Peek Inline HUD Indicator (Volume / Brightness)
            Row {
                anchors.centerIn: parent
                spacing: 6
                visible: islandWin.hudActive

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12; height: 12
                    path: (islandWin.hudEvent && islandWin.hudEvent.kind === "brightness") ? Icons.brightness : Icons.volumeUp
                    color: Theme.primary
                }

                Rectangle {
                    width: 50; height: 4; radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(1, 1, 1, 0.20)
                    Rectangle {
                        height: parent.height; radius: parent.radius
                        color: Theme.primary
                        width: Math.max(3, parent.width * Math.min(1.0, Math.max(0.0, ((islandWin.hudEvent && islandWin.hudEvent.percent !== undefined) ? islandWin.hudEvent.percent : 0) / 100)))
                    }
                }
            }

            // 4.1. Caps Lock Notch Toast (Atoll reverse-engineered)
            Row {
                anchors.centerIn: parent
                spacing: 6
                visible: !!(Preferences.notchCapsLockHud && islandWin.atollHud && islandWin.atollHud.capsLockToastActive)
                z: 15

                Rectangle {
                    width: 14; height: 14; radius: 3
                    color: (islandWin.atollHud && islandWin.atollHud.capsLockActive) ? "#10B981" : Qt.rgba(1, 1, 1, 0.20)
                    anchors.verticalCenter: parent.verticalCenter
                    Txt {
                        anchors.centerIn: parent
                        text: "⇪"
                        size: 10
                        weight: Font.Bold
                        color: "#FFFFFF"
                    }
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (islandWin.atollHud && islandWin.atollHud.capsLockActive) ? qsTr("CAPS ON") : qsTr("CAPS OFF")
                    size: 9.5
                    weight: Font.Bold
                    color: (islandWin.atollHud && islandWin.atollHud.capsLockActive) ? "#10B981" : Qt.rgba(1, 1, 1, 0.65)
                }
            }

            // 4.2. Focus / Do Not Disturb Notch Toast (Atoll reverse-engineered)
            Row {
                anchors.centerIn: parent
                spacing: 5
                visible: !!(Preferences.notchFocusHud && islandWin.atollHud && islandWin.atollHud.focusToastActive && !islandWin.atollHud.capsLockToastActive)
                z: 15

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12; height: 12
                    path: Icons.moon || Icons.bell
                    color: (islandWin.atollHud && islandWin.atollHud.focusActive) ? "#A78BFA" : Qt.rgba(1, 1, 1, 0.65)
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (islandWin.atollHud && islandWin.atollHud.focusActive) ? (islandWin.atollHud.focusModeName || qsTr("Focus On")) : qsTr("Focus Off")
                    size: 9.5
                    weight: Font.DemiBold
                    color: (islandWin.atollHud && islandWin.atollHud.focusActive) ? "#C084FC" : Qt.rgba(1, 1, 1, 0.65)
                }
            }

            // 4.3. Bluetooth Audio Connect Toast (Atoll reverse-engineered)
            Row {
                anchors.centerIn: parent
                spacing: 5
                visible: !!(Preferences.notchBluetoothHud && islandWin.atollHud && islandWin.atollHud.bluetoothToastActive && !islandWin.atollHud.capsLockToastActive && !islandWin.atollHud.focusToastActive)
                z: 15

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12; height: 12
                    path: Icons.headphones || Icons.volumeUp
                    color: "#38BDF8"
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("%1 (%2%)").arg((islandWin.atollHud && islandWin.atollHud.bluetoothDeviceType) ? islandWin.atollHud.bluetoothDeviceType : "Audio").arg((islandWin.atollHud && islandWin.atollHud.bluetoothBattery) ? islandWin.atollHud.bluetoothBattery : 100)
                    size: 9.5
                    weight: Font.DemiBold
                    color: "#38BDF8"
                }
            }

            // 4.4. Hardware Privacy Indicator Dots (poshak2004/island reverse-engineered)
            Row {
                anchors.right: parent.right
                anchors.rightMargin: -16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                visible: !!(Preferences.notchPrivacySensorHud && islandWin.privacySensors && islandWin.privacySensors.anyActive)
                z: 20

                // Camera active indicator (Green LED)
                Rectangle {
                    width: 7; height: 7; radius: 3.5
                    color: "#10B981"
                    visible: !!(islandWin.privacySensors && islandWin.privacySensors.cameraActive)
                }

                // Microphone active indicator (Amber/Orange LED)
                Rectangle {
                    width: 7; height: 7; radius: 3.5
                    color: "#F59E0B"
                    visible: !!(islandWin.privacySensors && islandWin.privacySensors.micActive)
                }
            }

            // 4.5. Live Download Progress Toast (poshak2004/island reverse-engineered)
            Row {
                anchors.centerIn: parent
                spacing: 5
                visible: !!(Preferences.notchDownloadsHud && islandWin.downloadsData && islandWin.downloadsData.hasActiveDownloads && (!islandWin.atollHud || (!islandWin.atollHud.capsLockToastActive && !islandWin.atollHud.focusToastActive && !islandWin.atollHud.bluetoothToastActive)))
                z: 15

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12; height: 12
                    path: Icons.download
                    color: "#38BDF8"
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        const first = (islandWin.downloadsData && islandWin.downloadsData.downloads && islandWin.downloadsData.downloads.length > 0) ? islandWin.downloadsData.downloads[0] : null
                        return first ? (first.percent + "% • " + first.speedMBs + " MB/s") : qsTr("Downloading…")
                    }
                    size: 9.5
                    weight: Font.DemiBold
                    color: "#38BDF8"
                }
            }

            // 4.5.5. Live Network & Hotspot Connection Toast (Notchly reverse-engineered)
            Row {
                anchors.centerIn: parent
                spacing: 5
                visible: !!(Preferences.notchNetworkStatusEnabled && islandWin.networkStatus && islandWin.networkStatus.toastActive && (!islandWin.atollHud || (!islandWin.atollHud.capsLockToastActive && !islandWin.atollHud.focusToastActive && !islandWin.atollHud.bluetoothToastActive)))
                z: 16

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12; height: 12
                    path: (islandWin.networkStatus && islandWin.networkStatus.isHotspot) ? (Icons.phone || Icons.wifi) : Icons.wifi
                    color: (islandWin.networkStatus && islandWin.networkStatus.connected) ? "#34D399" : "#F87171"
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (islandWin.networkStatus && islandWin.networkStatus.toastMessage) ? islandWin.networkStatus.toastMessage : ""
                    size: 9.5
                    weight: Font.DemiBold
                    color: (islandWin.networkStatus && islandWin.networkStatus.connected) ? "#34D399" : "#F87171"
                }
            }

            // 4.6. Ledge Standing Notch Announcements & Peripheral Alert Strip (egemertbalcik/Ledge reverse-engineered)
            Rectangle {
                id: ledgeStandingStrip
                anchors.top: parent.bottom
                anchors.topMargin: -4
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width + 48.0, 300.0)
                height: 24
                radius: 12
                color: "#0D0D11"
                border.width: 1
                border.color: (islandWin.ledgeAnnouncement && islandWin.ledgeAnnouncement.accentHex) ? islandWin.ledgeAnnouncement.accentHex : "#38BDF8"
                visible: !!(Preferences.notchAnnouncementsEnabled && islandWin.ledgeAnnouncement && islandWin.ledgeAnnouncement.active && !islandWin.expanded)
                z: 25

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        width: 6; height: 6; radius: 3
                        color: (islandWin.ledgeAnnouncement && islandWin.ledgeAnnouncement.accentHex) ? islandWin.ledgeAnnouncement.accentHex : "#38BDF8"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (islandWin.ledgeAnnouncement && islandWin.ledgeAnnouncement.title) ? islandWin.ledgeAnnouncement.title : ""
                        size: 9.5
                        weight: Font.DemiBold
                        color: (islandWin.ledgeAnnouncement && islandWin.ledgeAnnouncement.accentHex) ? islandWin.ledgeAnnouncement.accentHex : "#EDEDEF"
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        visible: !!(islandWin.ledgeAnnouncement && islandWin.ledgeAnnouncement.dotsCount > 0)
                        Repeater {
                            model: (islandWin.ledgeAnnouncement && islandWin.ledgeAnnouncement.dotsCount) ? islandWin.ledgeAnnouncement.dotsCount : 0
                            Rectangle {
                                width: 4; height: 4; radius: 2
                                color: (islandWin.ledgeAnnouncement && islandWin.ledgeAnnouncement.accentHex) ? islandWin.ledgeAnnouncement.accentHex : "#38BDF8"
                            }
                        }
                    }
                }
            }

            // 4.7. QuietNotch Inline Volume / Brightness HUD (quietapps/QuietNotch reverse-engineered)
            Row {
                anchors.centerIn: parent
                spacing: 6
                visible: !!(Preferences.notchQuietInlineHudEnabled && islandWin.quietnotchHud && islandWin.quietnotchHud.visible)
                z: 18

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12; height: 12
                    path: {
                        if (!islandWin.quietnotchHud) return Icons.volumeUp
                        if (islandWin.quietnotchHud.kind === "brightness") return Icons.brightness
                        if (islandWin.quietnotchHud.kind === "mic") return Icons.mic
                        return Icons.volumeUp
                    }
                    color: (islandWin.quietnotchHud && islandWin.quietnotchHud.isMuted) ? "#F87171" : "#38BDF8"
                }

                Rectangle {
                    width: 60; height: 4; radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(1, 1, 1, 0.20)

                    Rectangle {
                        height: parent.height; radius: parent.radius
                        color: (islandWin.quietnotchHud && islandWin.quietnotchHud.isMuted) ? "#F87171" : "#38BDF8"
                        width: Math.max(3, parent.width * Math.min(1.0, Math.max(0.0, (islandWin.quietnotchHud ? islandWin.quietnotchHud.value : 0.0))))
                        Behavior on width { NumberAnimation { duration: 80 } }
                    }
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (islandWin.quietnotchHud && islandWin.quietnotchHud.title) ? islandWin.quietnotchHud.title : ""
                    size: 9.0
                    weight: Font.DemiBold
                    color: (islandWin.quietnotchHud && islandWin.quietnotchHud.isMuted) ? "#F87171" : "#EDEDEF"
                }
            }

            // 4.8. QuietNotch Notification Drop Toast (quietapps/QuietNotch reverse-engineered)
            Rectangle {
                id: quietnotchNotifBanner
                anchors.top: parent.bottom
                anchors.topMargin: 2
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width + 120.0, 380.0)
                height: 34
                radius: 10
                color: "#0F1117"
                border.width: 1
                border.color: Qt.rgba(0.22, 0.74, 0.97, 0.35)
                visible: !!(Preferences.notchQuietNotificationsEnabled && islandWin.quietnotchNotification && islandWin.quietnotchNotification.hasNotification && !islandWin.expanded)
                z: 30

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: DynamoController.dismissQuietnotchNotification()
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Rectangle {
                        width: 18; height: 18; radius: 5
                        color: "#1E293B"
                        anchors.verticalCenter: parent.verticalCenter
                        Icon {
                            anchors.centerIn: parent
                            width: 11; height: 11
                            path: Icons.bell
                            color: "#38BDF8"
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        width: parent.width - 40

                        Row {
                            spacing: 6
                            Txt {
                                text: (islandWin.quietnotchNotification && islandWin.quietnotchNotification.appName) ? islandWin.quietnotchNotification.appName : "System"
                                size: 8.5
                                weight: Font.Bold
                                color: "#94A3B8"
                            }
                            Txt {
                                text: "•"
                                size: 8.5
                                color: "#64748B"
                            }
                            Txt {
                                text: (islandWin.quietnotchNotification && islandWin.quietnotchNotification.title) ? islandWin.quietnotchNotification.title : ""
                                size: 9.0
                                weight: Font.Bold
                                color: "#F8FAFC"
                                elide: Text.ElideRight
                                width: Math.min(implicitWidth, 220)
                            }
                        }

                        Txt {
                            text: (islandWin.quietnotchNotification && islandWin.quietnotchNotification.body) ? islandWin.quietnotchNotification.body : ""
                            size: 8.5
                            color: "#CBD5E1"
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, 290)
                        }
                    }
                }
            }

            // 4.9 Isle Live Crypto & Forex Ticker (TheVinizzz/Isle reverse-engineered)
            Rectangle {
                id: isleFinanceTickerBar
                anchors.centerIn: parent
                height: Math.min(22, parent.height - 4)
                width: Math.min(parent.width - 12, financeRow.implicitWidth + 14)
                radius: height / 2
                color: Qt.rgba(0.08, 0.11, 0.16, 0.88)
                border.width: 1
                border.color: (islandWin.isleFinance && islandWin.isleFinance.changePercent >= 0) ? Qt.rgba(0.13, 0.77, 0.37, 0.4) : Qt.rgba(0.94, 0.27, 0.27, 0.4)
                visible: !!(Preferences.notchIsleFinanceEnabled && islandWin.isleFinance && islandWin.isleFinance.symbol && !islandWin.expanded)
                z: 8

                Row {
                    id: financeRow
                    anchors.centerIn: parent
                    spacing: 5

                    Txt {
                        text: (islandWin.isleFinance && islandWin.isleFinance.symbol) ? islandWin.isleFinance.symbol : "BTC"
                        size: 9
                        weight: Font.Bold
                        color: "#E2E8F0"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Txt {
                        text: (islandWin.isleFinance && islandWin.isleFinance.priceFormatted) ? islandWin.isleFinance.priceFormatted : "$0.00"
                        size: 9
                        weight: Font.Medium
                        color: "#F8FAFC"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        height: 12
                        width: changeTxt.implicitWidth + 6
                        radius: 3
                        color: (islandWin.isleFinance && islandWin.isleFinance.changePercent >= 0) ? Qt.rgba(0.13, 0.77, 0.37, 0.22) : Qt.rgba(0.94, 0.27, 0.27, 0.22)
                        anchors.verticalCenter: parent.verticalCenter

                        Txt {
                            id: changeTxt
                            anchors.centerIn: parent
                            text: {
                                if (!islandWin.isleFinance || islandWin.isleFinance.changePercent === undefined) return "+0.0%"
                                const cp = islandWin.isleFinance.changePercent
                                return (cp >= 0 ? "+" : "") + cp.toFixed(1) + "%"
                            }
                            size: 8
                            weight: Font.Bold
                            color: (islandWin.isleFinance && islandWin.isleFinance.changePercent >= 0) ? "#34D399" : "#F87171"
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        DynamoController.refreshIsleFinance()
                    }
                }
            }

            // 4.10 MacIsland Battery & Fast Charge HUD (BadRat-in/MacIsland reverse-engineered)
            Rectangle {
                id: macislandBatteryHud
                anchors.centerIn: parent
                height: Math.min(22, parent.height - 4)
                width: Math.min(parent.width - 12, battRow.implicitWidth + 16)
                radius: height / 2
                color: Qt.rgba(0.04, 0.16, 0.08, 0.92)
                border.width: 1
                border.color: Qt.rgba(0.2, 0.85, 0.45, 0.5)
                visible: !!(Preferences.notchMacislandBatteryHudEnabled && islandWin.macislandBattery && islandWin.macislandBattery.isCharging && !islandWin.expanded)
                z: 9

                Row {
                    id: battRow
                    anchors.centerIn: parent
                    spacing: 5

                    Txt {
                        text: "⚡"
                        size: 9
                        color: "#34D399"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Txt {
                        text: (islandWin.macislandBattery && islandWin.macislandBattery.percentage !== undefined) ? (islandWin.macislandBattery.percentage + "%") : "100%"
                        size: 9.5
                        weight: Font.Bold
                        color: "#FFFFFF"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Txt {
                        text: (islandWin.macislandBattery && islandWin.macislandBattery.timeRemaining) ? islandWin.macislandBattery.timeRemaining : "Charging"
                        size: 8.5
                        color: "#A7F3D0"
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 110)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // 4.11 MacWake Keyboard & Screen Cleaning HUD (Jarvis322/MacWake reverse-engineered)
            Rectangle {
                id: macwakeCleaningHud
                anchors.centerIn: parent
                height: Math.min(22, parent.height - 4)
                width: Math.min(parent.width - 12, cleanRow.implicitWidth + 18)
                radius: height / 2
                color: Qt.rgba(0.18, 0.12, 0.02, 0.95)
                border.width: 1
                border.color: Qt.rgba(0.96, 0.65, 0.14, 0.65)
                visible: !!(Preferences.notchMacwakeCleaningModeEnabled && islandWin.macwakeCleaning && islandWin.macwakeCleaning.isActive && !islandWin.expanded)
                z: 10

                Row {
                    id: cleanRow
                    anchors.centerIn: parent
                    spacing: 6

                    Txt {
                        text: "🧹"
                        size: 9
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Txt {
                        text: (islandWin.macwakeCleaning && islandWin.macwakeCleaning.remainingSeconds !== undefined)
                            ? qsTr("Cleaning: %1s").arg(islandWin.macwakeCleaning.remainingSeconds)
                            : qsTr("Cleaning Mode")
                        size: 9.5
                        weight: Font.Bold
                        color: "#FDE68A"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Txt {
                        text: qsTr("(Click to exit)")
                        size: 8.5
                        color: "#FBBF24"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        DynamoController.stopCleaningMode()
                    }
                }
            }

            // 4.12 PiIsland AI Coding Agent Companion (phun333/pi-island & jwintz/pi-island reverse-engineered)
            Rectangle {
                id: piislandAgentHud
                anchors.centerIn: parent
                height: Math.min(22, parent.height - 4)
                width: Math.min(parent.width - 12, piRow.implicitWidth + 18)
                radius: height / 2
                color: Qt.rgba(0.06, 0.09, 0.16, 0.94)
                border.width: 1
                border.color: Qt.rgba(0.22, 0.74, 0.97, 0.5)
                visible: !!(Preferences.notchPiislandSessionMonitorEnabled && islandWin.piislandSessions && islandWin.piislandSessions.hasActiveSession && islandWin.piislandSessions.currentSession && islandWin.piislandSessions.currentSession.isBusy && !islandWin.expanded)
                z: 10

                Row {
                    id: piRow
                    anchors.centerIn: parent
                    spacing: 6

                    Txt {
                        text: "✨"
                        size: 9
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Txt {
                        text: (islandWin.piislandSessions && islandWin.piislandSessions.currentSession && islandWin.piislandSessions.currentSession.agent)
                            ? islandWin.piislandSessions.currentSession.agent
                            : "Antigravity"
                        size: 9.5
                        weight: Font.Bold
                        color: "#38BDF8"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Txt {
                        text: (islandWin.piislandSessions && islandWin.piislandSessions.currentSession && islandWin.piislandSessions.currentSession.activeTool)
                            ? (":" + islandWin.piislandSessions.currentSession.activeTool)
                            : ":thinking"
                        size: 8.5
                        weight: Font.Medium
                        color: "#E2E8F0"
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 90)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // 4.13 Pookify Animated Agent Glyphs (eyadhammouda/pookify reverse-engineered)
            Rectangle {
                id: pookifyGlyphHud
                anchors.centerIn: parent
                height: Math.min(22, parent.height - 4)
                width: Math.min(parent.width - 12, pookRow.implicitWidth + 18)
                radius: height / 2
                color: Qt.rgba(0.18, 0.08, 0.04, 0.94)
                border.width: 1
                border.color: Qt.rgba(0.85, 0.47, 0.34, 0.6)
                visible: !!(Preferences.notchPookifyAgentGlyphsEnabled && islandWin.pookifyAnim && islandWin.pookifyAnim.isWorking && !islandWin.expanded)
                z: 10

                Row {
                    id: pookRow
                    anchors.centerIn: parent
                    spacing: 6

                    Txt {
                        text: (islandWin.pookifyAnim && islandWin.pookifyAnim.glyph) ? islandWin.pookifyAnim.glyph : "🦀"
                        size: 9.5
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Txt {
                        text: (islandWin.pookifyAnim && islandWin.pookifyAnim.currentTurn && islandWin.pookifyAnim.currentTurn.label)
                            ? islandWin.pookifyAnim.currentTurn.label
                            : "Claude Code"
                        size: 9
                        weight: Font.DemiBold
                        color: "#FED7AA"
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 120)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // 4.14 Find on Screen Live OCR Pill (windows-dynamic-island reverse-engineered)
            Rectangle {
                id: visionOcrHud
                height: 22
                width: Math.min(ocrRow.implicitWidth + 14, 180)
                radius: 11
                color: Qt.rgba(0.08, 0.16, 0.32, 0.90)
                border.width: 1
                border.color: "#38BDF8"
                anchors.centerIn: parent
                visible: !!(Preferences.notchVisionOcrSearchEnabled && islandWin.screenOcr && (islandWin.screenOcr.isScanning || (islandWin.screenOcr.hasScanned && islandWin.screenOcr.matchCount > 0)) && !islandWin.expanded)
                z: 6

                Row {
                    id: ocrRow
                    anchors.centerIn: parent
                    spacing: 5

                    Txt {
                        text: islandWin.screenOcr.isScanning ? "🔍" : "👁️"
                        size: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Txt {
                        text: islandWin.screenOcr.isScanning ? qsTr("Scanning...") : ("\"" + (islandWin.screenOcr.query || "") + "\" (" + (islandWin.screenOcr.currentIndex || 0) + "/" + (islandWin.screenOcr.matchCount || 0) + ")")
                        role: "caption"
                        size: 10
                        weight: Font.DemiBold
                        color: "#BAE6FD"
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 130)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // 4.15 TopNotch Focus & Pomodoro Ring Pill (techuila/top-notch reverse-engineered)
            Rectangle {
                id: topnotchFocusHud
                height: 22
                width: Math.min(focusRow.implicitWidth + 16, 175)
                radius: 11
                color: Qt.rgba(0.12, 0.08, 0.20, 0.90)
                border.width: 1
                border.color: islandWin.topnotchFocus && islandWin.topnotchFocus.phase === "work" ? "#F59E0B" : "#10B981"
                anchors.centerIn: parent
                visible: !!(Preferences.notchTopnotchFocusEnabled && islandWin.topnotchFocus && (islandWin.topnotchFocus.isRunning || islandWin.topnotchFocus.isPaused) && !islandWin.expanded)
                z: 6

                Row {
                    id: focusRow
                    anchors.centerIn: parent
                    spacing: 5

                    Txt {
                        text: islandWin.topnotchFocus && islandWin.topnotchFocus.phase === "work" ? "⏱️" : "☕"
                        size: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Txt {
                        text: (islandWin.topnotchFocus && islandWin.topnotchFocus.formattedTime) ? islandWin.topnotchFocus.formattedTime : "25:00"
                        role: "caption"
                        size: 10
                        weight: Font.Bold
                        color: "#FDE68A"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Txt {
                        text: (islandWin.topnotchFocus && islandWin.topnotchFocus.phaseLabel) ? ("• " + islandWin.topnotchFocus.phaseLabel) : "• Focus"
                        role: "caption"
                        size: 9
                        weight: Font.Medium
                        color: "#D1D5DB"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // 4.16 MacIsland2 Video Call Ring Light HUD Pill (ethantiller/macisland2 reverse-engineered)
            Rectangle {
                id: ringLightHud
                height: 22
                width: Math.min(ringLightRow.implicitWidth + 16, 175)
                radius: 11
                color: Qt.rgba(0.24, 0.20, 0.08, 0.92)
                border.width: 1
                border.color: "#FDE047"
                anchors.centerIn: parent
                visible: !!(Preferences.notchMacislandStudioEnabled && islandWin.macislandStudio && islandWin.macislandStudio.ringLightOn && !islandWin.expanded)
                z: 6

                Row {
                    id: ringLightRow
                    anchors.centerIn: parent
                    spacing: 5

                    Txt {
                        text: "💡"
                        size: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Txt {
                        text: qsTr("Ring Light Active")
                        role: "caption"
                        size: 10
                        weight: Font.Bold
                        color: "#FEF08A"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Txt {
                        text: "• " + Math.round(((islandWin.macislandStudio && islandWin.macislandStudio.ringBrightness) || 0.8) * 100) + "%"
                        role: "caption"
                        size: 9
                        weight: Font.Medium
                        color: "#FFFFFF"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // 5. Drag-to-Shelf Drop Target Cue (boring.notch reverse-engineered)
            Rectangle {
                id: notchDragDropTarget
                anchors.fill: parent
                radius: 12
                visible: Preferences.notchDragToShelf && DynamoController.notchDragActive
                color: Qt.rgba(0.2, 0.6, 1.0, 0.28)
                border.width: 1.5
                border.color: "#60A5FA"
                z: 10

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Icon {
                        width: 13; height: 13
                        path: Icons.shelf
                        color: "#FFFFFF"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Txt {
                        text: qsTr("Drop onto Shelf")
                        role: "caption"
                        size: 10
                        weight: Font.DemiBold
                        color: "#FFFFFF"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // 6. MagSafe / AC Charging Pulse Ring (boring.notch reverse-engineered)
            Timer {
                id: chargingPulseTimer
                interval: 2200
                repeat: false
            }

            Rectangle {
                id: chargingPulseGlow
                anchors.fill: parent
                radius: 12
                visible: chargingPulseTimer.running
                color: Qt.rgba(0.2, 0.85, 0.4, 0.22)
                border.width: 1.5
                border.color: "#4ADE80"
                opacity: 0.0
                z: 9

                SequentialAnimation on opacity {
                    id: chargingPulseAnim
                    running: false
                    NumberAnimation { from: 0.0; to: 1.0; duration: 250; easing.type: Easing.OutCubic }
                    NumberAnimation { from: 1.0; to: 0.3; duration: 500; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 0.3; to: 0.9; duration: 450; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 0.9; to: 0.0; duration: 800; easing.type: Easing.InQuad }
                }
            }

            // 7. Mochi Animated Squircle Companion (coucou reverse-engineered)
            Item {
                id: mochiCompanionNotch
                anchors.centerIn: parent
                width: 44
                height: Math.min(22, parent.height - 4)
                visible: Preferences.notchMochiCompanion && (Preferences.notchMascotType === "mochi" || (Preferences.notchMascotType !== "antigravity" && Preferences.notchMascotType !== "mio")) && !islandWin.hudActive && !(Preferences.notchDragToShelf && DynamoController.notchDragActive)
                z: 11
                scale: (islandWin.mochiState && islandWin.mochiState.breathScaleX) ? islandWin.mochiState.breathScaleX : 1.0

                Row {
                    anchors.centerIn: parent
                    spacing: 11

                    // Left Eye
                    Item {
                        width: 7; height: 11
                        scale: Qt.size(1.0, islandWin.mochiState ? Math.max(0.12, 1.0 - (islandWin.mochiState.blink || 0.0)) : 1.0)

                        Rectangle {
                            anchors.fill: parent
                            radius: 3.5
                            color: (islandWin.mochiState && islandWin.mochiState.colorHex) ? islandWin.mochiState.colorHex : "#EDEDEF"
                            visible: !islandWin.mochiState || (islandWin.mochiState.eyeShape === "pill")

                            Rectangle {
                                width: 3.5; height: 4.5; radius: 1.75
                                color: "#000000"
                                x: 1.75 + ((islandWin.mochiState && islandWin.mochiState.yaw) ? islandWin.mochiState.yaw * 1.5 : 0)
                                y: 3.25 + ((islandWin.mochiState && islandWin.mochiState.pitch) ? islandWin.mochiState.pitch * 2.0 : 0)
                            }
                        }

                        Txt {
                            anchors.centerIn: parent
                            text: "^"
                            weight: Font.Bold
                            size: 11
                            color: (islandWin.mochiState && islandWin.mochiState.colorHex) ? islandWin.mochiState.colorHex : "#10B981"
                            visible: !!(islandWin.mochiState && islandWin.mochiState.eyeShape === "happy")
                        }

                        Txt {
                            anchors.centerIn: parent
                            text: "@"
                            weight: Font.Bold
                            size: 9
                            color: "#F59E0B"
                            visible: !!(islandWin.mochiState && islandWin.mochiState.eyeShape === "spiral")
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 6; height: 1.5; radius: 0.75
                            color: "#94A3B8"
                            visible: !!(islandWin.mochiState && islandWin.mochiState.eyeShape === "closed")
                        }
                    }

                    // Right Eye
                    Item {
                        width: 7; height: 11
                        scale: Qt.size(1.0, islandWin.mochiState ? Math.max(0.12, 1.0 - (islandWin.mochiState.blink || 0.0)) : 1.0)

                        Rectangle {
                            anchors.fill: parent
                            radius: 3.5
                            color: (islandWin.mochiState && islandWin.mochiState.colorHex) ? islandWin.mochiState.colorHex : "#EDEDEF"
                            visible: !islandWin.mochiState || (islandWin.mochiState.eyeShape === "pill")

                            Rectangle {
                                width: 3.5; height: 4.5; radius: 1.75
                                color: "#000000"
                                x: 1.75 + ((islandWin.mochiState && islandWin.mochiState.yaw) ? islandWin.mochiState.yaw * 1.5 : 0)
                                y: 3.25 + ((islandWin.mochiState && islandWin.mochiState.pitch) ? islandWin.mochiState.pitch * 2.0 : 0)
                            }
                        }

                        Txt {
                            anchors.centerIn: parent
                            text: "^"
                            weight: Font.Bold
                            size: 11
                            color: (islandWin.mochiState && islandWin.mochiState.colorHex) ? islandWin.mochiState.colorHex : "#10B981"
                            visible: !!(islandWin.mochiState && islandWin.mochiState.eyeShape === "happy")
                        }

                        Txt {
                            anchors.centerIn: parent
                            text: "@"
                            weight: Font.Bold
                            size: 9
                            color: "#F59E0B"
                            visible: !!(islandWin.mochiState && islandWin.mochiState.eyeShape === "spiral")
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 6; height: 1.5; radius: 0.75
                            color: "#94A3B8"
                            visible: !!(islandWin.mochiState && islandWin.mochiState.eyeShape === "closed")
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: DynamoController.pokeMochi()
                }
            }

            // 7.1. AntiGravity Bot Animated Mascot (CodeIsland reverse-engineered)
            Item {
                id: antiGravityBotNotch
                anchors.centerIn: parent
                width: 48
                height: Math.min(22, parent.height - 4)
                visible: Preferences.notchMochiCompanion && (Preferences.notchMascotType === "antigravity") && !islandWin.hudActive && !(Preferences.notchDragToShelf && DynamoController.notchDragActive)
                z: 11
                scale: (islandWin.mochiState && islandWin.mochiState.breathScaleX) ? islandWin.mochiState.breathScaleX : 1.0

                Row {
                    anchors.centerIn: parent
                    spacing: 5

                    // Rainbow Bot Icon / Avatar
                    Rectangle {
                        width: 18; height: 18; radius: 5
                        color: Qt.rgba(0.2, 0.4, 0.9, 0.35)
                        border.width: 1
                        border.color: (islandWin.agentTasks && islandWin.agentTasks.hasTasks) ? "#3B82F6" : "#A78BFA"
                        anchors.verticalCenter: parent.verticalCenter

                        Txt {
                            anchors.centerIn: parent
                            text: "A"
                            weight: Font.Black
                            size: 11
                            color: (islandWin.agentTasks && islandWin.agentTasks.hasTasks) ? "#60A5FA" : "#C084FC"
                        }
                    }

                    // Bot Eyes
                    Row {
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            width: 4; height: 7; radius: 2
                            color: "#FFFFFF"
                            scale: Qt.size(1.0, islandWin.mochiState ? Math.max(0.12, 1.0 - (islandWin.mochiState.blink || 0.0)) : 1.0)
                        }
                        Rectangle {
                            width: 4; height: 7; radius: 2
                            color: "#FFFFFF"
                            scale: Qt.size(1.0, islandWin.mochiState ? Math.max(0.12, 1.0 - (islandWin.mochiState.blink || 0.0)) : 1.0)
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: DynamoController.pokeMochi()
                }
            }

            // 7.1.5. Mio CyberCat Mascot (MioIsland reverse-engineered)
            Item {
                id: mioCyberCatNotch
                anchors.centerIn: parent
                width: 48
                height: Math.min(22, parent.height - 4)
                visible: Preferences.notchMochiCompanion && (Preferences.notchMascotType === "mio") && !islandWin.hudActive && !(Preferences.notchDragToShelf && DynamoController.notchDragActive)
                z: 11

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    Rectangle {
                        width: 18; height: 18; radius: 4
                        color: Qt.rgba(0.06, 0.72, 0.51, 0.25)
                        border.width: 1.2
                        border.color: "#10B981"
                        anchors.verticalCenter: parent.verticalCenter

                        Txt {
                            anchors.centerIn: parent
                            text: "=^..^="
                            weight: Font.Bold
                            size: 8
                            color: "#34D399"
                        }
                    }

                    Row {
                        spacing: 3
                        anchors.verticalCenter: parent.verticalCenter
                        Rectangle { width: 3.5; height: 6; radius: 1.5; color: "#06B6D4" }
                        Rectangle { width: 3.5; height: 6; radius: 1.5; color: "#EC4899" }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        DynamoController.pokeMochi()
                        if (Preferences.notchSynthAudioEnabled) DynamoController.playSynthSound("start")
                    }
                }
            }

            // 7.2. Agent Task Progress Bar (CodeIsland reverse-engineered)
            Rectangle {
                id: agentTaskNotchProgress
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 24
                height: 2.2
                radius: 1.1
                visible: Preferences.notchAgentTasksEnabled && islandWin.agentTasks && islandWin.agentTasks.hasTasks && !underNotchProgress.visible
                color: Qt.rgba(1, 1, 1, 0.16)
                z: 12

                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    color: (islandWin.agentTasks && islandWin.agentTasks.isAllCompleted) ? "#22C55E" : "#3B82F6"
                    width: Math.max(3, parent.width * Math.min(1.0, Math.max(0.0, ((islandWin.agentTasks && islandWin.agentTasks.percent) ? islandWin.agentTasks.percent : 0) / 100)))
                    Behavior on width { NumberAnimation { duration: 200 } }
                }
            }
        }

        // ====================================================================
        // 2. NON-NOTCHED CENTRAL FLOATING PILL (Collapsed External Monitor)
        // ====================================================================
        Rectangle {
            id: centerFloatingPill
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: 160.0
            height: 32.0
            radius: 16.0
            visible: !islandWin.isNotchAttached && !islandWin.expanded
            onVisibleChanged: if (!visible) islandWin.floatingHovered = false
            z: 1

            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.00; color: Qt.rgba(0, 0, 0, 0.86) }
                GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.70) }
            }
            border.width: 0.85
            border.color: Qt.rgba(1, 1, 1, 0.18)

            // Apple camera lens dot indicator
            Rectangle {
                id: floatingCameraDot
                width: 7; height: 7; radius: 3.5
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(1, 1, 1, 0.25)
                Rectangle {
                    width: 3; height: 3; radius: 1.5
                    anchors.centerIn: parent
                    color: "#000000"
                }
            }

            Row {
                anchors.left: floatingCameraDot.right
                anchors.leftMargin: 6
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                visible: !Preferences.notchMochiCompanion || islandWin.mode === "media"

                Icon {
                    visible: islandWin.mode === "media"
                    anchors.verticalCenter: parent.verticalCenter
                    width: 10; height: 10
                    path: Icons.music
                    color: Theme.primary
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - (islandWin.mode === "media" ? 14 : 0)
                    role: "caption"
                    size: 10
                    weight: Font.Medium
                    color: Qt.rgba(1, 1, 1, 0.80)
                    elide: Text.ElideRight
                    text: islandWin.mode === "media" ? islandWin.mediaTitle : "MacLink"
                }
            }

            // Mochi Animated Companion (External Display Center Pill)
            Item {
                id: mochiFloatingItem
                anchors.centerIn: parent
                width: 44
                height: 20
                visible: Preferences.notchMochiCompanion && (Preferences.notchMascotType === "mochi" || (Preferences.notchMascotType !== "antigravity" && Preferences.notchMascotType !== "mio")) && islandWin.mode !== "media"
                z: 2
                scale: (islandWin.mochiState && islandWin.mochiState.breathScaleX) ? islandWin.mochiState.breathScaleX : 1.0

                Row {
                    anchors.centerIn: parent
                    spacing: 11

                    // Left Eye
                    Item {
                        width: 6; height: 10
                        scale: Qt.size(1.0, islandWin.mochiState ? Math.max(0.12, 1.0 - (islandWin.mochiState.blink || 0.0)) : 1.0)
                        Rectangle {
                            anchors.fill: parent
                            radius: 3
                            color: (islandWin.mochiState && islandWin.mochiState.colorHex) ? islandWin.mochiState.colorHex : "#EDEDEF"
                            visible: !islandWin.mochiState || (islandWin.mochiState.eyeShape === "pill")
                            Rectangle {
                                width: 3; height: 4; radius: 1.5
                                color: "#000000"
                                x: 1.5 + ((islandWin.mochiState && islandWin.mochiState.yaw) ? islandWin.mochiState.yaw * 1.2 : 0)
                                y: 3.0 + ((islandWin.mochiState && islandWin.mochiState.pitch) ? islandWin.mochiState.pitch * 1.5 : 0)
                            }
                        }
                        Txt {
                            anchors.centerIn: parent; text: "^"; weight: Font.Bold; size: 10
                            color: (islandWin.mochiState && islandWin.mochiState.colorHex) ? islandWin.mochiState.colorHex : "#10B981"
                            visible: !!(islandWin.mochiState && islandWin.mochiState.eyeShape === "happy")
                        }
                        Txt {
                            anchors.centerIn: parent; text: "@"; weight: Font.Bold; size: 8; color: "#F59E0B"
                            visible: !!(islandWin.mochiState && islandWin.mochiState.eyeShape === "spiral")
                        }
                    }

                    // Right Eye
                    Item {
                        width: 6; height: 10
                        scale: Qt.size(1.0, islandWin.mochiState ? Math.max(0.12, 1.0 - (islandWin.mochiState.blink || 0.0)) : 1.0)
                        Rectangle {
                            anchors.fill: parent
                            radius: 3
                            color: (islandWin.mochiState && islandWin.mochiState.colorHex) ? islandWin.mochiState.colorHex : "#EDEDEF"
                            visible: !islandWin.mochiState || (islandWin.mochiState.eyeShape === "pill")
                            Rectangle {
                                width: 3; height: 4; radius: 1.5
                                color: "#000000"
                                x: 1.5 + ((islandWin.mochiState && islandWin.mochiState.yaw) ? islandWin.mochiState.yaw * 1.2 : 0)
                                y: 3.0 + ((islandWin.mochiState && islandWin.mochiState.pitch) ? islandWin.mochiState.pitch * 1.5 : 0)
                            }
                        }
                        Txt {
                            anchors.centerIn: parent; text: "^"; weight: Font.Bold; size: 10
                            color: (islandWin.mochiState && islandWin.mochiState.colorHex) ? islandWin.mochiState.colorHex : "#10B981"
                            visible: !!(islandWin.mochiState && islandWin.mochiState.eyeShape === "happy")
                        }
                        Txt {
                            anchors.centerIn: parent; text: "@"; weight: Font.Bold; size: 8; color: "#F59E0B"
                            visible: !!(islandWin.mochiState && islandWin.mochiState.eyeShape === "spiral")
                        }
                    }
                }
            }

            // AntiGravity Bot (External Display Center Pill)
            Item {
                id: antiGravityFloatingItem
                anchors.centerIn: parent
                width: 44
                height: 20
                visible: Preferences.notchMochiCompanion && (Preferences.notchMascotType === "antigravity") && islandWin.mode !== "media"
                z: 2
                scale: (islandWin.mochiState && islandWin.mochiState.breathScaleX) ? islandWin.mochiState.breathScaleX : 1.0

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    Rectangle {
                        width: 16; height: 16; radius: 4
                        color: Qt.rgba(0.2, 0.4, 0.9, 0.35)
                        border.width: 1
                        border.color: (islandWin.agentTasks && islandWin.agentTasks.hasTasks) ? "#3B82F6" : "#A78BFA"
                        anchors.verticalCenter: parent.verticalCenter
                        Txt {
                            anchors.centerIn: parent
                            text: "A"
                            weight: Font.Black
                            size: 10
                            color: (islandWin.agentTasks && islandWin.agentTasks.hasTasks) ? "#60A5FA" : "#C084FC"
                        }
                    }

                    Row {
                        spacing: 3
                        anchors.verticalCenter: parent.verticalCenter
                        Rectangle {
                            width: 3.5; height: 6; radius: 1.75
                            color: "#FFFFFF"
                            scale: Qt.size(1.0, islandWin.mochiState ? Math.max(0.12, 1.0 - (islandWin.mochiState.blink || 0.0)) : 1.0)
                        }
                        Rectangle {
                            width: 3.5; height: 6; radius: 1.75
                            color: "#FFFFFF"
                            scale: Qt.size(1.0, islandWin.mochiState ? Math.max(0.12, 1.0 - (islandWin.mochiState.blink || 0.0)) : 1.0)
                        }
                    }
                }
            }

            // Mio CyberCat (External Display Center Pill)
            Item {
                id: mioFloatingItem
                anchors.centerIn: parent
                width: 44
                height: 20
                visible: Preferences.notchMochiCompanion && (Preferences.notchMascotType === "mio") && islandWin.mode !== "media"
                z: 2

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    Rectangle {
                        width: 16; height: 16; radius: 4
                        color: Qt.rgba(0.06, 0.72, 0.51, 0.25)
                        border.width: 1
                        border.color: "#10B981"
                        anchors.verticalCenter: parent.verticalCenter
                        Txt {
                            anchors.centerIn: parent
                            text: "=^..^="
                            weight: Font.Bold
                            size: 7.5
                            color: "#34D399"
                        }
                    }

                    Row {
                        spacing: 2.5
                        anchors.verticalCenter: parent.verticalCenter
                        Rectangle { width: 3; height: 5; radius: 1.5; color: "#06B6D4" }
                        Rectangle { width: 3; height: 5; radius: 1.5; color: "#EC4899" }
                    }
                }
            }

            // External Floating Pill Agent Task Progress
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 16
                height: 2.0
                radius: 1.0
                visible: Preferences.notchAgentTasksEnabled && islandWin.agentTasks && islandWin.agentTasks.hasTasks
                color: Qt.rgba(1, 1, 1, 0.16)
                z: 3

                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    color: (islandWin.agentTasks && islandWin.agentTasks.isAllCompleted) ? "#22C55E" : "#3B82F6"
                    width: Math.max(3, parent.width * Math.min(1.0, Math.max(0.0, ((islandWin.agentTasks && islandWin.agentTasks.percent) ? islandWin.agentTasks.percent : 0) / 100)))
                    Behavior on width { NumberAnimation { duration: 200 } }
                }
            }

            MouseArea {
                id: floatingMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    islandWin.floatingHovered = true
                    islandWin.isHoverExpanded = true
                }
                onExited: islandWin.floatingHovered = false
                onClicked: {
                    islandWin.userPinnedOpen = !islandWin.userPinnedOpen
                    if (islandWin.userPinnedOpen) autoCollapseTimer.restart()
                }
            }
        }

        // ====================================================================
        // 3. LEFT TELEMETRY WING (LeftNotchDropShape + CPUTempGlowEdge)
        // ====================================================================
        Item {
            id: leftWingContainer
            z: 0
            visible: islandWin.wingsActive && !islandWin.expanded
            onVisibleChanged: if (!visible && !islandWin.expanded) islandWin.leftHovered = false
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 160 } }

            // Anchoring: FLUSH against notch wall (0px margin) on notch, or 8px gap on external
            anchors.right: islandWin.isNotchAttached ? centerNotchAnchor.left : centerFloatingPill.left
            anchors.rightMargin: islandWin.isNotchAttached ? 0 : 8
            anchors.top: islandWin.isNotchAttached ? parent.top : undefined
            anchors.verticalCenter: islandWin.isNotchAttached ? undefined : centerFloatingPill.verticalCenter
            width: islandWin.leftWingWidth
            height: islandWin.isNotchAttached ? islandWin.centerNotchHeight : 32.0

            readonly property real cpuPercentVal: {
                if (islandWin.telemetry && islandWin.telemetry.cpuPercent !== undefined)
                    return islandWin.telemetry.cpuPercent
                if (islandWin.telemetry && islandWin.telemetry.sample && islandWin.telemetry.sample.cpuPercent !== undefined)
                    return islandWin.telemetry.sample.cpuPercent
                return islandWin.mockCpuPercent
            }
            readonly property real cpuTempCVal: {
                if (islandWin.macwakeThermal && islandWin.macwakeThermal.cpuTempC !== undefined && islandWin.macwakeThermal.cpuTempC > 0)
                    return islandWin.macwakeThermal.cpuTempC
                if (islandWin.telemetry && islandWin.telemetry.sample && islandWin.telemetry.sample.cpuTempC !== undefined)
                    return islandWin.telemetry.sample.cpuTempC
                if (islandWin.telemetry && islandWin.telemetry.cpuTempC !== undefined)
                    return islandWin.telemetry.cpuTempC
                return 48.0
            }
            readonly property real ramPercentVal: {
                if (islandWin.telemetry && islandWin.telemetry.sample && islandWin.telemetry.sample.ramPercent !== undefined)
                    return islandWin.telemetry.sample.ramPercent
                if (islandWin.telemetry && islandWin.telemetry.ramPercent !== undefined)
                    return islandWin.telemetry.ramPercent
                return islandWin.mockRamPercent
            }
            readonly property color ramBarColor: islandWin.getRamBarColor(ramPercentVal)
            readonly property color cpuThermalColor: islandWin.getCpuThermalColor(cpuTempCVal)

            // A. Exact LeftNotchDropShape (Notched Displays - 70% Transparent Apple Liquid Glass)
            Shape {
                id: leftNotchShape
                anchors.fill: parent
                visible: islandWin.isNotchAttached
                preferredRendererType: Shape.CurveRenderer
                asynchronous: true

                ShapePath {
                    startX: leftWingContainer.width; startY: 0
                    fillGradient: LinearGradient {
                        x1: 0; y1: 0; x2: leftWingContainer.width; y2: 0
                        GradientStop { position: 0.00; color: Qt.rgba(0.06, 0.07, 0.10, 0.60) }
                        GradientStop { position: 0.85; color: Qt.rgba(0.06, 0.07, 0.10, 0.60) }
                        GradientStop { position: 1.00; color: Qt.rgba(0.06, 0.07, 0.10, 0.60) }
                    }
                    strokeGradient: LinearGradient {
                        x1: 0; y1: 0; x2: leftWingContainer.width; y2: 0
                        GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.32) }
                        GradientStop { position: 0.80; color: Qt.rgba(1, 1, 1, 0.12) }
                        GradientStop { position: 1.00; color: "transparent" } // Flush with notch wall
                    }
                    strokeWidth: 0.75
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin

                    // Down the notch wall to bottom right
                    PathLine { x: leftWingContainer.width; y: leftWingContainer.height }
                    // Leftward along bottom edge
                    PathLine { x: Math.min(10, Math.min(leftWingContainer.width / 2, leftWingContainer.height / 2)); y: leftWingContainer.height }
                    // Rounded droplet tip on left
                    PathQuad {
                        x: 0
                        y: leftWingContainer.height - Math.min(10, Math.min(leftWingContainer.width / 2, leftWingContainer.height / 2))
                        controlX: 0
                        controlY: leftWingContainer.height
                    }
                    PathLine { x: 0; y: Math.min(10, Math.min(leftWingContainer.width / 2, leftWingContainer.height / 2)) }
                    PathQuad {
                        x: Math.min(10, Math.min(leftWingContainer.width / 2, leftWingContainer.height / 2))
                        y: 0
                        controlX: 0
                        controlY: 0
                    }
                    // Top edge back to notch wall
                    PathLine { x: leftWingContainer.width; y: 0 }
                }
            }

            // Apple Glass Top Lip Highlight
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 0.5
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 6
                anchors.rightMargin: 1
                height: 0.75
                radius: 0.5
                color: Qt.rgba(1, 1, 1, 0.22)
            }

            // B. Floating Capsule Shape (Non-notched External Displays - 70% Transparent Apple Liquid Glass)
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                visible: !islandWin.isNotchAttached
                color: Qt.rgba(0.06, 0.07, 0.10, 0.60)
                border.width: 0.75
                border.color: Qt.rgba(1, 1, 1, 0.28)
            }

            // C. CPUTempGlowEdge: 50% Fire Flare CPU Temperature Fill (Copied 1:1 from dynamo-mac)
            Item {
                id: cpuTempGlowEdge
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height
                visible: true // Permanent baseline indicator (copied from dynamo CPUTempGlowEdge overlay)
                clip: true

                Timer {
                    id: dynamoFlameTimer
                    interval: 33 // 30 fps matching dynamo-mac's TimelineView(.animation(minimumInterval: 1.0 / 30.0))
                    repeat: true
                    running: islandWin.visible && !islandWin.expanded && !Theme.reduceMotion
                    onTriggered: {
                        dynamoFlameCanvas.time += 0.033
                        dynamoFlameCanvas.requestPaint()
                    }
                }

                Canvas {
                    id: dynamoFlameCanvas
                    anchors.fill: parent
                    renderTarget: Canvas.Image

                    property real time: 0
                    property color flameColor: leftWingContainer.cpuThermalColor
                    property real tempC: leftWingContainer.cpuTempCVal
                    onTimeChanged: requestPaint()
                    onFlameColorChanged: requestPaint()
                    onTempCChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()

                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        if (width <= 0 || height <= 0) return

                        const fillFraction = 0.50 // WingIndicatorColors.flareFillFraction (50% wing height)
                        const maxFlareHeight = height * fillFraction

                        // Normalized temperature t across 35°C to 70°C rule
                        const t = Math.max(0.0, Math.min(1.0, (tempC - 35.0) / (70.0 - 35.0)))
                        const urgent = tempC >= 70.0

                        // Breathing modulation when in urgent state (1.2s cycle)
                        var breathMult = 1.0
                        if (urgent) {
                            const breathPhase = Math.sin(time * (2.0 * Math.PI / 1.2))
                            breathMult = 0.85 + 0.15 * breathPhase
                        }

                        // Overall intensity rises with normalized temperature t
                        const intensityMult = (0.75 + 0.25 * t) * breathMult
                        const c = flameColor

                        // Core color: temperature color lightened with ~35% white
                        const coreR = Math.min(1.0, c.r * 0.65 + 0.35)
                        const coreG = Math.min(1.0, c.g * 0.65 + 0.35)
                        const coreB = Math.min(1.0, c.b * 0.65 + 0.35)

                        const deepR = c.r * 0.90
                        const deepG = c.g * 0.82
                        const deepB = c.b * 0.82

                        // 1. Base vertical gradient: solid temperature color at bottom edge fading to transparent at 50% line
                        const baseGrad = ctx.createLinearGradient(0, height, 0, height - maxFlareHeight)
                        baseGrad.addColorStop(0.0, Qt.rgba(c.r, c.g, c.b, 0.46 * intensityMult))
                        baseGrad.addColorStop(0.50, Qt.rgba(c.r, c.g, c.b, 0.22 * intensityMult))
                        baseGrad.addColorStop(1.0, Qt.rgba(c.r, c.g, c.b, 0.0))
                        ctx.fillStyle = baseGrad
                        ctx.fillRect(0, height - maxFlareHeight, width, maxFlareHeight)

                        // 2. Flame tongues: 6 soft vertical lobes along width whose heights flicker independently
                        // (Copied 1:1 from dynamo-mac TongueSpec)
                        const tongues = [
                            { relX: 0.12, widthFraction: 0.22, speed: 2.1, phase: 0.0, baseHeightPct: 0.65, heightAmpPct: 0.25, swayAmp: 1.2 },
                            { relX: 0.28, widthFraction: 0.25, speed: 3.4, phase: 1.8, baseHeightPct: 0.75, heightAmpPct: 0.22, swayAmp: 1.5 },
                            { relX: 0.45, widthFraction: 0.28, speed: 2.7, phase: 3.6, baseHeightPct: 0.82, heightAmpPct: 0.18, swayAmp: 1.8 },
                            { relX: 0.62, widthFraction: 0.26, speed: 3.1, phase: 5.2, baseHeightPct: 0.78, heightAmpPct: 0.20, swayAmp: 1.6 },
                            { relX: 0.78, widthFraction: 0.24, speed: 2.3, phase: 2.4, baseHeightPct: 0.70, heightAmpPct: 0.24, swayAmp: 1.4 },
                            { relX: 0.90, widthFraction: 0.20, speed: 3.8, phase: 4.1, baseHeightPct: 0.60, heightAmpPct: 0.28, swayAmp: 1.0 }
                        ]

                        const maxAllowedTongueHeight = (t >= 1.0) ? (maxFlareHeight + height * 0.10) : maxFlareHeight

                        for (var i = 0; i < tongues.length; i++) {
                            const tg = tongues[i]
                            const effectiveSpeed = tg.speed * (0.65 + 0.70 * t)
                            const osc = Math.sin(time * effectiveSpeed + tg.phase)
                            const sway = tg.swayAmp * Math.sin(time * effectiveSpeed * 0.7 + tg.phase + 1.2) * (0.4 + 0.6 * t)

                            const heightFactor = tg.baseHeightPct + tg.heightAmpPct * osc * (0.40 + 0.60 * t)
                            const tongueH = Math.max(2.0, Math.min(maxAllowedTongueHeight, maxFlareHeight * heightFactor))

                            const centerX = width * tg.relX + sway
                            const tongueW = width * tg.widthFraction

                            ctx.beginPath()
                            ctx.moveTo(centerX - tongueW * 0.5, height)
                            ctx.bezierCurveTo(
                                centerX - tongueW * 0.35, height - tongueH * 0.45,
                                centerX - tongueW * 0.10, height - tongueH * 0.92,
                                centerX, height - tongueH
                            )
                            ctx.bezierCurveTo(
                                centerX + tongueW * 0.10, height - tongueH * 0.92,
                                centerX + tongueW * 0.35, height - tongueH * 0.45,
                                centerX + tongueW * 0.5, height
                            )
                            ctx.closePath()

                            // Tongue gradient: lighter core at base, deeper at tip
                            const tongueGrad = ctx.createLinearGradient(centerX, height, centerX, height - tongueH)
                            tongueGrad.addColorStop(0.0, Qt.rgba(coreR, coreG, coreB, 0.38 * intensityMult))
                            tongueGrad.addColorStop(0.45, Qt.rgba(c.r, c.g, c.b, 0.30 * intensityMult))
                            tongueGrad.addColorStop(1.0, Qt.rgba(deepR, deepG, deepB, 0.0))
                            ctx.fillStyle = tongueGrad
                            ctx.fill()
                        }

                        // 3. Additive hot glow along bottom edge
                        const glowH = 3.0
                        const glowGrad = ctx.createLinearGradient(0, height - glowH, 0, height)
                        glowGrad.addColorStop(0.0, Qt.rgba(coreR, coreG, coreB, 0.0))
                        glowGrad.addColorStop(1.0, Qt.rgba(coreR, coreG, coreB, 0.50 * intensityMult))
                        ctx.fillStyle = glowGrad
                        ctx.fillRect(0, height - glowH, width, glowH)

                        // 4. Horizontal mask for soft blending into rounded wing ends (matching dynamo-mac mask)
                        ctx.globalCompositeOperation = "destination-in"
                        const hMask = ctx.createLinearGradient(0, 0, width, 0)
                        hMask.addColorStop(0.00, "transparent")
                        hMask.addColorStop(0.14, Qt.rgba(0, 0, 0, 1.0))
                        hMask.addColorStop(0.86, Qt.rgba(0, 0, 0, 1.0))
                        hMask.addColorStop(1.00, "transparent")
                        ctx.fillStyle = hMask
                        ctx.fillRect(0, 0, width, height)
                        ctx.globalCompositeOperation = "source-over"
                    }
                }
            }

            // E. Left Wing Dynamic Content (Menu Bar Origin, Content-Driven Auto-Resizing)
            Item {
                id: leftWingContentItem
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 4
                z: 1

                Row {
                    id: leftWingContentRow
                    anchors.centerIn: parent
                    spacing: 4

                    // 1. Permanent CPU Temperature Fire Flare Fill (Copied 1:1 from dynamo-mac)
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        visible: islandWin.activeLeftWingWidget === "cpu_temp_flame"

                        // Quick Tools (when hovered)
                        Row {
                            id: leftToolsRow
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3
                            visible: islandWin.leftHovered

                            // Color Eyedropper
                            Rectangle {
                                width: 16; height: 16; radius: 8
                                color: eyeBtnAreaL1.containsMouse ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.14)
                                anchors.verticalCenter: parent.verticalCenter
                                Icon { anchors.centerIn: parent; width: 8.5; height: 8.5; path: Icons.palette; color: "#F472B6" }
                                MouseArea {
                                    id: eyeBtnAreaL1
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (DynamoController && typeof DynamoController.pickScreenColor === "function") DynamoController.pickScreenColor() }
                                }
                            }

                            // Caffeinate
                            Rectangle {
                                width: 16; height: 16; radius: 8
                                property bool isCaf: DynamoController ? DynamoController.isCaffeinateActive() : false
                                color: isCaf ? Qt.rgba(0.96, 0.62, 0.04, 0.35) : (cafBtnAreaL1.containsMouse ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.14))
                                anchors.verticalCenter: parent.verticalCenter
                                Icon { anchors.centerIn: parent; width: 8.5; height: 8.5; path: Icons.coffee; color: parent.isCaf ? "#FBBF24" : Qt.rgba(1, 1, 1, 0.70) }
                                MouseArea {
                                    id: cafBtnAreaL1
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (DynamoController && typeof DynamoController.toggleCaffeinate === "function") parent.isCaf = DynamoController.toggleCaffeinate() }
                                }
                            }

                            // Shelf Jumper
                            Rectangle {
                                width: 16; height: 16; radius: 8
                                color: shelfBtnAreaL1.containsMouse ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.14)
                                anchors.verticalCenter: parent.verticalCenter
                                Icon { anchors.centerIn: parent; width: 8.5; height: 8.5; path: Icons.folder; color: "#A78BFA" }
                                MouseArea {
                                    id: shelfBtnAreaL1
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: AppController.toggleShelf()
                                }
                            }
                        }
                    }

                    // 2. Auxiliary Widget on Left Wing (When Selected in Settings)
                    // Combined Net Speed (⇅ Combined throughput)
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        visible: islandWin.activeLeftWingWidget === "net_speed"

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "⇅"
                            size: 9.5
                            weight: Font.Bold
                            color: "#38BDF8"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: "#38BDF8"
                            text: (islandWin.networkStatus && islandWin.networkStatus.combinedCompact) ? islandWin.networkStatus.combinedCompact : "0K"
                        }
                    }

                    // CPU Load & Activity
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        visible: islandWin.activeLeftWingWidget === "cpu_load"

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 9.5; height: 9.5
                            path: Icons.cpu
                            color: leftWingContainer.cpuThermalColor
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: leftWingContainer.cpuThermalColor
                            text: Math.round(leftWingContainer.cpuPercentVal) + "%"
                        }
                    }

                    // RAM Memory Status Bar (when chosen on left)
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        visible: islandWin.activeLeftWingWidget === "ram_bar"

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 9.5; height: 9.5
                            path: Icons.memorychip
                            color: leftWingContainer.ramBarColor
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: leftWingContainer.ramBarColor
                            text: Math.round(leftWingContainer.ramPercentVal) + "%"
                        }
                    }

                    // Battery & Power Status
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        visible: islandWin.activeLeftWingWidget === "battery"

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 9.0; height: 9.0
                            path: (islandWin.sysBattery && (islandWin.sysBattery.isCharging || islandWin.sysBattery.isPluggedIn)) ? Icons.bolt : Icons.battery
                            color: (islandWin.sysBattery && (islandWin.sysBattery.isCharging || islandWin.sysBattery.isPluggedIn)) ? "#4ADE80" : ((islandWin.sysBattery && islandWin.sysBattery.level <= 20) ? "#EF4444" : "#FFFFFF")
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: "#FFFFFF"
                            text: (islandWin.sysBattery && islandWin.sysBattery.level !== undefined) ? (Math.round(islandWin.sysBattery.level) + "%") : "100%"
                        }
                    }

                    // Now Playing Media
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        visible: islandWin.activeLeftWingWidget === "media"

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 9.0; height: 9.0
                            path: Icons.music
                            color: "#10B981"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.DemiBold
                            color: "#FFFFFF"
                            text: islandWin.mediaTitle || qsTr("Music")
                            elide: Text.ElideRight
                            width: Math.min(65, implicitWidth)
                        }
                    }

                    // Crypto Ticker
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        visible: islandWin.activeLeftWingWidget === "crypto"

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.0
                            weight: Font.Bold
                            color: "#F59E0B"
                            text: "BTC"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.DemiBold
                            color: "#FFFFFF"
                            text: (islandWin.isleFinance && islandWin.isleFinance.price) ? islandWin.isleFinance.price : "$94.2K"
                        }
                    }

                    // RAM Details (Used / Total)
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3.5
                        visible: islandWin.activeLeftWingWidget === "ram_details"

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8.5; height: 8.5
                            path: Icons.memorychip
                            color: "#A855F7"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 8.5
                            weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.50)
                            text: "RAM"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: "#FFFFFF"
                            text: ((leftWingContainer.ramPercentVal / 100.0) * 16.0).toFixed(1) + "G/16G"
                        }
                    }

                    // RAM Pressure
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3.5
                        visible: islandWin.activeLeftWingWidget === "ram_pressure"

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8.5; height: 8.5
                            path: Icons.compass
                            color: leftWingContainer.ramBarColor
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 8.5
                            weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.50)
                            text: "PRESS"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: leftWingContainer.ramBarColor
                            text: islandWin.leftHovered
                                ? ((leftWingContainer.ramPercentVal > 80 ? "Critical" : (leftWingContainer.ramPercentVal > 60 ? "Warning" : "Normal")) + " " + Math.round(leftWingContainer.ramPercentVal) + "%")
                                : (leftWingContainer.ramPercentVal > 80 ? "Critical" : (leftWingContainer.ramPercentVal > 60 ? "Warning" : "Normal"))
                        }
                    }

                    // Download Speed
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3.5
                        visible: islandWin.activeLeftWingWidget === "net_down"

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8.5; height: 8.5
                            path: Icons.arrowDown
                            color: "#22C55E"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 8.5
                            weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.50)
                            text: "DL"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: "#FFFFFF"
                            text: islandWin.leftHovered
                                ? ((islandWin.networkStatus && islandWin.networkStatus.combinedCompact) ? islandWin.networkStatus.combinedCompact : "0K")
                                : ((islandWin.networkStatus && islandWin.networkStatus.downloadCompact) ? islandWin.networkStatus.downloadCompact : "0K")
                        }
                    }

                    // Upload Speed
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3.5
                        visible: islandWin.activeLeftWingWidget === "net_up"

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8.5; height: 8.5
                            path: Icons.arrowUp
                            color: "#38BDF8"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 8.5
                            weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.50)
                            text: "UL"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: "#FFFFFF"
                            text: islandWin.leftHovered
                                ? ((islandWin.networkStatus && islandWin.networkStatus.combinedCompact) ? islandWin.networkStatus.combinedCompact : "0K")
                                : ((islandWin.networkStatus && islandWin.networkStatus.uploadCompact) ? islandWin.networkStatus.uploadCompact : "0K")
                        }
                    }

                    // Bluetooth Device Battery
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3.5
                        visible: islandWin.activeLeftWingWidget === "bluetooth_battery"

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8.5; height: 8.5
                            path: Icons.bluetooth
                            color: "#3B82F6"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 8.5
                            weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.50)
                            text: "BT"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: "#FFFFFF"
                            text: (islandWin.atollHud && islandWin.atollHud.bluetoothBattery) ? (islandWin.atollHud.bluetoothBattery + "%") : "85%"
                        }
                    }

                    // System Volume
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3.5
                        visible: islandWin.activeLeftWingWidget === "volume"

                        readonly property bool isMuted: !!(islandWin.quietnotchHud && islandWin.quietnotchHud.isMuted)
                        readonly property int volVal: (islandWin.quietnotchHud && islandWin.quietnotchHud.kind === "volume") ? Math.round(islandWin.quietnotchHud.value * 100) : 65

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8.5; height: 8.5
                            path: parent.isMuted ? Icons.soundOff : Icons.speaker
                            color: parent.isMuted ? "#EF4444" : "#38BDF8"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 8.5
                            weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.50)
                            text: "VOL"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: parent.isMuted ? "#EF4444" : "#FFFFFF"
                            text: parent.isMuted ? "Mute" : (parent.volVal + "%")
                        }
                    }

                    // Display Brightness
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3.5
                        visible: islandWin.activeLeftWingWidget === "brightness"

                        readonly property int brtVal: (islandWin.quietnotchHud && islandWin.quietnotchHud.kind === "brightness") ? Math.round(islandWin.quietnotchHud.value * 100) : 75

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8.5; height: 8.5
                            path: Icons.brightness
                            color: "#FBBF24"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 8.5
                            weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.50)
                            text: "BRT"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: "#FFFFFF"
                            text: parent.brtVal + "%"
                        }
                    }

                    // Clock & Date
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3.5
                        visible: islandWin.activeLeftWingWidget === "clock"

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8.5; height: 8.5
                            path: Icons.clock
                            color: Qt.rgba(1, 1, 1, 0.85)
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: "#FFFFFF"
                            text: islandWin.leftHovered ? (islandWin.liveClockStr + " • " + Qt.formatDate(new Date(), "ddd MMM d")) : islandWin.liveClockStr
                        }
                    }

                    // Ambient Weather
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3.5
                        visible: islandWin.activeLeftWingWidget === "weather"

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8.5; height: 8.5
                            path: Icons.brightness
                            color: "#FB923C"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 8.5
                            weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.50)
                            text: "WX"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: "#FFFFFF"
                            text: "72° Sunny"
                        }
                    }

                    // Interactive Media Controls (Copied from Dynamo)
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        visible: islandWin.activeLeftWingWidget === "media_controls"

                        Rectangle {
                            width: 14; height: 14; radius: 7
                            color: prevBtnAreaL.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.10)
                            anchors.verticalCenter: parent.verticalCenter
                            Icon { anchors.centerIn: parent; width: 8.0; height: 8.0; path: Icons.skipPrevious; color: Qt.rgba(1, 1, 1, 0.85) }
                            MouseArea {
                                id: prevBtnAreaL
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: islandWin.prevMedia()
                            }
                        }

                        Rectangle {
                            width: 16; height: 16; radius: 8
                            color: playBtnAreaL.containsMouse ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.15)
                            anchors.verticalCenter: parent.verticalCenter
                            Icon {
                                anchors.centerIn: parent
                                width: 8.5; height: 8.5
                                path: (islandWin.mediaPlaying || islandWin.localMediaPlaying) ? Icons.pause : Icons.play
                                color: "#10B981"
                            }
                            MouseArea {
                                id: playBtnAreaL
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: islandWin.playPauseMedia()
                            }
                        }

                        Rectangle {
                            width: 14; height: 14; radius: 7
                            color: nextBtnAreaL.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.10)
                            anchors.verticalCenter: parent.verticalCenter
                            Icon { anchors.centerIn: parent; width: 8.0; height: 8.0; path: Icons.skipNext; color: Qt.rgba(1, 1, 1, 0.85) }
                            MouseArea {
                                id: nextBtnAreaL
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: islandWin.nextMedia()
                            }
                        }
                    }

                    // Phone Battery (MacLink Bridge)
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3.5
                        visible: islandWin.activeLeftWingWidget === "phone_battery"

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8.5; height: 8.5
                            path: Icons.phone
                            color: "#4ADE80"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 8.5
                            weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.50)
                            text: "PHN"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: "#FFFFFF"
                            text: (typeof DeviceList !== "undefined" && DeviceList && DeviceList.count > 0 && typeof DeviceList.batteryAt === "function" && DeviceList.batteryAt(0) !== undefined) ? (DeviceList.batteryAt(0) + "%") : "88%"
                        }
                    }

                    // Cellular Signal
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3.5
                        visible: islandWin.activeLeftWingWidget === "phone_signal"

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8.5; height: 8.5
                            path: Icons.signal
                            color: "#38BDF8"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 8.5
                            weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.50)
                            text: "CELL"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: "#FFFFFF"
                            text: "5G"
                        }
                    }

                    // Keep Awake (Caffeinate)
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3.5
                        visible: islandWin.activeLeftWingWidget === "keep_awake"

                        property bool isCafActive: DynamoController ? DynamoController.isCaffeinateActive() : false

                        Rectangle {
                            width: 16; height: 16; radius: 8
                            color: parent.isCafActive ? Qt.rgba(0.96, 0.62, 0.04, 0.35) : (cafWidgetAreaL.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12))
                            anchors.verticalCenter: parent.verticalCenter
                            Icon {
                                anchors.centerIn: parent
                                width: 8.5; height: 8.5
                                path: Icons.coffee
                                color: parent.parent.isCafActive ? "#FBBF24" : Qt.rgba(1, 1, 1, 0.60)
                            }
                            MouseArea {
                                id: cafWidgetAreaL
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (DynamoController && typeof DynamoController.toggleCaffeinate === "function") {
                                        parent.parent.isCafActive = DynamoController.toggleCaffeinate()
                                    }
                                }
                            }
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 8.5
                            weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.50)
                            text: "AWK"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: parent.isCafActive ? "#FBBF24" : Qt.rgba(1, 1, 1, 0.60)
                            text: parent.isCafActive ? "ON" : "OFF"
                        }
                    }
                }
            }

            HoverHandler {
                id: leftWingHoverHandler
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onHoveredChanged: {
                    islandWin.leftHovered = hovered
                }
            }

            MouseArea {
                id: leftWingMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    islandWin.leftHovered = true
                    islandWin.isHoverExpanded = true
                    autoCollapseTimer.stop()
                }
                onExited: {
                    islandWin.leftHovered = false
                    islandWin.checkHoverState()
                }
                onClicked: {
                    islandWin.userPinnedOpen = !islandWin.userPinnedOpen
                    if (islandWin.userPinnedOpen) autoCollapseTimer.restart()
                }
            }
        }

        // ====================================================================
        // 4. RIGHT TELEMETRY WING (RightNotchDropShape + RAMBottomBar)
        // ====================================================================
        Item {
            id: rightWingContainer
            z: 0
            visible: islandWin.wingsActive && !islandWin.expanded
            onVisibleChanged: if (!visible && !islandWin.expanded) islandWin.rightHovered = false
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 160 } }

            // Anchoring: FLUSH against notch wall (0px margin) on notch, or 8px gap on external
            anchors.left: islandWin.isNotchAttached ? centerNotchAnchor.right : centerFloatingPill.right
            anchors.leftMargin: islandWin.isNotchAttached ? 0 : 8
            anchors.top: islandWin.isNotchAttached ? parent.top : undefined
            anchors.verticalCenter: islandWin.isNotchAttached ? undefined : centerFloatingPill.verticalCenter
            width: islandWin.rightWingWidth
            height: islandWin.isNotchAttached ? islandWin.centerNotchHeight : 32.0

            readonly property real ramPercentVal: {
                if (islandWin.telemetry && islandWin.telemetry.sample && islandWin.telemetry.sample.ramPercent !== undefined)
                    return islandWin.telemetry.sample.ramPercent
                if (islandWin.telemetry && islandWin.telemetry.ramPercent !== undefined)
                    return islandWin.telemetry.ramPercent
                return islandWin.mockRamPercent
            }
            readonly property color ramBarColor: islandWin.getRamBarColor(ramPercentVal)
            readonly property real cpuPercentVal: {
                if (islandWin.telemetry && islandWin.telemetry.cpuPercent !== undefined)
                    return islandWin.telemetry.cpuPercent
                if (islandWin.telemetry && islandWin.telemetry.sample && islandWin.telemetry.sample.cpuPercent !== undefined)
                    return islandWin.telemetry.sample.cpuPercent
                return islandWin.mockCpuPercent
            }
            readonly property real cpuTempCVal: {
                if (islandWin.macwakeThermal && islandWin.macwakeThermal.cpuTempC !== undefined && islandWin.macwakeThermal.cpuTempC > 0)
                    return islandWin.macwakeThermal.cpuTempC
                if (islandWin.telemetry && islandWin.telemetry.sample && islandWin.telemetry.sample.cpuTempC !== undefined)
                    return islandWin.telemetry.sample.cpuTempC
                if (islandWin.telemetry && islandWin.telemetry.cpuTempC !== undefined)
                    return islandWin.telemetry.cpuTempC
                return 48.0
            }
            readonly property color cpuThermalColor: islandWin.getCpuThermalColor(cpuTempCVal)

            // A. Exact RightNotchDropShape (Notched Displays - 70% Transparent Apple Liquid Glass)
            Shape {
                id: rightNotchShape
                anchors.fill: parent
                visible: islandWin.isNotchAttached
                preferredRendererType: Shape.CurveRenderer
                asynchronous: true

                ShapePath {
                    startX: 0; startY: 0
                    fillGradient: LinearGradient {
                        x1: 0; y1: 0; x2: rightWingContainer.width; y2: 0
                        GradientStop { position: 0.00; color: Qt.rgba(0.06, 0.07, 0.10, 0.60) }
                        GradientStop { position: 0.15; color: Qt.rgba(0.06, 0.07, 0.10, 0.60) }
                        GradientStop { position: 1.00; color: Qt.rgba(0.06, 0.07, 0.10, 0.60) }
                    }
                    strokeGradient: LinearGradient {
                        x1: 0; y1: 0; x2: rightWingContainer.width; y2: 0
                        GradientStop { position: 0.00; color: "transparent" } // Flush with notch wall
                        GradientStop { position: 0.20; color: Qt.rgba(1, 1, 1, 0.12) }
                        GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, 0.32) }
                    }
                    strokeWidth: 0.75
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin

                    // Top edge outward to the right
                    PathLine { x: rightWingContainer.width - Math.min(10, Math.min(rightWingContainer.width / 2, rightWingContainer.height / 2)); y: 0 }
                    // Rounded droplet tip on right
                    PathQuad {
                        x: rightWingContainer.width
                        y: Math.min(10, Math.min(rightWingContainer.width / 2, rightWingContainer.height / 2))
                        controlX: rightWingContainer.width
                        controlY: 0
                    }
                    PathLine { x: rightWingContainer.width; y: rightWingContainer.height - Math.min(10, Math.min(rightWingContainer.width / 2, rightWingContainer.height / 2)) }
                    PathQuad {
                        x: rightWingContainer.width - Math.min(10, Math.min(rightWingContainer.width / 2, rightWingContainer.height / 2))
                        y: rightWingContainer.height
                        controlX: rightWingContainer.width
                        controlY: rightWingContainer.height
                    }
                    // Bottom edge back inward toward notch wall
                    PathLine { x: 0; y: rightWingContainer.height }
                    // Up the notch wall to top left
                    PathLine { x: 0; y: 0 }
                }
            }

            // Apple Glass Top Lip Highlight
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 0.5
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 1
                anchors.rightMargin: 6
                height: 0.75
                radius: 0.5
                color: Qt.rgba(1, 1, 1, 0.22)
            }

            // B. Floating Capsule Shape (Non-notched External Displays - 70% Transparent Apple Liquid Glass)
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                visible: !islandWin.isNotchAttached
                color: Qt.rgba(0.06, 0.07, 0.10, 0.60)
                border.width: 0.75
                border.color: Qt.rgba(1, 1, 1, 0.28)
            }

            // C. RAMBottomBar: Permanent Bold 3D Status Bar across the Bottom (Copied from dynamo-mac)
            Item {
                id: ramBottomBarItem
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 2.0
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(0, parent.width - 12.0)
                height: 4.5
                visible: true // Permanent baseline indicator

                // 3D Recessed Groove Track
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 4.5
                    radius: 2.25
                    color: Qt.rgba(0, 0, 0, 0.65)
                    border.width: 0.75
                    border.color: Qt.rgba(255, 255, 255, 0.14)
                }

                // Bold 3D Cylindrical Active Fill Capsule
                Rectangle {
                    id: ramFilledBar
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    height: 4.5
                    radius: 2.25
                    color: rightWingContainer.ramBarColor
                    width: Math.max(3.0, parent.width * Math.min(1.0, Math.max(0.06, rightWingContainer.ramPercentVal / 100.0)))

                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.00; color: Qt.lighter(rightWingContainer.ramBarColor, 1.35) }
                        GradientStop { position: 0.45; color: rightWingContainer.ramBarColor }
                        GradientStop { position: 1.00; color: Qt.darker(rightWingContainer.ramBarColor, 1.30) }
                    }

                    Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 240 } }

                    // Glossy Specular Reflection Line (Top Half)
                    Rectangle {
                        anchors.top: parent.top
                        anchors.topMargin: 0.5
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.max(2.0, parent.width - 2.0)
                        height: 1.5
                        radius: 0.75
                        color: Qt.rgba(1, 1, 1, 0.45)
                    }

                    // Outer 3D Ambient Radiant Glow
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: rightWingContainer.ramBarColor
                        opacity: 0.40
                        scale: 1.15
                        z: -1
                    }
                }
            }

            // D. Right Wing Dynamic Menu Bar Status Content (Content-Driven Auto-Resizing)
            Item {
                id: rightWingContentItem
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 6
                anchors.bottomMargin: 3

                Row {
                    id: rightWingContentRow
                    anchors.centerIn: parent
                    spacing: 4

                    // 1. Permanent RAM Status (Bold 3D Status Bar at Bottom, No Numeric Values)
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        // Contextual controls when hovered
                        Row {
                            id: rightToolsRow
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3
                            visible: islandWin.rightHovered

                            // Wi-Fi Icon
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 9; height: 9
                                path: Icons.wifi
                                color: (islandWin.networkStatus && islandWin.networkStatus.connected) ? "#34D399" : Qt.rgba(1, 1, 1, 0.45)
                            }

                            // DND Moon Toggle
                            Rectangle {
                                width: 16; height: 16; radius: 8
                                color: Preferences.notchQuietHoursEnabled ? Qt.rgba(0.65, 0.54, 0.98, 0.35) : (dndBtnAreaR.containsMouse ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.14))
                                anchors.verticalCenter: parent.verticalCenter
                                Icon {
                                    anchors.centerIn: parent
                                    width: 8.5; height: 8.5
                                    path: Icons.moon
                                    color: Preferences.notchQuietHoursEnabled ? "#C084FC" : Qt.rgba(1, 1, 1, 0.75)
                                }
                                MouseArea {
                                    id: dndBtnAreaR
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Preferences.notchQuietHoursEnabled = !Preferences.notchQuietHoursEnabled
                                    }
                                }
                            }
                        }
                    }

                    // 2. Auxiliary Widget on Right Wing (When Selected in Settings)
                    // Combined Net Speed (⇅ Combined throughput)
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        visible: islandWin.activeRightWingWidget === "net_speed"

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "⇅"
                            size: 9.5
                            weight: Font.Bold
                            color: "#38BDF8"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: "#38BDF8"
                            text: (islandWin.networkStatus && islandWin.networkStatus.combinedCompact) ? islandWin.networkStatus.combinedCompact : "0K"
                        }
                    }

                    // CPU Temperature & Flame (No Numeric Values)
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        visible: islandWin.activeRightWingWidget === "cpu_temp_flame"

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 10; height: 10
                            path: Icons.flame
                            color: rightWingContainer.cpuThermalColor
                            scale: (rightWingContainer.cpuTempCVal >= 80) ? 1.15 : 1.0
                            Behavior on scale { NumberAnimation { duration: 250 } }
                        }
                    }

                    // CPU Load & Activity
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        visible: islandWin.activeRightWingWidget === "cpu_load"

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 9.5; height: 9.5
                            path: Icons.cpu
                            color: rightWingContainer.cpuThermalColor
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: rightWingContainer.cpuThermalColor
                            text: Math.round(rightWingContainer.cpuPercentVal) + "%"
                        }
                    }

                    // Battery & Power Status
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        visible: islandWin.activeRightWingWidget === "battery"

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 9.0; height: 9.0
                            path: (islandWin.sysBattery && (islandWin.sysBattery.isCharging || islandWin.sysBattery.isPluggedIn)) ? Icons.bolt : Icons.battery
                            color: (islandWin.sysBattery && (islandWin.sysBattery.isCharging || islandWin.sysBattery.isPluggedIn)) ? "#4ADE80" : ((islandWin.sysBattery && islandWin.sysBattery.level <= 20) ? "#EF4444" : "#FFFFFF")
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: "#FFFFFF"
                            text: (islandWin.sysBattery && islandWin.sysBattery.level !== undefined) ? (Math.round(islandWin.sysBattery.level) + "%") : "100%"
                        }
                    }

                    // Now Playing Media & Visualizer
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        visible: islandWin.activeRightWingWidget === "media"

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 9.0; height: 9.0
                            path: Icons.music
                            color: "#10B981"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.DemiBold
                            color: "#FFFFFF"
                            text: islandWin.mediaTitle || qsTr("Music")
                            elide: Text.ElideRight
                            width: Math.min(65, implicitWidth)
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            visible: !islandWin.rightHovered
                            Rectangle { width: 2.5; height: islandWin.visualizerBar1; radius: 1.25; color: "#10B981"; anchors.verticalCenter: parent.verticalCenter }
                            Rectangle { width: 2.5; height: islandWin.visualizerBar2; radius: 1.25; color: "#10B981"; anchors.verticalCenter: parent.verticalCenter }
                            Rectangle { width: 2.5; height: islandWin.visualizerBar3; radius: 1.25; color: "#10B981"; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }

                    // Crypto Ticker
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        visible: islandWin.activeRightWingWidget === "crypto"

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.0
                            weight: Font.Bold
                            color: "#F59E0B"
                            text: "BTC"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.DemiBold
                            color: "#FFFFFF"
                            text: (islandWin.isleFinance && islandWin.isleFinance.price) ? islandWin.isleFinance.price : "$94.2K"
                        }
                    }

                    // RAM Details (Used / Total)
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3.5
                        visible: islandWin.activeRightWingWidget === "ram_details"

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8.5; height: 8.5
                            path: Icons.memorychip
                            color: "#A855F7"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 8.5
                            weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.50)
                            text: "RAM"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: "#FFFFFF"
                            text: ((rightWingContainer.ramPercentVal / 100.0) * 16.0).toFixed(1) + "G/16G"
                        }
                    }

                    // RAM Pressure
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3.5
                        visible: islandWin.activeRightWingWidget === "ram_pressure"

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8.5; height: 8.5
                            path: Icons.compass
                            color: rightWingContainer.ramBarColor
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 8.5
                            weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.50)
                            text: "PRESS"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: rightWingContainer.ramBarColor
                            text: islandWin.rightHovered
                                ? ((rightWingContainer.ramPercentVal > 80 ? "Critical" : (rightWingContainer.ramPercentVal > 60 ? "Warning" : "Normal")) + " " + Math.round(rightWingContainer.ramPercentVal) + "%")
                                : (rightWingContainer.ramPercentVal > 80 ? "Critical" : (rightWingContainer.ramPercentVal > 60 ? "Warning" : "Normal"))
                        }
                    }

                    // Download Speed
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3.5
                        visible: islandWin.activeRightWingWidget === "net_down"

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8.5; height: 8.5
                            path: Icons.arrowDown
                            color: "#22C55E"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 8.5
                            weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.50)
                            text: "DL"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: "#FFFFFF"
                            text: islandWin.rightHovered
                                ? ((islandWin.networkStatus && islandWin.networkStatus.combinedCompact) ? islandWin.networkStatus.combinedCompact : "0K")
                                : ((islandWin.networkStatus && islandWin.networkStatus.downloadCompact) ? islandWin.networkStatus.downloadCompact : "0K")
                        }
                    }

                    // Upload Speed
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3.5
                        visible: islandWin.activeRightWingWidget === "net_up"

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8.5; height: 8.5
                            path: Icons.arrowUp
                            color: "#38BDF8"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 8.5
                            weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.50)
                            text: "UL"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: "#FFFFFF"
                            text: islandWin.rightHovered
                                ? ((islandWin.networkStatus && islandWin.networkStatus.combinedCompact) ? islandWin.networkStatus.combinedCompact : "0K")
                                : ((islandWin.networkStatus && islandWin.networkStatus.uploadCompact) ? islandWin.networkStatus.uploadCompact : "0K")
                        }
                    }

                    // Bluetooth Device Battery
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3.5
                        visible: islandWin.activeRightWingWidget === "bluetooth_battery"

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8.5; height: 8.5
                            path: Icons.bluetooth
                            color: "#3B82F6"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 8.5
                            weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.50)
                            text: "BT"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: "#FFFFFF"
                            text: (islandWin.atollHud && islandWin.atollHud.bluetoothBattery) ? (islandWin.atollHud.bluetoothBattery + "%") : "85%"
                        }
                    }

                    // System Volume
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3.5
                        visible: islandWin.activeRightWingWidget === "volume"

                        readonly property bool isMuted: !!(islandWin.quietnotchHud && islandWin.quietnotchHud.isMuted)
                        readonly property int volVal: (islandWin.quietnotchHud && islandWin.quietnotchHud.kind === "volume") ? Math.round(islandWin.quietnotchHud.value * 100) : 65

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8.5; height: 8.5
                            path: parent.isMuted ? Icons.soundOff : Icons.speaker
                            color: parent.isMuted ? "#EF4444" : "#38BDF8"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 8.5
                            weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.50)
                            text: "VOL"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: parent.isMuted ? "#EF4444" : "#FFFFFF"
                            text: parent.isMuted ? "Mute" : (parent.volVal + "%")
                        }
                    }

                    // Display Brightness
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3.5
                        visible: islandWin.activeRightWingWidget === "brightness"

                        readonly property int brtVal: (islandWin.quietnotchHud && islandWin.quietnotchHud.kind === "brightness") ? Math.round(islandWin.quietnotchHud.value * 100) : 75

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8.5; height: 8.5
                            path: Icons.brightness
                            color: "#FBBF24"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 8.5
                            weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.50)
                            text: "BRT"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: "#FFFFFF"
                            text: parent.brtVal + "%"
                        }
                    }

                    // Clock & Date
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3.5
                        visible: islandWin.activeRightWingWidget === "clock"

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8.5; height: 8.5
                            path: Icons.clock
                            color: Qt.rgba(1, 1, 1, 0.85)
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: "#FFFFFF"
                            text: islandWin.rightHovered ? (islandWin.liveClockStr + " • " + Qt.formatDate(new Date(), "ddd MMM d")) : islandWin.liveClockStr
                        }
                    }

                    // Ambient Weather
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3.5
                        visible: islandWin.activeRightWingWidget === "weather"

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8.5; height: 8.5
                            path: Icons.brightness
                            color: "#FB923C"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 8.5
                            weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.50)
                            text: "WX"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: "#FFFFFF"
                            text: "72° Sunny"
                        }
                    }

                    // Interactive Media Controls (Copied from Dynamo)
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        visible: islandWin.activeRightWingWidget === "media_controls"

                        Rectangle {
                            width: 14; height: 14; radius: 7
                            color: prevBtnAreaR.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.10)
                            anchors.verticalCenter: parent.verticalCenter
                            Icon { anchors.centerIn: parent; width: 8.0; height: 8.0; path: Icons.skipPrevious; color: Qt.rgba(1, 1, 1, 0.85) }
                            MouseArea {
                                id: prevBtnAreaR
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: islandWin.prevMedia()
                            }
                        }

                        Rectangle {
                            width: 16; height: 16; radius: 8
                            color: playBtnAreaR.containsMouse ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.15)
                            anchors.verticalCenter: parent.verticalCenter
                            Icon {
                                anchors.centerIn: parent
                                width: 8.5; height: 8.5
                                path: (islandWin.mediaPlaying || islandWin.localMediaPlaying) ? Icons.pause : Icons.play
                                color: "#10B981"
                            }
                            MouseArea {
                                id: playBtnAreaR
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: islandWin.playPauseMedia()
                            }
                        }

                        Rectangle {
                            width: 14; height: 14; radius: 7
                            color: nextBtnAreaR.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.10)
                            anchors.verticalCenter: parent.verticalCenter
                            Icon { anchors.centerIn: parent; width: 8.0; height: 8.0; path: Icons.skipNext; color: Qt.rgba(1, 1, 1, 0.85) }
                            MouseArea {
                                id: nextBtnAreaR
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: islandWin.nextMedia()
                            }
                        }
                    }

                    // Phone Battery (MacLink Bridge)
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3.5
                        visible: islandWin.activeRightWingWidget === "phone_battery"

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8.5; height: 8.5
                            path: Icons.phone
                            color: "#4ADE80"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 8.5
                            weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.50)
                            text: "PHN"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: "#FFFFFF"
                            text: (typeof DeviceList !== "undefined" && DeviceList && DeviceList.count > 0 && typeof DeviceList.batteryAt === "function" && DeviceList.batteryAt(0) !== undefined) ? (DeviceList.batteryAt(0) + "%") : "88%"
                        }
                    }

                    // Cellular Signal
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3.5
                        visible: islandWin.activeRightWingWidget === "phone_signal"

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8.5; height: 8.5
                            path: Icons.signal
                            color: "#38BDF8"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 8.5
                            weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.50)
                            text: "CELL"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: "#FFFFFF"
                            text: "5G"
                        }
                    }

                    // Keep Awake (Caffeinate)
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3.5
                        visible: islandWin.activeRightWingWidget === "keep_awake"

                        property bool isCafActive: DynamoController ? DynamoController.isCaffeinateActive() : false

                        Rectangle {
                            width: 16; height: 16; radius: 8
                            color: parent.isCafActive ? Qt.rgba(0.96, 0.62, 0.04, 0.35) : (cafWidgetAreaR.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12))
                            anchors.verticalCenter: parent.verticalCenter
                            Icon {
                                anchors.centerIn: parent
                                width: 8.5; height: 8.5
                                path: Icons.coffee
                                color: parent.parent.isCafActive ? "#FBBF24" : Qt.rgba(1, 1, 1, 0.60)
                            }
                            MouseArea {
                                id: cafWidgetAreaR
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (DynamoController && typeof DynamoController.toggleCaffeinate === "function") {
                                        parent.parent.isCafActive = DynamoController.toggleCaffeinate()
                                    }
                                }
                            }
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 8.5
                            weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.50)
                            text: "AWK"
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            size: 9.5
                            weight: Font.Bold
                            color: parent.isCafActive ? "#FBBF24" : Qt.rgba(1, 1, 1, 0.60)
                            text: parent.isCafActive ? "ON" : "OFF"
                        }
                    }
                }
            }

            HoverHandler {
                id: rightWingHoverHandler
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onHoveredChanged: {
                    islandWin.rightHovered = hovered
                }
            }

            MouseArea {
                id: rightWingMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    islandWin.rightHovered = true
                    islandWin.isHoverExpanded = true
                    autoCollapseTimer.stop()
                }
                onExited: {
                    islandWin.rightHovered = false
                    islandWin.checkHoverState()
                }
                onClicked: {
                    islandWin.userPinnedOpen = !islandWin.userPinnedOpen
                    if (islandWin.userPinnedOpen) autoCollapseTimer.restart()
                }
            }
        }

        // ====================================================================
        // 5. EXPANDED DYNAMIC ISLAND (DynamicIslandShape + 5-Layer Liquid Glass)
        // ====================================================================
        Item {
            id: expandedIslandContainer
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: islandWin.width
            height: islandWin.height
            visible: islandWin.expanded
            opacity: islandWin.expanded ? 1.0 : 0.0
            z: 2

            Behavior on opacity { NumberAnimation { duration: 160 } }


            // Layer 1: Hardware-Notch Continuous Squircle Shape (Concave Ears + 28px Rounded Squircle Chin - 30% Transparency)
            Shape {
                id: dynamicIslandBgShape
                anchors.fill: parent
                visible: islandWin.isNotchAttached
                preferredRendererType: Shape.CurveRenderer
                asynchronous: true

                ShapePath {
                    startX: 0; startY: -1.0
                    fillGradient: LinearGradient {
                        x1: 0; y1: 0; x2: 0; y2: dynamicIslandBgShape.height
                        GradientStop { position: 0.00; color: Qt.rgba(0.06, 0.07, 0.09, 0.72) }
                        GradientStop { position: 0.35; color: Qt.rgba(0.04, 0.05, 0.07, 0.70) }
                        GradientStop { position: 0.75; color: Qt.rgba(0.02, 0.02, 0.04, 0.70) }
                        GradientStop { position: 1.00; color: Qt.rgba(0.01, 0.01, 0.02, 0.70) }
                    }
                    strokeGradient: LinearGradient {
                        x1: 0; y1: 0; x2: 0; y2: dynamicIslandBgShape.height
                        GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.16) }
                        GradientStop { position: 0.50; color: Qt.rgba(1, 1, 1, 0.08) }
                        GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, 0.22) }
                    }
                    strokeWidth: 1.0
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin

                    // Concave top-left ear: curves downward and inward into notch left side
                    PathQuad { x: 8.0; y: 6.0; controlX: 8.0; controlY: -1.0 }
                    // Left vertical edge
                    PathLine { x: 8.0; y: dynamicIslandBgShape.height - 28.0 }
                    // Convex bottom-left corner with Apple continuous smoothing (0.448 factor)
                    PathCubic {
                        x: 8.0 + 28.0; y: dynamicIslandBgShape.height
                        control1X: 8.0; control1Y: dynamicIslandBgShape.height - 28.0 * 0.448
                        control2X: 8.0 + 28.0 * 0.448; control2Y: dynamicIslandBgShape.height
                    }
                    // Bottom horizontal chin edge
                    PathLine { x: dynamicIslandBgShape.width - 8.0 - 28.0; y: dynamicIslandBgShape.height }
                    // Convex bottom-right corner with Apple continuous smoothing (0.448 factor)
                    PathCubic {
                        x: dynamicIslandBgShape.width - 8.0; y: dynamicIslandBgShape.height - 28.0
                        control1X: dynamicIslandBgShape.width - 8.0 - 28.0 * 0.448; control1Y: dynamicIslandBgShape.height
                        control2X: dynamicIslandBgShape.width - 8.0; control2Y: dynamicIslandBgShape.height - 28.0 * 0.448
                    }
                    // Upward vertical right edge
                    PathLine { x: dynamicIslandBgShape.width - 8.0; y: 6.0 }
                    // Concave top-right ear: curves outward to top-right bezel
                    PathQuad { x: dynamicIslandBgShape.width; y: -1.0; controlX: dynamicIslandBgShape.width - 8.0; controlY: -1.0 }
                    // Top horizontal edge closing the shape
                    PathLine { x: 0; y: -1.0 }
                }
            }

            // Layer 1 (Fallback for Non-notched Displays): 28px Rounded Rectangle (30% Transparency)
            Rectangle {
                anchors.fill: parent
                radius: 28
                visible: !islandWin.isNotchAttached
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.00; color: Qt.rgba(0.06, 0.07, 0.09, 0.72) }
                    GradientStop { position: 1.00; color: Qt.rgba(0.01, 0.01, 0.02, 0.70) }
                }
                border.width: 1.0
                border.color: Qt.rgba(1, 1, 1, 0.22)
            }

            // Interactive Gestures on Expanded Island
            WheelHandler {
                id: expWheel
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => {
                    // Do not steal wheel events if cursor is over scrollable views (like clipboard, launcher, teleprompter, emoji)
                    if (islandWin.activeTab === "clipboard" || islandWin.activeTab === "launcher" || islandWin.activeTab === "teleprompter" || islandWin.activeTab === "emojiPicker") {
                        event.accepted = false
                        return
                    }
                    if (!Preferences.notchScrollGestures) return
                    const step = event.angleDelta.y > 0 ? 5 : -5
                    try {
                        const st = JSON.parse(DynamoController.systemHudJson || "{}")
                        const cur = st.event && st.event.percent !== undefined ? st.event.percent : 50
                        const isBrightness = st.event && st.event.kind === "brightness"
                        if (isBrightness) {
                            DynamoController.setBrightness(Math.max(0, Math.min(100, cur + step)))
                        } else {
                            DynamoController.setVolume(Math.max(0, Math.min(100, cur + step)), false)
                        }
                    } catch (e) {
                        DynamoController.setVolume(50 + step, false)
                    }
                }
            }

            HoverHandler {
                id: expHoverHandler
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onHoveredChanged: {
                    islandWin.expHovered = hovered
                    if (!hovered) {
                        autoCollapseTimer.restart()
                    } else {
                        autoCollapseTimer.stop()
                    }
                }
            }

            MouseArea {
                id: expMouseArea
                z: 0
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onEntered: {
                    islandWin.expHovered = true
                    autoCollapseTimer.stop()
                }
                onExited: {
                    islandWin.expHovered = false
                    islandWin.checkHoverState()
                }
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        DynamoController.toggleGestureTarget()
                        return
                    }
                    // Click in top notch area toggles/collapses back to Menu Bar
                    if (mouse.y <= (islandWin.centerNotchHeight + 10) && Math.abs(mouse.x - (width / 2.0)) <= (islandWin.centerNotchWidth / 2.0 + 30)) {
                        islandWin.userPinnedOpen = !islandWin.userPinnedOpen
                        return
                    }
                    if (expandedControlsRow.visible) {
                        const p = expandedControlsRow.mapFromItem(expandedIslandContainer, mouse.x, mouse.y)
                        if (p.x >= 0 && p.y >= 0 && p.x <= expandedControlsRow.width && p.y <= expandedControlsRow.height)
                            return
                    }
                    // Pin island open cleanly without opening the main MacLink app window
                    islandWin.userPinnedOpen = true
                }
            }

            // ================================================================
            // EXPANDED CONTENT INTERIOR (Top Toolbar, Home Cards, Activities)
            // ================================================================
            IslandToolbar {
                id: islandTopToolbar
                z: 20
                anchors.top: parent.top
                anchors.topMargin: islandWin.isNotchAttached ? 4 : 4
                anchors.left: parent.left
                anchors.right: parent.right
                centerNotchWidth: islandWin.centerNotchWidth
                centerNotchHeight: islandWin.centerNotchHeight
                hasPhysicalNotch: islandWin.isNotchAttached
                activeTab: islandWin.activeTab
                onHomeClicked: {
                    islandWin.activeTab = "home"
                    islandWin.userPinnedOpen = true
                }
                onMoreClicked: (mouse) => {
                    morePopover.isOpen = !morePopover.isOpen
                }
                onEditClicked: {
                    editSheet.isOpen = true
                }
                onToolSelected: (toolId) => {
                    islandWin.userPinnedOpen = true
                    if (toolId === "music") islandWin.activeTab = "media"
                    else if (toolId === "home") islandWin.activeTab = "home"
                    else if (toolId === "launcher") islandWin.activeTab = "launcher"
                    else if (toolId === "clipboard") islandWin.activeTab = "clipboard"
                    else if (toolId === "teleprompter") islandWin.activeTab = "teleprompter"
                    else if (toolId === "emojiPicker") islandWin.activeTab = "emojiPicker"
                }
            }

            // Interior Area 1: Home Dashboard (4 Cards)
            IslandHomeCards {
                id: homeDashboardView
                z: 10
                anchors.top: islandTopToolbar.bottom
                anchors.topMargin: 2
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.bottomMargin: 16
                clip: true
                visible: (islandWin.activeTab === "home") && !agentApprovalBanner.visible && !agentQuestionCard.visible && !quickShareArrivalCard.visible
                onRequestTab: (tab) => islandWin.activeTab = tab
            }

            // Interior Area 2: Live Activity / Media / Call / Transfer
            Item {
                id: expContent
                anchors.top: islandTopToolbar.bottom
                anchors.topMargin: 4
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.bottomMargin: 16
                clip: true
                visible: (islandWin.activeTab !== "home" && islandWin.activeTab !== "launcher" && islandWin.activeTab !== "clipboard") && !agentApprovalBanner.visible && !agentQuestionCard.visible && !quickShareArrivalCard.visible

                // Left slot: Album Art / Progress Ring / Call Pulse (48×48px)
                Item {
                    id: expLeftSlot
                    width: 48
                    height: 48
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        visible: islandWin.mode === "media"
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.24)
                        Icon {
                            anchors.centerIn: parent
                            width: 22; height: 22
                            visible: !(islandWin.mediaArt.length > 0 && expArtImg.status === Image.Ready)
                            path: Icons.music
                            color: Theme.primary
                        }
                        RoundedImage {
                            id: expArtImg
                            anchors.fill: parent
                            radius: 12
                            source: islandWin.mediaArt
                            sourceSize: Qt.size(112, 112)
                        }
                    }

                    Item {
                        anchors.fill: parent
                        visible: islandWin.mode === "transfer"

                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                strokeColor: Qt.rgba(1, 1, 1, 0.16)
                                fillColor: "transparent"
                                strokeWidth: 3.4
                                capStyle: ShapePath.RoundCap
                                PathAngleArc {
                                    centerX: 24; centerY: 24
                                    radiusX: 19; radiusY: 19
                                    startAngle: 0; sweepAngle: 360
                                }
                            }
                            ShapePath {
                                strokeColor: islandWin.transferJustFinished ? "#4ADE80" : Theme.primary
                                fillColor: "transparent"
                                strokeWidth: 3.4
                                capStyle: ShapePath.RoundCap
                                PathAngleArc {
                                    centerX: 24; centerY: 24
                                    radiusX: 19; radiusY: 19
                                    startAngle: -90
                                    sweepAngle: 360 * (islandWin.transferJustFinished ? 1.0 : Math.max(0.06, islandWin.activeTransferProgress))
                                }
                            }
                        }

                        Txt {
                            anchors.centerIn: parent
                            size: 10
                            weight: Font.Bold
                            color: "#FFFFFF"
                            text: islandWin.transferJustFinished
                                ? "100%"
                                : (Math.round(islandWin.activeTransferProgress * 100) + "%")
                        }
                    }

                    // Download progress ring (poshak2004/island reverse-engineered)
                    Item {
                        anchors.fill: parent
                        visible: islandWin.mode === "download"

                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                strokeColor: Qt.rgba(1, 1, 1, 0.16)
                                fillColor: "transparent"
                                strokeWidth: 3.4
                                capStyle: ShapePath.RoundCap
                                PathAngleArc {
                                    centerX: 24; centerY: 24
                                    radiusX: 19; radiusY: 19
                                    startAngle: 0; sweepAngle: 360
                                }
                            }
                            ShapePath {
                                strokeColor: "#38BDF8"
                                fillColor: "transparent"
                                strokeWidth: 3.4
                                capStyle: ShapePath.RoundCap
                                PathAngleArc {
                                    centerX: 24; centerY: 24
                                    radiusX: 19; radiusY: 19
                                    startAngle: -90
                                    sweepAngle: 360 * Math.max(0.06, (islandWin.downloadsData && islandWin.downloadsData.downloads && islandWin.downloadsData.downloads.length > 0) ? islandWin.downloadsData.downloads[0].fraction : 0.0)
                                }
                            }
                        }

                        Icon {
                            anchors.centerIn: parent
                            width: 16; height: 16
                            path: Icons.download
                            color: "#38BDF8"
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 24
                        visible: islandWin.mode === "call" || islandWin.mode === "notification" || islandWin.mode === "waiting" || islandWin.mode === "idle"
                        color: islandWin.mode === "call"
                            ? Qt.rgba(0.29, 0.87, 0.50, 0.22)
                            : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
                        Icon {
                            anchors.centerIn: parent
                            width: 22; height: 22
                            path: islandWin.mode === "call"
                                ? Icons.call
                                : (islandWin.mode === "notification"
                                    ? Icons.bell
                                    : (islandWin.mode === "waiting" ? Icons.send : Icons.phone))
                            color: islandWin.mode === "call" ? "#4ADE80" : Theme.primary
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        visible: islandWin.mode === "hud"
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.24)
                        Icon {
                            anchors.centerIn: parent
                            width: 22; height: 22
                            path: (islandWin.hudEvent && islandWin.hudEvent.kind === "brightness") ? Icons.brightness : Icons.volumeUp
                            color: Theme.primary
                        }
                    }
                }

                // Center title + subtitle + progress bar
                Column {
                    anchors.left: expLeftSlot.right
                    anchors.leftMargin: 12
                    anchors.right: expandedControlsRow.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Txt {
                        width: parent.width
                        role: "title"
                        size: 13
                        weight: Font.DemiBold
                        color: "#FFFFFF"
                        elide: Text.ElideRight
                        text: islandWin.primaryLabel
                    }

                    Txt {
                        width: parent.width
                        role: "caption"
                        size: 11
                        color: Qt.rgba(1, 1, 1, 0.68)
                        elide: Text.ElideRight
                        text: islandWin.secondaryLabel
                    }

                    Rectangle {
                        visible: (islandWin.mode === "media" && islandWin.mediaDuration > 0) || islandWin.mode === "transfer" || islandWin.mode === "hud"
                        width: parent.width
                        height: 3.5
                        radius: 1.75
                        color: Qt.rgba(1, 1, 1, 0.16)

                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            color: islandWin.mode === "transfer" && islandWin.transferJustFinished ? "#4ADE80" : Theme.primary
                            width: {
                                if (islandWin.mode === "hud")
                                    return parent.width * Math.min(1.0, Math.max(0.0, ((islandWin.hudEvent && islandWin.hudEvent.percent !== undefined) ? islandWin.hudEvent.percent : 0) / 100))
                                if (islandWin.mode === "transfer")
                                    return parent.width * (islandWin.transferJustFinished ? 1.0 : Math.max(0.04, islandWin.activeTransferProgress))
                                if (islandWin.mediaDuration > 0)
                                    return parent.width * Math.max(0, Math.min(1, islandWin.mediaPosition / islandWin.mediaDuration))
                                return 0
                            }
                            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                // Right action buttons in expanded island
                Row {
                    id: expandedControlsRow
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    // Call controls: Answer, Mute, Hang up
                    Rectangle {
                        visible: islandWin.mode === "call" && PhoneCall.ringing && PhoneCall.canEnd
                        width: 32; height: 32; radius: 16
                        color: "#22C55E"
                        Icon {
                            anchors.centerIn: parent
                            width: 15; height: 15
                            path: Icons.call
                            color: "#FFFFFF"
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: PhoneCall.answer() }
                    }

                    Rectangle {
                        visible: islandWin.mode === "call" && !PhoneCall.ringing && PhoneCall.controls
                        width: 30; height: 30; radius: 15
                        color: PhoneCall.muted ? Qt.rgba(1, 1, 1, 0.26) : Qt.rgba(1, 1, 1, 0.12)
                        Icon {
                            anchors.centerIn: parent
                            width: 14; height: 14
                            path: PhoneCall.muted ? Icons.micOff : Icons.mic
                            color: "#FFFFFF"
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: PhoneCall.setMute(!PhoneCall.muted) }
                    }

                    Rectangle {
                        visible: islandWin.mode === "call" && PhoneCall.canEnd
                        width: 32; height: 32; radius: 16
                        color: "#EF4444"
                        Icon {
                            anchors.centerIn: parent
                            width: 15; height: 15
                            path: Icons.callEnd
                            color: "#FFFFFF"
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: PhoneCall.end() }
                    }

                    // Media controls: Previous, Play/Pause, Next
                    Rectangle {
                        visible: islandWin.mode === "media" && islandWin.mediaCanPrev
                        width: 28; height: 28; radius: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: expPrevHover.hovered ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.08)
                        Icon {
                            anchors.centerIn: parent
                            width: 13; height: 13
                            path: Icons.skipPrevious
                            color: "#FFFFFF"
                        }
                        HoverHandler { id: expPrevHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                if (islandWin.mediaDeviceId === "local_system" || Preferences.notchSystemMedia) {
                                    DynamoController.mediaPrevious()
                                } else {
                                    MediaList.command(islandWin.mediaDeviceId, islandWin.mediaPlayerId, "previous", 0)
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: islandWin.mode === "media"
                        width: 34; height: 34; radius: 17
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.primary
                        Icon {
                            anchors.centerIn: parent
                            width: 15; height: 15
                            path: islandWin.mediaPlaying ? Icons.pause : Icons.play
                            color: Theme.primaryContent
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                if (islandWin.mediaDeviceId === "local_system" || Preferences.notchSystemMedia) {
                                    DynamoController.mediaPlayPause()
                                } else {
                                    MediaList.command(
                                        islandWin.mediaDeviceId,
                                        islandWin.mediaPlayerId,
                                        islandWin.mediaPlaying ? "pause" : "play",
                                        0
                                    )
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: islandWin.mode === "media" && islandWin.mediaCanNext
                        width: 28; height: 28; radius: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: expNextHover.hovered ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.08)
                        Icon {
                            anchors.centerIn: parent
                            width: 13; height: 13
                            path: Icons.skipNext
                            color: "#FFFFFF"
                        }
                        HoverHandler { id: expNextHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                if (islandWin.mediaDeviceId === "local_system" || Preferences.notchSystemMedia) {
                                    DynamoController.mediaNext()
                                } else {
                                    MediaList.command(islandWin.mediaDeviceId, islandWin.mediaPlayerId, "next", 0)
                                }
                            }
                        }
                    }

                    // Transfer cancel button
                    Rectangle {
                        visible: islandWin.mode === "transfer" && !islandWin.transferJustFinished && islandWin.activeTransferId.length > 0
                        width: 28; height: 28; radius: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: expCancelHover.hovered ? Qt.rgba(1, 0.3, 0.3, 0.28) : Qt.rgba(1, 1, 1, 0.10)
                        Icon {
                            anchors.centerIn: parent
                            width: 13; height: 13
                            path: Icons.close
                            color: "#FFFFFF"
                        }
                        HoverHandler { id: expCancelHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: TransferList.cancel(islandWin.activeTransferId)
                        }
                    }

                    // Download controls (poshak2004/island reverse-engineered)
                    Row {
                        visible: islandWin.mode === "download"
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Rectangle {
                            width: 28; height: 28; radius: 14
                            color: expRevealHover.hovered ? Qt.rgba(0.22, 0.74, 0.97, 0.28) : Qt.rgba(1, 1, 1, 0.10)
                            Icon {
                                anchors.centerIn: parent
                                width: 13; height: 13
                                path: Icons.folder || Icons.window
                                color: "#38BDF8"
                            }
                            HoverHandler { id: expRevealHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    const first = (islandWin.downloadsData && islandWin.downloadsData.downloads && islandWin.downloadsData.downloads.length > 0) ? islandWin.downloadsData.downloads[0] : null
                                    if (first) DynamoController.revealDownload(first.id)
                                }
                            }
                        }

                        Rectangle {
                            width: 28; height: 28; radius: 14
                            color: expDlCancelHover.hovered ? Qt.rgba(1, 0.3, 0.3, 0.28) : Qt.rgba(1, 1, 1, 0.10)
                            Icon {
                                anchors.centerIn: parent
                                width: 13; height: 13
                                path: Icons.close
                                color: "#FFFFFF"
                            }
                            HoverHandler { id: expDlCancelHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    const first = (islandWin.downloadsData && islandWin.downloadsData.downloads && islandWin.downloadsData.downloads.length > 0) ? islandWin.downloadsData.downloads[0] : null
                                    if (first) DynamoController.cancelDownload(first.id)
                                }
                            }
                        }
                    }

                    // Modular Add-on Tools (Idle / Telemetry / HUD)
                    Row {
                        visible: islandWin.mode !== "call" && islandWin.mode !== "media" && islandWin.mode !== "transfer" && islandWin.mode !== "download"
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Rectangle {
                            width: 28; height: 28; radius: 14
                            anchors.verticalCenter: parent.verticalCenter
                            color: expDropHover.hovered ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.08)
                            Icon {
                                anchors.centerIn: parent
                                width: 13; height: 13
                                path: Icons.palette
                                color: Theme.primary
                            }
                            HoverHandler { id: expDropHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: DynamoController.pickScreenColor() }
                        }

                        Rectangle {
                            width: 28; height: 28; radius: 14
                            anchors.verticalCenter: parent.verticalCenter
                            color: expMountHover.hovered ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.08)
                            Icon {
                                anchors.centerIn: parent
                                width: 13; height: 13
                                path: Icons.desktop
                                color: Theme.primary
                            }
                            HoverHandler { id: expMountHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    const devId = DeviceList.count > 0 ? DeviceList.deviceIdAt(0) : ""
                                    DynamoController.phoneBridgeMountInFinder(devId)
                                }
                            }
                        }

                        Rectangle {
                            width: 28; height: 28; radius: 14
                            anchors.verticalCenter: parent.verticalCenter
                            color: expShelfHover.hovered ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.08)
                            Icon {
                                anchors.centerIn: parent
                                width: 13; height: 13
                                path: Icons.shelf
                                color: Theme.primary
                            }
                            HoverHandler { id: expShelfHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: AppController.toggleShelf() }
                        }
                    }
                }
            }

            // Interior Area 3: AI Agent Approval Request Card (Coucou Hook Relay)
            Item {
                id: agentApprovalBanner
                anchors.top: islandTopToolbar.bottom
                anchors.topMargin: 4
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.bottomMargin: 10
                visible: !!(Preferences.notchAgentHooksEnabled && islandWin.agentHook && islandWin.agentHook.hasApproval)
                z: 20

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: Qt.rgba(0.12, 0.08, 0.04, 0.95)
                    border.width: 1.2
                    border.color: "#F97316"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Rectangle {
                            width: 36; height: 36; radius: 18
                            color: Qt.rgba(0.97, 0.45, 0.08, 0.25)
                            border.width: 1
                            border.color: "#F97316"
                            anchors.verticalCenter: parent.verticalCenter
                            Icon {
                                anchors.centerIn: parent
                                width: 18; height: 18
                                path: Icons.shield
                                color: "#F97316"
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3
                            width: agentApprovalBanner.width - 200

                            Txt {
                                text: ((islandWin.agentHook && islandWin.agentHook.agentName) ? islandWin.agentHook.agentName : "AI Agent") + " Permission Required"
                                weight: Font.DemiBold
                                size: 12
                                color: "#FFFFFF"
                            }

                            Txt {
                                text: (islandWin.agentHook && islandWin.agentHook.approvalPrompt) ? islandWin.agentHook.approvalPrompt : qsTr("Approve action execution?")
                                size: 10.5
                                color: Qt.rgba(1, 1, 1, 0.78)
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                    }

                    // Action buttons: Jump to Terminal, Deny & Allow
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Rectangle {
                            width: 28; height: 28; radius: 6
                            color: Qt.rgba(1, 1, 1, 0.12)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.22)
                            visible: Preferences.notchTerminalJumperEnabled
                            Icon {
                                anchors.centerIn: parent
                                width: 14; height: 14
                                path: Icons.desktop || Icons.mirror
                                color: "#38BDF8"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: DynamoController.jumpToTerminal("")
                            }
                        }

                        Rectangle {
                            width: 64; height: 28; radius: 6
                            color: Qt.rgba(1, 1, 1, 0.12)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.22)
                            Txt {
                                anchors.centerIn: parent
                                text: qsTr("Deny")
                                size: 11
                                weight: Font.Medium
                                color: "#FCA5A5"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: DynamoController.respondAgentApproval(false)
                            }
                        }

                        Rectangle {
                            width: 68; height: 28; radius: 6
                            color: "#22C55E"
                            Txt {
                                anchors.centerIn: parent
                                text: qsTr("Allow")
                                size: 11
                                weight: Font.DemiBold
                                color: "#FFFFFF"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: DynamoController.respondAgentApproval(true)
                            }
                        }
                    }
                }
            }

            // Interior Area 4: AI Agent Question Resolution Card (CodeIsland reverse-engineered)
            Item {
                id: agentQuestionCard
                anchors.top: islandTopToolbar.bottom
                anchors.topMargin: 4
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.bottomMargin: 10
                visible: !!(Preferences.notchAgentHooksEnabled && islandWin.agentQuestion && islandWin.agentQuestion.hasQuestion && !agentApprovalBanner.visible)
                z: 21

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: Qt.rgba(0.06, 0.08, 0.14, 0.96)
                    border.width: 1.2
                    border.color: "#3B82F6"

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        Row {
                            width: parent.width
                            spacing: 10

                            Rectangle {
                                width: 32; height: 32; radius: 16
                                color: Qt.rgba(0.23, 0.51, 0.96, 0.25)
                                border.width: 1
                                border.color: "#3B82F6"
                                anchors.verticalCenter: parent.verticalCenter
                                Icon {
                                    anchors.centerIn: parent
                                    width: 16; height: 16
                                    path: Icons.info
                                    color: "#3B82F6"
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                width: parent.width - 80

                                Txt {
                                    text: ((islandWin.agentQuestion && islandWin.agentQuestion.agentName) ? islandWin.agentQuestion.agentName : "AI Agent") + " Question"
                                    weight: Font.DemiBold
                                    size: 11.5
                                    color: "#60A5FA"
                                }

                                Txt {
                                    text: (islandWin.agentQuestion && islandWin.agentQuestion.question) ? islandWin.agentQuestion.question : ""
                                    size: 11
                                    color: "#FFFFFF"
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.Wrap
                                    width: parent.width
                                }
                            }

                            Rectangle {
                                width: 26; height: 26; radius: 6
                                color: Qt.rgba(1, 1, 1, 0.12)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.22)
                                visible: Preferences.notchTerminalJumperEnabled
                                anchors.verticalCenter: parent.verticalCenter
                                Icon {
                                    anchors.centerIn: parent
                                    width: 13; height: 13
                                    path: Icons.desktop || Icons.mirror
                                    color: "#38BDF8"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: DynamoController.jumpToTerminal("")
                                }
                            }
                        }

                        // Options Flow
                        Flow {
                            width: parent.width
                            spacing: 8

                            Repeater {
                                model: (islandWin.agentQuestion && islandWin.agentQuestion.options) ? islandWin.agentQuestion.options : []
                                delegate: Rectangle {
                                    height: 28
                                    width: Math.min(optTxt.implicitWidth + 24, agentQuestionCard.width / 2 - 12)
                                    radius: 6
                                    color: optMouse.containsMouse ? "#2563EB" : Qt.rgba(1, 1, 1, 0.12)
                                    border.width: 1
                                    border.color: optMouse.containsMouse ? "#60A5FA" : Qt.rgba(1, 1, 1, 0.24)

                                    Txt {
                                        id: optTxt
                                        anchors.centerIn: parent
                                        text: modelData
                                        size: 11
                                        weight: Font.Medium
                                        color: "#FFFFFF"
                                        elide: Text.ElideRight
                                        width: Math.min(implicitWidth, parent.width - 12)
                                    }

                                    MouseArea {
                                        id: optMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: DynamoController.answerAgentQuestion(index)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Interior Area 5: Quick Share Incoming Request Card (SquickShare reverse-engineered)
            Item {
                id: quickShareArrivalCard
                anchors.top: islandTopToolbar.bottom
                anchors.topMargin: 4
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.bottomMargin: 10
                visible: !!(Preferences.notchQuickshareEnabled && islandWin.quickShare && islandWin.quickShare.hasRequest && !agentApprovalBanner.visible && !agentQuestionCard.visible)
                z: 22

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: Qt.rgba(0.04, 0.08, 0.12, 0.96)
                    border.width: 1.2
                    border.color: "#06B6D4"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        // Left Device Icon
                        Rectangle {
                            width: 38; height: 38; radius: 19
                            color: Qt.rgba(0.02, 0.71, 0.83, 0.22)
                            border.width: 1
                            border.color: "#06B6D4"
                            Layout.alignment: Qt.AlignVCenter
                            Icon {
                                anchors.centerIn: parent
                                width: 18; height: 18
                                path: Icons.phone
                                color: "#06B6D4"
                            }
                        }

                        // Middle Device & Content Info
                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 3

                            Row {
                                spacing: 8
                                Txt {
                                    text: (islandWin.quickShare && islandWin.quickShare.deviceName) ? islandWin.quickShare.deviceName : qsTr("Nearby Android Device")
                                    weight: Font.DemiBold
                                    size: 12
                                    color: "#FFFFFF"
                                }
                                Rectangle {
                                    width: 58; height: 18; radius: 4
                                    color: Qt.rgba(0.02, 0.71, 0.83, 0.25)
                                    border.width: 0.75
                                    border.color: "#06B6D4"
                                    anchors.verticalCenter: parent.verticalCenter
                                    Txt {
                                        anchors.centerIn: parent
                                        text: qsTr("PIN %1").arg((islandWin.quickShare && islandWin.quickShare.pin) ? islandWin.quickShare.pin : "----")
                                        role: "code"
                                        size: 9.5
                                        weight: Font.Bold
                                        color: "#22D3EE"
                                    }
                                }
                            }

                            Txt {
                                text: qsTr("Quick Share • %1 items (%2)").arg(islandWin.quickShare && islandWin.quickShare.items ? islandWin.quickShare.items.length : 0).arg(islandWin.quickShare && islandWin.quickShare.totalBytes ? ((islandWin.quickShare.totalBytes / (1024 * 1024)).toFixed(1) + " MB") : "0 MB")
                                size: 10.5
                                color: Qt.rgba(1, 1, 1, 0.75)
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        // Right Action Buttons: Decline & Accept
                        Row {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 8

                            Rectangle {
                                width: 62; height: 28; radius: 6
                                color: Qt.rgba(1, 1, 1, 0.12)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.22)
                                Txt {
                                    anchors.centerIn: parent
                                    text: qsTr("Decline")
                                    size: 11
                                    weight: Font.Medium
                                    color: "#FCA5A5"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: DynamoController.respondQuickShare(false)
                                }
                            }

                            Rectangle {
                                width: 66; height: 28; radius: 6
                                color: "#06B6D4"
                                Txt {
                                    anchors.centerIn: parent
                                    text: qsTr("Accept")
                                    size: 11
                                    weight: Font.DemiBold
                                    color: "#000000"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: DynamoController.respondQuickShare(true)
                                }
                            }
                        }
                    }
                }
            }

            // Interior Area 6: NotchIsland Spotlight Launcher & Math Engine
            Item {
                id: islandLauncherView
                anchors.top: islandTopToolbar.bottom
                anchors.topMargin: 4
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.bottomMargin: 10
                visible: (islandWin.activeTab === "launcher") && !agentApprovalBanner.visible && !agentQuestionCard.visible && !quickShareArrivalCard.visible

                Column {
                    anchors.fill: parent
                    spacing: 6

                    // Search Pill
                    Rectangle {
                        width: parent.width
                        height: 32
                        radius: 16
                        color: Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1
                        border.color: launcherSearchInput.activeFocus ? Theme.primary : Qt.rgba(1, 1, 1, 0.15)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Icon {
                                width: 14; height: 14
                                path: Icons.search
                                color: launcherSearchInput.activeFocus ? Theme.primary : Qt.rgba(1, 1, 1, 0.50)
                            }

                            TextInput {
                                id: launcherSearchInput
                                Layout.fillWidth: true
                                color: "#FFFFFF"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                selectByMouse: true
                                clip: true

                                Text {
                                    text: qsTr("Search apps, math (e.g. 149 * 0.18), unit convert…")
                                    color: Qt.rgba(1, 1, 1, 0.35)
                                    font: launcherSearchInput.font
                                    visible: !launcherSearchInput.text && !launcherSearchInput.inputMethodComposing
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                onTextChanged: DynamoController.queryLauncher(text)

                                onAccepted: {
                                    if (islandWin.launcherResults && islandWin.launcherResults.length > 0) {
                                        DynamoController.executeLauncherItem(islandWin.launcherResults[0].id)
                                    }
                                }
                            }

                            Rectangle {
                                width: 16; height: 16; radius: 8
                                color: Qt.rgba(1, 1, 1, 0.18)
                                visible: launcherSearchInput.text.length > 0
                                Layout.alignment: Qt.AlignVCenter
                                Icon {
                                    anchors.centerIn: parent
                                    width: 8; height: 8
                                    path: Icons.close
                                    color: "#FFFFFF"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        launcherSearchInput.text = ""
                                        DynamoController.queryLauncher("")
                                    }
                                }
                            }
                        }
                    }

                    // Empty State Quick Suggestion Chips
                    Row {
                        visible: launcherSearchInput.text.length === 0
                        spacing: 6
                        width: parent.width

                        Repeater {
                            model: ["149 * 0.18", "100 km in mi", "Lock Screen", "Terminal", "Sleep"]
                            delegate: Rectangle {
                                height: 22
                                width: chipTxt.implicitWidth + 14
                                radius: 11
                                color: chipHover.hovered ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                                border.width: 0.5
                                border.color: Qt.rgba(1, 1, 1, 0.14)

                                Txt {
                                    id: chipTxt
                                    anchors.centerIn: parent
                                    text: modelData
                                    size: 9.5
                                    weight: Font.Medium
                                    color: Qt.rgba(1, 1, 1, 0.75)
                                }

                                MouseArea {
                                    id: chipHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        launcherSearchInput.text = modelData
                                        DynamoController.queryLauncher(modelData)
                                    }
                                }
                            }
                        }
                    }

                    // Results List (Scrollable)
                    ListView {
                        id: launcherListView
                        width: parent.width
                        height: Math.max(60, parent.height - 40)
                        clip: true
                        spacing: 4
                        boundsBehavior: Flickable.StopAtBounds

                        ScrollBar.vertical: ScrollBar {
                            id: launcherScrollBar
                            active: launcherListView.moving || launcherListView.flicking || launchSbHover.hovered
                            policy: ScrollBar.AsNeeded
                            width: 6
                            anchors.right: parent.right
                            anchors.rightMargin: 1
                            contentItem: Rectangle {
                                radius: 3
                                color: launchSbHover.hovered ? Qt.rgba(1, 1, 1, 0.50) : Qt.rgba(1, 1, 1, 0.28)
                            }
                            HoverHandler { id: launchSbHover }
                        }

                        model: islandWin.launcherResults

                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 36
                            radius: 8
                            color: itemHover.hovered ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.04)
                            border.width: itemHover.hovered ? 1 : 0.5
                            border.color: itemHover.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.5) : Qt.rgba(1, 1, 1, 0.08)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                Rectangle {
                                    width: 24; height: 24; radius: 6
                                    color: (modelData.category === "math" || modelData.category === "unit")
                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                                        : Qt.rgba(1, 1, 1, 0.10)
                                    Icon {
                                        anchors.centerIn: parent
                                        width: 12; height: 12
                                        path: (modelData.category === "math") ? Icons.calculator : (modelData.category === "unit" ? Icons.sparkle : (modelData.category === "action" ? Icons.settings : Icons.window))
                                        color: (modelData.category === "math" || modelData.category === "unit") ? Theme.primary : "#FFFFFF"
                                    }
                                }

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Txt {
                                        text: modelData.title || ""
                                        role: "caption"
                                        size: 11
                                        weight: 600
                                        color: "#FFFFFF"
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                    Txt {
                                        text: modelData.subtitle || ""
                                        role: "caption"
                                        size: 9
                                        color: Qt.rgba(1, 1, 1, 0.50)
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                }

                                Rectangle {
                                    width: catTxt.implicitWidth + 8
                                    height: 16
                                    radius: 4
                                    color: Qt.rgba(1, 1, 1, 0.08)
                                    Txt {
                                        id: catTxt
                                        anchors.centerIn: parent
                                        text: (modelData.category || "APP").toUpperCase()
                                        size: 8
                                        weight: 700
                                        color: Qt.rgba(1, 1, 1, 0.60)
                                    }
                                }
                            }

                            MouseArea {
                                id: itemHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: DynamoController.executeLauncherItem(modelData.id)
                            }
                        }
                    }
                }
            }

            // Interior Area 7: SuperIsland Camera-Aligned Notch Teleprompter
            Item {
                id: islandTeleprompterView
                anchors.top: islandTopToolbar.bottom
                anchors.topMargin: 4
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.bottomMargin: 10
                visible: (islandWin.activeTab === "teleprompter") && !agentApprovalBanner.visible && !agentQuestionCard.visible && !quickShareArrivalCard.visible

                Column {
                    anchors.fill: parent
                    spacing: 8

                    // Header Controls Strip
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            height: 26
                            width: playBtnRow.implicitWidth + 16
                            radius: 13
                            color: (islandWin.teleprompterData && islandWin.teleprompterData.isPlaying) ? "#10B981" : Qt.rgba(1, 1, 1, 0.12)

                            Row {
                                id: playBtnRow
                                anchors.centerIn: parent
                                spacing: 4
                                Icon {
                                    width: 11; height: 11
                                    path: (islandWin.teleprompterData && islandWin.teleprompterData.isPlaying) ? Icons.pause : Icons.play
                                    color: "#FFFFFF"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: (islandWin.teleprompterData && islandWin.teleprompterData.isPlaying) ? qsTr("Pause") : qsTr("Start Reading")
                                    size: 10
                                    weight: Font.DemiBold
                                    color: "#FFFFFF"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: DynamoController.teleprompterToggle()
                            }
                        }

                        Rectangle {
                            height: 26
                            width: resetBtnRow.implicitWidth + 16
                            radius: 13
                            color: Qt.rgba(1, 1, 1, 0.08)

                            Row {
                                id: resetBtnRow
                                anchors.centerIn: parent
                                spacing: 4
                                Icon {
                                    width: 10; height: 10
                                    path: Icons.refresh
                                    color: Qt.rgba(1, 1, 1, 0.80)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: qsTr("Reset")
                                    size: 10
                                    weight: Font.Medium
                                    color: Qt.rgba(1, 1, 1, 0.80)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: DynamoController.teleprompterReset()
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Txt {
                            text: qsTr("Speed: %1 pts/s").arg(islandWin.teleprompterData ? islandWin.teleprompterData.speed : 25)
                            role: "caption"
                            size: 9.5
                            color: Qt.rgba(1, 1, 1, 0.50)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            height: 22
                            width: 24
                            radius: 6
                            color: Qt.rgba(1, 1, 1, 0.08)
                            Txt { anchors.centerIn: parent; text: "-"; size: 12; color: "#FFFFFF"; weight: Font.Bold }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const cur = islandWin.teleprompterData ? islandWin.teleprompterData.speed : 25
                                    DynamoController.teleprompterSetSpeed(Math.max(10, cur - 5))
                                }
                            }
                        }

                        Rectangle {
                            height: 22
                            width: 24
                            radius: 6
                            color: Qt.rgba(1, 1, 1, 0.08)
                            Txt { anchors.centerIn: parent; text: "+"; size: 12; color: "#FFFFFF"; weight: Font.Bold }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const cur = islandWin.teleprompterData ? islandWin.teleprompterData.speed : 25
                                    DynamoController.teleprompterSetSpeed(Math.min(90, cur + 5))
                                }
                            }
                        }
                    }

                    // Reading Display Surface
                    Rectangle {
                        width: parent.width
                        height: parent.height - 38
                        radius: 10
                        color: Qt.rgba(0, 0, 0, 0.40)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.10)
                        clip: true

                        Flickable {
                            id: teleprompterFlick
                            anchors.fill: parent
                            anchors.margins: 12
                            contentWidth: width
                            contentHeight: teleprompterTxt.implicitHeight + 60
                            boundsBehavior: Flickable.StopAtBounds

                            ScrollBar.vertical: ScrollBar {
                                id: teleSb
                                active: teleprompterFlick.moving || teleprompterFlick.flicking || teleSbHover.hovered
                                policy: ScrollBar.AsNeeded
                                width: 5
                                contentItem: Rectangle {
                                    radius: 2.5
                                    color: teleSbHover.hovered ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(1, 1, 1, 0.25)
                                }
                                HoverHandler { id: teleSbHover }
                            }

                            contentY: {
                                if (islandWin.teleprompterData && islandWin.teleprompterData.progress !== undefined) {
                                    return (teleprompterTxt.implicitHeight) * islandWin.teleprompterData.progress
                                }
                                return 0
                            }

                            Behavior on contentY {
                                NumberAnimation { duration: 150; easing.type: Easing.Linear }
                            }

                            Txt {
                                id: teleprompterTxt
                                width: parent.width
                                text: (islandWin.teleprompterData && islandWin.teleprompterData.script)
                                    ? islandWin.teleprompterData.script
                                    : qsTr("Type or paste speech notes here. Place directly beneath your FaceTime camera lens for natural eye contact.")
                                size: 15
                                weight: Font.DemiBold
                                lineHeight: 1.4
                                color: "#EDEDEF"
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        // Countdown Pill Overlay
                        Rectangle {
                            anchors.centerIn: parent
                            width: 64; height: 64; radius: 32
                            color: Qt.rgba(0, 0, 0, 0.85)
                            border.width: 2
                            border.color: "#38BDF8"
                            visible: !!(islandWin.teleprompterData && islandWin.teleprompterData.isCountingDown)
                            z: 20

                            Txt {
                                anchors.centerIn: parent
                                text: (islandWin.teleprompterData && islandWin.teleprompterData.countdown) ? islandWin.teleprompterData.countdown : 3
                                size: 28
                                weight: Font.Bold
                                color: "#38BDF8"
                            }
                        }
                    }
                }
            }

            // Interior Area 8: SuperIsland Instant Emoji Picker & Search
            Item {
                id: islandEmojiPickerView
                anchors.top: islandTopToolbar.bottom
                anchors.topMargin: 4
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.bottomMargin: 10
                visible: (islandWin.activeTab === "emojiPicker") && !agentApprovalBanner.visible && !agentQuestionCard.visible && !quickShareArrivalCard.visible

                property string copiedFeedback: ""
                Timer {
                    id: emojiFeedbackTimer
                    interval: 2000
                    onTriggered: islandEmojiPickerView.copiedFeedback = ""
                }

                Column {
                    anchors.fill: parent
                    spacing: 8

                    // Search input & Copied toast
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            height: 30
                            radius: 15
                            color: Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1
                            border.color: emojiSearchInput.activeFocus ? Theme.primary : Qt.rgba(1, 1, 1, 0.12)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 6

                                Icon {
                                    width: 13; height: 13
                                    path: Icons.search
                                    color: emojiSearchInput.activeFocus ? Theme.primary : Qt.rgba(1, 1, 1, 0.40)
                                }

                                TextInput {
                                    id: emojiSearchInput
                                    Layout.fillWidth: true
                                    color: "#FFFFFF"
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    selectByMouse: true
                                    clip: true

                                    Text {
                                        text: qsTr("Search emoji (e.g. rocket, fire, love, done, robot)…")
                                        color: Qt.rgba(1, 1, 1, 0.35)
                                        font: emojiSearchInput.font
                                        visible: !emojiSearchInput.text && !emojiSearchInput.inputMethodComposing
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    onTextChanged: DynamoController.searchEmojis(text)
                                }
                            }
                        }

                        // Feedback Pill
                        Rectangle {
                            height: 26
                            width: copiedTxt.implicitWidth + 16
                            radius: 13
                            color: "#10B981"
                            visible: islandEmojiPickerView.copiedFeedback.length > 0

                            Txt {
                                id: copiedTxt
                                anchors.centerIn: parent
                                text: islandEmojiPickerView.copiedFeedback
                                size: 10
                                weight: Font.Bold
                                color: "#FFFFFF"
                            }
                        }
                    }

                    // Grid of Emojis
                    GridView {
                        width: parent.width
                        height: parent.height - 38
                        clip: true
                        cellWidth: Math.floor(width / 8)
                        cellHeight: 40
                        model: (islandWin.emojiResults && islandWin.emojiResults.length > 0)
                            ? islandWin.emojiResults
                            : [
                                {"emoji":"🚀","name":"Rocket"}, {"emoji":"🔥","name":"Fire"},
                                {"emoji":"⚡️","name":"Zap"}, {"emoji":"✨","name":"Sparkles"},
                                {"emoji":"👍","name":"Thumbs Up"}, {"emoji":"❤️","name":"Heart"},
                                {"emoji":"🎉","name":"Party"}, {"emoji":"💡","name":"Idea"},
                                {"emoji":"💻","name":"Laptop"}, {"emoji":"🎯","name":"Bullseye"},
                                {"emoji":"✅","name":"Check"}, {"emoji":"☕️","name":"Coffee"},
                                {"emoji":"🧠","name":"Brain"}, {"emoji":"🤖","name":"Robot"},
                                {"emoji":"👀","name":"Eyes"}, {"emoji":"🙌","name":"Hands"}
                              ]

                        delegate: Rectangle {
                            width: GridView.view.cellWidth - 4
                            height: 36
                            radius: 8
                            color: emHover.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.05)
                            border.width: 0.5
                            border.color: Qt.rgba(1, 1, 1, 0.10)

                            Txt {
                                anchors.centerIn: parent
                                text: modelData.emoji || ""
                                size: 18
                            }

                            MouseArea {
                                id: emHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    DynamoController.copyEmoji(modelData.emoji)
                                    islandEmojiPickerView.copiedFeedback = qsTr("Copied %1!").arg(modelData.emoji)
                                    emojiFeedbackTimer.restart()
                                }
                            }
                        }
                    }
                }
            }

            // Interior Area 9: AnotherNotch Clipboard History Shelf & Instant Paste
            Item {
                id: islandClipboardView
                z: 10
                anchors.top: islandTopToolbar.bottom
                anchors.topMargin: 4
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.bottomMargin: 16
                clip: true
                visible: (islandWin.activeTab === "clipboard") && !agentApprovalBanner.visible && !agentQuestionCard.visible && !quickShareArrivalCard.visible

                onVisibleChanged: {
                    if (visible && DynamoController && typeof DynamoController.searchClipboardHistory === "function") {
                        DynamoController.searchClipboardHistory("")
                    }
                }

                property string copiedFeedback: ""
                Timer {
                    id: clipFeedbackTimer
                    interval: 2000
                    onTriggered: islandClipboardView.copiedFeedback = ""
                }

                Column {
                    anchors.fill: parent
                    spacing: 8

                    // Header Row: Search + Clear All + Copied Toast
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            height: 30
                            radius: 15
                            color: Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1
                            border.color: clipSearchInput.activeFocus ? Theme.primary : Qt.rgba(1, 1, 1, 0.12)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 6

                                Icon {
                                    width: 12; height: 12
                                    path: Icons.search
                                    color: Qt.rgba(1, 1, 1, 0.40)
                                }

                                TextInput {
                                    id: clipSearchInput
                                    Layout.fillWidth: true
                                    font.pixelSize: 11
                                    color: "#FFFFFF"
                                    clip: true
                                    verticalAlignment: TextInput.AlignVCenter

                                    Text {
                                        text: qsTr("Search clipboard history…")
                                        color: Qt.rgba(1, 1, 1, 0.35)
                                        font: clipSearchInput.font
                                        visible: !clipSearchInput.text && !clipSearchInput.inputMethodComposing
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    onTextChanged: DynamoController.searchClipboardHistory(text)
                                }
                            }
                        }

                        // Copied Toast Pill
                        Rectangle {
                            height: 26
                            width: clipCopiedTxt.implicitWidth + 16
                            radius: 13
                            color: "#10B981"
                            visible: islandClipboardView.copiedFeedback.length > 0

                            Txt {
                                id: clipCopiedTxt
                                anchors.centerIn: parent
                                text: islandClipboardView.copiedFeedback
                                size: 10
                                weight: Font.Bold
                                color: "#FFFFFF"
                            }
                        }

                        // Clear Button
                        Rectangle {
                            height: 26
                            width: clearTxt.implicitWidth + 16
                            radius: 13
                            color: clHover.hovered ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                            border.width: 0.5
                            border.color: Qt.rgba(1, 1, 1, 0.15)

                            Txt {
                                id: clearTxt
                                anchors.centerIn: parent
                                text: qsTr("Clear All")
                                size: 10
                                weight: Font.Medium
                                color: Qt.rgba(1, 1, 1, 0.75)
                            }

                            MouseArea {
                                id: clHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: DynamoController.clearClipboardHistory()
                            }
                        }
                    }

                    // List of Clippings (Scrollable)
                    ListView {
                        id: clipListView
                        width: parent.width
                        height: Math.max(60, parent.height - 38)
                        clip: true
                        spacing: 4
                        boundsBehavior: Flickable.StopAtBounds

                        ScrollBar.vertical: ScrollBar {
                            id: clipScrollBar
                            active: clipListView.moving || clipListView.flicking || clipSbHover.hovered
                            policy: ScrollBar.AsNeeded
                            width: 6
                            anchors.right: parent.right
                            anchors.rightMargin: 1
                            contentItem: Rectangle {
                                radius: 3
                                color: clipSbHover.hovered ? Qt.rgba(1, 1, 1, 0.50) : Qt.rgba(1, 1, 1, 0.28)
                            }
                            HoverHandler { id: clipSbHover }
                        }

                        model: (islandWin.clipboardHistory && islandWin.clipboardHistory.length > 0) ? islandWin.clipboardHistory : []

                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 38
                            radius: 8
                            color: rowHover.hovered ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                            border.width: 0.5
                            border.color: rowHover.hovered ? Theme.primary : Qt.rgba(1, 1, 1, 0.08)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                Rectangle {
                                    width: 20; height: 20; radius: 5
                                    color: Qt.rgba(1, 1, 1, 0.08)
                                    Icon {
                                        anchors.centerIn: parent
                                        width: 11; height: 11
                                        path: Icons.clipboard
                                        color: "#38BDF8"
                                    }
                                }

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Txt {
                                        text: modelData.preview || ""
                                        size: 10.5
                                        weight: Font.Medium
                                        color: "#F1F5F9"
                                        elide: Text.ElideRight
                                        width: Math.min(implicitWidth, 420)
                                    }

                                    Txt {
                                        text: qsTr("%1 chars").arg(modelData.charCount || 0)
                                        size: 8.5
                                        color: Qt.rgba(1, 1, 1, 0.40)
                                    }
                                }

                                Rectangle {
                                    width: 50; height: 22; radius: 11
                                    color: copyBtnHover.hovered ? Theme.primary : Qt.rgba(1, 1, 1, 0.10)

                                    Txt {
                                        anchors.centerIn: parent
                                        text: qsTr("Copy")
                                        size: 9.5
                                        weight: Font.DemiBold
                                        color: "#FFFFFF"
                                    }

                                    MouseArea {
                                        id: copyBtnHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            DynamoController.copyClipboardEntry(modelData.id)
                                            islandClipboardView.copiedFeedback = qsTr("Copied to clipboard!")
                                            clipFeedbackTimer.restart()
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: rowHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                z: -1
                                onClicked: {
                                    DynamoController.copyClipboardEntry(modelData.id)
                                    islandClipboardView.copiedFeedback = qsTr("Copied to clipboard!")
                                    clipFeedbackTimer.restart()
                                }
                            }
                        }

                        // Empty State
                        Item {
                            anchors.fill: parent
                            visible: !islandWin.clipboardHistory || islandWin.clipboardHistory.length === 0

                            Column {
                                anchors.centerIn: parent
                                spacing: 4
                                Icon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 24; height: 24
                                    path: Icons.clipboard
                                    color: Qt.rgba(1, 1, 1, 0.25)
                                }
                                Txt {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: qsTr("No clipboard items yet. Copy text or links anywhere on your Mac!")
                                    size: 10
                                    color: Qt.rgba(1, 1, 1, 0.40)
                                }
                            }
                        }
                    }
                }
            }

            // Smart More Overflow Popover
            IslandMorePopover {
                id: morePopover
                anchors.top: islandTopToolbar.bottom
                anchors.topMargin: 4
                anchors.right: parent.right
                anchors.rightMargin: 16
                overflowTools: islandTopToolbar.overflowTools
                onToolSelected: (id) => islandTopToolbar.handleToolClick(id)
                onCloseRequested: morePopover.isOpen = false
                z: 15
            }

            // Toolbar Customization Sheet
            IslandEditSheet {
                id: editSheet
                allFeatures: islandTopToolbar.allFeatures
                currentEnabledIds: islandTopToolbar.enabledToolIds
                onSaveRequested: (newIds) => {
                    islandTopToolbar.enabledToolIds = newIds
                }
                onCloseRequested: editSheet.isOpen = false
                z: 25
            }
        }
    }
}
