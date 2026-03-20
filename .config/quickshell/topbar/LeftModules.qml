import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
    id: root
    
    // Performance Fix: Avoid resizing the OS window on every frame during workspace animations.
    property real targetImplicitWidth: layout.implicitWidth + 20
    property real currentImplicitWidth: targetImplicitWidth

    implicitWidth: currentImplicitWidth
    implicitHeight: 50

    Timer {
        id: shrinkTimer
        interval: 500 // Wait longer before shrinking to avoid jitter
        onTriggered: root.currentImplicitWidth = root.targetImplicitWidth
    }

    onTargetImplicitWidthChanged: {
        if (targetImplicitWidth > currentImplicitWidth) {
            // Expansion: Resize IMMEDIATELY with a large buffer.
            // This prevents the window from resizing during the animation.
            currentImplicitWidth = targetImplicitWidth + 100;
            shrinkTimer.stop();
        } else {
            // Shrinking: Debounce the window resize.
            shrinkTimer.restart();
        }
    }
    
    // Load colors from cache
    property var walColors: null


    RowLayout {
        id: layout
        anchors {
            top: parent.top
            left: parent.left
            bottom: parent.bottom
            topMargin: 10
            bottomMargin: 5
            leftMargin: 10
        }
        spacing: 12

        // ── Launcher Module ──────────────────────────────────────────────────
        Rectangle {
            id: launcher
            Layout.preferredHeight: 40
            Layout.preferredWidth: 60
            radius: height / 2
            color: root.walColors.special.background

            Text {
                anchors.centerIn: parent
                // Add a little padding to the left to match the icon perfectly
                anchors.horizontalCenterOffset: 1
                text: "󰣇"
                color: "#1793d1" // Arch Linux Blue
                font.pixelSize: 30
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Quickshell.execDetached ({
                        command: ["bash", "-c", "~/.config/hypr/scripts_hypr/launcher.sh"]
                    });
                }
            }
        }

        // ── Workspaces Module ────────────────────────────────────────────────
        Rectangle {
            id: workspacesRect
            Layout.preferredHeight: 40
            // Width auto-grows based on content
            Layout.preferredWidth: workspacesRow.implicitWidth + 20
            radius: height / 2
            color: root.walColors.special.background

            RowLayout {
                id: workspacesRow
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 10
                    rightMargin: 10
                }
                spacing: 8

                Repeater {
                    id: wsRepeater
                    
                    // Filter down to only valid active workspaces + special workspaces
                    model: {
                        let activeWorkspaces = Hyprland.workspaces.values.slice().filter(ws => ws.name !== "special:scratchpad"); // optional filter
                        
                        // Sort so that numbered workspaces come first sequentially, then specials at the end
                        activeWorkspaces.sort((a, b) => {
                            if (a.id > 0 && b.id > 0) return a.id - b.id;
                            if (a.id < 0 && b.id > 0) return 1;
                            if (a.id > 0 && b.id < 0) return -1;
                            return a.id - b.id;
                        });
                        return activeWorkspaces;
                    }

                    delegate: Rectangle {
                        id: wsDelegate
                        property bool isActive: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === modelData.id
                        property bool isSpecial: modelData.name.startsWith("special:")
                        property bool isUrgent: modelData.urgent
                        property string displayName: isSpecial ? modelData.name.replace("special:", "") : modelData.name

                        Layout.preferredHeight: 24
                        Layout.preferredWidth: 24 // Initial/fallback
                        radius: height / 2

                        // Use states for robust visual management
                        state: {
                            if (isActive) return "active";
                            if (isUrgent) return "urgent";
                            if (isSpecial) return "special";
                            if (wsMouse.containsMouse) return "hover";
                            return "default";
                        }

                        states: [
                            State {
                                name: "active"
                                PropertyChanges { target: wsDelegate; color: root.walColors.colors.color1; Layout.preferredWidth: Math.max(60, wsText.implicitWidth + 20); opacity: 1.0 }
                            },
                            State {
                                name: "urgent"
                                PropertyChanges { target: wsDelegate; color: root.walColors.colors.color3; Layout.preferredWidth: 50; opacity: 1.0 }
                            },
                            State {
                                name: "special"
                                PropertyChanges { target: wsDelegate; color: root.walColors.colors.color1; Layout.preferredWidth: Math.max(50, wsText.implicitWidth + 20); opacity: 1.0 }
                            },
                            State {
                                name: "hover"
                                PropertyChanges { target: wsDelegate; color: root.walColors.colors.color5; Layout.preferredWidth: Math.max(50, wsText.implicitWidth + 16); opacity: 1.0 }
                            },
                            State {
                                name: "default"
                                PropertyChanges { target: wsDelegate; color: root.walColors.colors.color5; Layout.preferredWidth: 24; opacity: 1.0 }
                            }
                        ]

                        transitions: [
                            Transition {
                                from: "*"; to: "*"
                                ColorAnimation { duration: 250 }
                                NumberAnimation { properties: "Layout.preferredWidth"; duration: 250; easing.type: Easing.OutQuint }
                                NumberAnimation { properties: "opacity"; duration: 250 }
                            }
                        ]

                        // Pulsing overlay for urgency
                        SequentialAnimation {
                            id: pulseAnim
                            running: wsDelegate.state === "urgent"
                            loops: Animation.Infinite
                            NumberAnimation { target: wsDelegate; property: "opacity"; from: 1.0; to: 0.6; duration: 800; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: wsDelegate; property: "opacity"; from: 0.6; to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                        }

                        Text {
                            id: wsText
                            anchors.centerIn: parent
                            text: parent.displayName
                            visible: parent.isActive || parent.isSpecial || parent.isUrgent || wsMouse.containsMouse
                            color: "#FFFFFF"
                            font.family: "JetBrainsMono Nerd Fonts Mono"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            opacity: apparentVisible ? 1.0 : 0.0
                            property bool apparentVisible: visible
                            
                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }
                        }

                        MouseArea {
                            id: wsMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                if (parent.isSpecial) {
                                    Hyprland.dispatch("togglespecialworkspace " + parent.displayName);
                                } else {
                                    Hyprland.dispatch("workspace " + modelData.name);
                                }
                            }
                        }
                    }
                }
            }
        }

        CavaModule {
            walColors: root.walColors
        }
    }
}
