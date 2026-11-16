// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.maclink

// ============================================================================
// MacLink Island Toolbar Customization Editor Sheet
// ============================================================================
Item {
    id: editSheetRoot

    property var allFeatures: []
    property var currentEnabledIds: []
    property bool isOpen: false

    signal saveRequested(var newEnabledIds)
    signal closeRequested()

    visible: isOpen
    opacity: isOpen ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 180 } }

    anchors.fill: parent

    // Scrim
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.65)
        TapHandler { onTapped: editSheetRoot.closeRequested() }
    }

    // Modal Content
    Rectangle {
        id: sheetContainer
        anchors.centerIn: parent
        width: Math.min(540, parent.width - 24)
        height: Math.min(280, parent.height - 16)
        radius: 16
        color: Qt.rgba(0.10, 0.10, 0.12, 0.95)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.22)

        GlassRim { radius: 16 }

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // Header
            Item {
                width: parent.width
                height: 26

                Row {
                    spacing: 6
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    Icon { width: 14; height: 14; path: Icons.edit; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                    Txt { text: qsTr("Customize Island Toolbar"); size: 12; weight: Font.DemiBold; color: "#FFFFFF"; anchors.verticalCenter: parent.verticalCenter }
                }

                Row {
                    spacing: 8
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    // Reset to Default
                    Rectangle {
                        width: 90; height: 24; radius: 12
                        color: resetHover.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                        border.width: 0.75; border.color: Qt.rgba(1, 1, 1, 0.16)

                        Txt { anchors.centerIn: parent; text: qsTr("Reset Default"); size: 10; color: Qt.rgba(1, 1, 1, 0.75) }
                        HoverHandler { id: resetHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                editSheetRoot.currentEnabledIds = [
                                    "dropper", "keepAwake", "phoneBridge", "music", "systemStats",
                                    "scopa", "watcher", "powerload", "shelf", "timer", "privacyGuard",
                                    "downloads", "clipboard", "volumeControl", "brightnessControl"
                                ]
                            }
                        }
                    }

                    // Done / Save
                    Rectangle {
                        width: 60; height: 24; radius: 12
                        color: Theme.primary

                        Txt { anchors.centerIn: parent; text: qsTr("Done"); size: 10.5; weight: Font.Medium; color: Theme.primaryContent }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                editSheetRoot.saveRequested(editSheetRoot.currentEnabledIds)
                                editSheetRoot.closeRequested()
                            }
                        }
                    }
                }
            }

            // Scrollable Tools List
            ListView {
                width: parent.width
                height: parent.height - 42
                clip: true
                spacing: 4
                model: editSheetRoot.allFeatures

                delegate: Rectangle {
                    id: rowItem
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 32
                    radius: 8
                    color: rowHover.hovered ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
                    border.width: 0.5
                    border.color: Qt.rgba(1, 1, 1, 0.10)

                    readonly property bool isEnabled: modelData.id === "home" || editSheetRoot.currentEnabledIds.indexOf(modelData.id) !== -1

                    HoverHandler { id: rowHover }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 13; height: 13
                            path: modelData.icon
                            color: rowItem.isEnabled ? Theme.primary : Qt.rgba(1, 1, 1, 0.40)
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 140
                            text: modelData.label + (modelData.id === "home" ? qsTr(" (Permanent)") : "")
                            size: 11
                            color: rowItem.isEnabled ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.45)
                            elide: Text.ElideRight
                        }

                        Item { width: 1; height: 1; Layout.fillWidth: true }

                        // Move Up / Move Down
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            visible: modelData.id !== "home" && rowItem.isEnabled

                            Rectangle {
                                width: 20; height: 20; radius: 10
                                color: upHover.hovered ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.08)
                                Icon { anchors.centerIn: parent; width: 9; height: 9; path: Icons.arrowUp; color: "#FFFFFF" }
                                HoverHandler { id: upHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    onTapped: {
                                        let arr = editSheetRoot.currentEnabledIds.slice()
                                        const idx = arr.indexOf(modelData.id)
                                        if (idx > 0) {
                                            const tmp = arr[idx - 1]
                                            arr[idx - 1] = arr[idx]
                                            arr[idx] = tmp
                                            editSheetRoot.currentEnabledIds = arr
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: 20; height: 20; radius: 10
                                color: downHover.hovered ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.08)
                                Icon { anchors.centerIn: parent; width: 9; height: 9; path: Icons.arrowDown; color: "#FFFFFF" }
                                HoverHandler { id: downHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    onTapped: {
                                        let arr = editSheetRoot.currentEnabledIds.slice()
                                        const idx = arr.indexOf(modelData.id)
                                        if (idx >= 0 && idx < arr.length - 1) {
                                            const tmp = arr[idx + 1]
                                            arr[idx + 1] = arr[idx]
                                            arr[idx] = tmp
                                            editSheetRoot.currentEnabledIds = arr
                                        }
                                    }
                                }
                            }
                        }

                        // Enable/Disable Toggle
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32; height: 18; radius: 9
                            color: rowItem.isEnabled ? Theme.primary : Qt.rgba(1, 1, 1, 0.20)
                            visible: modelData.id !== "home"

                            Rectangle {
                                width: 14; height: 14; radius: 7
                                anchors.verticalCenter: parent.verticalCenter
                                x: rowItem.isEnabled ? parent.width - width - 2 : 2
                                color: "#FFFFFF"
                                Behavior on x { NumberAnimation { duration: 120 } }
                            }

                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    let arr = editSheetRoot.currentEnabledIds.slice()
                                    const idx = arr.indexOf(modelData.id)
                                    if (idx !== -1) arr.splice(idx, 1)
                                    else arr.push(modelData.id)
                                    editSheetRoot.currentEnabledIds = arr
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
