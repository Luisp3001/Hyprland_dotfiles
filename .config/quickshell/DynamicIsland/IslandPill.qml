import QtQuick
import QtQuick.Layouts
import "music"
import "airdrop"
import "applauncher"
import "notifications"
import "overview"   
import "screenrec"

Rectangle {
    id: pill
    property var rootWidget
    property alias compactPlayer: row

    z: 1
    property real compactWidth: 370
    property real expandedWidth: 850
    property real launcherWidth: 560
    property real airdropWidth: 420
    property real screenRecWidth: 420
    property real overviewWidth: (overviewContentLoader.item ? overviewContentLoader.item.gridWidth : 700) + 46
    property real notifWidth: 430
    property real notifHeight: {
        if (!rootWidget.notificationVisible)
            return 90;

        // Calculate height based on content
        return Math.min(300, Math.max(90, notifContent.notifColumn.implicitHeight + 30));
    }
    property real launcherHeight: (launcherContentLoader.item ? launcherContentLoader.item.preferredHeight : 425) + 28
    property real airdropHeight: (airdropContentLoader.item ? airdropContentLoader.item.preferredHeight : 200) + 28
    property real screenRecHeight: (screenRecContentLoader.item ? screenRecContentLoader.item.preferredHeight : 250) + 28
    property real overviewHeight: (overviewContentLoader.item ? overviewContentLoader.item.preferredHeight : 280) + 28
    property real targetWidth: rootWidget.screenRecOpen ? screenRecWidth : (rootWidget.overviewOpen ? overviewWidth : (rootWidget.airdropOpen ? airdropWidth : (rootWidget.launcherOpen ? launcherWidth : (rootWidget.notificationVisible ? notifWidth : (rootWidget.detailExpanded ? expandedWidth : compactWidth)))))
    property real targetHeight: rootWidget.screenRecOpen ? screenRecHeight : (rootWidget.overviewOpen ? overviewHeight : (rootWidget.airdropOpen ? airdropHeight : (rootWidget.launcherOpen ? launcherHeight : (rootWidget.notificationVisible ? notifHeight : (rootWidget.detailExpanded ? 420 : 45)))))

    antialiasing: true
    clip: true
    layer.enabled: true
    width: targetWidth
    height: targetHeight
    radius: (rootWidget.detailExpanded || rootWidget.notificationVisible || rootWidget.launcherOpen || rootWidget.airdropOpen || rootWidget.overviewOpen || rootWidget.screenRecOpen) ? 22 : height / 2
    color: rootWidget.walColors.special.background
    border.color: rootWidget.expanded ? "#3d4150" : "transparent"
    border.width: 1
    opacity: {
        if (rootWidget.notifCenterVisible)
            return 0;

        return (rootWidget.expanded || rootWidget.notificationVisible) ? 1 : 0;
    }
    scale: rootWidget.notifCenterVisible ? 0.9 : 1

    anchors {
        top: parent.top
        topMargin: rootWidget.launcherOpen ? (parent.height * 0.28) : rootWidget.verticalPadding
        horizontalCenter: parent.horizontalCenter
        horizontalCenterOffset: 0
    }

    Behavior on anchors.topMargin {
        NumberAnimation {
            duration: 500
            easing.type: Easing.OutQuint
        }
    }

    // Click to toggle expanded view / dismiss notification
    MouseArea {
        anchors.fill: parent

        property real startY: 0
        property bool isSwiping: false

        onPressed: (mouse) => {
            startY = mouse.y;
            isSwiping = false;
        }

        onPositionChanged: (mouse) => {
            if (rootWidget.notificationVisible && !isSwiping) {
                if (startY - mouse.y > 20) {
                    isSwiping = true;
                    rootWidget.notifHandler.dismiss();
                }
            }
        }

        onClicked: {
            if (isSwiping) return;
            if (rootWidget.launcherOpen) return; // Don't toggle detail while launcher is open
            if (rootWidget.airdropOpen) return; // Don't toggle detail while airdrop is open
            if (rootWidget.overviewOpen) return; // Don't toggle detail while overview is open
            if (rootWidget.screenRecOpen) return; // Don't toggle detail while screenRec is open

            if (rootWidget.notificationVisible) {
                var invoked = false;
                for (var i = 0; i < rootWidget.notifHandler.actions.length; i++) {
                    var action = rootWidget.notifHandler.actions[i];
                    if ((action.identifier && action.identifier === "default") || action.id === "default") {
                        if (action.invoke)
                            action.invoke();

                        invoked = true;
                        break;
                    }
                }
                rootWidget.notifHandler.dismiss();
            } else {
                rootWidget.toggleDetail();
            }
        }
    }

    // ── Compact content (top row) ─────────────────────────────
    CompactPlayer {
        id: row

        rootWidget: pill.rootWidget
        visible: !rootWidget.launcherOpen || rootWidget.launcherOpacity.value < 0.5

        anchors {
            top: parent.top
            topMargin: rootWidget.detailExpanded ? 10 : 0
            left: parent.left
            right: parent.right
            leftMargin: 20
            rightMargin: 20
            verticalCenter: rootWidget.detailExpanded ? undefined : parent.verticalCenter
        }
    }

    // ── Expanded detail content ───────────────────────────────
    ExpandedPlayer {
        id: detailContent

        rootWidget: pill.rootWidget
        visible: rootWidget.detailOpacity.value > 0
        opacity: rootWidget.detailOpacity.value

        anchors {
            top: row.bottom
            topMargin: 12
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: 18
            rightMargin: 18
            bottomMargin: 14
        }
    }

    // ── Notification content ──────────────────────────────────
    NotificationContent {
        id: notifContent

        rootWidget: pill.rootWidget
        visible: rootWidget.notifOpacity.value > 0 && !rootWidget.launcherOpen && !rootWidget.airdropOpen && !rootWidget.overviewOpen && !rootWidget.screenRecOpen
        opacity: rootWidget.notifOpacity.value

        anchors {
            fill: parent
            leftMargin: 22
            rightMargin: 22
            topMargin: 12
            bottomMargin: 12
        }
    }

    // ── App Launcher content ─────────────────────────────────────
    Loader {
        id: launcherContentLoader
        active: rootWidget.launcherOpen || rootWidget.launcherOpacity.value > 0
        visible: rootWidget.launcherOpacity.value > 0
        opacity: rootWidget.launcherOpacity.value
        sourceComponent: Component {
            AppLauncherContent {
                rootWidget: pill.rootWidget
            }
        }

        // When the Loader finishes creating the item, load apps + grab focus
        onLoaded: {
            if (item && rootWidget.launcherOpen)
                item.reload();
        }

        anchors {
            fill: parent
            leftMargin: 18
            rightMargin: 18
            topMargin: 14
            bottomMargin: 14
        }
    }

    // ── Airdrop content ──────────────────────────────────────────
    Loader {
        id: airdropContentLoader
        active: rootWidget.airdropOpen || rootWidget._airdropOpacity.value > 0 || rootWidget.airdropMinimized
        visible: rootWidget._airdropOpacity.value > 0
        opacity: rootWidget._airdropOpacity.value
        sourceComponent: Component {
            AirdropContent {
                rootWidget: pill.rootWidget
            }
        }

        anchors {
            fill: parent
            leftMargin: 18
            rightMargin: 18
            topMargin: 14
            bottomMargin: 14
        }
    }

    // ── Workspace Overview content ───────────────────────────────────
    Loader {
        id: overviewContentLoader
        active: rootWidget.overviewOpen || rootWidget.overviewOpacity.value > 0
        visible: rootWidget.overviewOpacity.value > 0
        opacity: rootWidget.overviewOpacity.value
        sourceComponent: Component {
            WorkspaceOverviewContent {
                rootWidget: pill.rootWidget
            }
        }

        onLoaded: {
            if (item && rootWidget.overviewOpen)
                item.reload();
        }

        anchors {
            fill: parent
            leftMargin: 18
            rightMargin: 18
            topMargin: 14
            bottomMargin: 14
        }
    }

    // ── ScreenRec content ────────────────────────────────────────────
    Loader {
        id: screenRecContentLoader
        active: rootWidget.screenRecOpen || rootWidget._screenRecOpacity.value > 0 || rootWidget.screenRecMinimized
        visible: rootWidget._screenRecOpacity.value > 0
        opacity: rootWidget._screenRecOpacity.value
        sourceComponent: Component {
            ScreenRecContent {
                rootWidget: pill.rootWidget
            }
        }

        anchors {
            fill: parent
            leftMargin: 18
            rightMargin: 18
            topMargin: 14
            bottomMargin: 14
        }
    }

    // ── Global DropArea: expand island on external file drag ─────
    DropArea {
        id: pillDropArea
        anchors.fill: parent
        keys: ["text/uri-list", "text/plain"]
        enabled: !rootWidget.airdropOpen && !rootWidget.launcherOpen && !rootWidget.overviewOpen && !rootWidget.screenRecOpen

        onEntered: (drag) => {
            // A file is being dragged over the island — expand to airdrop
            if (!rootWidget.airdropOpen) {
                rootWidget.toggleAirdrop();
            }
        }
    }

    // Global ESC handler — closes launcher, airdrop, or overview from anywhere in the pill
    Keys.onEscapePressed: function(event) {
        if (rootWidget.launcherOpen) {
            rootWidget.toggleLauncher();
            event.accepted = true;
        } else if (rootWidget.airdropOpen) {
            rootWidget.toggleAirdrop();
            event.accepted = true;
        } else if (rootWidget.overviewOpen) {
            rootWidget.toggleOverview();
            event.accepted = true;
        } else if (rootWidget.screenRecOpen) {
            rootWidget.toggleScreenRec();
            event.accepted = true;
        }
    }
    focus: rootWidget.launcherOpen || rootWidget.airdropOpen || rootWidget.overviewOpen || rootWidget.screenRecOpen

    Behavior on anchors.horizontalCenterOffset {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutQuint
        }
    }

    Behavior on width {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }
    }

    Behavior on height {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }
    }

    Behavior on radius {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 250
            easing.type: Easing.InOutQuad
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: 300
            easing.type: Easing.InOutQuad
        }
    }

    Behavior on border.color {
        ColorAnimation {
            duration: 200
        }
    }
}
