import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property date currentDate: new Date()
    property date displayDate: new Date()
    property var walColors: null

    property bool active: false

    color: "transparent"
    border.width: 0

    // Optimization: only use layer when animating (managed by parent if needed)
    // For now, let's keep it simple but efficient
    clip: true

    readonly property int firstDayOfMonth: getFirstDayOfMonth(displayDate.getMonth(), displayDate.getFullYear())
    readonly property int daysInMonth: getDaysInMonth(displayDate.getMonth(), displayDate.getFullYear())

    function getDaysInMonth(month, year) {
        return new Date(year, month + 1, 0).getDate();
    }

    function getFirstDayOfMonth(month, year) {
        return new Date(year, month, 1).getDay();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15
        
        opacity: root.active ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        // Header: Month and Year
        RowLayout {
            Layout.fillWidth: true
            
            Text {
                text: Qt.formatDate(root.displayDate, "MMMM yyyy")
                color: root.walColors ? root.walColors.special.foreground : "white"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 20
                font.weight: Font.Bold
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: 12
                
                // Prev Month
                Rectangle {
                    width: 30; height: 30; radius: 15
                    color: prevMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    Text { text: "󰁍"; anchors.centerIn: parent; font.pixelSize: 18; color: root.walColors ? root.walColors.colors.color4 : "white" }
                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            var d = new Date(root.displayDate.getFullYear(), root.displayDate.getMonth() - 1, 1);
                            root.displayDate = d;
                        }
                    }
                }

                // Next Month
                Rectangle {
                    width: 30; height: 30; radius: 15
                    color: nextMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    Text { text: "󰁔"; anchors.centerIn: parent; font.pixelSize: 18; color: root.walColors ? root.walColors.colors.color4 : "white" }
                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            var d = new Date(root.displayDate.getFullYear(), root.displayDate.getMonth() + 1, 1);
                            root.displayDate = d;
                        }
                    }
                }
            }
        }

        // Days of week header
        RowLayout {
            Layout.fillWidth: true
            Repeater {
                model: ["Dom", "Lun", "Mar", "Mie", "Jue", "Vie", "Sab"]
                delegate: Text {
                    text: modelData
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    color: root.walColors ? root.walColors.special.foreground : "gray"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    opacity: 0.4
                }
            }
        }

        // Calendar Grid
        GridLayout {
            columns: 7
            Layout.fillWidth: true
            Layout.fillHeight: true
            rowSpacing: 4
            columnSpacing: 4

            Repeater {
                model: 42 // 6 weeks * 7 days
                delegate: Rectangle {
                    id: dayRect
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: 10
                    
                    readonly property int dayNumber: {
                        var date = index - root.firstDayOfMonth + 1;
                        return (date > 0 && date <= root.daysInMonth) ? date : -1;
                    }

                    readonly property bool isToday: {
                        return dayNumber === root.currentDate.getDate() && 
                               root.displayDate.getMonth() === root.currentDate.getMonth() &&
                               root.displayDate.getFullYear() === root.currentDate.getFullYear();
                    }

                    color: isToday ? (root.walColors ? root.walColors.colors.color4 : "#89b4fa") : "transparent"
                    border.color: (dayNumber !== -1 && !isToday && dayMouse.containsMouse) ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: dayNumber === -1 ? "" : dayNumber
                        color: isToday ? (root.walColors ? root.walColors.special.background : "#1c1e26") : 
                                         (root.walColors ? root.walColors.special.foreground : "white")
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        font.weight: isToday ? Font.Bold : Font.Normal
                        opacity: dayNumber === -1 ? 0 : (isToday ? 1 : 0.8)
                    }

                    MouseArea {
                        id: dayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: dayNumber !== -1
                    }
                }
            }
        }
    }

}
