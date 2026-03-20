import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Rectangle {
    id: root
    property var walColors: null

    property string netType: "none"
    property string netName: "Disconnected"
    

    Layout.preferredHeight: 40
    Layout.preferredWidth: Math.max(100, row.implicitWidth + 30)
    radius: height / 2
    color: root.walColors ? root.walColors.special.background : "#1c1e26"

    Process {
        id: netProc
        command: ["bash", "-c", "nmcli -t -f TYPE,NAME connection show --active | grep -E 'wireless|ethernet' | head -n 1"]
        stdout: SplitParser {
            onRead: function(line) {
                var parts = line.split(":");
                if (parts.length >= 2) {
                    var t = parts[0];
                    root.netName = parts.slice(1).join(":");
                    if (t.indexOf("wireless") !== -1) root.netType = "wifi";
                    else if (t.indexOf("ethernet") !== -1) root.netType = "eth";
                    else root.netType = "none";
                }
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: netProc.running = true
        Component.onCompleted: netProc.running = true
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Text {
            text: root.netType === "wifi" ? "󰤨" : (root.netType === "eth" ? "󰈀" : "󰤮")
            color: root.walColors ? root.walColors.colors.color5 : "#c678dd"
            font.family: "JetBrainsMono Nerd Fonts Mono"
            font.pixelSize: 15
        }

        Text {
            text: root.netName
            color: root.walColors ? root.walColors.special.foreground : "#ebdbb2"
            font.family: "JetBrainsMono Nerd Fonts Mono"
            font.pixelSize: 13
            font.weight: Font.Bold
        }
    }
}
