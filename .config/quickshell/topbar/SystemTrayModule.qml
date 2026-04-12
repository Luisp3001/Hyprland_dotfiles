import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import Quickshell.DBusMenu

Rectangle {
    id: root
    property var walColors: null
    property var panelWindow: null
    property bool isExpanded: false

    implicitHeight: 40
    implicitWidth: Math.max(40, trayRow.implicitWidth + 20)
    radius: height / 2
    color: root.walColors ? root.walColors.special.background : "#1e1e2e"
    
    visible: SystemTray.items.values.length > 0

    // ── Shared Menu Instance (outside Repeater) ──────────────────────
    // Single QsMenuOpener that gets reconfigured per-icon on right-click
    QsMenuOpener {
        id: sharedMenuOpener
        menu: null
    }

    DropdownMenu {
        id: trayMenu
        window: root.panelWindow
        walColors: root.walColors
        anchorX: 0 // Updated dynamically on right-click
        model: sharedMenuOpener.children
        
        onItemTriggered: trayMenu.visible = false
    }

    RowLayout {
        id: trayRow
        anchors.centerIn: parent
        spacing: 8

        // Botón de expansión
        Item {
            visible: SystemTray.items.values.length > 3
            width: 20
            height: 24
            
            Text {
                anchors.centerIn: parent
                font.family: "Material Design Icons"
                text: root.isExpanded ? "󰅂" : "󰅁"
                color: root.walColors ? root.walColors.colors.color4 : "white"
                font.pixelSize: 18
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.isExpanded = !root.isExpanded
                cursorShape: Qt.PointingHandCursor
            }
        }

        // Lista de iconos del system tray
        Repeater {
            model: SystemTray.items
            
            delegate: Item {
                id: sysTrayItem
                visible: SystemTray.items.values.length <= 3 || root.isExpanded
                width: 24
                height: 24

                // Renderizado de iconos
                IconImage {
                    id: iconImg
                    anchors.fill: parent
                    source: modelData.icon           
                }

                // Fallback de texto si no hay icono
                Text {
                    anchors.centerIn: parent
                    text: modelData.title ? modelData.title.substring(0, 1).toUpperCase() : "?"
                    color: root.walColors ? root.walColors.colors.color4 : "white"
                    font.bold: true
                    visible: !modelData.icon || iconImg.status === Image.Error || iconImg.status === Image.Null
                }

                // Controles de ratón
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            modelData.activate();
                        } else if (mouse.button === Qt.RightButton) {
                            if (modelData.hasMenu) {
                                // Calculate position relative to the parent window
                                var pos = sysTrayItem.mapToItem(null, 0, 0);
                                trayMenu.anchorX = pos.x;

                                // Reset menu to force QsMenuOpener to re-query DBus
                                sharedMenuOpener.menu = null;
                                sharedMenuOpener.menu = modelData.menu;

                                // Toggle the dropdown
                                trayMenu.visible = true;
                            } else {
                                modelData.secondaryActivate();
                            }
                        }
                    }
                }
            }
        }
    }
}