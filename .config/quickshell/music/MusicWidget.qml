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
    // EQ expanded state
    property bool eqExpanded: false
    // ── App Launcher state ──────────────────────────────────────────────
    property bool launcherOpen: false
    // ── Airdrop state ───────────────────────────────────────────────────
    property bool airdropOpen: false
    property bool airdropMinimized: false    // pill collapsed but transfer alive
    property string airdropLsState: "idle"   // mirrored from AirdropContent
    property string airdropFileName: ""      // mirrored from AirdropContent
    property string airdropStatusMsg: ""     // mirrored from AirdropContent
    property var airdropOpacity
    // ── Notification system ────────────────────────────────────────────
    required property var notifHandler
    property var server: null
    property var historyModel: null
    property bool notifCenterVisible: false
    property bool dndEnabled: false
    property var onToggleNotifCenter: null
    property bool notificationVisible: false
    property int verticalPadding: 8
    // Opacity controller for notification content
    property var notifOpacity
    // Opacity controller for launcher content
    property var launcherOpacity
    // Opacity controller for airdrop content
    property var _airdropOpacity
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
            return 690;

        var h = pill.targetHeight;
        return h + root.verticalPadding + 15;
    }

    // ── Airdrop toggle ──────────────────────────────────────────────────
    function toggleAirdrop() {
        if (root.airdropOpen) {
            // Close airdrop: fade content then shrink
            root._airdropOpacity.value = 0.0;
            airdropCloseTimer.start();
        } else {
            // Close any other expanded state first
            if (root.detailExpanded) {
                detailOpacity.value = 0;
                root.detailExpanded = false;
                root.eqExpanded = false;
            }
            if (root.notificationVisible) {
                root.notifOpacity.value = 0;
                root.notificationVisible = false;
            }
            if (root.launcherOpen) {
                root.launcherOpacity.value = 0;
                root.launcherOpen = false;
            }
            root.airdropMinimized = false;
            root.airdropOpen = true;
        }
    }

    function minimizeAirdrop() {
        // Collapse pill but keep transfer alive in background
        root._airdropOpacity.value = 0.0;
        airdropMinimizeTimer.start();
    }

    function restoreAirdrop() {
        // Re-expand pill from minimized state
        if (root.detailExpanded) {
            detailOpacity.value = 0;
            root.detailExpanded = false;
            root.eqExpanded = false;
        }
        if (root.notificationVisible) {
            root.notifOpacity.value = 0;
            root.notificationVisible = false;
        }
        if (root.launcherOpen) {
            root.launcherOpacity.value = 0;
            root.launcherOpen = false;
        }
        // IMPORTANT: set airdropOpen FIRST so the Loader stays active
        // (active = airdropOpen || opacity > 0 || airdropMinimized).
        // If we cleared airdropMinimized first, all three would be false
        // for one frame and the Loader would destroy the component, losing state.
        root.airdropOpen = true;
        root.airdropMinimized = false;
    }

    onAirdropOpenChanged: {
        if (airdropOpen) {
            airdropFadeInTimer.start();
            // Hide compact player
            row.hideControls.start();
            row.hideText.start();
            row.hideNote.start();
        }
    }

    // ── App Launcher toggle ─────────────────────────────────────────────
    function toggleLauncher() {
        if (root.launcherOpen) {
            // Close launcher: fade content then shrink
            launcherOpacity.value = 0.0;
            launcherCloseTimer.start();
        } else {
            // Close any other expanded state first
            if (root.detailExpanded) {
                detailOpacity.value = 0;
                root.detailExpanded = false;
                root.eqExpanded = false;
            }
            if (root.notificationVisible) {
                root.notifOpacity.value = 0;
                root.notificationVisible = false;
            }
            if (root.airdropOpen) {
                root._airdropOpacity.value = 0;
                root.airdropOpen = false;
            }
            root.launcherOpen = true;
        }
    }

    onLauncherOpenChanged: {
        if (launcherOpen) {
            launcherFadeInTimer.start();
            // If Loader item already exists (re-open), reload now.
            // First open is handled by Loader.onLoaded.
            Qt.callLater(function() {
                if (launcherContentLoader.item)
                    launcherContentLoader.item.reload();
            });
        }
    }
    property real currentImplicitHeight: targetImplicitHeight

    function toggleDetail() {
        if (!root.hasSpotify)
            return ;

        if (root.notificationVisible)
            return ;

        // Block while notification, launcher, or airdrop showing
        if (root.launcherOpen)
            return;
        if (root.airdropOpen)
            return;

        if (root.detailExpanded) {
            // Step 1: fade out detail content immediately
            detailOpacity.value = 0;
            // Step 2: after content fades, shrink the pill
            collapseSequencer.start();
        } else {
            root.detailExpanded = true;
            root.eqExpanded = false;
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
    implicitWidth: 860

    property Item maskItem: maskContainer
    Item {
        id: maskContainer
        x: Math.min(pill.x, notifBubble.x, airdropBubble.x)
        y: Math.min(pill.y, notifBubble.y, airdropBubble.y)
        width: Math.max(pill.x + pill.width, notifBubble.x + notifBubble.width, airdropBubble.x + airdropBubble.width) - x
        height: Math.max(pill.y + pill.height, notifBubble.y + notifBubble.height, airdropBubble.y + airdropBubble.height) - y
    }

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
        property real expandedWidth: 850
        property real launcherWidth: 560
        property real airdropWidth: 420
        property real notifWidth: 430
        property real notifHeight: {
            if (!root.notificationVisible)
                return 90;

            // Calculate height based on content
            return Math.min(300, Math.max(90, notifContent.notifColumn.implicitHeight + 30));
        }
        property real launcherHeight: (launcherContentLoader.item ? launcherContentLoader.item.preferredHeight : 425) + 28
        property real airdropHeight: (airdropContentLoader.item ? airdropContentLoader.item.preferredHeight : 200) + 28
        property real targetWidth: root.airdropOpen ? airdropWidth : (root.launcherOpen ? launcherWidth : (root.notificationVisible ? notifWidth : (root.detailExpanded ? expandedWidth : compactWidth)))
        property real targetHeight: root.airdropOpen ? airdropHeight : (root.launcherOpen ? launcherHeight : (root.notificationVisible ? notifHeight : (root.detailExpanded ? 420 : 45)))

        antialiasing: true
        clip: true
        layer.enabled: true
        width: targetWidth
        height: targetHeight
        radius: (root.detailExpanded || root.notificationVisible || root.launcherOpen || root.airdropOpen) ? 22 : height / 2
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

            property real startY: 0
            property bool isSwiping: false

            onPressed: (mouse) => {
                startY = mouse.y;
                isSwiping = false;
            }

            onPositionChanged: (mouse) => {
                if (root.notificationVisible && !isSwiping) {
                    if (startY - mouse.y > 20) {
                        isSwiping = true;
                        root.notifHandler.dismiss();
                    }
                }
            }

            onClicked: {
                if (isSwiping) return;
                if (root.launcherOpen) return; // Don't toggle detail while launcher is open
                if (root.airdropOpen) return; // Don't toggle detail while airdrop is open

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
            visible: root.notifOpacity.value > 0 && !root.launcherOpen && !root.airdropOpen
            opacity: root.notifOpacity.value

            anchors {
                fill: parent
                leftMargin: 22
                rightMargin: 22
                topMargin: 12
                bottomMargin: 12
            }

        }

        // ── App Launcher content ─────────────────────────────────────
        Loader {
            id: launcherContentLoader
            active: root.launcherOpen || root.launcherOpacity.value > 0
            visible: root.launcherOpacity.value > 0
            opacity: root.launcherOpacity.value
            sourceComponent: Component {
                AppLauncherContent {
                    rootWidget: root
                }
            }

            // When the Loader finishes creating the item, load apps + grab focus
            onLoaded: {
                if (item && root.launcherOpen)
                    item.reload();
            }

            anchors {
                fill: parent
                leftMargin: 18
                rightMargin: 18
                topMargin: 14
                bottomMargin: 14
            }
        }

        // ── Airdrop content ──────────────────────────────────────────
        Loader {
            id: airdropContentLoader
            active: root.airdropOpen || root._airdropOpacity.value > 0 || root.airdropMinimized
            visible: root._airdropOpacity.value > 0
            opacity: root._airdropOpacity.value
            sourceComponent: Component {
                AirdropContent {
                    rootWidget: root
                }
            }

            anchors {
                fill: parent
                leftMargin: 18
                rightMargin: 18
                topMargin: 14
                bottomMargin: 14
            }
        }

        // ── Global DropArea: expand island on external file drag ─────
        DropArea {
            id: pillDropArea
            anchors.fill: parent
            keys: ["text/uri-list", "text/plain"]
            enabled: !root.airdropOpen && !root.launcherOpen

            onEntered: (drag) => {
                // A file is being dragged over the island — expand to airdrop
                if (!root.airdropOpen) {
                    root.toggleAirdrop();
                }
            }
        }

        // Global ESC handler — closes launcher or airdrop from anywhere in the pill
        Keys.onEscapePressed: function(event) {
            if (root.launcherOpen) {
                root.toggleLauncher();
                event.accepted = true;
            } else if (root.airdropOpen) {
                root.toggleAirdrop();
                event.accepted = true;
            }
        }
        focus: root.launcherOpen || root.airdropOpen

        Behavior on anchors.horizontalCenterOffset {
            NumberAnimation {
                duration: 400
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
        dndEnabled: root.dndEnabled
        onDndEnabledChanged: root.dndEnabled = notifBubble.dndEnabled
        state: (!root.notificationVisible && !root.launcherOpen && !root.airdropOpen && (root.notifCenterVisible || (root.expanded && !root.detailExpanded))) ? "visible" : ""
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

    // ── Airdrop bubble (left side, background transfer status) ─────
    AirdropBubble {
        id: airdropBubble

        walColors: root.walColors
        lsState: root.airdropLsState
        fileName: root.airdropFileName
        statusMessage: root.airdropStatusMsg
        state: {
            // Hide the bubble if notification or notif center is visible
            if (root.notificationVisible || root.notifCenterVisible) return "";
            
            // Show when minimized and there's an active transfer
            var hasActivity = (root.airdropLsState === "scanning" || root.airdropLsState === "ready" ||
                               root.airdropLsState === "sending" || root.airdropLsState === "sent" ||
                               root.airdropLsState === "error");
            if (root.airdropMinimized && hasActivity && !root.airdropOpen) return "visible";
            return "";
        }
        visible: state === "visible" || opacity > 0
        onClicked: {
            root.restoreAirdrop();
        }

        anchors {
            top: pill.top
            horizontalCenter: parent.horizontalCenter
            horizontalCenterOffset: {
                var showBubble = (root.airdropMinimized && !root.airdropOpen);
                if (showBubble)
                    return -212.5;

                // When hiding, slide inward behind pill
                return -150;
            }
        }

        Behavior on anchors.horizontalCenterOffset {
            NumberAnimation {
                duration: 500
                easing.type: Easing.OutQuint
            }
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
            root.eqExpanded = false;
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
            // If launcher is open, close it first
            if (root.launcherOpen) {
                root.launcherOpacity.value = 0;
                root.launcherOpen = false;
            }
            // If airdrop is open, minimize it (don't kill active transfers)
            if (root.airdropOpen) {
                var hasTransfer = (root.airdropLsState === "sending" || root.airdropLsState === "scanning" || root.airdropLsState === "ready");
                root._airdropOpacity.value = 0;
                if (hasTransfer) {
                    root.airdropMinimized = true;
                }
                root.airdropOpen = false;
            }
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


    // ── Launcher opacity + timers ─────────────────────────────────────────
    launcherOpacity: QtObject {
        property real value: 0.0

        Behavior on value {
            NumberAnimation {
                duration: 250
                easing.type: Easing.InOutQuad
            }
        }
    }

    Timer {
        id: launcherFadeInTimer
        interval: 200 // let pill expand before showing content
        onTriggered: root.launcherOpacity.value = 1.0
    }

    Timer {
        id: launcherCloseTimer
        interval: 250 // let content fade out before shrinking
        onTriggered: {
            root.launcherOpen = false;
            // Restore compact player
            if (root.expanded) {
                row.showNote.start();
                row.showText.start();
                row.showControls.start();
            }
        }
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

    // ── Airdrop opacity + timers ──────────────────────────────────────────
    _airdropOpacity: QtObject {
        property real value: 0.0

        Behavior on value {
            NumberAnimation {
                duration: 250
                easing.type: Easing.InOutQuad
            }
        }
    }

    airdropOpacity: root._airdropOpacity

    Timer {
        id: airdropFadeInTimer
        interval: 200 // let pill expand before showing content
        onTriggered: root._airdropOpacity.value = 1.0
    }

    Timer {
        id: airdropCloseTimer
        interval: 250 // let content fade out before shrinking
        onTriggered: {
            root.airdropOpen = false;
            // Restore compact player so pill returns to normal
            if (root.expanded) {
                row.showNote.start();
                row.showText.start();
                row.showControls.start();
            }
        }
    }

    Timer {
        id: airdropMinimizeTimer
        interval: 250
        onTriggered: {
            root.airdropMinimized = true;
            root.airdropOpen = false;
            // Restore compact player
            if (root.expanded) {
                row.showNote.start();
                row.showText.start();
                row.showControls.start();
            }
        }
    }

}
