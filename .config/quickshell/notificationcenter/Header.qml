import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import "../components" as Lib
import "../config.js" as Config

Item {
  id: root
  property bool active: true
  property QtObject theme: null
  property string profileName: Config.PROFILE_NAME
  property string profileImage: Config.PROFILE_IMG

  property bool expanded: false
  signal closeRequested()
  signal powerAction(string action, string label)

  readonly property bool _hasTheme: theme !== null
  readonly property bool _isDark: (!_hasTheme || theme.isDarkMode === undefined) ? true : theme.isDarkMode
  readonly property color _textPrimary:      theme ? theme.textPrimary      : "#d3c6aa"
  readonly property color _outline:          theme ? theme.outline          : Qt.rgba(1,1,1,0.10)
  readonly property color _subtleFill:       theme ? theme.subtleFill       : Qt.rgba(1,1,1,0.05)
  readonly property color _subtleFillHover:  theme ? theme.subtleFillHover  : Qt.rgba(1,1,1,0.15)
  readonly property color _accentRed:        theme ? theme.accentRed        : "#e67e80"

  implicitHeight: 52

  Timer {
    id: snapTimer
    interval: 320
    repeat: false
    onTriggered: Quickshell.execDetached(["bash", "-lc", "command -v grimblast >/dev/null && grimblast --notify copysave area || true"])
  }

  ColumnLayout {
      anchors.fill: parent
      spacing: 0

      RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 52
        spacing: 12

        // Profile Pic
        Item {
          width: 48; height: 48
          Layout.alignment: Qt.AlignVCenter
          Rectangle { id: pfpMask; anchors.fill: parent; radius: width/2; visible: false }
          Item {
            anchors.fill: parent; layer.enabled: root.visible; layer.smooth: true
            layer.effect: OpacityMask { maskSource: pfpMask }
            Image {
              anchors.fill: parent
              fillMode: Image.PreserveAspectCrop
              source: (root.profileImage.startsWith("file://") ? "" : "file://") + root.profileImage
              mipmap: true; smooth: true; cache: true; asynchronous: true
              sourceSize: Qt.size(256, 256)
            }
          }
          Rectangle {
            anchors.fill: parent
            radius: width/2
            color: "transparent"
            border.width: 1
            border.color: root._outline
            antialiasing: true
          }
        }

        Text {
          text: root.profileName
          font.family: theme ? theme.textFont : "Manrope"
          font.pixelSize: 18
          font.weight: 700
          color: root._textPrimary
          Layout.fillWidth: true
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideRight
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            spacing: 5

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8

                Rectangle {
                    id: pwrBtn
                    width: 40; height: 40; radius: 24
                    color: pwrTap.pressed ? root._accentRed
                          : (pwrHover.hovered ? root._accentRed : root._subtleFill)
                    border.width: 1
                    border.color: root._outline
                    scale: pwrTap.pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                      anchors.centerIn: parent
                      topPadding: 1
                      rightPadding: -1

                      text: ""
                      font.family: theme ? theme.iconFont : "JetBrainsMono Nerd Font"
                      font.pixelSize: 12
                      color: (pwrHover.hovered || pwrTap.pressed)
                      //  ACTIVE STATE (Hovered/Clicked)
                      ? (root._isDark ? "#e5e6c5" : "#e1e4bd")

                      //  INACTIVE STATE (Normal)
                      : root._accentRed
                    }

                    HoverHandler { id: pwrHover }
                    TapHandler {
                        id: pwrTap
                        onTapped: Quickshell.execDetached(["qs", "ipc", "call", "shell", "togglePowerMenu"])
                    }
                }
            }
        }
      }
  }

  Lib.CommandPoll {
      id: cpu
      running: root.active && root.visible; interval: 4000
      property var prevIdle: 0; property var prevTotal: 0
      command: ["bash","-lc","grep 'cpu ' /proc/stat"]
      parse: function(out) {
          var parts = String(out).split(/\s+/)
          var idle = Number(parts[4]) + Number(parts[5])
          var total = 0
          for (var i=1; i<parts.length; i++) total += Number(parts[i])
          var diffTotal = total - prevTotal
          var usage = (diffTotal > 0) ? (1 - ((idle - prevIdle) / diffTotal)) * 100 : 0
          prevIdle = idle; prevTotal = total
          return Math.round(usage) + "%"
      }
  }

  Lib.CommandPoll {
      id: ram
      running: root.active && root.visible; interval: 5000
      command: ["bash","-lc","awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END{ if(t>0) printf(\"%d%%\", (100-(a*100/t))); else print \"0%\" }' /proc/meminfo || true"]
      parse: function(o) { return String(o).trim() || "0%" }
  }
}
