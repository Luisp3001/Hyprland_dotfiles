import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Rectangle {
    id: root
    property var walColors: null
    property bool onACPower: true
    property int batteryPercent: 0
    property bool isCharging: false

    Layout.preferredHeight: 40
    Layout.preferredWidth: Math.max(90, row.implicitWidth + 30)
    radius: height / 2
    color: root.walColors ? root.walColors.special.background : "#1c1e26"

    Process {
        id: batProc
        command: ["sh", "-c", "echo $(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null) $(cat /sys/class/power_supply/BAT0/status 2>/dev/null)"]
        stdout: SplitParser {
            onRead: function(line) {
                var parts = line.trim().split(/\s+/);
                if (parts.length >= 2) {
                    var cap = parseInt(parts[0]);
                    if (!isNaN(cap)) root.batteryPercent = cap;
                    root.isCharging = (parts[1] === "Charging");
                }
            }
        }
    }

    Timer {
        interval: root.onACPower ? 5000 : 30000 // Faster on AC, slower on battery
        running: true
        repeat: true
        onTriggered: batProc.running = true
        Component.onCompleted: batProc.running = true
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Text {
            id: batIcon
            text: {
                if (root.isCharging) return "󰂄";
                if (root.batteryPercent <= 10) return "󰂎";
                if (root.batteryPercent <= 20) return "󰁺";
                if (root.batteryPercent <= 30) return "󰁻";
                if (root.batteryPercent <= 40) return "󰁼";
                if (root.batteryPercent <= 50) return "󰁽";
                if (root.batteryPercent <= 60) return "󰁾";
                if (root.batteryPercent <= 70) return "󰁿";
                if (root.batteryPercent <= 80) return "󰂀";
                if (root.batteryPercent <= 90) return "󰂁";
                if (root.batteryPercent < 100) return "󰂂";
                return "󰁹";
            }
            color: {
                if (!root.walColors) return "#89b4fa";
                if (root.isCharging) return root.walColors.colors.color2; // Greenish/Cyan depending on theme
                if (root.batteryPercent <= 20) return root.walColors.colors.color1; // Red
                return root.walColors.colors.color4; // Blueish
            }
            font.family: "JetBrainsMono Nerd Fonts Mono"
            font.pixelSize: 20
        }

        Text {
            text: root.batteryPercent + "%"
            color: root.walColors ? root.walColors.special.foreground : "#ebdbb2"
            font.family: "JetBrainsMono Nerd Fonts Mono"
            font.pixelSize: 14
            font.weight: Font.Bold
        }
    }
}
