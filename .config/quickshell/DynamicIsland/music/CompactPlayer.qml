import QtQuick
import QtQuick.Layouts

RowLayout {
    id: compactPlayer
    property var rootWidget

    property alias showNote: showNote
    property alias showText: showText
    property alias showControls: showControls
    property alias hideNote: hideNote
    property alias hideText: hideText
    property alias hideControls: hideControls

    property bool isTransitioning: false

    Timer {
        id: transitionTimer
        interval: 700 // Slightly longer than width transition (600ms)
        onTriggered: isTransitioning = false
    }

    spacing: 18
    visible: !rootWidget.notificationVisible && !rootWidget.launcherOpen && (noteOpacity.value > 0 || textOpacity.value > 0 || controlsOpacity.value > 0)

    QtObject {
        id: noteOpacity
        property real value: 0.0
        Behavior on value { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }
    }
    QtObject {
        id: textOpacity
        property real value: 0.0
        Behavior on value { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }
    }
    QtObject {
        id: controlsOpacity
        property real value: 0.0
        Behavior on value { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }
    }

    Timer { id: showNote;     interval: 200; onTriggered: noteOpacity.value = 1.0 }
    Timer { id: showText;     interval: 350; onTriggered: textOpacity.value = 1.0 }
    Timer { id: showControls; interval: 500; onTriggered: controlsOpacity.value = 1.0 }

    Timer { id: hideControls; interval: 0;   onTriggered: controlsOpacity.value = 0.0 }
    Timer { id: hideText;     interval: 20;  onTriggered: textOpacity.value = 0.0 }
    Timer { id: hideNote;     interval: 40; onTriggered: noteOpacity.value = 0.0 }

    Connections {
        target: rootWidget
        function onExpandedChanged() {
            if (rootWidget.expanded) {
                showNote.start();
                showText.start();
                showControls.start();
            } else {
                hideControls.start();
                hideText.start();
                hideNote.start();
            }
        }

        function onDetailExpandedChanged() {
            isTransitioning = true;
            transitionTimer.restart();
            scrollAnim.stop();
            trackLabel.x = 0;
        }

        function onNotificationVisibleChanged() {
            isTransitioning = true;
            transitionTimer.restart();
            scrollAnim.stop();
            trackLabel.x = 0;
        }

        function onLauncherOpenChanged() {
            isTransitioning = true;
            transitionTimer.restart();
            scrollAnim.stop();
            trackLabel.x = 0;
        }

        function onAirdropOpenChanged() {
            isTransitioning = true;
            transitionTimer.restart();
            scrollAnim.stop();
            trackLabel.x = 0;
        }

        function onOverviewOpenChanged() {
            isTransitioning = true;
            transitionTimer.restart();
            scrollAnim.stop();
            trackLabel.x = 0;
        }
         
        function onScreenRecOpenChanged() {
            isTransitioning = true;
            transitionTimer.restart();
            scrollAnim.stop();
            trackLabel.x = 0;
        }
    }

    // Music note + track info
    RowLayout {
        spacing: 10
        Layout.alignment: Qt.AlignVCenter
        Layout.fillWidth: true

        Text {
            text: "♪"
            color: rootWidget.walColors.special.foreground
            font.pixelSize: 17
            opacity: noteOpacity.value
            Layout.alignment: Qt.AlignVCenter

            SequentialAnimation on scale {
                id: noteBounce
                running: false
                NumberAnimation { to: 1.4; duration: 150; easing.type: Easing.OutQuad }
                NumberAnimation { to: 1.0; duration: 250; easing.type: Easing.OutBounce }
            }
        }

        Item {
            id: marqueeContainer
            property bool needsScroll: trackLabel.implicitWidth > width

            Layout.fillWidth: true
            Layout.preferredHeight: trackLabel.implicitHeight
            Layout.alignment: Qt.AlignVCenter
            opacity: textOpacity.value
            clip: true

            Text {
                id: trackLabel
                y: 0
                text: {
                    if (!rootWidget.hasSpotify) return "Nothing playing";
                    var artist = rootWidget.spotifyPlayer.trackArtist || "Unknown";
                    var title  = rootWidget.spotifyPlayer.trackTitle  || "Unknown";
                    return artist + "  —  " + title;
                }
                color: rootWidget.walColors.special.foreground
                font.family: "JetBrains Mono"
                font.pixelSize: 13
                font.weight: Font.Medium

                onTextChanged: {
                    scrollAnim.stop();
                    trackLabel.x = 0;
                    noteBounce.start();
                    if (marqueeContainer.needsScroll)
                        scrollAnim.start();
                }
            }

            SequentialAnimation {
                id: scrollAnim
                running: marqueeContainer.needsScroll && rootWidget.expanded && !isTransitioning
                loops: Animation.Infinite

                PauseAnimation { duration: 2000 }
                NumberAnimation {
                    target: trackLabel
                    property: "x"
                    from: 0
                    to: -(trackLabel.implicitWidth - marqueeContainer.width)
                    duration: trackLabel.implicitWidth * 18
                    easing.type: Easing.Linear
                }
                PauseAnimation { duration: 2000 }
                NumberAnimation {
                    target: trackLabel
                    property: "x"
                    from: -(trackLabel.implicitWidth - marqueeContainer.width)
                    to: 0
                    duration: trackLabel.implicitWidth * 18
                    easing.type: Easing.Linear
                }
            }
        }
    }

    // Playback controls (hidden when expanded — they move to bottom)
    RowLayout {
        z: 5
        spacing: 6
        Layout.alignment: Qt.AlignVCenter
        opacity: rootWidget.detailExpanded ? 0.0 : controlsOpacity.value
        visible: opacity > 0 && rootWidget.hasSpotify

        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
        }

        ControlButton {
            icon: ""
            onClicked: { if (rootWidget.hasSpotify) rootWidget.spotifyPlayer.previous() }
        }

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

        ControlButton {
            icon: ""
            onClicked: { if (rootWidget.hasSpotify) rootWidget.spotifyPlayer.next() }
        }
    }
}
