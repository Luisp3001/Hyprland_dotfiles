import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// WallpaperPicker – standalone component (no ShellRoot).
// Emits closed() instead of calling Qt.quit().
QtObject {
    id: root

    property bool active: false
    property var syncThumbnailsProcess

    syncThumbnailsProcess: Process {
        command: ["/home/luisp/.config/quickshell/generate_thumbnails.sh"]
        running: false
    }

    property var currentWallProcess

    currentWallProcess: Process {
        command: ["bash", "-c", "swww query | grep 'currently displaying' | sed -E 's/.*image: (.*)/\\1/' || true"]
        onExited: {
            pickerWindow.processFinished = true;
            pickerWindow.tryFocus();
        }

        stdout: SplitParser {
            onRead: (data) => {
                let parts = data.trim().split('/');
                let name = parts[parts.length - 1];
                if (name)
                    pickerWindow.targetWallName = name;

            }
        }
    }

    property var weProcess

    weProcess: Process {
        command: ["bash", "-c", "python3 -c 'import json, glob, os; [print(json.dumps({\"id\": os.path.basename(os.path.dirname(f)), \"title\": json.load(open(f, errors=\"ignore\")).get(\"title\", \"\"), \"preview\": \"file://\" + os.path.dirname(f) + \"/\" + json.load(open(f, errors=\"ignore\")).get(\"preview\", \"\")})) for f in glob.glob(\"/home/luisp/.local/share/Steam/steamapps/workshop/content/431960/*/project.json\") if os.path.isfile(f)]'"]
        running: false

        stdout: SplitParser {
            onRead: (data) => {
                let trimmed = data.trim();
                if (trimmed.length > 0) {
                    try {
                        let item = JSON.parse(trimmed);
                        animatedModel.append(item);
                    } catch (e) {
                    }
                }
            }
        }

    }

    property var pickerWindow

    pickerWindow: PanelWindow {
        // -------------------------------------------------------------------------
        // PROPERTIES
        // -------------------------------------------------------------------------
        property int targetWallIndex: 0
        property bool initialFocusSet: false
        property string targetWallName: ""
        property bool processFinished: false
        property bool isImageTab: true
        readonly property string homeDir: "file://" + Quickshell.env("HOME")
        readonly property string thumbDir: homeDir + "/.cache/wallpaper"
        readonly property string srcDir: Quickshell.env("HOME") + "/wallpaper"
        readonly property string swwwCommand: "swww img '%1' --transition-type %2 --transition-pos 0.5,0.5 --transition-fps 144 --transition-duration 2"
        readonly property var transitions: ["wave"]
        readonly property int itemWidthExpanded: 700
        readonly property int itemWidthCollapsed: 120
        readonly property int itemHeight: 420
        readonly property int borderWidth: 3
        readonly property int wpSpacing: 6
        readonly property real skewFactor: -0.15
        readonly property color accentGold: "#C8A961"

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
                    initialFocusSet = true;
                } else if (targetWallIndex > 0 && view.count > targetWallIndex) {
                    view.currentIndex = targetWallIndex;
                    initialFocusSet = true;
                } else if (folderModel.status === FolderListModel.Ready && view.count > 0) {
                    let safeIndex = Math.min(targetWallIndex, view.count - 1);
                    view.currentIndex = safeIndex;
                    initialFocusSet = true;
                }
            }
        }

        color: "transparent"
        visible: root.active
        WlrLayershell.namespace: "wallpaper-picker"
        WlrLayershell.layer: WlrLayer.overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        // Allows receiving keyboard focus to use navigation shortcuts
        focusable: true
        Component.onCompleted: {
            view.forceActiveFocus();
        }

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Shortcut {
            sequence: "Left"
            onActivated: pickerWindow.isImageTab ? view.decrementCurrentIndex() : animatedView.decrementCurrentIndex()
        }

        Shortcut {
            sequence: "Right"
            onActivated: pickerWindow.isImageTab ? view.incrementCurrentIndex() : animatedView.incrementCurrentIndex()
        }

        Shortcut {
            sequence: "Return"
            onActivated: {
                if (pickerWindow.isImageTab && view.currentItem)
                    view.currentItem.pickWallpaper();
                else if (!pickerWindow.isImageTab && animatedView.currentItem)
                    animatedView.currentItem.pickWallpaper();
            }
        }

        Shortcut {
            sequence: "Escape"
            onActivated: root.closed()
        }

        // -------------------------------------------------------------------------
        // CONTENT
        // -------------------------------------------------------------------------
        ListModel {
            id: animatedModel
        }

        // Click outside card to dismiss
        MouseArea {
            anchors.fill: parent
            onClicked: root.closed()
        }

        // Centered card container
        Item {
            id: cardContainer
            width: Math.min(parent.width * 0.85, 1600)
            height: pickerWindow.itemHeight + 80
            anchors.centerIn: parent

            // Block clicks from passing through the card to the dismiss area
            MouseArea {
                anchors.fill: parent
                onClicked: {} // absorb
            }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 0
            spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: view

                    anchors.fill: parent
                    visible: pickerWindow.isImageTab
                    spacing: pickerWindow.wpSpacing
                    orientation: ListView.Horizontal
                    clip: false
                    cacheBuffer: 800
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    preferredHighlightBegin: (width / 2) - (pickerWindow.itemWidthExpanded / 2)
                    preferredHighlightEnd: (width / 2) + (pickerWindow.itemWidthExpanded / 2)
                    highlightMoveDuration: pickerWindow.initialFocusSet ? 350 : 0
                    focus: pickerWindow.isImageTab
                    onCountChanged: pickerWindow.tryFocus()

                    header: Item { width: (view.width - pickerWindow.itemWidthExpanded) / 2; height: 1 }
                    footer: Item { width: (view.width - pickerWindow.itemWidthExpanded) / 2; height: 1 }

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

                        readonly property bool isCurrent: ListView.isCurrentItem

                        // Edge fade opacity: items near left/right edges fade out
                        property real viewX: x - view.contentX
                        property real fadeZone: pickerWindow.itemWidthCollapsed * 3.5
                        property real edgeOpacity: {
                            if (fadeZone <= 0) return 1.0;
                            var center = viewX + width * 0.5;
                            var leftFade = Math.min(1.0, Math.max(0.0, center / fadeZone));
                            var rightFade = Math.min(1.0, Math.max(0.0, (view.width - center) / fadeZone));
                            return Math.min(leftFade, rightFade);
                        }
                        opacity: edgeOpacity

                        function pickWallpaper() {
                            const originalFile = pickerWindow.srcDir + "/" + fileName;
                            // Kill wallpaper engine if it was running
                            Quickshell.execDetached(["bash", "-c", "killall linux-wallpaperengine || true"]);
                            const randomTransition = pickerWindow.transitions[Math.floor(Math.random() * pickerWindow.transitions.length)];
                            const finalCmd = pickerWindow.swwwCommand.arg(originalFile).arg(randomTransition);
                            Quickshell.execDetached(["bash", "-c", finalCmd]);
                            // Update colors
                            const postCmd = "sleep 2 && /home/luisp/.config/hypr/scripts_hypr/update_color.sh '" + originalFile + "'";
                            Quickshell.execDetached(["bash", "-c", postCmd]);
                            root.closed();
                        }

                        width: isCurrent ? pickerWindow.itemWidthExpanded : pickerWindow.itemWidthCollapsed
                        height: view.height
                        z: isCurrent ? 10 : 1

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                view.currentIndex = index;
                                delegateRoot.pickWallpaper();
                            }
                        }

                        Item {
                            anchors.centerIn: parent
                            width: parent.width
                            height: pickerWindow.itemHeight
                            opacity: delegateRoot.isCurrent ? 1 : 0.55

                            // Gold border for selected, subtle border for others
                            Rectangle {
                                anchors.fill: parent
                                radius: delegateRoot.isCurrent ? 12 : 4
                                color: delegateRoot.isCurrent ? pickerWindow.accentGold : "#40FFFFFF"

                                Behavior on radius {
                                    NumberAnimation {
                                        duration: 400
                                    }

                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 400
                                    }

                                }

                            }

                            Item {
                                anchors.fill: parent
                                anchors.margins: delegateRoot.isCurrent ? pickerWindow.borderWidth : 2
                                clip: true

                                Rectangle {
                                    anchors.fill: parent
                                    radius: delegateRoot.isCurrent ? 10 : 3
                                    color: "black"

                                    Behavior on radius {
                                        NumberAnimation {
                                            duration: 400
                                        }

                                    }

                                }

                                Image {
                                    anchors.centerIn: parent
                                    width: parent.width + (parent.height * Math.abs(pickerWindow.skewFactor)) + 50
                                    height: parent.height
                                    fillMode: Image.PreserveAspectCrop
                                    source: fileUrl
                                    asynchronous: true
                                    sourceSize.width: pickerWindow.itemWidthExpanded + (pickerWindow.itemHeight * Math.abs(pickerWindow.skewFactor)) + 50
                                    sourceSize.height: pickerWindow.itemHeight

                                    transform: Matrix4x4 {
                                        property real s: -pickerWindow.skewFactor

                                        matrix: Qt.matrix4x4(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                                    }

                                }

                                // Darkening overlay for non-selected items
                                Rectangle {
                                    anchors.fill: parent
                                    color: "#000000"
                                    opacity: delegateRoot.isCurrent ? 0 : 0.25

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 400
                                        }

                                    }

                                }

                                Behavior on anchors.margins {
                                    NumberAnimation {
                                        duration: 400
                                    }

                                }

                            }

                            // File index badge (bottom-right)
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.margins: delegateRoot.isCurrent ? 14 : 6
                                width: 28
                                height: 28
                                radius: 6
                                color: "#80000000"
                                visible: true

                                Text {
                                    anchors.centerIn: parent
                                    text: (index + 1).toString()
                                    color: "white"
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 400
                                }

                            }

                            transform: Matrix4x4 {
                                property real s: pickerWindow.skewFactor

                                matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                            }

                        }

                         Behavior on width {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutQuad          
                            }

                        }

                    }

                }

                ListView {
                    id: animatedView

                    anchors.fill: parent
                    visible: !pickerWindow.isImageTab
                    spacing: pickerWindow.wpSpacing
                    orientation: ListView.Horizontal
                    clip: false
                    cacheBuffer: 800
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    preferredHighlightBegin: (width / 2) - (pickerWindow.itemWidthExpanded / 2)
                    preferredHighlightEnd: (width / 2) + (pickerWindow.itemWidthExpanded / 2)
                    highlightMoveDuration: pickerWindow.initialFocusSet ? 350 : 0
                    focus: !pickerWindow.isImageTab
                    model: animatedModel

                    header: Item { width: (animatedView.width - pickerWindow.itemWidthExpanded) / 2; height: 1 }
                    footer: Item { width: (animatedView.width - pickerWindow.itemWidthExpanded) / 2; height: 1 }

                    delegate: Item {
                        id: animDelegateRoot

                        readonly property bool isCurrent: ListView.isCurrentItem

                        // Edge fade opacity: items near left/right edges fade out
                        property real viewX: x - animatedView.contentX
                        property real fadeZone: pickerWindow.itemWidthCollapsed * 1.5
                        property real edgeOpacity: {
                            if (fadeZone <= 0) return 1.0;
                            var center = viewX + width * 0.5;
                            var leftFade = Math.min(1.0, Math.max(0.0, center / fadeZone));
                            var rightFade = Math.min(1.0, Math.max(0.0, (animatedView.width - center) / fadeZone));
                            return Math.min(leftFade, rightFade);
                        }
                        opacity: edgeOpacity

                        function pickWallpaper() {
                            const bgId = model.id;
                            const blackWall = "/home/luisp/Pictures/icon/black.jpg";
                            const swwwCmd = pickerWindow.swwwCommand.arg(blackWall).arg("wave");
                            const cmd = "killall linux-wallpaperengine || true; " + swwwCmd + " & for m in $(hyprctl monitors -j | jq -r '.[].name'); do linux-wallpaperengine --screen-root $m --bg " + bgId + " --scaling fill --fps 60 -s  & done; disown";
                            Quickshell.execDetached(["bash", "-c", cmd]);
                            const previewPath = model.preview.replace('file://', '');
                            const postCmd = "sleep 2 && /home/luisp/.config/hypr/scripts_hypr/update_color.sh '" + previewPath + "'";
                            Quickshell.execDetached(["bash", "-c", postCmd]);
                            root.closed();
                        }

                        width: isCurrent ? pickerWindow.itemWidthExpanded : pickerWindow.itemWidthCollapsed
                        height: animatedView.height
                        z: isCurrent ? 10 : 1

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                animatedView.currentIndex = index;
                                animDelegateRoot.pickWallpaper();
                            }
                        }

                        Item {
                            anchors.centerIn: parent
                            width: parent.width
                            height: pickerWindow.itemHeight
                            opacity: animDelegateRoot.isCurrent ? 1 : 0.55

                            // Gold border for selected, subtle border for others
                            Rectangle {
                                anchors.fill: parent
                                radius: animDelegateRoot.isCurrent ? 12 : 4
                                color: animDelegateRoot.isCurrent ? pickerWindow.accentGold : "#40FFFFFF"

                                Behavior on radius {
                                    NumberAnimation {
                                        duration: 400
                                    }

                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 400
                                    }

                                }

                            }

                            Item {
                                anchors.fill: parent
                                anchors.margins: animDelegateRoot.isCurrent ? pickerWindow.borderWidth : 2
                                clip: true

                                Rectangle {
                                    anchors.fill: parent
                                    radius: animDelegateRoot.isCurrent ? 10 : 3
                                    color: "black"

                                    Behavior on radius {
                                        NumberAnimation {
                                            duration: 400
                                        }

                                    }

                                }

                                Image {
                                    anchors.centerIn: parent
                                    width: parent.width + (parent.height * Math.abs(pickerWindow.skewFactor)) + 50
                                    height: parent.height
                                    fillMode: Image.Stretch
                                    source: model.preview
                                    asynchronous: true
                                    sourceSize.width: pickerWindow.itemWidthExpanded + (pickerWindow.itemHeight * Math.abs(pickerWindow.skewFactor)) + 50
                                    sourceSize.height: pickerWindow.itemHeight

                                    transform: Matrix4x4 {
                                        property real s: -pickerWindow.skewFactor

                                        matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                                    }

                                }

                                // Darkening overlay for non-selected items
                                Rectangle {
                                    anchors.fill: parent
                                    color: "#000000"
                                    opacity: animDelegateRoot.isCurrent ? 0 : 0.25

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 400
                                        }

                                    }

                                }

                                // Play icon for animated wallpapers (selected only)
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 10
                                    width: 32
                                    height: 32
                                    radius: 6
                                    color: "#60000000"
                                    visible: animDelegateRoot.isCurrent

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

                                // Title bar for animated wallpapers (selected only)
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 40
                                    radius: 10
                                    color: "#90000000"
                                    visible: animDelegateRoot.isCurrent

                                    Text {
                                        anchors.fill: parent
                                        anchors.margins: 5
                                        text: model.title
                                        color: "white"
                                        font.pointSize: 10
                                        font.bold: true
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                }

                                Behavior on anchors.margins {
                                    NumberAnimation {
                                        duration: 400
                                    }

                                }

                            }

                            // Index badge (bottom-right)
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.margins: animDelegateRoot.isCurrent ? 14 : 6
                                width: 28
                                height: 28
                                radius: 6
                                color: "#80000000"

                                Text {
                                    anchors.centerIn: parent
                                    text: (index + 1).toString()
                                    color: "white"
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 400
                                }

                            }

                            transform: Matrix4x4 {
                                property real s: pickerWindow.skewFactor

                                matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                            }

                        }

                         Behavior on width {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.InOutQuad
                            }

                        }

                    }

                }

            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 30
                spacing: 20

                Rectangle {
                    width: 150
                    height: 40
                    radius: 20
                    color: pickerWindow.isImageTab ? "white" : "#40FFFFFF"

                    Text {
                        anchors.centerIn: parent
                        text: "Imágenes"
                        color: pickerWindow.isImageTab ? "black" : "white"
                        font.pointSize: 13
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            pickerWindow.isImageTab = true;
                            view.forceActiveFocus();
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }

                    }

                }

                Rectangle {
                    width: 150
                    height: 40
                    radius: 20
                    color: !pickerWindow.isImageTab ? "white" : "#40FFFFFF"

                    Text {
                        anchors.centerIn: parent
                        text: "Animados"
                        color: !pickerWindow.isImageTab ? "black" : "white"
                        font.pointSize: 13
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            pickerWindow.isImageTab = false;
                            animatedView.forceActiveFocus();
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }

                    }

                }

            }

        }

        } // cardContainer

    }

    signal closed()

    onActiveChanged: {
        if (active) {
            // Reset state for fresh open
            pickerWindow.initialFocusSet = false;
            pickerWindow.processFinished = false;
            pickerWindow.targetWallName = "";
            pickerWindow.targetWallIndex = 0;
            currentWallProcess.running = true;
            animatedModel.clear();
            weProcess.running = true;
            // Trigger thumbnail synchronization
            syncThumbnailsProcess.running = true;
        }
    }
}
