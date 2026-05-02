import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Airdrop content that lives inside the dynamic island pill.
// Displayed when rootWidget.airdropOpen === true and a file is dropped.
Item {
    id: airdropContent
    property var rootWidget

    // ── State ─────────────────────────────────────────────────────────────────
    property var droppedFilePaths: []
    property string droppedFileName: ""
    property string droppedFileExt: ""
    property string lsState: "idle"  // idle | scanning | ready | sending | sent | error
    property string statusMessage: ""
    property real progressVal: 0.0

    // ── Propagate state to rootWidget for the AirdropBubble ────────────────────
    onLsStateChanged: {
        if (rootWidget) rootWidget.airdropLsState = lsState
    }
    onDroppedFileNameChanged: {
        if (rootWidget) rootWidget.airdropFileName = droppedFileName
    }
    onStatusMessageChanged: {
        if (rootWidget) rootWidget.airdropStatusMsg = statusMessage
    }

    ListModel { id: deviceModel }

    // Height adapts to content
    property int preferredHeight: {
        if (lsState === "idle") return 200;
        if (lsState === "scanning") return 220;
        var deviceRows = Math.min(4, deviceModel.count);
        if (deviceRows === 0) deviceRows = 1;
        return 100 + (deviceRows * 52);
    }

    // ── Processes ─────────────────────────────────────────────────────────────
    Process {
        id: discoverProc
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/localsend/localsend_discover.sh"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                var text = line.trim()
                if (text === "") return
                var parts = text.split('\t')
                if (parts.length >= 2) {
                    var ip = parts[1].trim()
                    if (/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(ip)) {
                        // Check for duplicates
                        for (var i = 0; i < deviceModel.count; i++) {
                            if (deviceModel.get(i).ip === ip) return
                        }
                        deviceModel.append({ alias: parts[0].trim(), ip: ip })
                    }
                }
            }
        }
        onExited: {
            if (airdropContent.lsState === "scanning") {
                airdropContent.lsState = deviceModel.count > 0 ? "ready" : "ready"
                airdropContent.statusMessage = deviceModel.count > 0
                    ? "Select a device"
                    : "No devices found"
            }
        }
    }

    Process {
        id: sendProc
        property string targetIp: ""
        command: {
            var cmd = ["bash", Quickshell.env("HOME") + "/.config/quickshell/localsend/localsend_send.sh", targetIp]
            for (var i = 0; i < airdropContent.droppedFilePaths.length; i++) {
                cmd.push(airdropContent.droppedFilePaths[i])
            }
            return cmd
        }
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                var text = line.trim()
                if (text.startsWith("PROGRESS:")) {
                    var val = parseFloat(text.substring(9))
                    if (!isNaN(val)) {
                        airdropContent.progressVal = val / 100.0
                    }
                } else if (text === "REJECTED") {
                    airdropContent.lsState = "error"
                    airdropContent.statusMessage = "Declined by receiver"
                } else if (text === "CANCELLED") {
                    airdropContent.lsState = "error"
                    airdropContent.statusMessage = "Cancelled by receiver"
                }
            }
        }
        onExited: (code) => {
            if (airdropContent.lsState === "idle") return
            
            if (code === 0) {
                airdropContent.lsState = "sent"
                airdropContent.statusMessage = "File sent!"
                sentResetTimer.start()
            } else {
                if (airdropContent.lsState !== "error" || (airdropContent.statusMessage !== "Declined by receiver" && airdropContent.statusMessage !== "Cancelled by receiver")) {
                    airdropContent.lsState = "error"
                    airdropContent.statusMessage = "Transfer failed"
                }
                sentResetTimer.start()
            }
        }
    }

    Timer {
        id: sentResetTimer
        interval: 2500
        onTriggered: {
            airdropContent.lsState = "idle"
            airdropContent.droppedFilePaths = []
            airdropContent.droppedFileName = ""
            airdropContent.statusMessage = ""
            // If open, close the panel
            if (rootWidget.airdropOpen) {
                rootWidget.toggleAirdrop()
            }
            // Clear minimized state since transfer is done
            rootWidget.airdropMinimized = false
        }
    }

    // ── Functions ─────────────────────────────────────────────────────────────
    function handleFileDrop(paths) {
        droppedFilePaths = paths
        if (paths.length === 1) {
            droppedFileName = paths[0].split('/').pop()
            droppedFileExt = droppedFileName.split('.').pop().toUpperCase()
        } else {
            droppedFileName = paths.length + " files"
            droppedFileExt = "MULTIPLE"
        }
        deviceModel.clear()
        lsState = "scanning"
        statusMessage = "Scanning for devices…"
        discoverProc.running = false
        discoverProc.running = true
    }

    function sendTo(ip) {
        lsState = "sending"
        statusMessage = "Sending…"
        sendProc.targetIp = ip
        sendProc.running = false
        sendProc.running = true
    }

    function reset() {
        lsState = "idle"
        droppedFilePaths = []
        droppedFileName = ""
        droppedFileExt = ""
        statusMessage = ""
        progressVal = 0.0
        deviceModel.clear()
        discoverProc.running = false
        sendProc.running = false
        // Clear rootWidget minimized state
        if (rootWidget) {
            rootWidget.airdropMinimized = false
        }
    }

    // ── UI ─────────────────────────────────────────────────────────────────────
    Column {
        anchors.fill: parent
        spacing: 0

        // ── Header with file info ────────────────────────────────────────
        RowLayout {
            width: parent.width
            height: 44
            spacing: 12

            // Airdrop icon
            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignVCenter
                radius: 16
                color: {
                    if (lsState === "sent") return Qt.rgba(0.2, 0.8, 0.4, 0.2)
                    if (lsState === "error") return Qt.rgba(0.9, 0.2, 0.2, 0.2)
                    if (lsState === "sending") return Qt.rgba(0.5, 0.4, 0.9, 0.25)
                    return Qt.rgba(0.35, 0.7, 0.9, 0.2)
                }
                Behavior on color { ColorAnimation { duration: 300 } }

                Text {
                    anchors.centerIn: parent
                    text: {
                        if (lsState === "sent") return "󰄬"
                        if (lsState === "error") return "󰅖"
                        if (lsState === "sending") return "󰕒"
                        return ""
                    }
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 16
                    color: {
                        if (lsState === "sent") return "#a6e3a1"
                        if (lsState === "error") return "#f38ba8"
                        if (lsState === "sending") return "#cba6f7"
                        return "#89dceb"
                    }
                    Behavior on color { ColorAnimation { duration: 300 } }

                    rotation: 0

                    SequentialAnimation {
                        id: headerScanAnim
                        running: lsState === "scanning"
                        loops: Animation.Infinite
                        NumberAnimation { target: headerScanAnim.parent; property: "rotation"; from: 0; to: 360; duration: 1200 }
                    }
                    Connections {
                        target: headerScanAnim
                        function onRunningChanged() { if (!headerScanAnim.running) headerScanAnim.parent.rotation = 0 }
                    }
                }
            }

            // File info
            Column {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Text {
                    width: parent.width
                    text: droppedFileName || "Drop a file to send"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: rootWidget.walColors.special.foreground
                    elide: Text.ElideMiddle
                }

                Text {
                    text: {
                        if (lsState === "idle" && !droppedFileName) return "Drag files onto the island"
                        if (statusMessage) return statusMessage
                        return droppedFileExt + " file"
                    }
                    font.family: "JetBrains Mono"
                    font.pixelSize: 11
                    color: rootWidget.walColors.special.foreground
                    opacity: 0.5
                }
            }

            // Minimize button (visible during active transfers)
            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                Layout.alignment: Qt.AlignVCenter
                radius: 14
                visible: lsState === "scanning" || lsState === "ready" || lsState === "sending"
                color: minimizeHover.containsMouse
                    ? Qt.rgba(1, 1, 1, 0.1)
                    : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: ""  // minimize icon
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 14
                    color: rootWidget.walColors.special.foreground
                    opacity: minimizeHover.containsMouse ? 0.9 : 0.6
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                MouseArea {
                    id: minimizeHover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        rootWidget.minimizeAirdrop()
                    }
                }
            }

            // Close button
            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                Layout.alignment: Qt.AlignVCenter
                radius: 14
                color: closeHover.containsMouse
                    ? Qt.rgba(1, 1, 1, 0.1)
                    : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 14
                    color: rootWidget.walColors.special.foreground
                    opacity: 0.6
                }

                MouseArea {
                    id: closeHover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        airdropContent.reset()
                        if (rootWidget.airdropOpen)
                            rootWidget.toggleAirdrop()
                    }
                }
            }
        }

        // ── Divider ──────────────────────────────────────────────────────
        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(
                rootWidget.walColors.special.foreground.r,
                rootWidget.walColors.special.foreground.g,
                rootWidget.walColors.special.foreground.b,
                0.1
            )
        }

        // ── Drop zone (when idle / waiting for file) ─────────────────────
        Item {
            width: parent.width
            height: parent.height - 45
            visible: lsState === "idle"

            DropArea {
                id: innerDrop
                anchors.fill: parent
                keys: ["text/uri-list", "text/plain"]

                property bool isHovered: false
                onEntered: (drag) => { isHovered = true }
                onExited: { isHovered = false }
                onDropped: (drop) => {
                    isHovered = false
                    if (drop.hasUrls) {
                        var paths = []
                        for (var i = 0; i < drop.urls.length; i++) {
                            var url = drop.urls[i].toString().trim()
                            if (url.startsWith("file://")) {
                                paths.push(decodeURIComponent(url.replace("file://", "")))
                            }
                        }
                        if (paths.length > 0) {
                            airdropContent.handleFileDrop(paths)
                        }
                    }
                    drop.accept()
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 8
                anchors.topMargin: 12
                radius: 16
                color: innerDrop.isHovered
                    ? Qt.rgba(0.35, 0.7, 0.9, 0.12)
                    : Qt.rgba(1, 1, 1, 0.03)
                border.width: 2
                border.color: innerDrop.isHovered
                    ? Qt.rgba(0.35, 0.7, 0.9, 0.4)
                    : Qt.rgba(1, 1, 1, 0.08)
                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                // Dashed border overlay
                Image {
                    anchors.fill: parent
                    visible: !innerDrop.isHovered
                    source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg'><rect width='100%' height='100%' fill='none' rx='16' stroke='%23585b70' stroke-width='1.5' stroke-dasharray='8 4'/></svg>"
                    fillMode: Image.Stretch
                    opacity: 0.5
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: innerDrop.isHovered ? "󰌶" : ""
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: 36
                        color: innerDrop.isHovered ? "#89dceb" : rootWidget.walColors.special.foreground
                        opacity: innerDrop.isHovered ? 1.0 : 0.35
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: innerDrop.isHovered ? "Release to send" : "Drop file here"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: innerDrop.isHovered ? "#89dceb" : rootWidget.walColors.special.foreground
                        opacity: innerDrop.isHovered ? 0.9 : 0.4
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
            }
        }

        // ── Scanning / Device list ───────────────────────────────────────
        Item {
            width: parent.width
            height: parent.height - 45
            visible: lsState !== "idle"

            // Scanning spinner
            Column {
                anchors.centerIn: parent
                spacing: 12
                visible: lsState === "scanning" && deviceModel.count === 0

                Rectangle {
                    width: 40; height: 40; radius: 20
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Qt.rgba(0.35, 0.7, 0.9, 0.15)
                    border.width: 2
                    border.color: Qt.rgba(0.35, 0.7, 0.9, 0.3)

                    Text {
                        id: scanSpinnerIcon
                        anchors.centerIn: parent
                        text: "󰍉"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: 18
                        color: "#89dceb"
                        rotation: 0

                        SequentialAnimation {
                            id: scanSpinnerAnim
                            running: lsState === "scanning"
                            loops: Animation.Infinite
                            NumberAnimation { target: scanSpinnerIcon; property: "rotation"; from: 0; to: 360; duration: 1500 }
                        }
                        Connections {
                            target: scanSpinnerAnim
                            function onRunningChanged() { if (!scanSpinnerAnim.running) scanSpinnerIcon.rotation = 0 }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Scanning network…"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 12
                    color: rootWidget.walColors.special.foreground
                    opacity: 0.5
                }
            }

            // Sending state
            Column {
                anchors.centerIn: parent
                spacing: 12
                visible: lsState === "sending"

                Rectangle {
                    width: 40; height: 40; radius: 20
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Qt.rgba(0.5, 0.4, 0.9, 0.15)
                    border.width: 2
                    border.color: Qt.rgba(0.5, 0.4, 0.9, 0.3)

                    Text {
                        anchors.centerIn: parent
                        text: "󰕒"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: 18
                        color: "#cba6f7"

                        SequentialAnimation on opacity {
                            running: lsState === "sending"
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.3; duration: 800 }
                            NumberAnimation { from: 0.3; to: 1.0; duration: 800 }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Sending " + droppedFileName + "…"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 12
                    color: rootWidget.walColors.special.foreground
                    opacity: 0.5
                    elide: Text.ElideMiddle
                    width: Math.min(implicitWidth, airdropContent.width - 40)
                }

                // Progress Bar
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 150
                    height: 4
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.1)
                    clip: true

                    Rectangle {
                        height: parent.height
                        width: parent.width * Math.max(0, Math.min(1, airdropContent.progressVal))
                        radius: 2
                        color: "#cba6f7"
                        Behavior on width { NumberAnimation { duration: 100 } }
                    }
                }
            }

            // Sent / Error state
            Column {
                anchors.centerIn: parent
                spacing: 12
                visible: lsState === "sent" || lsState === "error"

                Rectangle {
                    width: 40; height: 40; radius: 20
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: lsState === "sent"
                        ? Qt.rgba(0.2, 0.8, 0.4, 0.15)
                        : Qt.rgba(0.9, 0.2, 0.2, 0.15)
                    border.width: 2
                    border.color: lsState === "sent"
                        ? Qt.rgba(0.2, 0.8, 0.4, 0.3)
                        : Qt.rgba(0.9, 0.2, 0.2, 0.3)

                    Text {
                        anchors.centerIn: parent
                        text: lsState === "sent" ? "󰄬" : "󰅖"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: 18
                        color: lsState === "sent" ? "#a6e3a1" : "#f38ba8"
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: statusMessage
                    font.family: "JetBrains Mono"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: lsState === "sent" ? "#a6e3a1" : "#f38ba8"
                }
            }

            // Device list
            ListView {
                id: deviceList
                anchors.fill: parent
                anchors.topMargin: 8
                clip: true
                visible: (lsState === "ready" || (lsState === "scanning" && deviceModel.count > 0))
                model: deviceModel
                spacing: 6

                // No devices message
                Text {
                    anchors.centerIn: parent
                    visible: lsState === "ready" && deviceModel.count === 0
                    text: "No devices found"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 12
                    color: rootWidget.walColors.special.foreground
                    opacity: 0.4
                }

                delegate: Rectangle {
                    width: deviceList.width
                    height: 46
                    radius: 12
                    color: deviceHover.containsMouse
                        ? Qt.rgba(0.35, 0.7, 0.9, 0.12)
                        : Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: deviceHover.containsMouse
                        ? Qt.rgba(0.35, 0.7, 0.9, 0.25)
                        : Qt.rgba(1, 1, 1, 0.06)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 14; anchors.rightMargin: 14
                        spacing: 12

                        // Device icon
                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            Layout.alignment: Qt.AlignVCenter
                            radius: 15
                            color: Qt.rgba(0.35, 0.7, 0.9, 0.15)

                            Text {
                                anchors.centerIn: parent
                                text: "󰐻"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: 14
                                color: "#89dceb"
                            }
                        }

                        // Device info
                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            Text {
                                text: model.alias
                                font.family: "JetBrains Mono"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: rootWidget.walColors.special.foreground
                            }

                            Text {
                                text: model.ip
                                font.family: "JetBrains Mono"
                                font.pixelSize: 10
                                color: rootWidget.walColors.special.foreground
                                opacity: 0.4
                            }
                        }

                        // Send arrow
                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: "󰁔"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: 16
                            color: "#89dceb"
                            opacity: deviceHover.containsMouse ? 1.0 : 0.3
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }
                    }

                    MouseArea {
                        id: deviceHover
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: lsState === "ready"
                        onClicked: airdropContent.sendTo(model.ip)
                    }
                }
            }

            // Rescan button (when ready with or without devices)
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 6
                width: 100
                height: 28
                radius: 14
                visible: lsState === "ready"
                color: rescanHover.containsMouse
                    ? Qt.rgba(1, 1, 1, 0.08)
                    : Qt.rgba(1, 1, 1, 0.04)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.08)
                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "󰑐"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: 12
                        color: rootWidget.walColors.special.foreground
                        opacity: 0.6
                    }

                    Text {
                        text: "Rescan"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 10
                        color: rootWidget.walColors.special.foreground
                        opacity: 0.6
                    }
                }

                MouseArea {
                    id: rescanHover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        deviceModel.clear()
                        airdropContent.lsState = "scanning"
                        airdropContent.statusMessage = "Scanning for devices…"
                        discoverProc.running = false
                        discoverProc.running = true
                    }
                }
            }
        }
    }
}
