import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls
import QtQuick.Shapes
import QtMultimedia
import ".."

// Wallpaper picker with parallelogram slices, ollama AI tagging, color/tag/type filtering
Scope {
  id: wallpaperSelector

  // External bindings
  property var colors
  property bool showing: false
  property alias selectedColorFilter: service.selectedColorFilter


  property string mainMonitor: Config.mainMonitor


  signal wallpaperChanged()


  function resetScroll() {
    wallpaperSelector.lastContentX = 0
    wallpaperSelector.lastIndex = 0
    sliceListView.currentIndex = 0
    if (service.filteredModel.count > 0)
      sliceListView.positionViewAtIndex(0, ListView.Beginning)
  }


  WallpaperSelectorService {
    id: service
    scriptsDir: Config.scriptsDir
    homeDir: Config.homeDir
    wallpaperDir: Config.wallpaperDir
    cacheBaseDir: Config.cacheDir
    weDir: Config.weDir
    weAssetsDir: Config.weAssetsDir
    ollamaStatusPollMs: Config.ollamaStatusPollMs
    showing: wallpaperSelector.showing
    onModelUpdated: {
      if (service.filteredModel.count > 0) {
        sliceListView.currentIndex = 0
        sliceListView.positionViewAtIndex(0, ListView.Beginning)
      }
    }
    onWallpaperApplied: wallpaperSelector.wallpaperChanged()
  }

  onShowingChanged: {
    if (showing) {
      _restorePending = true
      service.startCacheCheck()
      cardShowTimer.restart()
    } else {
      cardVisible = false
    }
  }


  Timer {
    id: cardShowTimer
    interval: 50
    onTriggered: wallpaperSelector.cardVisible = true
  }



  Timer {
    id: focusTimer
    interval: 50
    onTriggered: sliceListView.forceActiveFocus()
  }


  // Slice geometry constants
  property int sliceWidth: 135
  property int expandedWidth: 924
  property int sliceHeight: 520
  property int skewOffset: 35
  property int sliceSpacing: -22


  property int cardWidth: 1600
  property int topBarHeight: 50
  property bool tagCloudVisible: false
  property int tagCloudHeight: tagCloudVisible ? 120 : 0
  property int cardHeight: sliceHeight + topBarHeight + tagCloudHeight + 60


  property real lastContentX: 0
  property int lastIndex: 0
  property bool _restorePending: false


  property bool cardVisible: false


  // Full-screen overlay panel
  PanelWindow {
    id: selectorPanel

    screen: Quickshell.screens.find(s => s.name === wallpaperSelector.mainMonitor) ?? Quickshell.screens[0]

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }
    margins {
      top: 0
      bottom: 0
      left: 0
      right: 0
    }

    visible: wallpaperSelector.showing
    color: "transparent"

    WlrLayershell.namespace: "wallpaper-selector-parallel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: wallpaperSelector.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    exclusionMode: ExclusionMode.Ignore


    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.5)
      opacity: wallpaperSelector.cardVisible ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 300 } }
    }


    MouseArea {
      anchors.fill: parent
      onClicked: wallpaperSelector.showing = false
    }


  // Card container with fade-in
  Item {
    id: cardContainer
    width: wallpaperSelector.cardWidth
    height: wallpaperSelector.cardHeight
    anchors.centerIn: parent
    visible: wallpaperSelector.cardVisible


    opacity: 0
    property bool animateIn: wallpaperSelector.cardVisible

    onAnimateInChanged: {
      fadeInAnim.stop()
      if (animateIn) {
        opacity = 0
        fadeInAnim.start()
        focusTimer.restart()
      }
    }

    NumberAnimation {
      id: fadeInAnim
      target: cardContainer
      property: "opacity"
      from: 0; to: 1
      duration: 400
      easing.type: Easing.OutCubic
    }

    MouseArea {
      anchors.fill: parent
      onClicked: {}
    }


    // Ollama analysis status indicator (top-right)
    Rectangle {
      id: ollamaStatusIndicator
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: 8
      anchors.rightMargin: 8
      z: 100

      visible: service.ollamaActive
      opacity: service.ollamaActive ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 200 } }

      width: Math.max(ollamaStatusRow.width + 20, ollamaLogText.width + 20)
      height: service.ollamaLogLine ? 44 : 28
      radius: height / 2
      color: wallpaperSelector.colors ? Qt.rgba(wallpaperSelector.colors.surfaceContainer.r, wallpaperSelector.colors.surfaceContainer.g, wallpaperSelector.colors.surfaceContainer.b, 0.9) : Qt.rgba(0.1, 0.12, 0.18, 0.9)

      layer.enabled: false

      Column {
        anchors.centerIn: parent
        spacing: 2

        Row {
          id: ollamaStatusRow
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: 6

          Text {
            text: "󰔟"
            font.family: Style.fontFamilyNerdIcons
            font.pixelSize: 14
            color: wallpaperSelector.colors ? wallpaperSelector.colors.primary : "#8BC34A"
            RotationAnimation on rotation {
              from: 0; to: 360; duration: 1000
              loops: Animation.Infinite
              running: service.ollamaActive
            }
          }

          Text {
            text: {
              var status = "ANALYZING"
              var progress = ""
              if (service.ollamaTotalThumbs > 0) {
                progress = " " + service.ollamaTaggedCount + "/" + service.ollamaTotalThumbs
              }
              var eta = service.ollamaEta
              if (eta && eta !== "") return status + progress + " (" + eta + ")"
              return status + progress
            }
            font.family: Style.fontFamily
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 0.5
            color: wallpaperSelector.colors ? wallpaperSelector.colors.tertiary : "#8bceff"
          }
        }

        Text {
          id: ollamaLogText
          anchors.horizontalCenter: parent.horizontalCenter
          text: service.ollamaLogLine
          visible: service.ollamaLogLine !== ""
          font.family: Style.fontFamilyCode
          font.pixelSize: 9
          color: wallpaperSelector.colors ? Qt.rgba(wallpaperSelector.colors.surfaceText.r, wallpaperSelector.colors.surfaceText.g, wallpaperSelector.colors.surfaceText.b, 0.6) : Qt.rgba(1, 1, 1, 0.5)
          elide: Text.ElideMiddle
          maximumLineCount: 1
        }
      }
    }


  // Card contents (filter bar, tag cloud, context menu, progress)
  Item {
    id: backgroundRect
    anchors.fill: parent

    // Top filter bar background pill
    Rectangle {
      id: filterBarBg
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: 10
      width: topFilterBar.width + 30
      height: topFilterBar.height + 14
      radius: height / 2
      color: wallpaperSelector.colors ? Qt.rgba(wallpaperSelector.colors.surfaceContainer.r,
                                                 wallpaperSelector.colors.surfaceContainer.g,
                                                 wallpaperSelector.colors.surfaceContainer.b, 0.85)
                                      : Qt.rgba(0.1, 0.12, 0.18, 0.85)
      z: 10
    }

    // Top filter bar (type, color dots, sort, count)
    Row {
      id: topFilterBar
      anchors.centerIn: filterBarBg
      spacing: 20
      z: 11


      Row {
        id: typeFilterRow
        spacing: 4

        Repeater {
          model: [
            { type: "", icon: "󰄶", label: "All" },
            { type: "static", icon: "󰋩", label: "Pic" },
            { type: "video", icon: "󰕧", label: "Vid" },
            { type: "we", icon: "󰖔", label: "WE" }
          ]

          Rectangle {
            width: 32
            height: 24
            radius: 4
            property bool isSelected: service.selectedTypeFilter === modelData.type
            property bool isHovered: typeMouseArea.containsMouse

            color: isSelected
              ? (wallpaperSelector.colors ? wallpaperSelector.colors.primary : "#4fc3f7")
              : (isHovered
                ? (wallpaperSelector.colors ? Qt.rgba(wallpaperSelector.colors.surfaceVariant.r, wallpaperSelector.colors.surfaceVariant.g, wallpaperSelector.colors.surfaceVariant.b, 0.5) : Qt.rgba(1, 1, 1, 0.15))
                : "transparent")

            border.width: isSelected ? 0 : 1
            border.color: isHovered ? (wallpaperSelector.colors ? Qt.rgba(wallpaperSelector.colors.primary.r, wallpaperSelector.colors.primary.g, wallpaperSelector.colors.primary.b, 0.4) : Qt.rgba(1, 1, 1, 0.2)) : "transparent"

            Behavior on color { ColorAnimation { duration: 100 } }
            Behavior on border.color { ColorAnimation { duration: 100 } }

            Text {
              anchors.centerIn: parent
              text: modelData.icon
              font.pixelSize: 14
              font.family: Style.fontFamilyNerdIcons
              color: parent.isSelected
                ? (wallpaperSelector.colors ? wallpaperSelector.colors.primaryText : "#000")
                : (wallpaperSelector.colors ? wallpaperSelector.colors.tertiary : "#8bceff")
            }

            MouseArea {
              id: typeMouseArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (parent.isSelected) {
                  service.selectedTypeFilter = ""
                } else {
                  service.selectedTypeFilter = modelData.type
                }
              }
            }

            ToolTip {
              visible: typeMouseArea.containsMouse
              text: modelData.label
              delay: 500
              contentWidth: implicitContentWidth
            }
          }
        }
      }


      Rectangle {
        width: 1; height: 20
        color: wallpaperSelector.colors ? Qt.rgba(wallpaperSelector.colors.primary.r, wallpaperSelector.colors.primary.g, wallpaperSelector.colors.primary.b, 0.3) : Qt.rgba(1, 1, 1, 0.2)
      }


      // Color hue filter (parallelogram dots)
      Row {
        id: colorDotsRow
        spacing: -5

        Repeater {
          model: 13

          Item {
            width: 38; height: 20
            readonly property int filterValue: index < 12 ? index : 99
            readonly property bool isSelected: service.selectedColorFilter === filterValue
            readonly property color shapeColor: index === 12 ? "#777" : Qt.hsla(index / 12.0, 0.7, 0.5, 1.0)
            readonly property color shadowColor: index === 12 ? "#555" : Qt.hsla(index / 12.0, 0.8, 0.3, 1.0)

            Canvas {
              id: colorCanvas
              anchors.centerIn: parent
              width: parent.width; height: parent.height
              scale: parent.isSelected ? 1.15 : 1.0
              Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutBack } }

              property color fillColor: parent.shapeColor
              property color borderColor: index === 12 ? "#aaa" : Qt.hsla(index / 12.0, 0.7, 0.75, 1.0)
              property color dropShadowColor: parent.shadowColor
              property real fillOpacity: parent.isSelected ? 1.0 : 0.6
              property bool showShadow: parent.isSelected

              onFillColorChanged: requestPaint()
              onFillOpacityChanged: requestPaint()
              onShowShadowChanged: requestPaint()

              onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var skew = 15
                if (showShadow) {
                  ctx.globalAlpha = 0.6
                  ctx.fillStyle = dropShadowColor
                  ctx.beginPath()
                  ctx.moveTo(skew + 3, 2 + 3)
                  ctx.lineTo(width + 3, 2 + 3)
                  ctx.lineTo(width - skew + 3, 18 + 3)
                  ctx.lineTo(0 + 3, 18 + 3)
                  ctx.closePath()
                  ctx.fill()
                }
                ctx.globalAlpha = fillOpacity
                ctx.fillStyle = fillColor
                ctx.beginPath()
                ctx.moveTo(skew, 2)
                ctx.lineTo(width, 2)
                ctx.lineTo(width - skew, 18)
                ctx.lineTo(0, 18)
                ctx.closePath()
                ctx.fill()
                ctx.globalAlpha = fillOpacity
                ctx.strokeStyle = borderColor
                ctx.lineWidth = 1.5
                ctx.stroke()
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (parent.isSelected) {
                  service.selectedColorFilter = -1
                } else {
                  service.selectedColorFilter = parent.filterValue
                }
              }
            }
          }
        }
      }


      Rectangle {
        width: 1; height: 20
        color: wallpaperSelector.colors ? Qt.rgba(wallpaperSelector.colors.primary.r, wallpaperSelector.colors.primary.g, wallpaperSelector.colors.primary.b, 0.3) : Qt.rgba(1, 1, 1, 0.2)
      }


      Row {
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
          model: [
            { mode: "date", icon: "󰃰", label: "Newest" },
            { mode: "color", icon: "󰏘", label: "Color" }
          ]

          Rectangle {
            width: 32; height: 24; radius: 4
            property bool isSelected: service.sortMode === modelData.mode
            property bool isHovered: sortMouseArea.containsMouse

            color: isSelected
              ? (wallpaperSelector.colors ? wallpaperSelector.colors.primary : "#4fc3f7")
              : (isHovered
                ? (wallpaperSelector.colors ? Qt.rgba(wallpaperSelector.colors.surfaceVariant.r, wallpaperSelector.colors.surfaceVariant.g, wallpaperSelector.colors.surfaceVariant.b, 0.5) : Qt.rgba(1, 1, 1, 0.15))
                : "transparent")

            border.width: isSelected ? 0 : 1
            border.color: isHovered ? (wallpaperSelector.colors ? Qt.rgba(wallpaperSelector.colors.primary.r, wallpaperSelector.colors.primary.g, wallpaperSelector.colors.primary.b, 0.4) : Qt.rgba(1, 1, 1, 0.2)) : "transparent"

            Behavior on color { ColorAnimation { duration: 100 } }
            Behavior on border.color { ColorAnimation { duration: 100 } }

            Text {
              anchors.centerIn: parent
              text: modelData.icon
              font.pixelSize: 14
              font.family: Style.fontFamilyNerdIcons
              color: parent.isSelected
                ? (wallpaperSelector.colors ? wallpaperSelector.colors.primaryText : "#000")
                : (wallpaperSelector.colors ? wallpaperSelector.colors.tertiary : "#8bceff")
            }

            MouseArea {
              id: sortMouseArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                service.sortMode = modelData.mode
                service.updateFilteredModel()
              }
            }

            ToolTip {
              visible: sortMouseArea.containsMouse
              text: modelData.label
              delay: 500
              contentWidth: implicitContentWidth
            }
          }
        }
      }

      // Separator
      Rectangle {
        width: 1; height: 18
        color: wallpaperSelector.colors ? Qt.rgba(wallpaperSelector.colors.primary.r, wallpaperSelector.colors.primary.g, wallpaperSelector.colors.primary.b, 0.3) : Qt.rgba(1, 1, 1, 0.2)
        anchors.verticalCenter: parent.verticalCenter
      }

      // Favourite filter
      Rectangle {
        id: favFilterBtn
        width: 32; height: 24; radius: 4
        property bool isSelected: service.favouriteFilterActive
        property bool isHovered: favFilterMouse.containsMouse

        color: isSelected
          ? (wallpaperSelector.colors ? wallpaperSelector.colors.primary : "#4fc3f7")
          : (isHovered
            ? (wallpaperSelector.colors ? Qt.rgba(wallpaperSelector.colors.surfaceVariant.r, wallpaperSelector.colors.surfaceVariant.g, wallpaperSelector.colors.surfaceVariant.b, 0.5) : Qt.rgba(1, 1, 1, 0.15))
            : "transparent")

        border.width: isSelected ? 0 : 1
        border.color: isHovered ? (wallpaperSelector.colors ? Qt.rgba(wallpaperSelector.colors.primary.r, wallpaperSelector.colors.primary.g, wallpaperSelector.colors.primary.b, 0.4) : Qt.rgba(1, 1, 1, 0.2)) : "transparent"

        Behavior on color { ColorAnimation { duration: 100 } }
        Behavior on border.color { ColorAnimation { duration: 100 } }
        anchors.verticalCenter: parent.verticalCenter

        Text {
          anchors.centerIn: parent
          text: "󰋑"
          font.pixelSize: 14
          font.family: Style.fontFamilyNerdIcons
          color: parent.isSelected
            ? (wallpaperSelector.colors ? wallpaperSelector.colors.primaryText : "#000")
            : (wallpaperSelector.colors ? wallpaperSelector.colors.tertiary : "#8bceff")
        }

        MouseArea {
          id: favFilterMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: service.favouriteFilterActive = !service.favouriteFilterActive
        }

        ToolTip {
          visible: favFilterMouse.containsMouse
          text: "Favourites"
          delay: 500
          contentWidth: implicitContentWidth
        }
      }


      Text {
        text: service.filteredModel.count + (service.filteredModel.count !== service.wallpaperModel.count ? "/" + service.wallpaperModel.count : "")
        font.family: Style.fontFamily
        font.pixelSize: 11
        font.weight: Font.Medium
        color: wallpaperSelector.colors ? Qt.rgba(wallpaperSelector.colors.surfaceText.r, wallpaperSelector.colors.surfaceText.g, wallpaperSelector.colors.surfaceText.b, 0.5) : Qt.rgba(1, 1, 1, 0.4)
        anchors.verticalCenter: parent.verticalCenter
      }
    }


    // Tag cloud panel (toggled with Shift+Down)
    Rectangle {
      id: tagCloudBg
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: 10
      anchors.bottomMargin: 8
      height: wallpaperSelector.tagCloudVisible ? wallpaperSelector.tagCloudHeight + 4 : 0
      visible: wallpaperSelector.tagCloudVisible
      radius: 16
      color: wallpaperSelector.colors ? Qt.rgba(wallpaperSelector.colors.surfaceContainer.r,
                                                 wallpaperSelector.colors.surfaceContainer.g,
                                                 wallpaperSelector.colors.surfaceContainer.b, 0.85)
                                      : Qt.rgba(0.1, 0.12, 0.18, 0.85)

      Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    }


    Flickable {
      id: tagCloudFlickable
      anchors.fill: tagCloudBg
      anchors.margins: 8
      visible: wallpaperSelector.tagCloudVisible
      opacity: wallpaperSelector.tagCloudVisible ? 1.0 : 0.0
      clip: true
      contentWidth: width
      contentHeight: tagCloudRow.implicitHeight
      flickableDirection: Flickable.VerticalFlick
      boundsBehavior: Flickable.StopAtBounds

      Behavior on opacity { NumberAnimation { duration: 200 } }
      z: 11

      Rectangle {
        visible: tagCloudFlickable.contentHeight > tagCloudFlickable.height
        anchors.right: parent.right
        anchors.rightMargin: 2
        y: tagCloudFlickable.visibleArea.yPosition * tagCloudFlickable.height
        width: 4
        height: tagCloudFlickable.visibleArea.heightRatio * tagCloudFlickable.height
        radius: 2
        color: wallpaperSelector.colors ? wallpaperSelector.colors.primary : "#fff"
        opacity: 0.5
      }

      Flow {
        id: tagCloudRow
        width: parent.width - 10
        spacing: 8

        Repeater {
          model: service.popularTags

          Rectangle {
            id: tagChip
            width: tagText.width + 16
            height: 26
            radius: 4
            property bool isSelected: service.selectedTags.indexOf(modelData.tag) !== -1
            property bool isHovered: tagMouse.containsMouse

            color: isSelected
              ? (wallpaperSelector.colors ? wallpaperSelector.colors.primary : "#4fc3f7")
              : (isHovered
                ? (wallpaperSelector.colors ? Qt.rgba(wallpaperSelector.colors.surfaceVariant.r, wallpaperSelector.colors.surfaceVariant.g, wallpaperSelector.colors.surfaceVariant.b, 0.5) : "#444")
                : "transparent")

            border.width: isSelected ? 0 : 1
            border.color: isSelected ? "transparent" : (isHovered ? (wallpaperSelector.colors ? Qt.rgba(wallpaperSelector.colors.primary.r, wallpaperSelector.colors.primary.g, wallpaperSelector.colors.primary.b, 0.4) : Qt.rgba(1, 1, 1, 0.2)) : (wallpaperSelector.colors ? wallpaperSelector.colors.outline : Qt.rgba(1, 1, 1, 0.15)))

            Behavior on color { ColorAnimation { duration: 100 } }
            Behavior on border.color { ColorAnimation { duration: 100 } }

            Text {
              id: tagText
              anchors.centerIn: parent
              text: modelData.tag.toUpperCase()
              color: tagChip.isSelected
                ? (wallpaperSelector.colors ? wallpaperSelector.colors.primaryText : "#000")
                : (wallpaperSelector.colors ? wallpaperSelector.colors.tertiary : "#8bceff")
              font.family: Style.fontFamily
              font.pixelSize: 11
              font.weight: tagChip.isSelected ? Font.Bold : Font.Medium
              font.letterSpacing: 0.5
            }

            MouseArea {
              id: tagMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                var tags = service.selectedTags.slice()
                var idx = tags.indexOf(modelData.tag)
                if (idx !== -1) {
                  tags.splice(idx, 1)
                } else {
                  tags.push(modelData.tag)
                }
                service.selectedTags = tags
                service.updateFilteredModel()
              }
            }
          }
        }
      }
    }




    // Cache loading progress bar
    Rectangle {
      id: progressContainer
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottomMargin: 30
      width: 400
      height: 40
      radius: 20
      color: wallpaperSelector.colors ? Qt.rgba(wallpaperSelector.colors.surfaceContainer.r, wallpaperSelector.colors.surfaceContainer.g, wallpaperSelector.colors.surfaceContainer.b, 0.9) : Qt.rgba(0, 0, 0, 0.8)
      visible: service.cacheLoading
      opacity: service.cacheLoading ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 200 } }

      Rectangle {
        id: progressBg
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: 16
        height: 4
        radius: 2
        color: Qt.rgba(1, 1, 1, 0.1)

        Rectangle {
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          radius: 2
          width: service.cacheTotal > 0
            ? parent.width * (service.cacheProgress / service.cacheTotal)
            : 0
          color: wallpaperSelector.colors ? wallpaperSelector.colors.primary : "#4fc3f7"
          Behavior on width { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
        }
      }

      Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -12
        text: service.cacheTotal > 0
          ? "LOADING WALLPAPERS... " + service.cacheProgress + " / " + service.cacheTotal
          : "SCANNING..."
        color: wallpaperSelector.colors ? wallpaperSelector.colors.tertiary : "#8bceff"
        font.family: Style.fontFamily
        font.pixelSize: 12
        font.weight: Font.Medium
        font.letterSpacing: 0.5
      }
    }
  }
  }


    // Horizontal parallelogram slice list view
    ListView {
      id: sliceListView

      anchors.top: cardContainer.top
      anchors.topMargin: wallpaperSelector.topBarHeight + 15
      anchors.bottom: cardContainer.bottom
      anchors.bottomMargin: (wallpaperSelector.tagCloudVisible ? wallpaperSelector.tagCloudHeight : 0) + 20

      anchors.horizontalCenter: parent.horizontalCenter
      property int visibleCount: 12
      width: wallpaperSelector.expandedWidth + (visibleCount - 1) * (wallpaperSelector.sliceWidth + wallpaperSelector.sliceSpacing)

      orientation: ListView.Horizontal
      model: service.filteredModel
      clip: false
      spacing: wallpaperSelector.sliceSpacing

      flickDeceleration: 1500
      maximumFlickVelocity: 3000
      boundsBehavior: Flickable.StopAtBounds
      cacheBuffer: wallpaperSelector.expandedWidth * 4

      visible: wallpaperSelector.cardVisible

      property bool keyboardNavActive: false
      property real lastMouseX: -1
      property real lastMouseY: -1
      property bool animateRemoval: false

      Timer {
        id: removeAnimResetTimer
        interval: 350
        onTriggered: sliceListView.animateRemoval = false
      }

      highlightFollowsCurrentItem: true
      highlightMoveDuration: 350
      highlight: Item {}

      remove: Transition {
        enabled: sliceListView.animateRemoval
        NumberAnimation { property: "y"; to: sliceListView.height + 50; duration: 300; easing.type: Easing.InCubic }
        NumberAnimation { property: "opacity"; to: 0; duration: 300 }
      }
      displaced: Transition {
        enabled: sliceListView.animateRemoval
        NumberAnimation { properties: "x,y"; duration: 300; easing.type: Easing.OutCubic }
      }

      preferredHighlightBegin: (width - wallpaperSelector.expandedWidth) / 2
      preferredHighlightEnd: (width + wallpaperSelector.expandedWidth) / 2
      highlightRangeMode: ListView.StrictlyEnforceRange

      header: Item { width: (sliceListView.width - wallpaperSelector.expandedWidth) / 2; height: 1 }
      footer: Item { width: (sliceListView.width - wallpaperSelector.expandedWidth) / 2; height: 1 }

      focus: wallpaperSelector.showing
      onVisibleChanged: {
        if (visible) forceActiveFocus()
      }

      Connections {
        target: wallpaperSelector
        function onShowingChanged() {
          if (!wallpaperSelector.showing) {
            wallpaperSelector.lastContentX = sliceListView.contentX
            wallpaperSelector.lastIndex = sliceListView.currentIndex
          } else {
            sliceListView.forceActiveFocus()
          }
        }
      }
      onCountChanged: {
        if (count > 0 && wallpaperSelector.showing && wallpaperSelector._restorePending) {
          wallpaperSelector._restorePending = false
          contentX = wallpaperSelector.lastContentX
          currentIndex = Math.min(wallpaperSelector.lastIndex, count - 1)
        } else if (count > 0 && wallpaperSelector.showing) {
          currentIndex = Math.min(currentIndex, count - 1)
        }
      }

      MouseArea {
        anchors.fill: parent
        propagateComposedEvents: true
        onWheel: function(wheel) {

          var step = 1
          if (wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0) {
            sliceListView.currentIndex = Math.max(0, sliceListView.currentIndex - step)
          } else if (wheel.angleDelta.y < 0 || wheel.angleDelta.x < 0) {
            sliceListView.currentIndex = Math.min(service.filteredModel.count - 1, sliceListView.currentIndex + step)
          }
        }
        onPressed: function(mouse) { mouse.accepted = false }
        onReleased: function(mouse) { mouse.accepted = false }
        onClicked: function(mouse) { mouse.accepted = false }
      }

      Timer {
        id: wheelDebounce
        interval: 400
        onTriggered: {
          var centerX = sliceListView.contentX + sliceListView.width / 2
          var nearest = sliceListView.indexAt(centerX, sliceListView.height / 2)
          if (nearest >= 0) sliceListView.currentIndex = nearest
        }
      }

      Keys.onEscapePressed: wallpaperSelector.showing = false
      Keys.onReturnPressed: {
        if (currentIndex >= 0 && currentIndex < service.filteredModel.count) {
          const item = service.filteredModel.get(currentIndex)
          if (item.type === "we") {
            service.applyWE(item.weId)
          } else if (item.type === "video") {
            service.applyVideo(item.path)
          } else {
            service.applyStatic(item.path)
          }
        }
      }
      Keys.onPressed: function(event) {

        if (event.modifiers & Qt.ShiftModifier) {
          if (event.key === Qt.Key_Down) {
            wallpaperSelector.tagCloudVisible = !wallpaperSelector.tagCloudVisible
            if (!wallpaperSelector.tagCloudVisible) {
              service.selectedTags = []
              service.updateFilteredModel()
            }
            event.accepted = true
            return
          } else if (event.key === Qt.Key_Left) {
            if (service.selectedColorFilter === -1) {
              service.selectedColorFilter = 99
            } else if (service.selectedColorFilter === 99) {
              service.selectedColorFilter = 11
            } else if (service.selectedColorFilter === 0) {
              service.selectedColorFilter = 99
            } else {
              service.selectedColorFilter--
            }
            event.accepted = true
            return
          } else if (event.key === Qt.Key_Right) {
            if (service.selectedColorFilter === -1) {
              service.selectedColorFilter = 0
            } else if (service.selectedColorFilter === 11) {
              service.selectedColorFilter = 99
            } else if (service.selectedColorFilter === 99) {
              service.selectedColorFilter = 0
            } else {
              service.selectedColorFilter++
            }
            event.accepted = true
            return
          }
        }
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
          keyboardNavActive = true
        }

        if (event.key === Qt.Key_Left && !(event.modifiers & Qt.ShiftModifier)) {
          if (currentIndex > 0) {
            currentIndex--
          }
          event.accepted = true
          return
        }

        if (event.key === Qt.Key_Right && !(event.modifiers & Qt.ShiftModifier)) {
          if (currentIndex < service.filteredModel.count - 1) {
            currentIndex++
          }
          event.accepted = true
          return
        }
      }

      // Parallelogram slice delegate
      delegate: Item {
        id: delegateItem

        width: isCurrent ? wallpaperSelector.expandedWidth : wallpaperSelector.sliceWidth
        height: sliceListView.height
        property bool isCurrent: ListView.isCurrentItem
        property bool isHovered: itemMouseArea.containsMouse
        property bool flipped: false

        property string videoPath: model.videoFile ? model.videoFile : ""
        property bool hasVideo: videoPath.length > 0
        property bool videoActive: false

        onIsCurrentChanged: {
          if (!isCurrent) flipped = false
          if (isCurrent && hasVideo) {
            videoDelayTimer.restart()
          } else {
            videoDelayTimer.stop()
            videoActive = false
          }
        }

        Timer {
          id: videoDelayTimer
          interval: 300
          onTriggered: delegateItem.videoActive = true
        }

        z: isCurrent ? 100 : (isHovered ? 90 : 50 - Math.min(Math.abs(index - sliceListView.currentIndex), 50))

        property real viewX: x - sliceListView.contentX
        property real fadeZone: wallpaperSelector.sliceWidth * 1.5
        property real edgeOpacity: {
          if (fadeZone <= 0) return 1.0
          var center = viewX + width * 0.5

          var leftFade = Math.min(1.0, Math.max(0.0, center / fadeZone))
          var rightFade = Math.min(1.0, Math.max(0.0, (sliceListView.width - center) / fadeZone))
          return Math.min(leftFade, rightFade)
        }
        opacity: edgeOpacity
        Behavior on width {
          NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
        }


        containmentMask: Item {
          id: hitMask
          function contains(point) {
            var w = delegateItem.width
            var h = delegateItem.height
            var sk = wallpaperSelector.skewOffset
            if (h <= 0 || w <= 0) return false


            var leftX = sk * (1.0 - point.y / h)


            var rightX = w - sk * (point.y / h)
            return point.x >= leftX && point.x <= rightX && point.y >= 0 && point.y <= h
          }
        }

        Loader {
          id: sharedVideoLoader
          width: delegateItem.width
          height: delegateItem.height
          active: delegateItem.videoActive
          visible: false
          layer.enabled: active

          sourceComponent: Video {
            anchors.fill: parent
            source: "file://" + delegateItem.videoPath
            fillMode: VideoOutput.PreserveAspectCrop
            loops: MediaPlayer.Infinite
            muted: true
            Component.onCompleted: play()
          }
        }

        Item {
          id: flipContainer
          anchors.fill: parent
          transform: Rotation {
            id: flipRotation
            origin.x: flipContainer.width / 2
            origin.y: flipContainer.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: delegateItem.flipped ? 180 : 0
            Behavior on angle {
              NumberAnimation { duration: 400; easing.type: Easing.InOutQuad }
            }
          }

        Item {
          id: frontFace
          anchors.fill: parent
          visible: flipRotation.angle < 90

        Canvas {
          id: shadowCanvas
          z: -1
          anchors.fill: parent
          anchors.margins: -10
          property real shadowOffsetX: delegateItem.isCurrent ? 4 : 2
          property real shadowOffsetY: delegateItem.isCurrent ? 10 : 5
          property real shadowAlpha: delegateItem.isCurrent ? 0.6 : 0.4
          onWidthChanged: requestPaint()
          onHeightChanged: requestPaint()
          onShadowAlphaChanged: requestPaint()
          onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var ox = 10
            var oy = 10
            var w = delegateItem.width
            var h = delegateItem.height
            var sk = wallpaperSelector.skewOffset
            var sx = shadowOffsetX
            var sy = shadowOffsetY
            var layers = [
              { dx: sx, dy: sy, alpha: shadowAlpha * 0.5 },
              { dx: sx * 0.6, dy: sy * 0.6, alpha: shadowAlpha * 0.3 },
              { dx: sx * 1.4, dy: sy * 1.4, alpha: shadowAlpha * 0.2 }
            ]
            for (var i = 0; i < layers.length; i++) {
              var l = layers[i]
              ctx.globalAlpha = l.alpha
              ctx.fillStyle = "#000000"
              ctx.beginPath()
              ctx.moveTo(ox + sk + l.dx, oy + l.dy)
              ctx.lineTo(ox + w + l.dx, oy + l.dy)
              ctx.lineTo(ox + w - sk + l.dx, oy + h + l.dy)
              ctx.lineTo(ox + l.dx, oy + h + l.dy)
              ctx.closePath()
              ctx.fill()
            }
          }
        }

        Item {
          id: imageContainer
          anchors.fill: parent
          Image {
            id: thumbImage
            anchors.fill: parent
            source: "file://" + model.thumb
            fillMode: Image.PreserveAspectCrop
            smooth: true
            asynchronous: true
            sourceSize.width: wallpaperSelector.expandedWidth
            sourceSize.height: wallpaperSelector.sliceHeight
          }

          Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, delegateItem.isCurrent ? 0 : (delegateItem.isHovered ? 0.15 : 0.4))
            Behavior on color { ColorAnimation { duration: 200 } }
          }
          layer.enabled: true
          layer.smooth: true
          layer.samples: 4
          layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: ShaderEffectSource {
              sourceItem: Item {
                width: imageContainer.width
                height: imageContainer.height
                layer.enabled: true
                layer.smooth: true
                layer.samples: 8
                Shape {
                  anchors.fill: parent
                  antialiasing: true
                  preferredRendererType: Shape.CurveRenderer
                  ShapePath {
                    fillColor: "white"
                    strokeColor: "transparent"
                    startX: wallpaperSelector.skewOffset
                    startY: 0
                    PathLine { x: delegateItem.width; y: 0 }
                    PathLine { x: delegateItem.width - wallpaperSelector.skewOffset; y: delegateItem.height }
                    PathLine { x: 0; y: delegateItem.height }
                    PathLine { x: wallpaperSelector.skewOffset; y: 0 }
                  }
                }
              }
            }
            maskThresholdMin: 0.3
            maskSpreadAtMin: 0.3
          }
        }

        Item {
          id: videoOverlay
          anchors.fill: parent
          visible: sharedVideoLoader.active && sharedVideoLoader.status === Loader.Ready

          ShaderEffectSource {
            anchors.fill: parent
            sourceItem: sharedVideoLoader
            live: true
          }

          layer.enabled: true
          layer.smooth: true
          layer.samples: 4
          layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: ShaderEffectSource {
              sourceItem: Item {
                width: delegateItem.width
                height: delegateItem.height
                layer.enabled: true
                layer.smooth: true
                Shape {
                  anchors.fill: parent
                  antialiasing: true
                  preferredRendererType: Shape.CurveRenderer
                  ShapePath {
                    fillColor: "white"
                    strokeColor: "transparent"
                    startX: wallpaperSelector.skewOffset
                    startY: 0
                    PathLine { x: delegateItem.width; y: 0 }
                    PathLine { x: delegateItem.width - wallpaperSelector.skewOffset; y: delegateItem.height }
                    PathLine { x: 0; y: delegateItem.height }
                    PathLine { x: wallpaperSelector.skewOffset; y: 0 }
                  }
                }
              }
            }
            maskThresholdMin: 0.3
            maskSpreadAtMin: 0.3
          }
        }

        Shape {
          id: glowBorder
          anchors.fill: parent
          antialiasing: true
          preferredRendererType: Shape.CurveRenderer
          opacity: 1.0
          ShapePath {
            fillColor: "transparent"
            strokeColor: delegateItem.isCurrent
              ? (wallpaperSelector.colors ? wallpaperSelector.colors.primary : "#8BC34A")
              : (delegateItem.isHovered
                ? Qt.rgba(wallpaperSelector.colors ? wallpaperSelector.colors.primary.r : 0.5, wallpaperSelector.colors ? wallpaperSelector.colors.primary.g : 0.76, wallpaperSelector.colors ? wallpaperSelector.colors.primary.b : 0.29, 0.4)
                : Qt.rgba(0, 0, 0, 0.6))
            Behavior on strokeColor { ColorAnimation { duration: 200 } }
            strokeWidth: delegateItem.isCurrent ? 3 : 1
            startX: wallpaperSelector.skewOffset
            startY: 0
            PathLine { x: delegateItem.width; y: 0 }
            PathLine { x: delegateItem.width - wallpaperSelector.skewOffset; y: delegateItem.height }
            PathLine { x: 0; y: delegateItem.height }
            PathLine { x: wallpaperSelector.skewOffset; y: 0 }
          }
        }

        Rectangle {
          id: videoIndicator
          anchors.top: parent.top
          anchors.topMargin: 10
          anchors.right: parent.right
          anchors.rightMargin: 10
          width: 22
          height: 22
          radius: 11
          color: delegateItem.videoActive ? (wallpaperSelector.colors ? wallpaperSelector.colors.primary : "#4fc3f7") : Qt.rgba(0, 0, 0, 0.7)
          border.width: 1
          border.color: delegateItem.videoActive
            ? "transparent"
            : (wallpaperSelector.colors ? Qt.rgba(wallpaperSelector.colors.primary.r, wallpaperSelector.colors.primary.g, wallpaperSelector.colors.primary.b, 0.6) : Qt.rgba(1, 1, 1, 0.4))
          visible: delegateItem.hasVideo
          z: 10

          Behavior on color { ColorAnimation { duration: 200 } }

          Text {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: 1
            text: "▶"
            font.pixelSize: 9
            color: delegateItem.videoActive
              ? (wallpaperSelector.colors ? wallpaperSelector.colors.primaryText : "#000")
              : (wallpaperSelector.colors ? wallpaperSelector.colors.primary : "#4fc3f7")
          }
        }



        Item {
          id: typeBadge
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 8
          anchors.right: parent.right
          anchors.rightMargin: wallpaperSelector.skewOffset + 8
          property real skew: 4
          width: typeBadgeText.implicitWidth + 16 + skew
          height: 16
          z: 10

          Shape {
            anchors.fill: parent
            ShapePath {
              fillColor: Qt.rgba(0, 0, 0, 0.75)
              strokeColor: wallpaperSelector.colors ? Qt.rgba(wallpaperSelector.colors.primary.r, wallpaperSelector.colors.primary.g, wallpaperSelector.colors.primary.b, 0.4) : Qt.rgba(1, 1, 1, 0.2)
              strokeWidth: 1
              startX: typeBadge.skew; startY: 0
              PathLine { x: typeBadge.width; y: 0 }
              PathLine { x: typeBadge.width - typeBadge.skew; y: typeBadge.height }
              PathLine { x: 0; y: typeBadge.height }
              PathLine { x: typeBadge.skew; y: 0 }
            }
          }

          Text {
            id: typeBadgeText
            anchors.centerIn: parent
            text: model.type === "static" ? "PIC" : ((model.type === "video" || model.videoFile) ? "VID" : "WE")
            font.family: Style.fontFamily
            font.pixelSize: 9
            font.weight: Font.Bold
            font.letterSpacing: 0.5
            color: wallpaperSelector.colors ? wallpaperSelector.colors.tertiary : "#8bceff"
          }
        }

        // Matugen color preview dots – shows the colors quickshell components actually use
        Row {
          z: 10
          anchors.verticalCenter: typeBadge.verticalCenter
          anchors.right: typeBadge.left
          anchors.rightMargin: 6
          spacing: 4
          visible: Config.wallpaperColorDots && wallpaperColors !== undefined
          property var wallpaperColors: {
            var key = model.weId ? model.weId : model.thumb.split("/").pop().replace(/\.[^/.]+$/, "")
            return service.matugenDb[key]
          }
          Repeater {
            model: ["primary", "tertiary", "secondary"]
            Rectangle {
              width: 10; height: 10; radius: 5
              color: parent.wallpaperColors ? (parent.wallpaperColors[modelData] ?? "#888") : "#888"
              border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.5)
            }
          }
        }

        }

        Item {
          id: backFace
          anchors.fill: parent
          visible: flipRotation.angle >= 90
          transform: Rotation {
            origin.x: backFace.width / 2
            origin.y: backFace.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: 180
          }

          Item {
            id: backClip
            anchors.fill: parent

            Rectangle {
              anchors.fill: parent
              color: wallpaperSelector.colors
                ? wallpaperSelector.colors.surfaceContainer
                : "#1a1a2e"
            }

            ShaderEffectSource {
              anchors.fill: parent
              sourceItem: sharedVideoLoader
              live: true
              visible: delegateItem.videoActive && delegateItem.flipped && sharedVideoLoader.status === Loader.Ready
              opacity: 0.25
            }

            Image {
              anchors.fill: parent
              source: "file://" + model.thumb
              fillMode: Image.PreserveAspectCrop
              opacity: 0.12
              visible: !(delegateItem.videoActive && delegateItem.flipped)
            }

            // Action buttons
            Column {
              anchors.centerIn: parent
              spacing: 14
              width: Math.min(parent.width * 0.45, 260)

              Text {
                width: parent.parent.width - wallpaperSelector.skewOffset * 2 - 20
                anchors.horizontalCenter: parent.horizontalCenter
                text: model.name.replace(/\.[^/.]+$/, "").toUpperCase()
                color: wallpaperSelector.colors ? wallpaperSelector.colors.tertiary : "#8bceff"
                font.family: Style.fontFamily
                font.pixelSize: 14
                font.weight: Font.Bold
                font.letterSpacing: 1
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
              }

              Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.1) }

              Item {
                width: parent.width
                height: 36

                Text {
                  id: favLabel
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: "FAVOURITE"
                  color: wallpaperSelector.colors ? wallpaperSelector.colors.tertiary : "#8bceff"
                  font.family: Style.fontFamily
                  font.pixelSize: 12
                  font.weight: Font.Medium
                  font.letterSpacing: 0.5
                }

                Item {
                  id: favToggle
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  width: 48; height: 24

                  property bool checked: false

                  Component.onCompleted: {
                    var key = (model.weId || "") !== "" ? model.weId : model.name
                    checked = !!service.favouritesDb[key]
                  }

                  Connections {
                    target: delegateItem
                    function onFlippedChanged() {
                      if (delegateItem.flipped) {
                        var key = (model.weId || "") !== "" ? model.weId : model.name
                        favToggle.checked = !!service.favouritesDb[key]
                      }
                    }
                  }

                  Canvas {
                    id: favToggleBg
                    anchors.fill: parent
                    property bool isOn: favToggle.checked
                    property color fillColor: isOn
                      ? (wallpaperSelector.colors ? wallpaperSelector.colors.primary : "#4fc3f7")
                      : Qt.rgba(1, 1, 1, 0.15)
                    onFillColorChanged: requestPaint()
                    onIsOnChanged: requestPaint()
                    onPaint: {
                      var ctx = getContext("2d")
                      ctx.clearRect(0, 0, width, height)
                      var sk = 8
                      ctx.fillStyle = fillColor
                      ctx.beginPath()
                      ctx.moveTo(sk, 0)
                      ctx.lineTo(width, 0)
                      ctx.lineTo(width - sk, height)
                      ctx.lineTo(0, height)
                      ctx.closePath()
                      ctx.fill()
                    }
                  }

                  Canvas {
                    id: favToggleKnob
                    width: 22; height: 18; y: 3
                    x: favToggle.checked ? parent.width - width - 4 : 4
                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    property color knobColor: favToggle.checked
                      ? (wallpaperSelector.colors ? wallpaperSelector.colors.primaryText : "#000")
                      : (wallpaperSelector.colors ? wallpaperSelector.colors.surfaceText : "#fff")
                    onKnobColorChanged: requestPaint()
                    onPaint: {
                      var ctx = getContext("2d")
                      ctx.clearRect(0, 0, width, height)
                      var sk = 5
                      ctx.fillStyle = knobColor
                      ctx.beginPath()
                      ctx.moveTo(sk, 0)
                      ctx.lineTo(width, 0)
                      ctx.lineTo(width - sk, height)
                      ctx.lineTo(0, height)
                      ctx.closePath()
                      ctx.fill()
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      favToggle.checked = !favToggle.checked
                      service.toggleFavourite(model.name, model.weId || "")
                    }
                  }
                }
              }

              Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.1) }

              Rectangle {
                width: parent.width; height: 42; radius: 8
                color: backViewMouse.containsMouse
                  ? Qt.rgba(wallpaperSelector.colors ? wallpaperSelector.colors.primary.r : 0.5,
                             wallpaperSelector.colors ? wallpaperSelector.colors.primary.g : 0.5,
                             wallpaperSelector.colors ? wallpaperSelector.colors.primary.b : 0.5, 0.25)
                  : Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: backViewMouse.containsMouse
                  ? Qt.rgba(wallpaperSelector.colors ? wallpaperSelector.colors.primary.r : 1,
                             wallpaperSelector.colors ? wallpaperSelector.colors.primary.g : 1,
                             wallpaperSelector.colors ? wallpaperSelector.colors.primary.b : 1, 0.4)
                  : Qt.rgba(1, 1, 1, 0.08)
                Behavior on color { ColorAnimation { duration: 100 } }
                Text {
                  anchors.centerIn: parent
                  text: "VIEW FILE"
                  color: backViewMouse.containsMouse
                    ? (wallpaperSelector.colors ? wallpaperSelector.colors.primary : "#ffffff")
                    : (wallpaperSelector.colors ? wallpaperSelector.colors.tertiary : "#8bceff")
                  font.family: Style.fontFamily; font.pixelSize: 12
                  font.weight: Font.Medium; font.letterSpacing: 0.5
                  Behavior on color { ColorAnimation { duration: 100 } }
                }
                MouseArea {
                  id: backViewMouse
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    var dir = model.path.substring(0, model.path.lastIndexOf("/"))
                    Qt.openUrlExternally("file://" + dir)
                    delegateItem.flipped = false
                  }
                }
              }

              // Delete
              Rectangle {
                width: parent.width; height: 42; radius: 8
                color: backDeleteMouse.containsMouse
                  ? Qt.rgba(1, 0.3, 0.3, 0.25) : Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: backDeleteMouse.containsMouse
                  ? Qt.rgba(1, 0.3, 0.3, 0.4) : Qt.rgba(1, 1, 1, 0.08)
                Behavior on color { ColorAnimation { duration: 100 } }
                Text {
                  anchors.centerIn: parent
                  text: "DELETE"
                  color: backDeleteMouse.containsMouse ? "#ff6b6b"
                    : (wallpaperSelector.colors ? wallpaperSelector.colors.tertiary : "#8bceff")
                  font.family: Style.fontFamily; font.pixelSize: 12
                  font.weight: Font.Medium; font.letterSpacing: 0.5
                  Behavior on color { ColorAnimation { duration: 100 } }
                }
                MouseArea {
                  id: backDeleteMouse
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    var idx = index
                    sliceListView.animateRemoval = true
                    service.deleteWallpaperItem(model.type, model.name, model.weId || "")
                    var newIdx = Math.min(idx, service.filteredModel.count - 1)
                    // Force ListView to re-evaluate by toggling index
                    sliceListView.currentIndex = -1
                    sliceListView.currentIndex = newIdx
                    sliceListView.positionViewAtIndex(newIdx, ListView.Center)
                    removeAnimResetTimer.restart()
                  }
                }
              }

              // View on Steam (WE only)
              Rectangle {
                visible: model.type === "we"
                width: parent.width; height: 42; radius: 8
                color: backSteamMouse.containsMouse
                  ? Qt.rgba(wallpaperSelector.colors ? wallpaperSelector.colors.primary.r : 0.5,
                             wallpaperSelector.colors ? wallpaperSelector.colors.primary.g : 0.5,
                             wallpaperSelector.colors ? wallpaperSelector.colors.primary.b : 0.5, 0.25)
                  : Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: backSteamMouse.containsMouse
                  ? Qt.rgba(wallpaperSelector.colors ? wallpaperSelector.colors.primary.r : 1,
                             wallpaperSelector.colors ? wallpaperSelector.colors.primary.g : 1,
                             wallpaperSelector.colors ? wallpaperSelector.colors.primary.b : 1, 0.4)
                  : Qt.rgba(1, 1, 1, 0.08)
                Behavior on color { ColorAnimation { duration: 100 } }
                Text {
                  anchors.centerIn: parent
                  text: "VIEW ON STEAM"
                  color: backSteamMouse.containsMouse
                    ? (wallpaperSelector.colors ? wallpaperSelector.colors.primary : "#ffffff")
                    : (wallpaperSelector.colors ? wallpaperSelector.colors.tertiary : "#8bceff")
                  font.family: Style.fontFamily; font.pixelSize: 12
                  font.weight: Font.Medium; font.letterSpacing: 0.5
                  Behavior on color { ColorAnimation { duration: 100 } }
                }
                MouseArea {
                  id: backSteamMouse
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    service.openSteamPage(model.weId || "")
                    delegateItem.flipped = false
                  }
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              z: -1
              onClicked: delegateItem.flipped = false
            }

            layer.enabled: true
            layer.smooth: true
            layer.samples: 4
            layer.effect: MultiEffect {
              maskEnabled: true
              maskSource: ShaderEffectSource {
                sourceItem: Item {
                  width: backClip.width
                  height: backClip.height
                  layer.enabled: true
                  layer.smooth: true
                  layer.samples: 8
                  Shape {
                    anchors.fill: parent
                    antialiasing: true
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                      fillColor: "white"
                      strokeColor: "transparent"
                      startX: wallpaperSelector.skewOffset
                      startY: 0
                      PathLine { x: delegateItem.width; y: 0 }
                      PathLine { x: delegateItem.width - wallpaperSelector.skewOffset; y: delegateItem.height }
                      PathLine { x: 0; y: delegateItem.height }
                      PathLine { x: wallpaperSelector.skewOffset; y: 0 }
                    }
                  }
                }
              }
              maskThresholdMin: 0.3
              maskSpreadAtMin: 0.3
            }
          }

          Shape {
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
              fillColor: "transparent"
              strokeColor: wallpaperSelector.colors ? wallpaperSelector.colors.primary : "#8BC34A"
              strokeWidth: 2
              startX: wallpaperSelector.skewOffset
              startY: 0
              PathLine { x: delegateItem.width; y: 0 }
              PathLine { x: delegateItem.width - wallpaperSelector.skewOffset; y: delegateItem.height }
              PathLine { x: 0; y: delegateItem.height }
              PathLine { x: wallpaperSelector.skewOffset; y: 0 }
            }
          }
        }

        }

        MouseArea {
          id: itemMouseArea
          anchors.fill: parent
          hoverEnabled: !delegateItem.flipped
          acceptedButtons: delegateItem.flipped ? Qt.RightButton : (Qt.LeftButton | Qt.RightButton)
          cursorShape: delegateItem.flipped ? Qt.ArrowCursor : Qt.PointingHandCursor
          onPositionChanged: function(mouse) {
            if (delegateItem.flipped) return
            var globalPos = mapToItem(sliceListView, mouse.x, mouse.y)
            var dx = Math.abs(globalPos.x - sliceListView.lastMouseX)
            var dy = Math.abs(globalPos.y - sliceListView.lastMouseY)
            if (dx > 2 || dy > 2) {
              sliceListView.lastMouseX = globalPos.x
              sliceListView.lastMouseY = globalPos.y
              sliceListView.keyboardNavActive = false
              sliceListView.currentIndex = index
            }
          }
          onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
              sliceListView.currentIndex = index
              delegateItem.flipped = !delegateItem.flipped
            } else if (!delegateItem.flipped) {
              if (delegateItem.isCurrent) {
                if (model.type === "we") {
                  service.applyWE(model.weId)
                } else if (model.type === "video") {
                  service.applyVideo(model.path)
                } else {
                  service.applyStatic(model.path)
                }
              } else {
                sliceListView.currentIndex = index
              }
            }
          }
        }
    }
    }



  }
}