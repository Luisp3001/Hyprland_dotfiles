import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    property var walColors: null
    
    implicitWidth: layout.implicitWidth + 25
    implicitHeight: 40
    radius: height / 2
    color: root.walColors ? root.walColors.special.background : "#1c1e26"

    property var barValues: []
    property int barWidth: 10
    property int barCount: 12

    Component.onCompleted: {
        var initial = [];
        for (var i = 0; i < root.barCount; i++) initial.push(0);
        root.barValues = initial;
    }

    Process {
        id: cavaProc
        command: ["cava", "-p", Quickshell.env("HOME") + "/.config/quickshell/cava.conf"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                var parts = line.trim().split(/[ ;]/);
                var newValues = [];
                for (var i = 0; i < parts.length; i++) {
                    var val = parseInt(parts[i]);
                    if (!isNaN(val)) {
                        newValues.push(val);
                    }
                }
                
                // Only update if we have at least some data
                if (newValues.length > 0) {
                    // Update our internal values, padding if necessary
                    var updated = [];
                    for (var j = 0; j < root.barCount; j++) {
                        updated.push(j < newValues.length ? newValues[j] : 0);
                    }
                    root.barValues = updated;
                }
            }
        }
    }

    Row {
        id: layout
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 8
        spacing: -2
        height: 25 // Fixed height for bars to align against
        
        Repeater {
            model: root.barCount
            delegate: Rectangle {
                width: root.barWidth
                height: 2 + (root.barValues && root.barValues.length > index ? (root.barValues[index] / 100) * 22 : 0)
                radius: 2
                color: root.walColors ? root.walColors.colors.color4 : "#89b4fa"
                anchors.bottom: parent.bottom
                
                Behavior on height {
                    NumberAnimation { duration: 60; easing.type: Easing.OutSine }
                }
            }
        }
    }
}
