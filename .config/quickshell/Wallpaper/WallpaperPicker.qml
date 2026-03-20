import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// WallpaperPicker – standalone component (no ShellRoot).
// Emits closed() instead of calling Qt.quit().
QtObject {
    id: root

    signal closed()
    property bool active: false

    onActiveChanged: {
        if (active) {
            // Reset state for fresh open
            pickerWindow.initialFocusSet = false;
            pickerWindow.processFinished = false;
            pickerWindow.targetWallName = "";
            pickerWindow.targetWallIndex = 0;
            currentWallProcess.running = true;
        }
    }

    property var currentWallProcess: Process {
        command: ["bash", "-c", "swww query | grep 'currently displaying' | sed -E 's/.*image: (.*)/\\1/' || true"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split('/');
                let name = parts[parts.length - 1];
                if (name) {
                    pickerWindow.targetWallName = name;
                }
            }
        }
        onExited: {
            pickerWindow.processFinished = true;
            pickerWindow.tryFocus();
        }
    }

    property var pickerWindow: PanelWindow {
        color: "transparent"
        visible: root.active

        WlrLayershell.namespace: "wallpaper-picker"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Allows receiving keyboard focus to use navigation shortcuts
        focusable: true

        // -------------------------------------------------------------------------
        // PROPERTIES
        // -------------------------------------------------------------------------
        property int targetWallIndex: 0
        property bool initialFocusSet: false
        property string targetWallName: ""
        property bool processFinished: false

        readonly property string homeDir: "file://" + Quickshell.env("HOME")
        readonly property string thumbDir: homeDir + "/.cache/wallpaper"
        readonly property string srcDir: Quickshell.env("HOME") + "/dotfiles/wallpaper"

        readonly property string swwwCommand: "swww img '%1' --transition-type %2 --transition-pos 0.5,0.5 --transition-fps 144 --transition-duration 2"

        readonly property var transitions: ["wave"]

        readonly property int itemWidth: 300
        readonly property int itemHeight: 420
        readonly property int borderWidth: 3
        readonly property int wpSpacing: 15
        readonly property real skewFactor: -0.35

        function tryFocus() {
            if (!initialFocusSet && processFinished) {
                let foundIndex = -1;

                if (targetWallName !== "" && targetWallIndex === 0) {
                    for (let i = 0; i < view.count; i++) {
                        let fname = folderModel.get(i, "fileName");
                        if (fname === targetWallName || fname === "000_" + targetWallName) {
                            foundIndex = i;
                            break;
                        }
                    }
                }

                if (foundIndex !== -1) {
                    view.currentIndex = foundIndex;
                    view.positionViewAtIndex(foundIndex, ListView.Center);
                    initialFocusSet = true;
                } else if (targetWallIndex > 0 && view.count > targetWallIndex) {
                    view.currentIndex = targetWallIndex;
                    view.positionViewAtIndex(targetWallIndex, ListView.Center);
                    initialFocusSet = true;
                } else if (folderModel.status === FolderListModel.Ready && view.count > 0) {
                    let safeIndex = Math.min(targetWallIndex, view.count - 1);
                    view.currentIndex = safeIndex;
                    view.positionViewAtIndex(safeIndex, ListView.Center);
                    initialFocusSet = true;
                }
            }
        }

        Shortcut { sequence: "Left"; onActivated: view.decrementCurrentIndex() }
        Shortcut { sequence: "Right"; onActivated: view.incrementCurrentIndex() }
        Shortcut { sequence: "Return"; onActivated: { if (view.currentItem) view.currentItem.pickWallpaper() } }
        Shortcut { sequence: "Escape"; onActivated: root.closed() }

        // -------------------------------------------------------------------------
        // CONTENT
        // -------------------------------------------------------------------------
        ListView {
            id: view
            anchors.fill: parent
            anchors.margins: 0

            spacing: pickerWindow.wpSpacing
            orientation: ListView.Horizontal
            clip: false

            cacheBuffer: 2000

            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: (width / 2) - (pickerWindow.itemWidth / 2)
            preferredHighlightEnd: (width / 2) + (pickerWindow.itemWidth / 2)

            highlightMoveDuration: pickerWindow.initialFocusSet ? 300 : 0

            focus: true

            onCountChanged: pickerWindow.tryFocus()

            model: FolderListModel {
                id: folderModel
                folder: pickerWindow.thumbDir
                nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif"]
                showDirs: false
                sortField: FolderListModel.Name

                onStatusChanged: pickerWindow.tryFocus()
            }

            delegate: Item {
                id: delegateRoot
                width: pickerWindow.itemWidth
                height: view.height

                readonly property bool isCurrent: ListView.isCurrentItem
                readonly property bool isVideo: fileName.startsWith("000_")

                z: isCurrent ? 10 : 1

                function pickWallpaper() {
                    let cleanName = fileName
                    if (cleanName.startsWith("000_")) {
                        cleanName = cleanName.substring(4)
                    }

                    const originalFile = pickerWindow.srcDir + "/" + cleanName

                    if (isVideo) {
                         const finalCmd = pickerWindow.mpvCommand.arg(originalFile)
                         Quickshell.execDetached(["bash", "-c", finalCmd])
                    } else {
                         const randomTransition = pickerWindow.transitions[Math.floor(Math.random() * pickerWindow.transitions.length)]
                         const finalCmd = pickerWindow.swwwCommand.arg(originalFile).arg(randomTransition)
                         Quickshell.execDetached(["bash", "-c", finalCmd])
                    }

                    // Update colors
                    const postCmd = "sleep 2 && /home/luisp/.config/hypr/scripts_hypr/update_color.sh"
                    Quickshell.execDetached(["bash", "-c", postCmd])
                    root.closed()
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        view.currentIndex = index
                        delegateRoot.pickWallpaper()
                    }
                }

                Item {
                    anchors.centerIn: parent
                    width: pickerWindow.itemWidth
                    height: pickerWindow.itemHeight

                    scale: delegateRoot.isCurrent ? 1.15 : 0.95
                    opacity: delegateRoot.isCurrent ? 1.0 : 0.6

                    Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
                    Behavior on opacity { NumberAnimation { duration: 500 } }

                    transform: Matrix4x4 {
                        property real s: pickerWindow.skewFactor
                        matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                    }

                    Image {
                        anchors.fill: parent
                        source: fileUrl
                        sourceSize: Qt.size(1, 1)
                        fillMode: Image.Stretch
                        visible: true

                        asynchronous: true
                    }

                    Item {
                        anchors.fill: parent
                        anchors.margins: pickerWindow.borderWidth

                        Rectangle { anchors.fill: parent; color: "black" }
                        clip: true

                        Image {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: -50

                            width: parent.width + (parent.height * Math.abs(pickerWindow.skewFactor)) + 50
                            height: parent.height

                            fillMode: Image.PreserveAspectCrop
                            source: fileUrl

                            asynchronous: true

                            transform: Matrix4x4 {
                                property real s: -pickerWindow.skewFactor
                                matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                            }
                        }

                        Rectangle {
                            visible: delegateRoot.isVideo
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 10

                            width: 32
                            height: 32
                            radius: 6
                            color: "#60000000"

                            transform: Matrix4x4 {
                                property real s: -pickerWindow.skewFactor
                                matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                            }

                            Canvas {
                                anchors.fill: parent
                                anchors.margins: 8
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.fillStyle = "#EEFFFFFF";
                                    ctx.beginPath();
                                    ctx.moveTo(4, 0);
                                    ctx.lineTo(14, 8);
                                    ctx.lineTo(4, 16);
                                    ctx.closePath();
                                    ctx.fill();
                                }
                            }
                        }
                    }
                }
            }
        }

        Component.onCompleted: {
            view.forceActiveFocus();
        }
    }
}
