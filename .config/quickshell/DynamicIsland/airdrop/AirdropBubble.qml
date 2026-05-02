import QtQuick
import QtQuick.Layouts

// Floating bubble that appears on the LEFT side of the dynamic island
// when the airdrop panel is minimized but a transfer is still in progress.
Rectangle {
    id: root

    property var walColors: null
    // Airdrop state mirrored from AirdropContent
    property string lsState: "idle"       // idle | scanning | ready | sending | sent | error
    property string fileName: ""
    property string statusMessage: ""

    signal clicked()

    antialiasing: true
    clip: true
    layer.enabled: true
    width: 45
    height: 45
    radius: 300
    color: walColors ? walColors.special.background : "#1c1e26"
    border.color: {
        if (lsState === "sending") return Qt.rgba(0.5, 0.4, 0.9, 0.6)   // purple
        if (lsState === "sent") return Qt.rgba(0.4, 0.85, 0.5, 0.6)     // green
        if (lsState === "error") return Qt.rgba(0.9, 0.3, 0.3, 0.6)     // red
        return "#3d4150"
    }
    border.width: 1
    opacity: 0
    scale: 0.8

    Behavior on border.color { ColorAnimation { duration: 300 } }

    states: [
        State {
            name: "visible"

            PropertyChanges {
                target: root
                opacity: 1
                scale: 1
            }
        }
    ]

    // ── Icon content ──────────────────────────────────────────────────
    Item {
        anchors.fill: parent

        MouseArea {
            id: bubbleMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }

        // Main icon
        Text {
            id: mainIcon
            anchors.centerIn: parent
            text: {
                if (root.lsState === "sent") return "󰄬"
                if (root.lsState === "error") return "󰅖"
                if (root.lsState === "sending") return "󰕒"
                if (root.lsState === "scanning") return "󰍉"
                return "󰒊"
            }
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 18
            color: {
                if (root.lsState === "sent") return "#a6e3a1"
                if (root.lsState === "error") return "#f38ba8"
                if (root.lsState === "sending") return "#cba6f7"
                if (root.lsState === "scanning") return "#89dceb"
                if (bubbleMouseArea.containsMouse) return walColors ? walColors.colors.color2 : "#89dceb"
                return walColors ? walColors.special.foreground : "#cdd6f4"
            }
            opacity: bubbleMouseArea.containsMouse ? 1 : 0.7

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        // Pulsing animation for sending
        SequentialAnimation {
            running: root.lsState === "sending"
            loops: Animation.Infinite

            NumberAnimation {
                target: mainIcon
                property: "opacity"
                from: 1.0; to: 0.3
                duration: 800
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: mainIcon
                property: "opacity"
                from: 0.3; to: 1.0
                duration: 800
                easing.type: Easing.InOutQuad
            }
        }

        // Spinning animation for scanning — resets to 0 when stopped
        SequentialAnimation {
            id: scanRotation
            running: root.lsState === "scanning"
            loops: Animation.Infinite

            NumberAnimation {
                target: mainIcon
                property: "rotation"
                from: 0; to: 360
                duration: 1500
            }
        }

        // Reset rotation cleanly when scanning stops
        Connections {
            target: scanRotation
            function onRunningChanged() {
                if (!scanRotation.running)
                    mainIcon.rotation = 0;
            }
        }

        // Subtle progress ring for sending state
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: root.lsState === "sending"
                ? Qt.rgba(0.5, 0.4, 0.9, 0.3)
                : "transparent"
            visible: root.lsState === "sending"

            Behavior on border.color { ColorAnimation { duration: 300 } }
        }
    }

    // ── Tooltip on hover ──────────────────────────────────────────────
    Rectangle {
        id: tooltip
        visible: bubbleMouseArea.containsMouse && root.fileName !== ""
        opacity: visible ? 1 : 0
        anchors.top: parent.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        width: tooltipContent.implicitWidth + 16
        height: tooltipContent.implicitHeight + 10
        radius: 8
        color: walColors ? Qt.rgba(walColors.special.background.r, walColors.special.background.g, walColors.special.background.b, 0.95) : "#1c1e26"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)

        Behavior on opacity { NumberAnimation { duration: 150 } }

        Column {
            id: tooltipContent
            anchors.centerIn: parent
            spacing: 2

            Text {
                text: root.fileName
                font.family: "JetBrains Mono"
                font.pixelSize: 10
                font.weight: Font.Bold
                color: walColors ? walColors.special.foreground : "#cdd6f4"
                elide: Text.ElideMiddle
                width: Math.min(implicitWidth, 160)
            }

            Text {
                text: root.statusMessage || root.lsState
                font.family: "JetBrains Mono"
                font.pixelSize: 9
                color: {
                    if (root.lsState === "sent") return "#a6e3a1"
                    if (root.lsState === "error") return "#f38ba8"
                    if (root.lsState === "sending") return "#cba6f7"
                    return walColors ? walColors.special.foreground : "#cdd6f4"
                }
                opacity: 0.6
            }
        }
    }

    // ── Behaviors ─────────────────────────────────────────────────────
    Behavior on width {
        NumberAnimation { duration: 600; easing.type: Easing.OutExpo }
    }

    Behavior on height {
        NumberAnimation { duration: 600; easing.type: Easing.OutExpo }
    }

    Behavior on radius {
        NumberAnimation { duration: 600; easing.type: Easing.OutExpo }
    }

    Behavior on opacity {
        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
    }

    Behavior on scale {
        NumberAnimation { duration: 400; easing.type: Easing.OutExpo }
    }
}
