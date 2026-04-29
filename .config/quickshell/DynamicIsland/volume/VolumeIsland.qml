import QtQuick
import QtQuick.Layouts

Rectangle {
    id: volumePill
    property var rootWidget

    readonly property int gapHeight:      7
    readonly property int pillHeight:     38
    readonly property int pillWidth:      180
    readonly property int totalHeight:    pillHeight + gapHeight
    readonly property int targetWidth:    pillWidth

    width:  pillWidth
    height: pillHeight
    radius: pillHeight / 2

    color:        rootWidget.walColors.special.background
    border.color: "#3d4150"
    border.width: 1

    transformOrigin: Item.Top
    scale: rootWidget.volumeVisible ? 1.0 : 0.0
    opacity: rootWidget.volumeVisible ? 1.0 : 0.0

    Behavior on scale {
        NumberAnimation {
            duration: 380
            easing.type: rootWidget.volumeVisible ? Easing.OutBack : Easing.InBack
            easing.overshoot: rootWidget.volumeVisible ? 1.4 : 0.8
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: rootWidget.volumeVisible ? 150 : 280
            easing.type: Easing.InOutQuad
        }
    }

    RowLayout {
        anchors {
            verticalCenter: parent.verticalCenter
            left:           parent.left
            right:          parent.right
            leftMargin:     14
            rightMargin:    14
        }
        spacing: 10

        Text {
            id: volIcon
            text: {
                if (rootWidget.isMuted || rootWidget.currentVolume <= 0.0) return "🔇";
                if (rootWidget.currentVolume < 0.35)                 return "🔈";
                if (rootWidget.currentVolume < 0.70)                 return "🔉";
                return "🔊";
            }
            font.pixelSize: 15
            Layout.alignment: Qt.AlignVCenter

            Behavior on text {
                SequentialAnimation {
                    NumberAnimation { target: volIcon; property: "scale"; to: 1.3; duration: 80 }
                    NumberAnimation { target: volIcon; property: "scale"; to: 1.0; duration: 150; easing.type: Easing.OutBounce }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            height: 6
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.1)
            }

            Rectangle {
                id: volBar
                anchors {
                    left:           parent.left
                    top:            parent.top
                    bottom:         parent.bottom
                }
                radius: height / 2

                width: Math.max(radius * 2,
                                Math.min(parent.width,
                                         parent.width * (rootWidget.isMuted ? 0 : rootWidget.currentVolume)))

                Behavior on width {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                color: {
                    var v = rootWidget.isMuted ? 0 : rootWidget.currentVolume;
                    if (v < 0.6)  return rootWidget.walColors.colors.color2;
                    if (v < 0.85) return rootWidget.walColors.colors.color3;
                    return rootWidget.walColors.colors.color1;
                }

                Behavior on color {
                    ColorAnimation { duration: 300 }
                }
            }
        }

        Text {
            id: volPctLabel
            text: rootWidget.isMuted ? "—" : Math.round(rootWidget.currentVolume * 100) + "%"
            color: rootWidget.walColors.special.foreground
            font.family: "JetBrains Mono"
            font.pixelSize: 11
            font.weight: Font.Medium
            opacity: 0.85
            Layout.alignment: Qt.AlignVCenter

            Behavior on text {
                SequentialAnimation {
                    NumberAnimation { target: volPctLabel; property: "opacity"; to: 0.3; duration: 60 }
                    NumberAnimation { target: volPctLabel; property: "opacity"; to: 0.85; duration: 120 }
                }
            }
        }
    }
}
