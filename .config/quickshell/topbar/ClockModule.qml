import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    property var walColors: null
    
    // Window dimensions for shell.qml to bind to.
    implicitWidth: 140
    implicitHeight: 50

    // The clock pill
    Rectangle {
        id: pill
        x: 0
        y: 5 // Add a small margin from the top
        
        width: 140
        height: 40
        radius: height / 2
        
        color: root.walColors ? root.walColors.special.background : "#1c1e26"
        border.color: root.walColors ? root.walColors.colors.color4 : "transparent"
        border.width: 0

        // Clock content
        RowLayout {
            anchors.centerIn: parent
            spacing: 8
            
            Text {
                text: "󰥔"
                color: root.walColors ? root.walColors.colors.color4 : "#89b4fa"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
            }

            Text {
                id: timeText
                color: root.walColors ? root.walColors.special.foreground : "#ebdbb2"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.weight: Font.Bold
                text: Qt.formatTime(new Date(), "hh:mm:ss AP")
            }
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: timeText.text = Qt.formatTime(new Date(), "hh:mm:ss AP")
        }
    }
}
