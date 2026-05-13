import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// Spotlight-style unified search launcher.
// Categories: Apps, Files (plocate), Web (firefox --search), Math (qalculate).
// Prefixes: ? = web only, : = files only, = = math only, no prefix = all.
Item {
    id: launcher
    property var rootWidget
    property var appUsages: ({})

    readonly property int itemHeight: 44
    readonly property int headerHeight: 28
    readonly property int searchBarHeight: 48
    readonly property int dividerHeight: 1
    readonly property int maxApps: 5
    readonly property int maxFiles: 5
    readonly property int maxRecent: 8

    property var appResults: []
    property var fileResults: []
    property string calcResult: ""   // last qalc answer
    property bool calcPending: false  // waiting for qalc process
    property var selectableIndices: []
    property int currentSelIdx: 0

    ListModel { id: allAppsModel }
    ListModel { id: resultModel }

    property int preferredHeight: {
        let h = searchBarHeight + dividerHeight
        for (let i = 0; i < resultModel.count; i++)
            h += resultModel.get(i).type === "header" ? headerHeight : itemHeight
        if (resultModel.count === 0) h += itemHeight
        return Math.min(h, 520)
    }

    // Stored properties — updated imperatively by updateSearch()
    // to avoid QML binding evaluation order issues (stale last-char).
    property string searchMode: "all"
    property string cleanQuery: ""

    property string placeholderText: {
        if (searchMode === "web")   return "Search the web..."
        if (searchMode === "files") return "Search files..."
        if (searchMode === "math")  return "Enter expression (e.g. 2^10, sin(45 deg))..."
        return "Spotlight Search"
    }

    // ─── Fuzzy scoring ───────────────────────────────────────────────────
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

    // ─── Filter apps into appResults ─────────────────────────────────────
    function filterApps(query) {
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
                    sc += (appUsages[a.name] || 0) * 0.1
                    scored.push({ sc: sc, a: a })
                }
            }
        }
        scored.sort((x, y) => y.sc - x.sc || x.a.name.localeCompare(y.a.name))
        let max = q ? maxApps : maxRecent
        appResults = scored.slice(0, max).map(s => ({
            type: "app", label: s.a.name, icon: s.a.icon,
            exec: s.a.exec, desktop: s.a.desktop,
            keywords: s.a.keywords || "", terminal: s.a.terminal || "false", path: "", isDir: false
        }))
        buildResults()
    }

    // ─── Build unified result model ──────────────────────────────────────
    function buildResults() {
        resultModel.clear()
        let indices = []
        let q = cleanQuery
        let mode = searchMode

        if (!q) {
            // No query → recent apps
            if (appResults.length > 0) {
                resultModel.append({ type: "header", label: "RECENT", icon: "", exec: "", desktop: "", keywords: "", terminal: "false", path: "", isDir: false })
                for (let a of appResults) {
                    indices.push(resultModel.count)
                    resultModel.append(a)
                }
            }
        } else {
            // Math result (= prefix or pending)
            if (mode === "math") {
                resultModel.append({ type: "header", label: "RESULT", icon: "", exec: "", desktop: "", keywords: "", terminal: "false", path: "", isDir: false })
                let resultLabel = calcPending ? "Calculating..." : (calcResult.length > 0 ? q + "  =  " + calcResult : "Not a valid expression")
                indices.push(resultModel.count)
                resultModel.append({
                    type: "calc", label: resultLabel, icon: "",
                    exec: "", desktop: "", keywords: "", terminal: "false", path: calcResult, isDir: false
                })
            } else {
                // Apps
                if (mode !== "web" && mode !== "files" && appResults.length > 0) {
                    resultModel.append({ type: "header", label: "APPS", icon: "", exec: "", desktop: "", keywords: "", terminal: "false", path: "", isDir: false })
                    for (let a of appResults) {
                        indices.push(resultModel.count)
                        resultModel.append(a)
                    }
                }
                // Files
                if (mode !== "web" && fileResults.length > 0) {
                    resultModel.append({ type: "header", label: "FILES", icon: "", exec: "", desktop: "", keywords: "", terminal: "false", path: "", isDir: false })
                    for (let f of fileResults) {
                        indices.push(resultModel.count)
                        resultModel.append(f)
                    }
                }
                // Web
                if (mode !== "files") {
                    resultModel.append({ type: "header", label: "WEB", icon: "", exec: "", desktop: "", keywords: "", terminal: "false", path: "", isDir: false })
                    indices.push(resultModel.count)
                    resultModel.append({
                        type: "web", label: "Search \"" + q + "\" in Firefox",
                        icon: "󰖟", exec: "firefox --search \"" + q + "\"",
                        desktop: "", keywords: "", terminal: "false", path: "", isDir: false
                    })
                }
            }
        }

        selectableIndices = indices
        if (indices.length > 0) {
            currentSelIdx = 0
            resultList.currentIndex = indices[0]
        }
    }

    // ─── Keyboard navigation (skip headers) ──────────────────────────────
    function navigateUp() {
        if (currentSelIdx > 0) {
            currentSelIdx--
            resultList.currentIndex = selectableIndices[currentSelIdx]
        }
    }
    function navigateDown() {
        if (currentSelIdx < selectableIndices.length - 1) {
            currentSelIdx++
            resultList.currentIndex = selectableIndices[currentSelIdx]
        }
    }

    // ─── Execute selected item ───────────────────────────────────────────
    function executeItem(idx) {
        if (idx < 0 || idx >= resultModel.count) return
        let item = resultModel.get(idx)
        if (item.type === "header") return

        if (item.type === "app") {
            logUsageProc.appName = item.label
            logUsageProc.running = false
            logUsageProc.running = true
            let execCmd = item.exec
            if (item.terminal === "true" || item.terminal === "True")
                execCmd = "kitty -e zsh -i -c '" + item.exec + "'"
            launchProc.launchCmd = execCmd
            launchProc.running = false
            launchProc.running = true
            if (rootWidget.launcherOpen) rootWidget.toggleLauncher()
        } else if (item.type === "file") {
            // Open directory or select file in dolphin
            if (item.isDir) {
                launchProc.launchCmd = "dolphin \"" + item.path + "\""
            } else {
                launchProc.launchCmd = "dolphin --select \"" + item.path + "\""
            }
            launchProc.running = false
            launchProc.running = true
            if (rootWidget.launcherOpen) rootWidget.toggleLauncher()
        } else if (item.type === "web") {
            launchProc.launchCmd = item.exec
            launchProc.running = false
            launchProc.running = true
            if (rootWidget.launcherOpen) rootWidget.toggleLauncher()
        } else if (item.type === "calc") {
            // Copy result to clipboard — don't close launcher so user can see it
            if (item.path.length > 0) {
                clipProc.textToCopy = item.path
                clipProc.running = false
                clipProc.running = true
            }
        }
    }

    function reload() {
        searchInput.text = ""
        fileResults = []
        getUsageProc.running = false
        getUsageProc.running = true
        filterApps("")
        appsProc.running = false
        appsProc.running = true
        focusTimer.start()
    }

    function updateSearch() {
        // Compute mode & query imperatively from the *current* text
        // (avoids stale binding reads that drop the last character).
        let raw = searchInput.text.trim()
        if (raw.startsWith("?"))      { searchMode = "web";   cleanQuery = raw.substring(1).trim() }
        else if (raw.startsWith(":")) { searchMode = "files"; cleanQuery = raw.substring(1).trim() }
        else if (raw.startsWith("=")) { searchMode = "math";  cleanQuery = raw.substring(1).trim() }
        else                          { searchMode = "all";   cleanQuery = raw }

        let q = cleanQuery
        let mode = searchMode

        if (mode === "math") {
            calcResult = ""
            if (q.length >= 1) {
                calcPending = true
                buildResults()
                calcDebounce.restart()
            } else {
                calcPending = false
                buildResults()
            }
            return
        }

        calcResult = ""
        calcPending = false

        if (mode !== "web" && mode !== "files")
            filterApps(q)
        else {
            appResults = []
            buildResults()
        }
        // Trigger file search with debounce
        if (q.length >= 2 && mode !== "web")
            fileDebounce.restart()
        else {
            fileResults = []
            buildResults()
        }
    }

    Timer { id: focusTimer; interval: 80; onTriggered: searchInput.forceActiveFocus() }

    Timer {
        id: fileDebounce
        interval: 200
        onTriggered: {
            let q = launcher.cleanQuery
            if (q.length >= 2) {
                fileSearchProc.running = false
                fileSearchProc.running = true
            }
        }
    }

    Timer {
        id: calcDebounce
        interval: 300
        onTriggered: {
            let q = launcher.cleanQuery
            if (q.length >= 1 && launcher.searchMode === "math") {
                qalcProc.running = false
                qalcProc.running = true
            }
        }
    }

    // ─── Processes ───────────────────────────────────────────────────────
    Process {
        id: getUsageProc
        command: ["bash", "-c", "cat ~/.cache/quickshell_app_usage.json 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { launcher.appUsages = JSON.parse(this.text) }
                catch(e) { launcher.appUsages = {} }
                if (allAppsModel.count > 0) launcher.filterApps(searchInput.text)
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
                launcher.filterApps(searchInput.text)
            }
        }
    }

    Process {
        id: launchProc
        property string launchCmd: ""
        command: ["hyprctl", "dispatch", "hl.dsp.exec_cmd([[" + launchCmd + "]])"]
    }

    Process {
        id: clipProc
        property string textToCopy: ""
        command: ["bash", "-c", "printf '%s' " + JSON.stringify(textToCopy) + " | wl-copy"]
    }

    Process {
        id: qalcProc
        command: ["qalc", "--terse", launcher.cleanQuery]
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = this.text.trim()
                let q   = launcher.cleanQuery.trim()
                launcher.calcPending = false
                // Only accept the result if it differs from the input
                if (raw.length > 0 && raw !== q) {
                    launcher.calcResult = raw
                } else {
                    launcher.calcResult = ""
                }
                launcher.buildResults()
            }
        }
    }


    Process {
        id: fileSearchProc
        // Pass query securely via bash positional args, and let bash expand ~ to $HOME
        command: ["bash", "-c", "plocate -i -l 8 \"${1/#~/$HOME}\"", "_", launcher.cleanQuery]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n").filter(l => l.length > 0)
                let results = []
                for (let line of lines) {
                    let parts = line.split("/")
                    let basename = parts[parts.length - 1]
                    // Detect directory: plocate returns the path as-is;
                    // we check if the basename has no extension (rough heuristic)
                    // and rely on a follow-up stat check via bash
                    results.push({
                        type: "file",
                        label: basename,
                        icon: "󰈔",   // overridden in delegate based on isDir
                        exec: "", desktop: "", keywords: "", terminal: "false",
                        path: line,
                        isDir: false   // filled in by statProc below
                    })
                }
                launcher.fileResults = results
                // Run stat check to identify directories
                if (lines.length > 0) {
                    statProc.pathList = lines.join("\n")
                    statProc.running = false
                    statProc.running = true
                } else {
                    launcher.buildResults()
                }
            }
        }
    }

    // Stat check: determine which paths are directories
    // Uses newline separator so paths with spaces are handled correctly.
    Process {
        id: statProc
        property string pathList: ""   // newline-joined list of paths
        command: ["bash", "-c",
            "printf '%s\\n' \"$1\" | while IFS= read -r p; do [ -z \"$p\" ] && continue; [ -d \"$p\" ] && echo \"DIR:$p\" || echo \"FILE:$p\"; done",
            "_", pathList]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n").filter(l => l.length > 0)
                let dirSet = {}
                for (let line of lines) {
                    if (line.startsWith("DIR:")) dirSet[line.substring(4)] = true
                }
                // Update isDir on fileResults
                let updated = []
                for (let r of launcher.fileResults) {
                    let copy = Object.assign({}, r)
                    copy.isDir = dirSet[r.path] === true
                    updated.push(copy)
                }
                launcher.fileResults = updated
                launcher.buildResults()
            }
        }
    }

    // ─── UI ──────────────────────────────────────────────────────────────
    Column {
        anchors.fill: parent
        spacing: 0

        // ── Search bar ───────────────────────────────────────────
        Row {
            width: parent.width
            height: searchBarHeight
            spacing: 12

            Text {
                text: "󰍉"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 20
                color: rootWidget.walColors.special.foreground
                opacity: 0.5
                anchors.verticalCenter: parent.verticalCenter
            }

            Item {
                width: parent.width - 32 - 12
                height: parent.height

                Text {
                    visible: searchInput.text.length === 0
                    text: launcher.placeholderText
                    font.family: "JetBrains Mono"
                    font.pixelSize: 14
                    color: rootWidget.walColors.special.foreground
                    opacity: 0.35
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
                        rootWidget.walColors.colors.color2.b, 0.35
                    )
                    onTextChanged: launcher.updateSearch()
                    Keys.onUpPressed:     function(event) { launcher.navigateUp(); event.accepted = true }
                    Keys.onDownPressed:   function(event) { launcher.navigateDown(); event.accepted = true }
                    Keys.onReturnPressed: function(event) { launcher.executeItem(resultList.currentIndex); event.accepted = true }
                    Keys.onEscapePressed: function(event) { if (rootWidget.launcherOpen) rootWidget.toggleLauncher(); event.accepted = true }
                    Keys.onTabPressed:    function(event) { launcher.navigateDown(); event.accepted = true }
                }
            }
        }

        // ── Divider ──────────────────────────────────────────────
        Rectangle {
            width: parent.width
            height: dividerHeight
            color: Qt.rgba(
                rootWidget.walColors.special.foreground.r,
                rootWidget.walColors.special.foreground.g,
                rootWidget.walColors.special.foreground.b, 0.12
            )
        }

        // ── Results ──────────────────────────────────────────────
        ListView {
            id: resultList
            width: parent.width
            height: parent.height - (searchBarHeight + dividerHeight)
            clip: true
            model: resultModel
            currentIndex: 0
            boundsBehavior: Flickable.StopAtBounds
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            // Empty state
            Text {
                anchors.centerIn: parent
                visible: resultModel.count === 0 && searchInput.text.length > 0
                text: "No results found"
                font.family: "JetBrains Mono"
                font.pixelSize: 13
                color: rootWidget.walColors.special.foreground
                opacity: 0.35
            }

            delegate: Loader {
                width: resultList.width
                height: model.type === "header" ? headerHeight : itemHeight
                sourceComponent: model.type === "header" ? headerDelegate : itemDelegate

                Component {
                    id: headerDelegate
                    Item {
                        width: resultList.width
                        height: headerHeight
                        Text {
                            text: model.label
                            font.family: "JetBrains Mono"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 1.5
                            color: rootWidget.walColors.special.foreground
                            opacity: 0.35
                            anchors {
                                left: parent.left; leftMargin: 4
                                bottom: parent.bottom; bottomMargin: 4
                            }
                        }
                    }
                }

                Component {
                    id: itemDelegate
                    Rectangle {
                        width: resultList.width
                        height: itemHeight
                        radius: 10
                        color: resultList.currentIndex === index
                            ? Qt.rgba(rootWidget.walColors.colors.color2.r, rootWidget.walColors.colors.color2.g, rootWidget.walColors.colors.color2.b, 0.15)
                            : itemHover.containsMouse
                                ? Qt.rgba(rootWidget.walColors.special.foreground.r, rootWidget.walColors.special.foreground.g, rootWidget.walColors.special.foreground.b, 0.06)
                                : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Row {
                            anchors { left: parent.left; right: parent.right; margins: 10; verticalCenter: parent.verticalCenter }
                            spacing: 12

                            // Icon area
                            Item {
                                width: 28; height: 28
                                anchors.verticalCenter: parent.verticalCenter
                                visible: model.type === "app"

                                Image {
                                    id: appIcon
                                    anchors.fill: parent
                                    source: {
                                        if (!model.icon) return ""
                                        if (model.icon.startsWith("/")) return "file://" + model.icon
                                        if (model.icon.startsWith("file://") || model.icon.startsWith("image://")) return model.icon
                                        return "image://icon/" + model.icon
                                    }
                                    fillMode: Image.PreserveAspectFit; asynchronous: true; smooth: true
                                }
                                Image {
                                    visible: appIcon.status !== Image.Ready
                                    anchors.fill: parent
                                    source: "../../assets/icons/package.png"
                                    fillMode: Image.PreserveAspectFit; smooth: true; asynchronous: true
                                }
                            }

                            // Nerd font icon for file / dir / web / calc
                            Text {
                                visible: model.type === "file" || model.type === "web" || model.type === "calc"
                                text: {
                                    if (model.type === "web")  return "󰖟"
                                    if (model.type === "calc") return "󰪚"
                                    return model.isDir ? "󰉋" : "󰈔"
                                }
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: 18
                                color: resultList.currentIndex === index
                                    ? rootWidget.walColors.colors.color2
                                    : rootWidget.walColors.special.foreground
                                opacity: resultList.currentIndex === index ? 1.0 : 0.6
                                width: 28
                                horizontalAlignment: Text.AlignHCenter
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // Label column
                            Column {
                                width: parent.width - 28 - 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1

                                Text {
                                    width: parent.width
                                    text: model.label
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    color: resultList.currentIndex === index
                                        ? rootWidget.walColors.colors.color2
                                        : rootWidget.walColors.special.foreground
                                    opacity: resultList.currentIndex === index ? 1.0 : 0.75
                                    elide: Text.ElideRight
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                // Subtitle: directory path for files, "Copy to clipboard" for calc
                                Text {
                                    visible: (model.type === "file" && model.path.length > 0)
                                             || model.type === "calc"
                                    width: parent.width
                                    text: {
                                        if (model.type === "calc") return "Press Enter to copy result"
                                        if (model.type !== "file" || !model.path) return ""
                                        let parts = model.path.split("/")
                                        parts.pop()
                                        return parts.join("/").replace(/^\/home\/[^/]+/, "~")
                                    }
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 10
                                    color: rootWidget.walColors.special.foreground
                                    opacity: 0.35
                                    elide: Text.ElideMiddle
                                }
                            }
                        }

                        MouseArea {
                            id: itemHover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: launcher.executeItem(index)
                        }
                    }
                }
            }
        }
    }
}
