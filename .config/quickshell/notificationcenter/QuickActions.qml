import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// QuickActions – mute audio, mute mic, toggle Wi-Fi, power (wlogout).
// Designed to be embedded inside the NotificationCenter panel.
Item {
    id: root

    // ── Wal colors passed in from parent ─────────────────────────────────
    required property var walColors
    // ── State ────────────────────────────────────────────────────────────
    property bool active: false
    property bool audioMuted: false
    property bool micMuted: false
    property bool wifiOn: true
    // ── Poll current states ──────────────────────────────────────────────
    property var _stateTimer

    _stateTimer: Timer {
        interval: 2000
        running: root.active
        repeat: true
        onTriggered: {
            audioStateProc.running = true;
            micStateProc.running = true;
            wifiStateProc.running = true;
        }
    }

    property var audioStateProc

    audioStateProc: Process {
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]

        stdout: SplitParser {
            onRead: function(line) {
                root.audioMuted = line.indexOf("[MUTED]") !== -1;
            }
        }

    }

    property var micStateProc

    micStateProc: Process {
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SOURCE@"]

        stdout: SplitParser {
            onRead: function(line) {
                root.micMuted = line.indexOf("[MUTED]") !== -1;
            }
        }

    }

    property var wifiStateProc

    wifiStateProc: Process {
        command: ["bash", "-c", "nmcli radio wifi"]

        stdout: SplitParser {
            onRead: function(line) {
                root.wifiOn = line.trim() === "enabled";
            }
        }

    }

    // ── Toggle processes ─────────────────────────────────────────────────
    property var _audioToggle

    _audioToggle: Process {
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        onRunningChanged: {
            if (!running) {
                audioStateProc.running = true;
            }
        }
    }

    property var _micToggle

    _micToggle: Process {
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]
        onRunningChanged: {
            if (!running) {
                micStateProc.running = true;
            }
        }
    }
    // Using a detached process so kitty stays open when Quickshell reloads

    property var _launchNmtui

    _launchNmtui: Process {
        command: ["sh", "-c", "kitty -e nmtui &"]
    }

    // ── Power (wlogout) ──────────────────────────────────────────────────
    property var _wlogout

    _wlogout: Process {
        command: ["sh", "-c", "~/.config/hypr/scripts_hypr/wlogout.sh"]
    }

    implicitHeight: actionsRow.implicitHeight
    onActiveChanged: {
        if (active) {
            audioStateProc.running = true;
            micStateProc.running = true;
            wifiStateProc.running = true;
        }
    }
    RowLayout {
        id: actionsRow

        spacing: 8

        anchors {
            left: parent.left
            right: parent.right
        }

        // ── Audio mute ───────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 64 // Increased height
            radius: 14
            color: root.audioMuted ? Qt.rgba(root.walColors.colors.color2.r, root.walColors.colors.color2.g, root.walColors.colors.color2.b, 0.22) : Qt.rgba(1, 1, 1, 0.05)
            border.color: root.audioMuted ? root.walColors.colors.color2 : Qt.rgba(1, 1, 1, 0.12)
            border.width: 1

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 2

                Image {
                    id: audioImg

                    Layout.alignment: Qt.AlignHCenter
                    source: root.audioMuted ? "../assets/icons/speaker_mute.svg" : "../assets/icons/speaker.svg"
                    sourceSize: Qt.size(28, 28) // Increased icon size
                    visible: false
                }

                ColorOverlay {
                    Layout.alignment: Qt.AlignHCenter
                    width: 28 // Increased overlay size
                    height: 28
                    source: audioImg
                    color: root.walColors.special.foreground
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.audioMuted ? "Unmute" : "Mute"
                    color: root.walColors.special.foreground // Increased font
                    font.family: "JetBrains Mono"
                    font.pixelSize: 11
                    opacity: 0.7
                }

            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root._audioToggle.running = true

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }

                    }

                }

            }

            Behavior on color {
                ColorAnimation {
                    duration: 200
                }

            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 200
                }

            }

        }

        // ── Mic mute ─────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 64 // Increased height
            radius: 14
            color: root.micMuted ? Qt.rgba(root.walColors.colors.color2.r, root.walColors.colors.color2.g, root.walColors.colors.color2.b, 0.22) : Qt.rgba(1, 1, 1, 0.05)
            border.color: root.micMuted ? root.walColors.colors.color2 : Qt.rgba(1, 1, 1, 0.12)
            border.width: 1

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 2

                Image {
                    id: micImg

                    Layout.alignment: Qt.AlignHCenter
                    source: root.micMuted ? "../assets/icons/mic_muted.svg" : "../assets/icons/mic.svg"
                    sourceSize: Qt.size(28, 28) // Increased icon size
                    visible: false
                }

                ColorOverlay {
                    Layout.alignment: Qt.AlignHCenter
                    width: 28 // Increased overlay size
                    height: 28
                    source: micImg
                    color: root.walColors.special.foreground
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.micMuted ? "Mic Off" : "Mic On"
                    color: root.walColors.special.foreground // Increased font
                    font.family: "JetBrains Mono"
                    font.pixelSize: 11
                    opacity: 0.7
                }

            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root._micToggle.running = true

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }

                    }

                }

            }

            Behavior on color {
                ColorAnimation {
                    duration: 200
                }

            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 200
                }

            }

        }

        // ── Wi-Fi ────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 64 // Increased height
            radius: 14
            color: root.wifiOn ? Qt.rgba(root.walColors.colors.color2.r, root.walColors.colors.color2.g, root.walColors.colors.color2.b, 0.22) : Qt.rgba(1, 1, 1, 0.05)
            border.color: root.wifiOn ? root.walColors.colors.color2 : Qt.rgba(1, 1, 1, 0.12)
            border.width: 1

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 2

                Image {
                    id: wifiImg

                    Layout.alignment: Qt.AlignHCenter
                    source: "../assets/icons/wifi.svg"
                    sourceSize: Qt.size(28, 28) // Increased icon size
                    visible: false
                }

                ColorOverlay {
                    Layout.alignment: Qt.AlignHCenter
                    width: 28 // Increased overlay size
                    height: 28
                    source: wifiImg
                    color: root.walColors.special.foreground
                    opacity: 1
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Wi-Fi"
                    color: root.walColors.special.foreground // Increased font
                    font.family: "JetBrains Mono"
                    font.pixelSize: 11
                    opacity: 0.7
                }

            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root._launchNmtui.running = true

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }

                    }

                }

            }

            Behavior on color {
                ColorAnimation {
                    duration: 200
                }

            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 200
                }

            }

        }

        // ── Power (wlogout) ──────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 64 // Increased height
            radius: 14
            color: Qt.rgba(1, 1, 1, 0.05)
            border.color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 2

                Image {
                    id: powerImg

                    Layout.alignment: Qt.AlignHCenter
                    source: "../assets/icons/power.svg"
                    sourceSize: Qt.size(28, 28) // Increased icon size
                    visible: false
                }

                ColorOverlay {
                    Layout.alignment: Qt.AlignHCenter
                    width: 28 // Increased overlay size
                    height: 28
                    source: powerImg
                    color: root.walColors.special.foreground
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Power"
                    color: root.walColors.special.foreground // Increased font
                    font.family: "JetBrains Mono"
                    font.pixelSize: 11
                    opacity: 0.7
                }

            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root._wlogout.running = true

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }

                    }

                }

            }

        }

    }

}
