import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    property var walColors: null
    
    property bool isExpanded: shell.calendarVisible

    Connections {
        target: shell
        function onCalendarVisibleChanged() {
            if (shell.calendarVisible) {
                shrinkTimer.stop()
                root.isExpanded = true
            } else {
                shrinkTimer.restart()
            }
        }
    }

    Timer {
        id: shrinkTimer
        interval: 320 // Slightly longer than the 300ms animation
        onTriggered: root.isExpanded = false
    }

    // Window dimensions for shell.qml to bind to.
    // Width is always 330 to avoid horizontal window jumping/teleporting.
    implicitWidth: 330
    // Height snaps instantly on expand and delays on shrink to cover the animation.
    implicitHeight: isExpanded ? 450 : 50

    // The animating pill
    Rectangle {
        id: pill
        // Keep it aligned to the right edge of the 330px window
        x: shell.calendarVisible ? 0 : (root.width - 140)
        y: 5 // Add a small margin from the top
        
        width: shell.calendarVisible ? 320 : 140
        height: shell.calendarVisible ? 400 : 40
        radius: shell.calendarVisible ? 24 : height / 2
        
        color: {
            if (!root.walColors) return "#1c1e26";
            var bg = Qt.color(root.walColors.special.background);
            return shell.calendarVisible ? Qt.rgba(bg.r, bg.g, bg.b, 0.95) : bg;
        }
        border.color: root.walColors ? root.walColors.colors.color4 : "transparent"
        border.width: shell.calendarVisible ? 1 : 0
        
        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 200 } }

        // Intercept clicks to toggle calendar if clicked on the pill background
        MouseArea {
            anchors.fill: parent
            onClicked: shell.calendarVisible = !shell.calendarVisible
            onEntered: if (!shell.calendarVisible) pill.opacity = 0.8
            onExited: pill.opacity = 1.0
            hoverEnabled: true
            
            // Allow clicks to pass through to the calendar buttons when expanded
            // Actually, we'll let CalendarView intercept its own clicks by placing it above.
        }

        // --- CLOCK CONTENT (Fades out when expanded) ---
        RowLayout {
            anchors.centerIn: parent
            spacing: 8
            
            opacity: shell.calendarVisible ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

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
            running: !shell.calendarVisible
            repeat: true
            onTriggered: timeText.text = Qt.formatTime(new Date(), "hh:mm:ss AP")
        }

        // --- CALENDAR CONTENT (Fades in when expanded) ---
        CalendarView {
            anchors.fill: parent
            walColors: root.walColors
            active: shell.calendarVisible
        }
    }
}
