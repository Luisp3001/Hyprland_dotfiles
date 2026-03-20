import QtQuick

Rectangle {
    id: root

    property string icon: ""
    property bool highlighted: false
    property bool toggleActive: false

    signal clicked()

    width: 30
    height: 30
    radius: 15

    color: {
        if (mouseArea.pressed) return highlighted ? "#ebdbb2" : "#454e63";
        if (mouseArea.containsMouse) return highlighted ? walColors.colors.color2  : "#3d4150";
        if (toggleActive) return Qt.rgba(walColors.colors.color2.r, walColors.colors.color2.g, walColors.colors.color2.b, 0.25);
        return highlighted ? walColors.colors.color1 : "transparent";
    }

    Behavior on color {
        ColorAnimation { duration: 120 }
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: {
            if (mouseArea.pressed && highlighted) return "#1c1e26";
            if (root.toggleActive) return walColors.colors.color2;
            return "#ebdbb2";
        }
        font.pixelSize: 13

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
