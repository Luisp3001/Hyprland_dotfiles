import QtQuick

QtObject {
    id: root
    property bool isDarkMode: true

    // Sizing & Fonts 
    readonly property int    radiusOuter: 24
    readonly property int    radiusInner: 16
    readonly property int    padCard:     12
    readonly property int    gapCard:     10
    readonly property int    btnH:        54
    readonly property int    sliderH:     24
    readonly property string textFont:    "Manrope"
    readonly property string iconFont:    "JetBrainsMono Nerd Font"

    property var walColors: null

    // 1) Surfaces 
    property color bgPanel:     walColors ? walColors.special.background : (isDarkMode ? Qt.rgba(20/255, 23/255, 25/255, 0.88) : Qt.rgba(237/255, 197/255, 198/255, 0.69))
    property color bgMain:      walColors ? walColors.special.background : (isDarkMode ? "#141719"  : "#a6b0a0")
    property color bgCard:      walColors ? Qt.lighter(walColors.special.background, 1.1) : (isDarkMode ? "#1e2326"  : "#edc5c6b0")
    property color bgItem:      walColors ? Qt.lighter(walColors.special.background, 1.25) : (isDarkMode ? "#2d353b"  : Qt.rgba(0, 0, 0, 0.05))
    property color bgItemHover: walColors ? Qt.lighter(walColors.special.background, 1.4) : (isDarkMode ? "#374145"  : Qt.rgba(0, 0, 0, 0.08))
    property color bgWidget:    walColors ? Qt.lighter(walColors.special.background, 1.25) : (isDarkMode ? "#2d353b"  : Qt.rgba(0, 0, 0, 0.05))
    property color bgOSD:       walColors ? Qt.lighter(walColors.special.background, 1.1) : (isDarkMode ? '#f9515451': '#f9c5c6b0')

    // 2) Text 
    property color textPrimary:   walColors ? walColors.special.foreground : (isDarkMode ? "#d3c6aa" : "#3c4841")
    property color textSecondary: walColors ? Qt.darker(walColors.special.foreground, 1.4) : (isDarkMode ? "#9da9a0" : "#232a23")
    property color textOnAccent:  walColors ? walColors.special.background : (isDarkMode ? "#232a2e" : "#f0f2d4")
    property color textOSD:       walColors ? walColors.special.foreground : (isDarkMode ? '#a7b3aa' : '#5f7b5f')

    // 3) Accents 
    property color accent:        walColors ? walColors.colors.color2 : (isDarkMode ? "#a7c080" : "#3c4841")
    property color accentSlider:  walColors ? walColors.colors.color3 : (isDarkMode ? "#83C092" : "#273018")
    property color accentBlue:    walColors ? walColors.colors.color4 : "#7AA1A6"
    property color accentRed:     walColors ? walColors.colors.color1 : (isDarkMode ? "#e67e80" : "#7a2a2a")
    property color accentSlider2: walColors ? walColors.colors.color5 : (isDarkMode ? "#f1af97" : "#d39984")

    // 4) Lines, hovers, misc 
    property color border:          walColors ? Qt.alpha(walColors.colors.color3, 0.4) : (isDarkMode ? "#70a7c080" : "#b9566a35")
    property color outline:         isDarkMode ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.10)
    property color subtleFill:      isDarkMode ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.05)
    property color subtleFillHover: isDarkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.10)
    property color hoverSpotlight:  isDarkMode ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.10)

    // 5) Weather
    property color weatherColor: walColors ? walColors.special.foreground : (isDarkMode ? "#9da9a0" : "#3c4841")
}
