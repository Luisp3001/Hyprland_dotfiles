import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland

// MusicWidget – standalone component (no ShellRoot).
Item {
    // ── UI CONTENT ───────────────────────────────────────────────────

    id: root

    property var spotifyPlayer: _detectedSpotify
    property bool hasSpotify: spotifyPlayer !== null
    property bool isPlaying: hasSpotify && spotifyPlayer.playbackState === MprisPlaybackState.Playing
    // Dynamic Island state
    property bool expanded: true
    // Expanded detail view (click to toggle)
    property bool detailExpanded: false
    // ── Notification system ────────────────────────────────────────────
    required property var notifHandler
    property var server: null
    property var historyModel: null
    property bool notifCenterVisible: false
    property var onToggleNotifCenter: null
    property bool notificationVisible: false
    property int verticalPadding: 8
    // Opacity controller for notification content
    property var notifOpacity
    // Sequenced collapse: fade out content first, THEN shrink pill
    property var collapseSequencer
    // Timer to show notification after music content fades
    property var notifShowTimer
    // Timer to fade in notification content after pill expands
    property var notifFadeInTimer
    // Timer to restore music content after notification dismissed
    property var notifRestoreTimer
    property var notifHandlerConnections
    property var notifHideTimer
    // ── Volume Island ──────────────────────────────────────────────────
    property real currentVolume: 0.5
    property bool isMuted: false
    property bool volumeVisible: false
    // ── Position tracking ──────────────────────────────────────────────
    property real trackPosition: 0
    property real trackLength: 0
    property var positionPoller
    property var walColors: null
    // ── Spotify detection (Reactive) ───────────────────────────────────
    property var _allPlayers: Mpris.players.values
    property var _detectedSpotify: {
        for (var i = 0; i < _allPlayers.length; i++) {
            var p = _allPlayers[i];
            if (p.identity && p.identity.toLowerCase().includes("spotify"))
                return p;

        }
        return null;
    }
    // ── Volume polling via wpctl ───────────────────────────────────────
    property var volProcess
    property var volPoll
    property var volumeHideTimer
    // ── Detail opacity (referenced from visual tree) ──────────────────
    property var detailOpacity
    // Performance Fix: Use a stable width (440px) to avoid horizontal window jumps.
    // However, height remains dynamic to release screen real estate and fix click-through.
    property real targetImplicitHeight: {
        if (root.notifCenterVisible)
            return 620;

        var h = pill.targetHeight;
        if (root.volumeVisible)
            h += volumePill.totalHeight;

        return h + root.verticalPadding + 15;
    }
    property real currentImplicitHeight: targetImplicitHeight

    function toggleDetail() {
        if (!root.hasSpotify)
            return ;

        if (root.notificationVisible)
            return ;

        // Block while notification showing
        if (root.detailExpanded) {
            // Step 1: fade out detail content immediately
            detailOpacity.value = 0;
            // Step 2: after content fades, shrink the pill
            collapseSequencer.start();
        } else {
            root.detailExpanded = true;
            root.trackPosition = root.spotifyPlayer.position;
            root.trackLength = root.spotifyPlayer.length;
        }
    }

    function formatTime(seconds) {
        var s = Math.floor(seconds);
        var m = Math.floor(s / 60);
        s = s % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    on_DetectedSpotifyChanged: {
        if (_detectedSpotify) {
            spotifyPlayer = _detectedSpotify;
            if (!expanded)
                expanded = true;

        } else {
            // Keep expanded = true to stay visible
            // We set spotifyPlayer to null to trigger placeholders
            spotifyPlayer = null;
        }
    }
    Component.onCompleted: {
        expanded = true;
        // Ensure content shows up on startup
        row.showNote.start();
        row.showText.start();
        row.showControls.start();
    }
    implicitWidth: 500
    implicitHeight: currentImplicitHeight
    onTargetImplicitHeightChanged: {
        if (targetImplicitHeight > currentImplicitHeight)
            currentImplicitHeight = targetImplicitHeight; // Expand instantly

        shrinkTimer.restart();
    }

    Timer {
        id: shrinkTimer

        interval: 650
        onTriggered: {
            root.currentImplicitHeight = root.targetImplicitHeight;
        }
    }

    // ── Music pill ────────────────────────────────────────────────
    Rectangle {
        id: pill

        z: 1
        property real compactWidth: 370
        property real expandedWidth: 400
        property real notifWidth: 430
        property real notifHeight: {
            if (!root.notificationVisible)
                return 90;

            // Calculate height based on content
            return Math.min(300, Math.max(90, notifContent.notifColumn.implicitHeight + 30));
        }
        property real targetWidth: root.notificationVisible ? notifWidth : (root.detailExpanded ? expandedWidth : compactWidth)
        property real targetHeight: root.notificationVisible ? notifHeight : (root.detailExpanded ? 230 : 45)

        antialiasing: true
        clip: true
        layer.enabled: true
        width: targetWidth
        height: targetHeight
        radius: (root.detailExpanded || root.notificationVisible) ? 22 : height / 2
        color: root.walColors.special.background
        border.color: root.expanded ? "#3d4150" : "transparent"
        border.width: 1
        opacity: {
            if (root.notifCenterVisible)
                return 0;

            return (root.expanded || root.notificationVisible) ? 1 : 0;
        }
        scale: root.notifCenterVisible ? 0.9 : 1

        anchors {
            top: parent.top
            topMargin: root.verticalPadding
            horizontalCenter: parent.horizontalCenter
            horizontalCenterOffset: 0
        }

        // Click to toggle expanded view / dismiss notification
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (root.notificationVisible) {
                    var invoked = false;
                    for (var i = 0; i < root.notifHandler.actions.length; i++) {
                        var action = root.notifHandler.actions[i];
                        if ((action.identifier && action.identifier === "default") || action.id === "default") {
                            if (action.invoke)
                                action.invoke();

                            invoked = true;
                            break;
                        }
                    }
                    root.notifHandler.dismiss();
                } else {
                    root.toggleDetail();
                }
            }
        }

        // ── Compact content (top row) ─────────────────────────────
        CompactPlayer {
            id: row

            rootWidget: root

            anchors {
                top: parent.top
                topMargin: root.detailExpanded ? 10 : 0
                left: parent.left
                right: parent.right
                leftMargin: 20
                rightMargin: 20
                verticalCenter: root.detailExpanded ? undefined : parent.verticalCenter
            }

        }

        // ── Expanded detail content ───────────────────────────────
        ExpandedPlayer {
            id: detailContent

            rootWidget: root
            visible: root.detailOpacity.value > 0
            opacity: root.detailOpacity.value

            anchors {
                top: row.bottom
                topMargin: 12
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                leftMargin: 18
                rightMargin: 18
                bottomMargin: 14
            }

        }

        // ── Notification content ──────────────────────────────────
        NotificationContent {
            id: notifContent

            rootWidget: root
            visible: root.notifOpacity.value > 0
            opacity: root.notifOpacity.value

            anchors {
                fill: parent
                leftMargin: 22
                rightMargin: 22
                topMargin: 12
                bottomMargin: 12
            }

        }

        Behavior on anchors.horizontalCenterOffset {
            NumberAnimation {
                duration: 500
                easing.type: Easing.OutQuint
            }

        }

        Behavior on width {
            NumberAnimation {
                duration: 600
                easing.type: Easing.InOutQuint
            }

        }

        Behavior on height {
            NumberAnimation {
                duration: 600
                easing.type: Easing.InOutQuint
            }

        }

        Behavior on radius {
            NumberAnimation {
                duration: 600
                easing.type: Easing.InOutQuint
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: 250
                easing.type: Easing.InOutQuad
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: 300
                easing.type: Easing.InOutQuad
            }

        }

        Behavior on border.color {
            ColorAnimation {
                duration: 200
            }

        }

    }

    // ── Notification bubble (bell/center) ─────────────────────────
    NotificationBubble {
        id: notifBubble

        z: root.notifCenterVisible ? 100 : 0
        server: root.server
        historyModel: root.historyModel
        walColors: root.walColors
        centerOpen: root.notifCenterVisible
        state: (!root.notificationVisible && (root.notifCenterVisible || (root.expanded && !root.detailExpanded))) ? "visible" : ""
        visible: state === "visible" || opacity > 0
        onClicked: {
            if (root.onToggleNotifCenter)
                root.onToggleNotifCenter();

        }

        anchors {
            top: pill.top
            horizontalCenter: parent.horizontalCenter
            horizontalCenterOffset: {
                if (root.notifCenterVisible)
                    return 0;

                var showBubble = (!root.notificationVisible && (root.expanded && !root.detailExpanded));
                if (showBubble)
                    return 212.5;

                // When hiding, move inwards to slide "behind/into" the expanding pill
                return 150;
            }
        }

        Behavior on anchors.horizontalCenterOffset {
            NumberAnimation {
                duration: 500
                easing.type: Easing.OutQuint
            }

        }

    }

    // ── Volume Dynamic Island ─────────────────────────────────────
    VolumeIsland {
        id: volumePill

        rootWidget: root

        anchors {
            top: pill.bottom
            topMargin: volumePill.gapHeight
            horizontalCenter: parent.horizontalCenter
        }

    }

    notifOpacity: QtObject {
        property real value: 0

        Behavior on value {
            SequentialAnimation {
                // Delay fade-in until pill has grown a bit
                PauseAnimation {
                    duration: 150
                }

                NumberAnimation {
                    duration: 300
                    easing.type: Easing.InOutQuad
                }

            }

        }

    }

    collapseSequencer: Timer {
        interval: 350
        onTriggered: {
            root.detailExpanded = false;
        }
    }

    notifShowTimer: Timer {
        interval: 400
        onTriggered: {
            root.notificationVisible = true;
            notifFadeInTimer.start();
        }
    }

    notifFadeInTimer: Timer {
        interval: 250
        onTriggered: root.notifOpacity.value = 1
    }

    notifRestoreTimer: Timer {
        interval: 500
        onTriggered: {
            // Re-trigger compact content fade-in
            if (root.expanded) {
                row.showNote.start();
                row.showText.start();
                row.showControls.start();
            }
        }
    }

    notifHandlerConnections: Connections {
        function onNotificationArrived() {
            // If detail view is open, close it first
            if (root.detailExpanded) {
                detailOpacity.value = 0;
                collapseSequencer.start();
            }
            // Fade out music compact content
            row.hideControls.start();
            row.hideText.start();
            row.hideNote.start();
            // After music fades, show notification
            notifShowTimer.start();
        }

        function onNotificationDismissed() {
            // Fade out notification
            root.notifOpacity.value = 0;
            // After fade, hide notification state and restore music
            notifHideTimer.start();
        }

        target: notifHandler
    }

    notifHideTimer: Timer {
        interval: 350
        onTriggered: {
            root.notificationVisible = false;
            notifRestoreTimer.start();
        }
    }

    positionPoller: Timer {
        interval: 500
        running: root.isPlaying && root.detailExpanded
        repeat: true
        onTriggered: {
            if (root.hasSpotify) {
                root.trackPosition = root.spotifyPlayer.position;
                root.trackLength = root.spotifyPlayer.length;
            }
        }
    }

    volProcess: Process {
        property string lastRaw: ""

        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]

        stdout: SplitParser {
            onRead: function(line) {
                var muted = line.indexOf("[MUTED]") !== -1;
                var match = line.match(/Volume:\s*([\d.]+)/);
                if (!match)
                    return ;

                var vol = parseFloat(match[1]);
                var raw = line.trim();
                if (raw !== volProcess.lastRaw) {
                    volProcess.lastRaw = raw;
                    root.isMuted = muted;
                    root.currentVolume = vol;
                    root.volumeVisible = true;
                    volumeHideTimer.restart();
                }
            }
        }

    }

    volPoll: Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            if (!volProcess.running)
                volProcess.running = true;

        }
    }

    volumeHideTimer: Timer {
        interval: 3000
        onTriggered: root.volumeVisible = false
    }

    detailOpacity: QtObject {
        property real value: 0

        Behavior on value {
            NumberAnimation {
                duration: 300
                easing.type: Easing.InOutQuad
            }

        }

    }

}
