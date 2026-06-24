import QtQuick

Item {
    id: timers
    property var rootWidget
    property var pill

    property alias notifOpacity: notifOpacityObj
    property alias collapseSequencer: collapseSequencerTimer
    property alias notifShowTimer: notifShowTimerObj
    property alias notifFadeInTimer: notifFadeInTimerObj
    property alias notifRestoreTimer: notifRestoreTimerObj
    property alias notifHandlerConnections: notifHandlerConnectionsObj
    property alias notifHideTimer: notifHideTimerObj
    property alias positionPoller: positionPollerObj
    property alias launcherOpacity: launcherOpacityObj
    property alias launcherFadeInTimer: launcherFadeInTimerObj
    property alias launcherCloseTimer: launcherCloseTimerObj
    property alias detailOpacity: detailOpacityObj
    property alias _airdropOpacity: _airdropOpacityObj
    property alias airdropFadeInTimer: airdropFadeInTimerObj
    property alias airdropCloseTimer: airdropCloseTimerObj
    property alias airdropMinimizeTimer: airdropMinimizeTimerObj
    property alias overviewOpacity: overviewOpacityObj
    property alias overviewFadeInTimer: overviewFadeInTimerObj
    property alias overviewCloseTimer: overviewCloseTimerObj
    property alias _screenRecOpacity: _screenRecOpacityObj
    property alias screenRecFadeInTimer: screenRecFadeInTimerObj
    property alias screenRecCloseTimer: screenRecCloseTimerObj

    QtObject {
        id: notifOpacityObj
        property real value: 0
        Behavior on value {
            SequentialAnimation {
                PauseAnimation { duration: 150 }
                NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
            }
        }
    }

    Timer {
        id: collapseSequencerTimer
        interval: 350
        onTriggered: {
            rootWidget.detailExpanded = false;
            rootWidget.eqExpanded = false;
        }
    }

    Timer {
        id: notifShowTimerObj
        interval: 400
        onTriggered: {
            rootWidget.notificationVisible = true;
            notifFadeInTimerObj.start();
        }
    }

    Timer {
        id: notifFadeInTimerObj
        interval: 250
        onTriggered: notifOpacityObj.value = 1
    }

    Timer {
        id: notifRestoreTimerObj
        interval: 500
        onTriggered: {
            if (rootWidget.expanded) {
                pill.compactPlayer.showNote.start();
                pill.compactPlayer.showText.start();
                pill.compactPlayer.showControls.start();
            }
        }
    }

    Connections {
        id: notifHandlerConnectionsObj
        target: rootWidget.notifHandler
        function onNotificationArrived() {
            // Close the notification center if open, so the pill (opacity:0 when
            // notifCenterVisible) becomes visible again to show the popup.
            if (rootWidget.notifCenterVisible && rootWidget.onToggleNotifCenter) {
                rootWidget.onToggleNotifCenter();
            }
            if (rootWidget.launcherOpen) {
                launcherOpacityObj.value = 0;
                rootWidget.launcherOpen = false;
            }
            if (rootWidget.overviewOpen) {
                overviewOpacityObj.value = 0;
                rootWidget.overviewOpen = false;
            }
            if (rootWidget.airdropOpen) {
                var hasTransfer = (rootWidget.airdropLsState === "sending" || rootWidget.airdropLsState === "scanning" || rootWidget.airdropLsState === "ready");
                _airdropOpacityObj.value = 0;
                if (hasTransfer) {
                    rootWidget.airdropMinimized = true;
                }
                rootWidget.airdropOpen = false;
            }
            if (rootWidget.screenRecOpen) {
                _screenRecOpacityObj.value = 0;
                rootWidget.screenRecMinimized = true;
                rootWidget.screenRecOpen = false;
            }
            if (rootWidget.detailExpanded) {
                detailOpacityObj.value = 0;
                collapseSequencerTimer.start();
            }
            pill.compactPlayer.hideControls.start();
            pill.compactPlayer.hideText.start();
            pill.compactPlayer.hideNote.start();
            notifShowTimerObj.start();
        }

        function onNotificationDismissed() {
            notifOpacityObj.value = 0;
            notifHideTimerObj.start();
        }
    }

    Timer {
        id: notifHideTimerObj
        interval: 350
        onTriggered: {
            rootWidget.notificationVisible = false;
            notifRestoreTimerObj.start();
        }
    }

    Timer {
        id: positionPollerObj
        interval: 500
        running: rootWidget.isPlaying && rootWidget.detailExpanded
        repeat: true
        onTriggered: {
            if (rootWidget.hasSpotify) {
                rootWidget.trackPosition = rootWidget.spotifyPlayer.position;
                rootWidget.trackLength = rootWidget.spotifyPlayer.length;
            }
        }
    }

    QtObject {
        id: launcherOpacityObj
        property real value: 0.0
        Behavior on value {
            NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
        }
    }

    Timer {
        id: launcherFadeInTimerObj
        interval: 200
        onTriggered: launcherOpacityObj.value = 1.0
    }

    Timer {
        id: launcherCloseTimerObj
        interval: 250
        onTriggered: {
            rootWidget.launcherOpen = false;
            if (rootWidget.expanded) {
                pill.compactPlayer.showNote.start();
                pill.compactPlayer.showText.start();
                pill.compactPlayer.showControls.start();
            }
        }
    }

    QtObject {
        id: detailOpacityObj
        property real value: 0
        Behavior on value {
            NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
        }
    }

    QtObject {
        id: _airdropOpacityObj
        property real value: 0.0
        Behavior on value {
            NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
        }
    }

    Timer {
        id: airdropFadeInTimerObj
        interval: 200
        onTriggered: _airdropOpacityObj.value = 1.0
    }

    Timer {
        id: airdropCloseTimerObj
        interval: 250
        onTriggered: {
            rootWidget.airdropOpen = false;
            if (rootWidget.expanded) {
                pill.compactPlayer.showNote.start();
                pill.compactPlayer.showText.start();
                pill.compactPlayer.showControls.start();
            }
        }
    }

    Timer {
        id: airdropMinimizeTimerObj
        interval: 250
        onTriggered: {
            rootWidget.airdropMinimized = true;
            rootWidget.airdropOpen = false;
            if (rootWidget.expanded) {
                pill.compactPlayer.showNote.start();
                pill.compactPlayer.showText.start();
                pill.compactPlayer.showControls.start();
            }
        }
    }

    QtObject {
        id: overviewOpacityObj
        property real value: 0.0
        Behavior on value {
            NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
        }
    }

    Timer {
        id: overviewFadeInTimerObj
        interval: 200
        onTriggered: overviewOpacityObj.value = 1.0
    }

    Timer {
        id: overviewCloseTimerObj
        interval: 250
        onTriggered: {
            rootWidget.overviewOpen = false;
            if (rootWidget.expanded) {
                pill.compactPlayer.showNote.start();
                pill.compactPlayer.showText.start();
                pill.compactPlayer.showControls.start();
            }
        }
    }

    QtObject {
        id: _screenRecOpacityObj
        property real value: 0.0
        Behavior on value {
            NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
        }
    }

    Timer {
        id: screenRecFadeInTimerObj
        interval: 200
        onTriggered: _screenRecOpacityObj.value = 1.0
    }

    Timer {
        id: screenRecCloseTimerObj
        interval: 250
        onTriggered: {
            rootWidget.screenRecOpen = false;
            if (rootWidget.expanded) {
                pill.compactPlayer.showNote.start();
                pill.compactPlayer.showText.start();
                pill.compactPlayer.showControls.start();
            }
        }
    }
}
