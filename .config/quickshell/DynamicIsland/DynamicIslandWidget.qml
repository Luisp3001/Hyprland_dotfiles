import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland
import "../components" as Lib
import "music"
import "airdrop"
import "applauncher"
import "notifications"
import "overview"
import "screenrec"
import "volume"

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
    property var airdropOpacity: _airdropOpacity
    // ── Workspace Overview state ─────────────────────────────────────────
    property bool overviewOpen: false
    // ── Screen Recording state ──────────────────────────────────────────
    property string screenRecState: "idle"
    property int screenRecElapsed: 0
    property bool screenRecOpen: false
    property bool screenRecMinimized: true

    readonly property string screenRecScript: Quickshell.env("HOME") + "/.config/quickshell/DynamicIsland/screenrec/wl_screenrec_ctl.sh"

    function screenRecRunCtl(action) {
        Quickshell.execDetached(["bash", screenRecScript, action]);
    }

    Lib.CommandPoll {
        id: screenRecPoll
        interval: 500
        command: ["bash", root.screenRecScript, "status"]
        parse: function(out) { return String(out ?? "").trim(); }
        onUpdated: {
            try {
                var o = JSON.parse(screenRecPoll.text || "{}");
                root.screenRecState = o.state || "idle";
                if (typeof o.elapsed_sec === "number")
                    root.screenRecElapsed = Math.floor(o.elapsed_sec);
                else
                    root.screenRecElapsed = parseInt(o.elapsed_sec, 10) || 0;
                
                if (root.screenRecState === "idle" && root.screenRecOpen) {
                    root.toggleScreenRec();
                }
            } catch (e) {
                root.screenRecState = "idle";
                root.screenRecElapsed = 0;
            }
        }
    }
    // ── Notification system ────────────────────────────────────────────
    required property var notifHandler
    property var server: null
    property var historyModel: null
    property bool notifCenterVisible: false
    property bool dndEnabled: false
    property var onToggleNotifCenter: null
    property bool notificationVisible: false
    property int verticalPadding: 8
    // Alias to compact player for functions to access
    property var row: pill.compactPlayer

    // Opacity controller for notification content
    property var notifOpacity: islandTimers.notifOpacity
    // Opacity controller for launcher content
    property var launcherOpacity: islandTimers.launcherOpacity
    // Opacity controller for overview content
    property var overviewOpacity: islandTimers.overviewOpacity
    // Opacity controller for airdrop content
    property var _airdropOpacity: islandTimers._airdropOpacity
    // Sequenced collapse: fade out content first, THEN shrink pill
    property var collapseSequencer: islandTimers.collapseSequencer
    // Timer to show notification after music content fades
    property var notifShowTimer: islandTimers.notifShowTimer
    // Timer to fade in notification content after pill expands
    property var notifFadeInTimer: islandTimers.notifFadeInTimer
    // Timer to restore music content after notification dismissed
    property var notifRestoreTimer: islandTimers.notifRestoreTimer
    property var notifHandlerConnections: islandTimers.notifHandlerConnections
    property var notifHideTimer: islandTimers.notifHideTimer

    property var overviewFadeInTimer: islandTimers.overviewFadeInTimer
    property var overviewCloseTimer: islandTimers.overviewCloseTimer
    property var _screenRecOpacity: islandTimers._screenRecOpacity
    property var screenRecFadeInTimer: islandTimers.screenRecFadeInTimer
    property var screenRecCloseTimer: islandTimers.screenRecCloseTimer
    property var airdropFadeInTimer: islandTimers.airdropFadeInTimer
    property var airdropCloseTimer: islandTimers.airdropCloseTimer
    property var airdropMinimizeTimer: islandTimers.airdropMinimizeTimer
    property var launcherFadeInTimer: islandTimers.launcherFadeInTimer
    property var launcherCloseTimer: islandTimers.launcherCloseTimer

    // ── Position tracking ──────────────────────────────────────────────
    property real trackPosition: 0
    property real trackLength: 0
    property var positionPoller: islandTimers.positionPoller
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
    property var detailOpacity: islandTimers.detailOpacity

    // ── Workspace Overview toggle ─────────────────────────────────────────
    function toggleOverview() {
        if (root.overviewOpen) {
            // Close overview: fade content then shrink
            root.overviewOpacity.value = 0.0;
            overviewCloseTimer.start();
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
            if (root.airdropOpen) {
                root._airdropOpacity.value = 0;
                root.airdropOpen = false;
            }
            if (root.screenRecOpen) {
                root._screenRecOpacity.value = 0;
                root.screenRecOpen = false;
            }
            root.overviewOpen = true;
        }
    }

    onOverviewOpenChanged: {
        if (overviewOpen) {
            overviewFadeInTimer.start();
            // Hide compact player
            row.hideControls.start();
            row.hideText.start();
            row.hideNote.start();
            // Reload data when opening
            Qt.callLater(function() {
                if (overviewContentLoader.item)
                    overviewContentLoader.item.reload();
            });
        }
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
            if (root.overviewOpen) {
                root.overviewOpacity.value = 0;
                root.overviewOpen = false;
            }
            if (root.screenRecOpen) {
                root._screenRecOpacity.value = 0;
                root.screenRecOpen = false;
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
        if (root.screenRecOpen) {
            root._screenRecOpacity.value = 0;
            root.screenRecOpen = false;
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
            if (root.overviewOpen) {
                root.overviewOpacity.value = 0;
                root.overviewOpen = false;
            }
            if (root.screenRecOpen) {
                root._screenRecOpacity.value = 0;
                root.screenRecOpen = false;
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

    // ── Screen Recorder toggle ──────────────────────────────────────────
    function toggleScreenRec() {
        if (root.screenRecOpen) {
            root._screenRecOpacity.value = 0.0;
            screenRecCloseTimer.start();
            root.screenRecMinimized = true;
        } else {
            if (root.detailExpanded) { detailOpacity.value = 0; root.detailExpanded = false; root.eqExpanded = false; }
            if (root.notificationVisible) { root.notifOpacity.value = 0; root.notificationVisible = false; }
            if (root.launcherOpen) { root.launcherOpacity.value = 0; root.launcherOpen = false; }
            if (root.airdropOpen) { root._airdropOpacity.value = 0; root.airdropOpen = false; }
            if (root.overviewOpen) { root.overviewOpacity.value = 0; root.overviewOpen = false; }
            
            root.screenRecMinimized = false;
            root.screenRecOpen = true;
        }
    }

    onScreenRecOpenChanged: {
        if (screenRecOpen) {
            screenRecFadeInTimer.start();
            row.hideControls.start();
            row.hideText.start();
            row.hideNote.start();
        }
    }


    function toggleDetail() {
        if (!root.hasSpotify)
            return ;

        if (root.notificationVisible)
            return ;

        // Block while notification, launcher, airdrop, or overview showing
        if (root.launcherOpen)
            return;
        if (root.airdropOpen)
            return;
        if (root.overviewOpen)
            return;
        if (root.screenRecOpen)
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

        Qt.callLater(function() {
            try {
                var o = JSON.parse(screenRecPoll.text || "{}");
                root.screenRecState = o.state || "idle";
                if (typeof o.elapsed_sec === "number")
                    root.screenRecElapsed = Math.floor(o.elapsed_sec);
                else
                    root.screenRecElapsed = parseInt(o.elapsed_sec, 10) || 0;
            } catch (e) {}
        });
    }
    implicitWidth: 860
    // Fixed height: the mask handles click-through so this never blocks input.
    // Eliminates the jitter from Hyprland re-laying-out the window mid-animation.
    implicitHeight: 700

    // Stack screen-rec bubble below AirdropBubble when both would sit on the left
    readonly property bool screenRecStackUnderAirdrop: {
        if (root.notificationVisible || root.notifCenterVisible)
            return false;

        var hasActivity = (root.airdropLsState === "scanning" || root.airdropLsState === "ready" || root.airdropLsState === "sending" || root.airdropLsState === "sent" || root.airdropLsState === "error");
        return root.airdropMinimized && hasActivity && !root.airdropOpen;
    }

    property Item maskItem: maskContainer

    // Exclude hidden screen-rec bubble so idle geometry does not widen the input mask.
    readonly property real _maskScreenRecLeft: screenRecBubble.visible ? screenRecBubble.x : 999999
    readonly property real _maskScreenRecTop: screenRecBubble.visible ? screenRecBubble.y : 999999
    readonly property real _maskScreenRecRight: screenRecBubble.visible ? (screenRecBubble.x + screenRecBubble.width) : -999999
    readonly property real _maskScreenRecBottom: screenRecBubble.visible ? (screenRecBubble.y + screenRecBubble.height) : -999999

    Item {
        id: maskContainer
        x: Math.min(pill.x, notifBubble.x, airdropBubble.x, root._maskScreenRecLeft)
        y: Math.min(pill.y, notifBubble.y, airdropBubble.y, root._maskScreenRecTop)
        width: Math.max(pill.x + pill.width, notifBubble.x + notifBubble.width, airdropBubble.x + airdropBubble.width, root._maskScreenRecRight) - x
        height: Math.max(pill.y + pill.height, notifBubble.y + notifBubble.height, airdropBubble.y + airdropBubble.height, root._maskScreenRecBottom) - y
    }

    // ── Music pill ────────────────────────────────────────────────
    IslandPill {
        id: pill
        rootWidget: root
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
        state: (!root.notificationVisible && !root.launcherOpen && !root.airdropOpen && !root.overviewOpen && !root.screenRecOpen && (root.notifCenterVisible || (root.expanded && !root.detailExpanded))) ? "visible" : ""
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
            // Hide the bubble if other main widgets are expanded
            if (root.notificationVisible || root.notifCenterVisible || root.detailExpanded || root.launcherOpen || root.overviewOpen || root.screenRecOpen) return "";
            
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

    // ── Screen recording bubble (wl-screenrec + wl_screenrec_ctl.sh) ──
    ScreenRecBubble {
        id: screenRecBubble

        z: 2
        walColors: root.walColors
        rootWidget: root

        anchors {
            top: root.screenRecStackUnderAirdrop ? airdropBubble.bottom : pill.top
            topMargin: root.screenRecStackUnderAirdrop ? 8 : 0
            horizontalCenter: parent.horizontalCenter
            horizontalCenterOffset: {
                var hasActivity = (root.screenRecState === "recording" || root.screenRecState === "paused");
                var showBubble = (root.screenRecMinimized && hasActivity && !root.screenRecOpen);
                if (showBubble)
                    return -212.5;

                return -150;
            }
        }

        state: {
            if (root.notificationVisible || root.notifCenterVisible || root.detailExpanded || root.launcherOpen || root.airdropOpen || root.overviewOpen) return "";
            var hasActivity = (root.screenRecState === "recording" || root.screenRecState === "paused");
            if (root.screenRecMinimized && hasActivity && !root.screenRecOpen) return "visible";
            return "";
        }
        visible: state === "visible" || opacity > 0
        onClicked: {
            root.toggleScreenRec();
        }

        Behavior on anchors.topMargin {
            NumberAnimation {
                duration: 400
                easing.type: Easing.OutQuint
            }
        }

        Behavior on anchors.horizontalCenterOffset {
            NumberAnimation {
                duration: 500
                easing.type: Easing.OutQuint
            }
        }
    }

    IslandTimers {
        id: islandTimers
        rootWidget: root
        pill: pill
    }
}
