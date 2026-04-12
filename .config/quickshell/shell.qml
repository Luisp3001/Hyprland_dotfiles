import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "music"
import "Wallpaper"
import "HyprQuickFrame"
import "notificationcenter"
import "topbar"
import "components"

ShellRoot {
    id: shell

    // ── State ──────────────────────────────────────────────────────────
    property bool wallpaperVisible:    false
    property bool screenshotActive:    false
    property bool notifCenterVisible:  false
    property bool calendarVisible:     false
    property bool powerMenuVisible:    false
    property bool dndEnabled:          false

    // ── Volume State ───────────────────────────────────────────────────
    property real currentVolume: 0.5
    property bool isMuted: false
    property bool volumeVisible: false

    onWallpaperVisibleChanged: {
        if (!wallpaperVisible) {
            gc();
        }
    }

    // ── Shared Notification Service ────────────────────────────────────
    property var notifServer: NotificationServer {
        actionsSupported: true
        keepOnReload: true
        imageSupported: true
        bodyImagesSupported: true
    }

    property var musicNotifHandler: NotificationHandler {
        server: shell.notifServer
        dndEnabled: shell.dndEnabled
    }

    property var notifHistory: NotifHistoryModel {
        server: shell.notifServer
    }

    // ── Pywal Colors (Centralized) ─────────────────────────────────────
    property var jsonfile: FileView {
        // Use plain path string for more reliable watching
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        blockLoading: true
        onFileChanged: {
            console.log("Pywal: colors.json changed signal received.");
            colorTimer.restart();
        }
    }

    // Fallback poller in case watchChanges fails (e.g. file replacement via sync)
    Timer {
        id: pollTimer
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            jsonfile.reload();
            shell.parseColors();
        }
    }

    Timer {
        id: colorTimer
        interval: 200
        onTriggered: {
            jsonfile.reload();
            shell.parseColors();
        }
    }

    property var walColors: ({
        special: { background: "#1c1e26", foreground: "#ebdbb2", cursor: "#ebdbb2" },
        colors: { 
            color0: "#1c1e26", color1: "#e95678", color2: "#fab387", color3: "#f0c674", 
            color4: "#89b4fa", color5: "#c678dd", color6: "#56b6c2", color7: "#abb2bf",
            color8: "#1c1e26", color9: "#e95678", color10: "#fab387", color11: "#f0c674",
            color12: "#89b4fa", color13: "#c678dd", color14: "#56b6c2", color15: "#abb2bf" 
        }
    })

    property string _lastColorHash: ""

    function parseColors() {
        var rawText = jsonfile.text();
        if (!rawText || rawText.trim() === "") return;
        
        // Simple hash to avoid unnecessary object reassignments
        if (rawText === shell._lastColorHash) return;
        shell._lastColorHash = rawText;

        try {
            var parsed = JSON.parse(rawText);
            if (parsed && parsed.special && parsed.colors) {
                console.log("Pywal: Applying new colors (update detected)");
                shell.walColors = {
                    special: parsed.special,
                    colors: parsed.colors
                };
            }
        } catch (e) {
            console.log("Pywal: Error parsing colors.json:", e);
        }
    }

    Component.onCompleted: {
        shell.parseColors();
    }

    // ── Volume polling via wpctl ───────────────────────────────────────
    property var volProcess: Process {
        property string lastRaw: ""
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: function(line) {
                var muted = line.indexOf("[MUTED]") !== -1;
                var match = line.match(/Volume:\s*([\d.]+)/);
                if (!match) return;

                var vol = parseFloat(match[1]);
                var raw = line.trim();
                if (raw !== volProcess.lastRaw) {
                    volProcess.lastRaw = raw;
                    shell.isMuted = muted;
                    shell.currentVolume = vol;
                    shell.volumeVisible = true;
                    volumeHideTimer.restart();
                }
            }
        }
    }

    Timer {
        id: volPoll
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            if (!volProcess.running)
                volProcess.running = true;
        }
    }

    Timer {
        id: volumeHideTimer
        interval: 3000
        onTriggered: shell.volumeVisible = false
    }

    // ── IPC Handler ────────────────────────────────────────────────────
    // Usage from Hyprland keybinds:
    //   bind = SUPER, P, exec, qs ipc call shell toggleWallpaper
    //   bind = SUPER SHIFT, S, exec, qs ipc call shell launchScreenshot
    IpcHandler {
        target: "shell"

        function lockScreen(): void {
            Quickshell.execDetached(["qs", "-p", Quickshell.env("HOME") + "/.config/quickshell/components/Lock.qml"]);
        }

        function toggleWallpaper(): void {
            shell.wallpaperVisible = !shell.wallpaperVisible;
        }

        function launchScreenshot(): void {
            shell.screenshotActive = true;
        }

        function toggleNotifCenter(): void {
            shell.notifCenterVisible = !shell.notifCenterVisible;
        }

        function clearNotifHistory(): void {
            shell.notifHistory.clearAll();
        }

        function togglePowerMenu(): void {
            shell.powerMenuVisible = !shell.powerMenuVisible;
        }
    }

    // ── Top Bar Windowing Strategy ─────────────────────────────────────
    
    // 1. Space Reservation Window
    // Reserves space globally so other applications don't overlap the bar.
    PanelWindow {
        anchors { top: true; left: true; right: true }
        implicitHeight: 50
        color: "transparent"
        visible: true
        exclusionMode: ExclusionMode.Exclusive
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "quickshell"
    }

    // 2. Global Dismiss Overlay (Only active when Notification Center is open)
    // Sits on WlrLayer.Bottom, beneath Top windows but above the wallpaper.
    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        visible: shell.notifCenterVisible
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "notificationcenter" // Different namespace to avoid Hyprland layerrule conflicts
        color: "transparent"
        
        MouseArea {
            anchors.fill: parent
            onClicked: shell.notifCenterVisible = false
        }
    }

    // 3. Left Modules Window (Launcher + Workspaces)
    PanelWindow {
        anchors { top: true; left: true }
        implicitWidth: lm.implicitWidth
        implicitHeight: lm.implicitHeight
        color: "transparent"
        visible: true
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell"
        
        LeftModules { 
            id: lm
            anchors.fill: parent
            walColors: shell.walColors
        }
    }

    // 4. Center Music & Notification Window
    PanelWindow {
        anchors { top: true } // Auto-centered by Hyprland/wlroots
        implicitWidth: mWidget.implicitWidth
        implicitHeight: mWidget.implicitHeight
        color: "transparent"
        visible: true
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell"
        WlrLayershell.layer:     WlrLayer.Top

        MusicWidget {
            id: mWidget
            anchors.fill: parent
            walColors: shell.walColors
            notifHandler: shell.musicNotifHandler
            server: shell.notifServer
            historyModel: shell.notifHistory
            notifCenterVisible: shell.notifCenterVisible
            dndEnabled: shell.dndEnabled
            onToggleNotifCenter: () => shell.notifCenterVisible = !shell.notifCenterVisible
            onDndEnabledChanged: shell.dndEnabled = mWidget.dndEnabled
        }
    }

    // 5. Right Modules Window (Cpu, Network, Tray)
    PanelWindow {
        id: rightModulesWindow
        anchors { top: true; right: true }
        // Offset this window so it sits to the left of the Clock window (which is ~130px when collapsed)
        margins.right: 135
        implicitWidth: rm.implicitWidth
        implicitHeight: rm.implicitHeight
        color: "transparent"
        visible: true
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell"
        
        RightModules { 
            id: rm
            anchors.fill: parent
            walColors: shell.walColors
            panelWindow: rightModulesWindow
        }
    }

    // 6. Clock & Calendar Window
    PanelWindow {
        anchors { top: true; right: true }
        // We use the implicit dimensions of the module which handles the snap-expand/delayed-shrink logic
        implicitWidth: clockMod.implicitWidth
        implicitHeight: clockMod.implicitHeight
        margins.top: 5
        margins.right: 5
        
        color: "transparent"
        visible: true
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell" // Mandatory for blur debugging and Hyprland rules

        ClockModule {
            id: clockMod
            anchors.fill: parent
            walColors: shell.walColors
        }
    }

    // ── Wallpaper Picker (toggled via SUPER+P) ─────────────────────────
    Loader {
        active: shell.wallpaperVisible
        sourceComponent: Component {
            WallpaperPicker {
                active: true
                onClosed: shell.wallpaperVisible = false
            }
        }
    }

    // ── HyprQuickFrame / Screenshot Tool (SUPER+SHIFT+S) ──────────────
    ScreenshotTool {
        active: shell.screenshotActive
        onDone: shell.screenshotActive = false
    }

    // ── Power Menu (toggled via SUPER+X or IPC) ───────────────────────
    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        visible: shell.powerMenuVisible
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "power-menu"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: "transparent"

        PowerMenu {
            id: powerMenu
            anchors.fill: parent
            walColors: shell.walColors
        }

        onVisibleChanged: {
            if (visible) {
                powerMenu.open();
            }
        }

        Connections {
            target: powerMenu
            function onVisibleChanged() {
                if (!powerMenu.visible) {
                    shell.powerMenuVisible = false;
                }
            }
        }
    }

    // ── Volume Island (Overlay Layer) ──────────────────────────────────
    PanelWindow {
        anchors { top: true }
        // Match core width to ensure centering matches MusicWidget
        implicitWidth: 500 
        implicitHeight: 80
        // Position it dynamically below the MusicWidget
        margins.top: mWidget.y + mWidget.height - 30
        color: "transparent"
        visible: shell.volumeVisible || volumeIsland.opacity > 0
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell"

        VolumeIsland {
            id: volumeIsland
            anchors.centerIn: parent
            rootWidget: shell
        }
    }
}