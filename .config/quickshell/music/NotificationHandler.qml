import QtQuick
import Quickshell.Services.Notifications

QtObject {
    id: handler

    // ── Exposed state ──────────────────────────────────────────────────
    property bool   active:   false
    property string summary:  ""
    property string body:     ""
    property string appName:  ""
    property string appIcon:  ""
    property url    image:    ""
    property int    urgency:  0  // 0=Low, 1=Normal, 2=Critical
    property var    actions:  []

    signal notificationArrived()
    signal notificationDismissed()

    // ── Internal queue ─────────────────────────────────────────────────
    property var _queue: []
    property var _currentNotif: null

    property var _notifConnections: Connections {
        target: _currentNotif
        ignoreUnknownSignals: true
        function onSummaryChanged() { if (_currentNotif) handler.summary = _currentNotif.summary; }
        function onBodyChanged()    { if (_currentNotif) handler.body    = _currentNotif.body; }
        function onImageChanged()   { if (_currentNotif) handler.image   = _currentNotif.image; }
        function onAppIconChanged() { if (_currentNotif) handler.appIcon = _currentNotif.appIcon; }
        function onActionsChanged() { if (_currentNotif) handler.actions = _currentNotif.actions; }
    }

    // ── Auto-dismiss timer ─────────────────────────────────────────────
    property var _dismissTimer: Timer {
        interval: 5000
        onTriggered: handler.dismiss()
    }

    // ── Notification Server (shared from shell.qml) ───────────────────
    required property var server

    property var _serverConnections: Connections {
        target: handler.server
        ignoreUnknownSignals: true
        function onNotification(notification) {
            // Skip notifications from previous reload sessions
            if (notification.lastGeneration) return;

            handler._queue.push(notification);

            // Immediately show if nothing is active
            if (!handler.active) {
                handler._showNext();
            }
        }
    }

    // ── Show next notification from queue ───────────────────────────────
    function _showNext() {
        if (_queue.length === 0) {
            active = false;
            _currentNotif = null;
            summary = "";
            body    = "";
            appName = "";
            appIcon = "";
            image   = "";
            urgency = 0;
            actions = [];
            notificationDismissed();
            return;
        }

        var notif = _queue.shift();
        _currentNotif = notif;

        summary = notif.summary  || "";
        body    = notif.body     || "";
        appName = notif.appName  || "";
        appIcon = notif.appIcon  || "";
        
        // Resolve app icon or image (unified logic)
        function resolveIcon(icon) {
            if (!icon) return "";
            var s = icon.toString();
            if (s !== "" && !s.startsWith("/") && !s.startsWith("file://") && !s.startsWith("image://")) {
                return "image://icon/" + s;
            }
            return s;
        }

        image = resolveIcon(notif.image) || resolveIcon(notif.appIcon) || "";

        urgency = notif.urgency  ?? 1;
        actions = notif.actions  || [];

        active = true;
        notificationArrived();

        // Set auto-dismiss (critical gets longer)
        _dismissTimer.interval = (urgency === 2) ? 8000 : 5000;
        _dismissTimer.restart();
    }

    // ── Dismiss current notification ───────────────────────────────────
    function dismiss() {
        _dismissTimer.stop();
        if (_currentNotif) {
            _currentNotif.dismiss();
            _currentNotif = null;
        }

        // Short delay before showing next, to let collapse animation play
        _nextTimer.start();
    }

    property var _nextTimer: Timer {
        interval: 600
        onTriggered: handler._showNext()
    }
}
