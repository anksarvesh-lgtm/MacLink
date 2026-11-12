// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.maclink

// ============================================================================
// MacLink Island More Overflow Popover (Liquid Glass 3-Column Grid)
// ============================================================================
Item {
    id: popoverRoot

    property var overflowTools: []
    property bool isOpen: false
    property string searchQuery: ""

    signal toolSelected(string toolId)
    signal closeRequested()

    visible: isOpen
    opacity: isOpen ? 1.0 : 0.0
    scale: isOpen ? 1.0 : 0.94
    Behavior on opacity { NumberAnimation { duration: 160 } }
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

    width: 320
    height: Math.min(300, filteredTools.length > 0 ? (Math.ceil(filteredTools.length / 3) * 64 + 68) : 100)

    // Filtered tools by search query
    readonly property var filteredTools: {
        if (!searchQuery) return overflowTools
        const q = searchQuery.toLowerCase().trim()
        let res = []
        for (let i = 0; i < overflowTools.length; i++) {
            const t = overflowTools[i]
            if (t.label.toLowerCase().indexOf(q) !== -1 || t.id.toLowerCase().indexOf(q) !== -1) {
                res.push(t)
            }
        }
        return res
    }

    // Backdrop shadow and Glass surface
    Rectangle {
        anchors.fill: parent
        radius: 16
        color: Qt.rgba(0.08, 0.08, 0.10, 0.92)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.22)

        GlassRim { radius: 16 }

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            // Header + Search Input
            Row {
                width: parent.width
                height: 26
                spacing: 8

                Rectangle {
                    width: parent.width - 28
                    height: 26
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 0.75
                    border.color: Qt.rgba(1, 1, 1, 0.16)

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 12; height: 12
                            path: Icons.search
                            color: Qt.rgba(1, 1, 1, 0.50)
                        }

                        TextInput {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 20
                            font.pixelSize: 11
                            color: "#FFFFFF"
                            selectByMouse: true
                            onTextChanged: popoverRoot.searchQuery = text

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                visible: !parent.text && !parent.activeFocus
                                text: qsTr("Filter overflow tools…")
                                font.pixelSize: 11
                                color: Qt.rgba(1, 1, 1, 0.40)
                            }
                        }
                    }
                }

                // Close Button
                Rectangle {
                    width: 24; height: 24; radius: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: closeHover.hovered ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.08)

                    Icon {
                        anchors.centerIn: parent
                        width: 10; height: 10
                        path: Icons.close
                        color: "#FFFFFF"
                    }

                    HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: popoverRoot.closeRequested() }
                }
            }

            // 3-Column Grid of Tools
            Grid {
                width: parent.width
                columns: 3
                spacing: 6

                Repeater {
                    model: popoverRoot.filteredTools
                    delegate: Rectangle {
                        required property var modelData
                        width: (parent.width - 12) / 3
                        height: 56
                        radius: 10
                        color: gridItemHover.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                        border.width: 0.75
                        border.color: gridItemHover.hovered ? Theme.primary : Qt.rgba(1, 1, 1, 0.12)

                        Column {
                            anchors.centerIn: parent
                            spacing: 3

                            Icon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 15; height: 15
                                path: modelData.icon
                                color: gridItemHover.hovered ? Theme.primary : "#FFFFFF"
                            }

                            Txt {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.parent.width - 8
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.label
                                size: 9.5
                                color: "#FFFFFF"
                                elide: Text.ElideRight
                            }
                        }

                        HoverHandler { id: gridItemHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                popoverRoot.toolSelected(modelData.id)
                                popoverRoot.closeRequested()
                            }
                        }
                    }
                }
            }
        }
    }
}
