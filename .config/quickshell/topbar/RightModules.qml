import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    property var walColors: null

    implicitWidth: layout.implicitWidth + 20
    implicitHeight: 50

    RowLayout {
        id: layout
        anchors {
            top: parent.top
            right: parent.right
            topMargin: 10
            rightMargin: 15
        }
        spacing: 5
        layoutDirection: Qt.LeftToRight

        SystemTrayModule {
            walColors: root.walColors
            opacity: shell.calendarVisible ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutSine } }
        }

        VolumeModule {
            walColors: root.walColors
            opacity: shell.calendarVisible ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutSine } }
        }

        CpuModule {
            walColors: root.walColors
            opacity: shell.calendarVisible ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutSine } }
        }

        NetworkModule {
            walColors: root.walColors
            opacity: shell.calendarVisible ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutSine } }
        }
    }
}
