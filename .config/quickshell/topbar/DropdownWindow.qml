import Quickshell
import QtQuick
import QtQuick.Layouts

PopupWindow {
  id: menuRoot
  default property alias content: menuMouseArea.data

  // Pywal colors — passed from parent
  property var walColors: null

  // Background & shape
  readonly property color surfaceColor: walColors ? walColors.special.background : "#1c1e26"
  color: "transparent"

  // Anchor configuration — parent must set these
  required property var window
  anchor.window: window
  anchor.edges: Edges.Top

  // Positioning
  property real anchorX: 0
  anchor.rect.x: anchorX
  anchor.rect.y: window ? window.height + 8 : 0

  // Auto-hide timer when mouse leaves
  Timer {
    id: hideTimer
    interval: 800
    running: false
    repeat: false
    onTriggered: menuRoot.visible = false
  }

  // Expose hideTimer so parent can restart it
  property alias autoHideTimer: hideTimer

  MouseArea {
    id: menuMouseArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    propagateComposedEvents: true
    preventStealing: true

    onEntered: hideTimer.stop()
    onExited: hideTimer.restart()

    Rectangle {
      anchors.fill: parent
      color: menuRoot.surfaceColor
      radius: 12
    }
  }
}