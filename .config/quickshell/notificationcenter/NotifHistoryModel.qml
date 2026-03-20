import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// NotifHistoryModel – maintains a persistent list of received notifications.
QtObject {
    id: historyModel

    // ── Public history list model ────────────────────────────────────────
    property var model: ListModel { id: _model }

    signal newNotification(var entry)

    // ── Persistence ──────────────────────────────────────────────────────
    readonly property string cacheFile: Quickshell.env("HOME") + "/.cache/quickshell/notifications.json"

    property bool _loaded: false

    property var loadFile: FileView {
        id: _cacheFileView
        path: historyModel.cacheFile
        onLoaded: historyModel.load()
        onLoadFailed: (err) => {
            historyModel._loaded = true;
        }
    }

    // Timer for debounced saving
    property var _saveTimer: Timer {
        interval: 1000
        onTriggered: historyModel._doSave()
    }

    function save() {
        if (!historyModel._loaded) return;
        _saveTimer.restart();
    }

    function _doSave() {
        var data = [];
        for (var i = 0; i < _model.count; i++) {
            var item = _model.get(i);
            if (!item) continue;
            data.push({
                notifId: item.notifId,
                summary: item.summary,
                body: item.body,
                appName: item.appName,
                appIcon: item.appIcon,
                image: item.image,
                urgency: item.urgency,
                time: item.time
            });
        }
        
        var json = JSON.stringify(data);
        
        // Use FileView.setText for safe, direct writing (no shell argument limits)
        _cacheFileView.setText(json);
    }

    function load() {
        if (historyModel._loaded) return;
        try {
            var raw = _cacheFileView.text();
            if (raw && raw.trim() !== "") {
                var data = JSON.parse(raw);
                if (Array.isArray(data)) {
                    _model.clear();
                    for (var i = 0; i < data.length; i++) {
                        // Ensure we don't carry over stale notifRefs from saved JSON
                        data[i].notifRef = null;
                        _model.append(data[i]);
                    }
                }
            }
        } catch(e) { console.log("Error loading notifications:", e); }
        historyModel._loaded = true;
    }

    Component.onCompleted: {
        if (_cacheFileView.loaded) {
            load();
        }
    }

    // ── Notification server (shared) ────────────────────────────────────
    required property var server

    property var _serverConnections: Connections {
        target: historyModel.server
        ignoreUnknownSignals: true

        function onNotification(notif) {
            if (notif.lastGeneration) return;

            notif.tracked = true;

            // Resolve app icon or image (unified logic)
            function resolveIcon(icon) {
                if (!icon) return "";
                var s = icon.toString();
                if (s !== "" && !s.startsWith("/") && !s.startsWith("file://") && !s.startsWith("image://")) {
                    return "image://icon/" + s;
                }
                return s;
            }

            var sourceImage = resolveIcon(notif.image) || resolveIcon(notif.appIcon);

            var entry = {
                notifId:  notif.id,
                summary:  notif.summary  || "",
                body:     notif.body     || "",
                appName:  notif.appName  || "",
                appIcon:  notif.appIcon  || "",
                image:    sourceImage    || "",
                urgency:  notif.urgency  ?? 1,
                time:     Qt.formatTime(new Date(), "hh:mm"),
                notifRef: notif
            };

            _model.insert(0, entry);
            historyModel.newNotification(entry);

            if (_model.count > 50)
                _model.remove(_model.count - 1);
            
            historyModel.save();
        }
    }

    // ── Public functions ─────────────────────────────────────────────────
    function removeAt(index) {
        if (index < 0 || index >= _model.count) return;
        
        var entry = _model.get(index);
        var ref = entry ? entry.notifRef : null;

        // 1. Expire/Dismiss first if it's a live notification
        if (ref) {
            try { ref.expire(); } catch(e) {}
        }
        
        // 2. Clear reference before removal to help GC
        if (entry) _model.setProperty(index, "notifRef", null);
        
        // 3. Remove from model
        _model.remove(index);
        
        // 4. Schedule save
        historyModel.save();
    }

    function clearAll() {
        // Collect live refs to expire them after clearing the model
        var liveRefs = [];
        for (var i = 0; i < _model.count; i++) {
            var item = _model.get(i);
            if (item && item.notifRef) {
                liveRefs.push(item.notifRef);
            }
        }

        // 1. Clear model first to ensure UI is reset and avoiding indexing issues
        _model.clear();

        // 2. Expire live notifications
        for (var j = 0; j < liveRefs.length; j++) {
            try { liveRefs[j].expire(); } catch(e) {}
        }

        // 3. Force an immediate save for clearAll
        _saveTimer.stop();
        historyModel._doSave();
    }
}
