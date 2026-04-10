import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts

// PowerProfileMenu – A sub-menu to select the system's power profile
Item {
    id: root

    required property var walColors
    property string currentProfile: "balanced" // "performance" | "balanced" | "power-saver"

    signal backClicked()
    signal profileSelected(string profile)

    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 12

        // ── Header (Back Button) ──────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MouseArea {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: "<"
                    color: root.walColors.special.foreground
                    font.family: "JetBrains Mono"
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    opacity: 0.7
                }

                onClicked: root.backClicked()
            }

            Text {
                Layout.fillWidth: true
                text: "Power Mode"
                color: root.walColors.special.foreground
                font.family: "JetBrains Mono"
                font.pixelSize: 14 // Reduced font to fit nicely
                font.weight: Font.Bold
                opacity: 0.9
            }
        }

        // ── Separator ─────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        // ── Profile Options List ──────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            ProfileOption {
                Layout.fillWidth: true
                profileId: "performance"
                label: "Performance"
                icon: "../assets/icons/performance.svg"
                walColors: root.walColors
                isActive: root.currentProfile === profileId
                onSelected: root.profileSelected(profileId)
            }

            ProfileOption {
                Layout.fillWidth: true
                profileId: "balanced"
                label: "Balanced"
                icon: "../assets/icons/balanced.svg"
                walColors: root.walColors
                isActive: root.currentProfile === profileId
                onSelected: root.profileSelected(profileId)
            }

            ProfileOption {
                Layout.fillWidth: true
                profileId: "power-saver"
                label: "Power Saver"
                icon: "../assets/icons/powersave.svg"
                walColors: root.walColors
                isActive: root.currentProfile === profileId
                onSelected: root.profileSelected(profileId)
            }
        }
    }

    // ── Component for an option item ──────────────────────────────────────
    component ProfileOption: Rectangle {
        id: optBox
        property string profileId: ""
        property string label: ""
        property string icon: ""
        property bool isActive: false
        property var walColors
        
        signal selected()

        height: 48
        radius: 12
        color: isActive ? Qt.rgba(walColors.colors.color2.r, walColors.colors.color2.g, walColors.colors.color2.b, 0.15) : Qt.rgba(1, 1, 1, 0.03)
        border.color: isActive ? walColors.colors.color2 : Qt.rgba(1, 1, 1, 0.05)
        border.width: 1

        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Image {
                id: pIcon
                source: optBox.icon
                sourceSize: Qt.size(20, 20)
                visible: false
            }

            ColorOverlay {
                Layout.preferredWidth: 20; Layout.preferredHeight: 20
                source: pIcon
                color: optBox.walColors.special.foreground
                opacity: 0.8
            }

            Text {
                Layout.fillWidth: true
                text: optBox.label
                color: optBox.walColors.special.foreground
                font.family: "JetBrains Mono"
                font.pixelSize: 12
                opacity: 0.8
            }

            // Radio dot indicator
            Rectangle {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                radius: 8
                color: "transparent"
                border.color: optBox.isActive ? optBox.walColors.colors.color2 : Qt.rgba(1, 1, 1, 0.3)
                border.width: 2

                Rectangle {
                    anchors.centerIn: parent
                    width: 8; height: 8
                    radius: 4
                    color: optBox.walColors.colors.color2
                    visible: optBox.isActive
                    scale: optBox.isActive ? 1 : 0
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: optBox.selected()

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }
    }
}
