import "../notificationcenter"
import "../components" as Lib
import "../notificationcenter" as Hub
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
    // Morph dimensions: from 45x45 bell → 380x740 vertical panel
    width: centerOpen ? 400 : 45
    height: centerOpen ? 670 : 45
    radius: centerOpen ? 22 : 300 // Use a high fixed radius during close for aggressive rounding
    color: walColors ? walColors.special.background : "#1c1e26"
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
            cache: false
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

        property var theme: Lib.ThemeEngine {
            isDarkMode: true
            walColors: root.walColors
        }
        property bool batteryCardActive: false
        property bool wifiMenuOpen: false
        
        onVisibleChanged: {
            if (!visible) wifiMenuOpen = false
        }
        
        width: parent.width - 24
        height: parent.height - 24
        anchors.centerIn: parent
        opacity: root.centerOpen ? 1 : 0
        visible: root.centerOpen
        clip: true

        Item {
            anchors.fill: parent

            ColumnLayout {
                id: verticalLayout
                visible: !expandedState.wifiMenuOpen
            anchors.fill: parent
            anchors.margins: 4
            spacing: expandedState.theme.gapCard

            // ── Header (Profile + CPU/RAM + Power) ──
            Hub.Header {
                id: header
                theme: expandedState.theme
                Layout.fillWidth: true
                profileName: "luisp"
                profileImage: Quickshell.env("HOME") + "/.face.icon"
                active: root.centerOpen
                onCloseRequested: root.clicked()

                onPowerAction: function(act, lbl) {
                    header.expanded = false
                    expandedState.executeAction(act)
                }
            }

            // ── Buttons & Sliders (WiFi, BT, CPU, DND + Vol/Bri) ──
            Hub.ButtonsSlidersCard {
                id: buttons
                Layout.fillWidth: true
                active: root.centerOpen
                theme: expandedState.theme
                onCloseRequested: root.clicked()
                onBatteryToggleRequested: expandedState.batteryCardActive = !expandedState.batteryCardActive
                onWifiMenuRequested: expandedState.wifiMenuOpen = true
            }

            // ── Battery Health (expandable) ──
            Hub.BatteryHealthCard {
                id: battery
                Layout.fillWidth: true
                active: expandedState.batteryCardActive
                theme: expandedState.theme
            }

            Hub.MediaCard {
                id: mediaCard
                Layout.fillWidth: true;
                forceHidden: notifs.expanded && notifs.compactMode
            }


            // ── Calendar & Weather ──
            Hub.CalendarWeatherCard {
                Layout.fillWidth: true
                active: root.centerOpen
                theme: expandedState.theme
                onCloseRequested: root.clicked()
            }

            // ── Notifications (Quickshell History) ──
            Hub.NotificationsCard {
                id: notifs
                Layout.fillWidth: true
                active: root.centerOpen
                compactMode: battery.visible || header.expanded || mediaCard.wouldBeActive
                dndActive: buttons.dnd
                theme: expandedState.theme
                historyModel: root.historyModel
            }
            }
        
            Lib.WifiMenu {
                id: wifiMenu
                visible: expandedState.wifiMenuOpen
                anchors.fill: parent
                theme: expandedState.theme
                walColors: root.walColors
                onCloseRequested: expandedState.wifiMenuOpen = false
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
