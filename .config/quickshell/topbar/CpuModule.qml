import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Rectangle {
    id: root
    property var walColors: null
    property real cpuPercent: 0.0
    property var _prevCpu: null

    Layout.preferredHeight: 40
    Layout.preferredWidth: Math.max(90, row.implicitWidth + 30)
    radius: height / 2
    color: root.walColors ? root.walColors.special.background : "#1c1e26"

    Process {
        id: cpuProc
        command: ["sh", "-c", "head -1 /proc/stat"]
        stdout: SplitParser {
            onRead: function(line) {
                var parts = line.trim().split(/\s+/);
                if (parts.length < 5 || parts[0] !== "cpu") return;
                var user    = parseInt(parts[1]);
                var nice    = parseInt(parts[2]);
                var system  = parseInt(parts[3]);
                var idle    = parseInt(parts[4]);
                var iowait  = parseInt(parts[5]) || 0;
                var irq     = parseInt(parts[6]) || 0;
                var softirq = parseInt(parts[7]) || 0;
                var total = user + nice + system + idle + iowait + irq + softirq;

                if (root._prevCpu !== null) {
                    var dtotal = total - root._prevCpu.total;
                    var didle  = idle  - root._prevCpu.idle;
                    if (dtotal > 0)
                        root.cpuPercent = Math.round((1 - didle / dtotal) * 100);
                }
                root._prevCpu = { total: total, idle: idle };
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: cpuProc.running = true
        Component.onCompleted: cpuProc.running = true
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Text {
            id: cpuIcon
            text: "󰈐" // Nerd Font Fan icon
            color: root.walColors ? root.walColors.colors.color3 : "#f0c674"
            font.family: "JetBrainsMono Nerd Fonts Mono"
            font.pixelSize: 20
            transformOrigin: Item.Center

            NumberAnimation on rotation {
                from: 0
                to: 360
                duration: {
                    // Base duration (100% CPU) is 400ms, Slowest (0% CPU) is 3000ms
                    var minDuration = 400;
                    var maxDuration = 3000;
                    var speedFactor = root.cpuPercent / 100;
                    return maxDuration - (speedFactor * (maxDuration - minDuration));
                }
                loops: Animation.Infinite
                running: true
            }
        }

        Text {
            text: root.cpuPercent + "%"
            color: root.walColors ? root.walColors.special.foreground : "#ebdbb2"
            font.family: "JetBrainsMono Nerd Fonts Mono"
            font.pixelSize: 14
            font.weight: Font.Bold
        }
    }
}
