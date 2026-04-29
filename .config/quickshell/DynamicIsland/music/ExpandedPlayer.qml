import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: expandedPlayer
    property var rootWidget

    // Background animation: Flowing Orbits
    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2
        duration: 90000
        loops: Animation.Infinite
        running: true
    }

    Item {
        z: -10
        anchors.fill: parent
        anchors.leftMargin: -18
        anchors.rightMargin: -18
        anchors.bottomMargin: -14
        anchors.topMargin: -80
        clip: true

        Rectangle {
            width: parent.width * 0.8; height: width; radius: width / 2
            x: (parent.width / 2 - width / 2) + Math.cos(expandedPlayer.globalOrbitAngle * 2) * 150
            y: (parent.height / 2 - height / 2) + Math.sin(expandedPlayer.globalOrbitAngle * 2) * 100
            
            opacity: rootWidget.isPlaying ? 0.08 : 0.04
            color: rootWidget.walColors.colors.color2
            Behavior on color { ColorAnimation { duration: 1000 } }
            Behavior on opacity { NumberAnimation { duration: 1000 } }
        }
        
        Rectangle {
            width: parent.width * 0.9; height: width; radius: width / 2
            x: (parent.width / 2 - width / 2) + Math.sin(expandedPlayer.globalOrbitAngle * 1.5) * -150
            y: (parent.height / 2 - height / 2) + Math.cos(expandedPlayer.globalOrbitAngle * 1.5) * -100
            
            opacity: rootWidget.isPlaying ? 0.08 : 0.02
            color: rootWidget.walColors.colors.color3 || rootWidget.walColors.colors.color1
            Behavior on color { ColorAnimation { duration: 1000 } }
            Behavior on opacity { NumberAnimation { duration: 1000 } }
        }
    }

    function execCmd(cmdStr) {
        var safeCmd = cmdStr.replace(/`/g, "\\`");
        var p = Qt.createQmlObject(`
            import Quickshell.Io
            Process {
                command: ["bash", "-c", \`${safeCmd}\`]
                running: true
                onExited: (exitCode) => destroy()
            }
        `, expandedPlayer);
    }

    property real eqLightningProgress: 0.0
    property real eqLightningFade: 1.0

    function triggerEqLightning() {
        eqLightningFade = 0.0;
        eqLightningProgress = 0.0;
        lightningAnim.restart();
    }

    SequentialAnimation {
        id: lightningAnim
        NumberAnimation {
            target: expandedPlayer
            property: "eqLightningProgress"
            from: 0.0; to: 10.0
            duration: 800
            easing.type: Easing.OutSine
        }
        NumberAnimation {
            target: expandedPlayer
            property: "eqLightningFade"
            from: 0.0; to: 1.0
            duration: 600
        }
    }

    Connections {
        target: rootWidget
        function onDetailExpandedChanged() {
            if (rootWidget.detailExpanded) {
                showDetail.start();
            }
            // Close fade is handled by toggleDetail() directly
        }
    }

    Timer {
        id: showDetail
        interval: 250
        onTriggered: rootWidget.detailOpacity.value = 1.0
    }

    // ── Album art + track info ────────────────────────────
    RowLayout {
        anchors.fill: parent
        spacing: 20

        // LEFT COLUMN (Player)
        ColumnLayout {
            Layout.preferredWidth: 260
            Layout.fillHeight: true
            spacing: 15

            // Album art + track info
            ColumnLayout {
                id: albumRow
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 14

        // Album art (Vinyl Record Style)
        Item {
            id: artContainerWrapper
            Layout.preferredWidth: 160
            Layout.preferredHeight: 160
            Layout.alignment: Qt.AlignHCenter
            
            // Allow the whole item to rotate smoothly like a vinyl
            Item {
                id: artContainer
                anchors.fill: parent
                
                NumberAnimation on rotation {
                    from: 0; to: 360; duration: 8000
                    loops: Animation.Infinite
                    running: rootWidget.isPlaying
                }

                // Máscara para hacer circular la imagen
                Rectangle {
                    id: cdMask
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                    layer.enabled: true
                }

                Image {
                    id: albumArt
                    anchors.fill: parent
                    source: rootWidget.hasSpotify ? rootWidget.spotifyPlayer.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: true
                    visible: false 
                }

                // El MultiEffect procesa y aplica la máscara
                MultiEffect {
                    anchors.fill: parent
                    source: albumArt
                    maskEnabled: true
                    antialiasing: true
                    maskSource: cdMask
                }

                // Black center circle (Vinyl hole)
                Rectangle {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    radius: 11
                    color: "black"
                    opacity: 0.8
                }
            }
            
            // Outer glow effect
            Rectangle {
                z: -1
                anchors.centerIn: parent
                width: parent.width + 20
                height: parent.height + 20
                radius: width / 2
                color: rootWidget.walColors.colors.color2
                border.width: 0
                opacity: rootWidget.isPlaying ? 0.5 : 0.0
                Behavior on opacity { NumberAnimation { duration: 500 } }
                
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 32
                    blur: 1.0
                }
            }

            Rectangle {
                z: -1
                anchors.centerIn: parent
                width: parent.width + 7
                height: parent.height + 7
                radius: width / 2
                color: rootWidget.walColors.colors.color2
                border.width: 0
                opacity: rootWidget.isPlaying ? 0.5 : 0.0
                Behavior on opacity { NumberAnimation { duration: 500 } }
                
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 32
                    blur: 1.0
                    brightness: 1
                }
            }

            // Fallback icon when no art
            Text {
                anchors.centerIn: parent
                text: "♪"
                color: rootWidget.walColors.special.foreground
                font.pixelSize: 28
                opacity: albumArt.status !== Image.Ready ? 0.4 : 0.0
                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }
            }
        }

        // Track details (vertically stacked)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 4

            Text {
                text: rootWidget.hasSpotify ? (rootWidget.spotifyPlayer.trackTitle || "Unknown") : "Nothing playing"
                color: rootWidget.walColors.special.foreground
                font.family: "JetBrains Mono"
                font.pixelSize: 16
                font.weight: Font.Bold
                elide: Text.ElideRight
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                text: rootWidget.hasSpotify ? (rootWidget.spotifyPlayer.trackArtist || "Unknown") : "Start playing some music"
                color: rootWidget.walColors.special.foreground
                font.family: "JetBrains Mono"
                font.pixelSize: 12
                font.weight: Font.Normal
                opacity: 0.65
                elide: Text.ElideRight
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                text: rootWidget.hasSpotify ? (rootWidget.spotifyPlayer.trackAlbum || "") : ""
                color: rootWidget.walColors.special.foreground
                font.family: "JetBrains Mono"
                font.pixelSize: 11
                font.weight: Font.Normal
                opacity: 0.45
                elide: Text.ElideRight
                Layout.fillWidth: true
                visible: text !== ""
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // ── Progress bar ──────────────────────────────────────
    ColumnLayout {
        id: progressSection
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        spacing: 5

        // Seek bar
        Item {
            Layout.fillWidth: true
            height: 6

            // Track background
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.1)
            }

            // Filled portion
            Rectangle {
                id: progressBar
                anchors {
                    left:   parent.left
                    top:    parent.top
                    bottom: parent.bottom
                }
                radius: height / 2

                property real ratio: rootWidget.trackLength > 0 ? Math.min(1.0, rootWidget.trackPosition / rootWidget.trackLength) : 0

                width: Math.max(radius * 2, parent.width * ratio)

                Behavior on width {
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                }

                color: rootWidget.walColors.colors.color2

                // Glowing dot at end
                Rectangle {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        rightMargin: -4
                    }
                    width: 10
                    height: 10
                    radius: 5
                    color: rootWidget.walColors.colors.color2
                    visible: progressBar.ratio > 0.01

                    // Subtle glow
                    Rectangle {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        radius: 8
                        color: "transparent"
                        border.color: Qt.rgba(rootWidget.walColors.colors.color2.r, rootWidget.walColors.colors.color2.g, rootWidget.walColors.colors.color2.b, 0.3)
                        border.width: 2
                    }
                }
            }

            // Seek click area
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                onClicked: function(mouse) {
                    if (!rootWidget.hasSpotify || rootWidget.trackLength <= 0) return;
                    var ratio = Math.max(0, Math.min(1, mouse.x / parent.width));
                    rootWidget.spotifyPlayer.position = ratio * rootWidget.trackLength;
                    rootWidget.trackPosition = ratio * rootWidget.trackLength;
                }
            }
        }

        // Timestamps
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: rootWidget.formatTime(rootWidget.trackPosition)
                color: rootWidget.walColors.special.foreground
                font.family: "JetBrains Mono"
                font.pixelSize: 10
                opacity: 0.6
            }

            Item { Layout.fillWidth: true }

            Text {
                text: rootWidget.trackLength > 0 ? rootWidget.formatTime(rootWidget.trackLength) : "--:--"
                color: rootWidget.walColors.special.foreground
                font.family: "JetBrains Mono"
                font.pixelSize: 10
                opacity: 0.6
            }
        }
    }

    // ── Controls row: 🔀 ⏮ ⏸ ⏭ 🔁 ──────────────────────
    RowLayout {
        id: controlsRow
        z: 5
        Layout.alignment: Qt.AlignHCenter
        spacing: 14
        visible: rootWidget.hasSpotify

        // Previous
        ControlButton {
            icon: ""
            onClicked: { if (rootWidget.hasSpotify) rootWidget.spotifyPlayer.previous() }
        }

        // Play / Pause
        ControlButton {
            icon: rootWidget.isPlaying ? "" : ""
            highlighted: rootWidget.isPlaying
            onClicked: {
                if (!rootWidget.hasSpotify) return;
                if (rootWidget.isPlaying)
                    rootWidget.spotifyPlayer.pause();
                else
                    rootWidget.spotifyPlayer.play();
            }
        }

        // Next
        ControlButton {
            icon: ""
            onClicked: { if (rootWidget.hasSpotify) rootWidget.spotifyPlayer.next() }
        }
    }

        } // End of Left Column

        // RIGHT COLUMN (Equalizer)
        ColumnLayout {
            id: eqSection
            Layout.fillWidth: true
            Layout.fillHeight: true
        spacing: 14
        visible: rootWidget.hasSpotify

        Text {
            text: "EQUALIZER"
            color: rootWidget.walColors.special.foreground
            font.family: "JetBrains Mono"
            font.pixelSize: 13
            font.weight: Font.Bold
            opacity: 0.8
            Layout.alignment: Qt.AlignHCenter
        }
        
        ColumnLayout {
            id: eqContent
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

        // 10-Band Sliders row
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 180

            Canvas {
                id: lightningCanvas
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    bottomMargin: 20 // Account for label height + spacing
                }
                opacity: 1.0 - expandedPlayer.eqLightningFade
                z: 0
                renderTarget: Canvas.FramebufferObject

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: rootWidget.walColors.colors.color2
                    shadowBlur: 1.0
                    brightness: 0.3
                    shadowOpacity: 0.6
                }

                Timer {
                    interval: 16
                    running: expandedPlayer.eqLightningFade < 1.0 && expandedPlayer.eqLightningProgress > 0.0
                    repeat: true
                    onTriggered: lightningCanvas.requestPaint()
                }

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    if (expandedPlayer.eqLightningProgress <= 0.0 || expandedPlayer.eqLightningFade >= 1.0) return;

                    var time = Date.now() / 1000;
                    var maxIdx = expandedPlayer.eqLightningProgress;

                    ctx.lineJoin = "round";
                    ctx.lineCap = "round";

                    var pts = [];
                    var itemWidth = width / 10;
                    for (var i = 0; i < 10; i++) {
                        var col = slidersRepeater.itemAt(i);
                        var val = col ? col.sliderVal : 0;
                        var px = (i + 0.5) * itemWidth;
                        var py = (height / 2) - (val / 10.0) * (height / 2);
                        pts.push({ x: px, y: py });
                    }

                    for (var s = 0; s < 4; s++) {
                        ctx.beginPath();
                        ctx.moveTo(pts[0].x, pts[0].y);

                        for (var i = 0; i < pts.length - 1; i++) {
                            if (i > maxIdx) break;

                            var p1 = pts[i];
                            var p2 = pts[i+1];
                            var fraction = (maxIdx < i + 1) ? maxIdx - i : 1.0;

                            var steps = s === 3 ? 6 : 8;
                            for (var j = 1; j <= steps; j++) {
                                var t = j / steps;
                                if (t > fraction) t = fraction;

                                var cx = p1.x + (p2.x - p1.x) * t;
                                var cy = p1.y + (p2.y - p1.y) * t;

                                var envelope = Math.sin(t * Math.PI);
                                var noiseAmpY = s === 3 ? 1.0 : (4 - s) * 3; 

                                var noiseY = Math.cos(time * (9-s) + i - j) * Math.sin(time * 7 + i - j) * noiseAmpY * envelope * (1 - expandedPlayer.eqLightningFade);

                                ctx.lineTo(cx, cy + noiseY);
                                if (t === fraction) break;
                            }
                        }

                        if (s === 0) {
                            ctx.lineWidth = 12;
                            ctx.strokeStyle = rootWidget.walColors.colors.color2;
                            ctx.globalAlpha = 0.2;
                        } else if (s === 1) {
                            ctx.lineWidth = 5;
                            ctx.strokeStyle = rootWidget.walColors.colors.color3 || rootWidget.walColors.colors.color2;
                            ctx.globalAlpha = 0.45;
                        } else if (s === 2) {
                            ctx.lineWidth = 2.5;
                            ctx.strokeStyle = rootWidget.walColors.colors.color4 || rootWidget.walColors.colors.color2;
                            ctx.globalAlpha = 0.85;
                        } else if (s === 3) {
                            ctx.lineWidth = 1.0;
                            ctx.strokeStyle = "#ffffff";
                            ctx.globalAlpha = 0.1;
                        }
                        ctx.stroke();
                    }
                }
            }

        RowLayout {
            anchors.fill: parent
            spacing: 6

            Repeater {
                id: slidersRepeater
                model: ["31", "62", "125", "250", "500", "1K", "2K", "4K", "8K", "16K"]
                
                ColumnLayout {
                    id: sliderCol
                    property alias sliderVal: sliderItem.dragValue

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    spacing: 6

                    // Slider Track & Thumb Container
                    Item {
                        id: sliderItem
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        // Fake initial values for visual variety
                        property real simulateValue: {
                            var map = [2, 4, 1, -2, -3, 0, 3, 5, 2, 4];
                            return map[index]; // Between -10 and 10
                        }

                        // Store the current dragged value here
                        property real dragValue: simulateValue
                        
                        Behavior on dragValue {
                            NumberAnimation { duration: 400; easing.type: Easing.OutQuart }
                        }

                        // Background track
                        Rectangle {
                            anchors.centerIn: parent
                            width: 6
                            height: parent.height
                            radius: 3
                            color: Qt.rgba(1, 1, 1, 0.1)
                            
                            // Highlighted filled portion from base (0)
                            Rectangle {
                                width: 6
                                radius: 3
                                color: rootWidget.walColors.colors.color2
                                opacity: 0.8
                                x: 0
                                y: parent.parent.dragValue >= 0 ? parent.height/2 - (parent.parent.dragValue/10)*(parent.height/2) : parent.height/2
                                height: Math.abs(parent.parent.dragValue/10) * (parent.height/2)
                            }
                        }

                        // Interactive Thumb
                        Rectangle {
                            id: thumb
                            width: 14
                            height: 14
                            radius: 7
                            color: rootWidget.walColors.special.foreground
                            
                            // Position thumb purely based on dragValue (-10 to 10)
                            x: parent.width/2 - width/2
                            y: parent.height/2 - (parent.dragValue/10)*(parent.height/2) - height/2

                            // Subtle glow
                            Rectangle {
                                anchors.centerIn: parent
                                width: 22
                                height: 22
                                radius: 11
                                color: "transparent"
                                border.color: rootWidget.walColors.colors.color2
                                border.width: 2
                                opacity: sliderMouseArea.pressed ? 0.8 : 0.3
                            }
                        }

                        MouseArea {
                            id: sliderMouseArea
                            anchors.fill: parent
                            anchors.margins: -10
                            
                            // Map drag visually
                            function updateVal(mouseY) {
                                var mapped = 10 - (mouseY / parent.height) * 20;
                                mapped = Math.max(-10, Math.min(10, mapped));
                                parent.dragValue = mapped;
                            }
                            
                            onPressed: (mouse) => updateVal(mouse.y)
                            onPositionChanged: (mouse) => updateVal(mouse.y)
                            onReleased: {
                                expandedPlayer.execCmd(`$HOME/.config/quickshell/DynamicIsland/music/music_eq/equalizer.sh set_band ${index + 1} ${parent.dragValue.toFixed(1)}`);
                                expandedPlayer.execCmd(`$HOME/.config/quickshell/DynamicIsland/music/music_eq/equalizer.sh apply`);
                            }
                        }
                    }

                    // Label
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredHeight: 14
                        text: modelData
                        color: rootWidget.walColors.special.foreground
                        font.family: "JetBrains Mono"
                        font.pixelSize: 9
                        opacity: 0.6
                    }
                }
            }
        }
        } // End Item wrapper for RowLayout/Canvas

        // Presets Buttons Grid
        GridLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            columns: 4
            rowSpacing: 8
            columnSpacing: 12
            Layout.topMargin: 8

            Repeater {
                model: ["Flat", "Bass", "Treble", "Vocal", "Pop", "Rock", "Jazz", "Classic"]
                
                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 30
                    radius: 12
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.color: presetArea.containsMouse ? rootWidget.walColors.colors.color2 : "transparent"
                    border.width: 1
                    
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: rootWidget.walColors.special.foreground
                        font.family: "JetBrains Mono"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                    }
                    
                    MouseArea {
                        id: presetArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            var presets = {
                                "Flat": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                                "Bass": [5, 7, 5, 2, 1, 0, 0, 0, 1, 2],
                                "Treble": [-2, -1, 0, 1, 2, 3, 4, 5, 6, 6],
                                "Vocal": [-2, -1, 1, 3, 5, 5, 4, 2, 1, 0],
                                "Pop": [2, 4, 2, 0, 1, 2, 4, 2, 1, 2],
                                "Rock": [5, 4, 2, -1, -2, -1, 2, 4, 5, 6],
                                "Jazz": [3, 3, 1, 1, 1, 1, 2, 1, 2, 3],
                                "Classic": [0, 1, 2, 2, 2, 2, 1, 2, 3, 4]
                            };
                            var vals = presets[modelData] || presets["Flat"];
                            for (var i = 0; i < 10; i++) {
                                var col = slidersRepeater.itemAt(i);
                                if (col) col.sliderVal = vals[i];
                            }
                            expandedPlayer.triggerEqLightning();
                            expandedPlayer.execCmd(`$HOME/.config/quickshell/DynamicIsland/music/music_eq/equalizer.sh preset ${modelData}`);
                        }
                    }
                }
            }
        }
        } // End eqContent ColumnLayout
        } // End RIGHT COLUMN ColumnLayout
    } // End Main RowLayout
}