// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import app.maclink

// ============================================================================
// MacLink Liquid Glass Notch-Safe Top Toolbar
// ============================================================================
// Intelligent Layout Engine:
//  - LEFT SAFE REGION: Home -> Leading Feature Shortcuts
//  - CENTRAL REGION: Physical Camera Notch Exclusion Zone (Zero Overlap)
//  - RIGHT SAFE REGION: Trailing Feature Shortcuts -> More (Overflow) -> Edit
// ============================================================================
Item {
    id: toolbarRoot

    property real centerNotchWidth: 193.0
    property real centerNotchHeight: 32.0
    property bool hasPhysicalNotch: true
    property string activeTab: "home" // "home" | "media" | "call" | "tool"
    property string activeToolId: ""
    property var overflowTools: []

    signal homeClicked()
    signal moreClicked(var mouse)
    signal editClicked()
    signal toolSelected(string toolId)

    height: 38

    // Master Catalog of all 24 Verified Tools
    readonly property var allFeatures: [
        { id: "home", label: qsTr("Home Dashboard"), icon: Icons.home, category: "core", isHome: true },
        { id: "dropper", label: qsTr("Color Dropper"), icon: Icons.palette, category: "tools" },
        { id: "keepAwake", label: qsTr("Sleep Prevent"), icon: Icons.coffee, category: "system" },
        { id: "phoneBridge", label: qsTr("Phone Bridge"), icon: Icons.desktop || Icons.mirror, category: "phone" },
        { id: "music", label: qsTr("Now Playing"), icon: Icons.music, category: "media" },
        { id: "systemStats", label: qsTr("System Stats"), icon: Icons.cpu, category: "system" },
        { id: "scopa", label: qsTr("Scopa Storage"), icon: Icons.trash, category: "system" },
        { id: "watcher", label: qsTr("Watcher"), icon: Icons.camera, category: "tools" },
        { id: "powerload", label: qsTr("Powerload Turbo"), icon: Icons.sparkle, category: "system" },
        { id: "shelf", label: qsTr("Notch Shelf"), icon: Icons.shelf, category: "tools" },
        { id: "timer", label: qsTr("Timer"), icon: Icons.clock, category: "tools" },
        { id: "stopwatch", label: qsTr("Stopwatch"), icon: Icons.history, category: "tools" },
        { id: "privacyGuard", label: qsTr("Privacy Guard"), icon: Icons.shield, category: "system" },
        { id: "webcamMonitor", label: qsTr("Webcam Monitor"), icon: Icons.camera, category: "tools" },
        { id: "micMonitor", label: qsTr("Mic Monitor"), icon: Icons.mic, category: "tools" },
        { id: "downloads", label: qsTr("Downloads"), icon: Icons.download, category: "tools" },
        { id: "clipboard", label: qsTr("Clipboard History"), icon: Icons.clipboard, category: "tools" },
        { id: "audioControls", label: qsTr("Audio Controls"), icon: Icons.speaker, category: "media" },
        { id: "volumeControl", label: qsTr("Volume"), icon: Icons.volumeUp, category: "system" },
        { id: "brightnessControl", label: qsTr("Brightness"), icon: Icons.brightness, category: "system" },
        { id: "calendar", label: qsTr("Calendar"), icon: Icons.book, category: "tools" },
        { id: "reminders", label: qsTr("Reminders"), icon: Icons.pin, category: "tools" },
        { id: "deviceUniverse", label: qsTr("Device Universe"), icon: Icons.globe, category: "phone" },
        { id: "externalDisplay", label: qsTr("External Island"), icon: Icons.window, category: "system" }
    ]

    // Persistent Toolbar Ordering & Visibility
    property var enabledToolIds: [
        "dropper", "keepAwake", "phoneBridge", "music", "systemStats",
        "scopa", "watcher", "powerload", "shelf", "timer", "privacyGuard",
        "downloads", "clipboard", "volumeControl", "brightnessControl"
    ]

    // Geometry Calculation
    readonly property real notchExclusionW: hasPhysicalNotch ? (centerNotchWidth + 24.0) : 0.0
    readonly property real availableHalfW: Math.max(120.0, (width - notchExclusionW) / 2.0)
    readonly property real iconTotalW: 35.0 // 29px icon + 6px spacing

    // Calculate how many feature icons fit on Left and Right
    readonly property int maxLeftSlots: Math.max(1, Math.floor((availableHalfW - iconTotalW) / iconTotalW)) // Left has fixed Home
    readonly property int maxRightSlots: Math.max(1, Math.floor((availableHalfW - (2 * iconTotalW)) / iconTotalW)) // Right reserves More + Edit

    // Partition tools into Left, Right, and Overflow
    readonly property var activeTools: {
        let list = []
        for (let i = 0; i < enabledToolIds.length; i++) {
            const id = enabledToolIds[i]
            for (let j = 0; j < allFeatures.length; j++) {
                if (allFeatures[j].id === id) {
                    list.push(allFeatures[j])
                    break
                }
            }
        }
        return list
    }

    readonly property var leftTools: activeTools.slice(0, maxLeftSlots)
    readonly property var rightTools: activeTools.slice(maxLeftSlots, maxLeftSlots + maxRightSlots)
    readonly property var hiddenTools: activeTools.slice(maxLeftSlots + maxRightSlots)

    onHiddenToolsChanged: overflowTools = hiddenTools

    // ------------------------------------------------------------------------
    // LEFT SAFE REGION: Home + Leading Shortcuts
    // ------------------------------------------------------------------------
    Row {
        id: leftSafeRow
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        // Permanent Home Button (Section A)
        Rectangle {
            id: homeBtn
            width: 32; height: 30; radius: 15
            color: (activeTab === "home")
                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.28)
                : (homeHover.hovered ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.10))
            border.width: (activeTab === "home") ? 1.2 : 0.8
            border.color: (activeTab === "home") ? Theme.primary : Qt.rgba(1, 1, 1, 0.22)
            scale: homeHover.hovered ? 1.08 : 1.0
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

            GlassRim { radius: homeBtn.radius }

            Icon {
                anchors.centerIn: parent
                width: 14; height: 14
                path: Icons.home
                color: (activeTab === "home") ? Theme.primary : "#FFFFFF"
            }

            HoverHandler { id: homeHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: {
                    activeTab = "home"
                    activeToolId = ""
                    toolbarRoot.homeClicked()
                }
            }

            ToolTip.visible: homeHover.hovered
            ToolTip.text: qsTr("Home Dashboard")
            ToolTip.delay: 400
        }

        // Left Feature Shortcuts
        Repeater {
            model: leftTools
            delegate: Rectangle {
                id: leftToolBtn
                required property var modelData
                width: 30; height: 30; radius: 15
                readonly property bool isSelected: activeToolId === modelData.id
                color: isSelected
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.28)
                    : (toolHover.hovered ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.09))
                border.width: isSelected ? 1.2 : 0.75
                border.color: isSelected ? Theme.primary : Qt.rgba(1, 1, 1, 0.20)
                scale: toolHover.hovered ? 1.08 : 1.0
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

                GlassRim { radius: leftToolBtn.radius }

                Icon {
                    anchors.centerIn: parent
                    width: 13.5; height: 13.5
                    path: modelData.icon
                    color: isSelected ? Theme.primary : (modelData.id === "keepAwake" && DynamoController.caffeinateActive ? "#F59E0B" : "#FFFFFF")
                }

                // Small active dot for keepAwake or live tools
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 3.5; height: 3.5; radius: 1.75
                    visible: (modelData.id === "keepAwake" && DynamoController.caffeinateActive)
                    color: "#F59E0B"
                }

                HoverHandler { id: toolHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: toolbarRoot.handleToolClick(modelData.id)
                }

                ToolTip.visible: toolHover.hovered
                ToolTip.text: modelData.label
                ToolTip.delay: 400
            }
        }
    }

    // ------------------------------------------------------------------------
    // CENTRAL HARDWARE NOTCH EXCLUSION ZONE (Empty spacer - zero controls)
    // ------------------------------------------------------------------------
    Item {
        id: notchCenterExclusion
        anchors.horizontalCenter: parent.horizontalCenter
        width: toolbarRoot.notchExclusionW
        height: parent.height
        visible: toolbarRoot.hasPhysicalNotch
    }

    // ------------------------------------------------------------------------
    // RIGHT SAFE REGION: Trailing Shortcuts + More + Edit (Section C)
    // ------------------------------------------------------------------------
    Row {
        id: rightSafeRow
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        // Trailing Feature Shortcuts
        Repeater {
            model: rightTools
            delegate: Rectangle {
                id: rightToolBtn
                required property var modelData
                width: 30; height: 30; radius: 15
                readonly property bool isSelected: activeToolId === modelData.id
                color: isSelected
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.28)
                    : (rHover.hovered ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.09))
                border.width: isSelected ? 1.2 : 0.75
                border.color: isSelected ? Theme.primary : Qt.rgba(1, 1, 1, 0.20)
                scale: rHover.hovered ? 1.08 : 1.0
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

                GlassRim { radius: rightToolBtn.radius }

                Icon {
                    anchors.centerIn: parent
                    width: 13.5; height: 13.5
                    path: modelData.icon
                    color: isSelected ? Theme.primary : "#FFFFFF"
                }

                HoverHandler { id: rHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: toolbarRoot.handleToolClick(modelData.id)
                }

                ToolTip.visible: rHover.hovered
                ToolTip.text: modelData.label
                ToolTip.delay: 400
            }
        }

        // Automatic More Overflow Button (Appears only when there are hidden tools)
        Rectangle {
            id: moreBtn
            visible: hiddenTools.length > 0
            width: 30; height: 30; radius: 15
            color: moreHover.hovered ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.10)
            border.width: 0.75
            border.color: Qt.rgba(1, 1, 1, 0.22)
            scale: moreHover.hovered ? 1.08 : 1.0
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

            GlassRim { radius: moreBtn.radius }

            Icon {
                anchors.centerIn: parent
                width: 13.5; height: 13.5
                path: Icons.more
                color: "#FFFFFF"
            }

            HoverHandler { id: moreHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: (mouse) => toolbarRoot.moreClicked(mouse)
            }

            ToolTip.visible: moreHover.hovered
            ToolTip.text: qsTr("More Tools (%1 hidden)").arg(hiddenTools.length)
            ToolTip.delay: 400
        }

        // Reserved Customization Edit Button (Section C)
        Rectangle {
            id: editBtn
            width: 30; height: 30; radius: 15
            color: editHover.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25) : Qt.rgba(1, 1, 1, 0.08)
            border.width: 0.75
            border.color: editHover.hovered ? Theme.primary : Qt.rgba(1, 1, 1, 0.20)
            scale: editHover.hovered ? 1.08 : 1.0
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

            GlassRim { radius: editBtn.radius }

            Icon {
                anchors.centerIn: parent
                width: 12.5; height: 12.5
                path: Icons.edit
                color: editHover.hovered ? Theme.primary : Qt.rgba(1, 1, 1, 0.80)
            }

            HoverHandler { id: editHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: toolbarRoot.editClicked()
            }

            ToolTip.visible: editHover.hovered
            ToolTip.text: qsTr("Customize Island Toolbar")
            ToolTip.delay: 400
        }
    }

    // ------------------------------------------------------------------------
    // Tool Execution Routing
    // ------------------------------------------------------------------------
    function handleToolClick(toolId) {
        activeToolId = toolId
        toolbarRoot.toolSelected(toolId)

        if (toolId === "dropper") {
            DynamoController.pickScreenColor()
        } else if (toolId === "keepAwake") {
            DynamoController.toggleCaffeinate()
        } else if (toolId === "shelf") {
            AppController.toggleShelf()
        } else if (toolId === "downloads") {
            DynamoController.openDownloads()
        } else if (toolId === "calendar") {
            DynamoController.openCalendar()
        } else if (toolId === "reminders") {
            DynamoController.openReminders()
        } else if (toolId === "phoneBridge") {
            const devId = DeviceList.count > 0 ? DeviceList.deviceIdAt(0) : ""
            DynamoController.phoneBridgeMountInFinder(devId)
        } else if (toolId === "music") {
            if (activeTab === "media") activeTab = "home"
            else activeTab = "media"
        } else if (toolId === "scopa" || toolId === "clipboard" || toolId === "systemStats") {
            activeTab = "home"
        }
    }
}
