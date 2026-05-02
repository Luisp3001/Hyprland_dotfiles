import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Controls
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
    property var tagsDb: ({})
    property string searchQuery: ""
    property bool isTagging: false
    property var syncThumbnailsProcess

    syncThumbnailsProcess: Process {
        command: ["/home/luisp/.config/quickshell/generate_thumbnails.sh"]
        running: false
    }

    property var taggingStatusProcess

    taggingStatusProcess: Process {
        command: ["bash", "-c", "while true; do if [ -f ~/.cache/wallpaper/tagger.lock ]; then echo '1'; else echo '0'; fi; sleep 2; done"]
        running: root.active
        stdout: SplitParser {
            splitMarker: ""
            onRead: (data) => {
                let text = data.trim();
                if (text === "1") root.isTagging = true;
                else if (text === "0") root.isTagging = false;
            }
        }
    }

    property var loadTagsProcess

    loadTagsProcess: Process {
        command: ["cat", Quickshell.env("HOME") + "/.cache/wallpaper/tags.json"]
        running: false

        stdout: SplitParser {
            splitMarker: ""
            onRead: (data) => {
                let text = data.trim();
                if (text.length > 0) {
                    try {
                        root.tagsDb = JSON.parse(text);
                    } catch (e) {
                        console.log("Failed to parse tags.json:", e);
                    }
                }
            }
        }
    }

    property var currentWallProcess

    currentWallProcess: Process {
        command: ["bash", "-c", "if bg_id=$(pgrep -af linux-wallpaper | grep -oP -e '--bg \\K[0-9]+' | head -n 1) && [ -n \"$bg_id\" ]; then echo \"animated:$bg_id\"; else swww query | grep 'currently displaying' | sed -E 's/.*image: (.*)/\\1/' | head -n 1 || true; fi"]
        onExited: {
            pickerWindow.processFinished = true;
            pickerWindow.tryFocus();
        }

        stdout: SplitParser {
            onRead: (data) => {
                let text = data.trim();
                if (text.startsWith("animated:")) {
                    let bgId = text.split(":")[1];
                    if (bgId) {
                        pickerWindow.targetAnimatedId = bgId;
                        pickerWindow.isImageTab = false;
                    }
                } else {
                    let parts = text.split('/');
                    let name = parts[parts.length - 1];
                    if (name && name !== "black.jpg") {
                        pickerWindow.targetWallName = name;
                        pickerWindow.isImageTab = true;
                    }
                }
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
                        if (!pickerWindow.initialFocusSet && pickerWindow.processFinished && !pickerWindow.isImageTab) {
                            pickerWindow.tryFocus();
                        }
                    } catch (e) {
                    }
                }
            }
        }

        onExited: {
            pickerWindow.weProcessFinished = true;
            pickerWindow.tryFocus();
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
        property string targetAnimatedId: ""
        property bool processFinished: false
        property bool weProcessFinished: false
        property bool isImageTab: true
        property bool searchFocused: false
        readonly property string homeDir: "file://" + Quickshell.env("HOME")
        readonly property string thumbDir: homeDir + "/.cache/wallpaper"
        readonly property string srcDir: Quickshell.env("HOME") + "/wallpaper"
        readonly property string swwwCommand: "swww img '%1' --transition-type %2 --transition-pos 0.5,0.5 --transition-fps 144 --transition-duration 1"
        readonly property var transitions: ["wave"]
        readonly property int itemWidthExpanded: 700
        readonly property int itemWidthCollapsed: 80
        readonly property int itemHeight: 420
        readonly property int borderWidth: 3
        readonly property int wpSpacing: 5
        readonly property real skewFactor: -0.20
        readonly property color accentGold: "#C8A961"

        // Helper: get tags for a filename
        function getTagsForFile(fileName) {
            if (root.tagsDb && root.tagsDb[fileName])
                return root.tagsDb[fileName];
            return [];
        }

        // Helper: check if a filename matches the current search
        function matchesSearch(fileName) {
            let q = root.searchQuery.trim().toLowerCase();
            if (q === "") return true;
            let terms = q.split(/\s+/);
            let tags = getTagsForFile(fileName);
            let tagStr = tags.join(" ");
            let nameStr = fileName.toLowerCase();
            // Every search term must match at least one tag or the filename
            for (let t of terms) {
                if (tagStr.indexOf(t) === -1 && nameStr.indexOf(t) === -1)
                    return false;
            }
            return true;
        }

        // Rebuild the filtered index map whenever search/model changes
        property var filteredIndices: []
        function rebuildFilter() {
            let indices = [];
            for (let i = 0; i < folderModel.count; i++) {
                let fname = folderModel.get(i, "fileName");
                if (matchesSearch(fname))
                    indices.push(i);
            }
            filteredIndices = indices;
        }

        function tryFocus() {
            if (!initialFocusSet && processFinished) {
                let foundIndex = -1;
                
                if (!isImageTab) {
                    if (targetAnimatedId !== "") {
                        for (let i = 0; i < animatedModel.count; i++) {
                            if (animatedModel.get(i).id === targetAnimatedId) {
                                foundIndex = i;
                                break;
                            }
                        }
                    }
                    if (foundIndex !== -1) {
                        animatedView.currentIndex = foundIndex;
                        initialFocusSet = true;
                    } else if (weProcessFinished && animatedModel.count > 0) {
                        let safeIndex = Math.min(targetWallIndex, animatedModel.count - 1);
                        animatedView.currentIndex = safeIndex;
                        initialFocusSet = true;
                    }
                } else {
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

        // React to search query changes
        Connections {
            target: root
            function onSearchQueryChanged() {
                pickerWindow.rebuildFilter();
                // Reset selection on filter change
                if (pickerWindow.isImageTab && view.count > 0)
                    view.currentIndex = 0;
            }
            function onTagsDbChanged() {
                pickerWindow.rebuildFilter();
            }
        }

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Shortcut {
            sequence: "Left"
            enabled: !pickerWindow.searchFocused
            onActivated: pickerWindow.isImageTab ? view.decrementCurrentIndex() : animatedView.decrementCurrentIndex()
        }

        Shortcut {
            sequence: "Right"
            enabled: !pickerWindow.searchFocused
            onActivated: pickerWindow.isImageTab ? view.incrementCurrentIndex() : animatedView.incrementCurrentIndex()
        }

        Shortcut {
            sequence: "Return"
            enabled: !pickerWindow.searchFocused
            onActivated: {
                if (pickerWindow.isImageTab && view.currentItem)
                    view.currentItem.pickWallpaper();
                else if (!pickerWindow.isImageTab && animatedView.currentItem)
                    animatedView.currentItem.pickWallpaper();
            }
        }

        Shortcut {
            sequence: "Escape"
            onActivated: {
                if (pickerWindow.searchFocused) {
                    searchField.focus = false;
                    pickerWindow.searchFocused = false;
                    view.forceActiveFocus();
                } else if (root.searchQuery !== "") {
                    root.searchQuery = "";
                    searchField.text = "";
                } else {
                    root.closed();
                }
            }
        }

        Shortcut {
            sequence: "Ctrl+F"
            onActivated: {
                searchField.forceActiveFocus();
                searchField.selectAll();
            }
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
            height: pickerWindow.itemHeight + 160
            anchors.centerIn: parent

            // Block clicks from passing through the card to the dismiss area
            MouseArea {
                anchors.fill: parent
                onClicked: {} // absorb
            }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 0
            spacing: 8

            // ── Search Bar ──────────────────────────────────────────────
            Rectangle {
                id: searchBar
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(parent.width * 0.5, 550)
                Layout.preferredHeight: 44
                radius: 22
                color: pickerWindow.searchFocused ? "#35FFFFFF" : "#20FFFFFF"
                border.color: pickerWindow.searchFocused ? pickerWindow.accentGold : "#30FFFFFF"
                border.width: 1.5

                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 12
                    spacing: 8

                    // Search icon
                    Text {
                        text: "⌕"
                        color: pickerWindow.searchFocused ? pickerWindow.accentGold : "#80FFFFFF"
                        font.pixelSize: 18
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    TextInput {
                        id: searchField
                        Layout.fillWidth: true
                        color: "white"
                        font.pixelSize: 14
                        font.family: "Inter, Segoe UI, sans-serif"
                        clip: true
                        selectByMouse: true
                        selectedTextColor: "black"
                        selectionColor: pickerWindow.accentGold

                        onTextChanged: {
                            root.searchQuery = text;
                        }
                        onActiveFocusChanged: {
                            pickerWindow.searchFocused = activeFocus;
                        }

                        // Placeholder
                        Text {
                            anchors.fill: parent
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Buscar por tags...  (Ctrl+F)"
                            color: "#50FFFFFF"
                            font: parent.font
                            visible: !parent.text && !parent.activeFocus
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    // Clear button
                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        color: clearMa.containsMouse ? "#40FFFFFF" : "transparent"
                        visible: searchField.text.length > 0
                        opacity: visible ? 1 : 0

                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: "#AAFFFFFF"
                            font.pixelSize: 12
                        }

                        MouseArea {
                            id: clearMa
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                searchField.text = "";
                                root.searchQuery = "";
                                view.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            // ── Tagging Indicator ───────────────────────────────────────
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                visible: root.isTagging

                Rectangle {
                    width: 10
                    height: 10
                    radius: 5
                    color: pickerWindow.accentGold
                    
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: root.isTagging
                        NumberAnimation { to: 0.3; duration: 800; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                    }
                }
                Text {
                    text: "Generando tags con IA..."
                    color: pickerWindow.accentGold
                    font.pixelSize: 12
                    font.bold: true
                }
            }


            // ── Search Results Count ────────────────────────────────────
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.searchQuery !== "" ? pickerWindow.filteredIndices.length + " resultados" : ""
                color: "#60FFFFFF"
                font.pixelSize: 11
                visible: root.searchQuery !== ""
                Layout.preferredHeight: visible ? implicitHeight : 0

                Behavior on Layout.preferredHeight { NumberAnimation { duration: 150 } }
            }

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
                    cacheBuffer: 0
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    preferredHighlightBegin: (width / 2) - (pickerWindow.itemWidthExpanded / 2)
                    preferredHighlightEnd: (width / 2) + (pickerWindow.itemWidthExpanded / 2)
                    highlightMoveDuration: pickerWindow.initialFocusSet ? 450 : 0
                    focus: pickerWindow.isImageTab
                    onCountChanged: pickerWindow.tryFocus()

                    header: Item { width: (view.width - pickerWindow.itemWidthExpanded) / 2; height: 1 }
                    footer: Item { width: (view.width - pickerWindow.itemWidthExpanded) / 2; height: 1 }

                    // Use filtered model when searching, full model otherwise
                    model: root.searchQuery !== "" ? filteredModel : folderModel

                    FolderListModel {
                        id: folderModel

                        folder: pickerWindow.thumbDir
                        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif"]
                        showDirs: false
                        sortField: FolderListModel.Name
                        onStatusChanged: {
                            pickerWindow.tryFocus();
                            pickerWindow.rebuildFilter();
                        }
                        onCountChanged: pickerWindow.rebuildFilter()
                    }

                    ListModel {
                        id: filteredModel
                    }

                    // Rebuild filtered model from filteredIndices
                    Connections {
                        target: pickerWindow
                        function onFilteredIndicesChanged() {
                            filteredModel.clear();
                            for (let idx of pickerWindow.filteredIndices) {
                                filteredModel.append({
                                    fileName: folderModel.get(idx, "fileName"),
                                    fileUrl: folderModel.get(idx, "fileUrl")
                                });
                            }
                        }
                    }

                    delegate: Item {
                        id: delegateRoot

                        readonly property bool isCurrent: ListView.isCurrentItem
                        readonly property var currentTags: pickerWindow.getTagsForFile(fileName)

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

                        Behavior on width {
                            NumberAnimation { duration: 450; easing.type: Easing.OutExpo }
                        }

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

                            Behavior on opacity {
                                NumberAnimation { duration: 450; easing.type: Easing.OutQuad }
                            }

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
                                    cache: false
                                    asynchronous: true

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

                            // ── Tags overlay (shown on selected item) ──
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: tagsFlow.implicitHeight + 16
                                color: "#CC000000"
                                radius: 10
                                visible: delegateRoot.isCurrent && delegateRoot.currentTags.length > 0
                                opacity: visible ? 1 : 0

                                Behavior on opacity { NumberAnimation { duration: 300 } }

                                Flow {
                                    id: tagsFlow
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 6

                                    Repeater {
                                        model: delegateRoot.currentTags

                                        Rectangle {
                                            width: tagLabel.implicitWidth + 14
                                            height: 22
                                            radius: 11
                                            color: {
                                                // Highlight tags that match the search
                                                let q = root.searchQuery.trim().toLowerCase();
                                                if (q !== "" && modelData.indexOf(q) !== -1)
                                                    return pickerWindow.accentGold;
                                                return "#30FFFFFF";
                                            }

                                            Behavior on color { ColorAnimation { duration: 200 } }

                                            Text {
                                                id: tagLabel
                                                anchors.centerIn: parent
                                                text: modelData
                                                color: {
                                                    let q = root.searchQuery.trim().toLowerCase();
                                                    if (q !== "" && modelData.indexOf(q) !== -1)
                                                        return "#111";
                                                    return "#CCFFFFFF";
                                                }
                                                font.pixelSize: 10
                                                font.bold: true
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    searchField.text = modelData;
                                                    root.searchQuery = modelData;
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // File index badge (bottom-right)
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.margins: delegateRoot.isCurrent ? 14 : 6
                                anchors.bottomMargin: delegateRoot.isCurrent && delegateRoot.currentTags.length > 0 ? (tagsFlow.implicitHeight + 24) : (delegateRoot.isCurrent ? 14 : 6)
                                width: 28
                                height: 28
                                radius: 6
                                color: "#80000000"
                                visible: true

                                Behavior on anchors.bottomMargin { NumberAnimation { duration: 300 } }

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
                    cacheBuffer: 0
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
                                    cache: false
                                    source: model.preview
                                    asynchronous: true

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
            pickerWindow.weProcessFinished = false;
            pickerWindow.targetWallName = "";
            pickerWindow.targetAnimatedId = "";
            pickerWindow.targetWallIndex = 0;
            searchQuery = "";
            currentWallProcess.running = true;
            animatedModel.clear();
            weProcess.running = true;
            // Load tags database
            loadTagsProcess.running = true;
            // Trigger thumbnail synchronization
            syncThumbnailsProcess.running = true;
        }
        else {
            animatedModel.clear()
            gc()
        }
    }
}
