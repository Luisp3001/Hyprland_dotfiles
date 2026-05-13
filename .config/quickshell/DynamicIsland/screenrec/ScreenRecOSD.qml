import QtQuick
import QtQuick.Layouts

// Compact OSD for screen recording when user is in fullscreen mode.
// Two views:
//   1. Selector: choose Full Screen or Region
//   2. Recording: elapsed time + pause / stop controls
Rectangle {
    id: osd

    // ── External bindings ─────────────────────────────────────────────
    property var walColors: null
    property string screenRecState: "idle"    // "idle" | "recording" | "paused"
    property int screenRecElapsed: 0
    property bool selectorMode: false         // true → show mode selector
    property bool osdVisible: false           // master visibility toggle

    signal selectFullscreen()
    signal selectRegion()
    signal requestPause()
    signal requestResume()
    signal requestStop()
    signal dismissed()

    // ── Appearance ────────────────────────────────────────────────────
    readonly property color bgColor: walColors ? walColors.special.background : "#1c1e26"
    readonly property color fgColor: walColors ? walColors.special.foreground : "#cdd6f4"
    readonly property color accent:  walColors ? walColors.colors.color2 : "#fab387"
    readonly property color recRed:  "#f03838"
    readonly property color pauseYellow: Qt.rgba(0.95, 0.65, 0.15, 1)

    width: contentRow.implicitWidth + 36
    height: 52
    radius: height / 2
    color: Qt.rgba(bgColor.r, bgColor.g, bgColor.b, 0.92)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.08)

    // ── Animation ─────────────────────────────────────────────────────
    transformOrigin: Item.Bottom
    scale: osdVisible ? 1.0 : 0.0
    opacity: osdVisible ? 1.0 : 0.0

    Behavior on scale {
        NumberAnimation {
            duration: 380
            easing.type: osd.osdVisible ? Easing.OutBack : Easing.InBack
            easing.overshoot: osd.osdVisible ? 1.4 : 0.8
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: osd.osdVisible ? 150 : 280
            easing.type: Easing.InOutQuad
        }
    }
    Behavior on width {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }

    function formatTime(sec) {
        var s = Math.floor(sec % 60);
        var m = Math.floor(sec / 60);
        return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s);
    }

    // ── Content ───────────────────────────────────────────────────────
    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 8

        // ━━━━ Selector Mode ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        Item {
            id: selectorContent
            visible: opacity > 0
            opacity: osd.selectorMode && osd.screenRecState === "idle" ? 1 : 0
            Layout.preferredWidth: visible ? selectorRow.implicitWidth : 0
            Layout.preferredHeight: 36

            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            RowLayout {
                id: selectorRow
                anchors.centerIn: parent
                spacing: 6

                // Record icon
                Text {
                    text: "󰑋"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 18
                    color: osd.fgColor
                    opacity: 0.7
                }

                // Separator
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 22
                    color: Qt.rgba(1, 1, 1, 0.12)
                }

                // Full Screen pill
                Rectangle {
                    id: fsPill
                    Layout.preferredWidth: fsRow.implicitWidth + 20
                    Layout.preferredHeight: 32
                    radius: 16
                    color: fsMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: fsMa.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.08)

                    Behavior on color      { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    scale: fsMa.pressed ? 0.93 : 1.0
                    Behavior on scale { NumberAnimation { duration: 80 } }

                    RowLayout {
                        id: fsRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: "󰍹"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: 14
                            color: osd.fgColor
                        }
                        Text {
                            text: "Full Screen"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: osd.fgColor
                        }
                    }

                    MouseArea {
                        id: fsMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: osd.selectFullscreen()
                    }
                }

                // Region pill
                Rectangle {
                    id: regPill
                    Layout.preferredWidth: regRow.implicitWidth + 20
                    Layout.preferredHeight: 32
                    radius: 16
                    color: regMa.containsMouse ? Qt.rgba(0.54, 0.84, 0.67, 0.14) : Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: regMa.containsMouse ? Qt.rgba(0.54, 0.84, 0.67, 0.4) : Qt.rgba(1, 1, 1, 0.08)

                    Behavior on color      { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    scale: regMa.pressed ? 0.93 : 1.0
                    Behavior on scale { NumberAnimation { duration: 80 } }

                    RowLayout {
                        id: regRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: "󰆟"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: 14
                            color: regMa.containsMouse ? "#a6e3a1" : osd.fgColor
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        Text {
                            text: "Region"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: regMa.containsMouse ? "#a6e3a1" : osd.fgColor
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

                    MouseArea {
                        id: regMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: osd.selectRegion()
                    }
                }
            }
        }

        // ━━━━ Recording / Paused Mode ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        Item {
            id: recContent
            visible: opacity > 0
            opacity: (osd.screenRecState === "recording" || osd.screenRecState === "paused") && !osd.selectorMode ? 1 : 0
            Layout.preferredWidth: visible ? recRow.implicitWidth : 0
            Layout.preferredHeight: 36

            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            RowLayout {
                id: recRow
                anchors.centerIn: parent
                spacing: 10

                // Pulsing record dot
                Rectangle {
                    id: recDot
                    Layout.preferredWidth: 10
                    Layout.preferredHeight: 10
                    radius: 5
                    color: osd.screenRecState === "paused" ? osd.pauseYellow : osd.recRed
                    Layout.alignment: Qt.AlignVCenter

                    SequentialAnimation on opacity {
                        running: osd.screenRecState === "recording"
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.25; duration: 700; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 0.25; to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
                    }
                }

                // Elapsed time
                Text {
                    text: osd.formatTime(osd.screenRecElapsed)
                    font.family: "JetBrains Mono"
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    color: osd.fgColor
                    Layout.alignment: Qt.AlignVCenter
                }

                // Separator
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 22
                    color: Qt.rgba(1, 1, 1, 0.12)
                }

                // Pause / Resume button
                Rectangle {
                    id: pauseBtn
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 16
                    color: pauseBtnMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: pauseBtnMa.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : "transparent"
                    Layout.alignment: Qt.AlignVCenter

                    Behavior on color      { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    scale: pauseBtnMa.pressed ? 0.9 : 1.0
                    Behavior on scale { NumberAnimation { duration: 80 } }

                    Text {
                        anchors.centerIn: parent
                        text: osd.screenRecState === "paused" ? "󰏤" : "󰐊"
                        font.pixelSize: 14
                        color: osd.fgColor
                    }

                    MouseArea {
                        id: pauseBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (osd.screenRecState === "recording")
                                osd.requestPause();
                            else if (osd.screenRecState === "paused")
                                osd.requestResume();
                        }
                    }
                }

                // Stop button
                Rectangle {
                    id: stopBtn
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 16
                    color: stopBtnMa.containsMouse ? Qt.rgba(0.94, 0.22, 0.22, 0.2) : Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: stopBtnMa.containsMouse ? Qt.rgba(0.94, 0.22, 0.22, 0.5) : "transparent"
                    Layout.alignment: Qt.AlignVCenter

                    Behavior on color      { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    scale: stopBtnMa.pressed ? 0.9 : 1.0
                    Behavior on scale { NumberAnimation { duration: 80 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰓛"
                        font.pixelSize: 12
                        color: stopBtnMa.containsMouse ? osd.recRed : osd.fgColor
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    MouseArea {
                        id: stopBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: osd.requestStop()
                    }
                }
            }
        }
    }
}
