import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

Rectangle {
    id: root
    property var walColors: null

    implicitHeight: 40
    implicitWidth: Math.max(40, trayRow.implicitWidth + 24)
    radius: height / 2
    color: root.walColors.special.background
    
    visible: SystemTray.items.values.length > 0
    RowLayout {
        id: trayRow
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: SystemTray.items
            
            delegate: Item {
                width: 24
                height: 24
                
                Image {
                    id: iconImg
                    anchors.fill: parent
                    source: modelData.icon || ""
                    sourceSize: Qt.size(24, 24)
                    fillMode: Image.PreserveAspectFit
                }

                // Fallback for missing icon or error
                Text {
                    anchors.centerIn: parent
                    text: modelData.title ? modelData.title.substring(0, 1).toUpperCase() : "?"
                    color: root.walColors ? root.walColors.colors.color4 : "white"
                    font.bold: true
                    visible: !modelData.icon || iconImg.status === Image.Error || iconImg.status === Image.Null
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            modelData.activate()
                        } else if (mouse.button === Qt.RightButton) {
                            if (modelData.menu) {
                                modelData.menu.open(root.Window.window)
                            } else {
                                modelData.secondaryActivate()
                            }
                        }
                    }
                }
            }
        }
    }
}
