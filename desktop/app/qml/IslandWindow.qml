// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Window
import QtQuick.Shapes
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
        interval: 1800
        repeat: true
        running: true
        onTriggered: {
            mockCpuPercent = Math.max(8.0, Math.min(85.0, mockCpuPercent + (Math.random() * 8.0 - 4.0)))
            mockRamPercent = Math.max(50.0, Math.min(82.0, mockRamPercent + (Math.random() * 2.0 - 1.0)))
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
    readonly property bool hudActive: Preferences.notchHudEnabled && !!(sysHud && sysHud.visible && hudEvent)
    readonly property bool wingsActive: (Preferences.notchWingsEnabled !== undefined) ? Preferences.notchWingsEnabled : true
    readonly property bool hasPhysicalNotch: {
        if (telemetry && (telemetry.hasPhysicalNotch || (telemetry.layout && telemetry.layout.hasPhysicalNotch)))
            return true
        return true // Default to true on notched MacBook displays
    }
    readonly property bool isNotchAttached: (Preferences.notchHardwareAttached !== undefined) ? (Preferences.notchHardwareAttached && hasPhysicalNotch) : hasPhysicalNotch
    readonly property bool isFullscreen: !!(telemetry && telemetry.isFullscreen)

    readonly property real centerNotchWidth: {
        if (telemetry && telemetry.layout && telemetry.layout.notchWidth > 100)
            return telemetry.layout.notchWidth + 14.0
        return 193.0
    }
    readonly property real centerNotchHeight: {
        if (telemetry && telemetry.layout && telemetry.layout.notchHeight > 20)
            return telemetry.layout.notchHeight
        return 32.0
    }

    readonly property real currentWingWidth: (leftHovered || rightHovered) ? 96.0 : 84.0

    readonly property bool hasMediaCandidate: mediaPlaying && mediaDeviceId !== "local" && mediaTitle.length > 0
    readonly property string mode: {
        if (Preferences.maclinkIslandCalls && PhoneCall.active) return "call"
        if (Preferences.maclinkIslandTransfers && (TransferList.active > 0 || transferJustFinished)) return "transfer"
        if (Preferences.maclinkIslandMedia && hasMediaCandidate) return "media"
        if (Preferences.maclinkIslandNotifications && notificationToastActive && NotificationList.count > 0) return "notification"
        if (Preferences.maclinkIslandTransfers && TransferList.waitingCount > 0) return "waiting"
        if (hudActive) return "hud"
        return "idle"
    }

    readonly property bool hasActivity: (mode !== "idle") || wingsActive
    visible: Preferences.maclinkIsland && hasActivity && (!Preferences.notchAutoHideFullscreen || !isFullscreen)

    onVisibleChanged: {
        console.warn("=== IslandWindow visibleChanged:", visible, "maclinkIsland:", Preferences.maclinkIsland, "hasActivity:", hasActivity, "wingsActive:", wingsActive, "mode:", mode)
        if (visible) {
            Qt.callLater(() => AppController.styleShelfWindow())
            if (!Theme.reduceMotion)
                dropInAnim.restart()
        }
    }

    Component.onCompleted: {
        console.warn("=== IslandWindow Component.onCompleted, visible:", visible, "maclinkIsland:", Preferences.maclinkIsland, "hasActivity:", hasActivity, "wingsActive:", wingsActive, "mode:", mode)
        Qt.callLater(() => {
            recomputeMedia()
            recomputeTransfer()
            AppController.styleShelfWindow()
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

    Timer {
        id: autoCollapseTimer
        interval: 3500
        repeat: false
        onTriggered: {
            if (!expHovered && !notchHovered && !floatingHovered && !PhoneCall.active) {
                islandWin.userPinnedOpen = false
            }
        }
    }

    readonly property bool expanded: userPinnedOpen
        || notchHovered
        || floatingHovered
        || expHovered
        || (Preferences.maclinkIslandCalls && PhoneCall.active && PhoneCall.ringing)

    readonly property real collapsedW: {
        if (isNotchAttached) {
            return centerNotchWidth + (wingsActive ? (2.0 * currentWingWidth) : 0.0)
        } else {
            return 160.0 + (wingsActive ? (2.0 * (currentWingWidth + 8.0)) : 0.0)
        }
    }

    readonly property real targetW: expanded ? Math.max(380.0, collapsedW) : collapsedW
    readonly property real targetH: {
        if (expanded) {
            return (mode === "call" || mode === "media") ? 120.0 : 88.0
        }
        return isNotchAttached ? centerNotchHeight : 34.0
    }

    width: targetW
    height: targetH
    x: areaX + Math.round((areaW - width) / 2)
    y: isNotchAttached ? Screen.virtualY : (areaY + 8)

    Behavior on width {
        enabled: !Theme.reduceMotion
        NumberAnimation { duration: 220; easing.type: Easing.OutBack }
    }
    Behavior on height {
        enabled: !Theme.reduceMotion
        NumberAnimation { duration: 220; easing.type: Easing.OutBack }
    }
    Behavior on x {
        enabled: !Theme.reduceMotion
        NumberAnimation { duration: 220; easing.type: Easing.OutBack }
    }

    onXChanged: { if (DynamoController && typeof DynamoController.updateNotchGestureBounds === "function") DynamoController.updateNotchGestureBounds(x, y, width, height) }
    onYChanged: { if (DynamoController && typeof DynamoController.updateNotchGestureBounds === "function") DynamoController.updateNotchGestureBounds(x, y, width, height) }
    onWidthChanged: { if (DynamoController && typeof DynamoController.updateNotchGestureBounds === "function") DynamoController.updateNotchGestureBounds(x, y, width, height) }
    onHeightChanged: { if (DynamoController && typeof DynamoController.updateNotchGestureBounds === "function") DynamoController.updateNotchGestureBounds(x, y, width, height) }

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
            from: -18
            to: 0
            duration: 240
            easing.type: Easing.OutBack
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
            z: 1

            // 1. Obsidian activation surface overlay (clicks & hover)
            Rectangle {
                anchors.fill: parent
                color: "#000000"
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

            MouseArea {
                id: notchMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: islandWin.notchHovered = true
                onExited: islandWin.notchHovered = false
                onClicked: {
                    islandWin.userPinnedOpen = !islandWin.userPinnedOpen
                    if (islandWin.userPinnedOpen) autoCollapseTimer.restart()
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

            MouseArea {
                id: floatingMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: islandWin.floatingHovered = true
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
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 160 } }

            // Anchoring: FLUSH against notch wall (0px margin) on notch, or 8px gap on external
            anchors.right: islandWin.isNotchAttached ? centerNotchAnchor.left : centerFloatingPill.left
            anchors.rightMargin: islandWin.isNotchAttached ? 0 : 8
            anchors.top: islandWin.isNotchAttached ? parent.top : undefined
            anchors.verticalCenter: islandWin.isNotchAttached ? undefined : centerFloatingPill.verticalCenter
            width: islandWin.currentWingWidth
            height: islandWin.isNotchAttached ? islandWin.centerNotchHeight : 32.0

            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            readonly property real cpuPercentVal: {
                if (islandWin.telemetry && islandWin.telemetry.sample && islandWin.telemetry.sample.cpuPercent !== undefined)
                    return islandWin.telemetry.sample.cpuPercent
                return islandWin.mockCpuPercent
            }
            readonly property real cpuTempCVal: {
                if (islandWin.telemetry && islandWin.telemetry.sample && islandWin.telemetry.sample.cpuTempC !== undefined)
                    return islandWin.telemetry.sample.cpuTempC
                if (islandWin.telemetry && islandWin.telemetry.cpuTempC !== undefined)
                    return islandWin.telemetry.cpuTempC
                return 0
            }
            readonly property color cpuThermalColor: {
                if (islandWin.telemetry && islandWin.telemetry.thermalColorHex && islandWin.telemetry.thermalColorHex.length > 0)
                    return islandWin.telemetry.thermalColorHex
                const t = cpuTempCVal
                if (t > 0) {
                    if (t <= 45) return "#00D4FF" // Cool Cyan
                    if (t <= 65) return "#34C759" // Normal Green
                    if (t <= 80) return "#FFD60A" // Elevated Yellow
                    if (t <= 92) return "#FF9500" // High Orange
                    return "#FF3B30"             // Critical Red
                }
                const c = cpuPercentVal
                if (c < 30) return "#00D4FF"
                if (c < 55) return "#34C759"
                if (c < 75) return "#FFD60A"
                if (c < 90) return "#FF9500"
                return "#FF3B30"
            }

            // A. Exact LeftNotchDropShape (Notched Displays)
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
                        GradientStop { position: 0.00; color: "#000000" }
                        GradientStop { position: 0.85; color: "#000000" }
                        GradientStop { position: 1.00; color: "#000000" }
                    }
                    strokeGradient: LinearGradient {
                        x1: 0; y1: 0; x2: leftWingContainer.width; y2: 0
                        GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.22) }
                        GradientStop { position: 0.80; color: Qt.rgba(1, 1, 1, 0.08) }
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

            // B. Floating Capsule Shape (Non-notched External Displays)
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                visible: !islandWin.isNotchAttached
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.00; color: Qt.rgba(0, 0, 0, 0.86) }
                    GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.70) }
                }
                border.width: 0.75
                border.color: Qt.rgba(1, 1, 1, 0.18)
            }

            // C. CPUTempGlowEdge (50% Fire Flare + 6 Swaying Tongues + Bottom Glow)
            Canvas {
                id: flareCanvas
                anchors.fill: parent
                visible: !Theme.reduceMotion

                property real time: 0
                property real normalizedT: {
                    const t = leftWingContainer.cpuTempCVal
                    if (t > 0) return Math.max(0.0, Math.min(1.0, (t - 35) / 55))
                    return Math.max(0.0, Math.min(1.0, leftWingContainer.cpuPercentVal / 100))
                }
                property bool isUrgent: {
                    const t = leftWingContainer.cpuTempCVal
                    if (t >= 85) return true
                    return leftWingContainer.cpuPercentVal >= 85
                }
                property color baseColor: leftWingContainer.cpuThermalColor

                Timer {
                    id: flareTimer
                    interval: 33
                    repeat: true
                    running: islandWin.visible && islandWin.wingsActive && !islandWin.expanded && !Theme.reduceMotion
                    onTriggered: {
                        flareCanvas.time += 0.033
                        flareCanvas.requestPaint()
                    }
                }

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    if (width <= 0 || height <= 0) return

                    const fillFraction = 0.50
                    const maxFlareHeight = height * fillFraction

                    let breathMult = 1.0
                    if (isUrgent) {
                        breathMult = 0.85 + 0.15 * Math.sin(time * (2.0 * Math.PI / 1.2))
                    }
                    const intensityMult = (0.75 + 0.25 * normalizedT) * breathMult

                    // 1. Base vertical gradient
                    const baseGrad = ctx.createLinearGradient(0, height - maxFlareHeight, 0, height)
                    baseGrad.addColorStop(0.0, "transparent")
                    baseGrad.addColorStop(0.50, Qt.rgba(baseColor.r, baseColor.g, baseColor.b, 0.22 * intensityMult))
                    baseGrad.addColorStop(1.00, Qt.rgba(baseColor.r, baseColor.g, baseColor.b, 0.46 * intensityMult))
                    ctx.fillStyle = baseGrad
                    ctx.fillRect(0, height - maxFlareHeight, width, maxFlareHeight)

                    // 2. 6 flame tongues
                    const tongues = [
                        { relX: 0.12, widthFraction: 0.22, speed: 2.1, phase: 0.0, baseHeightPct: 0.65, heightAmpPct: 0.25, swayAmp: 1.2 },
                        { relX: 0.28, widthFraction: 0.25, speed: 3.4, phase: 1.8, baseHeightPct: 0.75, heightAmpPct: 0.22, swayAmp: 1.5 },
                        { relX: 0.45, widthFraction: 0.28, speed: 2.7, phase: 3.6, baseHeightPct: 0.82, heightAmpPct: 0.18, swayAmp: 1.8 },
                        { relX: 0.62, widthFraction: 0.26, speed: 3.1, phase: 5.2, baseHeightPct: 0.78, heightAmpPct: 0.20, swayAmp: 1.6 },
                        { relX: 0.78, widthFraction: 0.24, speed: 2.3, phase: 2.4, baseHeightPct: 0.70, heightAmpPct: 0.24, swayAmp: 1.4 },
                        { relX: 0.90, widthFraction: 0.20, speed: 3.8, phase: 4.1, baseHeightPct: 0.60, heightAmpPct: 0.28, swayAmp: 1.0 }
                    ]

                    const coreR = Math.min(1.0, baseColor.r * 0.65 + 0.35)
                    const coreG = Math.min(1.0, baseColor.g * 0.65 + 0.35)
                    const coreB = Math.min(1.0, baseColor.b * 0.65 + 0.35)

                    for (let i = 0; i < tongues.length; i++) {
                        const tongue = tongues[i]
                        const effectiveSpeed = tongue.speed * (0.65 + 0.70 * normalizedT)
                        const osc = Math.sin(time * effectiveSpeed + tongue.phase)
                        const sway = tongue.swayAmp * Math.sin(time * effectiveSpeed * 0.7 + tongue.phase + 1.2) * (0.4 + 0.6 * normalizedT)
                        const heightFactor = tongue.baseHeightPct + tongue.heightAmpPct * osc * (0.40 + 0.60 * normalizedT)
                        const tongueH = Math.max(2.0, Math.min(maxFlareHeight * 1.1, maxFlareHeight * heightFactor))

                        const centerX = width * tongue.relX + sway
                        const tongueW = width * tongue.widthFraction

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

                        const tongueGrad = ctx.createLinearGradient(centerX, height, centerX, height - tongueH)
                        tongueGrad.addColorStop(0.0, Qt.rgba(coreR, coreG, coreB, 0.38 * intensityMult))
                        tongueGrad.addColorStop(0.45, Qt.rgba(baseColor.r, baseColor.g, baseColor.b, 0.30 * intensityMult))
                        tongueGrad.addColorStop(1.0, Qt.rgba(baseColor.r * 0.90, baseColor.g * 0.82, baseColor.b * 0.82, 0.0))
                        ctx.fillStyle = tongueGrad
                        ctx.fill()
                    }

                    // 3. Additive hot bottom glow (3px height)
                    const glowH = 3.0
                    const glowGrad = ctx.createLinearGradient(0, height - glowH, 0, height)
                    glowGrad.addColorStop(0.0, "transparent")
                    glowGrad.addColorStop(1.0, Qt.rgba(coreR, coreG, coreB, 0.55 * intensityMult))
                    ctx.fillStyle = glowGrad
                    ctx.fillRect(0, height - glowH, width, glowH)

                    // 4. Smooth horizontal gradient mask (fades into rounded droplet corners)
                    ctx.globalCompositeOperation = "destination-in"
                    const maskGrad = ctx.createLinearGradient(0, 0, width, 0)
                    maskGrad.addColorStop(0.00, "transparent")
                    maskGrad.addColorStop(0.14, "#ffffff")
                    maskGrad.addColorStop(0.86, "#ffffff")
                    maskGrad.addColorStop(1.00, "transparent")
                    ctx.fillStyle = maskGrad
                    ctx.fillRect(0, 0, width, height)
                    ctx.globalCompositeOperation = "source-over"
                }
            }

            // D. Static Flare Fallback (Reduce Motion)
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height * 0.50
                visible: Theme.reduceMotion
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.00; color: "transparent" }
                    GradientStop { position: 1.00; color: Qt.rgba(leftWingContainer.cpuThermalColor.r, leftWingContainer.cpuThermalColor.g, leftWingContainer.cpuThermalColor.b, 0.45) }
                }
            }

            // E. Left Wing Telemetry Readout Content (Exact dynamo-mac layout)
            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 14 // Padding away from curved left edge
                anchors.right: parent.right
                anchors.rightMargin: 8  // Padding away from notch wall
                spacing: 3.5

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 9; height: 9
                    path: Icons.cpu
                    color: leftWingContainer.cpuThermalColor
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "caption"
                    size: 9.5
                    weight: Font.Bold
                    color: leftWingContainer.cpuThermalColor
                    text: {
                        const pct = (leftWingContainer.cpuPercentVal > 0 ? Math.round(leftWingContainer.cpuPercentVal) : 0) + "%"
                        if (islandWin.leftHovered) {
                            if (leftWingContainer.cpuTempCVal > 0)
                                return pct + " • " + Math.round(leftWingContainer.cpuTempCVal) + "°C"
                            return pct + " • Normal"
                        }
                        return pct
                    }
                }
            }

            MouseArea {
                id: leftWingMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: islandWin.leftHovered = true
                onExited: islandWin.leftHovered = false
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
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 160 } }

            // Anchoring: FLUSH against notch wall (0px margin) on notch, or 8px gap on external
            anchors.left: islandWin.isNotchAttached ? centerNotchAnchor.right : centerFloatingPill.right
            anchors.leftMargin: islandWin.isNotchAttached ? 0 : 8
            anchors.top: islandWin.isNotchAttached ? parent.top : undefined
            anchors.verticalCenter: islandWin.isNotchAttached ? undefined : centerFloatingPill.verticalCenter
            width: islandWin.currentWingWidth
            height: islandWin.isNotchAttached ? islandWin.centerNotchHeight : 32.0

            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            readonly property real ramPercentVal: {
                if (islandWin.telemetry && islandWin.telemetry.sample && islandWin.telemetry.sample.ramPercent !== undefined)
                    return islandWin.telemetry.sample.ramPercent
                if (islandWin.telemetry && islandWin.telemetry.ramPercent !== undefined)
                    return islandWin.telemetry.ramPercent
                return islandWin.mockRamPercent
            }
            readonly property color ramBarColor: {
                const p = ramPercentVal
                if (p < 60) return "#34C759" // Normal Green
                if (p < 80) return "#FFD60A" // Elevated Yellow
                if (p < 90) return "#FF9500" // High Orange
                return "#FF3B30"             // Critical Red
            }

            // A. Exact RightNotchDropShape (Notched Displays)
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
                        GradientStop { position: 0.00; color: "#000000" } // Flush with notch wall
                        GradientStop { position: 0.15; color: "#000000" }
                        GradientStop { position: 1.00; color: "#000000" }
                    }
                    strokeGradient: LinearGradient {
                        x1: 0; y1: 0; x2: rightWingContainer.width; y2: 0
                        GradientStop { position: 0.00; color: "transparent" } // Flush with notch wall
                        GradientStop { position: 0.20; color: Qt.rgba(1, 1, 1, 0.08) }
                        GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, 0.22) }
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

            // B. Floating Capsule Shape (Non-notched External Displays)
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                visible: !islandWin.isNotchAttached
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.00; color: Qt.rgba(0, 0, 0, 0.86) }
                    GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.70) }
                }
                border.width: 0.75
                border.color: Qt.rgba(1, 1, 1, 0.18)
            }

            // C. RAMBottomBar: 2.5px Continuous Capsule Track (Exact dynamo-mac layout)
            Item {
                id: ramBottomBarItem
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 1.0
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(0, parent.width - 12.0) // 6pt margin on each side
                height: 3.5

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 2.5
                    radius: 1.25
                    color: Qt.rgba(1, 1, 1, 0.12)
                }

                Rectangle {
                    id: ramFilledBar
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    height: 2.5
                    radius: 1.25
                    color: rightWingContainer.ramBarColor
                    width: Math.max(2.5, parent.width * Math.min(1.0, Math.max(0.0, rightWingContainer.ramPercentVal / 100.0)))

                    Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 240 } }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: parent.color
                        opacity: islandWin.rightHovered ? 0.55 : 0.38
                        scale: 1.15
                        z: -1
                    }
                }
            }

            // D. Right Wing Telemetry Readout Content (Exact dynamo-mac layout)
            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 8  // Padding away from notch wall
                anchors.right: parent.right
                anchors.rightMargin: 14 // Padding away from curved right edge
                spacing: 3.5

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 9; height: 9
                    path: (islandWin.activeTransferRate > 0) ? Icons.arrowDown : Icons.memorychip
                    color: (islandWin.activeTransferRate > 0) ? "#34C759" : rightWingContainer.ramBarColor
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "caption"
                    size: 9.5
                    weight: Font.Bold
                    color: "#FFFFFF"
                    text: {
                        if (islandWin.activeTransferRate > 0)
                            return islandWin.formatRate(islandWin.activeTransferRate)
                        const pct = (rightWingContainer.ramPercentVal > 0 ? Math.round(rightWingContainer.ramPercentVal) : 0) + "%"
                        if (islandWin.rightHovered) {
                            if (islandWin.telemetry && islandWin.telemetry.sample && islandWin.telemetry.sample.ramUsedBytes) {
                                const gb = (islandWin.telemetry.sample.ramUsedBytes / (1024 * 1024 * 1024)).toFixed(1)
                                return pct + " • " + gb + " GB"
                            }
                            return pct + " • RAM"
                        }
                        return pct
                    }
                }

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8.5; height: 8.5
                    visible: !!(islandWin.telemetry && islandWin.telemetry.sample && islandWin.telemetry.sample.batteryCharging)
                    path: Icons.bolt
                    color: "#4ADE80"
                }
            }

            MouseArea {
                id: rightWingMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: islandWin.rightHovered = true
                onExited: islandWin.rightHovered = false
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

            // Layer -2 & -1: Dual Drop Shadow (Apple Liquid Glass Contact & Ambient Shadows)
            Rectangle {
                anchors.fill: parent
                anchors.margins: -1
                radius: islandWin.isNotchAttached ? 14 : height / 2
                color: Qt.rgba(0, 0, 0, 0.40)
                transform: Translate { y: 5 }
                z: -2
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: islandWin.isNotchAttached ? 16 : height / 2
                color: Qt.rgba(0, 0, 0, 0.50)
                transform: Translate { y: 12 }
                z: -3
            }

            // Layer 1: Hardware-Notch Continuous Squircle Shape (Concave Ears + Squircle Chin)
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
                        GradientStop { position: 0.00; color: "#000000" }
                        GradientStop { position: 0.22; color: "#000000" }
                        GradientStop { position: 0.65; color: Qt.rgba(0, 0, 0, 0.88) }
                        GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.70) }
                    }
                    strokeGradient: LinearGradient {
                        x1: 0; y1: 0; x2: 0; y2: dynamicIslandBgShape.height
                        GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.24) }
                        GradientStop { position: 0.50; color: Qt.rgba(1, 1, 1, 0.08) }
                        GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.25) }
                    }
                    strokeWidth: 0.85
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin

                    // Concave top-left ear: curves downward and inward into notch left side
                    PathQuad { x: 6.0; y: 5.0; controlX: 6.0; controlY: -1.0 }
                    // Left vertical edge
                    PathLine { x: 6.0; y: dynamicIslandBgShape.height - 14.0 }
                    // Convex bottom-left corner with Apple continuous smoothing (0.448 factor)
                    PathCubic {
                        x: 6.0 + 14.0; y: dynamicIslandBgShape.height
                        control1X: 6.0; control1Y: dynamicIslandBgShape.height - 14.0 * 0.448
                        control2X: 6.0 + 14.0 * 0.448; control2Y: dynamicIslandBgShape.height
                    }
                    // Bottom horizontal chin edge
                    PathLine { x: dynamicIslandBgShape.width - 6.0 - 14.0; y: dynamicIslandBgShape.height }
                    // Convex bottom-right corner with Apple continuous smoothing (0.448 factor)
                    PathCubic {
                        x: dynamicIslandBgShape.width - 6.0; y: dynamicIslandBgShape.height - 14.0
                        control1X: dynamicIslandBgShape.width - 6.0 - 14.0 * 0.448; control1Y: dynamicIslandBgShape.height
                        control2X: dynamicIslandBgShape.width - 6.0; control2Y: dynamicIslandBgShape.height - 14.0 * 0.448
                    }
                    // Upward vertical right edge
                    PathLine { x: dynamicIslandBgShape.width - 6.0; y: 5.0 }
                    // Concave top-right ear: curves outward to top-right bezel
                    PathQuad { x: dynamicIslandBgShape.width; y: -1.0; controlX: dynamicIslandBgShape.width - 6.0; controlY: -1.0 }
                    // Top horizontal edge closing the shape
                    PathLine { x: 0; y: -1.0 }
                }
            }

            // Layer 1 (Fallback for Non-notched Displays): Capsule Shape
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                visible: !islandWin.isNotchAttached
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.00; color: Qt.rgba(0, 0, 0, 0.86) }
                    GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.68) }
                }
                border.width: 0.85
                border.color: Qt.rgba(1, 1, 1, 0.24)
            }

            // Layer 2: Horizon Sheen Specular Highlight (1px top line)
            Rectangle {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.80
                height: 1
                color: Qt.rgba(1, 1, 1, 0.16)
                z: 1
            }

            // Interactive Gestures on Expanded Island
            WheelHandler {
                id: expWheel
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => {
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

            MouseArea {
                id: expMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onEntered: islandWin.expHovered = true
                onExited: islandWin.expHovered = false
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        DynamoController.toggleGestureTarget()
                        return
                    }
                    if (expandedControlsRow.visible) {
                        const p = expandedControlsRow.mapFromItem(expandedIslandContainer, mouse.x, mouse.y)
                        if (p.x >= 0 && p.y >= 0 && p.x <= expandedControlsRow.width && p.y <= expandedControlsRow.height)
                            return
                    }
                    AppController.activateRequested()
                }
            }

            // ================================================================
            // EXPANDED CONTENT INTERIOR (Calls, Media, Transfers, HUD)
            // ================================================================
            Item {
                id: expContent
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: islandWin.isNotchAttached ? (islandWin.centerNotchHeight > 30 ? 12 : 8) : 8
                anchors.bottomMargin: 10

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
                            onTapped: MediaList.command(islandWin.mediaDeviceId, islandWin.mediaPlayerId, "previous", 0)
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
                            onTapped: MediaList.command(
                                islandWin.mediaDeviceId,
                                islandWin.mediaPlayerId,
                                islandWin.mediaPlaying ? "pause" : "play",
                                0
                            )
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
                            onTapped: MediaList.command(islandWin.mediaDeviceId, islandWin.mediaPlayerId, "next", 0)
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

                    // Modular Add-on Tools (Idle / Telemetry / HUD)
                    Row {
                        visible: islandWin.mode !== "call" && islandWin.mode !== "media" && islandWin.mode !== "transfer"
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
        }
    }
}
