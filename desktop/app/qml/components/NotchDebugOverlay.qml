// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Shapes
import app.maclink

// ============================================================================
// Notch & Island Geometry Calibration Debug Overlay
// ============================================================================
// Visually outlines:
//   1. Physical / Virtual notchRect (Cyan #00E5FF)
//   2. Auxiliary Safe Areas Left & Right (Emerald #10B981)
//   3. Notch Center X Axis Crosshair (Hot Pink #F43F5E)
//   4. Top Safe-Area Inset Line (Amber #F59E0B)
//   5. Live Metrics HUD Badge with raw detected values & fallback status
// ============================================================================
Item {
    id: debugOverlayRoot
    anchors.fill: parent
    visible: Preferences.notchDebugOverlay
    z: 9999
    clip: false

    readonly property var geom: {
        try {
            return JSON.parse(DynamoController.notchGeometryJson || "{}")
        } catch (e) {
            return {}
        }
    }

    readonly property bool hasNotch: geom.hasNotch !== undefined ? !!geom.hasNotch : true
    readonly property bool virtualNotch: !!geom.virtualNotch
    readonly property bool isFallback: !!geom.isFallback
    readonly property string fallbackReason: geom.fallbackReason || ""
    readonly property real notchW: geom.notchWidth || 179.0
    readonly property real notchH: geom.notchHeight || 32.0
    readonly property real notchCX: geom.notchCenterX || (parent.width / 2.0)
    readonly property real auxLeftW: geom.leftAvailable || 645.5
    readonly property real auxRightW: geom.rightAvailable || 645.5
    readonly property real cornerR: geom.bottomCornerRadius || 14.0
    readonly property real scaleFactor: geom.backingScaleFactor || 2.0

    // 1. Measured Notch Outline
    Rectangle {
        id: notchRectBox
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: debugOverlayRoot.notchW
        height: debugOverlayRoot.notchH
        color: Qt.rgba(0, 0.90, 1.0, 0.15)
        border.width: 1.5
        border.color: "#00E5FF"

        // Center line
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1.0
            color: "#F43F5E"
        }

        // Notch Dimension Label
        Rectangle {
            anchors.centerIn: parent
            width: notchLbl.implicitWidth + 8
            height: 14
            radius: 3
            color: Qt.rgba(0, 0, 0, 0.85)

            Txt {
                id: notchLbl
                anchors.centerIn: parent
                text: `${Math.round(debugOverlayRoot.notchW)}×${Math.round(debugOverlayRoot.notchH)} pt`
                role: "caption"
                size: 9
                weight: 700
                color: "#00E5FF"
            }
        }
    }

    // 2. Safe Area Inset Horizontal Guideline
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: debugOverlayRoot.notchH
        height: 1.0
        color: "#F59E0B"
        opacity: 0.85
    }

    // 3. Floating Diagnostics HUD Badge (Positioned below the notch)
    Rectangle {
        id: hudCard
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: notchRectBox.bottom
        anchors.topMargin: 8
        width: hudCol.implicitWidth + 20
        height: hudCol.implicitHeight + 16
        radius: 8
        color: Qt.rgba(10/255, 15/255, 25/255, 0.95)
        border.width: 1.0
        border.color: debugOverlayRoot.isFallback ? "#F59E0B" : Qt.rgba(0, 0.90, 1.0, 0.40)

        Column {
            id: hudCol
            anchors.centerIn: parent
            spacing: 3

            Row {
                spacing: 6
                Rectangle {
                    width: 7; height: 7; radius: 3.5
                    anchors.verticalCenter: parent.verticalCenter
                    color: debugOverlayRoot.isFallback ? "#F59E0B" : (debugOverlayRoot.hasNotch ? "#10B981" : "#38BDF8")
                }
                Txt {
                    text: debugOverlayRoot.isFallback
                        ? "NOTCH: FALLBACK ESTIMATION"
                        : (debugOverlayRoot.hasNotch ? "NOTCH: NATIVE APPKIT DETECTED" : "NOTCH: VIRTUAL TOP-CENTER PILL")
                    role: "caption"
                    size: 9
                    weight: 700
                    color: debugOverlayRoot.isFallback ? "#F59E0B" : (debugOverlayRoot.hasNotch ? "#10B981" : "#38BDF8")
                }
            }

            Txt {
                text: `Notch Box: ${debugOverlayRoot.notchW.toFixed(1)} × ${debugOverlayRoot.notchH.toFixed(1)} pt  |  Center X: ${debugOverlayRoot.notchCX.toFixed(1)} pt`
                role: "caption"
                size: 9
                color: "#E2E8F0"
            }

            Txt {
                text: `Aux Areas: Left ${debugOverlayRoot.auxLeftW.toFixed(1)} pt  |  Right ${debugOverlayRoot.auxRightW.toFixed(1)} pt`
                role: "caption"
                size: 9
                color: "#94A3B8"
            }

            Txt {
                text: `Scale: ${debugOverlayRoot.scaleFactor.toFixed(1)}x  |  Bottom Radius: ${debugOverlayRoot.cornerR.toFixed(1)} pt  |  Header Gap: ${debugOverlayRoot.notchW.toFixed(1)} pt`
                role: "caption"
                size: 9
                color: "#94A3B8"
            }

            Txt {
                visible: debugOverlayRoot.isFallback && debugOverlayRoot.fallbackReason.length > 0
                text: "Reason: " + debugOverlayRoot.fallbackReason
                role: "caption"
                size: 8
                color: "#FBBF24"
            }

            Txt {
                visible: Preferences.notchOverrideWidth !== 0 || Preferences.notchOverrideHeight !== 0 || Preferences.notchOverrideRadius !== 0
                text: `Active Nudges: Δw=${Preferences.notchOverrideWidth.toFixed(1)} pt, Δh=${Preferences.notchOverrideHeight.toFixed(1)} pt, Δr=${Preferences.notchOverrideRadius.toFixed(1)} pt`
                role: "caption"
                size: 8
                color: "#A78BFA"
            }
        }
    }
}
