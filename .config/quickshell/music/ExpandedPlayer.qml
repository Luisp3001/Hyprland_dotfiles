import QtQuick
import QtQuick.Layouts

Item {
    id: expandedPlayer
    property var rootWidget

    Connections {
        target: rootWidget
        function onDetailExpandedChanged() {
            if (rootWidget.detailExpanded) {
                showDetail.start();
            }
            // Close fade is handled by toggleDetail() directly
        }
    }

    Timer {
        id: showDetail
        interval: 250
        onTriggered: rootWidget.detailOpacity.value = 1.0
    }

    // ── Album art + track info ────────────────────────────
    RowLayout {
        id: albumRow
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        spacing: 14
        height: 80

        // Album art
        Rectangle {
            id: artContainer
            Layout.preferredWidth: 80
            Layout.preferredHeight: 80
            radius: 12
            color: "#2a2d3a"
            clip: true

            Image {
                id: albumArt
                anchors.fill: parent
                source: rootWidget.hasSpotify ? rootWidget.spotifyPlayer.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                smooth: true
                asynchronous: true
            }

            // Rounded corner overlay mask
            Rectangle {
                anchors.fill: parent
                radius: 12
                color: "transparent"
                border.color: "#3d4150"
                border.width: 1
            }

            // Fallback icon when no art
            Text {
                anchors.centerIn: parent
                text: "♪"
                color: rootWidget.walColors.special.foreground
                font.pixelSize: 28
                opacity: albumArt.status !== Image.Ready ? 0.4 : 0.0
                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }
            }
        }

        // Track details (vertically stacked)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 4

            Text {
                text: rootWidget.hasSpotify ? (rootWidget.spotifyPlayer.trackTitle || "Unknown") : "Nothing playing"
                color: rootWidget.walColors.special.foreground
                font.family: "JetBrains Mono"
                font.pixelSize: 14
                font.weight: Font.Bold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: rootWidget.hasSpotify ? (rootWidget.spotifyPlayer.trackArtist || "Unknown") : "Start playing some music"
                color: rootWidget.walColors.special.foreground
                font.family: "JetBrains Mono"
                font.pixelSize: 11
                font.weight: Font.Normal
                opacity: 0.65
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: rootWidget.hasSpotify ? (rootWidget.spotifyPlayer.trackAlbum || "") : ""
                color: rootWidget.walColors.special.foreground
                font.family: "JetBrains Mono"
                font.pixelSize: 10
                font.weight: Font.Normal
                opacity: 0.45
                elide: Text.ElideRight
                Layout.fillWidth: true
                visible: text !== ""
            }
        }
    }

    // ── Progress bar ──────────────────────────────────────
    ColumnLayout {
        id: progressSection
        anchors {
            top: albumRow.bottom
            topMargin: 14
            left: parent.left
            right: parent.right
        }
        spacing: 5

        // Seek bar
        Item {
            Layout.fillWidth: true
            height: 6

            // Track background
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.1)
            }

            // Filled portion
            Rectangle {
                id: progressBar
                anchors {
                    left:   parent.left
                    top:    parent.top
                    bottom: parent.bottom
                }
                radius: height / 2

                property real ratio: rootWidget.trackLength > 0 ? Math.min(1.0, rootWidget.trackPosition / rootWidget.trackLength) : 0

                width: Math.max(radius * 2, parent.width * ratio)

                Behavior on width {
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                }

                color: rootWidget.walColors.colors.color2

                // Glowing dot at end
                Rectangle {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        rightMargin: -4
                    }
                    width: 10
                    height: 10
                    radius: 5
                    color: rootWidget.walColors.colors.color2
                    visible: progressBar.ratio > 0.01

                    // Subtle glow
                    Rectangle {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        radius: 8
                        color: "transparent"
                        border.color: Qt.rgba(rootWidget.walColors.colors.color2.r, rootWidget.walColors.colors.color2.g, rootWidget.walColors.colors.color2.b, 0.3)
                        border.width: 2
                    }
                }
            }

            // Seek click area
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                onClicked: function(mouse) {
                    if (!rootWidget.hasSpotify || rootWidget.trackLength <= 0) return;
                    var ratio = Math.max(0, Math.min(1, mouse.x / parent.width));
                    rootWidget.spotifyPlayer.position = ratio * rootWidget.trackLength;
                    rootWidget.trackPosition = ratio * rootWidget.trackLength;
                }
            }
        }

        // Timestamps
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: rootWidget.formatTime(rootWidget.trackPosition)
                color: rootWidget.walColors.special.foreground
                font.family: "JetBrains Mono"
                font.pixelSize: 10
                opacity: 0.6
            }

            Item { Layout.fillWidth: true }

            Text {
                text: rootWidget.trackLength > 0 ? rootWidget.formatTime(rootWidget.trackLength) : "--:--"
                color: rootWidget.walColors.special.foreground
                font.family: "JetBrains Mono"
                font.pixelSize: 10
                opacity: 0.6
            }
        }
    }

    // ── Controls row: 🔀 ⏮ ⏸ ⏭ 🔁 ──────────────────────
    RowLayout {
        z: 5
        anchors {
            top: progressSection.bottom
            topMargin: 8
            horizontalCenter: parent.horizontalCenter
        }
        spacing: 14
        visible: rootWidget.hasSpotify

        // Previous
        ControlButton {
            icon: ""
            onClicked: { if (rootWidget.hasSpotify) rootWidget.spotifyPlayer.previous() }
        }

        // Play / Pause
        ControlButton {
            icon: rootWidget.isPlaying ? "" : ""
            highlighted: rootWidget.isPlaying
            onClicked: {
                if (!rootWidget.hasSpotify) return;
                if (rootWidget.isPlaying)
                    rootWidget.spotifyPlayer.pause();
                else
                    rootWidget.spotifyPlayer.play();
            }
        }

        // Next
        ControlButton {
            icon: ""
            onClicked: { if (rootWidget.hasSpotify) rootWidget.spotifyPlayer.next() }
        }
    }
}
