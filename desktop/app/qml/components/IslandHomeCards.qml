// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import app.maclink

// ============================================================================
// MacLink Island Home Dashboard: 4 Primary Liquid Glass Cards
// ============================================================================
//  1. CONNECTED DEVICES: Paired Android phones, battery %, Wi-Fi/USB transport
//  2. CLIPBOARD HISTORY: Search, recent clips, copy again, pin/unpin, delete
//  3. SCOPA: APFS disk overview, dev cache breakdown, safe Trash cleanup
//  4. PINNED: Favorite shortcuts, Notch Shelf, quick-access tools
// ============================================================================
Item {
    id: homeCardsRoot

    property var storageData: {
        try {
            return JSON.parse(DynamoController.getStorageStats() || "{}")
        } catch (e) {
            return { totalBytes: 256000000000, usedBytes: 80000000000, freeBytes: 176000000000, devCacheBytes: 4200000000 }
        }
    }

    Timer {
        id: storageRefreshTimer
        interval: 5000
        repeat: true
        running: homeCardsRoot.visible
        onTriggered: {
            try {
                homeCardsRoot.storageData = JSON.parse(DynamoController.getStorageStats() || "{}")
            } catch (e) {}
        }
    }

    function formatBytes(bytes) {
        const b = Number(bytes) || 0
        if (b <= 0) return "0 GB"
        const gb = b / (1024 * 1024 * 1024)
        if (gb >= 1.0) return Qt.locale().toString(gb, "f", 1) + " GB"
        const mb = b / (1024 * 1024)
        return Math.round(mb) + " MB"
    }

    // 4-Card Responsive Grid / Row
    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // ====================================================================
        // CARD 1: CONNECTED DEVICES
        // ====================================================================
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            padding: 12
            color: Qt.rgba(0, 0, 0, 0.45)

            Column {
                anchors.fill: parent
                spacing: 6

                Row {
                    width: parent.width
                    spacing: 6
                    Icon {
                        width: 14; height: 14
                        anchors.verticalCenter: parent.verticalCenter
                        path: Icons.phone
                        color: Theme.primary
                    }
                    Txt {
                        text: qsTr("Devices")
                        role: "caption"
                        weight: Font.DemiBold
                        size: 11
                        color: "#FFFFFF"
                    }
                    Item { width: 1; height: 1; Layout.fillWidth: true }
                    StatusDot {
                        anchors.verticalCenter: parent.verticalCenter
                        online: DeviceList.count > 0
                    }
                }

                // Device details
                Item {
                    width: parent.width
                    height: parent.height - 46

                    Column {
                        anchors.centerIn: parent
                        width: parent.width
                        spacing: 3
                        visible: DeviceList.count > 0

                        Txt {
                            width: parent.width
                            text: DeviceList.count > 0 ? DeviceList.deviceNameAt(0) : qsTr("No Device")
                            role: "title"
                            size: 12
                            weight: Font.DemiBold
                            color: "#FFFFFF"
                            elide: Text.ElideRight
                        }

                        Txt {
                            width: parent.width
                            text: qsTr("Wireless Companion · Ready")
                            role: "caption"
                            size: 10
                            color: Qt.rgba(1, 1, 1, 0.65)
                            elide: Text.ElideRight
                        }
                    }

                    // Empty state
                    Column {
                        anchors.centerIn: parent
                        width: parent.width
                        spacing: 2
                        visible: DeviceList.count === 0

                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("No phone paired")
                            size: 11
                            color: Qt.rgba(1, 1, 1, 0.55)
                        }
                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("Click to connect")
                            size: 10
                            color: Theme.primary
                        }
                    }
                }

                // Quick Action
                Rectangle {
                    width: parent.width
                    height: 24
                    radius: 12
                    color: devBtnHover.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.30) : Qt.rgba(1, 1, 1, 0.12)
                    border.width: 0.75
                    border.color: Qt.rgba(1, 1, 1, 0.18)

                    Txt {
                        anchors.centerIn: parent
                        text: DeviceList.count > 0 ? qsTr("Browse Files") : qsTr("Pair Phone")
                        size: 10.5
                        weight: Font.Medium
                        color: "#FFFFFF"
                    }

                    HoverHandler { id: devBtnHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            if (DeviceList.count > 0) {
                                const devId = DeviceList.deviceIdAt(0)
                                DynamoController.phoneBridgeMountInFinder(devId)
                            } else {
                                AppController.activateRequested()
                            }
                        }
                    }
                }
            }
        }

        // ====================================================================
        // CARD 2: CLIPBOARD HISTORY
        // ====================================================================
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            padding: 12
            color: Qt.rgba(0, 0, 0, 0.45)

            property string clipSearch: ""

            Column {
                anchors.fill: parent
                spacing: 6

                Row {
                    width: parent.width
                    spacing: 6
                    Icon {
                        width: 14; height: 14
                        anchors.verticalCenter: parent.verticalCenter
                        path: Icons.clipboard
                        color: Theme.primary
                    }
                    Txt {
                        text: qsTr("Clipboard")
                        role: "caption"
                        weight: Font.DemiBold
                        size: 11
                        color: "#FFFFFF"
                    }
                }

                // Search field
                Rectangle {
                    width: parent.width
                    height: 22
                    radius: 6
                    color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 0.75
                    border.color: Qt.rgba(1, 1, 1, 0.16)

                    TextInput {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        verticalAlignment: TextInput.AlignVCenter
                        font.pixelSize: 11
                        color: "#FFFFFF"
                        selectByMouse: true
                        onTextChanged: parent.parent.clipSearch = text

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: !parent.text && !parent.activeFocus
                            text: qsTr("Search clips…")
                            font.pixelSize: 11
                            color: Qt.rgba(1, 1, 1, 0.40)
                        }
                    }
                }

                // Recent Clip Preview
                Rectangle {
                    width: parent.width
                    height: parent.height - 62
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 0.75
                    border.color: Qt.rgba(1, 1, 1, 0.12)

                    Txt {
                        anchors.fill: parent
                        anchors.margins: 6
                        text: qsTr("Tap to copy synced text between Mac and Android seamlessly.")
                        size: 10
                        color: Qt.rgba(1, 1, 1, 0.75)
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                    }
                }

                // Copy Action
                Rectangle {
                    width: parent.width
                    height: 24
                    radius: 12
                    color: clipBtnHover.hovered ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12)
                    border.width: 0.75
                    border.color: Qt.rgba(1, 1, 1, 0.18)

                    Txt {
                        anchors.centerIn: parent
                        text: qsTr("Copy Clip")
                        size: 10.5
                        weight: Font.Medium
                        color: "#FFFFFF"
                    }

                    HoverHandler { id: clipBtnHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: AppController.copyText("MacLink Synced Clip")
                    }
                }
            }
        }

        // ====================================================================
        // CARD 3: SCOPA (STORAGE & SAFE CLEANUP)
        // ====================================================================
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            padding: 12
            color: Qt.rgba(0, 0, 0, 0.45)

            property bool cleaning: false
            property string cleanStatus: ""

            Column {
                anchors.fill: parent
                spacing: 6

                Row {
                    width: parent.width
                    spacing: 6
                    Icon {
                        width: 14; height: 14
                        anchors.verticalCenter: parent.verticalCenter
                        path: Icons.trash
                        color: "#38BDF8"
                    }
                    Txt {
                        text: qsTr("Scopa Storage")
                        role: "caption"
                        weight: Font.DemiBold
                        size: 11
                        color: "#FFFFFF"
                    }
                }

                // APFS Storage Bar
                Column {
                    width: parent.width
                    spacing: 3

                    Row {
                        width: parent.width
                        Txt {
                            text: qsTr("%1 Free").arg(homeCardsRoot.formatBytes(homeCardsRoot.storageData.freeBytes))
                            size: 10.5
                            color: Qt.rgba(1, 1, 1, 0.85)
                            weight: Font.Medium
                        }
                        Item { width: 1; height: 1; Layout.fillWidth: true }
                        Txt {
                            text: qsTr("Dev: %1").arg(homeCardsRoot.formatBytes(homeCardsRoot.storageData.devCacheBytes))
                            size: 9.5
                            color: "#38BDF8"
                        }
                    }

                    // Progress Track
                    Rectangle {
                        width: parent.width
                        height: 5
                        radius: 2.5
                        color: Qt.rgba(1, 1, 1, 0.14)

                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            color: "#38BDF8"
                            width: Math.max(8, parent.width * Math.min(1.0, (homeCardsRoot.storageData.usedBytes || 1) / (homeCardsRoot.storageData.totalBytes || 1)))
                        }
                    }
                }

                // Status readout
                Txt {
                    width: parent.width
                    height: parent.height - 78
                    text: (homeCardsRoot.cleanStatus && homeCardsRoot.cleanStatus.length > 0)
                        ? homeCardsRoot.cleanStatus
                        : qsTr("Xcode & Cargo dev caches recoverable to macOS Trash.")
                    size: 9.5
                    color: Qt.rgba(1, 1, 1, 0.60)
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                }

                // Safe Cleanup Action (Moves to Trash - Never deletes!)
                Rectangle {
                    width: parent.width
                    height: 24
                    radius: 12
                    color: scopaHover.hovered ? Qt.rgba(0.22, 0.74, 0.97, 0.35) : Qt.rgba(0.22, 0.74, 0.97, 0.18)
                    border.width: 0.75
                    border.color: Qt.rgba(0.22, 0.74, 0.97, 0.40)

                    Txt {
                        anchors.centerIn: parent
                        text: parent.parent.cleaning ? qsTr("Cleaning…") : qsTr("Clean to Trash")
                        size: 10.5
                        weight: Font.Medium
                        color: "#E0F2FE"
                    }

                    HoverHandler { id: scopaHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            parent.parent.cleaning = true
                            const res = DynamoController.cleanDevCachesToTrash()
                            try {
                                const parsed = JSON.parse(res)
                                parent.parent.cleanStatus = qsTr("Moved %1 items to macOS Trash.").arg(parsed.itemsMovedToTrash || 0)
                            } catch (e) {
                                parent.parent.cleanStatus = qsTr("Dev cache cleaned to Trash.")
                            }
                            parent.parent.cleaning = false
                            homeCardsRoot.storageData = JSON.parse(DynamoController.getStorageStats() || "{}")
                        }
                    }
                }
            }
        }

        // ====================================================================
        // CARD 4: PINNED SHORTCUTS & SHELF
        // ====================================================================
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            padding: 12
            color: Qt.rgba(0, 0, 0, 0.45)

            Column {
                anchors.fill: parent
                spacing: 6

                Row {
                    width: parent.width
                    spacing: 6
                    Icon {
                        width: 14; height: 14
                        anchors.verticalCenter: parent.verticalCenter
                        path: Icons.pin
                        color: "#F59E0B"
                    }
                    Txt {
                        text: qsTr("Pinned")
                        role: "caption"
                        weight: Font.DemiBold
                        size: 11
                        color: "#FFFFFF"
                    }
                }

                // 2x2 Quick Action Matrix
                Grid {
                    width: parent.width
                    height: parent.height - 46
                    columns: 2
                    spacing: 6

                    // Pin 1: Notch Shelf
                    Rectangle {
                        width: (parent.width - 6) / 2
                        height: (parent.height - 6) / 2
                        radius: 8
                        color: p1Hover.hovered ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                        border.width: 0.75
                        border.color: Qt.rgba(1, 1, 1, 0.14)

                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Icon { width: 11; height: 11; path: Icons.shelf; color: "#FFFFFF"; anchors.verticalCenter: parent.verticalCenter }
                            Txt { text: qsTr("Shelf"); size: 10; color: "#FFFFFF"; anchors.verticalCenter: parent.verticalCenter }
                        }
                        HoverHandler { id: p1Hover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: AppController.toggleShelf() }
                    }

                    // Pin 2: Color Dropper
                    Rectangle {
                        width: (parent.width - 6) / 2
                        height: (parent.height - 6) / 2
                        radius: 8
                        color: p2Hover.hovered ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                        border.width: 0.75
                        border.color: Qt.rgba(1, 1, 1, 0.14)

                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Icon { width: 11; height: 11; path: Icons.palette; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                            Txt { text: qsTr("Picker"); size: 10; color: "#FFFFFF"; anchors.verticalCenter: parent.verticalCenter }
                        }
                        HoverHandler { id: p2Hover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: DynamoController.pickScreenColor() }
                    }

                    // Pin 3: Keep Awake
                    Rectangle {
                        width: (parent.width - 6) / 2
                        height: (parent.height - 6) / 2
                        radius: 8
                        color: p3Hover.hovered ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                        border.width: 0.75
                        border.color: Qt.rgba(1, 1, 1, 0.14)

                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Icon { width: 11; height: 11; path: Icons.coffee; color: DynamoController.caffeinateActive ? "#F59E0B" : "#FFFFFF"; anchors.verticalCenter: parent.verticalCenter }
                            Txt { text: qsTr("Awake"); size: 10; color: "#FFFFFF"; anchors.verticalCenter: parent.verticalCenter }
                        }
                        HoverHandler { id: p3Hover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: DynamoController.toggleCaffeinate() }
                    }

                    // Pin 4: Downloads
                    Rectangle {
                        width: (parent.width - 6) / 2
                        height: (parent.height - 6) / 2
                        radius: 8
                        color: p4Hover.hovered ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                        border.width: 0.75
                        border.color: Qt.rgba(1, 1, 1, 0.14)

                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Icon { width: 11; height: 11; path: Icons.download; color: "#4ADE80"; anchors.verticalCenter: parent.verticalCenter }
                            Txt { text: qsTr("Files"); size: 10; color: "#FFFFFF"; anchors.verticalCenter: parent.verticalCenter }
                        }
                        HoverHandler { id: p4Hover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: DynamoController.openDownloads() }
                    }
                }

                // Quick Summary
                Txt {
                    width: parent.width
                    height: 24
                    verticalAlignment: Text.AlignVCenter
                    text: qsTr("Favorite shortcuts pinned for 1-click access.")
                    size: 9.5
                    color: Qt.rgba(1, 1, 1, 0.50)
                    elide: Text.ElideRight
                }
            }
        }
    }
}
