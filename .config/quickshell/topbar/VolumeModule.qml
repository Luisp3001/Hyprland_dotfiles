import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: root
    property var walColors: null

    Layout.preferredHeight: 40
    Layout.preferredWidth: Math.max(90, row.implicitWidth + 30)
    radius: height / 2
    color: root.walColors ? root.walColors.special.background : "#1c1e26"
    
    // Smooth hover effect
    property bool hovered: false
    opacity: hovered ? 0.8 : 1.0
    Behavior on opacity { NumberAnimation { duration: 200 } }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: root.hovered = true
        onExited: root.hovered = false
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["pavucontrol"])
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Text {
            id: volIcon
            text: {
                if (shell.isMuted || shell.currentVolume <= 0.0) return "󰝟"
                if (shell.currentVolume < 0.35) return "󰕿"
                if (shell.currentVolume < 0.70) return "󰖀"
                return "󰕾"
            }
            color: root.walColors ? root.walColors.colors.color4 : "#89b4fa"
            font.family: "JetBrainsMono Nerd Fonts Mono"
            font.pixelSize: 20
            
            // Icon pop animation on volume change
            Behavior on text {
                SequentialAnimation {
                    NumberAnimation { target: volIcon; property: "scale"; to: 1.3; duration: 80 }
                    NumberAnimation { target: volIcon; property: "scale"; to: 1.0; duration: 150; easing.type: Easing.OutBounce }
                }
            }
        }

        Text {
            text: shell.isMuted ? "MUTED" : Math.round(shell.currentVolume * 100) + "%"
            color: root.walColors ? root.walColors.special.foreground : "#ebdbb2"
            font.family: "JetBrainsMono Nerd Fonts Mono"
            font.pixelSize: 14
            font.weight: Font.Bold
        }
    }
}
