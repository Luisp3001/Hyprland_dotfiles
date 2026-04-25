import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    anchors.fill: parent
    visible: false
    focus: true

    // ── Pywal colors (passed from shell) ──────────────────────────────────
    property var walColors: null

    // Derived accent colors from pywal
    readonly property color lockColor:    walColors ? walColors.colors.color4 : "#89b4fa"   // blue
    readonly property color sleepColor:   walColors ? walColors.colors.color6 : "#94e2d5"   // teal
    readonly property color logoutColor:  walColors ? walColors.colors.color5 : "#c678dd"   // mauve
    readonly property color rebootColor:  walColors ? walColors.colors.color3 : "#f0c674"   // yellow
    readonly property color powerColor:   walColors ? walColors.colors.color1 : "#e95678"   // red
    readonly property color fgColor:      walColors ? walColors.special.foreground : "#ebdbb2"

    // ── Inline button component ──────────────────────────────────────────────

    component PowerButton: Item {
        id: btn

        required property string icon
        required property string label
        required property color baseColor
        signal activated()

        width: 140
        height: 200
        opacity: 0

        property bool hovered: false
        property bool isPressed: false

        function enter(delayMs) {
            enterDelay.interval = delayMs
            enterDelay.start()
        }

        Timer {
            id: enterDelay
            onTriggered: {
                btn.y = 100
                slideIn.restart()
            }
        }

        ParallelAnimation {
            id: slideIn
            NumberAnimation {
                target: btn; property: "opacity"
                to: 1; duration: 380; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: btn; property: "y"
                to: 0; duration: 420; easing.type: Easing.OutCubic
            }
        }

        // Shadow simulation
        Rectangle {
            anchors.horizontalCenter: rect.horizontalCenter
            anchors.verticalCenter: rect.verticalCenter
            anchors.verticalCenterOffset: btn.hovered ? 20 : 10
            width: rect.width * 0.85
            height: rect.height * 0.85
            radius: rect.radius
            color: btn.baseColor
            opacity: btn.hovered ? 0.35 : 0.2
            scale: btn.isPressed ? 0.88 : (btn.hovered ? 1.02 : 1.0)
            
            Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        }

        // Main button
        Rectangle {
            id: rect
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: btn.hovered ? -15 : 0
            width: 110
            height: 110
            radius: 34

            color: btn.baseColor
            
            // Soft gradient
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.lighter(btn.baseColor, 1.15) }
                GradientStop { position: 1.0; color: btn.baseColor }
            }

            scale: btn.isPressed ? 0.92 : 1.0
            
            Behavior on anchors.topMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            Text {
                anchors.centerIn: parent
                text: btn.icon
                font.family: "Material Design Icons"
                font.pixelSize: 48
                color: "#ffffff"
                opacity: btn.hovered ? 1.0 : 0.85
                Behavior on opacity { NumberAnimation { duration: 250 } }
                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                scale: btn.isPressed ? 0.92 : (btn.hovered ? 1.08 : 1.0)
            }
        }

        // Label
        Text {
            anchors.top: rect.bottom
            anchors.topMargin: 24
            anchors.horizontalCenter: parent.horizontalCenter
            text: btn.label.toUpperCase()
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 2.5
            color: "white"
            opacity: btn.hovered ? 0.9 : 0.4
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: btn.hovered = true
            onExited: { btn.hovered = false; btn.isPressed = false }
            onPressed: btn.isPressed = true
            onReleased: btn.isPressed = false
            onClicked: btn.activated()
        }
    }

    // ── Backdrop ─────────────────────────────────────────────────────────────

    Rectangle {
        id: backdrop
        anchors.fill: parent
        opacity: 0

        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.30) }
            GradientStop { position: 0.42; color: Qt.rgba(0, 0, 0, 0.30) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.30) }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    }

    // ── Header label ─────────────────────────────────────────────────────────

    Column {
        id: header
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: btnRow.top
        anchors.bottomMargin: 52
        spacing: 8
        opacity: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "󰐥"
            font.family: "Material Design Icons"
            font.pixelSize: 20
            color: Qt.rgba(1, 1, 1, 0.22)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "POWER MENU"
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 4.0
            color: Qt.rgba(1, 1, 1, 0.25)
        }

        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    }

    // ── Button row ──────────────────────────────────────────────────────────────

    Row {
        id: btnRow
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -20
        spacing: 30

        PowerButton {
            id: lockBtn
            icon: "󰌾"
            label: "Lock"
            baseColor: root.lockColor
            onActivated: {
                root.close()
                Quickshell.execDetached(["bash", "-c", "qs ipc call shell toggleNotifCenter && sleep 1 && hyprlock"])
            }
        }

        PowerButton {
            id: sleepBtn
            icon: "󰤄"
            label: "Sleep"
            baseColor: root.sleepColor
            onActivated: {
                root.close()
                Quickshell.execDetached(["bash", "-c", "qs ipc call shell toggleNotifCenter && sleep 1 && systemctl suspend"])
            }
        }

        PowerButton {
            id: logoutBtn
            icon: "󰍃"
            label: "Logout"
            baseColor: root.logoutColor
            onActivated: {
                root.close()
                Quickshell.execDetached(["bash", "-c", "sleep 0.35 && hyprctl dispatch exit"])
            }
        }

        PowerButton {
            id: rebootBtn
            icon: "󰜉"
            label: "Reboot"
            baseColor: root.rebootColor
            onActivated: {
                root.close()
                Quickshell.execDetached(["bash", "-c", "sleep 0.35 && systemctl reboot"])
            }
        }

        PowerButton {
            id: powerBtn
            icon: "󰐥"
            label: "Power Off"
            baseColor: root.powerColor
            onActivated: {
                root.close()
                Quickshell.execDetached(["bash", "-c", "sleep 0.35 && systemctl poweroff"])
            }
        }
    }

    // ── Hint ─────────────────────────────────────────────────────────────────

    Text {
        id: hintText
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 52
        text: "ESC TO CANCEL"
        font.pixelSize: 10
        font.letterSpacing: 2.5
        font.weight: Font.Light
        color: Qt.rgba(1, 1, 1, 0.2)
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 400 } }
    }

    // ── Hint timer ────────────────────────────────────────────────────────────

    Timer {
        id: hintDelay
        interval: 420
        onTriggered: hintText.opacity = 1
    }

    // ── Close timer ───────────────────────────────────────────────────────────

    Timer {
        id: closeTimer
        interval: 280
        onTriggered: root.visible = false
    }

    // ── Open / Close ─────────────────────────────────────────────────────────

    function open() {
        visible = true
        forceActiveFocus()

        // reset
        lockBtn.opacity   = 0
        sleepBtn.opacity  = 0
        logoutBtn.opacity = 0
        rebootBtn.opacity = 0
        powerBtn.opacity  = 0
        hintText.opacity  = 0
        header.opacity    = 0
        backdrop.opacity  = 1

        // staggered entrance
        lockBtn.enter(60)
        sleepBtn.enter(120)
        logoutBtn.enter(180)
        rebootBtn.enter(240)
        powerBtn.enter(300)

        header.opacity = 1
        hintDelay.restart()
    }

    function close() {
        backdrop.opacity = 0
        lockBtn.opacity   = 0
        sleepBtn.opacity  = 0
        logoutBtn.opacity = 0
        rebootBtn.opacity = 0
        powerBtn.opacity  = 0
        header.opacity    = 0
        hintText.opacity  = 0
        closeTimer.restart()
    }

    // ── Keyboard ──────────────────────────────────────────────────────────────

    Keys.onEscapePressed: close()
}