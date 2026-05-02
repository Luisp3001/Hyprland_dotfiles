import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: screenRecContent
    property var rootWidget

    property real preferredHeight: 250

    // Background click to close
    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (rootWidget)
                rootWidget.toggleScreenRec();
        }
    }

    // Format time helper
    function formatTime(sec) {
        var s = Math.floor(sec % 60);
        var m = Math.floor(sec / 60);
        return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s);
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 15

        // Animated Icon
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 60
            Layout.preferredHeight: 60

            Rectangle {
                anchors.centerIn: parent
                width: 50
                height: 50
                radius: 25
                color: "transparent"
                border.width: 2
                border.color: rootWidget.screenRecState === "paused" ? Qt.rgba(0.95, 0.65, 0.15, 0.3) : Qt.rgba(0.94, 0.22, 0.22, 0.3)

                SequentialAnimation on scale {
                    running: rootWidget.screenRecState === "recording"
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 1.4; duration: 1000; easing.type: Easing.OutQuad }
                    NumberAnimation { from: 1.4; to: 1.0; duration: 1000; easing.type: Easing.InQuad }
                }
                SequentialAnimation on opacity {
                    running: rootWidget.screenRecState === "recording"
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.8; to: 0.0; duration: 1000; easing.type: Easing.OutQuad }
                    NumberAnimation { from: 0.0; to: 0.8; duration: 1000; easing.type: Easing.InQuad }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 34
                height: 34
                radius: 17
                color: rootWidget.screenRecState === "paused" ? Qt.rgba(0.95, 0.65, 0.15, 0.2) : Qt.rgba(0.94, 0.22, 0.22, 0.2)
                
                SequentialAnimation on scale {
                    running: rootWidget.screenRecState === "recording"
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 1.2; duration: 1000; easing.type: Easing.OutQuad }
                    NumberAnimation { from: 1.2; to: 1.0; duration: 1000; easing.type: Easing.InQuad }
                }
            }

            Rectangle {
                id: coreDot
                anchors.centerIn: parent
                width: 18
                height: 18
                radius: 9
                color: rootWidget.screenRecState === "paused" ? Qt.rgba(0.95, 0.65, 0.15, 1) : "#f03838"
            }
        }

        // Labels
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 2

            Text {
                text: rootWidget.screenRecState === "paused" ? "PAUSED" : "RECORDING"
                color: rootWidget.screenRecState === "paused" ? Qt.rgba(0.95, 0.65, 0.15, 1) : "#f03838"
                font.family: "JetBrains Mono"
                font.pixelSize: 12
                font.letterSpacing: 4
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: formatTime(rootWidget.screenRecElapsed)
                color: rootWidget.walColors ? rootWidget.walColors.special.foreground : "#ffffff"
                font.family: "JetBrains Mono"
                font.pixelSize: 42
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignHCenter
            }
        }

        Item { Layout.fillHeight: true } // Spacer

        // Buttons
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 15

            Rectangle {
                Layout.preferredWidth: 140
                Layout.preferredHeight: 40
                radius: 20
                color: pauseMa.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.1)

                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        text: rootWidget.screenRecState === "paused" ? "" : ""
                        color: rootWidget.walColors ? rootWidget.walColors.special.foreground : "#ffffff"
                        font.pixelSize: 14
                    }
                    Text {
                        text: rootWidget.screenRecState === "paused" ? "Resume" : "Pause"
                        color: rootWidget.walColors ? rootWidget.walColors.special.foreground : "#ffffff"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }
                }

                MouseArea {
                    id: pauseMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (rootWidget.screenRecState === "recording")
                            rootWidget.screenRecRunCtl("pause");
                        else if (rootWidget.screenRecState === "paused")
                            rootWidget.screenRecRunCtl("resume");
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 140
                Layout.preferredHeight: 40
                radius: 20
                color: stopMa.containsMouse ? Qt.rgba(0.94, 0.22, 0.22, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                border.color: stopMa.containsMouse ? Qt.rgba(0.94, 0.22, 0.22, 0.5) : Qt.rgba(1, 1, 1, 0.1)

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        text: ""
                        color: stopMa.containsMouse ? "#f03838" : (rootWidget.walColors ? rootWidget.walColors.special.foreground : "#ffffff")
                        font.pixelSize: 14
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Text {
                        text: "Stop"
                        color: stopMa.containsMouse ? "#f03838" : (rootWidget.walColors ? rootWidget.walColors.special.foreground : "#ffffff")
                        font.family: "JetBrains Mono"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                MouseArea {
                    id: stopMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        rootWidget.screenRecRunCtl("stop");
                        rootWidget.toggleScreenRec();
                    }
                }
            }
        }
    }
}
