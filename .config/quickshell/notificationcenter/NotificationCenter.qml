import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Qt5Compat.GraphicalEffects

// NotificationCenter – floating panel from the right edge.
// Toggle via:  qs ipc call shell toggleNotifCenter
QtObject {
    id: root
    required property var server
    property bool open: false
    property bool dndEnabled: false
    signal closeRequested()

    // ── Wal colors ──────────────────────────────────────────────────────
    property var jsonfile: FileView {
        readonly property string homeDir: "file://" + Quickshell.env("HOME")
        path: Qt.resolvedUrl(homeDir + "/.cache/wal/colors.json")
        watchChanges: true
        onFileChanged: this.reload()
        blockLoading: true
    }
    readonly property var walColors: JSON.parse(jsonfile.text())

    // ── Sub-components ───────────────────────────────────────────────────
    property var history: NotifHistoryModel { server: root.server }

    // ── Clock ────────────────────────────────────────────────────────────
    property string _clockTime: Qt.formatTime(new Date(), "hh:mm")
    property string _clockDate: Qt.formatDate(new Date(), "dddd, MMMM d")
    property var _clockTimer: Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root._clockTime = Qt.formatTime(new Date(), "hh:mm");
            root._clockDate = Qt.formatDate(new Date(), "dddd, MMMM d");
        }
    }

    // ── Panel window ─────────────────────────────────────────────────────
    property var window: PanelWindow {
        id: panelWindow
        color: "transparent"

        // Only show when open — this completely hides the window
        visible: root.open

        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.namespace:     "quickshell"
        WlrLayershell.layer:         WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors { top: true; horizontalCenter: true; bottom: false; left: false }
        margins.top: 48 // Just below the music widget

        implicitWidth:  800
        implicitHeight: Math.min(600, mainBg.implicitHeight + 40)

        Rectangle {
            id: mainBg
            anchors.fill: parent
            width: 780
            implicitHeight: horizontalLayout.implicitHeight + 40
            
            radius: 24
            color: Qt.tint(Qt.rgba(0, 0, 0, 0.35), Qt.alpha(root.walColors.special.background 0.15)) // Neutral translucency
            border.color: Qt.rgba(root.walColors.colors.color3.r, root.walColors.colors.color3.g, root.walColors.colors.color3.b, 0.4)
            border.width: 1.5
            clip: true

            // Emerge animation
            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.4
            transformOrigin: Item.Top

            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }

            // Subtle gradient overlay for glass depth
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: Qt.rgba(0,0,0,0.05) }
                    GradientStop { position: 0.35; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0,0,0,0.10) }
                }
            }

            // Prevent clicks inside from closing
            MouseArea { anchors.fill: parent }

            RowLayout {
                id: horizontalLayout
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20

                // ── Left Side: Clock & Quick Actions ──
                ColumnLayout {
                    Layout.preferredWidth: 280
                    Layout.fillHeight: true
                    spacing: 12

                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: root._clockTime
                            color: root.walColors.special.foreground
                            font.family: "JetBrains Mono"
                            font.pixelSize: 36
                            font.weight: Font.Bold
                        }
                        Text {
                            text: root._clockDate
                            color: root.walColors.special.foreground
                            font.family: "JetBrains Mono"
                            font.pixelSize: 12
                            opacity: 0.50
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 18
                        color: Qt.rgba(0, 0, 0, 0.20) // Darker inset background for contrast
                        border.color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 1

                        QuickActions {
                            id: quickActionsInner
                            active: root.open
                            dndEnabled: root.dndEnabled
                            anchors.centerIn: parent
                            width: parent.width - 20
                            walColors: root.walColors
                            onDndEnabledChanged: root.dndEnabled = quickActionsInner.dndEnabled
                        }
                    }
                }

                // ── Vertical Divider ──
                Rectangle {
                    Layout.fillHeight: true
                    Layout.topMargin: 10
                    Layout.bottomMargin: 10
                    width: 1
                    color: Qt.rgba(1, 1, 1, 0.08)
                }

                // ── Right: Notifications ──
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "NOTIFICATIONS"
                            color: root.walColors.special.foreground
                            font.family: "JetBrains Mono"
                            font.pixelSize: 12 // Increased font
                            font.weight: Font.Bold
                            opacity: 0.4
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "Clear all"
                            color: root.walColors.colors.color2
                            font.family: "JetBrains Mono"
                            font.pixelSize: 12 // Increased font
                            opacity: root.history.model.count > 0 ? 0.8 : 0.2
                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.history.clearAll()
                                enabled: root.history.model.count > 0
                            }
                        }
                    }

                    ListView {
                        id: notifList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: root.history.model
                        spacing: 8
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            width: notifList.width
                            height: 68 // Increased height
                            radius: 14
                            color: Qt.rgba(1, 1, 1, 0.05)
                            border.color: Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 12

                                Rectangle {
                                    width: 32; height: 32; radius: 8
                                    color: Qt.rgba(1, 1, 1, 0.1)
                                    Image {
                                        anchors.fill: parent; anchors.margins: 2
                                        source: image || ""
                                        fillMode: Image.PreserveAspectCrop
                                        visible: status === Image.Ready
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text {
                                        text: summary || "(no title)"
                                        color: root.walColors.special.foreground
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 14 // Increased font
                                        font.weight: Font.Bold
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: body || ""
                                        color: root.walColors.special.foreground
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 12 // Increased font
                                        opacity: 0.6
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    width: 25; height: 25
                                    Text { text: "✕"; color: root.walColors.special.foreground; anchors.centerIn: parent; opacity: 0.5 }
                                    onClicked: root.history.removeAt(index)
                                }
                            }
                        }

                        // Empty State
                        Text {
                            anchors.centerIn: parent
                            text: "No Notifications"
                            color: root.walColors.special.foreground
                            font.family: "JetBrains Mono"
                            font.pixelSize: 12
                            opacity: 0.3
                            visible: notifList.count === 0
                        }
                    }
                }
            }
        }
    }
