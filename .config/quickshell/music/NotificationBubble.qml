import "../notificationcenter"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Rectangle {
    id: root

    property var walColors: null
    property bool active: false
    property bool centerOpen: false
    property var server: null
    property var historyModel: null
    property bool dndEnabled: false

    signal clicked()

    antialiasing: true
    clip: true
    layer.enabled: true
    // Morph dimensions: from 45x45 bell → 340x620 vertical panel
    width: centerOpen ? 480 : 45
    height: centerOpen ? 600 : 45
    radius: centerOpen ? 22 : 300 // Use a high fixed radius during close for aggressive rounding
    color: walColors ? (centerOpen ? Qt.rgba(20/255, 20/255, 22/255, 1) : walColors.special.background) : "#1c1e26"
    border.color: active || centerOpen ? Qt.alpha(walColors.colors.color3, 0.5) : "#3d4150"
    border.width: centerOpen ? 1.5 : 1
    opacity: 0
    scale: 0.8
    states: [
        State {
            name: "visible"

            PropertyChanges {
                target: root
                opacity: 1
                scale: 1
            }

        }
    ]

    // Subtle gradient overlay for glass depth when expanded
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        visible: root.centerOpen
        opacity: root.centerOpen ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }

        }

        gradient: Gradient {
            orientation: Gradient.Vertical

            GradientStop {
                position: 0
                color: Qt.rgba(1, 1, 1, 0.04)
            }

            GradientStop {
                position: 0.3
                color: "transparent"
            }

            GradientStop {
                position: 1
                color: Qt.rgba(0, 0, 0, 0.08)
            }

        }

    }

    // MouseArea covering the background to block events when center is open
    MouseArea {
        id: bgMouseArea

        anchors.fill: parent
        enabled: root.centerOpen
        onClicked: {
        } // absorb clicks so they don't click anything underneath
    }

    // ── Normal Bell Icon state ────────────────────────────────────────
    Item {
        anchors.fill: parent
        opacity: root.centerOpen ? 0 : 1
        visible: opacity > 0

        MouseArea {
            id: bellMouseArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
            enabled: !root.centerOpen
            acceptedButtons: Qt.LeftButton
        }

        Image {
            id: bellIcon

            source: {
                if (root.dndEnabled) return "../assets/icons/bell_dnd.svg";
                if (root.historyModel && root.historyModel.model.count > 0) return "../assets/icons/new_notification.svg";
                return "../assets/icons/bell.svg";
            }
            anchors.centerIn: parent
            sourceSize: Qt.size(20, 20)
            visible: false
        }

        ColorOverlay {
            anchors.fill: bellIcon
            source: bellIcon
            color: bellMouseArea.containsMouse ? root.walColors.colors.color2 : root.walColors.special.foreground
            opacity: bellMouseArea.containsMouse ? 1 : 0.7

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }

            }

        }

        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation {
                    duration: root.centerOpen ? 0 : 200
                }

                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutQuad
                }

            }

        }

    }

    // ── Expanded Notification Center (vertical layout) ────────────────
    Item {
        id: expandedState

        // Sub-components
        property var history: root.historyModel

        // Clock
        property string _clockTime: Qt.formatTime(new Date(), "hh:mm")
        property string _clockDate: Qt.formatDate(new Date(), "dddd, MMMM d")

        width: parent.width - 20
        height: parent.height - 20
        anchors.centerIn: parent
        opacity: root.centerOpen ? 0.8 : 0
        visible: root.centerOpen ? true : false
        clip: true
        Timer {
            interval: 1000
            running: root.centerOpen
            repeat: true
            onTriggered: {
                expandedState._clockTime = Qt.formatTime(new Date(), "hh:mm");
                expandedState._clockDate = Qt.formatDate(new Date(), "dddd, MMMM d");
            }
        }

        ColumnLayout {
            id: verticalLayout

            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            // ── Row 1: Clock time + Clear All ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: expandedState._clockTime
                    color: root.walColors.special.foreground
                    font.family: "JetBrains Mono"
                    font.pixelSize: 32
                    font.weight: Font.Bold
                }

            }

            // ── Row 2: Date + Close button ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: expandedState._clockDate
                    color: root.walColors.special.foreground
                    font.family: "JetBrains Mono"
                    font.pixelSize: 16
                    opacity: 1
                }

            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            // ── Quick Actions grid + sliders ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: quickActionsInner.implicitHeight + 24
                radius: 16
                color: Qt.rgba(1, 1, 1, 0.04)
                border.color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1

                QuickActions {
                    id: quickActionsInner
                    active: root.centerOpen
                    dndEnabled: root.dndEnabled
                    anchors.centerIn: parent
                    width: parent.width - 16
                    walColors: root.walColors
                    onDndEnabledChanged: root.dndEnabled = quickActionsInner.dndEnabled
                }
            }



            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "NOTIFICATIONS"
                    color: root.walColors.special.foreground
                    font.family: "JetBrains Mono"
                    font.pixelSize: 13 // Increased font
                    font.weight: Font.Bold
                    opacity: 1
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: "Clear all"
                    color: root.walColors.colors.color2
                    font.family: "JetBrains Mono"
                    font.pixelSize: 13 // Increased font
                    opacity: expandedState.history.model.count > 0 ? 1 : 0.3

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: expandedState.history.clearAll()
                        enabled: expandedState.history.model.count > 0
                    }

                }

            }

            // ── Notification list ──
            ListView {
                id: notifList

                Layout.fillWidth: true
                Layout.fillHeight: true // Priority to take remaining space
                model: expandedState.history.model
                spacing: 6
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Text {
                    anchors.centerIn: parent
                    text: "No Notifications"
                    color: root.walColors.special.foreground
                    font.family: "JetBrains Mono"
                    font.pixelSize: 12
                    opacity: 0.25
                    visible: notifList.count === 0
                }

                delegate: Rectangle {
                    width: notifList.width
                    height: 64 // Increased height
                    radius: 12
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10 // Increased margins
                        spacing: 12 // Increased spacing

                        Rectangle {
                            width: 36
                            height: 36
                            radius: 8
                            color: Qt.rgba(1, 1, 1, 0.08)

                            Image {
                                anchors.fill: parent
                                anchors.margins: 4
                                source: image || ""
                                fillMode: Image.PreserveAspectFit
                                visible: status === Image.Ready
                                smooth: true
                            }

                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 2 // Increased spacing
                            clip: true

                            Text {
                                text: summary || "(no title)"
                                color: root.walColors.special.foreground
                                font.family: "JetBrains Mono"
                                font.pixelSize: 13 // Increased font
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                clip: true
                                Layout.fillWidth: true
                            }

                            Text {
                                text: body || ""
                                color: root.walColors.special.foreground
                                font.family: "JetBrains Mono"
                                font.pixelSize: 11 // Increased font
                                opacity: 1
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                clip: true
                                Layout.fillWidth: true
                            }

                        }

                        MouseArea {
                            width: 20
                            height: 20
                            cursorShape: Qt.PointingHandCursor
                            onClicked: expandedState.history.removeAt(index)

                            Text {
                                text: "✕"
                                color: root.walColors.special.foreground
                                anchors.centerIn: parent
                                font.pixelSize: 12
                                opacity: 1
                            }

                        }

                    }

                }

            }

        }

        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation {
                    duration: root.centerOpen ? 350 : 0
                }

                NumberAnimation {
                    duration: root.centerOpen ? 250 : 300
                    easing.type: Easing.OutQuad
                }

            }

        }

    }

    Behavior on width {
        NumberAnimation {
            duration: 600
            easing.type: Easing.OutExpo
        }

    }

    Behavior on height {
        NumberAnimation {
            duration: 600
            easing.type: Easing.OutExpo
        }

    }

    Behavior on radius {
        NumberAnimation {
            duration: 600
            easing.type: Easing.OutExpo
        }

    }

    Behavior on color {
        ColorAnimation {
            duration: 400
        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }

    }

    Behavior on scale {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutExpo
        }

    }

}
