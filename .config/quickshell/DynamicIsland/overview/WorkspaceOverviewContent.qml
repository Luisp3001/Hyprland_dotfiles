pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Wayland

// Workspace overview content that lives inside the dynamic island pill.
// Displayed when rootWidget.overviewOpen === true.
Item {
    id: overviewContent
    property var rootWidget

    // ── Layout config ──────────────────────────────────────────────────
    property real wsScale: 0.12
    property real wsSpacing: 6
    property real wsBorderRadius: 14
    property real wsLargeRadius: 22

    // ── Computed sizes ─────────────────────────────────────────────────
    readonly property var monitor: Hyprland.focusedMonitor
    readonly property real monitorWidth: monitor ? monitor.width : 1920
    readonly property real monitorHeight: monitor ? monitor.height : 1080
    readonly property real monitorScale: monitor && monitor.scale ? monitor.scale : 1
    readonly property real wsWidth: Math.max(120, monitorWidth * wsScale / monitorScale)
    readonly property real wsHeight: Math.max(80, monitorHeight * wsScale / monitorScale)

    // ── Active workspaces ──────────────────────────────────────────────
    property var activeWorkspacesList: {
        let activeWorkspaces = Hyprland.workspaces.values.slice().filter(ws => !ws.name.startsWith("special:S-"));
        
        activeWorkspaces.sort((a, b) => {
            if (a.id > 0 && b.id > 0) return a.id - b.id;
            if (a.id < 0 && b.id > 0) return 1;
            if (a.id > 0 && b.id < 0) return -1;
            return a.id - b.id;
        });
        
        // Ensure active workspace is included even if empty
        let currentActiveId = monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1;
        let hasActive = false;
        for (let i = 0; i < activeWorkspaces.length; i++) {
            if (activeWorkspaces[i].id === currentActiveId) {
                hasActive = true;
                break;
            }
        }
        if (!hasActive && currentActiveId > 0) {
            activeWorkspaces.push({ id: currentActiveId, name: currentActiveId.toString() });
            activeWorkspaces.sort((a, b) => {
                if (a.id > 0 && b.id > 0) return a.id - b.id;
                if (a.id < 0 && b.id > 0) return 1;
                if (a.id > 0 && b.id < 0) return -1;
                return a.id - b.id;
            });
        }
        
        return activeWorkspaces;
    }

    readonly property int activeCount: Math.max(1, activeWorkspacesList.length)
    readonly property int computedCols: Math.min(3, activeCount)
    readonly property int computedRows: Math.ceil(activeCount / computedCols)

    readonly property real gridWidth: computedCols * wsWidth + (computedCols - 1) * wsSpacing
    readonly property real gridHeight: computedRows * wsHeight + (computedRows - 1) * wsSpacing

    // Dynamic height for the pill
    property int preferredHeight: gridHeight + 56  // 44 header + 12 spacing

    readonly property int activeWorkspaceId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1

    // ── Hyprland data (IPC) ────────────────────────────────────────────
    property var windowList: []
    property var monitorList: []

    // ── Data fetching ──────────────────────────────────────────────────
    function reload() {
        fetchClientsProc.running = false;
        fetchClientsProc.running = true;
        fetchMonitorsProc.running = false;
        fetchMonitorsProc.running = true;
    }

    Process {
        id: fetchClientsProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    overviewContent.windowList = JSON.parse(this.text);
                } catch (e) {
                    overviewContent.windowList = [];
                }
            }
        }
    }

    Process {
        id: fetchMonitorsProc
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    overviewContent.monitorList = JSON.parse(this.text);
                } catch (e) {
                    overviewContent.monitorList = [];
                }
            }
        }
    }

    // Refresh data periodically while open
    Timer {
        id: refreshTimer
        interval: 1500
        running: overviewContent.visible && overviewContent.opacity > 0
        repeat: true
        onTriggered: overviewContent.reload()
    }

    // ── Helper functions ───────────────────────────────────────────────
    function getWindowsForWorkspace(wsId) {
        var result = [];
        for (var i = 0; i < windowList.length; i++) {
            var w = windowList[i];
            if (w.workspace && w.workspace.id === wsId) {
                result.push(w);
            }
        }
        return result;
    }

    // ── UI ─────────────────────────────────────────────────────────────
    Column {
        anchors.fill: parent
        spacing: 0

        // ── Header ───────────────────────────────────────────────────
        RowLayout {
            width: parent.width
            height: 44
            spacing: 12

            // Icon
            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignVCenter
                radius: 16
                color: Qt.rgba(0.45, 0.55, 0.95, 0.2)

                Text {
                    anchors.centerIn: parent
                    text: "󰍹"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 16
                    color: "#89b4fa"
                }
            }

            // Title
            Column {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Text {
                    text: "Workspaces"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: rootWidget.walColors.special.foreground
                }

                Text {
                    text: "Workspace " + overviewContent.activeWorkspaceId + " active"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 11
                    color: rootWidget.walColors.special.foreground
                    opacity: 0.5
                }
            }
        }

        // ── Divider ──────────────────────────────────────────────────
        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(
                rootWidget.walColors.special.foreground.r,
                rootWidget.walColors.special.foreground.g,
                rootWidget.walColors.special.foreground.b,
                0.1
            )
        }

        // ── Workspace Grid ───────────────────────────────────────────
        Item {
            width: parent.width
            height: parent.height - 45

            Item {
                id: gridContainer
                width: overviewContent.gridWidth
                height: overviewContent.gridHeight
                anchors.centerIn: parent

                // ── Workspace cells ──────────────────────────────────
                Flow {
                    id: wsFlowLayout
                    anchors.fill: parent
                    spacing: overviewContent.wsSpacing

                    Repeater {
                        model: overviewContent.activeWorkspacesList

                        delegate: Rectangle {
                            id: wsCell

                            required property var modelData
                            required property int index

                            property int wsId: modelData.id
                            property bool isActive: wsId === overviewContent.activeWorkspaceId

                            property bool isAtLeft: (index % overviewContent.computedCols) === 0
                            property bool isAtRight: (index % overviewContent.computedCols) === (overviewContent.computedCols - 1) || index === overviewContent.activeCount - 1
                            property bool isAtTop: index < overviewContent.computedCols
                            property bool isAtBottom: index >= (overviewContent.computedRows - 1) * overviewContent.computedCols

                            width: overviewContent.wsWidth
                            height: overviewContent.wsHeight
                            radius: overviewContent.wsBorderRadius
                            topLeftRadius: isAtLeft && isAtTop ? overviewContent.wsLargeRadius : overviewContent.wsBorderRadius
                            topRightRadius: isAtRight && isAtTop ? overviewContent.wsLargeRadius : overviewContent.wsBorderRadius
                            bottomLeftRadius: isAtLeft && isAtBottom ? overviewContent.wsLargeRadius : overviewContent.wsBorderRadius
                            bottomRightRadius: isAtRight && isAtBottom ? overviewContent.wsLargeRadius : overviewContent.wsBorderRadius
                                    color: wsCellMouse.containsMouse
                                        ? Qt.rgba(1, 1, 1, 0.08)
                                        : Qt.rgba(1, 1, 1, 0.03)
                                    border.width: isActive ? 2 : 1
                                    border.color: isActive
                                        ? "#73d4ff"
                                        : (wsCellMouse.containsMouse ? Qt.rgba(0.85, 0.96, 1, 0.3) : Qt.rgba(1, 1, 1, 0.08))

                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    // Workspace number label
                                    Text {
                                        anchors.centerIn: parent
                                        text: wsCell.wsId
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: wsCell.isActive ? "#73d4ff" : rootWidget.walColors.special.foreground
                                        opacity: {
                                            // Check if this workspace has windows
                                            var windows = overviewContent.getWindowsForWorkspace(wsCell.wsId);
                                            if (windows.length > 0) return 0.3;
                                            return wsCell.isActive ? 0.9 : 0.4;
                                        }
                                        z: 0
                                    }

                                    // Window thumbnails inside this workspace
                                    Repeater {
                                        model: {
                                            return overviewContent.getWindowsForWorkspace(wsCell.wsId);
                                        }

                                        delegate: Rectangle {
                                            id: windowTile
                                            required property var modelData

                                            readonly property real winScale: overviewContent.wsScale
                                            readonly property real winW: Math.max(30, (modelData.size ? modelData.size[0] : 200) * winScale)
                                            readonly property real winH: Math.max(22, (modelData.size ? modelData.size[1] : 120) * winScale)
                                            readonly property real winX: {
                                                if (!modelData.at) return 4;
                                                var monX = 0;
                                                for (var i = 0; i < overviewContent.monitorList.length; i++) {
                                                    if (overviewContent.monitorList[i].id === modelData.monitor) {
                                                        monX = overviewContent.monitorList[i].x;
                                                        break;
                                                    }
                                                }
                                                return Math.max(2, (modelData.at[0] - monX) * winScale);
                                            }
                                            readonly property real winY: {
                                                if (!modelData.at) return 4;
                                                var monY = 0;
                                                for (var i = 0; i < overviewContent.monitorList.length; i++) {
                                                    if (overviewContent.monitorList[i].id === modelData.monitor) {
                                                        monY = overviewContent.monitorList[i].y;
                                                        break;
                                                    }
                                                }
                                                return Math.max(2, (modelData.at[1] - monY) * winScale);
                                            }
                                            readonly property string iconName: modelData.class || modelData.initialClass || ""

                                            x: Math.min(winX, wsCell.width - winW - 2)
                                            y: Math.min(winY, wsCell.height - winH - 2)
                                            width: Math.min(winW, wsCell.width - 4)
                                            height: Math.min(winH, wsCell.height - 4)
                                            radius: 6
                                            color: windowTileMouse.containsMouse
                                                ? Qt.rgba(0.5, 0.6, 0.9, 0.3)
                                                : Qt.rgba(0.3, 0.35, 0.5, 0.35)
                                            border.width: windowTileMouse.containsMouse ? 1 : 0
                                            border.color: Qt.rgba(0.7, 0.8, 1, 0.3)
                                            clip: true
                                            z: modelData.focusHistoryID === 0 ? 2 : 1

                                            Behavior on color { ColorAnimation { duration: 120 } }

                                            // Window class label (shown when window is small)
                                            Text {
                                                anchors.centerIn: parent
                                                text: {
                                                    var cls = windowTile.iconName;
                                                    if (!cls) return "?";
                                                    // Shorten long names
                                                    if (cls.length > 8) return cls.substring(0, 6) + "…";
                                                    return cls;
                                                }
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: Math.max(7, Math.min(9, windowTile.height * 0.35))
                                                font.weight: Font.Medium
                                                color: "#ffffff"
                                                opacity: 0.7
                                                visible: windowTile.width < 60 || windowTile.height < 40
                                                z: 2
                                            }

                                            // Live window preview
                                            ScreencopyView {
                                                id: screencopyView
                                                anchors.fill: parent
                                                captureSource: {
                                                    if (!ToplevelManager.toplevels) return null;
                                                    var vals = ToplevelManager.toplevels.values;
                                                    var targetAddr = String(windowTile.modelData.address).toLowerCase();
                                                    for (var i = 0; i < vals.length; i++) {
                                                        var t = vals[i];
                                                        if (!t || !t.HyprlandToplevel) continue;
                                                        var raw = String(t.HyprlandToplevel.address || "");
                                                        var addr = raw.startsWith("0x") ? raw.toLowerCase() : ("0x" + raw).toLowerCase();
                                                        if (addr === targetAddr) {
                                                            return t;
                                                        }
                                                    }
                                                    return null;
                                                }
                                                live: rootWidget.overviewOpen
                                                constraintSize: Qt.size(Math.max(1, Math.round(windowTile.width)), Math.max(1, Math.round(windowTile.height)))
                                                visible: captureSource !== null && windowTile.width >= 40
                                                opacity: 0.95
                                            }

                                            // App icon for larger windows (fallback)
                                            Image {
                                                anchors.centerIn: parent
                                                visible: windowTile.width >= 60 && windowTile.height >= 40 && !screencopyView.visible
                                                source: {
                                                    var name = windowTile.iconName;
                                                    if (!name) return "";
                                                    return "image://icon/" + name;
                                                }
                                                width: Math.min(24, windowTile.width * 0.5, windowTile.height * 0.5)
                                                height: width
                                                sourceSize: Qt.size(width, height)
                                                smooth: true
                                                mipmap: true
                                                opacity: 0.85
                                                z: 1
                                            }

                                            MouseArea {
                                                id: windowTileMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                                onClicked: (mouse) => {
                                                    if (mouse.button === Qt.MiddleButton) {
                                                        // Middle-click to close
                                                        Hyprland.dispatch("hl.dsp.window.close({window = \"address:" + windowTile.modelData.address + "\"})");
                                                        overviewContent.reload();
                                                    } else {
                                                        // Left-click to focus
                                                        Hyprland.dispatch("hl.dsp.focus({window = \"address:" + windowTile.modelData.address + "\"})");
                                                        if (rootWidget.overviewOpen)
                                                            rootWidget.toggleOverview();
                                                    }
                                                }
                                            }

                                            // Title on hover
                                            Rectangle {
                                                visible: windowTileMouse.containsMouse && windowTile.width >= 40
                                                anchors.bottom: parent.bottom
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.bottomMargin: 2
                                                width: Math.min(titleText.implicitWidth + 8, parent.width - 4)
                                                height: titleText.implicitHeight + 4
                                                radius: 4
                                                color: Qt.rgba(0, 0, 0, 0.7)

                                                Text {
                                                    id: titleText
                                                    anchors.centerIn: parent
                                                    text: {
                                                        var t = windowTile.modelData.title || windowTile.iconName || "Window";
                                                        if (t.length > 20) return t.substring(0, 18) + "…";
                                                        return t;
                                                    }
                                                    font.family: "JetBrains Mono"
                                                    font.pixelSize: 7
                                                    color: "#ffffff"
                                                    opacity: 0.9
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: wsCellMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        z: -1  // Behind window tiles
                                        onClicked: {
                                            Hyprland.dispatch("hl.dsp.focus({workspace = " + wsCell.wsId + "})");
                                            if (rootWidget.overviewOpen)
                                                rootWidget.toggleOverview();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
