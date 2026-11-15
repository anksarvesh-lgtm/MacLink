// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import app.maclink

// Dynamo & Dynamic Island Control Center: Unified settings and controls
// for MacLink Dynamic Island, Live Telemetry Wings, Liquid Glass Toolbar,
// and hardware notch gestures.
Item {
    id: dynamoPage
    property bool active: true
    property string selectedCategory: "" // Overview hub by default (icons & names only)

    onVisibleChanged: {
        if (!visible) {
            selectedCategory = ""
        }
    }

    readonly property var categoryList: [
        {
            id: "island",
            label: qsTr("Dynamic Island"),
            desc: qsTr("Master island toggle, top pill status & instant quick actions"),
            icon: Icons.island,
            badge: qsTr("Core"),
            badgeColor: Theme.primary
        },
        {
            id: "wings",
            label: qsTr("Wings & Telemetry"),
            desc: qsTr("Sinusoidal CPU flame, RAM capsule track & live notch telemetry"),
            icon: Icons.wings,
            badge: qsTr("Live"),
            badgeColor: "#FF9500"
        },
        {
            id: "live_activity",
            label: qsTr("Live Activity"),
            desc: qsTr("Music player animations, timers, downloads & companion widgets"),
            icon: Icons.sparkle,
            badge: qsTr("Activity"),
            badgeColor: "#AF52DE"
        },
        {
            id: "tools",
            label: qsTr("Notch Tools & Shelf"),
            desc: qsTr("Drop-zone shelf, color eyedropper, keep-awake & quick launchers"),
            icon: Icons.shelf,
            badge: qsTr("Tools"),
            badgeColor: "#34C759"
        },
        {
            id: "system",
            label: qsTr("System & Sensors"),
            desc: qsTr("Display notch layout, thermal sensors, battery gauge & specs"),
            icon: Icons.cpu,
            badge: qsTr("Hardware"),
            badgeColor: "#00C7BE"
        },
        {
            id: "storage",
            label: qsTr("Storage & Cleanup"),
            desc: qsTr("Drive storage breakdown, dev cache recovery & cleanup tools"),
            icon: Icons.trash,
            badge: qsTr("Cleanup"),
            badgeColor: "#FF3B30"
        },
        {
            id: "gestures",
            label: qsTr("Gestures & HUD"),
            desc: qsTr("Notch hover triggers, edge gestures, sneak-peek HUD & haptics"),
            icon: Icons.dialpad,
            badge: qsTr("Controls"),
            badgeColor: "#5856D6"
        }
    ]

    function getCategoryObj(catId) {
        for (var i = 0; i < categoryList.length; ++i) {
            if (categoryList[i].id === catId) return categoryList[i]
        }
        return null
    }

    property string storageStats: ""
    property string cleanStatus: ""

    readonly property var storageObj: {
        try { return JSON.parse(storageStats || "{}") } catch (e) { return {} }
    }
    readonly property string formattedStorage: {
        if (!storageObj || !storageObj.totalBytes) return qsTr("Active • Xcode & Cargo caches recoverable to Trash.")
        const freeGB = (storageObj.freeBytes / (1024 * 1024 * 1024)).toFixed(1)
        const totalGB = (storageObj.totalBytes / (1024 * 1024 * 1024)).toFixed(0)
        const devMB = Math.round(storageObj.devCacheBytes / (1024 * 1024))
        const devText = (devMB >= 1024) ? (devMB / 1024).toFixed(1) + " GB" : devMB + " MB"
        return freeGB + " GB Free of " + totalGB + " GB  •  Recoverable Dev Caches: " + devText
    }

    function updateStorage() {
        storageStats = DynamoController.getStorageStats()
    }

    Component.onCompleted: {
        selectedCategory = ""
        DynamoController.refresh()
        updateStorage()
    }

    Timer {
        interval: 3000
        running: dynamoPage.active
        repeat: true
        onTriggered: {
            DynamoController.refresh()
            dynamoPage.updateStorage()
        }
    }

    readonly property var telemetry: {
        try { return JSON.parse(DynamoController.telemetryJson || "{}") } catch (e) { return {} }
    }
    readonly property var sysBattery: {
        try { return JSON.parse(DynamoController.batteryJson || "{}") } catch (e) { return {} }
    }
    readonly property var sysMedia: {
        try { return JSON.parse(DynamoController.systemMediaJson || "{}") } catch (e) { return {} }
    }
    readonly property var sysCal: {
        try { return JSON.parse(DynamoController.calendarJson || "{}") } catch (e) { return {} }
    }
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
    readonly property real cpuVal: telemetry && telemetry.cpuPercent !== undefined ? telemetry.cpuPercent : 24.0
    readonly property real ramVal: telemetry && telemetry.ramPercent !== undefined ? telemetry.ramPercent : 68.0
    readonly property bool hasNotch: telemetry && telemetry.hasPhysicalNotch !== undefined ? telemetry.hasPhysicalNotch : true
    readonly property real notchWidth: (telemetry && telemetry.layout && telemetry.layout.notchWidth) ? telemetry.layout.notchWidth : 179.0
    readonly property real notchHeight: (telemetry && telemetry.layout && telemetry.layout.notchHeight) ? telemetry.layout.notchHeight : 32.0

    Flickable {
        id: flickable
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.height + 48
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: contentColumn
            width: Math.min(680, parent.width - 48)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 24
            spacing: 16

            // ================================================================
            // VIEW A: Category Hub Overview (Visible ONLY on initial load or back)
            // Displays ONLY icons and their names for clean, instant visual navigation
            // ================================================================
            Column {
                id: overviewSection
                width: parent.width
                spacing: 20
                visible: dynamoPage.selectedCategory === ""

                // Overview Header
                Column {
                    width: parent.width
                    spacing: 4

                    Txt {
                        text: qsTr("Dynamo & Island Control")
                        role: "headline"
                        size: 22
                        weight: Font.Bold
                    }

                    Txt {
                        text: qsTr("Select a feature category to view and customize its options:")
                        role: "body"
                        muted: true
                    }
                }

                // Grid of Categories: Icons and Names
                Grid {
                    id: categoryGrid
                    width: parent.width
                    columns: width < 520 ? 1 : 2
                    columnSpacing: 12
                    rowSpacing: 12

                    Repeater {
                        model: dynamoPage.categoryList

                        delegate: Rectangle {
                            id: tile
                            width: categoryGrid.columns === 1 ? categoryGrid.width : Math.floor((categoryGrid.width - categoryGrid.columnSpacing) / 2)
                            height: 96
                            radius: 14
                            color: tileArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                            border.width: 1
                            border.color: tileArea.containsMouse 
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.5) 
                                : Qt.rgba(1, 1, 1, 0.10)

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 12

                                // Icon Squircle
                                Rectangle {
                                    Layout.preferredWidth: 46
                                    Layout.preferredHeight: 46
                                    radius: 12
                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, tileArea.containsMouse ? 0.24 : 0.14)
                                    border.width: 1
                                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, tileArea.containsMouse ? 0.45 : 0.22)
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Icon {
                                        anchors.centerIn: parent
                                        width: 22; height: 22
                                        path: modelData.icon
                                        color: Theme.primary
                                    }
                                }

                                // Name & Description
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 3

                                    Row {
                                        spacing: 6
                                        width: parent.width

                                        Txt {
                                            text: modelData.label
                                            size: 14
                                            weight: Font.SemiBold
                                            color: "#FFFFFF"
                                        }

                                        Rectangle {
                                            height: 16
                                            width: bTxt.implicitWidth + 8
                                            radius: 4
                                            color: Qt.rgba(1, 1, 1, 0.08)
                                            border.width: 1
                                            border.color: Qt.rgba(1, 1, 1, 0.12)
                                            anchors.verticalCenter: parent.verticalCenter

                                            Txt {
                                                id: bTxt
                                                anchors.centerIn: parent
                                                text: modelData.badge
                                                size: 9
                                                weight: Font.Bold
                                                color: modelData.badgeColor || Theme.primary
                                            }
                                        }
                                    }

                                    Txt {
                                        width: parent.width
                                        text: modelData.desc
                                        size: 11
                                        muted: true
                                        elide: Text.ElideRight
                                        maximumLineCount: 2
                                        wrapMode: Text.WordWrap
                                    }
                                }

                                // Chevron Right
                                Icon {
                                    Layout.preferredWidth: 14
                                    Layout.preferredHeight: 14
                                    path: Icons.chevronRight
                                    color: tileArea.containsMouse ? Theme.primary : Theme.surfaceContentVariant
                                    opacity: tileArea.containsMouse ? 1.0 : 0.4
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                }
                            }

                            MouseArea {
                                id: tileArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    dynamoPage.selectedCategory = modelData.id
                                    flickable.contentY = 0
                                }
                            }
                        }
                    }
                }
            }

            // ================================================================
            // VIEW B: Category Detail Navigation Header (Visible ONLY when a category is selected)
            // Shows "Back to Categories", category switcher, and active category banner
            // ================================================================
            Column {
                id: categoryDetailHeader
                width: parent.width
                spacing: 12
                visible: dynamoPage.selectedCategory !== ""

                // Top Navigation Row
                RowLayout {
                    width: parent.width
                    spacing: 12

                    // Back to Categories Button
                    Rectangle {
                        height: 34
                        width: backBtnRow.implicitWidth + 20
                        radius: 8
                        color: backBtnArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1
                        border.color: backBtnArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.5) : Qt.rgba(1, 1, 1, 0.12)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            id: backBtnRow
                            anchors.centerIn: parent
                            spacing: 6

                            Icon {
                                width: 14; height: 14
                                anchors.verticalCenter: parent.verticalCenter
                                path: Icons.back
                                color: Theme.primary
                            }

                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("All Categories")
                                size: 12
                                weight: Font.DemiBold
                                color: "#FFFFFF"
                            }
                        }

                        MouseArea {
                            id: backBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                dynamoPage.selectedCategory = ""
                                flickable.contentY = 0
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Horizontal Quick-Switch Pills Bar
                    Flickable {
                        Layout.fillWidth: true
                        height: 34
                        contentWidth: quickSwitchRow.implicitWidth
                        contentHeight: 34
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true

                        Row {
                            id: quickSwitchRow
                            spacing: 6
                            height: 34

                            Repeater {
                                model: dynamoPage.categoryList
                                delegate: Rectangle {
                                    height: 30
                                    width: qsInnerRow.implicitWidth + 18
                                    radius: 15
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: (dynamoPage.selectedCategory === modelData.id)
                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
                                        : qsArea.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.04)
                                    border.width: 1
                                    border.color: (dynamoPage.selectedCategory === modelData.id)
                                        ? Theme.primary
                                        : Qt.rgba(1, 1, 1, 0.10)

                                    Row {
                                        id: qsInnerRow
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Icon {
                                            width: 13; height: 13
                                            anchors.verticalCenter: parent.verticalCenter
                                            path: modelData.icon
                                            color: (dynamoPage.selectedCategory === modelData.id) ? Theme.primary : Theme.surfaceContentVariant
                                        }
                                        Txt {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.label
                                            size: 11
                                            weight: (dynamoPage.selectedCategory === modelData.id) ? Font.DemiBold : Font.Normal
                                            color: (dynamoPage.selectedCategory === modelData.id) ? Theme.primary : "#DDDDDD"
                                        }
                                    }

                                    MouseArea {
                                        id: qsArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            dynamoPage.selectedCategory = modelData.id
                                            flickable.contentY = 0
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Active Category Banner
                Rectangle {
                    width: parent.width
                    height: 56
                    radius: 12
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            radius: 10
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                            border.width: 1
                            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)

                            Icon {
                                anchors.centerIn: parent
                                width: 17; height: 17
                                path: dynamoPage.getCategoryObj(dynamoPage.selectedCategory) ? dynamoPage.getCategoryObj(dynamoPage.selectedCategory).icon : Icons.apps
                                color: Theme.primary
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: dynamoPage.getCategoryObj(dynamoPage.selectedCategory) ? dynamoPage.getCategoryObj(dynamoPage.selectedCategory).label : ""
                                size: 15
                                weight: Font.Bold
                                color: "#FFFFFF"
                            }

                            Txt {
                                text: dynamoPage.getCategoryObj(dynamoPage.selectedCategory) ? dynamoPage.getCategoryObj(dynamoPage.selectedCategory).desc : ""
                                size: 11
                                muted: true
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                    }
                }
            }

            // ================================================================
            // SECTION 1: Master Status & Quick Controls
            // ================================================================
            Card {
                width: parent.width
                padding: 18
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "island"

                Column {
                    width: parent.width
                    spacing: 14

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                            border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.island; color: Theme.primary }
                        }

                        StatusDot {
                            online: Preferences.maclinkIsland
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: Preferences.maclinkIsland
                                    ? qsTr("Dynamic Island is Active")
                                    : qsTr("Dynamic Island is Disabled")
                                role: "title"
                                weight: 600
                            }

                            Txt {
                                text: Preferences.maclinkIsland
                                    ? qsTr("Top-screen pill, notch companion, and liquid glass toolbar are running.")
                                    : qsTr("Enable Dynamic Island to show the notch companion and interactive toolbar.")
                                role: "bodySmall"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }

                        Toggle {
                            checked: Preferences.maclinkIsland
                            onToggled: (val) => {
                                Preferences.maclinkIsland = val
                                DynamoController.refresh()
                            }
                        }
                    }

                    // Quick Actions Row (when island is enabled)
                    Column {
                        width: parent.width
                        spacing: 10
                        visible: Preferences.maclinkIsland

                        Divider { width: parent.width }

                        Flow {
                            width: parent.width
                            spacing: 8

                            Button {
                                text: DynamoController.islandExpanded
                                    ? qsTr("Collapse Island")
                                    : qsTr("Expand Island")
                                iconPath: Icons.island
                                variant: DynamoController.islandExpanded ? "fill" : "tonal"
                                size: "sm"
                                onClicked: {
                                    if (DynamoController.islandExpanded) {
                                        DynamoController.collapse()
                                    } else {
                                        DynamoController.expand()
                                    }
                                }
                            }

                            Button {
                                text: qsTr("Pick Screen Color")
                                iconPath: Icons.palette
                                variant: "tonal"
                                size: "sm"
                                onClicked: DynamoController.pickScreenColor()
                            }

                            Button {
                                text: DynamoController.caffeinateActive
                                    ? qsTr("Keep Awake (Active)")
                                    : qsTr("Keep Awake")
                                iconPath: Icons.coffee
                                variant: DynamoController.caffeinateActive ? "fill" : "tonal"
                                size: "sm"
                                onClicked: DynamoController.toggleCaffeinate()
                            }

                            Button {
                                text: qsTr("Toggle Shelf")
                                iconPath: Icons.shelf
                                variant: "tonal"
                                size: "sm"
                                onClicked: AppController.toggleShelf()
                            }

                            Button {
                                text: qsTr("Downloads Folder")
                                iconPath: Icons.download
                                variant: "tonal"
                                size: "sm"
                                onClicked: DynamoController.openDownloads()
                            }
                        }
                    }
                }
            }

            // ================================================================
            // SECTION 2: Live Telemetry Wings (Hardware Notch Companion)
            // ================================================================
            Card {
                width: parent.width
                padding: 18
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "wings"

                Column {
                    width: parent.width
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                            border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.wings; color: Theme.primary }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: qsTr("Live Telemetry Wings")
                                role: "title"
                                weight: 600
                            }

                            Txt {
                                text: qsTr("Sinusoidal CPU heat flame on the left wing and continuous RAM capsule track on the right wing.")
                                role: "bodySmall"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Live Diagnostics Bar
                    Rectangle {
                        width: parent.width
                        height: 38
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 0.75
                        border.color: Qt.rgba(1, 1, 1, 0.10)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12

                            Row {
                                spacing: 6
                                Icon { width: 14; height: 14; path: Icons.cpu; color: "#F59E0B"; anchors.verticalCenter: parent.verticalCenter }
                                Txt {
                                    text: qsTr("CPU: ") + Math.round(dynamoPage.cpuVal) + "%"
                                    role: "caption"
                                    weight: 600
                                    color: "#F59E0B"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle { width: 1; height: 16; color: Qt.rgba(1, 1, 1, 0.15) }

                            Row {
                                spacing: 6
                                Icon { width: 14; height: 14; path: Icons.memorychip; color: "#38BDF8"; anchors.verticalCenter: parent.verticalCenter }
                                Txt {
                                    text: qsTr("RAM: ") + Math.round(dynamoPage.ramVal) + "%"
                                    role: "caption"
                                    weight: 600
                                    color: "#38BDF8"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle { width: 1; height: 16; color: Qt.rgba(1, 1, 1, 0.15) }

                            Row {
                                spacing: 6
                                Layout.fillWidth: true
                                Icon { width: 14; height: 14; path: Icons.island; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                                Txt {
                                    text: dynamoPage.hasNotch
                                        ? (qsTr("Hardware Display Notch (") + Math.round(dynamoPage.notchWidth) + "×" + Math.round(dynamoPage.notchHeight) + " px)")
                                        : qsTr("External Display (Centered Floating Pill)")
                                    role: "caption"
                                    color: Qt.rgba(1, 1, 1, 0.70)
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    Divider { width: parent.width }

                    // Wings Toggle
                    ListRow {
                        width: parent.width
                        iconPath: Icons.wings
                        title: qsTr("Enable Telemetry Wings")
                        description: qsTr("Flank the camera notch with live CPU heat and RAM usage indicators.")
                        Toggle {
                            checked: Preferences.notchWingsEnabled
                            onToggled: (val) => Preferences.notchWingsEnabled = val
                        }
                    }

                    Divider { width: parent.width }

                    // Left Wing Content Selector
                    Column {
                        width: parent.width
                        spacing: 8
                        visible: Preferences.notchWingsEnabled

                        Column {
                            width: parent.width
                            spacing: 2
                            Txt {
                                text: qsTr("Left Wing Content")
                                role: "body"
                                weight: 600
                            }
                            Txt {
                                text: qsTr("Choose which telemetry or contextual info appears on the left wing.")
                                role: "caption"
                                muted: true
                            }
                        }

                        Flow {
                            width: parent.width
                            spacing: 6

                            readonly property var items: [
                                { value: "cpu_temp_flame", label: qsTr("🔥 CPU Temp Flare") },
                                { value: "cpu_load", label: qsTr("⚡ CPU Usage") },
                                { value: "ram_bar", label: qsTr("📊 RAM Status Bar") },
                                { value: "ram_details", label: qsTr("💾 RAM (Used/Total)") },
                                { value: "ram_pressure", label: qsTr("🧭 RAM Pressure") },
                                { value: "net_speed", label: qsTr("⇅ Combined Net Speed") },
                                { value: "net_down", label: qsTr("↓ Download Speed") },
                                { value: "net_up", label: qsTr("↑ Upload Speed") },
                                { value: "battery", label: qsTr("🔋 Mac Battery") },
                                { value: "bluetooth_battery", label: qsTr("🎧 Bluetooth Battery") },
                                { value: "volume", label: qsTr("🔊 Volume") },
                                { value: "brightness", label: qsTr("☀️ Brightness") },
                                { value: "clock", label: qsTr("🕒 Clock & Date") },
                                { value: "weather", label: qsTr("⛅ Weather") },
                                { value: "media_controls", label: qsTr("⏯ Media Controls") },
                                { value: "media", label: qsTr("🎵 Now Playing Track") },
                                { value: "phone_battery", label: qsTr("📱 Phone Battery") },
                                { value: "phone_signal", label: qsTr("📶 Cellular Signal") },
                                { value: "keep_awake", label: qsTr("☕ Keep Awake") },
                                { value: "crypto", label: qsTr("🪙 Crypto Ticker") },
                                { value: "none", label: qsTr("🚫 Off") }
                            ]

                            Repeater {
                                model: parent.items
                                Chip {
                                    text: modelData.label
                                    selected: (Preferences.notchLeftWingContent || "cpu_temp_flame") === modelData.value
                                    interactive: true
                                    onClicked: Preferences.notchLeftWingContent = modelData.value
                                }
                            }
                        }
                    }

                    Divider { width: parent.width; visible: Preferences.notchWingsEnabled }

                    // Right Wing Content Selector
                    Column {
                        width: parent.width
                        spacing: 8
                        visible: Preferences.notchWingsEnabled

                        Column {
                            width: parent.width
                            spacing: 2
                            Txt {
                                text: qsTr("Right Wing Content")
                                role: "body"
                                weight: 600
                            }
                            Txt {
                                text: qsTr("Choose which telemetry or contextual info appears on the right wing.")
                                role: "caption"
                                muted: true
                            }
                        }

                        Flow {
                            width: parent.width
                            spacing: 6

                            readonly property var items: [
                                { value: "ram_bar", label: qsTr("📊 RAM Status Bar") },
                                { value: "cpu_temp_flame", label: qsTr("🔥 CPU Temp Flare") },
                                { value: "cpu_load", label: qsTr("⚡ CPU Usage") },
                                { value: "ram_details", label: qsTr("💾 RAM (Used/Total)") },
                                { value: "ram_pressure", label: qsTr("🧭 RAM Pressure") },
                                { value: "net_speed", label: qsTr("⇅ Combined Net Speed") },
                                { value: "net_down", label: qsTr("↓ Download Speed") },
                                { value: "net_up", label: qsTr("↑ Upload Speed") },
                                { value: "battery", label: qsTr("🔋 Mac Battery") },
                                { value: "bluetooth_battery", label: qsTr("🎧 Bluetooth Battery") },
                                { value: "volume", label: qsTr("🔊 Volume") },
                                { value: "brightness", label: qsTr("☀️ Brightness") },
                                { value: "clock", label: qsTr("🕒 Clock & Date") },
                                { value: "weather", label: qsTr("⛅ Weather") },
                                { value: "media_controls", label: qsTr("⏯ Media Controls") },
                                { value: "media", label: qsTr("🎵 Now Playing Track") },
                                { value: "phone_battery", label: qsTr("📱 Phone Battery") },
                                { value: "phone_signal", label: qsTr("📶 Cellular Signal") },
                                { value: "keep_awake", label: qsTr("☕ Keep Awake") },
                                { value: "crypto", label: qsTr("🪙 Crypto Ticker") },
                                { value: "none", label: qsTr("🚫 Off") }
                            ]

                            Repeater {
                                model: parent.items
                                Chip {
                                    text: modelData.label
                                    selected: (Preferences.notchRightWingContent || "ram_bar") === modelData.value
                                    interactive: true
                                    onClicked: Preferences.notchRightWingContent = modelData.value
                                }
                            }
                        }
                    }

                    Divider { width: parent.width; visible: Preferences.notchWingsEnabled }

                    // Hardware Notch Anchor
                    ListRow {
                        width: parent.width
                        iconPath: Icons.pin
                        title: qsTr("Anchor Flush Against Hardware Notch")
                        description: qsTr("Seamlessly align the island body flush with the physical MacBook screen bezel.")
                        Toggle {
                            checked: Preferences.notchHardwareAttached
                            onToggled: (val) => Preferences.notchHardwareAttached = val
                        }
                    }

                    Divider { width: parent.width }

                    // Fullscreen Auto-Hide
                    ListRow {
                        width: parent.width
                        iconPath: Icons.screenOff
                        title: qsTr("Auto-Hide in Fullscreen")
                        description: qsTr("Hide the island automatically when a fullscreen application occupies the display.")
                        Toggle {
                            checked: Preferences.notchAutoHideFullscreen
                            onToggled: (val) => Preferences.notchAutoHideFullscreen = val
                        }
                    }
                }
            }

            // ================================================================
            // SECTION 3: Live Activity Island Triggers
            // ================================================================
            Card {
                width: parent.width
                padding: 18
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "live_activity"

                Column {
                    width: parent.width
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(0.2, 0.6, 1.0, 0.14)
                            border.width: 1; border.color: Qt.rgba(0.2, 0.6, 1.0, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.sparkle; color: "#38BDF8" }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: qsTr("Live Activity Triggers")
                                role: "title"
                                weight: 600
                            }

                            Txt {
                                text: qsTr("Select which background events automatically surface the island pill.")
                                role: "bodySmall"
                                muted: true
                            }
                        }
                    }

                    Divider { width: parent.width }

                    ListRow {
                        width: parent.width
                        iconPath: Icons.call
                        title: qsTr("Phone Calls")
                        description: qsTr("Show active and incoming phone call banner with live audio controls.")
                        Toggle {
                            checked: Preferences.maclinkIslandCalls
                            onToggled: (val) => Preferences.maclinkIslandCalls = val
                        }
                    }

                    Divider { width: parent.width }

                    ListRow {
                        width: parent.width
                        iconPath: Icons.send
                        title: qsTr("File Transfers")
                        description: qsTr("Display real-time LocalSend QUIC transfer speed and circular progress ring.")
                        Toggle {
                            checked: Preferences.maclinkIslandTransfers
                            onToggled: (val) => Preferences.maclinkIslandTransfers = val
                        }
                    }

                    Divider { width: parent.width }

                    ListRow {
                        width: parent.width
                        iconPath: Icons.music
                        title: qsTr("Now Playing Media")
                        description: qsTr("Display album artwork, title, artist, and playback control buttons.")
                        Toggle {
                            checked: Preferences.maclinkIslandMedia
                            onToggled: (val) => Preferences.maclinkIslandMedia = val
                        }
                    }

                    Divider { width: parent.width }

                    ListRow {
                        width: parent.width
                        iconPath: Icons.bell
                        title: qsTr("Phone Notification Alerts")
                        description: qsTr("Show transient notification toasts underneath the camera notch.")
                        Toggle {
                            checked: Preferences.maclinkIslandNotifications
                            onToggled: (val) => Preferences.maclinkIslandNotifications = val
                        }
                    }
                }
            }

            // ================================================================
            // SECTION 3.5: Boring Notch Modular Add-Ons (macOS Native Extensions)
            // ================================================================
            Card {
                width: parent.width
                padding: 18
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "live_activity" || dynamoPage.selectedCategory === "tools"

                Column {
                    width: parent.width
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(0.2, 0.6, 1.0, 0.14)
                            border.width: 1; border.color: Qt.rgba(0.2, 0.6, 1.0, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.sparkle; color: "#38BDF8" }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: qsTr("Boring Notch Modular Add-Ons")
                                role: "title"
                                weight: 600
                            }

                            Txt {
                                text: qsTr("Reverse-engineered macOS extensions: Notch drag-to-shelf, MagSafe charging HUD, Apple Music & Spotify controls, and Calendar sneak-peek.")
                                role: "bodySmall"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Live Add-On Diagnostics Badge
                    Rectangle {
                        width: parent.width
                        height: 48
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 0.75
                        border.color: Qt.rgba(1, 1, 1, 0.10)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            // Battery state
                            Row {
                                spacing: 5
                                Icon {
                                    width: 13; height: 13
                                    path: (dynamoPage.sysBattery && (dynamoPage.sysBattery.isCharging || dynamoPage.sysBattery.isPluggedIn)) ? Icons.bolt : Icons.battery
                                    color: (dynamoPage.sysBattery && (dynamoPage.sysBattery.isCharging || dynamoPage.sysBattery.isPluggedIn)) ? "#4ADE80" : "#F59E0B"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: (dynamoPage.sysBattery && dynamoPage.sysBattery.level !== undefined)
                                        ? Math.round(dynamoPage.sysBattery.level) + "%" + (dynamoPage.sysBattery.isCharging ? " (Charging)" : (dynamoPage.sysBattery.isPluggedIn ? " (AC)" : ""))
                                        : qsTr("Battery N/A")
                                    role: "caption"
                                    size: 10
                                    weight: 600
                                    color: "#FFFFFF"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle { width: 1; height: 18; color: Qt.rgba(1, 1, 1, 0.15) }

                            // Media state
                            Row {
                                Layout.fillWidth: true
                                spacing: 5
                                Icon {
                                    width: 13; height: 13
                                    path: Icons.music
                                    color: (dynamoPage.sysMedia && dynamoPage.sysMedia.isPlaying) ? Theme.primary : Qt.rgba(1, 1, 1, 0.40)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: (dynamoPage.sysMedia && dynamoPage.sysMedia.hasTrack)
                                        ? (dynamoPage.sysMedia.title + " • " + dynamoPage.sysMedia.artist)
                                        : qsTr("No Media Playing")
                                    role: "caption"
                                    size: 10
                                    color: (dynamoPage.sysMedia && dynamoPage.sysMedia.isPlaying) ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.50)
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle { width: 1; height: 18; color: Qt.rgba(1, 1, 1, 0.15) }

                            // Calendar state
                            Row {
                                spacing: 5
                                Icon {
                                    width: 13; height: 13
                                    path: Icons.clock
                                    color: "#A78BFA"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: (dynamoPage.sysCal && dynamoPage.sysCal.hasEvent)
                                        ? (dynamoPage.sysCal.isOngoing ? qsTr("Meeting now") : qsTr("In %1m").arg(dynamoPage.sysCal.minutesUntil))
                                        : qsTr("No Events Today")
                                    role: "caption"
                                    size: 10
                                    weight: 600
                                    color: "#A78BFA"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    Divider { width: parent.width }

                    // Toggle 1: Notch Drag-to-Shelf
                    ListRow {
                        width: parent.width
                        iconPath: Icons.shelf
                        title: qsTr("Notch Drag-to-Shelf")
                        description: qsTr("Drop files, URLs, or text directly onto the physical camera notch to reveal the MacLink Shelf.")
                        Toggle {
                            checked: Preferences.notchDragToShelf
                            onToggled: (val) => {
                                Preferences.notchDragToShelf = val
                                if (val) {
                                    DynamoController.startNotchDragDetector(dynamoPage.telemetry.layout.notchMinX, dynamoPage.telemetry.layout.notchMaxX, dynamoPage.notchHeight)
                                } else {
                                    DynamoController.stopNotchDragDetector()
                                }
                            }
                        }
                    }

                    Divider { width: parent.width }

                    // Toggle 2: Battery & MagSafe Charging HUD
                    ListRow {
                        width: parent.width
                        iconPath: Icons.batteryCharging
                        title: qsTr("Battery & MagSafe Charging HUD")
                        description: qsTr("Display real-time Mac battery percentage in wings and a glowing charging pulse ring on power connection.")
                        Toggle {
                            checked: Preferences.notchBatteryHud
                            onToggled: (val) => Preferences.notchBatteryHud = val
                        }
                    }

                    Divider { width: parent.width }

                    // Toggle 3: Mac System Media Controls
                    ListRow {
                        width: parent.width
                        iconPath: Icons.music
                        title: qsTr("Mac System Media Controls")
                        description: qsTr("Control macOS Apple Music and Spotify playback with live animated waveform directly in the Island.")
                        Toggle {
                            checked: Preferences.notchSystemMedia
                            onToggled: (val) => Preferences.notchSystemMedia = val
                        }
                    }

                    Divider { width: parent.width }

                    // Toggle 4: Calendar Sneak-Peek
                    ListRow {
                        width: parent.width
                        iconPath: Icons.history
                        title: qsTr("Calendar & Meeting Sneak-Peek")
                        description: qsTr("Preview today's upcoming meetings and countdown directly in the Island Home cards.")
                        Toggle {
                            checked: Preferences.notchCalendarSneakPeek
                            onToggled: (val) => Preferences.notchCalendarSneakPeek = val
                        }
                    }

                    Divider { width: parent.width }

                    // Quick Tool Actions
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Button {
                            text: qsTr("Camera Mirror")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.openCameraMirror()
                        }

                        Button {
                            text: qsTr("Apple Calendar")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.openCalendar()
                        }

                        Button {
                            text: qsTr("Reminders")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.openReminders()
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: qsTr("Refresh Telemetry")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.refresh()
                        }
                    }
                }
            }

            // ================================================================
            // SECTION 3.6: Coucou Modular Add-Ons (Mochi Companion, Focus Timer & AI Hooks)
            // ================================================================
            Card {
                width: parent.width
                padding: 18
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "live_activity"

                Column {
                    width: parent.width
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                            border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.sparkle; color: Theme.primary }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: qsTr("Coucou Modular Add-Ons")
                                role: "title"
                                weight: 600
                            }

                            Txt {
                                text: qsTr("Reverse-engineered macOS extensions: Mochi animated squircle notch companion with eye-gaze tracking, Coucoudoro focus countdown timer, and AI agent session approvals.")
                                role: "bodySmall"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Live Add-On Diagnostics Badge
                    Rectangle {
                        width: parent.width
                        height: 48
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 0.75
                        border.color: Qt.rgba(1, 1, 1, 0.10)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            // Mochi Companion State
                            Row {
                                spacing: 5
                                Rectangle {
                                    width: 10; height: 10; radius: 5
                                    color: (dynamoPage.mochiState && dynamoPage.mochiState.colorHex) ? dynamoPage.mochiState.colorHex : "#EDEDEF"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: Preferences.notchMochiCompanion
                                        ? ("Mochi: " + ((dynamoPage.mochiState && dynamoPage.mochiState.mood) ? dynamoPage.mochiState.mood : "idle") + ((dynamoPage.mochiState && dynamoPage.mochiState.pokeCount > 0) ? (" (" + dynamoPage.mochiState.pokeCount + " pokes)") : ""))
                                        : qsTr("Mochi Off")
                                    role: "caption"
                                    size: 10
                                    weight: 600
                                    color: "#FFFFFF"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle { width: 1; height: 18; color: Qt.rgba(1, 1, 1, 0.15) }

                            // Coucoudoro State
                            Row {
                                spacing: 5
                                Icon {
                                    width: 13; height: 13
                                    path: Icons.clock
                                    color: (dynamoPage.coucoudoro && dynamoPage.coucoudoro.active) ? ((dynamoPage.coucoudoro.phase === "work") ? "#EF4444" : "#10B981") : Qt.rgba(1, 1, 1, 0.40)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: (dynamoPage.coucoudoro && dynamoPage.coucoudoro.active)
                                        ? ("Focus: " + dynamoPage.coucoudoro.clockString + (dynamoPage.coucoudoro.isPaused ? " (Paused)" : (" [" + dynamoPage.coucoudoro.phase + "]")))
                                        : qsTr("Focus Timer Idle")
                                    role: "caption"
                                    size: 10
                                    weight: 600
                                    color: (dynamoPage.coucoudoro && dynamoPage.coucoudoro.active) ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.50)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle { width: 1; height: 18; color: Qt.rgba(1, 1, 1, 0.15) }

                            // Agent Hook State
                            Row {
                                Layout.fillWidth: true
                                spacing: 5
                                Icon {
                                    width: 13; height: 13
                                    path: Icons.shield
                                    color: (dynamoPage.agentHook && dynamoPage.agentHook.hasApproval) ? "#F97316" : (Preferences.notchAgentHooksEnabled ? "#34C759" : Qt.rgba(1, 1, 1, 0.40))
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: (dynamoPage.agentHook && dynamoPage.agentHook.hasApproval)
                                        ? qsTr("Permission Pending")
                                        : (Preferences.notchAgentHooksEnabled ? qsTr("Agent Hooks Ready") : qsTr("Hooks Off"))
                                    role: "caption"
                                    size: 10
                                    weight: 600
                                    color: (dynamoPage.agentHook && dynamoPage.agentHook.hasApproval) ? "#F97316" : Qt.rgba(1, 1, 1, 0.70)
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    Divider { width: parent.width }

                    // Toggle 1: Mochi Notch Companion
                    ListRow {
                        width: parent.width
                        iconPath: Icons.sparkle
                        title: qsTr("Mochi Notch Companion")
                        description: qsTr("Nestles an expressive, animated squircle character in the MacBook notch that tracks cursor gaze, blinks, breathes, and reacts with spiral eyes when poked.")
                        Toggle {
                            checked: Preferences.notchMochiCompanion
                            onToggled: (val) => Preferences.notchMochiCompanion = val
                        }
                    }

                    Divider { width: parent.width }

                    // Toggle 2: Coucoudoro Pomodoro Focus Timer
                    ListRow {
                        width: parent.width
                        iconPath: Icons.clock
                        title: qsTr("Coucoudoro Focus Timer")
                        description: qsTr("25-minute focus intervals and 5-minute restful breaks with audio feedback and live countdown displayed in the notch.")
                        Toggle {
                            checked: Preferences.notchCoucoudoroEnabled
                            onToggled: (val) => Preferences.notchCoucoudoroEnabled = val
                        }
                    }

                    Divider { width: parent.width }

                    // Toggle 3: AI Agent Session Tracker & Approvals
                    ListRow {
                        width: parent.width
                        iconPath: Icons.shield
                        title: qsTr("AI Agent Session Tracker & Approvals")
                        description: qsTr("Notch-native approval prompts for AI agent actions (Antigravity, Claude Code, Cursor) with Allow and Deny controls.")
                        Toggle {
                            checked: Preferences.notchAgentHooksEnabled
                            onToggled: (val) => Preferences.notchAgentHooksEnabled = val
                        }
                    }

                    Divider { width: parent.width }

                    // Quick Actions
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Button {
                            text: qsTr("Poke Mochi")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.pokeMochi()
                        }

                        Button {
                            text: (dynamoPage.coucoudoro && dynamoPage.coucoudoro.active && !dynamoPage.coucoudoro.isPaused) ? qsTr("Pause Timer") : ((dynamoPage.coucoudoro && dynamoPage.coucoudoro.isPaused) ? qsTr("Resume Timer") : qsTr("Start 25m Timer"))
                            variant: "tonal"
                            size: "sm"
                            onClicked: {
                                if (dynamoPage.coucoudoro && dynamoPage.coucoudoro.active && !dynamoPage.coucoudoro.isPaused) {
                                    DynamoController.coucoudoroPause()
                                } else if (dynamoPage.coucoudoro && dynamoPage.coucoudoro.isPaused) {
                                    DynamoController.coucoudoroResume()
                                } else {
                                    DynamoController.coucoudoroStart()
                                }
                            }
                        }

                        Button {
                            text: qsTr("Reset Timer")
                            variant: "tonal"
                            size: "sm"
                            visible: !!(dynamoPage.coucoudoro && dynamoPage.coucoudoro.active)
                            onClicked: DynamoController.coucoudoroReset()
                        }

                        Button {
                            text: qsTr("Quick Screenshot")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.takeQuickScreenshot()
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }

            // ================================================================
            // SECTION 3.7: CodeIsland AI Agent Live Monitor (Task Checklist & Question Relay)
            // ================================================================
            Card {
                width: parent.width
                padding: 18
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "live_activity"

                Column {
                    width: parent.width
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                            border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.terminal; color: Theme.primary }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: qsTr("CodeIsland AI Agent Live Monitor")
                                role: "title"
                                weight: 600
                            }

                            Txt {
                                text: qsTr("Reverse-engineered from CodeIsland: Real-time task checklist progress tracking, interactive multiple-choice question resolution, and companion mascot selection (Mochi Squircle vs AntiGravity Rainbow Bot).")
                                role: "bodySmall"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Live Diagnostics Badge
                    Rectangle {
                        width: parent.width
                        height: 48
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 0.75
                        border.color: Qt.rgba(1, 1, 1, 0.10)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            // Tasks State
                            Row {
                                spacing: 5
                                Rectangle {
                                    width: 10; height: 10; radius: 5
                                    color: (dynamoPage.agentTasks && dynamoPage.agentTasks.isAllCompleted) ? "#10B981" : ((dynamoPage.agentTasks && dynamoPage.agentTasks.hasTasks) ? "#3B82F6" : "#6B7280")
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: (dynamoPage.agentTasks && dynamoPage.agentTasks.hasTasks)
                                        ? ("Tasks: " + dynamoPage.agentTasks.completed + "/" + dynamoPage.agentTasks.total + " (" + Math.round(dynamoPage.agentTasks.percent) + "%) • " + (dynamoPage.agentTasks.activeTitle || "Active"))
                                        : qsTr("No Active Agent Tasks")
                                    role: "caption"
                                    size: 10
                                    weight: 600
                                    color: "#FFFFFF"
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle { width: 1; height: 18; color: Qt.rgba(1, 1, 1, 0.15) }

                            // Question State
                            Row {
                                spacing: 5
                                Icon {
                                    width: 13; height: 13
                                    path: Icons.info
                                    color: (dynamoPage.agentQuestion && dynamoPage.agentQuestion.hasQuestion) ? "#60A5FA" : Qt.rgba(1, 1, 1, 0.40)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: (dynamoPage.agentQuestion && dynamoPage.agentQuestion.hasQuestion)
                                        ? qsTr("Question Pending: %1 options").arg(dynamoPage.agentQuestion.options ? dynamoPage.agentQuestion.options.length : 0)
                                        : qsTr("No Questions Pending")
                                    role: "caption"
                                    size: 10
                                    weight: 600
                                    color: (dynamoPage.agentQuestion && dynamoPage.agentQuestion.hasQuestion) ? "#60A5FA" : Qt.rgba(1, 1, 1, 0.50)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle { width: 1; height: 18; color: Qt.rgba(1, 1, 1, 0.15) }

                            // Mascot Active
                            Row {
                                Layout.fillWidth: true
                                spacing: 5
                                Txt {
                                    text: qsTr("Mascot: %1").arg(Preferences.notchMascotType === "antigravity" ? "AntiGravity Rainbow Bot" : (Preferences.notchMascotType === "mio" ? "Mio CyberCat" : "Mochi Squircle"))
                                    role: "caption"
                                    size: 10
                                    weight: 600
                                    color: (Preferences.notchMascotType === "antigravity") ? "#A78BFA" : ((Preferences.notchMascotType === "mio") ? "#34D399" : "#10B981")
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    // Settings Rows
                    // 1. Notch Agent Tasks Enabled Toggle
                    ListRow {
                        width: parent.width
                        iconPath: Icons.clipboard
                        title: qsTr("Notch Agent Tasks Progress")
                        description: qsTr("Display real-time task checklist progress bar under physical notch and inside home island cards.")
                        Toggle {
                            checked: Preferences.notchAgentTasksEnabled
                            onToggled: (val) => Preferences.notchAgentTasksEnabled = val
                        }
                    }

                    Divider { width: parent.width }

                    // 2. Mascot Companion Selector
                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Txt {
                                text: qsTr("Notch Mascot Persona")
                                weight: 500
                            }
                            Txt {
                                text: qsTr("Choose between Mochi (gaze-tracking Squircle), AntiGravity (Rainbow Bot), and Mio (CyberCat neon pixel mascot).")
                                role: "caption"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }

                        Row {
                            spacing: 8
                            Button {
                                text: qsTr("Mochi Squircle")
                                variant: (Preferences.notchMascotType === "mochi" || !Preferences.notchMascotType) ? "fill" : "tonal"
                                size: "sm"
                                onClicked: Preferences.notchMascotType = "mochi"
                            }
                            Button {
                                text: qsTr("AntiGravity Bot")
                                variant: (Preferences.notchMascotType === "antigravity") ? "fill" : "tonal"
                                size: "sm"
                                onClicked: Preferences.notchMascotType = "antigravity"
                            }
                            Button {
                                text: qsTr("Mio CyberCat")
                                variant: (Preferences.notchMascotType === "mio") ? "fill" : "tonal"
                                size: "sm"
                                onClicked: Preferences.notchMascotType = "mio"
                            }
                        }
                    }

                    Divider { width: parent.width }

                    // Quick Actions
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Button {
                            text: qsTr("Clear Finished Tasks")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.clearAgentTasks()
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }

            // ================================================================
            // SECTION 3.8: SquickShare Android Quick Share & AirDrop Bridge
            // ================================================================
            Card {
                width: parent.width
                padding: 18
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "live_activity"

                Column {
                    width: parent.width
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(0.02, 0.71, 0.83, 0.14)
                            border.width: 1; border.color: Qt.rgba(0.02, 0.71, 0.83, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.send; color: "#06B6D4" }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: qsTr("SquickShare Android Quick Share & AirDrop Bridge")
                                role: "title"
                                weight: 600
                            }

                            Txt {
                                text: qsTr("Reverse-engineered from squick-share: Native Google Quick Share / Nearby Share Bonjour advertisement (_FC9F5ED42C8A._tcp), UKEY2 4-digit PIN authentication, visibility modes (Everyone, 10 Minutes, Hidden), and trusted device auto-accept.")
                                role: "bodySmall"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Live Diagnostics Badge
                    Rectangle {
                        width: parent.width
                        height: 48
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 0.75
                        border.color: Qt.rgba(1, 1, 1, 0.10)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            // Receiver State
                            Row {
                                spacing: 5
                                Rectangle {
                                    width: 10; height: 10; radius: 5
                                    color: (dynamoPage.quickShare && dynamoPage.quickShare.isAdvertising) ? "#06B6D4" : "#6B7280"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: (dynamoPage.quickShare && dynamoPage.quickShare.isAdvertising)
                                        ? ("Quick Share: Port " + dynamoPage.quickShare.advertisingPort)
                                        : qsTr("Quick Share Inactive")
                                    role: "caption"
                                    size: 10
                                    weight: 600
                                    color: "#FFFFFF"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle { width: 1; height: 18; color: Qt.rgba(1, 1, 1, 0.15) }

                            // Visibility Mode
                            Row {
                                spacing: 5
                                Icon {
                                    width: 13; height: 13
                                    path: Icons.info
                                    color: "#22D3EE"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: {
                                        const vis = (dynamoPage.quickShare && dynamoPage.quickShare.visibility) ? dynamoPage.quickShare.visibility : Preferences.notchQuickshareVisibility
                                        if (vis === "everyone") return qsTr("Visible to Everyone")
                                        if (vis === "temporary") return qsTr("10 Min Countdown (%1s)").arg(dynamoPage.quickShare && dynamoPage.quickShare.temporaryRemaining !== undefined ? dynamoPage.quickShare.temporaryRemaining : 600)
                                        return qsTr("Hidden")
                                    }
                                    role: "caption"
                                    size: 10
                                    weight: 600
                                    color: "#22D3EE"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle { width: 1; height: 18; color: Qt.rgba(1, 1, 1, 0.15) }

                            // Transfer / Trusted Status
                            Row {
                                Layout.fillWidth: true
                                spacing: 5
                                Txt {
                                    text: (dynamoPage.quickShare && dynamoPage.quickShare.isTransferring)
                                        ? qsTr("Transferring: %1% (%2 MB/s)").arg(Math.round(dynamoPage.quickShare.transferPercent)).arg(dynamoPage.quickShare.transferRateMBs)
                                        : qsTr("Trusted Devices: %1").arg(dynamoPage.quickShare && dynamoPage.quickShare.trustedDevices ? dynamoPage.quickShare.trustedDevices.length : 0)
                                    role: "caption"
                                    size: 10
                                    weight: 600
                                    color: (dynamoPage.quickShare && dynamoPage.quickShare.isTransferring) ? "#34D399" : Qt.rgba(1, 1, 1, 0.70)
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    // Settings Rows
                    // 1. Quick Share Enabled Toggle
                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Txt {
                                text: qsTr("Enable Android Quick Share Receiver")
                                weight: 500
                            }
                            Txt {
                                text: qsTr("Broadcast mDNS service on local Wi-Fi so nearby Android phones can discover this Mac natively.")
                                role: "caption"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }

                        Toggle {
                            checked: Preferences.notchQuickshareEnabled
                            onToggled: (val) => Preferences.notchQuickshareEnabled = val
                        }
                    }

                    Divider { width: parent.width }

                    // 2. Visibility Mode Selector
                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Txt {
                                text: qsTr("Quick Share Visibility")
                                weight: 500
                            }
                            Txt {
                                text: qsTr("Control whether any nearby device can share or only during a temporary 10-minute window.")
                                role: "caption"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }

                        Row {
                            spacing: 6
                            Button {
                                text: qsTr("Everyone")
                                variant: Preferences.notchQuickshareVisibility === "everyone" ? "fill" : "tonal"
                                size: "sm"
                                onClicked: Preferences.notchQuickshareVisibility = "everyone"
                            }
                            Button {
                                text: qsTr("10 Minutes")
                                variant: Preferences.notchQuickshareVisibility === "temporary" ? "fill" : "tonal"
                                size: "sm"
                                onClicked: Preferences.notchQuickshareVisibility = "temporary"
                            }
                            Button {
                                text: qsTr("Hidden")
                                variant: Preferences.notchQuickshareVisibility === "hidden" ? "fill" : "tonal"
                                size: "sm"
                                onClicked: Preferences.notchQuickshareVisibility = "hidden"
                            }
                        }
                    }

                    Divider { width: parent.width }

                    // 3. Auto-Accept Trusted Devices Toggle
                    ListRow {
                        width: parent.width
                        iconPath: Icons.shield
                        title: qsTr("Auto-Accept Trusted Devices")
                        description: qsTr("Automatically accept incoming Quick Share transfers from your known Android devices without PIN prompt.")
                        Toggle {
                            checked: Preferences.notchQuickshareAutoAcceptTrusted
                            onToggled: (val) => Preferences.notchQuickshareAutoAcceptTrusted = val
                        }
                    }

                    Divider { width: parent.width }

                    // Quick Actions
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Button {
                            text: qsTr("Simulate Incoming Transfer")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.simulateQuickShareIncoming()
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }

            // ================================================================
            // SECTION 3.9: Atoll System HUD, Focus & Peripheral Integrations
            // ================================================================
            Card {
                width: parent.width
                padding: 18
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "gestures"

                Column {
                    width: parent.width
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                            border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.dialpad; color: Theme.primary }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: qsTr("Atoll System HUD, Focus & Peripheral Integrations")
                                role: "title"
                                weight: 600
                            }

                            Txt {
                                text: qsTr("Reverse-engineered from Atoll: Real-time Caps Lock visual indicator HUD, macOS Focus / Do Not Disturb state change detection (_NSDoNotDisturbEnabledNotification), and Bluetooth audio / AirPods battery connection toasts.")
                                role: "bodySmall"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Live Diagnostics Badge
                    Rectangle {
                        width: parent.width
                        height: 48
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 0.75
                        border.color: Qt.rgba(1, 1, 1, 0.10)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            // Caps Lock State
                            Row {
                                spacing: 5
                                Rectangle {
                                    width: 10; height: 10; radius: 5
                                    color: (dynamoPage.atollHud && dynamoPage.atollHud.capsLockActive) ? "#10B981" : "#6B7280"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: (dynamoPage.atollHud && dynamoPage.atollHud.capsLockActive) ? qsTr("Caps Lock: ON") : qsTr("Caps Lock: OFF")
                                    role: "caption"
                                    size: 10
                                    weight: 600
                                    color: (dynamoPage.atollHud && dynamoPage.atollHud.capsLockActive) ? "#10B981" : "#FFFFFF"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle { width: 1; height: 18; color: Qt.rgba(1, 1, 1, 0.15) }

                            // Focus Mode State
                            Row {
                                spacing: 5
                                Icon {
                                    width: 13; height: 13
                                    path: Icons.bell
                                    color: (dynamoPage.atollHud && dynamoPage.atollHud.focusActive) ? "#A78BFA" : Qt.rgba(1, 1, 1, 0.40)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: (dynamoPage.atollHud && dynamoPage.atollHud.focusActive)
                                        ? ("Focus: " + (dynamoPage.atollHud.focusModeName || qsTr("Active")))
                                        : qsTr("Focus Off")
                                    role: "caption"
                                    size: 10
                                    weight: 600
                                    color: (dynamoPage.atollHud && dynamoPage.atollHud.focusActive) ? "#C084FC" : Qt.rgba(1, 1, 1, 0.50)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle { width: 1; height: 18; color: Qt.rgba(1, 1, 1, 0.15) }

                            // Bluetooth Audio State
                            Row {
                                Layout.fillWidth: true
                                spacing: 5
                                Icon {
                                    width: 13; height: 13
                                    path: Icons.volumeUp
                                    color: (dynamoPage.atollHud && dynamoPage.atollHud.bluetoothConnected) ? "#38BDF8" : Qt.rgba(1, 1, 1, 0.40)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: (dynamoPage.atollHud && dynamoPage.atollHud.bluetoothConnected)
                                        ? qsTr("Audio: %1 (%2%)").arg(dynamoPage.atollHud.bluetoothDeviceType || "Connected").arg(dynamoPage.atollHud.bluetoothBattery)
                                        : qsTr("No Bluetooth Audio")
                                    role: "caption"
                                    size: 10
                                    weight: 600
                                    color: (dynamoPage.atollHud && dynamoPage.atollHud.bluetoothConnected) ? "#38BDF8" : Qt.rgba(1, 1, 1, 0.70)
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    // Settings Rows
                    // 1. Caps Lock HUD Toggle
                    ListRow {
                        width: parent.width
                        iconPath: Icons.keyboard
                        title: qsTr("Caps Lock Notch Indicator")
                        description: qsTr("Flash a sleek HUD indicator on the notch whenever Caps Lock is engaged or released.")
                        Toggle {
                            checked: Preferences.notchCapsLockHud
                            onToggled: (val) => Preferences.notchCapsLockHud = val
                        }
                    }

                    Divider { width: parent.width }

                    // 2. Focus Mode HUD Toggle
                    ListRow {
                        width: parent.width
                        iconPath: Icons.moon
                        title: qsTr("Focus Mode / Do Not Disturb HUD")
                        description: qsTr("Show a subtle notch sneak-peek toast when macOS Focus Mode or Do Not Disturb activates.")
                        Toggle {
                            checked: Preferences.notchFocusHud
                            onToggled: (val) => Preferences.notchFocusHud = val
                        }
                    }

                    Divider { width: parent.width }

                    // 3. Bluetooth Audio HUD Toggle
                    ListRow {
                        width: parent.width
                        iconPath: Icons.bluetooth
                        title: qsTr("Bluetooth Audio & AirPods Battery HUD")
                        description: qsTr("Display headphone connection toasts and battery percentage on the notch when devices connect.")
                        Toggle {
                            checked: Preferences.notchBluetoothHud
                            onToggled: (val) => Preferences.notchBluetoothHud = val
                        }
                    }

                    Divider { width: parent.width }

                    // Quick Actions
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Button {
                            text: qsTr("Toggle Caps Lock HUD")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.simulateCapsLock()
                        }

                        Button {
                            text: qsTr("Toggle Focus Mode HUD")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.simulateFocusMode()
                        }

                        Button {
                            text: qsTr("Simulate AirPods Connect")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.simulateBluetoothAudio()
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }

            // ================================================================
            // SECTION 3.10: NotchIsland Quick Command & Math Launcher
            // ================================================================
            Card {
                width: parent.width
                padding: 18
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "tools" || dynamoPage.selectedCategory === "island"

                Column {
                    width: parent.width
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                            border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.search; color: Theme.primary }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: qsTr("NotchIsland Quick Command & Math Launcher")
                                role: "title"
                                weight: 600
                            }

                            Txt {
                                text: qsTr("Reverse-engineered from NotchIsland: Instant in-island spotlight search, recursive-descent math calculator (e.g. 149 * 0.18, 2^8), multi-unit converter, and quick system actions directly from the notch.")
                                role: "bodySmall"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Interactive Launcher Preview / Search Test Box
                    Rectangle {
                        width: parent.width
                        height: 96
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 0.75
                        border.color: Qt.rgba(1, 1, 1, 0.10)

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            // Search test input
                            Rectangle {
                                width: parent.width
                                height: 28
                                radius: 14
                                color: Qt.rgba(1, 1, 1, 0.08)
                                border.width: 1
                                border.color: testSearchInput.activeFocus ? Theme.primary : Qt.rgba(1, 1, 1, 0.15)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    Icon {
                                        width: 12; height: 12
                                        path: Icons.search
                                        color: testSearchInput.activeFocus ? Theme.primary : Qt.rgba(1, 1, 1, 0.50)
                                    }

                                    TextInput {
                                        id: testSearchInput
                                        Layout.fillWidth: true
                                        color: "#FFFFFF"
                                        font.pixelSize: 11
                                        selectByMouse: true
                                        clip: true

                                        Text {
                                            text: qsTr("Try typing '149 * 0.18' or '100 km in mi' or 'Terminal'…")
                                            color: Qt.rgba(1, 1, 1, 0.35)
                                            font: testSearchInput.font
                                            visible: !testSearchInput.text && !testSearchInput.inputMethodComposing
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        onTextChanged: DynamoController.queryLauncher(text)
                                    }

                                    Rectangle {
                                        width: 14; height: 14; radius: 7
                                        color: Qt.rgba(1, 1, 1, 0.18)
                                        visible: testSearchInput.text.length > 0
                                        Layout.alignment: Qt.AlignVCenter
                                        Icon {
                                            anchors.centerIn: parent
                                            width: 7; height: 7
                                            path: Icons.close
                                            color: "#FFFFFF"
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                testSearchInput.text = ""
                                                DynamoController.queryLauncher("")
                                            }
                                        }
                                    }
                                }
                            }

                            // Preview of top launcher results
                            Row {
                                width: parent.width
                                spacing: 8

                                Repeater {
                                    model: (dynamoPage.launcherResults ? dynamoPage.launcherResults.slice(0, 3) : [])
                                    delegate: Rectangle {
                                        height: 38
                                        width: (parent.width - 16) / 3
                                        radius: 6
                                        color: Qt.rgba(1, 1, 1, 0.08)
                                        border.width: 0.5
                                        border.color: Qt.rgba(1, 1, 1, 0.12)

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            spacing: 6

                                            Icon {
                                                width: 14; height: 14
                                                path: (modelData.category === "math") ? Icons.calculator : (modelData.category === "unit" ? Icons.sparkle : (modelData.category === "action" ? Icons.settings : Icons.window))
                                                color: (modelData.category === "math" || modelData.category === "unit") ? Theme.primary : "#FFFFFF"
                                            }

                                            Column {
                                                Layout.fillWidth: true
                                                spacing: 1
                                                Txt {
                                                    text: modelData.title || ""
                                                    size: 10
                                                    weight: 600
                                                    color: "#FFFFFF"
                                                    elide: Text.ElideRight
                                                    width: parent.width
                                                }
                                                Txt {
                                                    text: modelData.subtitle || ""
                                                    size: 8.5
                                                    color: Qt.rgba(1, 1, 1, 0.50)
                                                    elide: Text.ElideRight
                                                    width: parent.width
                                                }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: DynamoController.executeLauncherItem(modelData.id)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Settings Rows
                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Txt {
                                text: qsTr("Enable Notch Spotlight & Math Launcher")
                                weight: 500
                            }
                            Txt {
                                text: qsTr("Add quick search, math evaluation, and unit conversion directly inside the Dynamic Island.")
                                role: "caption"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }

                        Toggle {
                            checked: Preferences.notchLauncherEnabled
                            onToggled: (val) => Preferences.notchLauncherEnabled = val
                        }
                    }

                    Divider { width: parent.width }

                    // Test Action Buttons
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Button {
                            text: qsTr("Calculate '149 * 0.18'")
                            variant: "tonal"
                            size: "sm"
                            onClicked: {
                                testSearchInput.text = "149 * 0.18"
                                DynamoController.queryLauncher("149 * 0.18")
                            }
                        }

                        Button {
                            text: qsTr("Convert '100 km in mi'")
                            variant: "tonal"
                            size: "sm"
                            onClicked: {
                                testSearchInput.text = "100 km in mi"
                                DynamoController.queryLauncher("100 km in mi")
                            }
                        }

                        Button {
                            text: qsTr("Search 'Terminal'")
                            variant: "tonal"
                            size: "sm"
                            onClicked: {
                                testSearchInput.text = "Terminal"
                                DynamoController.queryLauncher("Terminal")
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }

            // ================================================================
            // SECTION 3.11: Island System Download Progress & Hardware Sensor Privacy Monitor
            // ================================================================
            Card {
                width: parent.width
                padding: 18
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "system"

                Column {
                    width: parent.width
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(0.2, 0.7, 0.3, 0.14)
                            border.width: 1; border.color: Qt.rgba(0.2, 0.7, 0.3, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.download; color: "#4ADE80" }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: qsTr("Island System Download Progress & Hardware Sensor Privacy Monitor")
                                role: "title"
                                weight: 600
                            }

                            Txt {
                                text: qsTr("Reverse-engineered from poshak2004/island: System-wide download progress tracking (Safari, Chrome, Edge, Arc via Progress.addSubscriber) and real-time CoreAudio/CoreMediaIO hardware sensor privacy indicators (mic and webcam).")
                                role: "bodySmall"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Live Diagnostics Banner
                    Rectangle {
                        width: parent.width
                        height: 52
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 0.75
                        border.color: Qt.rgba(1, 1, 1, 0.10)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            // Camera Sensor Status
                            Row {
                                spacing: 5
                                Rectangle {
                                    width: 10; height: 10; radius: 5
                                    color: (dynamoPage.privacySensors && dynamoPage.privacySensors.cameraActive) ? "#10B981" : "#6B7280"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: (dynamoPage.privacySensors && dynamoPage.privacySensors.cameraActive) ? qsTr("Camera: ACTIVE") : qsTr("Camera: IDLE")
                                    role: "caption"
                                    size: 10
                                    weight: 600
                                    color: (dynamoPage.privacySensors && dynamoPage.privacySensors.cameraActive) ? "#10B981" : Qt.rgba(1, 1, 1, 0.60)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle { width: 1; height: 18; color: Qt.rgba(1, 1, 1, 0.15) }

                            // Microphone Sensor Status
                            Row {
                                spacing: 5
                                Rectangle {
                                    width: 10; height: 10; radius: 5
                                    color: (dynamoPage.privacySensors && dynamoPage.privacySensors.micActive) ? "#F59E0B" : "#6B7280"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: (dynamoPage.privacySensors && dynamoPage.privacySensors.micActive) ? qsTr("Mic: ACTIVE") : qsTr("Mic: IDLE")
                                    role: "caption"
                                    size: 10
                                    weight: 600
                                    color: (dynamoPage.privacySensors && dynamoPage.privacySensors.micActive) ? "#F59E0B" : Qt.rgba(1, 1, 1, 0.60)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle { width: 1; height: 18; color: Qt.rgba(1, 1, 1, 0.15) }

                            // Download Tracker Status
                            Row {
                                Layout.fillWidth: true
                                spacing: 5
                                Icon {
                                    width: 13; height: 13
                                    path: Icons.download
                                    color: (dynamoPage.downloadsData && dynamoPage.downloadsData.hasActiveDownloads) ? "#38BDF8" : Qt.rgba(1, 1, 1, 0.40)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: (dynamoPage.downloadsData && dynamoPage.downloadsData.hasActiveDownloads)
                                        ? qsTr("%1 download(s) active").arg(dynamoPage.downloadsData.activeCount)
                                        : qsTr("No active downloads")
                                    role: "caption"
                                    size: 10
                                    weight: 600
                                    color: (dynamoPage.downloadsData && dynamoPage.downloadsData.hasActiveDownloads) ? "#38BDF8" : Qt.rgba(1, 1, 1, 0.60)
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    // Settings Rows
                    // 1. Download HUD Toggle
                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Txt {
                                text: qsTr("Notch File Download Progress HUD")
                                weight: 500
                            }
                            Txt {
                                text: qsTr("Automatically show download progress ring, speed, and time remaining on the notch when browsers or apps download files.")
                                role: "caption"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }

                        Toggle {
                            checked: Preferences.notchDownloadsHud
                            onToggled: (val) => Preferences.notchDownloadsHud = val
                        }
                    }

                    Divider { width: parent.width }

                    // 2. Hardware Sensor Privacy HUD Toggle
                    ListRow {
                        width: parent.width
                        iconPath: Icons.camera
                        title: qsTr("Hardware Sensor Privacy Indicators (Green / Amber LEDs)")
                        description: qsTr("Display real-time privacy status dots directly on the notch wings whenever any macOS app captures camera video or microphone audio.")
                        Toggle {
                            checked: Preferences.notchPrivacySensorHud
                            onToggled: (val) => Preferences.notchPrivacySensorHud = val
                        }
                    }

                    Divider { width: parent.width }

                    // Quick Action Test Buttons
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Button {
                            text: qsTr("Simulate File Download")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.simulateDownload()
                        }

                        Button {
                            text: qsTr("Toggle Camera Sensor")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.simulatePrivacyCamera()
                        }

                        Button {
                            text: qsTr("Toggle Mic Sensor")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.simulatePrivacyMic()
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }

            // ================================================================
            // SECTION 3.12: Ledge Standing Notch Announcements & Peripheral Alerts
            // ================================================================
            Card {
                width: parent.width
                padding: 18
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "live_activity"

                Column {
                    width: parent.width
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(0.2, 0.6, 1.0, 0.14)
                            border.width: 1; border.color: Qt.rgba(0.2, 0.6, 1.0, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.bell; color: "#38BDF8" }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: qsTr("Ledge Standing Notch Announcements & Peripheral Alerts")
                                role: "title"
                                weight: 600
                            }

                            Txt {
                                text: qsTr("Reverse-engineered from egemertbalcik/Ledge: Compact standing notch peripheral alert drop strip that gently lowers below the notch to announce pomodoro cycles, break reminders, and priority status updates without interrupting active workflows.")
                                role: "bodySmall"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Live Diagnostics Banner
                    Rectangle {
                        width: parent.width
                        height: 48
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 0.75
                        border.color: Qt.rgba(1, 1, 1, 0.10)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            Rectangle {
                                width: 10; height: 10; radius: 5
                                color: (dynamoPage.ledgeAnnouncement && dynamoPage.ledgeAnnouncement.active)
                                    ? ((dynamoPage.ledgeAnnouncement && dynamoPage.ledgeAnnouncement.accentHex) ? dynamoPage.ledgeAnnouncement.accentHex : "#38BDF8")
                                    : "#6B7280"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Txt {
                                text: (dynamoPage.ledgeAnnouncement && dynamoPage.ledgeAnnouncement.active)
                                    ? qsTr("Active Announcement: %1").arg(dynamoPage.ledgeAnnouncement.title)
                                    : qsTr("No active standing announcement")
                                role: "caption"
                                size: 10
                                weight: 600
                                color: (dynamoPage.ledgeAnnouncement && dynamoPage.ledgeAnnouncement.active)
                                    ? ((dynamoPage.ledgeAnnouncement && dynamoPage.ledgeAnnouncement.accentHex) ? dynamoPage.ledgeAnnouncement.accentHex : "#38BDF8")
                                    : Qt.rgba(1, 1, 1, 0.60)
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }

                    // 1. Announcements Enabled Toggle
                    ListRow {
                        width: parent.width
                        iconPath: Icons.bell
                        title: qsTr("Enable Standing Notch Announcements")
                        description: qsTr("Drop a slim peripheral accent pill 24pt below the hardware notch for high-priority status shifts.")
                        Toggle {
                            checked: Preferences.notchAnnouncementsEnabled
                            onToggled: (val) => Preferences.notchAnnouncementsEnabled = val
                        }
                    }

                    Divider { width: parent.width }

                    // Quick Action Test Buttons
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Button {
                            text: qsTr("Test Focus Cycle (Blue)")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.triggerAnnouncement("Deep Focus Session Completed", "checkmark.circle.fill", "#38BDF8")
                        }

                        Button {
                            text: qsTr("Test Break Time (Green)")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.triggerAnnouncement("5-Minute Break Ready", "cup.and.saucer.fill", "#4ADE80")
                        }

                        Button {
                            text: qsTr("Dismiss")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.dismissAnnouncement()
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }

            // ================================================================
            // SECTION 3.13: SuperIsland Notch Teleprompter, Instant Emoji Picker & AI Usage Monitor
            // ================================================================
            Card {
                width: parent.width
                padding: 18
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "tools"

                Column {
                    width: parent.width
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(0.65, 0.55, 0.98, 0.14)
                            border.width: 1; border.color: Qt.rgba(0.65, 0.55, 0.98, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.text; color: "#A78BFA" }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: qsTr("SuperIsland Notch Teleprompter, Instant Emoji Picker & AI Usage")
                                role: "title"
                                weight: 600
                            }

                            Txt {
                                text: qsTr("Reverse-engineered from shobhit99/SuperIsland: Camera-aligned eye-level teleprompter for presentations & video calls, instant docked emoji fuzzy search with 1-click clipboard copy, and circular AI quota token usage rings.")
                                role: "bodySmall"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Live Diagnostics Banner
                    Rectangle {
                        width: parent.width
                        height: 52
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 0.75
                        border.color: Qt.rgba(1, 1, 1, 0.10)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 14

                            // Teleprompter Status
                            Row {
                                spacing: 5
                                Rectangle {
                                    width: 10; height: 10; radius: 5
                                    color: (dynamoPage.teleprompterData && dynamoPage.teleprompterData.isPlaying) ? "#10B981" : "#6B7280"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: (dynamoPage.teleprompterData && dynamoPage.teleprompterData.isPlaying)
                                        ? qsTr("Teleprompter: PLAYING (%1 pts/s)").arg(dynamoPage.teleprompterData.speed)
                                        : qsTr("Teleprompter: IDLE")
                                    role: "caption"
                                    size: 10
                                    weight: 600
                                    color: (dynamoPage.teleprompterData && dynamoPage.teleprompterData.isPlaying) ? "#10B981" : Qt.rgba(1, 1, 1, 0.60)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle { width: 1; height: 18; color: Qt.rgba(1, 1, 1, 0.15) }

                            // AI Usage Status
                            Row {
                                Layout.fillWidth: true
                                spacing: 8
                                Layout.alignment: Qt.AlignVCenter

                                Row {
                                    spacing: 4
                                    Icon {
                                        width: 12; height: 12
                                        path: Icons.sparkle
                                        color: "#A78BFA"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Txt {
                                        text: qsTr("Claude: %1%").arg(dynamoPage.aiUsage ? dynamoPage.aiUsage.claudePercent : 68)
                                        size: 9.5
                                        weight: 600
                                        color: "#A78BFA"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Row {
                                    spacing: 4
                                    Icon {
                                        width: 12; height: 12
                                        path: Icons.sparkle
                                        color: "#38BDF8"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Txt {
                                        text: qsTr("Codex: %1%").arg(dynamoPage.aiUsage ? dynamoPage.aiUsage.codexPercent : 82)
                                        size: 9.5
                                        weight: 600
                                        color: "#38BDF8"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }

                    // 1. Teleprompter Toggle
                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Txt {
                                text: qsTr("Camera Notch Teleprompter")
                                weight: 500
                            }
                            Txt {
                                text: qsTr("Position speech notes and presentation scripts directly beneath the MacBook webcam lens with customizable auto-scroll speed and countdown timer.")
                                role: "caption"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }

                        Toggle {
                            checked: Preferences.notchTeleprompterEnabled
                            onToggled: (val) => Preferences.notchTeleprompterEnabled = val
                        }
                    }

                    Divider { width: parent.width }

                    // 2. Emoji Picker Toggle
                    ListRow {
                        width: parent.width
                        iconPath: Icons.sparkle
                        title: qsTr("Instant Docked Emoji Picker")
                        description: qsTr("Quickly search and copy popular emojis directly from the notch toolbar without opening full-screen emoji palettes.")
                        Toggle {
                            checked: Preferences.notchEmojiPickerEnabled
                            onToggled: (val) => Preferences.notchEmojiPickerEnabled = val
                        }
                    }

                    Divider { width: parent.width }

                    // 3. AI Usage Monitor Toggle
                    ListRow {
                        width: parent.width
                        iconPath: Icons.cpu
                        title: qsTr("AI Token Usage & Quota Meter")
                        description: qsTr("Show live ring indicators for Claude and OpenAI Codex session quota directly in the island dashboard.")
                        Toggle {
                            checked: Preferences.notchAiUsageEnabled
                            onToggled: (val) => Preferences.notchAiUsageEnabled = val
                        }
                    }

                    Divider { width: parent.width }

                    // Quick Action Test Buttons
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Button {
                            text: qsTr("Toggle Teleprompter")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.teleprompterToggle()
                        }

                        Button {
                            text: qsTr("Reset Teleprompter")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.teleprompterReset()
                        }

                        Button {
                            text: qsTr("Refresh AI Usage")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.simulateAiUsageRefresh()
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }

            // ================================================================
            // SECTION 3.14: MioIsland 8-Bit Chiptune Audio & Terminal Jumper Engine
            // ================================================================
            Card {
                width: parent.width
                padding: 18
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "tools"

                Column {
                    width: parent.width
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(0.95, 0.3, 0.6, 0.14)
                            border.width: 1; border.color: Qt.rgba(0.95, 0.3, 0.6, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.speaker; color: "#F43F5E" }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: qsTr("MioIsland 8-Bit Chiptune Audio & Terminal Jumper Engine")
                                role: "title"
                                weight: 600
                            }

                            Txt {
                                text: qsTr("Reverse-engineered from MioMioOS/MioIsland: Programmatic zero-asset 8-bit chiptune audio synthesizer (AVAudioEngine) for agent states & transitions, and direct-to-terminal activation jumper (Ghostty, iTerm2, Terminal.app, Warp, WezTerm, Alacritty).")
                                role: "bodySmall"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Live Diagnostics Banner
                    Rectangle {
                        width: parent.width
                        height: 52
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 0.75
                        border.color: Qt.rgba(1, 1, 1, 0.10)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 14

                            // Chiptune Audio Status
                            Row {
                                spacing: 5
                                Rectangle {
                                    width: 10; height: 10; radius: 5
                                    color: Preferences.notchSynthAudioEnabled ? "#10B981" : "#6B7280"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: Preferences.notchSynthAudioEnabled ? qsTr("Chiptune Synth: READY") : qsTr("Chiptune Synth: MUTED")
                                    role: "caption"
                                    size: 10
                                    weight: 600
                                    color: Preferences.notchSynthAudioEnabled ? "#10B981" : Qt.rgba(1, 1, 1, 0.60)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle { width: 1; height: 18; color: Qt.rgba(1, 1, 1, 0.15) }

                            // Detected Terminals
                            Row {
                                Layout.fillWidth: true
                                spacing: 6
                                Layout.alignment: Qt.AlignVCenter
                                Icon {
                                    width: 13; height: 13
                                    path: Icons.desktop || Icons.mirror
                                    color: "#38BDF8"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: (dynamoPage.runningTerminals && dynamoPage.runningTerminals.running && dynamoPage.runningTerminals.running.length > 0)
                                        ? qsTr("Active Terminals: %1").arg(dynamoPage.runningTerminals.running.join(", "))
                                        : qsTr("Preferred Terminal: Terminal.app")
                                    role: "caption"
                                    size: 10
                                    weight: 600
                                    color: "#38BDF8"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    // 1. Chiptune Audio Toggle
                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Txt {
                                text: qsTr("8-Bit Chiptune Retro Audio Cues")
                                weight: 500
                            }
                            Txt {
                                text: qsTr("Synthesize native retro audio tones for AI agent session start, permission approval requests, and completed tasks.")
                                role: "caption"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }

                        Toggle {
                            checked: Preferences.notchSynthAudioEnabled
                            onToggled: (val) => Preferences.notchSynthAudioEnabled = val
                        }
                    }

                    Divider { width: parent.width }

                    // 2. Terminal Jumper Toggle
                    ListRow {
                        width: parent.width
                        iconPath: Icons.terminal
                        title: qsTr("Terminal Jumper Direct Activation")
                        description: qsTr("Show quick 1-click jump buttons in agent cards to immediately focus the host terminal application.")
                        Toggle {
                            checked: Preferences.notchTerminalJumperEnabled
                            onToggled: (val) => Preferences.notchTerminalJumperEnabled = val
                        }
                    }

                    Divider { width: parent.width }

                    // Quick Action Test Buttons
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Button {
                            text: qsTr("Play Start Chime")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.playSynthSound("start")
                        }

                        Button {
                            text: qsTr("Play Approval Chime")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.playSynthSound("approval")
                        }

                        Button {
                            text: qsTr("Play Victory Chime")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.playSynthSound("complete")
                        }

                        Button {
                            text: qsTr("Jump to Terminal")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.jumpToTerminal("")
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }

            // ================================================================
            // SECTION 3.15: Notchly Wi-Fi Network & Hotspot Monitor and Lock Screen Engine
            // ================================================================
            Card {
                width: parent.width
                padding: 18
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "system"

                Column {
                    width: parent.width
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(0.06, 0.71, 0.83, 0.14)
                            border.width: 1; border.color: Qt.rgba(0.06, 0.71, 0.83, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.wifi; color: "#06B6D4" }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: qsTr("Notchly Wi-Fi Network & Hotspot Monitor and Lock Screen Engine")
                                role: "title"
                                weight: 600
                            }

                            Txt {
                                text: qsTr("Reverse-engineered from Notchly/Notchly: System-wide Wi-Fi SSID tracking, iPhone personal hotspot detection, real-time signal strength bars, transient notch connection toasts, and native macOS lock screen sleep synchronization.")
                                role: "bodySmall"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Live Diagnostics Banner
                    Rectangle {
                        width: parent.width
                        height: 52
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 0.75
                        border.color: Qt.rgba(1, 1, 1, 0.10)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 14

                            // Connection Status
                            Row {
                                spacing: 5
                                Rectangle {
                                    width: 10; height: 10; radius: 5
                                    color: (dynamoPage.networkStatus && dynamoPage.networkStatus.connected) ? "#10B981" : "#EF4444"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: (dynamoPage.networkStatus && dynamoPage.networkStatus.connected)
                                        ? qsTr("%1 (%2)").arg(dynamoPage.networkStatus.ssid || "Connected").arg(dynamoPage.networkStatus.isHotspot ? "Hotspot" : "Wi-Fi")
                                        : qsTr("Network: Disconnected")
                                    role: "caption"
                                    size: 10
                                    weight: 600
                                    color: (dynamoPage.networkStatus && dynamoPage.networkStatus.connected) ? "#10B981" : "#EF4444"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle { width: 1; height: 18; color: Qt.rgba(1, 1, 1, 0.15) }

                            // Lock Screen State
                            Row {
                                Layout.fillWidth: true
                                spacing: 6
                                Layout.alignment: Qt.AlignVCenter
                                Icon {
                                    width: 13; height: 13
                                    path: DynamoController.screenLocked ? Icons.lock : Icons.shield
                                    color: DynamoController.screenLocked ? "#F59E0B" : "#38BDF8"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: DynamoController.screenLocked ? qsTr("Screen: LOCKED") : qsTr("Screen: UNLOCKED / ACTIVE")
                                    role: "caption"
                                    size: 10
                                    weight: 600
                                    color: DynamoController.screenLocked ? "#F59E0B" : "#38BDF8"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    // 1. Network Status HUD Toggle
                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Txt {
                                text: qsTr("Wi-Fi & Hotspot Connection Toasts")
                                weight: 500
                            }
                            Txt {
                                text: qsTr("Show transient notch connection notifications when joining new networks, switching to iPhone personal hotspot, or disconnecting.")
                                role: "caption"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }

                        Toggle {
                            checked: Preferences.notchNetworkStatusEnabled
                            onToggled: (val) => Preferences.notchNetworkStatusEnabled = val
                        }
                    }

                    Divider { width: parent.width }

                    // 2. Lock Screen Overlay Toggle
                    ListRow {
                        width: parent.width
                        iconPath: Icons.window
                        title: qsTr("Lock Screen Island Synchronization")
                        description: qsTr("Track macOS lock and unlock events to smoothly sleep and restore the dynamic island.")
                        Toggle {
                            checked: Preferences.notchLockScreenOverlayEnabled
                            onToggled: (val) => Preferences.notchLockScreenOverlayEnabled = val
                        }
                    }

                    Divider { width: parent.width }

                    // Quick Action Test Buttons
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Button {
                            text: qsTr("Simulate Wi-Fi Connect")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.simulateNetworkEvent("wifi")
                        }

                        Button {
                            text: qsTr("Simulate iPhone Hotspot")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.simulateNetworkEvent("hotspot")
                        }

                        Button {
                            text: qsTr("Simulate Disconnect")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.simulateNetworkEvent("offline")
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }

            // ================================================================
            // SECTION 3.16: QuietNotch Inline HUD & System Notification Filter
            // ================================================================
            Card {
                width: parent.width
                padding: 18
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "gestures"

                Column {
                    width: parent.width
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(0.96, 0.62, 0.04, 0.14)
                            border.width: 1; border.color: Qt.rgba(0.96, 0.62, 0.04, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.volumeUp; color: "#F59E0B" }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: qsTr("QuietNotch Inline HUD & System Notification Filter")
                                role: "title"
                                weight: 600
                            }

                            Txt {
                                text: qsTr("Reverse-engineered from quietapps/QuietNotch: Real-time CoreAudio volume listener, dynamic display brightness HUD slider on the hardware notch, and system notification banner aggregation with quiet hours / DND suppression filter.")
                                role: "bodySmall"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Live Diagnostics Banner
                    Rectangle {
                        width: parent.width
                        height: 52
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 0.75
                        border.color: Qt.rgba(1, 1, 1, 0.10)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 14

                            // Volume / HUD Status
                            Row {
                                spacing: 5
                                Icon {
                                    width: 14; height: 14
                                    path: Icons.volumeUp
                                    color: (dynamoPage.quietnotchHud && dynamoPage.quietnotchHud.isMuted) ? "#EF4444" : "#38BDF8"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: dynamoPage.quietnotchHud ? qsTr("HUD: %1 (%2)").arg(dynamoPage.quietnotchHud.kind || "volume").arg(dynamoPage.quietnotchHud.title || "50%") : qsTr("HUD: Ready")
                                    role: "caption"
                                    size: 10
                                    weight: 600
                                    color: (dynamoPage.quietnotchHud && dynamoPage.quietnotchHud.isMuted) ? "#EF4444" : "#38BDF8"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle { width: 1; height: 18; color: Qt.rgba(1, 1, 1, 0.15) }

                            // Notification Filter Status
                            Row {
                                Layout.fillWidth: true
                                spacing: 6
                                Layout.alignment: Qt.AlignVCenter
                                Icon {
                                    width: 13; height: 13
                                    path: Preferences.notchQuietHoursEnabled ? Icons.moon : Icons.bell
                                    color: Preferences.notchQuietHoursEnabled ? "#A78BFA" : "#10B981"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: Preferences.notchQuietHoursEnabled ? qsTr("Quiet Hours: ACTIVE (Alerts Silenced)") : qsTr("Notch Notifications: ACTIVE")
                                    role: "caption"
                                    size: 10
                                    weight: 600
                                    color: Preferences.notchQuietHoursEnabled ? "#A78BFA" : "#10B981"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    // 1. Inline HUD Toggle
                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Txt {
                                text: qsTr("Notch Inline Volume & Brightness HUD")
                                weight: 500
                            }
                            Txt {
                                text: qsTr("Display real-time hardware volume and screen brightness adjustments right inside the notch wings/anchor.")
                                role: "caption"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }

                        Toggle {
                            checked: Preferences.notchQuietInlineHudEnabled
                            onToggled: (val) => Preferences.notchQuietInlineHudEnabled = val
                        }
                    }

                    Divider { width: parent.width }

                    // 2. Notch Notifications Toggle
                    ListRow {
                        width: parent.width
                        iconPath: Icons.bell
                        title: qsTr("Notch Notification Banners")
                        description: qsTr("Catch and display incoming macOS notifications directly beneath the camera notch.")
                        Toggle {
                            checked: Preferences.notchQuietNotificationsEnabled
                            onToggled: (val) => Preferences.notchQuietNotificationsEnabled = val
                        }
                    }

                    Divider { width: parent.width }

                    // 3. Quiet Hours Toggle
                    ListRow {
                        width: parent.width
                        iconPath: Icons.moon
                        title: qsTr("Quiet Hours / Do Not Disturb Filter")
                        description: qsTr("Mute and suppress intrusive notch notification banners during focus sessions or quiet hours.")
                        Toggle {
                            checked: Preferences.notchQuietHoursEnabled
                            onToggled: (val) => Preferences.notchQuietHoursEnabled = val
                        }
                    }

                    Divider { width: parent.width }

                    // Quick Action Test Triggers
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Button {
                            text: qsTr("Test Volume HUD (75%)")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.simulateQuietnotchHud("volume", 0.75)
                        }

                        Button {
                            text: qsTr("Test Brightness HUD (60%)")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.simulateQuietnotchHud("brightness", 0.60)
                        }

                        Button {
                            text: qsTr("Simulate System Alert")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.sendQuietnotchTestNotification("Quiet Notch Alert", "System notification intercepted and displayed at notch!", "Finder")
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }

            // ================================================================
            // SECTION 3.17: AnotherNotch Clipboard Shelf & Fan Thermal Control
            // ================================================================
            Card {
                width: parent.width
                padding: 18
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "tools" || dynamoPage.selectedCategory === "wings"

                Column {
                    width: parent.width
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                            border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.clipboard; color: Theme.primary }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: qsTr("AnotherNotch Clipboard Shelf & Fan Thermal Control")
                                role: "title"
                                weight: 600
                            }

                            Txt {
                                text: qsTr("Reverse-engineered from jinkun1998/another.notch: Real-time clipboard history shelf with 1-click paste directly from the notch, and Mac SMC fan telemetry with adaptive thermal control profiles (Auto, Silent, Turbo).")
                                role: "bodySmall"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Live Diagnostics Banner
                    Rectangle {
                        width: parent.width
                        height: 52
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 0.75
                        border.color: Qt.rgba(1, 1, 1, 0.10)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 14

                            // Fan RPM Telemetry
                            Row {
                                spacing: 5
                                Icon {
                                    width: 14; height: 14
                                    path: Icons.cpu || Icons.clock
                                    color: (dynamoPage.fanTelemetry && dynamoPage.fanTelemetry.mode === "turbo") ? "#EF4444" : "#10B981"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: dynamoPage.fanTelemetry ? qsTr("Fan: %1 RPM • %2°C (%3)").arg(dynamoPage.fanTelemetry.leftRPM || 1850).arg(Math.round(dynamoPage.fanTelemetry.cpuTempC || 42)).arg((dynamoPage.fanTelemetry.mode || "auto").toUpperCase()) : qsTr("Fan: 1850 RPM • 42°C")
                                    role: "caption"
                                    size: 10
                                    weight: 600
                                    color: (dynamoPage.fanTelemetry && dynamoPage.fanTelemetry.mode === "turbo") ? "#EF4444" : "#10B981"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle { width: 1; height: 18; color: Qt.rgba(1, 1, 1, 0.15) }

                            // Clipboard Cache Status
                            Row {
                                Layout.fillWidth: true
                                spacing: 6
                                Layout.alignment: Qt.AlignVCenter
                                Icon {
                                    width: 13; height: 13
                                    path: Icons.clipboard
                                    color: "#38BDF8"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: (dynamoPage.clipboardHistory && dynamoPage.clipboardHistory.length > 0)
                                        ? qsTr("Clipboard: %1 items cached (Latest: \"%2\")").arg(dynamoPage.clipboardHistory.length).arg(dynamoPage.clipboardHistory[0].preview || "")
                                        : qsTr("Clipboard: Ready (Monitoring copied clips)")
                                    role: "caption"
                                    size: 10
                                    weight: 600
                                    color: "#38BDF8"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    // 1. Clipboard History Shelf Toggle
                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Txt {
                                text: qsTr("Notch Clipboard History Shelf")
                                weight: 500
                            }
                            Txt {
                                text: qsTr("Access, search, and 1-click copy recent clipboard items directly inside the expanded dynamic island.")
                                role: "caption"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }

                        Toggle {
                            checked: Preferences.notchClipboardShelfEnabled
                            onToggled: (val) => Preferences.notchClipboardShelfEnabled = val
                        }
                    }

                    Divider { width: parent.width }

                    // 2. Fan Speed & Thermal Telemetry Toggle
                    ListRow {
                        width: parent.width
                        iconPath: Icons.flame
                        title: qsTr("Mac Fan Telemetry & Thermal Modes")
                        description: qsTr("Read real-time cooling fan RPM speeds and select between Auto, Silent, and Turbo thermal profiles.")
                        Toggle {
                            checked: Preferences.notchFanTelemetryEnabled
                            onToggled: (val) => Preferences.notchFanTelemetryEnabled = val
                        }
                    }

                    Divider { width: parent.width }

                    // Fan Profile Quick Switcher & Test Action Buttons
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Txt {
                            text: qsTr("Fan Profile:")
                            size: 10.5
                            weight: Font.DemiBold
                            color: Qt.rgba(1, 1, 1, 0.65)
                        }

                        Button {
                            text: qsTr("Auto")
                            variant: (dynamoPage.fanTelemetry && dynamoPage.fanTelemetry.mode === "auto") ? "primary" : "tonal"
                            size: "sm"
                            onClicked: DynamoController.setFanMode("auto")
                        }

                        Button {
                            text: qsTr("Silent")
                            variant: (dynamoPage.fanTelemetry && dynamoPage.fanTelemetry.mode === "silent") ? "primary" : "tonal"
                            size: "sm"
                            onClicked: DynamoController.setFanMode("silent")
                        }

                        Button {
                            text: qsTr("Turbo")
                            variant: (dynamoPage.fanTelemetry && dynamoPage.fanTelemetry.mode === "turbo") ? "primary" : "tonal"
                            size: "sm"
                            onClicked: DynamoController.setFanMode("turbo")
                        }

                        Rectangle { width: 1; height: 16; color: Qt.rgba(1, 1, 1, 0.15) }

                        Button {
                            text: qsTr("Add Test Clip")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.addClipboardEntry("MacLink dynamic island clipboard clip test " + Math.floor(Math.random() * 1000))
                        }

                        Button {
                            text: qsTr("Clear History")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.clearClipboardHistory()
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }

            // ================================================================
            // SECTION 3.18: GHNotch Fast Local Command Engine & Natural Language Calculator
            // ================================================================
            Card {
                width: parent.width
                padding: 18
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "tools"

                Column {
                    width: parent.width
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(0.2, 0.6, 1.0, 0.14)
                            border.width: 1; border.color: Qt.rgba(0.2, 0.6, 1.0, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.calculator; color: "#38BDF8" }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: qsTr("GHNotch Fast Local Command Engine & Natural Language Calculator")
                                role: "title"
                                weight: 600
                            }

                            Txt {
                                text: qsTr("Reverse-engineered from aymandakirgh/ghnotch: Privacy-first local command dispatcher executing inline arithmetic, natural language percentages, case conversions, base64 coding, and AI queries directly at the notch.")
                                role: "bodySmall"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Live Diagnostics / Last Result Banner
                    Rectangle {
                        width: parent.width
                        height: 52
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 0.75
                        border.color: Qt.rgba(1, 1, 1, 0.10)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 14

                            Row {
                                spacing: 6
                                Icon {
                                    width: 14; height: 14
                                    path: Icons.search || Icons.terminal
                                    color: "#38BDF8"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: (dynamoPage.ghnotchResult && dynamoPage.ghnotchResult.hasResult)
                                        ? qsTr("Input: \"%1\"").arg(dynamoPage.ghnotchResult.input || "")
                                        : qsTr("Command Bar: Ready for expressions & commands")
                                    role: "caption"
                                    size: 10
                                    weight: 600
                                    color: "#38BDF8"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle { width: 1; height: 18; color: Qt.rgba(1, 1, 1, 0.15) }

                            Row {
                                Layout.fillWidth: true
                                spacing: 6
                                Layout.alignment: Qt.AlignVCenter
                                Txt {
                                    text: (dynamoPage.ghnotchResult && dynamoPage.ghnotchResult.hasResult)
                                        ? qsTr("Output: %1").arg(dynamoPage.ghnotchResult.output || "")
                                        : qsTr("Type an expression below or test with quick commands")
                                    role: "caption"
                                    size: 10
                                    weight: 600
                                    color: (dynamoPage.ghnotchResult && dynamoPage.ghnotchResult.hasResult) ? "#10B981" : Qt.rgba(1, 1, 1, 0.45)
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    // 1. Command Engine Toggle
                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Txt {
                                text: qsTr("Notch Fast Local Command Engine")
                                weight: 500
                            }
                            Txt {
                                text: qsTr("Execute mathematical expressions and instant text transforms locally without cloud transmission.")
                                role: "caption"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }

                        Toggle {
                            checked: Preferences.notchCommandEngineEnabled
                            onToggled: (val) => Preferences.notchCommandEngineEnabled = val
                        }
                    }

                    Divider { width: parent.width }

                    // Interactive Command Input Field
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            height: 32
                            radius: 16
                            color: Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1
                            border.color: cmdInput.activeFocus ? Theme.primary : Qt.rgba(1, 1, 1, 0.12)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 8

                                Icon {
                                    width: 12; height: 12
                                    path: Icons.search
                                    color: Qt.rgba(1, 1, 1, 0.40)
                                }

                                TextInput {
                                    id: cmdInput
                                    Layout.fillWidth: true
                                    font.pixelSize: 11
                                    color: "#FFFFFF"
                                    clip: true
                                    verticalAlignment: TextInput.AlignVCenter

                                    Text {
                                        text: qsTr("Type command or math (e.g. 25 * 4, 15% of 80, upper hello)…")
                                        color: Qt.rgba(1, 1, 1, 0.35)
                                        font: cmdInput.font
                                        visible: !cmdInput.text && !cmdInput.inputMethodComposing
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    onAccepted: {
                                        if (text.trim().length > 0) {
                                            DynamoController.executeNotchCommand(text.trim())
                                        }
                                    }
                                }
                            }
                        }

                        Button {
                            text: qsTr("Run")
                            variant: "primary"
                            size: "sm"
                            onClicked: {
                                if (cmdInput.text.trim().length > 0) {
                                    DynamoController.executeNotchCommand(cmdInput.text.trim())
                                }
                            }
                        }
                    }

                    Divider { width: parent.width }

                    // Test Action Quick Buttons
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Button {
                            text: qsTr("Calc: (14 * 6) + 18")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.executeNotchCommand("(14 * 6) + 18")
                        }

                        Button {
                            text: qsTr("Percentage: 20% of 250")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.executeNotchCommand("20% of 250")
                        }

                        Button {
                            text: qsTr("Count: Hello MacLink Island")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.executeNotchCommand("count Hello MacLink Island")
                        }

                        Button {
                            text: qsTr("Timer: timer 15m")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.executeNotchCommand("timer 15m")
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }

            // ================================================================
            // SECTION 3.19: Isle — Live Crypto & FX Financial Ticker (TheVinizzz/Isle)
            // ================================================================
            Card {
                width: parent.width
                padding: 18
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "tools"

                Column {
                    width: parent.width
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(0.96, 0.62, 0.04, 0.14)
                            border.width: 1; border.color: Qt.rgba(0.96, 0.62, 0.04, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.bolt; color: "#F59E0B" }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: qsTr("Isle — Live Crypto & Currency Market Ticker")
                                role: "title"
                                size: 14
                                weight: Font.Bold
                            }

                            Txt {
                                text: qsTr("Reverse-engineered from TheVinizzz/Isle: Real-time financial tickers (crypto & fiat currencies via AwesomeAPI / CoinCap), directional percentage badges, and instant refresh right in the notch.")
                                role: "body"
                                size: 11
                                color: Qt.rgba(1, 1, 1, 0.6)
                                wrapMode: Text.WordWrap
                            }
                        }

                        Toggle {
                            checked: Preferences.notchIsleFinanceEnabled
                            onToggled: (val) => Preferences.notchIsleFinanceEnabled = val
                        }
                    }

                    Divider { width: parent.width }

                    // Live Ticker Display Card
                    Rectangle {
                        width: parent.width
                        height: 52
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.08)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            Icon {
                                width: 22; height: 22
                                path: (dynamoPage.isleFinance && dynamoPage.isleFinance.changePercent >= 0) ? Icons.arrowUp : Icons.arrowDown
                                color: (dynamoPage.isleFinance && dynamoPage.isleFinance.changePercent >= 0) ? "#34D399" : "#F87171"
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    spacing: 8
                                    Txt {
                                        text: (dynamoPage.isleFinance && dynamoPage.isleFinance.symbol) ? dynamoPage.isleFinance.symbol : "BTC"
                                        size: 13
                                        weight: Font.Bold
                                        color: "#FFFFFF"
                                    }
                                    Txt {
                                        text: (dynamoPage.isleFinance && dynamoPage.isleFinance.priceFormatted) ? dynamoPage.isleFinance.priceFormatted : "$0.00"
                                        size: 13
                                        weight: Font.DemiBold
                                        color: "#38BDF8"
                                    }
                                    Rectangle {
                                        height: 16
                                        width: pctTxt.implicitWidth + 8
                                        radius: 4
                                        color: (dynamoPage.isleFinance && dynamoPage.isleFinance.changePercent >= 0) ? Qt.rgba(0.2, 0.8, 0.4, 0.2) : Qt.rgba(0.9, 0.2, 0.2, 0.2)

                                        Txt {
                                            id: pctTxt
                                            anchors.centerIn: parent
                                            text: {
                                                if (!dynamoPage.isleFinance || dynamoPage.isleFinance.changePercent === undefined) return "+0.00%"
                                                const cp = dynamoPage.isleFinance.changePercent
                                                return (cp >= 0 ? "+" : "") + cp.toFixed(2) + "%"
                                            }
                                            size: 9.5
                                            weight: Font.Bold
                                            color: (dynamoPage.isleFinance && dynamoPage.isleFinance.changePercent >= 0) ? "#34D399" : "#F87171"
                                        }
                                    }
                                }

                                Txt {
                                    text: qsTr("Source: %1 | Provider: %2").arg((dynamoPage.isleFinance && dynamoPage.isleFinance.source) ? dynamoPage.isleFinance.source : "IsleEngine").arg((dynamoPage.isleFinance && dynamoPage.isleFinance.provider) ? dynamoPage.isleFinance.provider : "AwesomeAPI")
                                    size: 10
                                    color: Qt.rgba(1, 1, 1, 0.45)
                                }
                            }

                            Button {
                                text: qsTr("Refresh Ticker")
                                variant: "secondary"
                                size: "sm"
                                onClicked: DynamoController.refreshIsleFinance()
                            }
                        }
                    }

                    // Symbol Selection and Quick Test Row
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Txt {
                            text: qsTr("Select Symbol:")
                            size: 11
                            color: Qt.rgba(1, 1, 1, 0.7)
                        }

                        Button {
                            text: qsTr("BTC")
                            variant: (Preferences.notchIsleFinanceSymbol === "BTC") ? "primary" : "tonal"
                            size: "sm"
                            onClicked: {
                                Preferences.notchIsleFinanceSymbol = "BTC"
                                DynamoController.setIsleSymbol("BTC")
                            }
                        }

                        Button {
                            text: qsTr("ETH")
                            variant: (Preferences.notchIsleFinanceSymbol === "ETH") ? "primary" : "tonal"
                            size: "sm"
                            onClicked: {
                                Preferences.notchIsleFinanceSymbol = "ETH"
                                DynamoController.setIsleSymbol("ETH")
                            }
                        }

                        Button {
                            text: qsTr("SOL")
                            variant: (Preferences.notchIsleFinanceSymbol === "SOL") ? "primary" : "tonal"
                            size: "sm"
                            onClicked: {
                                Preferences.notchIsleFinanceSymbol = "SOL"
                                DynamoController.setIsleSymbol("SOL")
                            }
                        }

                        Button {
                            text: qsTr("EUR")
                            variant: (Preferences.notchIsleFinanceSymbol === "EUR") ? "primary" : "tonal"
                            size: "sm"
                            onClicked: {
                                Preferences.notchIsleFinanceSymbol = "EUR"
                                DynamoController.setIsleSymbol("EUR")
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: qsTr("Simulate Bull (+4.2%)")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.simulateIsleQuote("BTC", 98500.0, 4.2)
                        }

                        Button {
                            text: qsTr("Simulate Bear (-3.1%)")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.simulateIsleQuote("BTC", 92100.0, -3.1)
                        }
                    }
                }
            }

            // ================================================================
            // SECTION 3.20: MacIsland — Battery & Fast Charge HUD + AirDrop (BadRat-in/MacIsland)
            // ================================================================
            Card {
                width: parent.width
                padding: 18
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "system"

                Column {
                    width: parent.width
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(0.2, 0.8, 0.4, 0.14)
                            border.width: 1; border.color: Qt.rgba(0.2, 0.8, 0.4, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.batteryCharging; color: "#34D399" }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: qsTr("MacIsland — Battery & Fast Charge HUD + AirDrop")
                                role: "title"
                                size: 14
                                weight: Font.Bold
                            }

                            Txt {
                                text: qsTr("Reverse-engineered from BadRat-in/MacIsland: Real-time IOKit power source tracking, AC/MagSafe connection triggers, time-remaining projections, and instant notch-level AirDrop sharing.")
                                role: "body"
                                size: 11
                                color: Qt.rgba(1, 1, 1, 0.6)
                                wrapMode: Text.WordWrap
                            }
                        }

                        Toggle {
                            checked: Preferences.notchMacislandBatteryHudEnabled
                            onToggled: (val) => Preferences.notchMacislandBatteryHudEnabled = val
                        }
                    }

                    Divider { width: parent.width }

                    // Live Battery Telemetry Card
                    Rectangle {
                        width: parent.width
                        height: 60
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.08)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            Rectangle {
                                width: 36; height: 36
                                radius: 18
                                color: (dynamoPage.macislandBattery && dynamoPage.macislandBattery.isCharging) ? Qt.rgba(0.2, 0.8, 0.4, 0.2) : Qt.rgba(1, 1, 1, 0.08)
                                border.width: 1
                                border.color: (dynamoPage.macislandBattery && dynamoPage.macislandBattery.isCharging) ? "#34D399" : Qt.rgba(1, 1, 1, 0.15)

                                Txt {
                                    anchors.centerIn: parent
                                    text: (dynamoPage.macislandBattery && dynamoPage.macislandBattery.isCharging) ? "⚡" : "🔋"
                                    size: 15
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    spacing: 8

                                    Txt {
                                        text: {
                                            if (!dynamoPage.macislandBattery || dynamoPage.macislandBattery.percentage === undefined) return "100%"
                                            return dynamoPage.macislandBattery.percentage + "%"
                                        }
                                        size: 14
                                        weight: Font.Bold
                                        color: (dynamoPage.macislandBattery && dynamoPage.macislandBattery.percentage <= 20 && !dynamoPage.macislandBattery.isCharging) ? "#F87171" : "#FFFFFF"
                                    }

                                    Rectangle {
                                        height: 16
                                        width: statusTag.implicitWidth + 8
                                        radius: 4
                                        color: (dynamoPage.macislandBattery && dynamoPage.macislandBattery.isCharging) ? Qt.rgba(0.2, 0.8, 0.4, 0.22) : Qt.rgba(1, 1, 1, 0.1)

                                        Txt {
                                            id: statusTag
                                            anchors.centerIn: parent
                                            text: (dynamoPage.macislandBattery && dynamoPage.macislandBattery.stateDescription) ? dynamoPage.macislandBattery.stateDescription : "On Battery"
                                            size: 9
                                            weight: Font.DemiBold
                                            color: (dynamoPage.macislandBattery && dynamoPage.macislandBattery.isCharging) ? "#34D399" : "#CBD5E1"
                                        }
                                    }

                                    Txt {
                                        text: (dynamoPage.macislandBattery && dynamoPage.macislandBattery.timeRemaining) ? ("(" + dynamoPage.macislandBattery.timeRemaining + ")") : ""
                                        size: 11
                                        color: Qt.rgba(1, 1, 1, 0.55)
                                    }
                                }

                                Txt {
                                    text: qsTr("Source: %1 | Adapter: %2").arg((dynamoPage.macislandBattery && dynamoPage.macislandBattery.source) ? dynamoPage.macislandBattery.source : "IOKit").arg((dynamoPage.macislandBattery && dynamoPage.macislandBattery.isACPower) ? "Connected" : "Disconnected")
                                    size: 10
                                    color: Qt.rgba(1, 1, 1, 0.4)
                                }
                            }

                            Button {
                                text: qsTr("Open AirDrop")
                                variant: "primary"
                                size: "sm"
                                onClicked: DynamoController.triggerAirDrop("")
                            }
                        }
                    }

                    // Simulation and Diagnostics Row
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Txt {
                            text: qsTr("Simulate Power Events:")
                            size: 11
                            color: Qt.rgba(1, 1, 1, 0.7)
                        }

                        Button {
                            text: qsTr("Plug MagSafe (85% Charging)")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.simulateMacIslandBattery(85, true)
                        }

                        Button {
                            text: qsTr("Low Battery (14%)")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.simulateMacIslandBattery(14, false)
                        }

                        Button {
                            text: qsTr("Full (100%)")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.simulateMacIslandBattery(100, true)
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: qsTr("Reset Simulation")
                            variant: "secondary"
                            size: "sm"
                            onClicked: DynamoController.resetMacIslandBattery()
                        }
                    }
                }
            }

            // ================================================================
            // SECTION 3.21: MacWake — Cleaning Mode & Thermal Telemetry (Jarvis322/MacWake)
            // ================================================================
            Card {
                width: parent.width
                padding: 18
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "storage" || dynamoPage.selectedCategory === "wings"

                Column {
                    width: parent.width
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(0.97, 0.44, 0.44, 0.14)
                            border.width: 1; border.color: Qt.rgba(0.97, 0.44, 0.44, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.flame; color: "#F87171" }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: qsTr("MacWake — Screen/Keyboard Cleaning Mode & Thermal Monitor")
                                role: "title"
                                size: 14
                                weight: Font.Bold
                            }

                            Txt {
                                text: qsTr("Reverse-engineered from Jarvis322/MacWake: Safe display & keyboard wiping lock mode, plus real-time Apple Silicon SoC, CPU, and GPU thermal telemetry at the notch.")
                                role: "body"
                                size: 11
                                color: Qt.rgba(1, 1, 1, 0.6)
                                wrapMode: Text.WordWrap
                            }
                        }

                        Toggle {
                            checked: Preferences.notchMacwakeCleaningModeEnabled
                            onToggled: (val) => Preferences.notchMacwakeCleaningModeEnabled = val
                        }
                    }

                    Divider { width: parent.width }

                    // Live Thermal Telemetry Card
                    Rectangle {
                        width: parent.width
                        height: 56
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.08)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 14

                            Icon {
                                width: 22; height: 22
                                path: Icons.cpu
                                color: (dynamoPage.macwakeThermal && dynamoPage.macwakeThermal.isThrottling) ? "#F87171" : "#38BDF8"
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    spacing: 8

                                    Txt {
                                        text: qsTr("CPU: %1°C (%2°F)").arg((dynamoPage.macwakeThermal && dynamoPage.macwakeThermal.cpuTempC) ? dynamoPage.macwakeThermal.cpuTempC : 45.0).arg((dynamoPage.macwakeThermal && dynamoPage.macwakeThermal.cpuTempF) ? dynamoPage.macwakeThermal.cpuTempF : 113.0)
                                        size: 13
                                        weight: Font.Bold
                                        color: "#FFFFFF"
                                    }

                                    Txt {
                                        text: qsTr("GPU: %1°C").arg((dynamoPage.macwakeThermal && dynamoPage.macwakeThermal.gpuTempC) ? dynamoPage.macwakeThermal.gpuTempC : 43.0)
                                        size: 12
                                        weight: Font.Medium
                                        color: "#94A3B8"
                                    }

                                    Rectangle {
                                        height: 16
                                        width: thermBadge.implicitWidth + 8
                                        radius: 4
                                        color: (dynamoPage.macwakeThermal && dynamoPage.macwakeThermal.isThrottling) ? Qt.rgba(0.9, 0.2, 0.2, 0.22) : Qt.rgba(0.2, 0.7, 0.4, 0.2)

                                        Txt {
                                            id: thermBadge
                                            anchors.centerIn: parent
                                            text: (dynamoPage.macwakeThermal && dynamoPage.macwakeThermal.thermalState) ? dynamoPage.macwakeThermal.thermalState : "Nominal"
                                            size: 9
                                            weight: Font.Bold
                                            color: (dynamoPage.macwakeThermal && dynamoPage.macwakeThermal.isThrottling) ? "#F87171" : "#34D399"
                                        }
                                    }
                                }

                                Txt {
                                    text: qsTr("Source: %1 | Thermal Pressure: %2%").arg((dynamoPage.macwakeThermal && dynamoPage.macwakeThermal.source) ? dynamoPage.macwakeThermal.source : "AppleThermalEngine").arg(Math.round(((dynamoPage.macwakeThermal && dynamoPage.macwakeThermal.pressureRatio) ? dynamoPage.macwakeThermal.pressureRatio : 0.2) * 100))
                                    size: 10
                                    color: Qt.rgba(1, 1, 1, 0.4)
                                }
                            }
                        }
                    }

                    // Cleaning Mode Trigger Controls
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Txt {
                            text: qsTr("Cleaning Mode:")
                            size: 11
                            color: Qt.rgba(1, 1, 1, 0.7)
                        }

                        Button {
                            text: (dynamoPage.macwakeCleaning && dynamoPage.macwakeCleaning.isActive)
                                ? qsTr("Cleaning Active (%1s)").arg(dynamoPage.macwakeCleaning.remainingSeconds)
                                : qsTr("Start 30s Clean Mode")
                            variant: (dynamoPage.macwakeCleaning && dynamoPage.macwakeCleaning.isActive) ? "primary" : "tonal"
                            size: "sm"
                            onClicked: {
                                if (dynamoPage.macwakeCleaning && dynamoPage.macwakeCleaning.isActive) {
                                    DynamoController.stopCleaningMode()
                                } else {
                                    DynamoController.startCleaningMode(30)
                                }
                            }
                        }

                        Button {
                            text: qsTr("Start 60s Clean Mode")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.startCleaningMode(60)
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: qsTr("Simulate Hot (88°C)")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.simulateMacWakeThermal(88.0, 84.0)
                        }

                        Button {
                            text: qsTr("Simulate Cool (38°C)")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.simulateMacWakeThermal(38.0, 36.0)
                        }

                        Button {
                            text: qsTr("Reset Thermal")
                            variant: "secondary"
                            size: "sm"
                            onClicked: DynamoController.resetMacWakeThermal()
                        }
                    }
                }
            }

            // ================================================================
            // SECTION 3.22: PiIsland — AI Coding Agent Session HUD (phun333 & jwintz)
            // ================================================================
            Card {
                width: parent.width
                padding: 18
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "live_activity"

                Column {
                    width: parent.width
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(0.2, 0.7, 1.0, 0.14)
                            border.width: 1; border.color: Qt.rgba(0.2, 0.7, 1.0, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.terminal; color: "#38BDF8" }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: qsTr("PiIsland — AI Coding Agent Session HUD & Quotas")
                                role: "title"
                                size: 14
                                weight: Font.Bold
                            }

                            Txt {
                                text: qsTr("Reverse-engineered from phun333/pi-island & jwintz/pi-island: Real-time telemetry for Antigravity, Claude Code, Gemini CLI, and Copilot sessions with live tool call pills, token burn rate, and provider quota tracking.")
                                role: "body"
                                size: 11
                                color: Qt.rgba(1, 1, 1, 0.6)
                                wrapMode: Text.WordWrap
                            }
                        }

                        Toggle {
                            checked: Preferences.notchPiislandSessionMonitorEnabled
                            onToggled: (val) => Preferences.notchPiislandSessionMonitorEnabled = val
                        }
                    }

                    Divider { width: parent.width }

                    // Live AI Session Telemetry Card
                    Rectangle {
                        width: parent.width
                        height: 64
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.08)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            Rectangle {
                                width: 38; height: 38
                                radius: 19
                                color: Qt.rgba(0.2, 0.7, 1.0, 0.18)
                                border.width: 1
                                border.color: "#38BDF8"

                                Txt {
                                    anchors.centerIn: parent
                                    text: "✨"
                                    size: 15
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 3

                                RowLayout {
                                    spacing: 8

                                    Txt {
                                        text: (dynamoPage.piislandSessions && dynamoPage.piislandSessions.currentSession)
                                            ? (dynamoPage.piislandSessions.currentSession.agent + " (" + dynamoPage.piislandSessions.currentSession.model + ")")
                                            : "Antigravity (Gemini 2.5 Pro)"
                                        size: 13
                                        weight: Font.Bold
                                        color: "#FFFFFF"
                                    }

                                    Rectangle {
                                        height: 16
                                        width: statusText.implicitWidth + 8
                                        radius: 4
                                        color: Qt.rgba(0.2, 0.7, 1.0, 0.2)

                                        Txt {
                                            id: statusText
                                            anchors.centerIn: parent
                                            text: (dynamoPage.piislandSessions && dynamoPage.piislandSessions.currentSession && dynamoPage.piislandSessions.currentSession.status)
                                                ? (dynamoPage.piislandSessions.currentSession.status + ": " + dynamoPage.piislandSessions.currentSession.activeTool)
                                                : "Executing Tool: run_command"
                                            size: 9
                                            weight: Font.DemiBold
                                            color: "#38BDF8"
                                        }
                                    }
                                }

                                Txt {
                                    text: qsTr("Tokens Used: %1 | Burn: %2 tok/min | Quota Remaining: %3%").arg(
                                        (dynamoPage.piislandSessions && dynamoPage.piislandSessions.currentSession) ? dynamoPage.piislandSessions.currentSession.tokensUsed : 48250
                                    ).arg(
                                        (dynamoPage.piislandSessions && dynamoPage.piislandSessions.currentSession) ? dynamoPage.piislandSessions.currentSession.burnRateTokensPerMin : 2400
                                    ).arg(
                                        (dynamoPage.piislandSessions && dynamoPage.piislandSessions.currentSession) ? dynamoPage.piislandSessions.currentSession.quotaRemainingPercent : 84.5
                                    )
                                    size: 10
                                    color: Qt.rgba(1, 1, 1, 0.45)
                                }
                            }
                        }
                    }

                    // Simulation and Controls Row
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Txt {
                            text: qsTr("Simulate Agent Session:")
                            size: 11
                            color: Qt.rgba(1, 1, 1, 0.7)
                        }

                        Button {
                            text: qsTr("Antigravity: run_command")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.simulatePiIslandEvent("Antigravity", "Gemini 2.5 Pro", "Executing Tool", "run_command")
                        }

                        Button {
                            text: qsTr("Claude Code: edit_file")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.simulatePiIslandEvent("Claude Code", "Claude 3.5 Sonnet", "Applying Diff", "edit_file")
                        }

                        Button {
                            text: qsTr("Copilot: completions")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.simulatePiIslandEvent("Copilot", "GPT-4o", "Streaming", "completion")
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: qsTr("Reset Agent")
                            variant: "secondary"
                            size: "sm"
                            onClicked: DynamoController.resetPiIslandSimulation()
                        }
                    }
                }
            }

            // ================================================================
            // SECTION 3.23: Pookify — Animated Agent Glyphs (eyadhammouda/pookify)
            // ================================================================
            Card {
                width: parent.width
                padding: 18
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "tools"

                Column {
                    width: parent.width
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(0.85, 0.47, 0.34, 0.14)
                            border.width: 1; border.color: Qt.rgba(0.85, 0.47, 0.34, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.sparkle; color: "#D97757" }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: qsTr("Pookify — Animated Claude Agent Glyphs & Sessions")
                                role: "title"
                                size: 14
                                weight: Font.Bold
                            }

                            Txt {
                                text: qsTr("Reverse-engineered from eyadhammouda/pookify: Animated Claude Code crab & spark glyph engine, multi-session priority queue, and turn progress timing directly at the notch.")
                                role: "body"
                                size: 11
                                color: Qt.rgba(1, 1, 1, 0.6)
                                wrapMode: Text.WordWrap
                            }
                        }

                        Toggle {
                            checked: Preferences.notchPookifyAgentGlyphsEnabled
                            onToggled: (val) => Preferences.notchPookifyAgentGlyphsEnabled = val
                        }
                    }

                    Divider { width: parent.width }

                    // Live Animated Glyph Telemetry Card
                    Rectangle {
                        width: parent.width
                        height: 56
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.08)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 14

                            Rectangle {
                                width: 34; height: 34
                                radius: 17
                                color: Qt.rgba(0.85, 0.47, 0.34, 0.22)
                                border.width: 1
                                border.color: "#D97757"

                                Txt {
                                    anchors.centerIn: parent
                                    text: (dynamoPage.pookifyAnim && dynamoPage.pookifyAnim.glyph) ? dynamoPage.pookifyAnim.glyph : "🦀"
                                    size: 16
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    spacing: 8

                                    Txt {
                                        text: (dynamoPage.pookifyAnim && dynamoPage.pookifyAnim.currentTurn && dynamoPage.pookifyAnim.currentTurn.label)
                                            ? dynamoPage.pookifyAnim.currentTurn.label
                                            : "Editing IslandWindow.qml"
                                        size: 13
                                        weight: Font.Bold
                                        color: "#FFFFFF"
                                    }

                                    Rectangle {
                                        height: 16
                                        width: stateTag.implicitWidth + 8
                                        radius: 4
                                        color: Qt.rgba(0.85, 0.47, 0.34, 0.22)

                                        Txt {
                                            id: stateTag
                                            anchors.centerIn: parent
                                            text: (dynamoPage.pookifyAnim && dynamoPage.pookifyAnim.state) ? dynamoPage.pookifyAnim.state.toUpperCase() : "TOOL"
                                            size: 9
                                            weight: Font.Bold
                                            color: "#D97757"
                                        }
                                    }

                                    Txt {
                                        text: qsTr("(%1s elapsed)").arg(
                                            (dynamoPage.pookifyAnim && dynamoPage.pookifyAnim.currentTurn) ? dynamoPage.pookifyAnim.currentTurn.durationSeconds : 18
                                        )
                                        size: 10.5
                                        color: Qt.rgba(1, 1, 1, 0.5)
                                    }
                                }

                                Txt {
                                    text: qsTr("Provider: %1 | Tool: %2").arg(
                                        (dynamoPage.pookifyAnim && dynamoPage.pookifyAnim.provider) ? dynamoPage.pookifyAnim.provider : "Claude Code"
                                    ).arg(
                                        (dynamoPage.pookifyAnim && dynamoPage.pookifyAnim.currentTurn) ? dynamoPage.pookifyAnim.currentTurn.tool : "Edit"
                                    )
                                    size: 10
                                    color: Qt.rgba(1, 1, 1, 0.4)
                                }
                            }
                        }
                    }

                    // Simulation and Controls Row
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Txt {
                            text: qsTr("Simulate Claude States:")
                            size: 11
                            color: Qt.rgba(1, 1, 1, 0.7)
                        }

                        Button {
                            text: qsTr("Crab: Editing (🦀)")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.simulatePookifyEvent("tool", "Edit", "IslandWindow.qml")
                        }

                        Button {
                            text: qsTr("Spark: Thinking (✦)")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.simulatePookifyEvent("thinking", "Reasoning", "Architecture")
                        }

                        Button {
                            text: qsTr("Warn: Permission (⚠️)")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.simulatePookifyEvent("permission", "Bash", "rm -rf build")
                        }

                        Button {
                            text: qsTr("Done: Party (🎉)")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.simulatePookifyEvent("done", "Complete", "Session Finished")
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: qsTr("Reset")
                            variant: "secondary"
                            size: "sm"
                            onClicked: DynamoController.resetPookifySimulation()
                        }
                    }
                }
            }

            // ================================================================
            // SECTION 3.24: Windows Dynamic Island — "Find on Screen" Live Vision OCR Search Engine
            // Reverse-Engineered from HeyyCzer/windows-dynamic-island
            // ================================================================
            Card {
                width: parent.width
                padding: 18
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "tools"

                Column {
                    width: parent.width
                    spacing: 14

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(0.01, 0.52, 0.78, 0.14)
                            border.width: 1; border.color: Qt.rgba(0.01, 0.52, 0.78, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.search; color: "#0284C7" }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: qsTr("Windows Dynamic Island — \"Find on Screen\" Vision OCR Engine")
                                role: "title"
                                size: 14
                                weight: Font.DemiBold
                            }

                            Txt {
                                text: qsTr("Real-time ScreenCaptureKit frame capture and Apple Vision OCR text locator directly at the notch.")
                                role: "caption"
                                size: 11
                                color: "#94A3B8"
                            }
                        }

                        Toggle {
                            checked: Preferences.notchVisionOcrSearchEnabled
                            onToggled: (val) => Preferences.notchVisionOcrSearchEnabled = val
                        }
                    }

                    // Live Search Bar & Status Card
                    Rectangle {
                        width: parent.width
                        height: 120
                        radius: 10
                        color: Qt.rgba(0.04, 0.08, 0.16, 0.6)
                        border.width: 1
                        border.color: Preferences.notchVisionOcrSearchEnabled ? "#0284C7" : "#334155"

                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            RowLayout {
                                width: parent.width
                                spacing: 8

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 32
                                    radius: 6
                                    color: Qt.rgba(0, 0, 0, 0.35)
                                    border.color: Qt.rgba(1, 1, 1, 0.12)
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 6

                                        Icon {
                                            width: 12; height: 12
                                            path: Icons.search
                                            color: ocrSearchInput.activeFocus ? Theme.primary : Qt.rgba(1, 1, 1, 0.40)
                                        }

                                        TextInput {
                                            id: ocrSearchInput
                                            Layout.fillWidth: true
                                            font.pixelSize: 11
                                            color: "#FFFFFF"
                                            clip: true
                                            verticalAlignment: TextInput.AlignVCenter
                                            selectByMouse: true

                                            Text {
                                                text: qsTr("Type search phrase (e.g. error, import, function)...")
                                                color: Qt.rgba(1, 1, 1, 0.35)
                                                font: ocrSearchInput.font
                                                visible: !ocrSearchInput.text && !ocrSearchInput.inputMethodComposing
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            onAccepted: {
                                                if (text.length > 0) {
                                                    DynamoController.searchScreenText(text)
                                                }
                                            }
                                        }
                                    }
                                }

                                Button {
                                    text: qsTr("Search Screen")
                                    variant: "primary"
                                    size: "sm"
                                    onClicked: {
                                        if (ocrSearchInput.text.length > 0) {
                                            DynamoController.searchScreenText(ocrSearchInput.text)
                                        }
                                    }
                                }

                                Button {
                                    text: qsTr("Clear")
                                    variant: "secondary"
                                    size: "sm"
                                    onClicked: {
                                        ocrSearchInput.text = ""
                                        DynamoController.clearScreenSearch()
                                    }
                                }
                            }

                            RowLayout {
                                width: parent.width
                                spacing: 8

                                Row {
                                    spacing: 6
                                    Layout.fillWidth: true
                                    Txt {
                                        text: dynamoPage.screenOcr && dynamoPage.screenOcr.isScanning ? "Scanning screen via ScreenCaptureKit & Vision..." : (
                                            dynamoPage.screenOcr && dynamoPage.screenOcr.hasScanned ?
                                                ("Matches: " + (dynamoPage.screenOcr.matchCount || 0) + " found | Current: #" + (dynamoPage.screenOcr.currentIndex || 0)) :
                                                "Ready to scan display text"
                                        )
                                        role: "caption"
                                        size: 11
                                        color: "#BAE6FD"
                                    }
                                }

                                Button {
                                    text: qsTr("◀ Prev")
                                    variant: "secondary"
                                    size: "sm"
                                    enabled: (dynamoPage.screenOcr && dynamoPage.screenOcr.matchCount > 0)
                                    onClicked: DynamoController.previousScreenMatch()
                                }

                                Button {
                                    text: qsTr("Next ▶")
                                    variant: "secondary"
                                    size: "sm"
                                    enabled: (dynamoPage.screenOcr && dynamoPage.screenOcr.matchCount > 0)
                                    onClicked: DynamoController.nextScreenMatch()
                                }
                            }
                        }
                    }

                    // Test & Simulation Actions
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Txt {
                            text: qsTr("Simulate Results:")
                            role: "caption"
                            size: 11
                            color: "#64748B"
                        }

                        Button {
                            text: qsTr("Simulate 'Error' (4)")
                            variant: "secondary"
                            size: "sm"
                            onClicked: {
                                ocrSearchInput.text = "Error"
                                DynamoController.simulateScreenMatches("Error", 4)
                            }
                        }

                        Button {
                            text: qsTr("Simulate 'Token' (7)")
                            variant: "secondary"
                            size: "sm"
                            onClicked: {
                                ocrSearchInput.text = "Token"
                                DynamoController.simulateScreenMatches("Token", 7)
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: qsTr("Reset Search")
                            variant: "secondary"
                            size: "sm"
                            onClicked: {
                                ocrSearchInput.text = ""
                                DynamoController.clearScreenSearch()
                            }
                        }
                    }
                }
            }

            // ================================================================
            // SECTION 3.25: TopNotch — Pomodoro Focus Engine & Notch Scratchpad
            // Reverse-Engineered from techuila/top-notch
            // ================================================================
            Card {
                width: parent.width
                padding: 18
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "tools"

                Column {
                    width: parent.width
                    spacing: 14

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(0.96, 0.62, 0.04, 0.14)
                            border.width: 1; border.color: Qt.rgba(0.96, 0.62, 0.04, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.clock; color: "#F59E0B" }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: qsTr("TopNotch — Pomodoro Focus Timer & Quick Scratchpad")
                                role: "title"
                                size: 14
                                weight: Font.DemiBold
                            }

                            Txt {
                                text: qsTr("Dedicated focus countdown ring, cycle tracker, and persistent quick notes parked directly at the notch.")
                                role: "caption"
                                size: 11
                                color: "#94A3B8"
                            }
                        }

                        Toggle {
                            checked: Preferences.notchTopnotchFocusEnabled
                            onToggled: (val) => Preferences.notchTopnotchFocusEnabled = val
                        }
                    }

                    // Pomodoro Telemetry & Countdown Card
                    Rectangle {
                        width: parent.width
                        height: 90
                        radius: 10
                        color: Qt.rgba(0.08, 0.05, 0.15, 0.6)
                        border.width: 1
                        border.color: Preferences.notchTopnotchFocusEnabled ? "#F59E0B" : "#334155"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 16

                            // Timer Badge & Icon
                            Rectangle {
                                width: 56
                                height: 56
                                radius: 28
                                color: (dynamoPage.topnotchFocus && dynamoPage.topnotchFocus.phase === "work") ? Qt.rgba(0.96, 0.62, 0.04, 0.20) : Qt.rgba(0.06, 0.72, 0.50, 0.20)
                                border.width: 1.5
                                border.color: (dynamoPage.topnotchFocus && dynamoPage.topnotchFocus.phase === "work") ? "#F59E0B" : "#10B981"

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 0
                                    Txt {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: (dynamoPage.topnotchFocus && dynamoPage.topnotchFocus.phase === "work") ? "⏱️" : "☕"
                                        size: 16
                                    }
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 4

                                Row {
                                    spacing: 8
                                    Txt {
                                        text: (dynamoPage.topnotchFocus && dynamoPage.topnotchFocus.formattedTime) ? dynamoPage.topnotchFocus.formattedTime : "25:00"
                                        role: "title"
                                        size: 20
                                        weight: Font.Bold
                                        color: "#FDE68A"
                                    }

                                    Rectangle {
                                        height: 18
                                        width: phaseTxt.implicitWidth + 10
                                        radius: 9
                                        color: (dynamoPage.topnotchFocus && dynamoPage.topnotchFocus.phase === "work") ? "#B45309" : "#047857"
                                        anchors.verticalCenter: parent.verticalCenter

                                        Txt {
                                            id: phaseTxt
                                            anchors.centerIn: parent
                                            text: (dynamoPage.topnotchFocus && dynamoPage.topnotchFocus.phaseLabel) ? dynamoPage.topnotchFocus.phaseLabel.toUpperCase() : "FOCUS"
                                            size: 9
                                            weight: Font.Bold
                                            color: "#FFFFFF"
                                        }
                                    }

                                    Txt {
                                        text: "• Cycle " + ((dynamoPage.topnotchFocus && dynamoPage.topnotchFocus.currentCycle) || 1) + "/4"
                                        role: "caption"
                                        size: 11
                                        color: "#CBD5E1"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Txt {
                                        text: "• " + ((dynamoPage.topnotchFocus && dynamoPage.topnotchFocus.totalRoundsToday) || 0) + " rounds completed today"
                                        role: "caption"
                                        size: 11
                                        color: "#94A3B8"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                // Progress Bar
                                Rectangle {
                                    width: parent.width
                                    height: 5
                                    radius: 2.5
                                    color: "#1E293B"

                                    Rectangle {
                                        height: parent.height
                                        radius: 2.5
                                        color: (dynamoPage.topnotchFocus && dynamoPage.topnotchFocus.phase === "work") ? "#F59E0B" : "#10B981"
                                        width: Math.min(parent.width, Math.max(4, parent.width * ((dynamoPage.topnotchFocus && dynamoPage.topnotchFocus.progress) || 0)))
                                    }
                                }
                            }
                        }
                    }

                    // Focus Controls
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Button {
                            text: (dynamoPage.topnotchFocus && dynamoPage.topnotchFocus.isRunning) ? qsTr("Pause Focus") : qsTr("Start 25m Focus")
                            variant: (dynamoPage.topnotchFocus && dynamoPage.topnotchFocus.isRunning) ? "secondary" : "primary"
                            size: "sm"
                            onClicked: {
                                if (dynamoPage.topnotchFocus && dynamoPage.topnotchFocus.isRunning) {
                                    DynamoController.topnotchPauseFocus()
                                } else if (dynamoPage.topnotchFocus && dynamoPage.topnotchFocus.isPaused) {
                                    DynamoController.topnotchResumeFocus()
                                } else {
                                    DynamoController.topnotchStartFocus(25)
                                }
                            }
                        }

                        Button {
                            text: qsTr("Start 50m Focus")
                            variant: "secondary"
                            size: "sm"
                            onClicked: DynamoController.topnotchStartFocus(50)
                        }

                        Button {
                            text: qsTr("Skip Phase")
                            variant: "secondary"
                            size: "sm"
                            enabled: (dynamoPage.topnotchFocus && (dynamoPage.topnotchFocus.isRunning || dynamoPage.topnotchFocus.isPaused))
                            onClicked: DynamoController.topnotchSkipFocus()
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: qsTr("Reset Timer")
                            variant: "secondary"
                            size: "sm"
                            onClicked: DynamoController.topnotchResetFocus()
                        }
                    }

                    // Quick Scratchpad & Pinned Notes
                    Column {
                        width: parent.width
                        spacing: 8

                        Txt {
                            text: qsTr("Notch Scratchpad & Pinned Notes (%1)").arg((dynamoPage.topnotchFocus && dynamoPage.topnotchFocus.noteCount) || 0)
                            role: "caption"
                            size: 12
                            weight: Font.DemiBold
                            color: "#E2E8F0"
                        }

                        RowLayout {
                            width: parent.width
                            spacing: 8

                            Rectangle {
                                Layout.preferredWidth: 160
                                height: 32
                                radius: 6
                                color: Qt.rgba(0, 0, 0, 0.35)
                                border.color: Qt.rgba(1, 1, 1, 0.12)
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8

                                    TextInput {
                                        id: noteTitleInput
                                        Layout.fillWidth: true
                                        font.pixelSize: 11
                                        color: "#FFFFFF"
                                        clip: true
                                        verticalAlignment: TextInput.AlignVCenter
                                        selectByMouse: true

                                        Text {
                                            text: qsTr("Note Title...")
                                            color: Qt.rgba(1, 1, 1, 0.35)
                                            font: noteTitleInput.font
                                            visible: !noteTitleInput.text && !noteTitleInput.inputMethodComposing
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 32
                                radius: 6
                                color: Qt.rgba(0, 0, 0, 0.35)
                                border.color: Qt.rgba(1, 1, 1, 0.12)
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8

                                    TextInput {
                                        id: noteBodyInput
                                        Layout.fillWidth: true
                                        font.pixelSize: 11
                                        color: "#FFFFFF"
                                        clip: true
                                        verticalAlignment: TextInput.AlignVCenter
                                        selectByMouse: true

                                        Text {
                                            text: qsTr("Note body (plain text / markdown)...")
                                            color: Qt.rgba(1, 1, 1, 0.35)
                                            font: noteBodyInput.font
                                            visible: !noteBodyInput.text && !noteBodyInput.inputMethodComposing
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                            }

                            Button {
                                text: qsTr("+ Pin Note")
                                variant: "primary"
                                size: "sm"
                                onClicked: {
                                    if (noteBodyInput.text.length > 0) {
                                        DynamoController.topnotchSaveNote(noteTitleInput.text, noteBodyInput.text)
                                        noteTitleInput.text = ""
                                        noteBodyInput.text = ""
                                    }
                                }
                            }
                        }

                        // Notes repeater / items
                        Column {
                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: (dynamoPage.topnotchFocus && dynamoPage.topnotchFocus.notes) ? dynamoPage.topnotchFocus.notes : []

                                Rectangle {
                                    width: parent.width
                                    height: 52
                                    radius: 8
                                    color: Qt.rgba(0.08, 0.12, 0.20, 0.45)
                                    border.width: 1
                                    border.color: "#334155"

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 12

                                        Column {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Row {
                                                spacing: 6
                                                Txt {
                                                    text: modelData.title || "Note"
                                                    role: "caption"
                                                    size: 11
                                                    weight: Font.DemiBold
                                                    color: "#FFFFFF"
                                                }
                                                Txt {
                                                    text: "• " + (modelData.wordCount || 0) + " words (" + (modelData.charCount || 0) + " chars)"
                                                    role: "caption"
                                                    size: 10
                                                    color: "#64748B"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }

                                            Txt {
                                                text: (modelData.text || "").replace(/\n/g, " ")
                                                role: "caption"
                                                size: 10
                                                color: "#94A3B8"
                                                elide: Text.ElideRight
                                                width: parent.width
                                            }
                                        }

                                        Button {
                                            text: qsTr("Delete")
                                            variant: "secondary"
                                            size: "sm"
                                            onClicked: DynamoController.topnotchDeleteNote(index)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ================================================================
            // SECTION 3.26: MacIsland2 — Video Call Ring Light & Audio Device Studio
            // Reverse-Engineered from ethantiller/macisland2
            // ================================================================
            Card {
                width: parent.width
                padding: 18
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "system"

                Column {
                    width: parent.width
                    spacing: 14

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(0.99, 0.88, 0.28, 0.14)
                            border.width: 1; border.color: Qt.rgba(0.99, 0.88, 0.28, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.video; color: "#FDE047" }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: qsTr("MacIsland2 — Video Call Ring Light & Audio Studio")
                                role: "title"
                                size: 14
                                weight: Font.DemiBold
                            }

                            Txt {
                                text: qsTr("Soft display border lighting for video calls, CoreAudio hardware switcher, and system level meters.")
                                role: "caption"
                                size: 11
                                color: "#94A3B8"
                            }
                        }

                        Toggle {
                            checked: Preferences.notchMacislandStudioEnabled
                            onToggled: (val) => Preferences.notchMacislandStudioEnabled = val
                        }
                    }

                    // Ring Light Control Card
                    Rectangle {
                        width: parent.width
                        height: 95
                        radius: 10
                        color: Qt.rgba(0.12, 0.10, 0.04, 0.6)
                        border.width: 1
                        border.color: Preferences.notchMacislandStudioEnabled ? "#FDE047" : "#334155"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 16

                            Button {
                                text: (dynamoPage.macislandStudio && dynamoPage.macislandStudio.ringLightOn) ? qsTr("💡 Turn Off Ring Light") : qsTr("💡 Turn On Ring Light")
                                variant: (dynamoPage.macislandStudio && dynamoPage.macislandStudio.ringLightOn) ? "primary" : "secondary"
                                size: "md"
                                onClicked: DynamoController.macislandToggleRingLight()
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 6

                                RowLayout {
                                    width: parent.width
                                    Txt {
                                        text: qsTr("Brightness: %1%").arg(Math.round(((dynamoPage.macislandStudio && dynamoPage.macislandStudio.ringBrightness) || 0.8) * 100))
                                        role: "caption"
                                        size: 11
                                        color: "#FEF08A"
                                    }
                                    Item { Layout.fillWidth: true }
                                    Txt {
                                        text: qsTr("Border Width: %1%").arg(Math.round(((dynamoPage.macislandStudio && dynamoPage.macislandStudio.ringWidth) || 0.4) * 100))
                                        role: "caption"
                                        size: 11
                                        color: "#CBD5E1"
                                    }
                                }

                                RowLayout {
                                    width: parent.width
                                    spacing: 8

                                    Button {
                                        text: qsTr("Soft 40%")
                                        variant: "secondary"
                                        size: "sm"
                                        onClicked: DynamoController.macislandSetRingLight(0.4, 0.3)
                                    }

                                    Button {
                                        text: qsTr("Medium 70%")
                                        variant: "secondary"
                                        size: "sm"
                                        onClicked: DynamoController.macislandSetRingLight(0.7, 0.4)
                                    }

                                    Button {
                                        text: qsTr("Bright 100%")
                                        variant: "secondary"
                                        size: "sm"
                                        onClicked: DynamoController.macislandSetRingLight(1.0, 0.6)
                                    }
                                }
                            }
                        }
                    }

                    // CoreAudio Hardware Output Switcher
                    Column {
                        width: parent.width
                        spacing: 8

                        Txt {
                            text: qsTr("CoreAudio Output Devices (%1)").arg((dynamoPage.macislandStudio && dynamoPage.macislandStudio.deviceCount) || 0)
                            role: "caption"
                            size: 12
                            weight: Font.DemiBold
                            color: "#E2E8F0"
                        }

                        Column {
                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: (dynamoPage.macislandStudio && dynamoPage.macislandStudio.audioDevices) ? dynamoPage.macislandStudio.audioDevices : []

                                Rectangle {
                                    width: parent.width
                                    height: 44
                                    radius: 8
                                    color: modelData.isDefault ? Qt.rgba(0.06, 0.30, 0.20, 0.5) : Qt.rgba(0.08, 0.12, 0.20, 0.4)
                                    border.width: 1
                                    border.color: modelData.isDefault ? "#10B981" : "#334155"

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 10

                                        Txt {
                                            text: modelData.isDefault ? "🔊" : "🔈"
                                            size: 13
                                        }

                                        Column {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Row {
                                                spacing: 6
                                                Txt {
                                                    text: modelData.name || "Device"
                                                    role: "caption"
                                                    size: 11
                                                    weight: Font.DemiBold
                                                    color: "#FFFFFF"
                                                }
                                                Rectangle {
                                                    height: 14
                                                    width: transTxt.implicitWidth + 8
                                                    radius: 7
                                                    color: "#1E293B"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Txt {
                                                        id: transTxt
                                                        anchors.centerIn: parent
                                                        text: modelData.transport || "Output"
                                                        size: 8
                                                        color: "#94A3B8"
                                                    }
                                                }
                                            }
                                        }

                                        Button {
                                            text: modelData.isDefault ? qsTr("Active") : qsTr("Select")
                                            variant: modelData.isDefault ? "primary" : "secondary"
                                            size: "sm"
                                            enabled: !modelData.isDefault
                                            onClicked: DynamoController.macislandSelectAudioDevice(modelData.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ================================================================
            // SECTION 4: Liquid Glass Top Toolbar & Shortcuts
            // ================================================================
            Card {
                width: parent.width
                padding: 18
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "tools"

                Column {
                    width: parent.width
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                            border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.shelf; color: Theme.primary }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: qsTr("Liquid Glass Toolbar & Shortcuts")
                                role: "title"
                                weight: 600
                            }

                            Txt {
                                text: qsTr("Top toolbar features a permanent Home dashboard, 24 verified feature shortcuts, notch-safe spatial distribution, and smart More overflow.")
                                role: "bodySmall"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }

                        Button {
                            text: qsTr("Open Toolbar Editor")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.expand()
                        }
                    }

                    // Feature Icons Showcase Grid
                    Rectangle {
                        width: parent.width
                        height: 52
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.width: 0.75
                        border.color: Qt.rgba(1, 1, 1, 0.08)

                        Row {
                            anchors.centerIn: parent
                            spacing: 14

                            Icon { width: 16; height: 16; path: Icons.home; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                            Icon { width: 16; height: 16; path: Icons.sparkle; color: "#A855F7"; anchors.verticalCenter: parent.verticalCenter }
                            Icon { width: 16; height: 16; path: Icons.coffee; color: "#F59E0B"; anchors.verticalCenter: parent.verticalCenter }
                            Icon { width: 16; height: 16; path: Icons.mirror; color: "#38BDF8"; anchors.verticalCenter: parent.verticalCenter }
                            Icon { width: 16; height: 16; path: Icons.music; color: "#EC4899"; anchors.verticalCenter: parent.verticalCenter }
                            Icon { width: 16; height: 16; path: Icons.cpu; color: "#F59E0B"; anchors.verticalCenter: parent.verticalCenter }
                            Icon { width: 16; height: 16; path: Icons.trash; color: "#38BDF8"; anchors.verticalCenter: parent.verticalCenter }
                            Icon { width: 16; height: 16; path: Icons.camera; color: "#4ADE80"; anchors.verticalCenter: parent.verticalCenter }
                            Icon { width: 16; height: 16; path: Icons.bolt; color: "#F59E0B"; anchors.verticalCenter: parent.verticalCenter }
                            Icon { width: 16; height: 16; path: Icons.shelf; color: "#60A5FA"; anchors.verticalCenter: parent.verticalCenter }
                            Icon { width: 16; height: 16; path: Icons.clock; color: "#A78BFA"; anchors.verticalCenter: parent.verticalCenter }
                            Icon { width: 16; height: 16; path: Icons.shield; color: "#34D399"; anchors.verticalCenter: parent.verticalCenter }
                            Icon { width: 16; height: 16; path: Icons.download; color: "#4ADE80"; anchors.verticalCenter: parent.verticalCenter }
                            Icon { width: 16; height: 16; path: Icons.clipboard; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                            Icon { width: 16; height: 16; path: Icons.more; color: Qt.rgba(1, 1, 1, 0.60); anchors.verticalCenter: parent.verticalCenter }
                            Icon { width: 16; height: 16; path: Icons.edit; color: Qt.rgba(1, 1, 1, 0.60); anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }

            // ================================================================
            // SECTION 5: Scopa Storage & Dev Cache Recovery
            // ================================================================
            Card {
                width: parent.width
                padding: 18
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "storage"

                Column {
                    width: parent.width
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(0.2, 0.6, 1.0, 0.14)
                            border.width: 1; border.color: Qt.rgba(0.2, 0.6, 1.0, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.trash; color: "#38BDF8" }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: qsTr("Scopa Storage Management")
                                role: "title"
                                weight: 600
                            }

                            Txt {
                                text: qsTr("Reclaim disk space by safely moving Xcode DerivedData, Cargo, and Gradle caches to macOS Trash.")
                                role: "bodySmall"
                                muted: true
                                wrapMode: Text.WordWrap
                            }
                        }

                        Button {
                            text: qsTr("Clean to Trash")
                            variant: "tonal"
                            size: "sm"
                            onClicked: {
                                dynamoPage.cleanStatus = DynamoController.cleanDevCachesToTrash()
                                dynamoPage.updateStorage()
                            }
                        }
                    }

                    // Storage Metrics Readout
                    Rectangle {
                        width: parent.width
                        height: 38
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 0.75
                        border.color: Qt.rgba(1, 1, 1, 0.10)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12

                            Icon { width: 14; height: 14; path: Icons.trash; color: "#38BDF8" }
                            Txt {
                                text: dynamoPage.cleanStatus.length > 0
                                    ? dynamoPage.cleanStatus
                                    : dynamoPage.formattedStorage
                                role: "caption"
                                color: Qt.rgba(1, 1, 1, 0.85)
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Txt {
                        text: qsTr("All cleanup operations strictly use macOS ~/.Trash and never permanently delete files.")
                        role: "caption"
                        muted: true
                    }
                }
            }

            // ================================================================
            // SECTION 6: Notch HUD & Scroll Gestures
            // ================================================================
            Card {
                width: parent.width
                padding: 18
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "gestures"

                Column {
                    width: parent.width
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                            border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.dialpad; color: Theme.primary }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: qsTr("HUD & Notch Scroll Gestures")
                                role: "title"
                                weight: 600
                            }

                            Txt {
                                text: qsTr("Control system brightness on the left edge of the notch and volume on the right edge.")
                                role: "bodySmall"
                                muted: true
                            }
                        }
                    }

                    Divider { width: parent.width }

                    ListRow {
                        width: parent.width
                        iconPath: Icons.dialpad
                        title: qsTr("Notch Scroll Gestures")
                        description: qsTr("Scroll up/down over the camera notch to adjust brightness and volume.")
                        Toggle {
                            checked: Preferences.notchScrollGestures
                            onToggled: (val) => Preferences.notchScrollGestures = val
                        }
                    }

                    Divider { width: parent.width }

                    ListRow {
                        width: parent.width
                        iconPath: Icons.sparkle
                        title: qsTr("System HUD Sneak-Peek")
                        description: qsTr("Display live slider percentage feedback directly inside the top notch pill.")
                        Toggle {
                            checked: Preferences.notchHudEnabled
                            onToggled: (val) => Preferences.notchHudEnabled = val
                        }
                    }

                    Divider { width: parent.width }

                    // Test Adjustments
                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Txt {
                            text: qsTr("Test Audio & Display:")
                            role: "bodySmall"
                            weight: 500
                            Layout.fillWidth: true
                        }

                        Button {
                            text: qsTr("Volume -10%")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.setVolume(50)
                        }

                        Button {
                            text: qsTr("Volume +10%")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.setVolume(80)
                        }

                        Button {
                            text: qsTr("Brightness 75%")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.setBrightness(75)
                        }
                    }
                }
            }

            // ================================================================
            // CARD 7: ADVANCED NOTCH CALIBRATION & DEBUG OVERLAY
            // ================================================================
            Card {
                width: parent.width
                visible: dynamoPage.selectedCategory === "all" || dynamoPage.selectedCategory === "system"

                Column {
                    width: parent.width
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(0.0, 0.9, 1.0, 0.14)
                            border.width: 1; border.color: Qt.rgba(0.0, 0.9, 1.0, 0.25)
                            Icon { anchors.centerIn: parent; width: 18; height: 18; path: Icons.compass; color: "#00E5FF" }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Txt {
                                text: qsTr("Advanced Notch Calibration & Diagnostics")
                                role: "titleSmall"
                                weight: 600
                            }

                            Txt {
                                text: qsTr("Real-time AppKit geometry inspection, debug outline overlay, and calibration nudges.")
                                role: "caption"
                                color: Theme.surfaceContentVariant
                            }
                        }
                    }

                    Divider { width: parent.width }

                    // Debug Overlay Toggle
                    ListRow {
                        width: parent.width
                        iconPath: Icons.compass
                        title: qsTr("Show Geometry Debug Overlay")
                        description: qsTr("Draw colorful bounding boxes for notchRect, auxiliary safe zones, center crosshair, and telemetry badge.")
                        Toggle {
                            checked: Preferences.notchDebugOverlay
                            onToggled: (val) => Preferences.notchDebugOverlay = val
                        }
                    }

                    Divider { width: parent.width }

                    // Geometry Raw Inspection Readout
                    Rectangle {
                        width: parent.width
                        height: 56
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.width: 0.75
                        border.color: Qt.rgba(1, 1, 1, 0.08)

                        Column {
                            anchors.centerIn: parent
                            spacing: 3

                            Txt {
                                text: `AppKit Detection: ${dynamoPage.hasNotch ? "Physical Camera Notch" : "Virtual Top Pill"}  |  Measured Box: ${dynamoPage.notchWidth.toFixed(1)} × ${dynamoPage.notchHeight.toFixed(1)} pt`
                                role: "caption"
                                size: 10
                                weight: 600
                                color: "#00E5FF"
                            }

                            Txt {
                                text: `Active Overrides: Width Δ=${Preferences.notchOverrideWidth.toFixed(1)} pt  |  Height Δ=${Preferences.notchOverrideHeight.toFixed(1)} pt  |  Radius Δ=${Preferences.notchOverrideRadius.toFixed(1)} pt`
                                role: "caption"
                                size: 9
                                color: Theme.surfaceContentVariant
                            }
                        }
                    }

                    Divider { width: parent.width }

                    // Calibration Nudge Controls
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Txt {
                            text: qsTr("Width Nudge:")
                            role: "caption"
                            weight: 500
                        }

                        Button {
                            text: "-2 pt"
                            size: "sm"
                            variant: "tonal"
                            onClicked: Preferences.notchOverrideWidth -= 2.0
                        }

                        Button {
                            text: "+2 pt"
                            size: "sm"
                            variant: "tonal"
                            onClicked: Preferences.notchOverrideWidth += 2.0
                        }

                        Item { Layout.fillWidth: true }

                        Txt {
                            text: qsTr("Height Nudge:")
                            role: "caption"
                            weight: 500
                        }

                        Button {
                            text: "-1 pt"
                            size: "sm"
                            variant: "tonal"
                            onClicked: Preferences.notchOverrideHeight -= 1.0
                        }

                        Button {
                            text: "+1 pt"
                            size: "sm"
                            variant: "tonal"
                            onClicked: Preferences.notchOverrideHeight += 1.0
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: qsTr("Reset Nudges")
                            size: "sm"
                            variant: "fill"
                            onClicked: {
                                Preferences.notchOverrideWidth = 0.0
                                Preferences.notchOverrideHeight = 0.0
                                Preferences.notchOverrideRadius = 0.0
                            }
                        }
                    }
                }
            }

            // Bottom Spacing
            Item { width: 1; height: 16 }
        }
    }
}
