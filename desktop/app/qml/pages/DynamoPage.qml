// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import app.maclink

// Dynamo section: controls the embedded or system LiquidDynamo notch helper application.
Item {
    id: dynamoPage
    property bool active: true

    Component.onCompleted: {
        DynamoController.refresh()
    }

    Timer {
        interval: 2000
        running: dynamoPage.active
        repeat: true
        onTriggered: DynamoController.refresh()
    }

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

            // Header
            Column {
                width: parent.width
                spacing: 4

                Txt {
                    text: qsTr("LiquidDynamo Control")
                    role: "headline"
                    size: 22
                }

                Txt {
                    text: qsTr("Dynamic Island notch companion, live telemetry wings, and HUD gestures.")
                    role: "body"
                    muted: true
                }
            }

            // Case 1: NOT INSTALLED
            Card {
                visible: !DynamoController.isInstalled
                width: parent.width
                padding: 20

                Column {
                    width: parent.width
                    spacing: 12

                    Row {
                        spacing: 10
                        anchors.left: parent.left
                        StatusDot {
                            anchors.verticalCenter: parent.verticalCenter
                            online: false
                        }
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("LiquidDynamo is not installed")
                            role: "title"
                            weight: 600
                        }
                    }

                    Txt {
                        width: parent.width
                        text: qsTr("LiquidDynamo.app was not found in MacLink.app/Contents/Helpers/ or /Applications. Install LiquidDynamo in your Applications folder or package it with MacLink using DYNAMO_APP to enable the Dynamic Island notch.")
                        role: "body"
                        muted: true
                        wrapMode: Text.WordWrap
                    }

                    Button {
                        text: qsTr("Check Again")
                        variant: "tonal"
                        size: "sm"
                        onClicked: DynamoController.refresh()
                    }
                }
            }

            // Overlap Warning (if MacLink's own Island is active)
            Card {
                visible: DynamoController.isInstalled && Preferences.maclinkIsland
                width: parent.width
                padding: 16
                color: Theme.glass ? Qt.rgba(0.95, 0.55, 0.1, 0.12) : Qt.rgba(0.95, 0.55, 0.1, 0.16)
                border.color: Qt.rgba(0.95, 0.55, 0.1, 0.35)

                RowLayout {
                    width: parent.width
                    spacing: 14

                    Icon {
                        source: Icons.island
                        size: 24
                        color: Theme.accentAmber || Theme.primary
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 2

                        Txt {
                            text: qsTr("MacLink Island is currently enabled")
                            role: "title"
                            weight: 600
                        }

                        Txt {
                            text: qsTr("Both MacLink Island and LiquidDynamo place an overlay at the top of your screen. Turn off MacLink Island to avoid overlap.")
                            role: "bodySmall"
                            muted: true
                            wrapMode: Text.WordWrap
                        }
                    }

                    Button {
                        text: qsTr("Turn Off MacLink Island")
                        variant: "tonal"
                        size: "sm"
                        onClicked: Preferences.maclinkIsland = false
                    }
                }
            }

            // Case 2: INSTALLED / RUNNING
            // Status Card
            Card {
                visible: DynamoController.isInstalled
                width: parent.width
                padding: 20

                Column {
                    width: parent.width
                    spacing: 16

                    RowLayout {
                        width: parent.width

                        Row {
                            spacing: 10
                            Layout.fillWidth: true
                            anchors.verticalCenter: parent.verticalCenter

                            StatusDot {
                                anchors.verticalCenter: parent.verticalCenter
                                online: DynamoController.isRunning
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Txt {
                                    text: DynamoController.isRunning ? qsTr("LiquidDynamo is running") : qsTr("LiquidDynamo is stopped")
                                    role: "title"
                                    weight: 600
                                }

                                Txt {
                                    text: DynamoController.installedPath.length > 0 ? DynamoController.installedPath : qsTr("Installed")
                                    role: "caption"
                                    muted: true
                                    elide: Text.ElideMiddle
                                    width: Math.min(360, contentColumn.width - 160)
                                }
                            }
                        }

                        Button {
                            text: DynamoController.isRunning ? qsTr("Stop Dynamo") : qsTr("Start Dynamo")
                            variant: DynamoController.isRunning ? "outline" : "fill"
                            onClicked: {
                                if (DynamoController.isRunning) {
                                    DynamoController.stop()
                                } else {
                                    DynamoController.launch()
                                }
                            }
                        }
                    }

                    Divider { width: parent.width }

                    // Quick Actions
                    Row {
                        spacing: 10
                        enabled: DynamoController.isRunning
                        opacity: DynamoController.isRunning ? 1.0 : 0.45

                        Button {
                            text: qsTr("Open Dynamo Settings")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.openSettings()
                        }

                        Button {
                            text: qsTr("Expand Island")
                            variant: "tonal"
                            size: "sm"
                            onClicked: DynamoController.expand()
                        }
                    }
                }
            }

            // Autostart Settings Card
            Card {
                visible: DynamoController.isInstalled
                width: parent.width
                padding: 16

                RowLayout {
                    width: parent.width

                    Column {
                        Layout.fillWidth: true
                        spacing: 2

                        Txt {
                            text: qsTr("Start Dynamo with MacLink")
                            role: "title"
                            weight: 600
                        }

                        Txt {
                            text: qsTr("Automatically launches LiquidDynamo in the background when MacLink starts.")
                            role: "bodySmall"
                            muted: true
                        }
                    }

                    Toggle {
                        checked: DynamoController.autostart
                        onToggled: (val) => DynamoController.autostart = val
                    }
                }
            }
        }
    }
}
