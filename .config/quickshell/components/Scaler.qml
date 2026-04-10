import QtQuick

QtObject {
    id: root
    property real currentWidth: 1920
    readonly property real baseScale: currentWidth / 1920.0
}
