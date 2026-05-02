import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// App launcher content that lives inside the dynamic island pill.
// Displayed when rootWidget.launcherOpen === true.
Item {
    id: launcherContent
    property var rootWidget
    property var appUsages: ({})
    readonly property int itemHeight: 48
    readonly property int searchBarHeight: 40
    readonly property int dividerHeight: 1
    readonly property int maxVisibleItems: 8

    property int preferredHeight: {
        let count = 0;
        if (searchInput.text.length === 0) {
            count = maxVisibleItems;
        } else {
            count = Math.min(filteredModel.count, maxVisibleItems);
            if (count === 0) count = 1; // For "No results found"
        }
        return searchBarHeight + dividerHeight + (count * itemHeight);
    }

    // ─── App data ─────────────────────────────────────────────────────────────
    ListModel { id: allAppsModel }
    ListModel { id: filteredModel }

    function fuzzyScore(name, query, keywords) {
        let n = name.toLowerCase(), q = query.toLowerCase()
        if (n === q)          return 5
        if (n.startsWith(q))  return 4
        if (n.includes(q))    return 3
        
        if (keywords) {
            let kw = keywords.toLowerCase()
            if (kw.includes(q)) return 2
        }

        let qi = 0
        for (let i = 0; i < n.length && qi < q.length; i++)
            if (n[i] === q[qi]) qi++
        return qi === q.length ? 1 : 0
    }

    function filterApps(query) {
        filteredModel.clear()
        let q = query.trim()
        
        let scored = []
        for (let i = 0; i < allAppsModel.count; i++) {
            let a = allAppsModel.get(i)
            let sc = 0
            
            if (!q) {
                sc = (appUsages[a.name] || 0)
                scored.push({ sc: sc, a: a })
            } else {
                sc = fuzzyScore(a.name, q, a.keywords)
                if (sc > 0) {
                    let usageBoost = (appUsages[a.name] || 0) * 0.1
                    sc += usageBoost
                    scored.push({ sc: sc, a: a })
                }
            }
        }
        
        scored.sort((x, y) => y.sc - x.sc || x.a.name.localeCompare(y.a.name))
        
        for (let i = 0; i < scored.length; i++) {
            let a = scored[i].a
            filteredModel.append({ name: a.name, exec: a.exec, icon: a.icon, desktop: a.desktop, keywords: a.keywords || "", terminal: a.terminal || "false" })
        }
        appList.currentIndex = 0
    }

    function launchApp(idx) {
        if (idx < 0 || idx >= filteredModel.count) return
        let a = filteredModel.get(idx)
        
        logUsageProc.appName = a.name
        logUsageProc.running = false
        logUsageProc.running = true

        let execCmd = a.exec
        if (a.terminal === "true" || a.terminal === "True") {
            execCmd = "kitty -e zsh -i -c '" + a.exec + "'"
        }
        launchProc.launchCmd = execCmd
        launchProc.running = false
        launchProc.running = true
        if (rootWidget.launcherOpen) {
            rootWidget.toggleLauncher()
        }
    }

    function reload() {
        searchInput.text = ""
        getUsageProc.running = false
        getUsageProc.running = true
        filterApps("")
        appsProc.running = false
        appsProc.running = true
        focusTimer.start()
    }

    // Small delay so the TextInput is fully visible before we focus it
    Timer {
        id: focusTimer
        interval: 80
        onTriggered: searchInput.forceActiveFocus()
    }

    // ─── Processes ────────────────────────────────────────────────────────────
    Process {
        id: getUsageProc
        command: ["bash", "-c", "cat ~/.cache/quickshell_app_usage.json 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    launcherContent.appUsages = JSON.parse(this.text)
                } catch(e) {
                    launcherContent.appUsages = {}
                }
                if (allAppsModel.count > 0) {
                    launcherContent.filterApps(searchInput.text)
                }
            }
        }
    }

    Process {
        id: logUsageProc
        property string appName: ""
        command: ["python3", "-c", "import json, sys, os\nf = os.path.expanduser('~/.cache/quickshell_app_usage.json')\nd = {}\ntry:\n with open(f, 'r') as file: d = json.load(file)\nexcept: pass\napp = sys.argv[1]\nd[app] = d.get(app, 0) + 1\nwith open(f, 'w') as file: json.dump(d, file)", appName]
    }

    Process {
        id: appsProc
        command: ["bash", "-c", "bash $HOME/.config/quickshell/components/get_app.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                allAppsModel.clear()
                let lines = this.text.trim().split("\n")
                for (let i = 0; i < lines.length; i++) {
                    let p = lines[i].split("|")
                    if (p.length >= 2 && p[0])
                        allAppsModel.append({ name: p[0], exec: p[1], icon: p[2] || "", desktop: p[3] || "", keywords: p[4] || "", terminal: p[5] || "false" })
                }
                filterApps(searchInput.text)
            }
        }
    }

    Process {
        id: launchProc
        property string launchCmd: ""
        command: ["hyprctl", "dispatch", "hl.dsp.exec_cmd([[" + launchCmd + "]])"]
    }

    // ─── UI ───────────────────────────────────────────────────────────────────
    Column {
        anchors.fill: parent
        spacing: 0

        // ── Search bar ───────────────────────────────────────────────
        Row {
            width: parent.width
            height: searchBarHeight
            spacing: 10

            // Search icon
            Text {
                text: "󰍉"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 18
                color: rootWidget.walColors.special.foreground
                opacity: 0.5
                anchors.verticalCenter: parent.verticalCenter
            }

            Item {
                width: parent.width - 28 - 10
                height: parent.height

                Text {
                    visible: searchInput.text.length === 0
                    text: "Search apps..."
                    font.family: "JetBrains Mono"
                    font.pixelSize: 14
                    color: rootWidget.walColors.special.foreground
                    opacity: 0.5
                    anchors.verticalCenter: parent.verticalCenter
                }

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    font.family: "JetBrains Mono"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: rootWidget.walColors.special.foreground
                    verticalAlignment: TextInput.AlignVCenter
                    selectionColor: Qt.rgba(
                        rootWidget.walColors.colors.color2.r,
                        rootWidget.walColors.colors.color2.g,
                        rootWidget.walColors.colors.color2.b,
                        0.35
                    )

                    onTextChanged: launcherContent.filterApps(text)

                    Keys.onUpPressed:     function(event) { appList.decrementCurrentIndex(); event.accepted = true }
                    Keys.onDownPressed:   function(event) { appList.incrementCurrentIndex(); event.accepted = true }
                    Keys.onReturnPressed: function(event) { launcherContent.launchApp(appList.currentIndex); event.accepted = true }
                    Keys.onEscapePressed: function(event) { if (rootWidget.launcherOpen) rootWidget.toggleLauncher(); event.accepted = true }
                    Keys.onTabPressed:    function(event) { appList.incrementCurrentIndex(); event.accepted = true }
                }
            }
        }

        // ── Divider ──────────────────────────────────────────────────
        Rectangle {
            width: parent.width
            height: dividerHeight
            color: Qt.rgba(
                rootWidget.walColors.special.foreground.r,
                rootWidget.walColors.special.foreground.g,
                rootWidget.walColors.special.foreground.b,
                0.12
            )
        }

        // ── Results list ─────────────────────────────────────────────
        ListView {
            id: appList
            width: parent.width
            height: parent.height - (searchBarHeight + dividerHeight)
            clip: true
            model: filteredModel
            currentIndex: 0
            boundsBehavior: Flickable.StopAtBounds

            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            // Empty state
            Text {
                anchors.centerIn: parent
                visible: filteredModel.count === 0 && searchInput.text.length > 0
                text: "No results found"
                font.family: "JetBrains Mono"
                font.pixelSize: 13
                color: rootWidget.walColors.special.foreground
                opacity: 0.35
            }

            delegate: Rectangle {
                width: appList.width
                height: itemHeight
                radius: 12
                color: appList.currentIndex === index
                    ? Qt.rgba(
                        rootWidget.walColors.colors.color2.r,
                        rootWidget.walColors.colors.color2.g,
                        rootWidget.walColors.colors.color2.b,
                        0.15
                    )
                    : hoverArea.containsMouse
                        ? Qt.rgba(
                            rootWidget.walColors.special.foreground.r,
                            rootWidget.walColors.special.foreground.g,
                            rootWidget.walColors.special.foreground.b,
                            0.06
                        )
                        : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    anchors {
                        left: parent.left; right: parent.right
                        margins: 10; verticalCenter: parent.verticalCenter
                    }
                    spacing: 12

                    // Icon with letter fallback
                    Item {
                        width: 32; height: 32
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            id: appIcon
                            anchors.fill: parent
                            source: {
                                if (!model.icon) return ""
                                if (model.icon.startsWith("/")) return "file://" + model.icon
                                if (model.icon.startsWith("file://") || model.icon.startsWith("image://")) return model.icon
                                return "image://icon/" + model.icon
                            }
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                        }

                        Image {
                            visible: appIcon.status !== Image.Ready
                            anchors.fill: parent
                            source: "../../assets/icons/package.png"
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                        }
                    }

                    // App name
                    Text {
                        width: parent.width - 32 - 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: model.name
                        font.family: "JetBrains Mono"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: appList.currentIndex === index
                            ? rootWidget.walColors.colors.color2
                            : rootWidget.walColors.special.foreground
                        opacity: appList.currentIndex === index ? 1.0 : 0.75
                        elide: Text.ElideRight
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                }

                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: launcherContent.launchApp(index)
                    onEntered: appList.currentIndex = index
                }
            }
        }
    }
}
