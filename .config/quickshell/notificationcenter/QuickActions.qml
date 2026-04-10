import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// QuickActions – Windows-style 2×3 toggle grid + volume/brightness sliders.
// Designed to be embedded inside the NotificationCenter panel or NotificationBubble.
Item {
    id: root

    // ── Wal colors passed in from parent ─────────────────────────────────
    required property var walColors

    // ── DND state (bound from shell) ─────────────────────────────────────
    property bool dndEnabled: false

    // ── State ────────────────────────────────────────────────────────────
    property bool active: false
    property bool wifiOn: true
    property bool bluetoothOn: false
    property bool airplaneOn: false
    property string powerProfile: "balanced" // balanced | power-saver | performance

    // ── Hardware availability ────────────────────────────────────────────
    property bool wifiAvailable: false
    property bool bluetoothAvailable: false
    property bool brightnessAvailable: false
    property bool powerProfileAvailable: false

    // ── Volume/Brightness values ─────────────────────────────────────────
    property real volumeValue: 0.5
    property real brightnessValue: 1.0
    property real brightnessMax: 1.0

    // ── Poll timer ───────────────────────────────────────────────────────
    property var _stateTimer: Timer {
        interval: 2000
        running: root.active
        repeat: true
        onTriggered: {
            if (root.wifiAvailable) wifiStateProc.running = true;
            if (root.bluetoothAvailable) btStateProc.running = true;
            if (root.powerProfileAvailable) powerProfileStateProc.running = true;
            volumeGetProc.running = true;
            if (root.brightnessAvailable) brightnessGetProc.running = true;
        }
    }

    // ── Hardware detection (run once on active) ──────────────────────────
    property var _detectWifi: Process {
        command: ["sh", "-c", "nmcli radio wifi 2>/dev/null | grep -q 'enabled' && echo '__OK__'"]
        stdout: SplitParser {
            onRead: function(line) {
                if (line.trim() === "__OK__") root.wifiAvailable = true;
                else if (line.trim() === "enabled") root.wifiOn = true;
                else if (line.trim() === "disabled") root.wifiOn = false;
            }
        }
    }

    property var _detectBt: Process {
        command: ["sh", "-c", "bluetoothctl show 2>/dev/null | grep -q 'Powered' && echo '__OK__'"]
        stdout: SplitParser {
            onRead: function(line) {
                if (line.trim() === "__OK__") root.bluetoothAvailable = true;
            }
        }
    }

    property var _detectBrightness: Process {
        command: ["sh", "-c", "ls /sys/class/backlight/*/brightness 2>/dev/null && echo '__OK__'"]
        stdout: SplitParser {
            onRead: function(line) {
                if (line.trim() === "__OK__") root.brightnessAvailable = true;
            }
        }
    }

    property var _detectPowerProfile: Process {
        command: ["sh", "-c", "powerprofilesctl list 2>/dev/null && echo '__OK__'"]
        stdout: SplitParser {
            onRead: function(line) {
                if (line.trim() === "__OK__") root.powerProfileAvailable = true;
            }
        }
    }

    // ── State polling processes ───────────────────────────────────────────
    property var wifiStateProc: Process {
        command: ["sh", "-c", "nmcli radio wifi"]
        stdout: SplitParser {
            onRead: function(line) {
                root.wifiOn = line.trim() === "enabled";
            }
        }
    }

    property var btStateProc: Process {
        command: ["sh", "-c", "bluetoothctl show 2>/dev/null | grep 'Powered' | awk '{print $2}'"]
        stdout: SplitParser {
            onRead: function(line) {
                root.bluetoothOn = line.trim() === "yes";
            }
        }
    }

    property var powerProfileStateProc: Process {
        command: ["sh", "-c", "powerprofilesctl get"]
        stdout: SplitParser {
            onRead: function(line) {
                root.powerProfile = line.trim();
            }
        }
    }

    property var volumeGetProc: Process {
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: function(line) {
                var match = line.match(/Volume:\s*([\d.]+)/);
                if (match) root.volumeValue = parseFloat(match[1]);
            }
        }
    }

    property var brightnessGetProc: Process {
        command: ["sh", "-c", "cat $(ls /sys/class/backlight/*/brightness | head -1) && echo '___SEP___' && cat $(ls /sys/class/backlight/*/max_brightness | head -1)"]
        property var _vals: []
        stdout: SplitParser {
            onRead: function(line) {
                if (line.trim() === "___SEP___") return;
                brightnessGetProc._vals.push(parseInt(line.trim()));
                if (brightnessGetProc._vals.length >= 2) {
                    root.brightnessValue = brightnessGetProc._vals[0];
                    root.brightnessMax = Math.max(1, brightnessGetProc._vals[1]);
                    brightnessGetProc._vals = [];
                }
            }
        }
    }

    // ── Toggle processes ─────────────────────────────────────────────────
    property var _wifiToggle: Process {
        property bool _turnOn: false
        command: ["nmcli", "radio", "wifi", _turnOn ? "on" : "off"]
        onRunningChanged: { if (!running) wifiStateProc.running = true; }
    }

    property var _btToggle: Process {
        property bool _turnOn: false
        command: ["bluetoothctl", "power", _turnOn ? "on" : "off"]
        onRunningChanged: { if (!running) btStateProc.running = true; }
    }

    property var _airplaneToggle: Process {
        property bool _block: false
        command: ["rfkill", _block ? "block" : "unblock", "all"]
        onRunningChanged: {
            if (!running) {
                if (root.wifiAvailable) wifiStateProc.running = true;
                if (root.bluetoothAvailable) btStateProc.running = true;
            }
        }
    }

    property var _powerProfileSet: Process {
        property string _profile: "balanced"
        command: ["powerprofilesctl", "set", _profile]
        onRunningChanged: { if (!running) powerProfileStateProc.running = true; }
    }

    property var _volumeSet: Process {
        property string _vol: "0.5"
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", _vol]
    }

    property var _brightnessSet: Process {
        property string _val: "50"
        command: ["brightnessctl", "set", _val]
    }

    // ── Power (wlogout) ──────────────────────────────────────────────────
    property var _wlogout: Process {
        command: ["qs", "ipc", "call", "shell", "togglePowerMenu"]
    }
    property var _wlogout1: Process {
        command: ["qs", "ipc", "call", "shell", "toggleNotifCenter"]
    }

    // ── Layout ───────────────────────────────────────────────────────────
    property string activeMenu: "" // "" = main, "power" = power profile switch
    implicitHeight: Math.max(mainColumn.implicitHeight, activeMenu === "power" ? powerMenu.implicitHeight : 0)

    onActiveChanged: {
        if (active) {
            // Run hardware detection
            _detectWifi.running = true;
            _detectBt.running = true;
            _detectBrightness.running = true;
            _detectPowerProfile.running = true;
            // Initial state fetch
            volumeGetProc.running = true;
            root.activeMenu = ""; // Reset menu state on open
        }
    }

    ColumnLayout {
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 10
        opacity: root.activeMenu === "" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        // ── 2×3 Quick Action Grid ───────────────────────────────────────
        Grid {
            id: actionGrid
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 8
            columnSpacing: 8

            property real tileWidth: (mainColumn.width - (columns - 1) * columnSpacing) / columns

            // ── Wi-Fi ────────────────────────────────────────────────────
            ActionTile {
                tileWidth: actionGrid.tileWidth
                height: 42
                label: "Wi-Fi"
                subLabel: root.wifiOn ? "On" : "Off"
                iconSource: root.wifiOn ? "../assets/icons/wifi.svg" : "../assets/icons/no_wifi.svg"
                isOn: root.wifiOn
                available: root.wifiAvailable
                walColors: root.walColors
                onToggled: {
                    root._wifiToggle._turnOn = !root.wifiOn;
                    root._wifiToggle.running = true;
                }
            }

            // ── Bluetooth ────────────────────────────────────────────────
            ActionTile {
                tileWidth: actionGrid.tileWidth
                height: 42
                label: "Bluetooth"
                subLabel: root.bluetoothOn ? "On" : "Off"
                iconSource: root.bluetoothOn ? "../assets/icons/bluetooth_on.svg" : "../assets/icons/blueetooth_disable.svg"
                isOn: root.bluetoothOn
                available: root.bluetoothAvailable
                walColors: root.walColors
                onToggled: {
                    root._btToggle._turnOn = !root.bluetoothOn;
                    root._btToggle.running = true;
                }
            }

            // ── Airplane Mode ────────────────────────────────────────────
            ActionTile {
                tileWidth: actionGrid.tileWidth
                height: 42
                label: "Airplane"
                subLabel: root.airplaneOn ? "On" : "Off"
                iconSource: "../assets/icons/airplane.svg"
                isOn: root.airplaneOn
                available: root.wifiAvailable || root.bluetoothAvailable
                walColors: root.walColors
                onToggled: {
                    root.airplaneOn = !root.airplaneOn;
                    root._airplaneToggle._block = root.airplaneOn;
                    root._airplaneToggle.running = true;
                }
            }

            // ── Power Save ───────────────────────────────────────────────
            ActionTile {
                tileWidth: actionGrid.tileWidth
                height: 42
                label: "Power Mode"
                subLabel: root.powerProfile === "power-saver" ? "Saving" : (root.powerProfile === "performance" ? "Performance" : "Balanced")
                iconSource: "../assets/icons/power_opt.svg"
                isOn: root.powerProfile === "power-saver"
                available: root.powerProfileAvailable
                walColors: root.walColors
                hasArrow: true
                onArrowClicked: {
                    root.activeMenu = "power";
                }
            }

            // ── Do Not Disturb ───────────────────────────────────────────
            ActionTile {
                tileWidth: actionGrid.tileWidth
                height: 42
                label: "DND"
                subLabel: root.dndEnabled ? "On" : "Off"
                iconSource: "../assets/icons/dnd.svg"
                isOn: root.dndEnabled
                available: true
                walColors: root.walColors
                onToggled: {
                    root.dndEnabled = !root.dndEnabled;
                }
            }

            // ── Power ────────────────────────────────────────────────────
            ActionTile {
                tileWidth: actionGrid.tileWidth
                height: 42
                label: "Power Menu"
                subLabel: "Sleep/Restart"
                iconSource: "../assets/icons/power.svg"
                isOn: false
                available: true
                walColors: root.walColors
                onToggled: {
                    root._wlogout.running = true;
                    root._wlogout1.running = true;
                }
            }
        }

        // ── Volume Slider ────────────────────────────────────────────────
        SliderRow {
            Layout.fillWidth: true
            height: 38
            iconSource: "../assets/icons/speaker.svg"
            value: root.volumeValue
            maxValue: 1.0
            walColors: root.walColors
            formatText: function(v) { return Math.round(v * 100) + "%"; }
            onMoved: function(newVal) {
                root.volumeValue = newVal;
                root._volumeSet._vol = newVal.toFixed(2);
                root._volumeSet.running = true;
            }
        }

        // ── Brightness Slider (auto-hidden if no backlight) ──────────────
        SliderRow {
            Layout.fillWidth: true
            visible: root.brightnessAvailable
            iconSource: "../assets/icons/brightness.svg"
            value: root.brightnessMax > 0 ? root.brightnessValue / root.brightnessMax : 0
            maxValue: 1.0
            walColors: root.walColors
            formatText: function(v) { return Math.round(v * 100) + "%"; }
            onMoved: function(newVal) {
                var rawVal = Math.round(newVal * root.brightnessMax);
                root.brightnessValue = rawVal;
                root._brightnessSet._val = rawVal.toString();
                root._brightnessSet.running = true;
            }
        }
    }

    // ── Sub-menus ────────────────────────────────────────────────────────
    PowerProfileMenu {
        id: powerMenu
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        opacity: root.activeMenu === "power" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        
        walColors: root.walColors
        currentProfile: root.powerProfile
        onBackClicked: root.activeMenu = ""
        onProfileSelected: function(p) {
             root._powerProfileSet._profile = p;
             root._powerProfileSet.running = true;
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // ActionTile – a single toggle button in the grid
    // ═══════════════════════════════════════════════════════════════════════
    component ActionTile: Rectangle {
        id: tile
        property real tileWidth: 80
        property string label: ""
        property string subLabel: ""
        property string iconSource: ""
        property bool isOn: false
        property bool available: true
        property bool hasArrow: false
        property var walColors

        signal toggled()
        signal arrowClicked()

        width: tileWidth
        height: 64
        radius: height / 2

        color: {
            if (!available) return Qt.rgba(1, 1, 1, 0.02);
            if (isOn) return walColors.colors.color2;
            return Qt.rgba(1, 1, 1, 0.05);
        }
        border.color: {
            if (!available) return "transparent";
            if (isOn) return walColors.colors.color2;
            return Qt.rgba(1, 1, 1, 0.12);
        }
        border.width: 1

        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Main clickable area
            MouseArea {
                Layout.fillHeight: true
                Layout.fillWidth: true
                hoverEnabled: true
                cursorShape: tile.available ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: { if (tile.available) tile.toggled(); }

                Rectangle {
                    anchors.fill: parent
                    radius: tile.radius
                    color: parent.containsMouse && tile.available ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    // Straighten the right edge if there is an arrow to make it look like one piece
                    Rectangle { 
                        anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: tile.radius; 
                        color: parent.color; visible: tile.hasArrow 
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: tile.hasArrow ? 4 : 12
                    spacing: 10

                    Item {
                        Layout.alignment: Qt.AlignVCenter
                        width: 18; height: 18

                        Image {
                            id: tileIcon
                            anchors.centerIn: parent
                            source: tile.iconSource
                            sourceSize: Qt.size(18, 18)
                            visible: false
                        }

                        ColorOverlay {
                            anchors.fill: tileIcon
                            source: tileIcon
                            color: {
                                if (!tile.available) return Qt.rgba(1, 1, 1, 0.2);
                                return tile.isOn ? tile.walColors.special.background : tile.walColors.special.foreground;
                            }
                            opacity: tile.available ? 1 : 0.4
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: tile.label
                            color: {
                                if (!tile.available) return Qt.rgba(1, 1, 1, 0.2);
                                return tile.isOn ? tile.walColors.special.background : tile.walColors.special.foreground;
                            }
                            font.family: "JetBrains Mono"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            opacity: tile.available ? (tile.isOn ? 1 : 0.9) : 0.4
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: tile.subLabel
                            color: {
                                if (!tile.available) return Qt.rgba(1, 1, 1, 0.2);
                                return tile.isOn ? tile.walColors.special.background : tile.walColors.special.foreground;
                            }
                            font.family: "JetBrains Mono"
                            font.pixelSize: 9
                            opacity: tile.available ? (tile.isOn ? 0.8 : 0.6) : 0.2
                            visible: tile.subLabel !== ""
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillHeight: true
                Layout.topMargin: 16
                Layout.bottomMargin: 16
                width: 1
                color: tile.isOn ? Qt.rgba(0, 0, 0, 0.15) : Qt.rgba(1, 1, 1, 0.1)
                visible: tile.hasArrow && tile.available
            }

            // Arrow Area
            MouseArea {
                visible: tile.hasArrow
                Layout.fillHeight: true
                Layout.preferredWidth: 36
                hoverEnabled: true
                cursorShape: tile.available ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: { if (tile.available) tile.arrowClicked(); }

                Rectangle {
                    anchors.fill: parent
                    radius: tile.radius
                    color: parent.containsMouse && tile.available ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    // Straighten the left edge to connect visually
                    Rectangle { 
                        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: tile.radius; 
                        color: parent.color; visible: tile.hasArrow 
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: ">"
                    color: tile.available ? (tile.isOn ? tile.walColors.special.background : tile.walColors.special.foreground) : Qt.rgba(1, 1, 1, 0.2)
                    font.family: "JetBrains Mono"
                    font.weight: Font.Bold
                    opacity: tile.available ? (tile.isOn ? 0.8 : 0.7) : 0.3
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SliderRow – icon + slider track + value label
    // ═══════════════════════════════════════════════════════════════════════
    component SliderRow: Item {
        id: sliderRow
        property string iconSource: ""
        property real value: 0
        property real maxValue: 1.0
        property var walColors
        property var formatText: function(v) { return Math.round(v * 100) + "%"; }

        signal moved(real newVal)

        implicitHeight: 36

        RowLayout {
            anchors.fill: parent
            spacing: 10

            // Icon
            Item {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22

                Image {
                    id: sliderIcon
                    anchors.fill: parent
                    source: sliderRow.iconSource
                    sourceSize: Qt.size(22, 22)
                    visible: false
                }

                ColorOverlay {
                    anchors.fill: sliderIcon
                    source: sliderIcon
                    color: sliderRow.walColors.special.foreground
                    opacity: 0.7
                }
            }

            // Slider track
            Rectangle {
                id: sliderTrack
                Layout.fillWidth: true
                height: 6
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.08)

                Rectangle {
                    width: parent.width * Math.min(1, sliderRow.value / sliderRow.maxValue)
                    height: parent.height
                    radius: 3
                    color: sliderRow.walColors.colors.color2

                    Behavior on width { NumberAnimation { duration: 100 } }
                }

                // Thumb
                Rectangle {
                    x: Math.max(0, Math.min(parent.width - width, parent.width * (sliderRow.value / sliderRow.maxValue) - width / 2))
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16; height: 16
                    radius: 8
                    color: sliderRow.walColors.colors.color2
                    border.color: Qt.rgba(0, 0, 0, 0.3)
                    border.width: 1

                    Behavior on x { NumberAnimation { duration: 100 } }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.topMargin: -10
                    anchors.bottomMargin: -10
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    property bool dragging: false

                    onPressed: function(mouse) {
                        dragging = true;
                        updateValue(mouse.x);
                    }
                    onReleased: { dragging = false; }
                    onPositionChanged: function(mouse) {
                        if (dragging) updateValue(mouse.x);
                    }

                    function updateValue(mouseX) {
                        var ratio = Math.max(0, Math.min(1, mouseX / sliderTrack.width));
                        sliderRow.moved(ratio * sliderRow.maxValue);
                    }
                }
            }

            // Value text
            Text {
                Layout.preferredWidth: 36
                horizontalAlignment: Text.AlignRight
                text: sliderRow.formatText(sliderRow.value)
                color: sliderRow.walColors.special.foreground
                font.family: "JetBrains Mono"
                font.pixelSize: 11
                opacity: 0.6
            }
        }
    }
}
