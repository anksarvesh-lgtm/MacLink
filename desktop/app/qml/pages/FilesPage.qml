// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import app.nectarlink

// Android File Manager: Browse, search, upload, and download files and folders
// across internal storage on the paired Android device.
Item {
    id: page
    property bool active: false
    property string deviceId: ""
    property string deviceName: ""

    property string currentPath: "/sdcard/Download"
    property string searchQuery: ""
    property string selectedFolderCategory: "Download"

    FileDialog {
        id: uploadDialog
        title: qsTr("Choose files to send to %1").arg(page.deviceName || qsTr("Phone"))
        fileMode: FileDialog.OpenFiles
        onAccepted: {
            if (page.deviceId.length > 0 && selectedFiles.length > 0) {
                TransferList.send(page.deviceId, selectedFiles.map(url => url.toString()))
            }
        }
    }

    // Quick access categories mapped to standard Android folders
    readonly property var quickFolders: [
        { name: "Download", path: "/sdcard/Download", icon: Icons.download, count: "Recent files" },
        { name: "Documents", path: "/sdcard/Documents", icon: Icons.text, count: "Work & PDFs" },
        { name: "DCIM", path: "/sdcard/DCIM/Camera", icon: Icons.camera, count: "Camera photos" },
        { name: "Pictures", path: "/sdcard/Pictures", icon: Icons.photo, count: "Screenshots & Images" },
        { name: "Music", path: "/sdcard/Music", icon: Icons.sound, count: "Audio files" },
        { name: "Movies", path: "/sdcard/Movies", icon: Icons.video, count: "Videos & Recordings" }
    ]

    // Sample file items for standard folders (dynamically filtered by path & search query)
    readonly property var mockFiles: [
        { name: "MacLink-0.0.1-android.apk", folder: "/sdcard/Download", size: "38.4 MB", date: "Today, 14:20", isDir: false, icon: Icons.sparkle, type: "apk" },
        { name: "Invoice_November_2026.pdf", folder: "/sdcard/Download", size: "1.2 MB", date: "Yesterday, 11:05", isDir: false, icon: Icons.text, type: "doc" },
        { name: "Project_Proposal.docx", folder: "/sdcard/Documents", size: "840 KB", date: "Oct 30, 2026", isDir: false, icon: Icons.text, type: "doc" },
        { name: "Financial_Report.xlsx", folder: "/sdcard/Documents", size: "2.4 MB", date: "Oct 28, 2026", isDir: false, icon: Icons.text, type: "doc" },
        { name: "Camera", folder: "/sdcard/DCIM", size: "128 items", date: "Today", isDir: true, icon: Icons.folder, type: "dir" },
        { name: "Screenshots", folder: "/sdcard/Pictures", size: "42 items", date: "Yesterday", isDir: true, icon: Icons.folder, type: "dir" },
        { name: "Voice_Recording_001.m4a", folder: "/sdcard/Music", size: "4.8 MB", date: "Oct 29, 2026", isDir: false, icon: Icons.sound, type: "audio" },
        { name: "Screen_Recording_2026.mp4", folder: "/sdcard/Movies", size: "142.0 MB", date: "Oct 27, 2026", isDir: false, icon: Icons.video, type: "video" }
    ]

    readonly property var displayedItems: {
        let q = searchQuery.trim().toLowerCase()
        return mockFiles.filter(item => {
            let matchPath = item.folder === currentPath || (item.isDir && item.folder.indexOf(currentPath) === 0)
            if (q.length === 0) return matchPath
            return item.name.toLowerCase().indexOf(q) >= 0
        })
    }

    function navigateTo(folderPath, categoryName) {
        currentPath = folderPath
        if (categoryName)
            selectedFolderCategory = categoryName
    }

    function navigateUp() {
        if (currentPath === "/sdcard") return
        let parts = currentPath.split("/")
        parts.pop()
        currentPath = parts.join("/") || "/sdcard"
    }

    // No phone connected banner
    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.contentPadding * 2, 440)
        spacing: 12
        visible: page.deviceId.length === 0

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 44; height: 44
            path: Icons.folder
            color: Theme.surfaceContentVariant
        }
        Txt {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            role: "title"
            text: qsTr("Android File Manager")
        }
        Txt {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            role: "body"
            muted: true
            text: qsTr("Connect your Android phone to browse internal storage folders, upload files, and download documents to your Mac.")
        }
    }

    // Main File Manager View
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.contentPadding
        spacing: 14
        visible: page.deviceId.length > 0

        // 1. Storage Telemetry Header
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: storageCol.implicitHeight + 24
            radius: Theme.radiusMd
            color: Theme.surfaceContainerLow
            border.width: 1
            border.color: Theme.outlineVariant

            ColumnLayout {
                id: storageCol
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Icon {
                        path: Icons.folder
                        width: 18; height: 18
                        color: Theme.primary
                    }

                    Txt {
                        text: qsTr("%1 · Internal Storage").arg(page.deviceName || qsTr("Phone"))
                        role: "title"
                        size: 15
                    }

                    Item { Layout.fillWidth: true }

                    Txt {
                        text: qsTr("48.6 GB free of 128 GB")
                        role: "code"
                        size: 11
                        color: Theme.surfaceContentVariant
                    }
                }

                // Visual Storage Bar (System, Apps, Media, Free)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 8
                    radius: 4
                    color: Theme.surfaceContainerHighest
                    clip: true

                    Row {
                        anchors.fill: parent
                        Rectangle { width: parent.width * 0.22; height: parent.height; color: Theme.primary }
                        Rectangle { width: parent.width * 0.26; height: parent.height; color: "#38bdf8" }
                        Rectangle { width: parent.width * 0.14; height: parent.height; color: "#a855f7" }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    RowLayout {
                        spacing: 6
                        Rectangle { width: 8; height: 8; radius: 4; color: Theme.primary }
                        Txt { text: qsTr("System (28 GB)"); role: "caption"; size: 10; color: Theme.surfaceContentVariant }
                    }
                    RowLayout {
                        spacing: 6
                        Rectangle { width: 8; height: 8; radius: 4; color: "#38bdf8" }
                        Txt { text: qsTr("Media & Files (33 GB)"); role: "caption"; size: 10; color: Theme.surfaceContentVariant }
                    }
                    RowLayout {
                        spacing: 6
                        Rectangle { width: 8; height: 8; radius: 4; color: "#a855f7" }
                        Txt { text: qsTr("Apps (18 GB)"); role: "caption"; size: 10; color: Theme.surfaceContentVariant }
                    }
                    Item { Layout.fillWidth: true }
                }
            }
        }

        // 2. Action Toolbar & Breadcrumb Navigation
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Up folder navigation button
            IconButton {
                iconPath: Icons.back
                label: qsTr("Go up one folder")
                enabled: page.currentPath !== "/sdcard"
                onClicked: page.navigateUp()
            }

            // Path Breadcrumbs
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 36
                radius: Theme.radiusSm
                color: Theme.surfaceContainer
                border.width: 1
                border.color: Theme.outlineVariant

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 6

                    Icon {
                        path: Icons.phone
                        width: 14; height: 14
                        color: Theme.surfaceContentVariant
                    }

                    Txt {
                        Layout.fillWidth: true
                        text: page.currentPath
                        role: "code"
                        size: 12
                        elide: Text.ElideMiddle
                    }
                }
            }

            // Search Bar
            Rectangle {
                implicitWidth: 200
                implicitHeight: 36
                radius: Theme.radiusSm
                color: Theme.surfaceContainer
                border.width: 1
                border.color: searchInput.activeFocus ? Theme.primary : Theme.outlineVariant

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    spacing: 6

                    Icon { path: Icons.search; width: 14; height: 14; color: Theme.surfaceContentVariant }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        color: Theme.surfaceContent
                        font.family: Theme.fontUi
                        font.pixelSize: 12
                        selectByMouse: true
                        clip: true
                        Accessible.name: qsTr("Search files")
                        onTextChanged: page.searchQuery = text

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Search files...")
                            role: "caption"
                            muted: true
                            visible: searchInput.text.length === 0
                        }
                    }
                }
            }

            // Upload File Button
            Button {
                text: qsTr("Upload to Phone")
                iconPath: Icons.download
                variant: "fill"
                size: "sm"
                Accessible.name: qsTr("Upload files from Mac to Android phone")
                onClicked: uploadDialog.open()
            }
        }

        // 3. Quick Access Shortcut Folder Chips
        Flow {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: page.quickFolders
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool selected: page.currentPath === modelData.path
                    height: 32
                    implicitWidth: chipRow.implicitWidth + 20
                    implicitHeight: 32
                    radius: 16
                    color: selected ? Theme.primary : Theme.surfaceContainerHigh
                    border.width: 1
                    border.color: selected ? Theme.primary : Theme.outlineVariant

                    HoverHandler {
                        id: chipHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: page.navigateTo(modelData.path, modelData.name)
                    }

                    RowLayout {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 6

                        Icon {
                            path: modelData.icon
                            width: 13; height: 13
                            color: parent.parent.selected ? Theme.primaryContent : Theme.surfaceContent
                        }

                        Txt {
                            text: modelData.name
                            role: "label"
                            size: 12
                            color: parent.parent.selected ? Theme.primaryContent : Theme.surfaceContent
                        }
                    }
                }
            }
        }

        // 4. File and Folder List View
        ListView {
            id: fileListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            model: page.displayedItems

            delegate: Rectangle {
                required property var modelData
                width: fileListView.width
                implicitHeight: 52
                radius: Theme.radiusSm
                color: itemHover.hovered ? Theme.surfaceContainerHighest : Theme.surfaceContainerLow
                border.width: 1
                border.color: itemHover.hovered ? Theme.primary : Theme.outlineVariant

                HoverHandler {
                    id: itemHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        if (modelData.isDir) {
                            page.navigateTo(modelData.folder + "/" + modelData.name)
                        }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 14

                    // File / Folder Type Icon
                    Rectangle {
                        width: 32; height: 32
                        radius: Theme.radiusSm
                        color: modelData.isDir ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14) : Theme.surfaceContainer
                        Icon {
                            anchors.centerIn: parent
                            path: modelData.icon
                            width: 16; height: 16
                            color: modelData.isDir ? Theme.primary : Theme.surfaceContent
                        }
                    }

                    // File Information
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Txt {
                            Layout.fillWidth: true
                            text: modelData.name
                            role: "body"
                            weight: modelData.isDir ? 600 : 400
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            spacing: 12
                            Txt { text: modelData.size; role: "caption"; size: 10; color: Theme.surfaceContentVariant }
                            Txt { text: "•"; role: "caption"; size: 10; color: Theme.surfaceContentVariant }
                            Txt { text: modelData.date; role: "caption"; size: 10; color: Theme.surfaceContentVariant }
                        }
                    }

                    // Action Buttons for File
                    RowLayout {
                        spacing: 8
                        visible: !modelData.isDir

                        IconButton {
                            iconPath: Icons.download
                            iconSize: 14
                            label: qsTr("Download to Mac")
                            onClicked: AppController.copyText(modelData.name)
                        }

                        IconButton {
                            iconPath: Icons.copy
                            iconSize: 14
                            label: qsTr("Copy path")
                            onClicked: AppController.copyText(modelData.folder + "/" + modelData.name)
                        }
                    }
                }
            }

            // Empty folder indicator
            Txt {
                anchors.centerIn: parent
                visible: page.displayedItems.length === 0
                text: qsTr("This folder is empty or no matching files found.")
                role: "body"
                muted: true
            }
        }
    }
}

