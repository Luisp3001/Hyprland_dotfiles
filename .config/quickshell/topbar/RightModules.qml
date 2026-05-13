import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    property var walColors: null
    property var panelWindow: null
    property bool onACPower: true

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
            panelWindow: root.panelWindow
        }

        VolumeModule {
            walColors: root.walColors
        }

        CpuModule {
            walColors: root.walColors
            onACPower: root.onACPower
        }

        BatteryModule {
            walColors: root.walColors
            onACPower: root.onACPower
        }
    }
}
