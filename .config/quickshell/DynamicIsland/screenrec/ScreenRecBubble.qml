import QtQuick
import QtQuick.Layouts

// Floating bubble that appears on the LEFT side of the dynamic island
// when a screen recording is active but minimized.
Rectangle {
    id: root

    property var walColors: null
    property var rootWidget: null // Passed from DynamicIslandWidget

    signal clicked()

    antialiasing: true
    clip: true
    layer.enabled: true
    width: 45
    height: 45
    radius: height / 2
    color: walColors ? walColors.special.background : "#1c1e26"
    
    border.color: {
        if (rootWidget && rootWidget.screenRecState === "paused")
            return Qt.rgba(0.95, 0.65, 0.15, 0.55);
        if (rootWidget && rootWidget.screenRecState === "recording")
            return Qt.rgba(0.95, 0.25, 0.25, 0.5);
        return "#3d4150";
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
            text: "󰑋" // Record icon
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 18
            color: {
                if (rootWidget && rootWidget.screenRecState === "paused") return "#f9e2af"; // Yellow
                if (rootWidget && rootWidget.screenRecState === "recording") return "#f38ba8"; // Red
                if (bubbleMouseArea.containsMouse) return walColors ? walColors.colors.color2 : "#89dceb";
                return walColors ? walColors.special.foreground : "#cdd6f4";
            }
            opacity: bubbleMouseArea.containsMouse ? 1 : 0.7

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        // Pulsing animation for recording
        SequentialAnimation {
            running: rootWidget && rootWidget.screenRecState === "recording"
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
    }

    // ── Tooltip on hover ──────────────────────────────────────────────
    Rectangle {
        id: tooltip
        visible: bubbleMouseArea.containsMouse && rootWidget && (rootWidget.screenRecState === "recording" || rootWidget.screenRecState === "paused")
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
                function formatTime(sec) {
                    var s = Math.floor(sec % 60);
                    var m = Math.floor(sec / 60);
                    return m + ":" + (s < 10 ? "0" : "") + s;
                }
                text: "Screen Record"
                font.family: "JetBrains Mono"
                font.pixelSize: 10
                font.weight: Font.Bold
                color: walColors ? walColors.special.foreground : "#cdd6f4"
            }

            Text {
                text: rootWidget ? (rootWidget.screenRecState === "paused" ? "Paused (" + parent.children[0].formatTime(rootWidget.screenRecElapsed) + ")" : "Recording (" + parent.children[0].formatTime(rootWidget.screenRecElapsed) + ")") : ""
                font.family: "JetBrains Mono"
                font.pixelSize: 9
                color: rootWidget && rootWidget.screenRecState === "paused" ? "#f9e2af" : "#f38ba8"
                opacity: 0.8
            }
        }
    }

    Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
    Behavior on height { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
    Behavior on radius { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
}
